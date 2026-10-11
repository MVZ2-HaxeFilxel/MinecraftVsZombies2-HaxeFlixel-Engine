package unity;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;

/**
 * Minimal UnityEngine.AudioSource shim, bridged to Flixel sounds.
 *
 * PORT-NOTE: Unity 的 AudioSource 是引擎侧的播放通道；移植层给每个 AudioSource 分配一个独立的 FlxSound
 * （同一个 AudioClip 可以被多个 AudioSource 同时播放），并复刻 Unity 的属性语义：
 *   - Play()  在正在播放时会从头重播（Unity 的行为）
 *   - Stop()  停止并归零播放位置；Pause() 之后 isPlaying 为 false（与 Unity 一致）
 *   - time/timeSamples 的单位分别是秒/采样数（Unity 语义），内部换算到毫秒
 *   - volume 走 unity.AudioMixerGroup 的总线（outputAudioMixerGroup），总线音量变化会立刻作用于正在播放的声音
 *   - playOnAwake：数值按 prefab 保留（见 audio_manifest.json 的 audioSourceTemplates）。
 *     TODO-PORT: Unity 在 GameObject 被激活时会对 playOnAwake 的 AudioSource 调用 Play()
 *     （SoundManager.Play 正是靠 `audioSource.gameObject.SetActive(true)` 起播的），
 *     而移植层的 unity.GameObject.SetActive 目前只改 active 标志、不派发组件生命周期，
 *     因此整条链路还缺这一环（见报告「需别的 agent 配合」：GameObject.SetActive / Instantiate）。
 *     本类只负责「被显式调用 Play() 之后」的播放语义。
 *
 * PORT-NOTE（重要的平台差异）：本机 lime 分支（lime-anit）的原生音频后端**不上报播放位置**
 * （openfl 的 SoundChannel.position 恒为 0），也**不派发 Event.SOUND_COMPLETE**。
 * 而 flixel 的 FlxSound 依赖 _channel.position 来计算 time、判断播放结束（endTime）与重启循环音效，
 * 于是直接用 flixel 会出现：time 恒为 0、音效播完后 isPlaying 永远为 true（SoundManager 无法回收音源）、
 * 循环音效只响一遍。为此本类用一个「本地播放时钟」补上这些语义：
 *   * 每个 AudioSource 播放的对象是 PlaybackSound（FlxSound 的子类），挂在 FlxG.sound.list 上，
 *     每帧回调本类；后端能上报位置时（time > 0）沿用后端的值（时钟自动关闭，行为等同 flixel 原生），
 *     后端恒为 0 时由本地时钟按帧累计播放位置（随 pitch 变化）。
 *   * 播放到 clip 末尾时：循环音效自行重播（对应 flixel 的 looped + endTime 路径），非循环音效做与
 *     flixel 的 stopped() 等价的收尾（playing 置 false，SoundManager.Update 据此回收音源）。
 *     本地时钟只在后端恒为 0 时启用，此时 flixel 自己的 endTime 判断（依赖 _channel.position）
 *     永远不会触发，因此两条结束路径互斥、不会重复处理。
 *   * TODO-PORT: 后端可靠时的循环是带缓冲的无缝循环；本地时钟路径靠重播实现，循环接缝处会有约一帧的间隙。
 *     等 lime 的原生音频补齐位置/完成事件后，可删除本地时钟（保留代码路径即可自动切换）。
 * PORT-NOTE: spatialBlend / 3D 衰减 / dopplerLevel / minDistance / maxDistance 只保留数值：
 * flixel 与 lime 的音频后端只有 2D 播放，工程里四个 AudioSource 模板的 spatialBlend 都是 0（见
 * assets/audio_manifest.json 的 audioSourceTemplates），因此不影响还原度。
 */
class AudioSource extends Behaviour {
    /** 判定「后端会上报位置」的下限（毫秒）：超过它才认为 SoundChannel.position 可信。 */
    private static inline var BACKEND_POSITION_THRESHOLD_MS:Float = 0.5;

    public var clip(get, set):AudioClip;
    public var volume(get, set):Float;
    public var pitch(get, set):Float;
    public var loop(get, set):Bool;
    public var mute(get, set):Bool;
    public var playOnAwake:Bool = true;
    public var time(get, set):Float;
    public var timeSamples(get, set):Int;
    public var spatialBlend:Float = 0;
    public var priority:Int = 128;
    public var dopplerLevel:Float = 1;
    public var minDistance:Float = 1;
    public var maxDistance:Float = 500;
    public var rolloffMode:Int = 0;

    /** 声音走哪条 mixer 总线（Unity 的 AudioSource.outputAudioMixerGroup）。 */
    public var outputAudioMixerGroup(get, set):AudioMixerGroup;
    function get_outputAudioMixerGroup():AudioMixerGroup return _outputAudioMixerGroup;
    function set_outputAudioMixerGroup(value:AudioMixerGroup):AudioMixerGroup {
        _outputAudioMixerGroup = value;
        // 已在播放的声音要跟着换总线（Unity 里换 OutputAudioMixerGroup 会立刻改变音量路由）。
        if (sound != null)
            attachSound();
        return value;
    }

    public var isPlaying(get, never):Bool;
    function get_isPlaying():Bool return sound != null && sound.playing;
    public var isVirtual(get, never):Bool;
    function get_isVirtual():Bool return false;

    private var _clip:AudioClip;
    private var _volume:Float = 1;
    private var _pitch:Float = 1;
    private var _loop:Bool = false;
    private var _mute:Bool = false;
    private var _outputAudioMixerGroup:AudioMixerGroup;
    /** 该 AudioSource 独占的播放对象（懒创建：第一次 Play 时才解码并播放）。 */
    private var sound:PlaybackSound = null;
    /** sound 当前装载的是哪个 clip。 */
    private var loadedClip:AudioClip = null;
    /** sound 是否已登记进 FlxG.sound.list（播放结束后会摘掉，避免列表无限增长）。 */
    private var attached:Bool = false;
    /** 本地播放时钟的位置（毫秒）；只在后端不上报位置时使用。 */
    private var clockPosition:Float = 0;
    /** 本地时钟是否接管（后端 position 恒为 0）。 */
    private var clockActive:Bool = false;

    public function new() {
        super();
    }

    // #region 属性
    function get_clip():AudioClip return _clip;
    function set_clip(value:AudioClip):AudioClip {
        if (_clip == value)
            return value;
        // C# 里给正在播放的 AudioSource 换 clip 等价于换曲继续播放（Dream/Nightmare 关卡用
        // SetPlayingMusic 在音乐播放中替换音轨，并随后把 Time 置 0）。
        var wasPlaying = isPlaying;
        stopAndRelease();
        _clip = value;
        if (wasPlaying)
            Play();
        return value;
    }

    function get_volume():Float return _volume;
    function set_volume(value:Float):Float {
        _volume = value;
        applyVolume();
        return value;
    }

    function get_pitch():Float return _pitch;
    function set_pitch(value:Float):Float {
        _pitch = value;
        applyPitch();
        return value;
    }

    function get_loop():Bool return _loop;
    function set_loop(value:Bool):Bool {
        _loop = value;
        if (sound != null)
            sound.looped = value;
        return value;
    }

    function get_mute():Bool return _mute;
    function set_mute(value:Bool):Bool {
        _mute = value;
        applyVolume();
        return value;
    }

    // C#: public float time { get; set; }（秒）
    function get_time():Float {
        if (sound == null)
            return 0;
        return getPositionMs() / 1000;
    }
    function set_time(value:Float):Float {
        if (sound == null)
            return value;
        var v = value < 0 ? 0 : value;
        var length = getClipLength();
        if (length > 0 && v > length)
            v = length;
        clockPosition = v * 1000;
        sound.time = clockPosition; // flixel 会停在目标位置，播放中则从该位置重新起播
        return value;
    }

    // C#: public int timeSamples { get; set; }
    function get_timeSamples():Int {
        return Std.int(get_time() * getFrequency());
    }
    function set_timeSamples(value:Int):Int {
        set_time(value / getFrequency());
        return value;
    }
    // #endregion

    // #region 播放控制
    public function Play():Void {
        var flx = prepareSound();
        if (flx == null) {
            // PORT-NOTE: Unity 的 Play() 在 clip 为空/音频数据取不到时静默失败（移植层保留该行为），
            // 但补一次告警：否则整条播放链失败时日志里没有任何痕迹。具体原因见 prepareSound 的告警
            // （clip 为空 / 解码失败），同一条只记一次。
            WarnOnce('Play/${clipKey(_clip)}', 'AudioSource.Play 被跳过：${clipKey(_clip)} 无法播放（原因见上一条告警）。');
            return;
        }
        applyVolume();
        applyPitch();
        clockPosition = 0;
        flx.play(true);
    }
    public function PlayDelayed(delay:Float):Void {
        // C# 里没有调用点（工程内音频全部走 SoundManager/MusicManager）。移植层没有音频调度器，
        // 这里退化为立即播放并告警，避免静默失效。
        Debug.LogWarning('AudioSource.PlayDelayed 在移植层退化为立即播放（delay=$delay）。');
        Play();
    }
    public function PlayOneShot(clip:AudioClip, ?volumeScale:Float = 1):Void {
        if (clip == null) {
            WarnOnce("PlayOneShot/null-clip", 'AudioSource.PlayOneShot 被跳过：clip 为 null。');
            return;
        }
        var group = getBusGroup();
        var oneShot = clip.newSound(false);
        if (oneShot == null) {
            WarnOnce('PlayOneShot/${clipKey(clip)}', 'AudioSource.PlayOneShot 被跳过：${clipKey(clip)} 无法播放（音频数据缺失）。');
            return;
        }
        oneShot.volume = clamp01(_volume * (volumeScale == null ? 1 : volumeScale));
        // PORT-NOTE: 一次性音效没有 AudioSource 持有它，同样要补上「后端不上报位置」时的结束检测，
        // 否则它会一直留在 FlxG.sound.list 里且 playing 永为 true。
        var lengthMs = clip.length > 0 ? clip.length * 1000 : oneShot.length;
        var played = 0.0;
        oneShot.onTick = function(elapsed:Float) {
            if (!oneShot.playing)
                return;
            if (oneShot.time > BACKEND_POSITION_THRESHOLD_MS)
                return; // 后端可用，交给 flixel 自己的结束判断
            played += elapsed * 1000;
            if (lengthMs > 0 && played >= lengthMs)
                oneShot.stop();
        };
        if (group != null)
            group.add(oneShot);
        oneShot.play();
    }
    public function Stop():Void {
        if (sound == null)
            return;
        sound.stop();
        clockPosition = 0;
        detachSound();
    }
    public function Pause():Void {
        if (sound == null)
            return;
        // PORT-NOTE: 暂停不摘掉更新列表——flixel 的 resume() 需要靠 update 继续推进。
        sound.pause();
    }
    public function UnPause():Void {
        if (sound == null)
            return;
        // PORT-NOTE: flixel 的 resume() 用内部 _time 作为起点，而后端不上报位置时它已被清成 0；
        // 先把本地时钟的位置写回去，再从该位置继续播放。
        if (clockActive)
            sound.time = clockPosition;
        sound.resume();
    }
    public function SetScheduledEndTime(time:Float):Void {
        // C# 侧无调用点；flixel 的 FlxSound.endTime 是「播放位置」的毫秒值，语义与 Unity 的
        // 「绝对时间戳」不同，移植层不实现（保留空实现并告警）。
        Debug.LogWarning('AudioSource.SetScheduledEndTime 在移植层未实现（time=$time）。');
    }
    public function GetOutputData(samples:Array<Float>, channel:Int):Void {
        // C# 侧无调用点：Unity 用于取实时 PCM 采样（波形显示）。移植层不做音频回调捕获。
    }
    // #endregion

    // #region 内部
    private function getFrequency():Int {
        if (_clip != null && _clip.frequency > 0)
            return _clip.frequency;
        return 44100;
    }

    private function getClipLength():Float {
        if (_clip != null && _clip.length > 0)
            return _clip.length;
        if (sound != null && sound.length > 0)
            return sound.length / 1000; // flixel 的 length 是毫秒
        return 0;
    }

    /** 当前播放位置（毫秒）：后端能上报时用后端值，否则用本地时钟。 */
    private function getPositionMs():Float {
        if (sound == null)
            return 0;
        var backend = sound.time;
        if (backend > BACKEND_POSITION_THRESHOLD_MS) {
            clockActive = false;
            clockPosition = backend;
            return backend;
        }
        if (sound.playing && clockPosition > 0)
            clockActive = true;
        return clockActive ? clockPosition : backend;
    }

    /** 保证有一个装载了当前 clip 的 FlxSound（必要时解码），并挂到总线上。 */
    private function prepareSound():PlaybackSound {
        if (_clip == null) {
            WarnOnce('prepareSound/null-clip', 'AudioSource：clip 为 null 时调用了 Play。');
            return null;
        }
        if (sound != null && loadedClip == _clip && sound.exists) {
            sound.looped = _loop;
            attachSound();
            return sound;
        }
        stopAndRelease();
        sound = _clip.newSound(_loop, _loop ? null : onSoundComplete);
        if (sound == null) {
            // PORT-NOTE: 音频数据缺失时 Unity 的 Play() 会静默失败（clip 为空），保持一致；
            // 但补一次告警（带 clip 的资源路径），否则解码失败时没有任何日志痕迹。
            WarnOnce('prepareSound/decode/${clipKey(_clip)}',
                'AudioSource：${clipKey(_clip)} 解码不出可播放的声音数据，播放已放弃。');
            return null;
        }
        sound.onTick = onTick;
        loadedClip = _clip;
        attachSound();
        return sound;
    }

    /**
     * 每帧由 flixel 的 FlxG.sound.list 驱动（见 PlaybackSound）。
     * PORT-NOTE: 后端不上报播放位置时，这里按帧累计位置并自行判断播放结束/循环，
     * 补回 flixel 依赖 _channel.position 而失效的语义（isPlaying、SoundManager 的音源回收、循环音效）。
     */
    private function onTick(elapsed:Float):Void {
        if (sound == null || !sound.playing)
            return;
        var backend = sound.time;
        if (backend > BACKEND_POSITION_THRESHOLD_MS) {
            // 后端会上报位置：交给 flixel 自己的 endTime/looped 逻辑，本地时钟关闭。
            clockActive = false;
            clockPosition = backend;
            return;
        }
        // 后端恒为 0 → 本地时钟接管（位置随 pitch 变化，与 Unity 的 time 语义一致）。
        clockActive = true;
        clockPosition += elapsed * 1000 * pitchRate();
        var lengthMs = getClipLength() * 1000;
        if (lengthMs <= 0 || clockPosition < lengthMs)
            return;
        if (_loop) {
            clockPosition = 0;
            sound.play(true);
        } else {
            clockPosition = 0;
            onSoundComplete();
            sound.stop();
        }
    }

    private function pitchRate():Float {
        #if FLX_PITCH
        return _pitch <= 0 ? 1 : _pitch;
        #else
        return 1;
        #end
    }

    /** clip 的诊断名：优先 lime 资源路径（audio_manifest.json 的 assetPath），其次资源名。 */
    private static function clipKey(clip:AudioClip):String {
        if (clip == null)
            return "<null clip>";
        if (clip.soundKey != null)
            return clip.soundKey;
        return clip.name != null && clip.name.length > 0 ? clip.name : "<unnamed clip>";
    }

    /** 同一条播放失败原因只告警一次（播放失败通常会被反复重试，避免刷屏）。 */
    private static function WarnOnce(key:String, message:String):Void {
        if (warnedKeys.exists(key))
            return;
        warnedKeys.set(key, true);
        Debug.LogWarning(message);
    }
    private static var warnedKeys:Map<String, Bool> = new Map();

    /**
     * 非循环音效播完后的清理：把它从 flixel 的更新列表里摘掉。
     * PORT-NOTE: FlxG.sound.list 的 remove(sound, false) 只是把成员槽位置空（不 splice），
     * 因此在 flixel 的 update 遍历过程中调用是安全的，槽位之后可被 add() 复用。
     * 循环音效不摘（重播要靠每帧 update），它们在 Stop() 时摘除。
     */
    private function onSoundComplete():Void {
        detachSound();
    }

    /** 把 FlxSound 登记进 flixel 的更新列表与 mixer 总线。 */
    private function attachSound():Void {
        if (sound == null)
            return;
        if (!attached && FlxG.sound != null) {
            FlxG.sound.list.add(sound);
            attached = true;
        }
        var group = getBusGroup();
        if (group != null)
            group.add(sound);
    }

    /** 把 FlxSound 从更新列表与总线里摘掉（停止播放后调用，避免 FlxG.sound.list 无限增长）。 */
    private function detachSound():Void {
        if (sound == null)
            return;
        if (attached) {
            // splice = false：只置空成员槽位，列表长度不变但槽位可被复用。
            if (FlxG.sound != null)
                FlxG.sound.list.remove(sound, false);
            attached = false;
        }
        if (sound.group != null)
            sound.group.remove(sound);
    }

    private function stopAndRelease():Void {
        if (sound == null)
            return;
        detachSound();
        sound.stop();
        sound.destroy();
        sound = null;
        loadedClip = null;
        clockActive = false;
        clockPosition = 0;
    }

    private function getBusGroup():FlxSoundGroup {
        var group = _outputAudioMixerGroup;
        if (group != null)
            return group.group;
        // PORT-NOTE: Unity 的 AudioSource 若未指定 outputAudioMixerGroup，声音只经过 Master 总线
        // （不可被 SoundVolume/MusicVolume 调节）。移植层用 flixel 的默认声音组表达同样的「不额外增益」。
        if (FlxG.sound != null)
            return FlxG.sound.defaultSoundGroup;
        return null;
    }

    private function applyVolume():Void {
        if (sound == null)
            return;
        sound.volume = _mute ? 0 : clamp01(_volume);
    }

    private function applyPitch():Void {
        if (sound == null)
            return;
        #if FLX_PITCH
        sound.pitch = _pitch;
        #end
    }

    private static function clamp01(v:Float):Float {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
    // #endregion
}


/**
 * 播放层用的 FlxSound：挂在 FlxG.sound.list 上，每帧把 elapsed 回调给所在的 AudioSource，
 * 让 AudioSource 能在「后端不上报播放位置」时用本地时钟补上 time / 播放结束 / 循环的语义。
 * PORT-NOTE: 这是 unity.AudioSource 的实现细节（见该类头部的平台差异说明），
 * 游戏代码只通过 unity.AudioSource 使用音频，不会直接依赖本类。
 */
class PlaybackSound extends FlxSound {
    /** 每帧回调（参数是本次经过的秒数）。 */
    public var onTick:Float->Void = null;

    public function new() {
        super();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (onTick != null)
            onTick(elapsed);
    }
}

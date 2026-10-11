package unity;

import flixel.FlxG;
import flixel.sound.FlxSound;
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import openfl.media.Sound;
import unity.AudioSource.PlaybackSound;
import unity.addressableassets.ResourceManifest;
import unity.UnityObject;

// Minimal UnityEngine.AudioClip shim.
class AudioClip extends UnityObject {
    public var length:Float = 0;
    public var samples:Int = 0;
    public var channels:Int = 1;
    public var frequency:Int = 44100;
    public var loadType:Int = 0;
    public var loadInBackground:Bool = false;

    // PORT-NOTE: 移植层扩展字段。Unity 的 AudioClip 由原生音频系统持有 PCM 数据，
    // 这里由 unity.addressableassets.ResourceManifest 在解码 ogg/wav/mp3 后写入：
    //   sound    —— openfl 的声音对象（Sound.fromAudioBuffer）
    //   flxSound —— flixel 的播放对象（new FlxSound().loadEmbedded(sound)），播放层可直接用
    // 上面的 length/samples/channels/frequency 也来自同一份解码结果（MusicManager 需要 length
    // 来计算音乐播放进度）。
    public var sound:openfl.media.Sound;
    public var flxSound:flixel.sound.FlxSound;

    // PORT-NOTE: 音频管线的扩展字段（见 HaxePort/assets/audio_manifest.json，由
    // HaxePort/tools_build/export_audio_manifest.py 从 Addressables 组 + .meta + 音频文件头导出）。
    // 有了这些字段，AudioClip 可以在「不解码文件」的情况下提供 Unity 侧的长度/采样率，并在第一次
    // 播放时才让 lime 去解码（对应 Unity 的 Streaming / CompressedInMemory 加载方式）：
    //   address   —— Addressables 的地址（PrimaryKey），如 "mvz2:click"
    //   soundKey  —— lime 资源 id / 相对 assets 根的文件路径，如
    //                "GameContent/Assets/mvz2/sounds/init/click.wav"
    //   format    —— 文件的实际容器（wav/ogg/mp3；工程里有 47 个 .wav 其实是 ogg）
    public var address:String;
    public var soundKey:String;
    public var format:String;

    /** 上一次为哪个播放对象成功解码过（避免同一个 clip 反复解码）。 */
    private var cachedSound:openfl.media.Sound;

    public function new(?name:String) {
        super();
        if (name != null) this.name = name;
    }

    /**
     * C# 的 `unity.UnityObject.exists(clip)`（UnityEngine.Object 的隐式 bool 转换）→ 移植层判断是否取到了音频数据。
     * PORT-NOTE: 与 unity.UnityObject.exists(unity.UnityObject) 不同：AudioClip 的「存在」还要求能取到声音数据，
     * 否则播放会静默失败（对应 Unity 里 clip 为 null/未加载）。
     */
    public function hasAudio():Bool {
        return sound != null || flxSound != null || soundKey != null;
    }

    /**
     * 为一次播放创建独立的 FlxSound（Unity 的 AudioSource 各自持有一条播放通道，
     * 同一个 AudioClip 可以被多个 AudioSource 同时播放）。
     * PORT-NOTE: 不能直接复用 `flxSound`（那是清单解码时共享的播放对象，多个音源共用会互相打断）。
     * 返回的是 unity.PlaybackSound（FlxSound 的子类，每帧回调调用方，用于补上本机 lime 原生音频
     * 不上报播放位置而丢失的 time/播放结束/循环语义，见 unity.AudioSource 的说明）。
     * 返回的对象已 autoDestroy = false 且登记进 FlxG.sound.list（flixel 靠它每帧 update），
     * 生命周期由调用方（unity.AudioSource）负责，`onComplete` 会在播放正常结束时回调。
     */
    public function newSound(looped:Bool = false, ?onComplete:Void->Void):PlaybackSound {
        var source = getSoundData();
        if (source == null) {
            // PORT-NOTE: 具体原因由 getSoundData/loadSoundData 的告警给出，这里只标出播放侧拿不到数据。
            WarnOnce('newSound/$key', 'AudioClip「$key」取不到声音数据，无法创建播放对象。');
            return null;
        }
        var flx = new PlaybackSound();
        flx.loadEmbedded(source, looped, false, onComplete);
        flx.autoDestroy = false;
        if (!flx.exists) {
            WarnOnce('newSound-exists/$key', 'AudioClip「$key」的声音数据无法播放（loadEmbedded 后 exists=false）。');
            flx.destroy();
            return null;
        }
        if (FlxG.sound != null)
            FlxG.sound.list.add(flx);
        return flx;
    }

    /** 取（必要时解码）openfl 的声音对象；失败返回 null。 */
    public function getSoundData():openfl.media.Sound {
        if (sound != null)
            return sound;
        if (cachedSound != null)
            return cachedSound;
        if (soundKey == null) {
            WarnOnce('no-key/$key', 'AudioClip「$key」既没有解码好的 sound，也没有 soundKey，取不到音频数据。');
            return null;
        }
        cachedSound = loadSoundData();
        if (cachedSound == null) {
            WarnOnce('load-failed/$key', '音频数据加载失败：$soundKey（见 assets/audio_manifest.json）。');
            return null;
        }
        // PORT-NOTE: 兼容 unity.addressableassets.ResourceManifest 解码路径留出的字段契约
        // （`clip.sound` / `clip.flxSound`）。清单登记的 AudioClip 是延迟解码的，
        // 首次取数据时把这两个字段补上，使两种来源的 AudioClip 对外表现一致。
        sound = cachedSound;
        if (flxSound == null)
            flxSound = new FlxSound().loadEmbedded(cachedSound);
        return cachedSound;
    }

    private function loadSoundData():openfl.media.Sound {
        // 1) lime 资源库（Project.xml 的 <assets path="assets"/> 会把音频打进资源清单）。
        try {
            if (openfl.utils.Assets.exists(soundKey, openfl.utils.AssetType.SOUND)
                || openfl.utils.Assets.exists(soundKey, openfl.utils.AssetType.MUSIC)) {
                var librarySound = openfl.utils.Assets.getSound(soundKey);
                if (librarySound != null)
                    return librarySound;
            }
        } catch (e:Dynamic) {
            WarnOnce('assets-get/$key', '按 lime 资源 id 取音频失败：$soundKey（$e）');
        }
        // 2) 直接从磁盘读（与 unity.addressableassets.ResourceManifest 的路径解析一致：
        //    资源不打进 lime 资源库时以仓库/部署目录里的文件为准）。
        var bytes = readFileBytes();
        if (bytes == null)
            return null;
        var buffer:AudioBuffer = null;
        try {
            buffer = AudioBuffer.fromBytes(bytes);
        } catch (e:Dynamic) {
            WarnOnce('decode/$key', '音频解码失败：$soundKey（$e）');
            return null;
        }
        if (buffer == null) {
            WarnOnce('buffer/$key', '音频解码结果为 null（格式不支持）：$soundKey。');
            return null;
        }
        var result = Sound.fromAudioBuffer(buffer);
        if (result == null) {
            WarnOnce('from-buffer/$key', 'Sound.fromAudioBuffer 返回 null，音频无法播放：$soundKey。');
            return null;
        }
        // PORT-NOTE: 清单里没有时长/采样率信息时（例如清单缺失、clip 由别处构造），
        // 用解码结果补齐 AudioClip 的元数据，保证 MusicManager 的 clip.length 可用。
        if (length <= 0 && result != null && result.length > 0)
            length = result.length / 1000; // openfl 的 Sound.length 是毫秒，Unity 的是秒
        if (frequency <= 0 && buffer.sampleRate > 0)
            frequency = buffer.sampleRate;
        if (channels <= 0 && buffer.channels > 0)
            channels = buffer.channels;
        return result;
    }

    private function readFileBytes():Bytes {
        var path = ResourceManifest.get().resolvePath(soundKey);
        if (path == null) {
            WarnOnce('resolve/$key', '找不到音频文件：$soundKey（assets 根：${ResourceManifest.get().assetsRoots.join(", ")}）');
            return null;
        }
        try {
            return sys.io.File.getBytes(path);
        } catch (e:Dynamic) {
            WarnOnce('read/$key', '读取音频文件失败：$path（$e）');
            return null;
        }
    }

    /** 采样数（Unity 的 AudioClip.samples）；清单里没有时按 length × frequency 推算。 */
    public function getSamples():Int {
        if (samples > 0)
            return samples;
        if (length > 0 && frequency > 0)
            return Std.int(length * frequency);
        return 0;
    }

    /** 诊断用名字：优先 lime 资源路径（audio_manifest.json 的 assetPath），其次资源名。 */
    private var key(get, never):String;
    function get_key():String {
        if (soundKey != null)
            return soundKey;
        return name != null && name.length > 0 ? name : "<unnamed clip>";
    }

    /** 同一条失败原因只告警一次（播放失败会被反复重试，避免刷屏）。 */
    private static function WarnOnce(key:String, message:String):Void {
        if (warnedKeys.exists(key))
            return;
        warnedKeys.set(key, true);
        Debug.LogWarning(message);
    }
    private static var warnedKeys:Map<String, Bool> = new Map();
}

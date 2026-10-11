package mvz2.audios;

import mvz2.managers.MainManager;
import mvz2.options.OptionsManager;
import mvz2logic.options.LogicOptionItemID;
import pvzengine.NamespaceID;
import unity.AudioMixer;
import unity.AudioSource;
import unity.Debug;
import unity.MonoBehaviour;
import unity.Quaternion;
import unity.Transform;
import unity.UnityObject;
import unity.Vector3;
import Main;
import mvz2.managers.ResourceManager;

// Ported from: Assets/Scripts/MVZ2/Audios/SoundManager.cs
class SoundManager extends MonoBehaviour {
    public function SetGlobalVolume(volume:Float):Void {
        mixer.SetFloat("SoundVolume", AudioHelper.PercentageToDbA(volume));
    }
    public function IsPlaying(id:NamespaceID):Bool {
        return Lambda.exists(soundSources, s -> s.SoundID == id);
    }
    public function Play2D(id:NamespaceID, pitch:Float = 1):AudioSource {
        return Play(id, Vector3.zero, pitch, 0);
    }
    public function Play(id:NamespaceID, pos:Vector3, pitch:Float = 1, spatialBlend:Float = 1):AudioSource {
        if (id == null) {
            WarnOnce("Play/null-id", "SoundManager.Play：音效 id 为 null，已跳过播放。");
            return null;
        }
        var soundsMeta = main.ResourceManager.GetSoundMetaList(id.SpaceName);
        var meta = main.ResourceManager.GetSoundMeta(id);
        if (soundsMeta == null || meta == null) {
            WarnOnce('Play/meta/$id', 'SoundManager.Play：音效「$id」没有元数据（sounds.xml 的 sounds / ModResource.SoundMetaList 缺失）。');
            return null;
        }
        var sample = meta.GetRandomSample();
        if (sample == null) {
            WarnOnce('Play/sample/$id', 'SoundManager.Play：音效「$id」没有可用采样（sounds.xml 里的 samples 为空）。');
            return null;
        }
        var clip = main.ResourceManager.GetSoundClip(sample.path);
        if (clip == null) {
            WarnOnce('Play/clip/$id/${sample.path}', 'SoundManager.Play：音效「$id」的采样 ${sample.path} 取不到 AudioClip（ModResource.Sounds 里没有该资源）。');
            return null;
        }
        var maxCount = meta.maxCount;
        var sameSoundSources = Lambda.array(Lambda.filter(soundSources, s -> s.SoundID == id));
        if (maxCount > 0 && sameSoundSources.length >= maxCount) {
            RemoveSoundSource(sameSoundSources.length > 0 ? sameSoundSources[0] : null);
        }
        var source = UnityObject.Instantiate(soundTemplate, pos, Quaternion.identity, soundSourceRoot);
        source.Volume = 1;
        source.SoundID = id;
        source.gameObject.name = Std.string(id);

        var audioSource = source.AudioSource;
        audioSource.clip = clip;
        audioSource.pitch = pitch;
        audioSource.spatialBlend = spatialBlend;
        audioSource.priority = meta.priority;
        soundSources.push(source);
        audioSource.gameObject.SetActive(true);
        audioSource.Play();
        return audioSource;
    }
    // #region 循环音效
    public function PlayLoopSound(id:NamespaceID):Bool {
        if (id == null) {
            WarnOnce("PlayLoopSound/null-id", "SoundManager.PlayLoopSound：音效 id 为 null，已跳过播放。");
            return false;
        }
        if (IsPlayingLoopSound(id))
            return false;
        var soundsMeta = main.ResourceManager.GetSoundMetaList(id.SpaceName);
        var meta = main.ResourceManager.GetSoundMeta(id);
        if (soundsMeta == null || meta == null) {
            WarnOnce('PlayLoopSound/meta/$id', 'SoundManager.PlayLoopSound：音效「$id」没有元数据（sounds.xml 的 sounds / ModResource.SoundMetaList 缺失）。');
            return false;
        }
        var sample = meta.GetRandomSample();
        if (sample == null) {
            WarnOnce('PlayLoopSound/sample/$id', 'SoundManager.PlayLoopSound：音效「$id」没有可用采样（sounds.xml 里的 samples 为空）。');
            return false;
        }
        var clip = main.ResourceManager.GetSoundClip(sample.path);
        if (clip == null) {
            WarnOnce('PlayLoopSound/clip/$id/${sample.path}', 'SoundManager.PlayLoopSound：音效「$id」的采样 ${sample.path} 取不到 AudioClip（ModResource.Sounds 里没有该资源）。');
            return false;
        }
        var source = UnityObject.Instantiate(loopSoundTemplate, Vector3.zero, Quaternion.identity, loopSoundSourceRoot);
        source.SoundID = id;
        source.gameObject.name = Std.string(id);

        var audioSource = source.AudioSource;
        audioSource.clip = clip;
        audioSource.priority = meta.priority;
        loopSoundSources.set(id, source);
        audioSource.loop = true;
        audioSource.gameObject.SetActive(true);
        audioSource.Play();
        return true;
    }
    public function StopLoopSound(id:NamespaceID):Bool {
        if (id == null)
            return false;
        if (!IsPlayingLoopSound(id))
            return false;

        if (!loopSoundSources.exists(id))
            return false;
        var source = loopSoundSources.get(id);

        source.AudioSource.Stop();
        UnityObject.Destroy(source.gameObject);
        loopSoundSources.remove(id);
        return true;
    }
    public function StartFadeLoopSound(id:NamespaceID, target:Float, time:Float):Void {
        if (!loopSoundSources.exists(id))
            return;
        var source = loopSoundSources.get(id);
        source.StartFade(target, time);
    }
    public function StopFadeLoopSound(id:NamespaceID):Void {
        if (!loopSoundSources.exists(id))
            return;
        var source = loopSoundSources.get(id);
        source.StopFade();
    }
    public function IsPlayingLoopSound(id:NamespaceID):Bool {
        return loopSoundSources.exists(id);
    }
    public function SetLoopSoundPosition(id:NamespaceID, position:Vector3):Void {
        if (!loopSoundSources.exists(id))
            return;
        var source = loopSoundSources.get(id);
        source.transform.position = position;
    }
    public function GetLoopSoundIntensity(id:NamespaceID):Float {
        if (!loopSoundSources.exists(id))
            return -1;
        var source = loopSoundSources.get(id);
        return source.Intensity;
    }
    public function SetLoopSoundIntensity(id:NamespaceID, intensity:Float):Void {
        if (!loopSoundSources.exists(id))
            return;
        var source = loopSoundSources.get(id);
        source.Intensity = intensity;
        UpdateLoopSound(id, source, intensity);
    }
    // #endregion
    private function Awake():Void {
        // PORT-NOTE: C# 里 mixer / soundTemplate / loopSoundTemplate 由 prefab 注入，且模板的
        // AudioSource 带 OutputAudioMixerGroup=Sound 等序列化值（见 assets/audio_manifest.json 的
        // audioSourceTemplates）。prefab→场景 转换尚未完成（mvz2/states/MainGameScene.hx 只 new 出
        // 空的 AudioSource），故按清单补齐这两处；转换完成后这些值相同，重复设置无副作用。
        // 与 MusicManager.Awake 同因：mixer 为空会让 SetGlobalVolume 在读取设置音量时直接空引用；
        // 模板缺 OutputAudioMixerGroup 则声音不过 Sound 总线，SoundVolume 设置对音效不生效。
        if (mixer == null)
            mixer = AudioManifest.mainMixer;
        if (soundTemplate != null)
            AudioManifest.applyTemplate(soundTemplate.AudioSource, "soundTemplate");
        if (loopSoundTemplate != null)
            AudioManifest.applyTemplate(loopSoundTemplate.AudioSource, "loopSoundTemplate");
        OptionsManager.OnOptionChangedFloat.add(OnOptionChangedFloatCallback);
    }
    private function Update():Void {
        for (source in soundSources.copy()) {
            if (!source.AudioSource.isPlaying) {
                RemoveSoundSource(source);
            }
        }
    }
    private function OnOptionChangedFloatCallback(id:NamespaceID, value:Float):Void {
        if (id == LogicOptionItemID.soundVolume) {
            SetGlobalVolume(value);
        }
    }
    private function UpdateLoopSound(id:NamespaceID, source:SoundSource, intensity:Float):Void {
        var meta = Main.ResourceManager.GetSoundMeta(id);
        if (meta == null) {
            WarnOnce('UpdateLoopSound/meta/$id', 'SoundManager.UpdateLoopSound：音效「$id」没有元数据，循环音效的强度/音量不生效。');
            source.Volume = intensity;
            source.Pitch = 1;
            return;
        }

        var pitchStart = meta.loopPitchStart;
        var pitchEnd = meta.loopPitchEnd;
        var pitch = (pitchEnd - pitchStart) * intensity + pitchStart;
        source.Volume = intensity * meta.loopVolume;
        source.Pitch = pitch;
    }
    private function RemoveSoundSource(source:SoundSource):Void {
        soundSources.remove(source);
        UnityObject.Destroy(source.gameObject);
    }
    /** 同一条播放失败原因只告警一次（播放失败通常每帧/每次点击都会重试）。 */
    private static function WarnOnce(key:String, message:String):Void {
        if (warnedKeys.exists(key))
            return;
        warnedKeys.set(key, true);
        Debug.LogWarning(message);
    }
    private static var warnedKeys:Map<String, Bool> = new Map();
    public var Main(get, never):MainManager;
    inline function get_Main():MainManager return main;

    @:serializeField
    private var main:MainManager = null;
    @:serializeField
    private var mixer:AudioMixer = null;
    @:serializeField
    private var soundSourceRoot:Transform = null;
    @:serializeField
    private var loopSoundSourceRoot:Transform = null;
    @:serializeField
    private var soundTemplate:SoundSource = null;
    @:serializeField
    private var loopSoundTemplate:SoundSource = null;

    @:inspectorHeader("AudioClips")
    private var soundSources:Array<SoundSource> = [];
    private var loopSoundSources:Map<NamespaceID, SoundSource> = new Map();
}

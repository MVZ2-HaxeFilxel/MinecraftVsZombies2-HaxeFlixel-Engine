package mvz2.audios;

import mvz2.managers.MainManager;
import mvz2.options.OptionsManager;
import mvz2.ui.FloatFader;
import mvz2logic.games.IGlobalMusic;
import mvz2logic.options.LogicOptionItemID;
import pvzengine.NamespaceID;
import unity.AudioClip;
import unity.AudioMixer;
import unity.AudioSource;
import unity.Mathf;
import unity.MonoBehaviour;
import Main;
import mvz2.managers.ResourceManager;
import unity.Time;
import unity.UnityObject;

// Ported from: Assets/Scripts/MVZ2/Audios/MusicManager.cs
class MusicManager extends MonoBehaviour implements IGlobalMusic {
    // #region 播放
    public function Play(id:NamespaceID):Void {
        var meta = main.ResourceManager.GetMusicMeta(id);
        if (meta == null)
            return;
        var mainTrack = main.ResourceManager.GetMusicClip(meta.MainTrack);
        var subTrack = main.ResourceManager.GetMusicClip(meta.SubTrack);
        musicID = id;
        SetSourceClip(mainTrackSource, mainTrack);
        SetSourceClip(subTrackSource, subTrack);
        IsPaused = false;

        PlaySource(mainTrackSource);
        PlaySource(subTrackSource);
    }
    public function SetPlayingMusic(id:NamespaceID):Void {
        var meta = main.ResourceManager.GetMusicMeta(id);
        if (meta == null)
            return;
        var mainTrack = main.ResourceManager.GetMusicClip(meta.MainTrack);
        var subTrack = main.ResourceManager.GetMusicClip(meta.SubTrack);
        musicID = id;
        SetSourceClip(mainTrackSource, mainTrack);
        SetSourceClip(subTrackSource, subTrack);
        IsPaused = false;
        Time = 0;
    }
    private function SetSourceClip(source:AudioSource, clip:AudioClip):Void {
        // PORT-NOTE: C# `unity.UnityObject.exists(clip)` extension → null check.
        var clipValid = clip != null;
        source.clip = clip;
        source.gameObject.SetActive(clipValid);
        UpdateTrackWeight();
    }
    private function PlaySource(source:AudioSource):Void {
        // PORT-NOTE: C# `source.isActiveAndEnabled`（AudioSource : Behaviour）→ unity shim 中
        // AudioSource 同样继承 unity.Behaviour，语义一致。
        if (!source.isActiveAndEnabled)
            return;
        source.Play();
    }
    // #endregion

    // #region 暂停、还原
    public function Pause():Void {
        if (IsPaused)
            return;
        IsPaused = true;
        mainTrackSource.Pause();
        subTrackSource.Pause();
    }
    public function Resume():Void {
        if (!IsPaused) {
            mainTrackSource.Play();
            subTrackSource.Play();
            return;
        }
        IsPaused = false;
        mainTrackSource.UnPause();
        subTrackSource.UnPause();
    }
    // #endregion

    // #region 停止
    public function Stop():Void {
        IsPaused = false;
        mainTrackSource.Stop();
        subTrackSource.Stop();
        musicID = null;
    }
    // #endregion

    // #region 当前音乐
    public function GetCurrentMusicID():NamespaceID {
        return musicID;
    }
    public function IsPlaying(id:NamespaceID):Bool {
        return musicID == id;
    }
    // #endregion

    // #region 渐变
    public function StartFade(target:Float, duration:Float):Void {
        volumeFader.StartFade(target, duration);
    }
    public function StopFade():Void {
        volumeFader.StopFade();
    }
    // #endregion

    // #region 音量
    public function SetVolume(volume:Float):Void {
        volumeFader.Value = volume;
    }
    public function GetVolume():Float {
        return volumeFader.Value;
    }
    public function SetGlobalVolume(volume:Float):Void {
        mixer.SetFloat("MusicVolume", AudioHelper.PercentageToDbA(volume));
    }
    // #endregion

    // #region 副轨权重
    public function GetTrackWeight():Float {
        return trackWeight;
    }
    public function SetTrackWeight(weight:Float):Void {
        trackWeight = weight;
        UpdateTrackWeight();
    }
    private function UpdateTrackWeight():Void {
        var w = subTrackSource.isActiveAndEnabled ? trackWeight : 0;
        mixer.SetFloat("MainWeight", AudioHelper.PercentageToDbA(1 - w));
        mixer.SetFloat("SubWeight", AudioHelper.PercentageToDbA(w));
    }
    // #endregion

    // #region 时间
    public function SetNormalizedMusicTime(time:Float):Void {
        if (mainTrackSource == null || mainTrackSource.clip == null)
            return;
        Time = time * mainTrackSource.clip.length;
    }
    public function GetNormalizedMusicTime():Float {
        if (mainTrackSource == null || mainTrackSource.clip == null)
            return 0;
        return Time / mainTrackSource.clip.length;
    }
    // #endregion

    private function Awake():Void {
        // PORT-NOTE: C# 里 mainTrackSource/subTrackSource 由 prefab 提供，并且带上 Loop=1、
        // OutputAudioMixerGroup=MainTrack/SubTrack、volume=1 等序列化值（见
        // assets/audio_manifest.json 的 audioSourceTemplates）。prefab→场景 转换尚未完成
        // （见 mvz2/states/MainGameScene.hx 的 PORT-NOTE，那里只 new 出了空的 AudioSource），
        // 故在此按清单补齐这两个音轨源的配置；转换完成后这些值与之相同，重复设置无副作用。
        AudioManifest.applyTemplate(mainTrackSource, "mainTrackSource");
        AudioManifest.applyTemplate(subTrackSource, "subTrackSource");
        // PORT-NOTE: C# 的 mixer 由 prefab 注入同一个 Assets/Mixers/Main 资源；缺引用时退回工程唯一的 mixer，
        // 避免下面的 SetFloat 空引用（音量滑条失效）。
        if (mixer == null)
            mixer = AudioManifest.mainMixer;
        volumeFader.OnValueChanged.add(function(value:Float) {
            mixer.SetFloat("FadeVolume", AudioHelper.PercentageToDbA(value));
        });
        volumeFader.SetValueWithoutNotify(1);
        SetTrackWeight(0);

        OptionsManager.OnOptionChangedFloat.add(OnOptionChangedFloatCallback);
    }
    private function Update():Void {
        if (subTrackSource.isActiveAndEnabled && Mathf.Abs(subTrackSource.timeSamples - mainTrackSource.timeSamples) >= 1000) {
            subTrackSource.timeSamples = mainTrackSource.timeSamples;
        }
    }
    private function OnOptionChangedFloatCallback(id:NamespaceID, value:Float):Void {
        if (id == LogicOptionItemID.musicVolume) {
            SetGlobalVolume(value);
        }
    }
    public var Main(get, never):MainManager;
    inline function get_Main():MainManager return main;

    public var Time(get, set):Float;
    function get_Time():Float return mainTrackSource.time;
    function set_Time(value:Float):Float {
        if (mainTrackSource.clip == null)
            return value;
        var v = Mathf.Min(mainTrackSource.clip.length - 0.001, value);
        mainTrackSource.time = v;
        subTrackSource.time = v;
        return value;
    }
    public var IsPaused(default, null):Bool;
    private var musicID:NamespaceID;
    private var trackWeight:Float;
    private var lowQuality:Bool;
    @:serializeField
    private var main:MainManager = null;
    @:serializeField
    private var mixer:AudioMixer = null;
    @:serializeField
    private var mainTrackSource:AudioSource = null;
    @:serializeField
    private var subTrackSource:AudioSource = null;
    @:serializeField
    private var volumeFader:FloatFader = null;
}

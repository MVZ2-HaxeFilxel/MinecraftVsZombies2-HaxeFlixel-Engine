package unity.ui;

import unity.events.UnityEvent1;
import unity.eventsystems.PointerEventData;

// Minimal UnityEngine.UI.Toggle shim.
class Toggle extends Selectable {
    public var onValueChanged:ToggleEvent = new ToggleEvent();
    public var graphic:Graphic;
    public var toggleTransition:ToggleTransition = ToggleTransition.Fade;
    public var isOn(get, set):Bool;
    function get_isOn():Bool return m_IsOn;
    function set_isOn(v:Bool):Bool {
        Set(v);
        return v;
    }
    public var group:Dynamic;

    private var m_IsOn:Bool = true;

    public function new() {
        super();
    }

    // C# (Toggle.OnEnable): 进入场景时按 m_IsOn 刷一次勾图显隐 —— isOn 的 setter 只在值真的变化时
    // 才 PlayEffect，prefab 里 isOn 与声明初值相同时不会触发，所以这一步不能省。
    override public function Awake():Void {
        super.Awake();
        ApplyToggleEffect();
    }

    public function SetIsOnWithoutNotify(value:Bool):Void {
        Set(value, false);
    }
    private function Set(value:Bool, ?sendCallback:Bool = true):Void {
        if (m_IsOn == value) return;
        m_IsOn = value;
        PlayEffect(toggleTransition == ToggleTransition.None);
        if (sendCallback) onValueChanged.Invoke(m_IsOn);
    }
    // C# (Toggle.PlayEffect): `graphic.CrossFadeAlpha(isOn ? 1 : 0, ...)`，即勾图按 isOn 显隐。
    // PORT-NOTE: 移植层没有独立的渐变量（UiRenderer 直接读 Graphic 的 color/enabled），落到等价字段
    // enabled 上：`s.visible = graphic.enabled && alpha > 0.001`（见 UiRenderer.updateGraphic）。
    // instant 只影响 Unity 的渐变时长，移植层忽略。
    private function PlayEffect(instant:Bool):Void {
        if (graphic == null) return;
        graphic.enabled = m_IsOn;
    }

    /** 按当前 isOn 刷一次勾图显隐（移植层新增：克隆体不会被派发 Awake，调用方需显式刷）。 */
    public function ApplyToggleEffect():Void {
        PlayEffect(toggleTransition == ToggleTransition.None);
    }
    public function OnPointerClick(eventData:PointerEventData):Void {
        if (!IsInteractable()) return;
        Set(!m_IsOn);
    }
    override public function OnPointerDown(eventData:PointerEventData):Void {
        super.OnPointerDown(eventData);
    }
}

// Minimal UnityEngine.UI.Toggle.ToggleTransition shim.
enum abstract ToggleTransition(Int) {
    var None = 0;
    var Fade = 1;
}

// Minimal UnityEngine.UI.Toggle.ToggleEvent shim.
class ToggleEvent extends UnityEvent1<Bool> {
    public function new() {
        super();
    }
}

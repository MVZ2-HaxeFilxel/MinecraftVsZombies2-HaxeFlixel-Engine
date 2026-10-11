package unity.ui;

import unity.Color;
import unity.eventsystems.AxisEventData;
import unity.eventsystems.BaseEventData;
import unity.eventsystems.PointerEventData;

// Minimal UnityEngine.UI.Selectable shim.
class Selectable extends UIBehaviour {
    public static var allSelectablesArray:Array<Selectable> = [];

    public var navigation:Navigation = new Navigation();
    public var transition:Transition = Transition.ColorTint;
    public var colors:ColorBlock = new ColorBlock();
    public var spriteState:SpriteState = new SpriteState();
    public var animationTriggers:Dynamic;
    public var targetGraphic:Graphic;
    public var interactable:Bool = true;
    public var image(get, set):Graphic;
    function get_image():Graphic return targetGraphic;
    function set_image(v:Graphic):Graphic {
        targetGraphic = v;
        return v;
    }
    public var animator:Dynamic;
    // PORT-NOTE: `enabled` 继承自 unity.MonoBehaviour，Haxe 不允许子类重定义变量。

    // PORT-NOTE: 指针状态（移植层新增）。uGUI 里 `IsHighlighted()` / `IsPressed()` 由 EventSystem 维护；
    // 移植层的悬停/按下由 mvz2.ui.UiRenderer 逐节点派发 OnPointerEnter/Exit/Down/Up（见 processPointer），
    // 这里按同一语义记录，供 DoStateTransition 求状态。
    private var m_IsHovered:Bool = false;
    private var m_IsPressed:Bool = false;
    // PORT-NOTE: ColorTint 的原色基线与它所属的 targetGraphic（见 baseColor）。
    private var m_BaseColor:Color;
    private var m_BaseColorTarget:Graphic;

    public function new() {
        super();
    }

    // C# (Selectable.OnEnable): 进入场景时按当前状态刷一次颜色 —— ColorTint 下这一步决定控件的常态外观
    //（例如列表条目 Item/Background 就是靠 normalColor 的 alpha=0 把自己隐藏起来的）。
    // PORT-NOTE: 移植层没有 OnEnable 派发路径（ScenePrefabLoader 派发的是 Awake），故挂在 Awake 上；
    // 两者都在「组件序列化字段全部写完」之后执行，时序等价。
    override public function Awake():Void {
        super.Awake();
        ApplySelectionState();
    }

    public function IsInteractable():Bool return interactable && enabled;
    public function IsHighlighted():Bool return m_IsHovered;
    public function IsPressed():Bool return m_IsPressed;
    public function FindSelectable(direction:unity.Vector3):Selectable return null;
    public function Select():Void {}
    public function OnMove(eventData:AxisEventData):Void {}
    public function OnPointerDown(eventData:PointerEventData):Void {
        m_IsPressed = true;
        ApplySelectionState();
    }
    public function OnPointerUp(eventData:PointerEventData):Void {
        m_IsPressed = false;
        ApplySelectionState();
    }
    public function OnPointerEnter(eventData:PointerEventData):Void {
        m_IsHovered = true;
        ApplySelectionState();
    }
    public function OnPointerExit(eventData:PointerEventData):Void {
        m_IsHovered = false;
        ApplySelectionState();
    }
    public function OnSelect(eventData:BaseEventData):Void {}
    public function OnDeselect(eventData:BaseEventData):Void {}
    public function Select_Internal():Void {}
    public function InstantClearState():Void {}

    // C# (Selectable.DoStateTransition): ColorTint 下把状态色应用到 targetGraphic。
    // PORT-NOTE: SpriteSwap / Animation 在移植层没有对应机制（没有 Animator 状态机），保持 prefab 里
    // 序列化的精灵与颜色不动 —— Unity 也是「按 transition 类型只走一条分支」。
    // instant 在 Unity 里只用于跳过渐变时长；移植层的 Graphic.CrossFadeColor 本来就是立即落色。
    public function DoStateTransition(state:SelectionState, instant:Bool):Void {
        if (transition != Transition.ColorTint || targetGraphic == null || colors == null)
            return;
        var source:Color = colors.normalColor;
        if (source == null) return;
        // 某项没配（null）时回落常态色，避免直接读字段空引用。
        if (state == SelectionState.Highlighted && colors.highlightedColor != null) source = colors.highlightedColor;
        else if (state == SelectionState.Pressed && colors.pressedColor != null) source = colors.pressedColor;
        else if (state == SelectionState.Selected && colors.selectedColor != null) source = colors.selectedColor;
        else if (state == SelectionState.Disabled && colors.disabledColor != null) source = colors.disabledColor;
        // C#: tintColor *= m_Colors.colorMultiplier；Unity 由 CanvasRenderer 把结果钳到 [0,1]。
        var m = colors.colorMultiplier;
        var tint = new Color(clamp01(source.r * m), clamp01(source.g * m),
            clamp01(source.b * m), clamp01(source.a * m));
        // 状态色是**乘**在 Graphic 自身颜色上的（见 baseColor 的说明）。
        var base = baseColor();
        targetGraphic.CrossFadeColor(new Color(clamp01(base.r * tint.r), clamp01(base.g * tint.g),
            clamp01(base.b * tint.b), clamp01(base.a * tint.a)), colors.fadeDuration, true, true);
    }

    /**
     * 「原色」基线：Unity 的 ColorTint 是**乘**在 Graphic 自身颜色上的 —— Selectable.StartColorTween 调
     * `Graphic.CrossFadeColor`，而 Unity 的 CrossFadeColor 改的是 CanvasRenderer 的颜色，最终渲染为
     * `Graphic.color × CanvasRenderer 颜色`。这正是 prefab 里可以给某个 Graphic 单独染色、再用
     * normalColor=白 保持原色的原因（如 Dropdown/Arrow 的琥珀色箭头、Scrollbar 半透明的 Handle）。
     *
     * PORT-NOTE: 移植层没有 CanvasRenderer 颜色通道（mvz2.ui.UiRenderer 只读 Graphic.color），因此把
     * 乘积写回 color 字段；基线在首次应用状态时从当前颜色取一次（此时读到的就是 prefab 原色，序列化
     * 字段先于 Awake 写入），targetGraphic 被换掉时重取。
     */
    private function baseColor():Color {
        if (m_BaseColor == null || m_BaseColorTarget != targetGraphic) {
            var current = targetGraphic.color;
            if (current == null) current = new Color(1, 1, 1, 1);
            m_BaseColor = new Color(current.r, current.g, current.b, current.a);
            m_BaseColorTarget = targetGraphic;
        }
        return m_BaseColor;
    }

    /** 当前应显示的状态（求值顺序与 uGUI 一致：不可交互 > 按下 > 高亮 > 常态）。 */
    public function GetSelectionState():SelectionState {
        if (!IsInteractable()) return SelectionState.Disabled;
        if (m_IsPressed) return SelectionState.Pressed;
        if (m_IsHovered) return SelectionState.Highlighted;
        return SelectionState.Normal;
    }

    /**
     * 按当前状态重新着色。
     *
     * PORT-NOTE: 移植层新增（C# 的等价路径是 OnEnable 与 EventSystem 的状态回调）。供拿不到事件流的
     * 调用方显式刷一次：`UnityObject.Instantiate` 不复制 ColorBlock / Color（二者都不是 UnityObject，
     * 见 UnityObject.copySerializedFields），克隆出来的 Selectable 颜色表与 targetGraphic 颜色会退回
     * 声明初值，而且克隆体不会被派发 Awake —— TMP_Dropdown 克隆出的列表项正属于这一类。
     */
    public function ApplySelectionState():Void {
        DoStateTransition(GetSelectionState(), true);
    }

    private static function clamp01(v:Float):Float {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
    public function Rebuild(update:CanvasUpdate):Void {}
    public function LayoutComplete():Void {}
    public function GraphicUpdateComplete():Void {}
}

// Minimal UnityEngine.UI.Selectable.Transition shim.
enum abstract Transition(Int) {
    var None = 0;
    var ColorTint = 1;
    var SpriteSwap = 2;
    var Animation = 3;
}

// Minimal UnityEngine.UI.Selectable.SelectionState shim.
enum abstract SelectionState(Int) {
    var Normal = 0;
    var Highlighted = 1;
    var Pressed = 2;
    var Selected = 3;
    var Disabled = 4;
}

// Minimal UnityEngine.UI.ColorBlock shim.
class ColorBlock {
    public var normalColor:Color = new Color(1, 1, 1, 1);
    public var highlightedColor:Color = new Color(245 / 255, 245 / 255, 245 / 255, 1);
    public var pressedColor:Color = new Color(200 / 255, 200 / 255, 200 / 255, 1);
    public var selectedColor:Color = new Color(245 / 255, 245 / 255, 245 / 255, 1);
    public var disabledColor:Color = new Color(200 / 255, 200 / 255, 200 / 255, 128 / 255);
    public var colorMultiplier:Float = 1;
    public var fadeDuration:Float = 0.1;

    public function new() {}
}

// Minimal UnityEngine.UI.SpriteState shim.
class SpriteState {
    public var highlightedSprite:unity.Sprite;
    public var pressedSprite:unity.Sprite;
    public var selectedSprite:unity.Sprite;
    public var disabledSprite:unity.Sprite;

    public function new() {}
}

// Minimal UnityEngine.UI.Navigation shim.
class Navigation {
    public var mode:NavigationMode = NavigationMode.Automatic;
    public var selectOnUp:Dynamic;
    public var selectOnDown:Dynamic;
    public var selectOnLeft:Dynamic;
    public var selectOnRight:Dynamic;

    public function new() {}

    public static var defaultNavigation(get, never):Navigation;
    static function get_defaultNavigation():Navigation return new Navigation();
}

// Minimal UnityEngine.UI.Navigation.Mode shim.
enum abstract NavigationMode(Int) {
    var None = 0;
    var Horizontal = 1;
    var Vertical = 2;
    var Automatic = 3;
    var Explicit = 4;
}

// Minimal UnityEngine.UI.CanvasUpdate shim.
enum abstract CanvasUpdate(Int) {
    var Prelayout = 0;
    var Layout = 1;
    var PostLayout = 2;
    var PreRender = 3;
    var LatePreRender = 4;
    var MaxUpdateValue = 5;
}

// Minimal UnityEngine.UI.ICanvasElement shim.
interface ICanvasElement {
    function Rebuild(executing:CanvasUpdate):Void;
    function LayoutComplete():Void;
    function GraphicUpdateComplete():Void;
    function IsDestroyed():Bool;
    function get_transform():unity.Transform;
}

// Minimal UnityEngine.UI.ILayoutElement shim.
interface ILayoutElement {
    function CalculateLayoutInputHorizontal():Void;
    function CalculateLayoutInputVertical():Void;
    var minWidth(get, never):Float;
    var preferredWidth(get, never):Float;
    var flexibleWidth(get, never):Float;
    var minHeight(get, never):Float;
    var preferredHeight(get, never):Float;
    var flexibleHeight(get, never):Float;
    var layoutPriority(get, never):Int;
}

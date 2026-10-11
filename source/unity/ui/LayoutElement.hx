package unity.ui;

import unity.RectTransform;
import unity.Transform;
import unity.Vector2;

// Minimal UnityEngine.UI.LayoutElement shim.
//
// PORT-NOTE: 对应 Unity 的 ILayoutElement + ILayoutIgnorer，本 shim 已经足够 —— Unity 侧的
// minWidth/preferredWidth/…/layoutPriority 就是这几个 [SerializeField] 字段的直读，
// 负值表示「这一项不参与」。真正消费它们的是 LayoutRebuilder.LayoutUtility（见 LayoutRebuilder.hx）。
class LayoutElement extends UIBehaviour {
    public var ignoreLayout:Bool = false;
    public var minWidth:Float = -1;
    public var minHeight:Float = -1;
    public var preferredWidth:Float = -1;
    public var preferredHeight:Float = -1;
    public var flexibleWidth:Float = -1;
    public var flexibleHeight:Float = -1;
    public var layoutPriority:Int = 1;

    public function new() {
        super();
    }
    public function CalculateLayoutInputHorizontal():Void {}
    public function CalculateLayoutInputVertical():Void {}
    public function SetProperty(property:Dynamic, value:Float):Void {}
    public function GetProperty(property:Dynamic):Float return -1;
}

// Minimal UnityEngine.UI.LayoutGroup shim.
//
// PORT-NOTE: 除数据字段外，本类还承担 Unity 的 ILayoutElement / ILayoutGroup 职责：
//   * `CalculateLayoutInputHorizontal` 重建参与布局的子节点表（Unity 的 LayoutGroup 就是这么做的），
//     并作为子类的 super 调用点；
//   * min/preferred/flexible 六个属性返回**子类算出来的汇总值**（Unity 的 m_Total*Size）；
//   * `getStartOffset` / `setChildAlongAxis` 等是子类（Horizontal/Vertical/Grid）共用的几何工具。
// 调度（谁在什么时候被调用）在 unity/ui/LayoutRebuilder.hx 里，算法本体在
// unity/ui/HorizontalOrVerticalLayoutGroup.hx 里。
class LayoutGroup extends UIBehaviour {
    public var padding:RectOffset = new RectOffset();
    public var childAlignment:unity.TextAnchor = unity.TextAnchor.UpperLeft;
    public var rectTransform(get, never):unity.RectTransform;
    function get_rectTransform():unity.RectTransform {
        // PORT-NOTE: 检查型向上转型（isInstanceOf 避免 hxcpp 的 Std.isOfType 多类同模块陷阱）。
        // 本字段是给外部 Unity 兼容调用点用的；布局算法内部只走 transform/字段上移后的 Transform。
        if (Std.isOfType(transform, unity.RectTransform))
            return cast transform;
        return null;
    }
    public var layoutPriority(get, never):Int;
    function get_layoutPriority():Int return 0;

    /**
     * 参与布局的子节点（激活、且未被 ignoreLayout 排除），顺序 = 层级顺序。
     *
     * PORT-NOTE: Unity 里是 `protected List<RectTransform>`；Haxe 的 private 不跨类（子类在
     * 另一个模块里），故为 public。每次 CalculateLayoutInputHorizontal 重建一份。
     * 类型为 Transform 而非 RectTransform：本工程布局组的子节点可能是普通 Transform
     * （UiRenderer 对这类节点做「帧透传」），下转型在 hxcpp 上会把指针缩成 null
     * （见 LayoutRebuilder.rebuild 的 PORT-NOTE），随后一访问就崩。
     */
    public var rectChildren:Array<Transform> = [];

    // Unity 的 m_TotalMinSize / m_TotalPreferredSize / m_TotalFlexibleSize（两轴各三个）。
    private var totalMinWidth:Float = 0;
    private var totalMinHeight:Float = 0;
    private var totalPreferredWidth:Float = 0;
    private var totalPreferredHeight:Float = 0;
    private var totalFlexibleWidth:Float = 0;
    private var totalFlexibleHeight:Float = 0;

    public function new() {
        super();
    }

    /**
     * Unity: `LayoutGroup.CalculateLayoutInputHorizontal`（重建子节点表）。
     * 子类的 override 里必须先调 super 再算自己的汇总值。
     */
    public function CalculateLayoutInputHorizontal():Void {
        rectChildren = [];
        if (transform == null)
            return;
        for (child in transform.children) {
            if (child == null || child.gameObject == null)
                continue;
            // Unity 只把「激活」且「不被 ILayoutIgnorer 排除」的子节点算进布局。
            if (!child.gameObject.activeInHierarchy)
                continue;
            if (LayoutRebuilder.isLayoutIgnored(child.gameObject))
                continue;
            // PORT-NOTE: 直接收 Transform（不再下转型 RectTransform）：本工程容器节点可能是
            // 普通 Transform，hxcpp 的 cast 会把它缩成 null（见 LayoutRebuilder.rebuild 注释），
            // 后续任何字段访问都会解引用崩溃。锚点/尺寸字段已上移到 Transform，算法不需要
            // RectTransform 专属 API。
            rectChildren.push(child);
        }
    }

    public function CalculateLayoutInputVertical():Void {}

    /** Unity: 布局组自身的 min/preferred/flexible = 子级汇总值（由子类的 CalcAlongAxis 写入）。 */
    public var minWidth(get, never):Float;
    function get_minWidth():Float return getTotalMinSize(0);
    public var preferredWidth(get, never):Float;
    function get_preferredWidth():Float return getTotalPreferredSize(0);
    public var flexibleWidth(get, never):Float;
    function get_flexibleWidth():Float return getTotalFlexibleSize(0);
    public var minHeight(get, never):Float;
    function get_minHeight():Float return getTotalMinSize(1);
    public var preferredHeight(get, never):Float;
    function get_preferredHeight():Float return getTotalPreferredSize(1);
    public var flexibleHeight(get, never):Float;
    function get_flexibleHeight():Float return getTotalFlexibleSize(1);

    /** ILayoutController.SetLayoutHorizontal（基类不做任何事，子类 override）。 */
    public function SetLayoutHorizontal():Void {}
    /** ILayoutController.SetLayoutVertical（基类不做任何事，子类 override）。 */
    public function SetLayoutVertical():Void {}
    public function CalculateLayoutInputHorizontalInternal():Void {}
    public function CalculateLayoutInputVerticalInternal():Void {}

    /**
     * 本组**已解析**的 rect 尺寸。
     *
     * PORT-NOTE: Unity 这里是 `rectTransform.rect.size[axis]`，但 shim 的 `RectTransform.rect`
     * 忽略锚点拉伸（本工程布局组节点大量是拉伸锚点），故改走 LayoutRebuilder 的解析链。
     */
    public function getResolvedSize(axis:Int):Float return LayoutRebuilder.axisSizeOf(transform, axis);

    public function getTotalMinSize(axis:Int):Float return axis == 0 ? totalMinWidth : totalMinHeight;
    public function getTotalPreferredSize(axis:Int):Float return axis == 0 ? totalPreferredWidth : totalPreferredHeight;
    public function getTotalFlexibleSize(axis:Int):Float return axis == 0 ? totalFlexibleWidth : totalFlexibleHeight;

    /** Unity: SetLayoutInputForAxis(totalMin, totalPreferred, totalFlexible, axis)。 */
    public function setLayoutInputForAxis(totalMin:Float, totalPreferred:Float, totalFlexible:Float, axis:Int):Void {
        if (axis == 0) {
            totalMinWidth = totalMin;
            totalPreferredWidth = totalPreferred;
            totalFlexibleWidth = totalFlexible;
        } else {
            totalMinHeight = totalMin;
            totalPreferredHeight = totalPreferred;
            totalFlexibleHeight = totalFlexible;
        }
    }

    /**
     * Unity: GetStartOffset(axis, requiredSpaceWithoutPadding) —— 第一个子节点在 axis 上的位置
     * （x 从左边缘、y 从**上**边缘算，与 setChildAlongAxis 的约定一致）。
     */
    public function getStartOffset(axis:Int, requiredSpaceWithoutPadding:Float):Float {
        var requiredSpace = requiredSpaceWithoutPadding + (axis == 0 ? padding.horizontal : padding.vertical);
        var surplusSpace = getResolvedSize(axis) - requiredSpace;
        return (axis == 0 ? padding.left : padding.top) + surplusSpace * getAlignmentOnAxis(axis);
    }

    /** Unity: GetAlignmentOnAxis —— childAlignment 在该轴上的对齐比例（0=左/上，1=右/下）。 */
    public function getAlignmentOnAxis(axis:Int):Float {
        // PORT-NOTE: `(cast e:T)` 是移植层既有的 enum abstract -> 底层 Int 的写法（见 UiRenderer
        // 的 TMP 对齐换算）；unity.TextAnchor 与 GridLayoutGroup.Corner 都是 Int 枚举。
        var alignment:Int = (cast childAlignment:Int);
        return axis == 0 ? (alignment % 3) * 0.5 : Std.int(alignment / 3) * 0.5;
    }

    /**
     * Unity: SetChildAlongAxis —— 把子节点放在 axis 的 pos 处（pos 从左边缘/上边缘量起），
     * 并在给定 size 时同时设定尺寸（size=null 表示只定位、尺寸由子节点自己决定）。
     *
     * PORT-NOTE: Unity 的两个重载（带/不带 size）在 Haxe 里合并为一个可选参数版本。
     * 锚点会被改写成左上角 (0,1)/(0,1)（Unity 同样如此），因此 `UiRenderer.childFrame` 解析出的
     * 就是「距左/上边缘 pos、尺寸 size」的矩形；y 方向的负号来自 childFrame 的 y 轴向上约定。
     * 形参用 `Transform`：本工程的布局子节点可能是普通 Transform，锚点/尺寸字段已上移到
     * Transform（见 Transform.hx 的防堆损坏 PORT-NOTE），不需要 RectTransform 专属 API；
     * 用 RectTransform 会让 hxcpp 的 cast 把普通 Transform 缩成 null，一访问就崩。
     */
    public function setChildAlongAxis(rect:Transform, axis:Int, pos:Float, ?size:Null<Float> = null,
            scaleFactor:Float = 1):Void {
        if (rect == null)
            return;
        rect.anchorMin = new Vector2(0, 1);
        rect.anchorMax = new Vector2(0, 1);
        var sd = rect.sizeDelta;
        if (size != null)
            sd = axis == 0 ? new Vector2(size, sd.y) : new Vector2(sd.x, size);
        rect.sizeDelta = sd;
        var sizeOnAxis = axis == 0 ? sd.x : sd.y;
        var anchoredPosition = rect.anchoredPosition;
        // Unity: x: pos + size * pivot.x；y: -pos - size * (1 - pivot.y)（相对锚点 (0,1)）。
        var value = axis == 0
            ? pos + sizeOnAxis * rect.pivot.x * scaleFactor
            : -pos - sizeOnAxis * (1 - rect.pivot.y) * scaleFactor;
        rect.anchoredPosition = axis == 0
            ? new Vector2(value, anchoredPosition.y)
            : new Vector2(anchoredPosition.x, value);
    }
}

// Minimal UnityEngine.RectOffset shim.
class RectOffset {
    public var left:Int = 0;
    public var right:Int = 0;
    public var top:Int = 0;
    public var bottom:Int = 0;

    public function new(?left:Int = 0, ?right:Int = 0, ?top:Int = 0, ?bottom:Int = 0) {
        this.left = left;
        this.right = right;
        this.top = top;
        this.bottom = bottom;
    }
    public var horizontal(get, never):Int;
    function get_horizontal():Int return left + right;
    public var vertical(get, never):Int;
    function get_vertical():Int return top + bottom;
}

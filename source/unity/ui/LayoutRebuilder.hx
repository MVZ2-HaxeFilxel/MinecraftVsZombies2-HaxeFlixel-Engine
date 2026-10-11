package unity.ui;

import flixel.FlxG;
import unity.Behaviour;
import unity.Canvas;
import unity.Canvas.RenderMode;
import unity.Component;
import unity.Debug;
import unity.GameObject;
import unity.MonoBehaviour;
import unity.RectTransform;
import unity.Transform;
import unity.Vector2;
import unity.ui.CanvasScaler;
import unity.ui.CanvasScaler.ScaleMode;
import unity.ui.CanvasScaler.ScreenMatchMode;
import unity.ui.HorizontalOrVerticalLayoutGroup.ContentSizeFitter;
import unity.ui.LayoutElement;
import unity.ui.LayoutElement.LayoutGroup;
import unity.tmpro.TMP_Text;
import unity.tmpro.TextMeshPro;
import unity.tmpro.TextMeshProUGUI;

// PORT-NOTE: 移植层新增（无 C# 对应源码）：**uGUI 自动布局引擎**。
//
// 问题：`mvz2.ui.UiRenderer` 直接拿 `RectTransform` 序列化的 anchoredPosition/sizeDelta 画 UI，
// 而受 LayoutGroup / ContentSizeFitter / LayoutElement 控制的节点这些值在 Unity 里是**运行期算出来的**
// （prefab 里的序列化值常为 0）——于是选项对话框的内容、图鉴/存档页骨架全塌成 0×0，
// 列表克隆条目全叠在模板位置上。本文件把这些值真正算出来并写回 RectTransform，渲染器下一帧即生效。
//
// 与 Unity 的对应关系（算法本体都在同名 shim 里，本类只负责遍历/取值/调度/几何）：
//   * `LayoutRebuilder.Rebuild` 的四阶段：算水平输入（子→父）→ 应用水平（父→子）→
//     算垂直输入 → 应用垂直。见 `rebuildImmediate`。
//   * `LayoutUtility`（本文件）/ `LayoutGroup`（LayoutElement.hx）/ `HorizontalOrVerticalLayoutGroup`
//     （含 Grid/ContentSizeFitter，HorizontalOrVerticalLayoutGroup.hx）分别承担 Unity 里同名类的职责。
//
// 几何（关键，别按 shim 的 `RectTransform.rect` 走）：shim 的 `RectTransform.rect` 忽略锚点拉伸，
// 而本工程大量布局组节点的锚点是拉伸的（如 OptionsDialog 的 MainElements：anchorMin=(0,0)、
// anchorMax=(1,1)、sizeDelta=(-20,-70)）。因此这里按 `UiRenderer.childFrame` 的同一约定
// （unity/Transform.hx 的锚点/尺寸字段 + 「父级 rect 尺寸 + anchoredPosition」）自己解析，
// 见 `sizeOf`/`parentSizeOf`；布局组写回子节点时用 Unity 的 `SetChildAlongAxis`
// （锚点设为左上角），与本工程渲染器的解析链一致。
//
// 与 Unity 的已知差异（都写在报告里）：
//   * 每次都从给定根做**全量**重建，不像 Unity 那样按 layout root 剪枝 —— 否则「本身没有
//     布局控制器的父节点」下面的嵌套布局组永远不会被算到；
//   * 非 RectTransform 节点按 UiRenderer 的「帧透传」语义处理（Unity 会跳过整棵子树）；
//   * 外部 ILayoutElement 实现（如 `mvz2.ui.LayoutSizeLimiter`）默认不参与，需注册
//     `layoutElementResolver`（原因见该字段注释）；
//   * AspectRatioFitter 不参与尺寸解析（渲染器只按它改绘制帧，不回写 RectTransform）。
class LayoutRebuilder {
    /**
     * 屏幕逻辑尺寸的来源（缺省读 `FlxG.width/height`）。
     *
     * PORT-NOTE: 只有「画布根」与「无 Canvas 的顶层节点」需要它（见 sizeOf），
     * 与 `mvz2.ui.UiRenderer.screenFrame` 用的是同一个量；留这个钩子是为了让冒烟测试
     * 能在没有 FlxG 的情况下注入尺寸。
     */
    public static var screenSizeProvider:Void->Vector2 = null;

    /**
     * 外部 ILayoutElement 实现的取值回调：(组件, 轴 0/1, 种类 0=min 1=preferred 2=flexible) -> 值；
     * 返回 <0 表示该元素不参与（Unity 的负值约定）。缺省 null = 这类元素完全不影响布局。
     *
     * PORT-NOTE: 移植层做不了 `GetComponents(typeof(ILayoutElement))` 这种接口查询
     * （hxcpp 上 `Std.isOfType(x, 接口)` 不可靠，同 `ScenePrefabFieldApplier` 的 PORT-NOTE），
     * 也**不主动**调用未知元素的 `CalculateLayoutInput*`：这类自缩放实现往往依赖被桩掉的
     * `LayoutUtility`（如 `mvz2.ui.LayoutSizeLimiter` 内部算出来恒为 0），驱动它反而会把节点
     * 塌成 0。需要这些元素时由集成方注册本回调，回调内部可自行驱动它们的 Calculate*。
     * 参与进来的元素按 `LayoutUtility.EXTERNAL_PRIORITY`（100）参与优先级比较。
     */
    public static var layoutElementResolver:Component->Int->Int->Float = null;

    // #region 公共入口

    /**
     * 对 root 的整棵子树重算自动布局（每帧调用即可；节点数百，全量重建足够快）。
     *
     * 只有「子树里存在布局组/ContentSizeFitter」的节点会被写回 RectTransform，其余节点的
     * anchoredPosition/sizeDelta 一个字节都不会动。
     */
    public static function rebuild(root:GameObject):Void {
        if (root == null)
            return;
        // PORT-NOTE: 不用 `cast` 缩窄到 RectTransform——hxcpp 里 Transform→RectTransform 的
        // 指针调整在对象不是 RectTransform 时会产生错误的空值（根通常只是普通 Transform）。
        // 锚点/尺寸字段都已上移到 Transform（见 Transform.hx 的防堆损坏 PORT-NOTE），
        // 直接用 Transform 语义完全等价。
        var rt:Transform = root.transform;
        rebuildImmediate(rt);
    }

    /** 同 rebuild，但以 Transform 指定根（Unity `ForceRebuildLayoutImmediate` 的语义）。 */
    public static function rebuildImmediate(rt:Transform):Void {
        if (rt == null || rt.gameObject == null || !rt.gameObject.activeInHierarchy)
            return;
        calculateLayoutInputs(rt, 0, 0);
        applyLayoutControl(rt, 0, 0);
        calculateLayoutInputs(rt, 1, 0);
        applyLayoutControl(rt, 1, 0);
    }

    /**
     * Unity 的延迟标记入口。
     *
     * PORT-NOTE: 移植层是「每帧全量重建」，标记本身没有意义；这里只保留 API 形状，
     * 避免 `LayoutSizeLimiter.SetDirty` 之类的调用点因为缺方法而编译不过。
     */
    public static function markLayoutForRebuild(rt:RectTransform):Void {}

    /** Unity `LayoutRebuilder.ForceRebuildLayoutImmediate` 的同名兼容入口。 */
    public static function ForceRebuildLayoutImmediate(layoutRoot:RectTransform):Void {
        rebuildImmediate(layoutRoot);
    }

    /** Unity `LayoutRebuilder.MarkLayoutForRebuild` 的同名兼容入口（语义同 markLayoutForRebuild）。 */
    public static function MarkLayoutForRebuild(rect:RectTransform):Void {}

    // #endregion

    // #region 几何解析

    /** 节点**已解析**的 rect 尺寸（画布单位），与 `UiRenderer.childFrame` 的解析链一致。 */
    public static function sizeOf(tr:Transform):Vector2 return sizeOfDepth(tr, 0);

    /** 已解析 rect 在 axis（0=宽 1=高）上的尺寸。 */
    public static function axisSizeOf(tr:Transform, axis:Int):Float {
        var size = sizeOf(tr);
        return axis == 0 ? size.x : size.y;
    }

    /** 锚点参考矩形尺寸（= 最近 RectTransform 祖先的已解析尺寸），供 sizeDelta 换算使用。 */
    public static function parentSizeOf(tr:Transform):Vector2 return ancestorSizeOf(tr, 0);

    /** 向上找锚点参考矩形（非 RectTransform 父级按 UiRenderer 的「帧透传」语义跳过）。 */
    private static function ancestorSizeOf(tr:Transform, depth:Int):Vector2 {
        if (tr == null || depth > 64)
            return new Vector2(0, 0);
        var parent:Transform = tr.parent;
        // PORT-NOTE: 父链必须**有界**：SetParent 不拒绝成环（Transform.hx 的 SetParent 只维护
        // 双向引用），一旦父链成环，无界 while 会把整帧挂死。64 步已超过本工程的层级深度。
        // 语义保持「向上找最近的 RectTransform 祖先」不变。
        var guard = 0;
        while (parent != null && guard++ < 64) {
            if (Std.isOfType(parent, RectTransform))
                break;
            parent = parent.parent;
        }
        if (parent == null)
            return screenSizeOn(nearestAncestorScaleFactor(tr));
        return sizeOfDepth(parent, depth + 1);
    }

    /**
     * Unity `RectTransform.SetSizeWithCurrentAnchors(axis, size)`：让**解析后的尺寸**等于 size。
     *
     * PORT-NOTE: shim 的 `RectTransform.SetSizeWithCurrentAnchors` 直接把 sizeDelta 设成 size，
     * 只对「锚点不拉伸」的节点成立；布局引擎在锚点拉伸时必须减去锚点跨度
     * （`sizeDelta = size - (anchorMax-anchorMin) * 父级尺寸`），否则 ContentSizeFitter 会算错。
     */
    public static function setSizeWithCurrentAnchors(tr:Transform, axis:Int, size:Float):Void {
        if (tr == null)
            return;
        var parentSize = parentSizeOf(tr);
        var span = axis == 0 ? (tr.anchorMax.x - tr.anchorMin.x) : (tr.anchorMax.y - tr.anchorMin.y);
        var parentLength = axis == 0 ? parentSize.x : parentSize.y;
        var delta = size - span * parentLength;
        var sd = tr.sizeDelta;
        tr.sizeDelta = axis == 0 ? new Vector2(delta, sd.y) : new Vector2(sd.x, delta);
    }

    /**
     * `CanvasScaler` -> 缩放系数。
     *
     * PORT-NOTE: 与 `mvz2.ui.UiRenderer.computeScaleFactor` 是同一份算法；unity 包不能反向
     * 依赖 mvz2（会成环），故在此复刻。两边必须保持一致，否则画布根尺寸与渲染帧对不上。
     */
    public static function scaleFactorOf(scaler:CanvasScaler):Float {
        if (scaler == null)
            return 1;
        if (scaler.uiScaleMode == ScaleMode.ConstantPixelSize)
            return scaler.scaleFactor != 0 ? scaler.scaleFactor : 1;
        if (scaler.uiScaleMode == ScaleMode.ConstantPhysicalSize)
            return 1;
        var ref = scaler.referenceResolution;
        if (ref == null || ref.x <= 0 || ref.y <= 0)
            return 1;
        var screen = screenSize();
        var logWidth = Math.log(screen.x / ref.x) / Math.log(2);
        var logHeight = Math.log(screen.y / ref.y) / Math.log(2);
        if (scaler.screenMatchMode == ScreenMatchMode.Expand)
            return Math.min(screen.x / ref.x, screen.y / ref.y);
        if (scaler.screenMatchMode == ScreenMatchMode.Shrink)
            return Math.max(screen.x / ref.x, screen.y / ref.y);
        return Math.pow(2, logWidth + (logHeight - logWidth) * scaler.matchWidthOrHeight);
    }

    private static function sizeOfDepth(tr:Transform, depth:Int):Vector2 {
        if (tr == null || depth > 64)
            return new Vector2(0, 0);
        var go = tr.gameObject;
        // 1) 画布节点：非世界空间画布 = 屏幕 / scaleFactor（UiRenderer.walkCanvas 直接用
        //    screenFrame 覆盖画布节点的 frame，画布自身的 RectTransform 不参与）；
        //    世界空间画布 = 自身 sizeDelta（walkWorldCanvas）。
        var canvas:Canvas = go != null ? go.GetComponent(Canvas) : null;
        if (canvas != null) {
            if (canvas.renderMode == RenderMode.WorldSpace)
                return new Vector2(tr.sizeDelta.x, tr.sizeDelta.y);
            return screenSizeOn(scaleFactorOf(canvas.gameObject != null
                ? canvas.gameObject.GetComponent(CanvasScaler) : null));
        }
        // 2) span * 父级尺寸 + sizeDelta（与 childFrame 的第 1 步同式）。
        var spanX = tr.anchorMax.x - tr.anchorMin.x;
        var spanY = tr.anchorMax.y - tr.anchorMin.y;
        var parent = ancestorSizeOf(tr, depth);
        return new Vector2(spanX * parent.x + tr.sizeDelta.x, spanY * parent.y + tr.sizeDelta.y);
    }

    /** 画布单位下的屏幕矩形（scaleFactor 为 0 时退化为 1，避免除零）。 */
    private static function screenSizeOn(scaleFactor:Float):Vector2 {
        var scale = scaleFactor > 0 ? scaleFactor : 1;
        var screen = screenSize();
        return new Vector2(screen.x / scale, screen.y / scale);
    }

    /** 屏幕逻辑尺寸；FlxG 未就绪时退回工程约定分辨率 1280x720（见 Main.hx）。 */
    private static function screenSize():Vector2 {
        if (screenSizeProvider != null) {
            var size = screenSizeProvider();
            if (size != null)
                return size;
        }
        return new Vector2(FlxG.width, FlxG.height);
    }

    /** 向上（含自身）找最近的 CanvasScaler 并取其缩放系数；找不到返回 1。 */
    private static function nearestAncestorScaleFactor(tr:Transform):Float {
        var t = tr;
        // PORT-NOTE: 父链必须有界（SetParent 不拒绝成环，见 ancestorSizeOf 的同款注释）。
        var guard = 0;
        while (t != null && guard++ < 64) {
            var go = t.gameObject;
            if (go != null) {
                var scaler = go.GetComponent(CanvasScaler);
                if (scaler != null)
                    return scaleFactorOf(scaler);
            }
            t = t.parent;
        }
        return 1;
    }

    // #endregion

    // #region 组件判定

    /** 组件是否参与布局（Unity：Behaviour 需 isActiveAndEnabled，且节点要在激活的层级里）。 */
    public static function isEnabledComponent(comp:Component):Bool {
        if (comp == null)
            return false;
        var enabled = true;
        // PORT-NOTE: shim 里 MonoBehaviour 与 Behaviour 是**两条**继承链（都直接继承 Component，
        // 各自声明 enabled），因此两种都要判。
        if (Std.isOfType(comp, MonoBehaviour))
            enabled = (cast(comp, MonoBehaviour)).enabled;
        else if (Std.isOfType(comp, Behaviour))
            enabled = (cast(comp, Behaviour)).enabled;
        if (!enabled)
            return false;
        var go = comp.gameObject;
        // PORT-NOTE: gameObject 为空 = 组件已脱离层级（destroy/未挂载），不应参与布局。
        // 原实现 `go == null || go.activeInHierarchy` 把空组件判为「参与」，会让后续
        // getAllComponents/activeInHierarchy 的解引用暴露在调用点。
        return go != null && go.activeInHierarchy;
    }

    /**
     * 该节点是否被 ILayoutIgnorer 排除在父布局组之外（Unity `LayoutGroup.CalculateLayoutInputHorizontal` 的判定）。
     *
     * PORT-NOTE: 只认 `unity.ui.LayoutElement`（本工程唯一的 ILayoutIgnorer 实现）。语义与 Unity
     * 一致：只要存在一个 ignoreLayout==false 的 ignorer 就**参与**布局，否则排除。
     */
    public static function isLayoutIgnored(go:GameObject):Bool {
        if (go == null)
            return false;
        var found = false;
        for (comp in go.GetAllComponents()) {
            if (!Std.isOfType(comp, LayoutElement))
                continue;
            if (!(cast(comp, LayoutElement)).ignoreLayout)
                return false;
            found = true;
        }
        return found;
    }

    // #endregion

    // #region 四阶段调度

    /**
     * 阶段一/三：算布局输入（**子先父后**，与 Unity `PerformLayoutCalculation` 一致）。
     *
     * PORT-NOTE: 只有布局组需要算（其它 ILayoutElement 的 min/preferred/flexible 是纯读属性）；
     * 递归不剪枝（Unity 会在「本节点没有 ILayoutElement/ILayoutGroup」时剪掉子树，靠
     * layout root 队列补算 —— 移植层每次从同一个根全量重建，剪枝会让嵌套布局组漏算）。
     */
    private static function calculateLayoutInputs(tr:Transform, axis:Int, depth:Int = 0):Void {
        if (tr == null || tr.gameObject == null)
            return;
        // 层级环/失控递归保险（正常深度 < 40）：一旦触底直接放弃本子树，
        // 不能带着无限递归继续跑（父链成环时 activeInHierarchy 也会挂）。
        if (depth > 96) {
            return;
        }
        for (child in tr.children) {
            if (child == null || child.gameObject == null || !child.gameObject.activeInHierarchy)
                continue;
            calculateLayoutInputs(child, axis, depth + 1);
        }
        var go = tr.gameObject;
        for (comp in go.GetAllComponents()) {
            if (!isEnabledComponent(comp) || !Std.isOfType(comp, LayoutGroup))
                continue;
            var group = cast(comp, LayoutGroup);
            // 单个组件抛异常只记日志：缺数据在移植层很常见，不能因为一个组件让整帧布局塌掉
            //（与 GameObject.dispatchComponents 的容错策略一致）。
            try {
                if (axis == 0) {
                    group.CalculateLayoutInputHorizontal();
                } else {
                    group.CalculateLayoutInputVertical();
                }
            } catch (e:Dynamic) {
                logComponentError(go, "LayoutGroup.CalculateLayoutInput", e);
            }
        }
    }

    /**
     * 阶段二/四：应用布局（**父先子后**，与 Unity `PerformLayoutControl` 一致）。
     *
     * 同一节点内的顺序也与 Unity 一致：先自控组件（ContentSizeFitter 改自身矩形），
     * 再布局组（用新矩形排子级）——所以「ContentSizeFitter + VerticalLayoutGroup」这类组合
     * 在水平/垂直两遍里都能拿到正确的自身尺寸。
     */
    private static function applyLayoutControl(tr:Transform, axis:Int, depth:Int = 0):Void {
        if (tr == null || tr.gameObject == null)
            return;
        // 层级环/失控递归保险（正常深度 < 40），同上。
        if (depth > 96) {
            return;
        }
        var go = tr.gameObject;
        for (comp in go.GetAllComponents()) {
            if (!isEnabledComponent(comp) || !Std.isOfType(comp, ContentSizeFitter))
                continue;
            var fitter = cast(comp, ContentSizeFitter);
            try {
                if (axis == 0) {
                    fitter.SetLayoutHorizontal();
                } else {
                    fitter.SetLayoutVertical();
                }
            } catch (e:Dynamic) {
                logComponentError(go, "ContentSizeFitter.SetLayout", e);
            }
        }
        for (comp in go.GetAllComponents()) {
            if (!isEnabledComponent(comp) || !Std.isOfType(comp, LayoutGroup))
                continue;
            var group = cast(comp, LayoutGroup);
            try {
                if (axis == 0) {
                    group.SetLayoutHorizontal();
                } else {
                    group.SetLayoutVertical();
                }
            } catch (e:Dynamic) {
                logComponentError(go, "LayoutGroup.SetLayout", e);
            }
        }
        for (child in tr.children) {
            if (child == null || child.gameObject == null || !child.gameObject.activeInHierarchy)
                continue;
            applyLayoutControl(child, axis, depth + 1);
        }
    }

    /** 布局组件抛异常时的统一告警（带节点名，便于定位是哪个 prefab 节点）。 */
    private static function logComponentError(go:GameObject, label:String, e:Dynamic):Void {
        Debug.LogWarning('[LayoutRebuilder] ${go != null ? go.name : "?"}.$label 出错：$e');
    }

    // #endregion
}

// PORT-NOTE: 对应 UnityEngine.UI.LayoutUtility。
//
// 取参数类型用 `unity.Transform` 而不是 `RectTransform`：shim 的锚点/尺寸字段都在 Transform 上
// （见 unity/Transform.hx 的 PORT-NOTE），这样纯 Transform 节点也能参与取值，也与移植层
// 已确立的 `cast transform` 惯例一致。
class LayoutUtility {
    /** 属性种类（对应 Unity ILayoutElement 的 min / preferred / flexible 三组属性）。 */
    public static inline var KIND_MIN:Int = 0;
    public static inline var KIND_PREFERRED:Int = 1;
    public static inline var KIND_FLEXIBLE:Int = 2;

    /** 注册了 `layoutElementResolver` 的未知元素的 layoutPriority（`mvz2.ui.LayoutSizeLimiter` 用的就是 100）。 */
    public static inline var EXTERNAL_PRIORITY:Int = 100;

    public static function getMinSize(tr:Transform, axis:Int):Float
        return getProperty(tr, axis, KIND_MIN, 0);

    /** Unity: `max(GetLayoutProperty(minWidth), GetLayoutProperty(preferredWidth))`（不是 max(min,preferred) 的简写）。 */
    public static function getPreferredSize(tr:Transform, axis:Int):Float {
        return Math.max(getProperty(tr, axis, KIND_MIN, 0), getProperty(tr, axis, KIND_PREFERRED, 0));
    }

    public static function getFlexibleSize(tr:Transform, axis:Int):Float
        return getProperty(tr, axis, KIND_FLEXIBLE, 0);

    /**
     * Unity `LayoutUtility.GetLayoutProperty`：遍历该节点上全部 ILayoutElement，
     * 取「优先级最高、且值非负」的那个的值；同优先级取最大。
     */
    public static function getProperty(tr:Transform, axis:Int, kind:Int, defaultValue:Float):Float {
        if (tr == null || tr.gameObject == null)
            return 0;
        var result = defaultValue;
        var bestPriority = -0x7FFFFFFF;
        for (comp in tr.gameObject.GetAllComponents()) {
            if (!LayoutRebuilder.isEnabledComponent(comp))
                continue;
            var priority = priorityOf(comp);
            if (priority < bestPriority)
                continue;
            var value = valueOf(comp, axis, kind);
            if (value < 0)
                continue;
            if (priority > bestPriority) {
                result = value;
                bestPriority = priority;
            } else if (value > result) {
                result = value;
            }
        }
        return result;
    }

    /** 组件的 layoutPriority（未知类型返回 EXTERNAL_PRIORITY；其值由 resolver 决定是否参与）。 */
    public static function priorityOf(comp:Component):Int {
        if (Std.isOfType(comp, LayoutElement))
            return (cast(comp, LayoutElement)).layoutPriority;
        if (Std.isOfType(comp, LayoutGroup))
            return (cast(comp, LayoutGroup)).layoutPriority;
        if (Std.isOfType(comp, Image))
            return (cast(comp, Image)).layoutPriority;
        if (Std.isOfType(comp, Text))
            return (cast(comp, Text)).layoutPriority;
        if (isTmpLayoutElement(comp))
            return (cast(comp, TextMeshProUGUI)).layoutPriority;
        if (Std.isOfType(comp, TMP_Text))
            return 0;
        return EXTERNAL_PRIORITY;
    }

    /** 组件在 (轴, 种类) 上的取值；负值 = 该组件在这项属性上不参与（Unity 约定）。 */
    public static function valueOf(comp:Component, axis:Int, kind:Int):Float {
        if (comp == null)
            return -1;
        if (Std.isOfType(comp, LayoutElement)) {
            var e = cast(comp, LayoutElement);
            return pickValue(axis, kind, e.minWidth, e.preferredWidth, e.flexibleWidth,
                e.minHeight, e.preferredHeight, e.flexibleHeight);
        }
        if (Std.isOfType(comp, LayoutGroup)) {
            var g = cast(comp, LayoutGroup);
            return pickValue(axis, kind, g.minWidth, g.preferredWidth, g.flexibleWidth,
                g.minHeight, g.preferredHeight, g.flexibleHeight);
        }
        if (Std.isOfType(comp, Image)) {
            // PORT-NOTE: Image shim 的 preferredWidth/Height 是**精灵像素**尺寸，而 Unity 的
            // Image.preferredWidth = sprite.rect.size / pixelsPerUnit（画布单位）。本工程精灵
            // ppu 基本都是 100（assets/sprites_manifest.json），不换算会让「受布局组控制、
            // 且 LayoutElement 没写 preferred 的 Image」把 preferred 撑大 100 倍，
            // 进而把同一轴上的 surplus 吃掉（行内其它元素跟着变小）。故这里按 Unity 的式子算。
            var sprite = (cast(comp, Image)).activeSprite;
            var ppu = (cast(comp, Image)).pixelsPerUnit;
            if (ppu <= 0)
                ppu = 100;
            var prefWidth = sprite != null ? sprite.rect.width / ppu : 0;
            var prefHeight = sprite != null ? sprite.rect.height / ppu : 0;
            return pickValue(axis, kind, 0, prefWidth, -1, 0, prefHeight, -1);
        }
        if (Std.isOfType(comp, Text)) {
            var t = cast(comp, Text);
            return pickValue(axis, kind, t.minWidth, t.preferredWidth, t.flexibleWidth,
                t.minHeight, t.preferredHeight, t.flexibleHeight);
        }
        // PORT-NOTE: 世界空间 TextMeshPro（继承 TextMeshProUGUI）不参与 uGUI 布局，
        // 与 UiRenderer 对这两者的区分一致。
        if (Type.getClass(comp) != TextMeshPro) {
            if (isTmpLayoutElement(comp)) {
                var tmp = cast(comp, TextMeshProUGUI);
                return pickValue(axis, kind, tmp.minWidth, tmp.preferredWidth, tmp.flexibleWidth,
                    tmp.minHeight, tmp.preferredHeight, tmp.flexibleHeight);
            }
            if (Std.isOfType(comp, TMP_Text)) {
                // TMP_Text 基类 shim 只有 preferred*，min/flexible 按 Unity 的默认值补齐。
                var tmpBase = cast(comp, TMP_Text);
                return pickValue(axis, kind, 0, tmpBase.preferredWidth, -1, 0, tmpBase.preferredHeight, -1);
            }
        }
        if (LayoutRebuilder.layoutElementResolver != null)
            return LayoutRebuilder.layoutElementResolver(comp, axis, kind);
        return -1;
    }

    /** TMP 文本是否参与 uGUI 布局（世界空间 TextMeshPro 排除）。 */
    public static function isTmpLayoutElement(comp:Component):Bool {
        if (comp == null || Type.getClass(comp) == TextMeshPro)
            return false;
        return Std.isOfType(comp, TextMeshProUGUI);
    }

    /** 按 (轴, 种类) 从三个属性对里挑值。 */
    public static inline function pickValue(axis:Int, kind:Int, minWidth:Float, preferredWidth:Float, flexibleWidth:Float,
            minHeight:Float, preferredHeight:Float, flexibleHeight:Float):Float {
        if (axis == 0)
            return kind == KIND_MIN ? minWidth : (kind == KIND_PREFERRED ? preferredWidth : flexibleWidth);
        return kind == KIND_MIN ? minHeight : (kind == KIND_PREFERRED ? preferredHeight : flexibleHeight);
    }
}

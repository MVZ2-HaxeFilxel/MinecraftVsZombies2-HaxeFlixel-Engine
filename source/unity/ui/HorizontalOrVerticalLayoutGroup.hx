package unity.ui;

import unity.Mathf;
import unity.RectTransform;
import unity.Vector2;
import unity.ui.LayoutElement.LayoutGroup;
import unity.ui.LayoutRebuilder.LayoutUtility;

// Minimal UnityEngine.UI.HorizontalOrVerticalLayoutGroup shim.
//
// PORT-NOTE: 本文件是 Horizontal/Vertical/Grid 布局组与 ContentSizeFitter 的**算法本体**
// （逐行对照 com.unity.ugui 的 HorizontalOrVerticalLayoutGroup.cs / GridLayoutGroup.cs /
// ContentSizeFitter.cs）。与 Unity 的差别只有三处，都在注释里标了 PORT-NOTE：
//   1. `rectTransform.rect.size[axis]` -> `getResolvedSize(axis)`（shim 的 RectTransform.rect
//      忽略锚点拉伸，见 LayoutElement.hx 的说明）；
//   2. Unity 的 out 参数 -> 可复用的 `LayoutSizes` 对象（Haxe 无 out）；
//   3. 除零/极端约束值加了保护（Unity 在这些位置是 UB）。
// 谁在什么时候调用这些方法，见 unity/ui/LayoutRebuilder.hx。
class HorizontalOrVerticalLayoutGroup extends LayoutGroup {
    public var spacing:Float = 0;
    public var childForceExpandWidth:Bool = true;
    public var childForceExpandHeight:Bool = true;
    public var childControlWidth:Bool = true;
    public var childControlHeight:Bool = true;
    public var childScaleWidth:Bool = false;
    public var childScaleHeight:Bool = false;
    public var reverseArrangement:Bool = false;

    /** 取子级尺寸用的暂存对象（Unity 用 out 参数；同一时刻只有一次 getChildSizes 在飞，可复用）。 */
    private var sizesScratch:LayoutSizes = new LayoutSizes();

    public function new() {
        super();
    }

    /**
     * Unity: `CalcAlongAxis(axis, isVertical)` —— 沿 axis 汇总子节点的 min/preferred/flexible，
     * 结果写进本组自己的布局输入（父级通过 minWidth/preferredWidth/… 读到）。
     *
     * `isVertical` = 本组是否**纵向**排列：纵向组在 axis 0 上取子级的最大值（并排宽度），
     * 在 axis 1 上取累加（依次往下堆叠）；横向组反之。
     */
    public function calcAlongAxis(axis:Int, isVertical:Bool):Void {
        var combinedPadding:Float = axis == 0 ? padding.horizontal : padding.vertical;
        var controlSize = axis == 0 ? childControlWidth : childControlHeight;
        var useScale = axis == 0 ? childScaleWidth : childScaleHeight;
        var childForceExpandSize = axis == 0 ? childForceExpandWidth : childForceExpandHeight;
        var alongOtherAxis = isVertical != (axis == 1);

        var totalMin = combinedPadding;
        var totalPreferred = combinedPadding;
        var totalFlexible:Float = 0;
        var sizes = sizesScratch;
        for (child in rectChildren) {
            getChildSizes(child, axis, controlSize, childForceExpandSize, sizes);
            var min = sizes.min;
            var preferred = sizes.preferred;
            var flexible = sizes.flexible;
            if (useScale) {
                var scaleFactor = axis == 0 ? child.localScale.x : child.localScale.y;
                min *= scaleFactor;
                preferred *= scaleFactor;
                flexible *= scaleFactor;
            }
            if (alongOtherAxis) {
                totalMin = Math.max(min + combinedPadding, totalMin);
                totalPreferred = Math.max(preferred + combinedPadding, totalPreferred);
                totalFlexible = Math.max(flexible, totalFlexible);
            } else {
                totalMin += min + spacing;
                totalPreferred += preferred + spacing;
                totalFlexible += flexible;
            }
        }
        if (!alongOtherAxis && rectChildren.length > 0) {
            totalMin -= spacing;
            totalPreferred -= spacing;
        }
        totalPreferred = Math.max(totalMin, totalPreferred);
        setLayoutInputForAxis(totalMin, totalPreferred, totalFlexible, axis);
    }

    /**
     * Unity: `SetChildrenAlongAxis(axis, isVertical)` —— 沿 axis 摆放子节点（并在控制该轴时写尺寸）。
     *
     * 排列轴（相加轴）：先按 `size - totalPreferred` 判断剩余空间：没有 flexible 子级就把整块内容
     * 按 childAlignment 居中/贴边，否则把剩余空间按 flexible 权重分给子级；
     * 交叉轴：每个子级占满内尺寸（夹在 min 与 preferred/flexible 之间）并按 childAlignment 对齐。
     */
    public function setChildrenAlongAxis(axis:Int, isVertical:Bool):Void {
        var size = getResolvedSize(axis);
        var controlSize = axis == 0 ? childControlWidth : childControlHeight;
        var useScale = axis == 0 ? childScaleWidth : childScaleHeight;
        var childForceExpandSize = axis == 0 ? childForceExpandWidth : childForceExpandHeight;
        var alignmentOnAxis = getAlignmentOnAxis(axis);
        var alongOtherAxis = isVertical != (axis == 1);

        var count = rectChildren.length;
        var reverse = reverseArrangement;
        var startIndex = reverse ? count - 1 : 0;
        var endIndex = reverse ? 0 : count;
        var increment = reverse ? -1 : 1;
        var sizes = sizesScratch;

        if (alongOtherAxis) {
            // 交叉轴：位置 + 尺寸都定（尺寸在 min / preferred / 满尺寸之间夹取）。
            var innerSize = size - (axis == 0 ? padding.horizontal : padding.vertical);
            var i = startIndex;
            while (reverse ? i >= endIndex : i < endIndex) {
                var child = rectChildren[i];
                getChildSizes(child, axis, controlSize, childForceExpandSize, sizes);
                var scaleFactor = useScale ? (axis == 0 ? child.localScale.x : child.localScale.y) : 1;
                var maxSize = sizes.flexible > 0 ? size : sizes.preferred;
                var requiredSpace = Math.min(Math.max(innerSize, sizes.min), maxSize);
                var startOffset = getStartOffset(axis, requiredSpace * scaleFactor);
                if (controlSize) {
                    setChildAlongAxis(child, axis, startOffset, requiredSpace, scaleFactor);
                } else {
                    // 不控制尺寸时子级保持自己的尺寸，只在格子里按对齐挪一下。
                    var offsetInCell = (requiredSpace - sizeDeltaOn(child, axis)) * alignmentOnAxis;
                    setChildAlongAxis(child, axis, startOffset + offsetInCell, null, scaleFactor);
                }
                i += increment;
            }
        } else {
            var pos:Float = axis == 0 ? padding.left : padding.top;
            var itemFlexibleMultiplier:Float = 0;
            var surplusSpace = size - getTotalPreferredSize(axis);
            if (surplusSpace > 0) {
                if (getTotalFlexibleSize(axis) == 0)
                    pos = getStartOffset(axis, getTotalPreferredSize(axis)
                        - (axis == 0 ? padding.horizontal : padding.vertical));
                else
                    itemFlexibleMultiplier = surplusSpace / getTotalFlexibleSize(axis);
            }
            var minMaxLerp:Float = 0;
            if (getTotalMinSize(axis) != getTotalPreferredSize(axis))
                minMaxLerp = Mathf.Clamp01((size - getTotalMinSize(axis))
                    / (getTotalPreferredSize(axis) - getTotalMinSize(axis)));

            var i = startIndex;
            while (reverse ? i >= endIndex : i < endIndex) {
                var child = rectChildren[i];
                getChildSizes(child, axis, controlSize, childForceExpandSize, sizes);
                var scaleFactor = useScale ? (axis == 0 ? child.localScale.x : child.localScale.y) : 1;
                // Unity: Mathf.Lerp(min, preferred, minMaxLerp)（t 已 Clamp01）。
                var childSize = sizes.min + (sizes.preferred - sizes.min) * minMaxLerp;
                childSize += sizes.flexible * itemFlexibleMultiplier;
                if (controlSize) {
                    setChildAlongAxis(child, axis, pos, childSize, scaleFactor);
                } else {
                    var offsetInCell = (childSize - sizeDeltaOn(child, axis)) * alignmentOnAxis;
                    setChildAlongAxis(child, axis, pos + offsetInCell, null, scaleFactor);
                }
                pos += childSize * scaleFactor + spacing;
                i += increment;
            }
        }
    }

    /**
     * Unity: `GetChildSizes` —— 子节点在 axis 上的 min/preferred/flexible。
     * 不控制尺寸时直接用子节点的 sizeDelta（Unity 同样读 `child.sizeDelta[axis]`）。
     */
    public function getChildSizes(child:Transform, axis:Int, controlSize:Bool, childForceExpand:Bool,
            sizes:LayoutSizes):Void {
        if (!controlSize) {
            sizes.min = sizeDeltaOn(child, axis);
            sizes.preferred = sizes.min;
            sizes.flexible = 0;
        } else {
            sizes.min = LayoutUtility.getMinSize(child, axis);
            sizes.preferred = LayoutUtility.getPreferredSize(child, axis);
            sizes.flexible = LayoutUtility.getFlexibleSize(child, axis);
        }
        if (childForceExpand)
            sizes.flexible = Math.max(sizes.flexible, 1);
    }

    private inline function sizeDeltaOn(child:Transform, axis:Int):Float
        return axis == 0 ? child.sizeDelta.x : child.sizeDelta.y;
}

// Minimal UnityEngine.UI.VerticalLayoutGroup shim.
class VerticalLayoutGroup extends HorizontalOrVerticalLayoutGroup {
    public function new() {
        super();
    }

    override public function CalculateLayoutInputHorizontal():Void {
        super.CalculateLayoutInputHorizontal();
        calcAlongAxis(0, true);
    }
    override public function CalculateLayoutInputVertical():Void {
        calcAlongAxis(1, true);
    }
    override public function SetLayoutHorizontal():Void {
        setChildrenAlongAxis(0, true);
    }
    override public function SetLayoutVertical():Void {
        setChildrenAlongAxis(1, true);
    }
}

// Minimal UnityEngine.UI.HorizontalLayoutGroup shim.
class HorizontalLayoutGroup extends HorizontalOrVerticalLayoutGroup {
    public function new() {
        super();
    }

    override public function CalculateLayoutInputHorizontal():Void {
        super.CalculateLayoutInputHorizontal();
        calcAlongAxis(0, false);
    }
    override public function CalculateLayoutInputVertical():Void {
        calcAlongAxis(1, false);
    }
    override public function SetLayoutHorizontal():Void {
        setChildrenAlongAxis(0, false);
    }
    override public function SetLayoutVertical():Void {
        setChildrenAlongAxis(1, false);
    }
}

// Minimal UnityEngine.UI.GridLayoutGroup shim.
class GridLayoutGroup extends LayoutGroup {
    public var startCorner:Corner = Corner.UpperLeft;
    public var startAxis:GridAxis = GridAxis.Horizontal;
    public var cellSize:unity.Vector2 = new unity.Vector2(100, 100);
    public var spacing:unity.Vector2 = new unity.Vector2();
    public var constraint:Constraint = Constraint.Flexible;
    public var constraintCount:Int = 2;

    public function new() {
        super();
    }

    /** Unity: `GridLayoutGroup.CalculateLayoutInputHorizontal`（列数由约束决定）。 */
    override public function CalculateLayoutInputHorizontal():Void {
        super.CalculateLayoutInputHorizontal();
        var minColumns:Int;
        var preferredColumns:Int;
        var constrainedCount = safeConstraintCount();
        if (constraint == Constraint.FixedColumnCount) {
            minColumns = constrainedCount;
            preferredColumns = constrainedCount;
        } else if (constraint == Constraint.FixedRowCount) {
            minColumns = Std.int(Math.ceil(rectChildren.length / constrainedCount - 0.001));
            preferredColumns = minColumns;
        } else {
            minColumns = 1;
            preferredColumns = Std.int(Math.ceil(Math.sqrt(rectChildren.length)));
        }
        setLayoutInputForAxis(
            padding.horizontal + (cellSize.x + spacing.x) * minColumns - spacing.x,
            padding.horizontal + (cellSize.x + spacing.x) * preferredColumns - spacing.x,
            -1, 0);
    }

    /** Unity: `GridLayoutGroup.CalculateLayoutInputVertical`（行数由列数/约束决定）。 */
    override public function CalculateLayoutInputVertical():Void {
        var minRows:Int;
        var constrainedCount = safeConstraintCount();
        if (constraint == Constraint.FixedColumnCount) {
            minRows = Std.int(Math.ceil(rectChildren.length / constrainedCount - 0.001));
        } else if (constraint == Constraint.FixedRowCount) {
            minRows = constrainedCount;
        } else {
            minRows = Std.int(Math.ceil(rectChildren.length / cellCountOnAxis(0)));
        }
        var minSpace = padding.vertical + (cellSize.y + spacing.y) * minRows - spacing.y;
        setLayoutInputForAxis(minSpace, minSpace, -1, 1);
    }

    override public function SetLayoutHorizontal():Void {
        setCellsAlongAxis(0);
    }
    override public function SetLayoutVertical():Void {
        setCellsAlongAxis(1);
    }

    /**
     * Unity: `GridLayoutGroup.SetCellsAlongAxis`。
     *
     * Unity 的注释同样适用：水平阶段只把所有子级设成 cellSize（位置留给垂直阶段），
     * 垂直阶段才按 startCorner/startAxis/constraint 计算行列位置。
     */
    private function setCellsAlongAxis(axis:Int):Void {
        var childCount = rectChildren.length;
        if (axis == 0) {
            for (i in 0...childCount) {
                var rect = rectChildren[i];
                rect.anchorMin = new Vector2(0, 1);
                rect.anchorMax = new Vector2(0, 1);
                rect.sizeDelta = new Vector2(cellSize.x, cellSize.y);
            }
            return;
        }

        var constrainedCount = safeConstraintCount();
        var cellCountX = 1;
        var cellCountY = 1;
        if (constraint == Constraint.FixedColumnCount) {
            cellCountX = constrainedCount;
            if (childCount > cellCountX)
                cellCountY = Std.int(childCount / cellCountX) + (childCount % cellCountX > 0 ? 1 : 0);
        } else if (constraint == Constraint.FixedRowCount) {
            cellCountY = constrainedCount;
            if (childCount > cellCountY)
                cellCountX = Std.int(childCount / cellCountY) + (childCount % cellCountY > 0 ? 1 : 0);
        } else {
            // PORT-NOTE: Unity 用 int.MaxValue 表示「该轴不限制」。
            cellCountX = cellSize.x + spacing.x <= 0 ? 0x7FFFFFFF : cellCountOnAxis(0);
            cellCountY = cellSize.y + spacing.y <= 0 ? 0x7FFFFFFF : cellCountOnAxis(1);
        }

        var corner:Int = (cast startCorner:Int);
        var cornerX = corner % 2;
        var cornerY = Std.int(corner / 2);

        var cellsPerMainAxis:Int;
        var actualCellCountX:Int;
        var actualCellCountY:Int;
        if (startAxis == GridAxis.Horizontal) {
            cellsPerMainAxis = cellCountX;
            actualCellCountX = Mathf.ClampInt(cellCountX, 1, childCount);
            if (constraint == Constraint.FixedRowCount)
                actualCellCountY = Mathf.MinInt(cellCountY, childCount);
            else
                actualCellCountY = Mathf.ClampInt(cellCountY, 1, Std.int(Math.ceil(childCount / cellsPerMainAxis)));
        } else {
            cellsPerMainAxis = cellCountY;
            actualCellCountY = Mathf.ClampInt(cellCountY, 1, childCount);
            if (constraint == Constraint.FixedColumnCount)
                actualCellCountX = Mathf.MinInt(cellCountX, childCount);
            else
                actualCellCountX = Mathf.ClampInt(cellCountX, 1, Std.int(Math.ceil(childCount / cellsPerMainAxis)));
        }

        var requiredSpace = new Vector2(
            actualCellCountX * cellSize.x + (actualCellCountX - 1) * spacing.x,
            actualCellCountY * cellSize.y + (actualCellCountY - 1) * spacing.y);
        var startOffset = new Vector2(getStartOffset(0, requiredSpace.x), getStartOffset(1, requiredSpace.y));

        // Unity case 1345471：受约束轴上「末行/末列不足」的子级仍然对齐到约束的列数/行数。
        var childrenToMove = 0;
        if (childCount > constrainedCount
            && Math.ceil(childCount / cellsPerMainAxis) < constrainedCount) {
            childrenToMove = constrainedCount - Std.int(Math.ceil(childCount / cellsPerMainAxis));
            // PORT-NOTE: Unity 这里是 `childrenToMove / (cellsPerMainAxis - 1)`，未防 cellsPerMainAxis == 1
            // （会除零）；这里显式跳过。
            if (cellsPerMainAxis > 1)
                childrenToMove += Std.int(childrenToMove / (cellsPerMainAxis - 1));
            if (childCount % cellsPerMainAxis == 1)
                childrenToMove += 1;
        }

        for (i in 0...childCount) {
            var positionX:Int;
            var positionY:Int;
            if (startAxis == GridAxis.Horizontal) {
                if (constraint == Constraint.FixedRowCount && childCount - i <= childrenToMove) {
                    positionX = 0;
                    positionY = constrainedCount - (childCount - i);
                } else {
                    positionX = i % cellsPerMainAxis;
                    positionY = Std.int(i / cellsPerMainAxis);
                }
            } else {
                if (constraint == Constraint.FixedColumnCount && childCount - i <= childrenToMove) {
                    positionX = constrainedCount - (childCount - i);
                    positionY = 0;
                } else {
                    positionX = Std.int(i / cellsPerMainAxis);
                    positionY = i % cellsPerMainAxis;
                }
            }
            if (cornerX == 1)
                positionX = actualCellCountX - 1 - positionX;
            if (cornerY == 1)
                positionY = actualCellCountY - 1 - positionY;

            setChildAlongAxis(rectChildren[i], 0, startOffset.x + (cellSize.x + spacing.x) * positionX, cellSize.x);
            setChildAlongAxis(rectChildren[i], 1, startOffset.y + (cellSize.y + spacing.y) * positionY, cellSize.y);
        }
    }

    /** 该轴上按 cellSize/spacing 放得下的格子数（Unity: cellCountX/cellCountY）。 */
    private function cellCountOnAxis(axis:Int):Int {
        var cell = axis == 0 ? cellSize.x : cellSize.y;
        var gap = axis == 0 ? spacing.x : spacing.y;
        var paddingOnAxis:Float = axis == 0 ? padding.horizontal : padding.vertical;
        if (cell + gap <= 0)
            return 1;
        var extent = getResolvedSize(axis);
        return Std.int(Math.max(1, Math.floor((extent - paddingOnAxis + gap + 0.001) / (cell + gap))));
    }

    /** PORT-NOTE: Unity 的 constraintCount setter 会把值钳到 >= 1；shim 的字段是裸 Int，这里补上。 */
    private inline function safeConstraintCount():Int return constraintCount > 0 ? constraintCount : 1;
}

// Minimal UnityEngine.UI.GridLayoutGroup.Corner shim.
enum abstract Corner(Int) {
    var UpperLeft = 0;
    var UpperRight = 1;
    var LowerLeft = 2;
    var LowerRight = 3;
}

// Minimal UnityEngine.UI.GridLayoutGroup.Axis shim.
enum abstract GridAxis(Int) {
    var Horizontal = 0;
    var Vertical = 1;
}

// Minimal UnityEngine.UI.GridLayoutGroup.Constraint shim.
enum abstract Constraint(Int) {
    var Flexible = 0;
    var FixedColumnCount = 1;
    var FixedRowCount = 2;
}

// Minimal UnityEngine.UI.ContentSizeFitter shim.
class ContentSizeFitter extends UIBehaviour {
    public var horizontalFit:FitMode = FitMode.Unconstrained;
    public var verticalFit:FitMode = FitMode.Unconstrained;

    public function new() {
        super();
    }

    /** Unity: `ILayoutSelfController.SetLayoutHorizontal` —— 按 horizontalFit 写自身宽度。 */
    public function SetLayoutHorizontal():Void {
        handleSelfFittingAlongAxis(0);
    }

    /** Unity: `ILayoutSelfController.SetLayoutVertical` —— 按 verticalFit 写自身高度。 */
    public function SetLayoutVertical():Void {
        handleSelfFittingAlongAxis(1);
    }

    /**
     * Unity: `HandleSelfFittingAlongAxis`。
     *
     * 尺寸来源是**本节点自身**的布局输入（LayoutUtility 会遍历本节点全部 ILayoutElement，
     * 包括同一节点上的 LayoutGroup 汇总值 —— 这正是「VerticalLayoutGroup + ContentSizeFitter」
     * 的常见组合能撑开高度的原因）。
     */
    private function handleSelfFittingAlongAxis(axis:Int):Void {
        var fitting = axis == 0 ? horizontalFit : verticalFit;
        if (fitting == FitMode.Unconstrained)
            return;
        var size = fitting == FitMode.MinSize
            ? LayoutUtility.getMinSize(transform, axis)
            : LayoutUtility.getPreferredSize(transform, axis);
        LayoutRebuilder.setSizeWithCurrentAnchors(transform, axis, size);
    }
}

// Minimal UnityEngine.UI.ContentSizeFitter.FitMode shim.
enum abstract FitMode(Int) {
    var Unconstrained = 0;
    var MinSize = 1;
    var PreferredSize = 2;
}

// Minimal UnityEngine.UI.AspectRatioFitter shim.
class AspectRatioFitter extends UIBehaviour {
    public var aspectMode:AspectMode = AspectMode.None;
    public var aspectRatio:Float = 1;

    public function new() {
        super();
    }
    public function SetLayoutHorizontal():Void {}
    public function SetLayoutVertical():Void {}
}

// Minimal UnityEngine.UI.AspectRatioFitter.AspectMode shim.
enum abstract AspectMode(Int) {
    var None = 0;
    var WidthControlsHeight = 1;
    var HeightControlsWidth = 2;
    var FitInParent = 3;
    var EnvelopeParent = 4;
}

/** min/preferred/flexible 三个值的容器（替代 Unity 的 out 参数）。 */
class LayoutSizes {
    public var min:Float = 0;
    public var preferred:Float = 0;
    public var flexible:Float = 0;

    public function new() {}
}

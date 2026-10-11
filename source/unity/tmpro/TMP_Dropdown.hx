package unity.tmpro;

import unity.GameObject;
import unity.RectTransform;
import unity.UnityObject;
import unity.ui.Toggle;
import unity.tmpro.TextMeshProUGUI.TextAlignmentOptions;

// Minimal TMPro.TMP_Dropdown shim.
class TMP_Dropdown extends unity.ui.Selectable {
    public var template:RectTransform;
    public var captionText:TextMeshProUGUI;
    public var captionImage:unity.ui.Image;
    public var itemText:TextMeshProUGUI;
    public var itemImage:unity.ui.Image;
    public var options(get, set):Array<TMP_OptionData>;
    function get_options():Array<TMP_OptionData> return m_Options.options;
    function set_options(v:Array<TMP_OptionData>):Array<TMP_OptionData> {
        SetupOptions(v, value);
        return v;
    }
    public var value(get, set):Int;
    function get_value():Int return m_Value;
    function set_value(v:Int):Int {
        Set(v, true);
        return v;
    }
    public var onValueChanged:TMP_DropdownEvent = new TMP_DropdownEvent();
    public var alphaFadeSpeed:Float = 0.15;
    public var itemTextAlignment:TextAlignmentOptions;

    private var m_Value:Int = 0;
    private var m_Options:TMP_OptionDataList = new TMP_OptionDataList();
    // PORT-NOTE: C# 的展开列表（blocker + 按 options 克隆出的 item）落成：Show 时把 template
    // 子树里第一个带 Toggle 的节点（即 Template/Viewport/Content/Item 原型）按 options 克隆到
    // 原型的父节点下，Hide 时销毁；alphaFadeSpeed 的淡入淡出未实现，直接切换 template 显隐。
    private var m_Items:Array<GameObject> = [];
    private var m_ItemPrototype:GameObject;
    private var m_ItemsDirty:Bool = true;
    // PORT-NOTE: 列表收窄用的基线（见 ApplyListSize）。Unity 每次 Show 收窄的是模板的**克隆体**
    // （m_Dropdown），移植层直接改原 template，所以要先记下未收窄时的高度，避免反复展开逐次叠加。
    private var m_TemplateBaseHeight:Float = -1;
    private var m_ContentBaseDeltaY:Float = 0;
    private var m_HasListSizeBaseline:Bool = false;

    public function new() {
        super();
    }

    public function SetValueWithoutNotify(input:Int):Void {
        Set(input, false);
    }
    private function Set(value:Int, sendCallback:Bool):Void {
        if (value == m_Value) return;
        m_Value = value;
        RefreshShownValue();
        if (sendCallback) onValueChanged.Invoke(m_Value);
    }
    // C# (TMP_Dropdown.RefreshShownValue): 按 value 取 option，写 captionText/captionImage。
    public function RefreshShownValue():Void {
        var list = m_Options.options;
        var selected = list != null && list.length > 0 ? list[clampIndex()] : null;
        if (captionText != null)
            captionText.text = selected != null && selected.text != null ? selected.text : "";
        if (captionImage != null) {
            captionImage.sprite = selected != null ? selected.image : null;
            captionImage.enabled = captionImage.sprite != null;
        }
    }
    public function AddOptions(options:Array<TMP_OptionData>):Void {
        m_Options.options = m_Options.options.concat(options);
        RefreshShownValue();
        InvalidateItems();
    }
    public function ClearOptions():Void {
        m_Options.options = [];
        RefreshShownValue();
        InvalidateItems();
    }
    private function SetupOptions(options:Array<TMP_OptionData>, defaultOption:Int):Void {
        m_Options.options = options.copy();
        Set(defaultOption, true);
        RefreshShownValue();
        InvalidateItems();
    }
    public function Show():Void {
        if (template == null) return;
        if (!IsActive() || !IsInteractable()) return;
        if (template.gameObject.activeSelf) return;
        if (m_ItemsDirty) BuildItems();
        template.gameObject.SetActive(true);
    }
    public function Hide():Void {
        if (template != null)
            template.gameObject.SetActive(false);
        ClearItems();
        m_ItemsDirty = true;
    }
    public function OnPointerClick(eventData:unity.eventsystems.PointerEventData):Void {
        // 点在下拉框本体 = 展开/收起；展开时点模板内的 item 由 item 自己的处理器接管
        // （Toggle / TMP_DropdownItem，见 BuildItems），派发到不了这里。
        if (IsExpanded()) Hide();
        else Show();
    }

    // #region 展开列表（移植层新增，对应 C# 的 CreateBlocker/CreateDropdownList/AddItem）
    private function IsExpanded():Bool return template != null && template.gameObject.activeSelf;
    private function InvalidateItems():Void {
        m_ItemsDirty = true;
        if (IsExpanded()) BuildItems();
    }
    private function clampIndex():Int {
        var count = m_Options.options != null ? m_Options.options.length : 0;
        if (count <= 0) return 0;
        if (m_Value < 0) return 0;
        if (m_Value > count - 1) return count - 1;
        return m_Value;
    }
    private function BuildItems():Void {
        ClearItems();
        m_ItemsDirty = false;
        if (template == null) return;
        var prototype = findItemPrototype();
        mvz2.states.BootTrace.step('TMP_Dropdown.BuildItems: prototype=${prototype != null} options=${m_Options.options != null ? m_Options.options.length : -1}');
        if (prototype == null) return;
        m_ItemPrototype = prototype;
        var list = m_Options.options != null ? m_Options.options : [];
        var parent = prototype.transform.parent;
        var rowHeight = itemRowHeight();
        // 原型的 Toggle：克隆体要按它补齐状态（见下面的循环）。
        var protoToggle = prototype.GetComponent(Toggle);
        for (i in 0...list.length) {
            var item = UnityObject.Instantiate(prototype, null, null, parent);
            if (item == null) continue;
            item.SetActive(true);
            var index = i;
            // PORT-NOTE: mvz2.ui.UiRenderer 不做 LayoutGroup 真实布局，克隆项会叠在原型位置上；
            // 这里按 Unity VerticalLayoutGroup 的结果手工往下排（Content 的 y 轴向上）。
            var itemRect = Std.isOfType(item.transform, RectTransform) ? cast(item.transform, RectTransform) : null;
            if (itemRect != null) {
                itemRect.anchoredPosition = new unity.Vector2(itemRect.anchoredPosition.x,
                    itemRect.anchoredPosition.y - index * rowHeight);
            }
            var data = list[index];
            var label:TextMeshProUGUI = itemText != null ? cast clonedEquivalent(item, itemText) : null;
            if (label == null)
                label = item.GetComponentInChildren(TextMeshProUGUI, true);
            if (label != null)
                label.text = data != null && data.text != null ? data.text : "";
            if (itemImage != null) {
                var image:unity.ui.Image = cast clonedEquivalent(item, itemImage);
                if (image != null)
                    image.sprite = data != null ? data.image : null;
            }
            // 行点击：C# 用 item 的 Toggle.onValueChanged 选中并收起，这里同样接线。
            var toggle = item.GetComponent(Toggle);
            if (toggle != null) {
                // PORT-NOTE: UnityObject.Instantiate 不复制 ColorBlock（普通类实例，见
                // UnityObject.copySerializedFields），克隆项的 Selectable 颜色表会退回声明初值 ——
                // 不补齐的话条目背景（Item/Background，normalColor 的 alpha=0）会重新变成不透明白块。
                if (protoToggle != null) {
                    toggle.colors = protoToggle.colors;
                    toggle.transition = protoToggle.transition;
                }
                toggle.SetIsOnWithoutNotify(index == m_Value);
                // 克隆体不会被派发 Awake（Instantiate 只做深拷贝），状态色与勾图显隐都得显式刷一次。
                toggle.ApplySelectionState();
                toggle.ApplyToggleEffect();
                toggle.onValueChanged.AddListener(function(_) SelectItem(index));
            }
            // PORT-NOTE: C# 的点击经事件系统 ExecuteHierarchy 冒泡到 item 的 Toggle（uGUI 的
            // Toggle 就在 item 根节点上）；移植层逐节点派发，TextMeshProUGUI 节点自己收得到
            // OnPointerClick，给标签文本区补一个把点击转发回所属下拉框的组件。
            if (label != null) {
                var forwarder = label.gameObject.AddComponent(TMP_DropdownItem);
                if (forwarder != null) {
                    forwarder.onSelect = function() SelectItem(index);
                    // 同理，Toggle 收不到标签区的悬停事件（不冒泡），悬停高亮由转发器补上。
                    if (toggle != null) {
                        forwarder.onEnter = toggle.OnPointerEnter;
                        forwarder.onExit = toggle.OnPointerExit;
                    }
                }
            }
            m_Items.push(item);
        }
        prototype.SetActive(false);
        // C# 的收窄发生在 Show() 里、作用对象是模板的克隆体（m_Dropdown）；移植层直接复用原
        // template，每次重建都从基线重算（见 ApplyListSize）。
        ApplyListSize(list.length);
    }
    private function ClearItems():Void {
        for (item in m_Items)
            if (item != null)
                UnityObject.destroy(item);
        m_Items = [];
    }
    private function SelectItem(index:Int):Void {
        if (!IsInteractable()) return;
        value = index;
        Hide();
    }
    /** template 子树里第一个带 Toggle 的节点 = item 原型（Unity 的 Template/Viewport/Content/Item）。 */
    private function findItemPrototype():GameObject {
        if (template == null) return null;
        return findFirstToggle(template.gameObject);
    }
    private function findFirstToggle(root:GameObject):GameObject {
        if (root == null) return null;
        for (child in root.transform.children) {
            var go = child.gameObject;
            if (go == null) continue;
            if (go.GetComponent(Toggle) != null) return go;
            var found = findFirstToggle(go);
            if (found != null) return found;
        }
        return null;
    }
    private function itemRowHeight():Float {
        if (m_ItemPrototype != null && Std.isOfType(m_ItemPrototype.transform, RectTransform)) {
            var h = cast(m_ItemPrototype.transform, RectTransform).sizeDelta.y;
            if (h > 0) return h;
        }
        return 30;
    }
    /**
     * 按条目数收窄展开列表（对应 C# TMP_Dropdown.Show() 结尾的收窄段）。
     *
     * C# 原文（变量名同源）：
     *   offsetMin = itemTemplate.rect.min - content.rect.min + itemTemplate.localPosition
     *   offsetMax = itemTemplate.rect.max - content.rect.max + itemTemplate.localPosition
     *   content.sizeDelta.y = itemSize.y * itemCount + offsetMin.y - offsetMax.y
     *   extraSpace = dropdownRect.height - content.rect.height
     *   若 extraSpace > 0：dropdownRect.sizeDelta.y -= extraSpace
     *
     * PORT-NOTE: 移植层的 RectTransform 没有 offsetMin/offsetMax，但这两式的 y 分量之差可以把
     * `itemTemplate.localPosition.y` 消掉（两类矩形的 min/max 都以各自 pivot 为原点，见
     * mvz2.ui.UiRenderer.childFrame 的约定）：
     *   offsetMin.y - offsetMax.y = (itemMin.y - itemMax.y) - (contentMin.y - contentMax.y)
     *                            = contentHeight - rowHeight
     * 因此只需要 content 的布局高度与行高。
     */
    private function ApplyListSize(itemCount:Int):Void {
        if (template == null || m_ItemPrototype == null) return;
        var contentRect = Std.isOfType(m_ItemPrototype.transform.parent, RectTransform)
            ? cast(m_ItemPrototype.transform.parent, RectTransform) : null;
        if (contentRect == null) return;
        if (!m_HasListSizeBaseline) {
            m_TemplateBaseHeight = template.sizeDelta.y;
            m_ContentBaseDeltaY = contentRect.sizeDelta.y;
            m_HasListSizeBaseline = true;
        }
        // 还原基线：等价于 Unity 每次 Show 都从模板克隆体重新开始。
        template.sizeDelta.y = m_TemplateBaseHeight;
        contentRect.sizeDelta.y = m_ContentBaseDeltaY;
        var templateHeight = template.sizeDelta.y;
        var viewportRect = Std.isOfType(contentRect.transform.parent, RectTransform)
            ? cast(contentRect.transform.parent, RectTransform) : null;
        // Content 的布局高度。本工程模板里 Content 的锚点是 (0,1)-(1,1)（高度 = sizeDelta.y）、
        // Viewport 是 (0,0)-(1,1)（高度 = template 高度），按通用公式算对拉伸锚点同样成立。
        var viewportHeight = viewportRect != null ? laidOutHeight(viewportRect, templateHeight) : templateHeight;
        var contentHeight = laidOutHeight(contentRect, viewportHeight);
        var rowHeight = itemRowHeight();
        // C#: itemSize.y * itemCount + offsetMin.y - offsetMax.y
        var listHeight = itemCount * rowHeight + (contentHeight - rowHeight);
        // 锚点非拉伸时上式即 listHeight（本工程如此），拉伸锚点下要减去父级占比才得到目标高度。
        contentRect.sizeDelta.y = listHeight
            - (contentRect.anchorMax.y - contentRect.anchorMin.y) * viewportHeight;
        // C#: extraSpace = 模板高度 - content 高度；只有列表比模板短时模板才收窄（否则靠 ScrollRect 滚动）。
        var extraSpace = templateHeight - listHeight;
        if (extraSpace > 0)
            template.sizeDelta.y = templateHeight - extraSpace;
        // Viewport 在本工程的模板里是纵向拉伸锚点，高度随 template 自动变化；Unity 的收窄段本身也不动它。
    }
    /** 子节点在父级局部单位下的高度（与 mvz2.ui.UiRenderer.childFrame 的同一公式）。 */
    private function laidOutHeight(rt:RectTransform, parentHeight:Float):Float {
        return (rt.anchorMax.y - rt.anchorMin.y) * parentHeight + rt.sizeDelta.y;
    }
    /** 原型子树里的组件在克隆体上的对应组件（按子级下标路径定位；克隆不复制事件/结构体字段）。 */
    private function clonedEquivalent(clone:GameObject, source:unity.Component):unity.Component {
        if (clone == null || source == null || m_ItemPrototype == null) return null;
        var path = relativePath(m_ItemPrototype, source.gameObject);
        if (path == null) return null;
        var target = nodeByPath(clone, path);
        return target != null ? target.GetComponent(Type.getClass(source)) : null;
    }
    /** node 相对 root 的子级下标路径（node == root 时为空数组）；不在子树内返回 null。 */
    private function relativePath(root:GameObject, node:GameObject):Array<Int> {
        if (node == null) return null;
        var path:Array<Int> = [];
        var tr = node.transform;
        while (tr != null && tr.gameObject != root) {
            if (tr.parent == null) return null;
            path.push(tr.parent.children.indexOf(tr));
            tr = tr.parent;
        }
        if (tr == null) return null;
        path.reverse();
        return path;
    }
    private function nodeByPath(root:GameObject, path:Array<Int>):GameObject {
        var current = root;
        for (index in path) {
            if (current == null) return null;
            var child = current.transform.children[index];
            current = child != null ? child.gameObject : null;
        }
        return current;
    }
    // #endregion
}

// Minimal TMPro.TMP_Dropdown.OptionData shim.
class TMP_OptionData {
    public var text:String;
    public var image:unity.Sprite;
    public function new(?text:String = null, ?image:unity.Sprite = null) {
        this.text = text;
        this.image = image;
    }
}

// Minimal TMPro.TMP_Dropdown.OptionDataList shim.
class TMP_OptionDataList {
    public var options:Array<TMP_OptionData> = [];
    public function new() {}
}

// Minimal TMPro.TMP_Dropdown.DropdownEvent shim.
class TMP_DropdownEvent extends unity.events.UnityEvent1<Int> {
    public function new() {
        super();
    }
}

// PORT-NOTE: 移植层新增（无 C# 对应源码）。Unity 的点击经事件系统 ExecuteHierarchy 冒泡到
// item 的 Toggle；移植层（mvz2.ui.UiRenderer）逐节点派发，TextMeshProUGUI 节点自己收得到
// OnPointerClick，这里补一个把点击转发回所属 TMP_Dropdown 的组件（见 TMP_Dropdown.BuildItems）。
// 悬停同样需要转发：Toggle 挂在 item 根节点上，而 UiRenderer 只向**命中节点自身**派发指针事件，
// 不转发的话条目的悬停高亮（ColorBlock.highlightedColor）永远不会生效。
class TMP_DropdownItem extends unity.MonoBehaviour {
    public var onSelect:Void->Void;
    public var onEnter:unity.eventsystems.PointerEventData->Void;
    public var onExit:unity.eventsystems.PointerEventData->Void;
    public function OnPointerClick(eventData:unity.eventsystems.PointerEventData):Void {
        if (onSelect != null) onSelect();
    }
    public function OnPointerEnter(eventData:unity.eventsystems.PointerEventData):Void {
        if (onEnter != null) onEnter(eventData);
    }
    public function OnPointerExit(eventData:unity.eventsystems.PointerEventData):Void {
        if (onExit != null) onExit(eventData);
    }
}

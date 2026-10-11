package unity;

// Minimal UnityEngine.Object shim (named UnityObject to avoid clashing with haxe `Object`).
class UnityObject {
    public var name:String = "";
    public var destroyed:Bool = false;

    public function new() {}

    // C# 的 Tools 扩展方法 `unity.UnityObject.exists(obj)` 在 Haxe 中无法在 null 上调用，
    // 因此调用点写 `UnityObject.exists(obj)`。
    public static function exists(obj:Dynamic):Bool {
        if (obj == null) return false;
        if (Std.isOfType(obj, UnityObject)) {
            return !(cast obj:UnityObject).destroyed;
        }
        return true;
    }
    public function Exists():Bool return !destroyed;

    public static function destroy(obj:Dynamic, ?delay:Float):Void {
        if (obj == null) return;
        if (Std.isOfType(obj, GameObject)) {
            // PORT-NOTE: 对应 Unity 的 Object.Destroy(GameObject) —— **整棵子树**被销毁。
            // 原先只置 destroyed 标记，GameObject 仍留在父级 Transform.children 里，
            // 于是显示列表（mvz2.ui.UiRenderer 按 children 遍历）会继续把它画出来，
            // `LevelController` 反复重建模型时还会不断累积。
            destroyGameObject(cast obj);
            return;
        }
        if (Std.isOfType(obj, Component)) {
            // PORT-NOTE: Unity 的 Destroy(Component) 只移除该组件、保留 GameObject。
            var component:Component = cast obj;
            component.destroyed = true;
            RenderBridge.unregister(component);
            return;
        }
        if (Std.isOfType(obj, UnityObject)) {
            (cast obj:UnityObject).destroyed = true;
            return;
        }
        if (Std.isOfType(obj, flixel.FlxBasic)) {
            var basic:flixel.FlxBasic = cast obj;
            basic.kill();
        } else if (Reflect.hasField(obj, "destroy")) {
            Reflect.callMethod(obj, Reflect.field(obj, "destroy"), []);
        }
    }

    /**
     * 递归销毁 GameObject 子树，并从父级 children 里摘除。
     *
     * PORT-NOTE: 这是「渲染对象随 GameObject 一起消失」的保证 —— 显示列表是按
     * `Transform.children` 遍历出来的（见 `mvz2/ui/UiRenderer.walk`），
     * 不摘除就会继续绘制已销毁的对象。Unity 在帧末真正移除；移植层立即摘除，
     * 对调用点是等价的（`Exists()` 立刻返回 false，与 C# 的伪空判断一致）。
     */
    private static function destroyGameObject(go:GameObject):Void {
        if (go == null || go.destroyed)
            return;
        go.destroyed = true;
        var tr = go.transform;
        if (tr != null) {
            // 先递归子级（子级 SetParent 会改 children 表，故先取副本）。
            for (child in tr.children.copy()) {
                if (child != null && child.gameObject != null)
                    destroyGameObject(child.gameObject);
            }
            // 从父级摘除（对应 Unity 的 Destroy 让对象离开层级）。
            if (tr.parent != null)
                tr.parent.children.remove(tr);
            tr.children = [];
            tr.parent = null;
        }
        // 注销该节点上的全部渲染器。
        for (component in go.GetAllComponents()) {
            if (component != null) {
                component.destroyed = true;
                RenderBridge.unregister(component);
            }
        }
    }
    public static function Destroy(obj:Dynamic, ?delay:Float):Void destroy(obj, delay);
    // PORT-NOTE: 新增 DestroyImmediate 以支持 ModelManager 等处的编辑器式立即销毁调用。
    public static function DestroyImmediate(obj:Dynamic):Void destroy(obj);
    public static function DontDestroyOnLoad(target:Dynamic):Void {}
    public static function Instantiate<T>(original:T, ?position:Vector3, ?rotation:Quaternion, ?parent:Transform):T {
        if (original == null)
            return original;
        // PORT-NOTE: 对应 Unity 的 Object.Instantiate —— 深拷贝整棵 GameObject 子树（层级、
        // 组件、以及指向子树内部的序列化字段引用）。旧实现只 new 一个空 GameObject + AddComponent，
        // 克隆体上所有 @:serializeField 都是 null，于是任何模板式列表
        //（ElementListUI/ElementList/ElementArray 的 CreateItem）在
        // `rect.GetComponent(ButtonRow)` / `button.Text.text` 处空引用。
        // 实测崩点：CustomDialog.SetDialog → ElementListUI.updateList → CreateItem。
        if (Std.isOfType(original, GameObject)) {
            var cloned = cloneSubtree(cast original);
            attachClone(cloned.root, position, rotation, parent);
            // PORT-NOTE: 对齐 Unity 的 Instantiate 语义 —— 实例化后对克隆树的全部组件派发
            // Awake（Unity 引擎在实例化时就会调）。移植层原先只建树不派发，于是一切
            // 「Awake 里创建字段、Init 里使用」的模式（EntityController.hpBarSource、
            // GridController.hpBarSource…）全部拿到 null，关卡实体一生成就空引用段错误。
            awakenCloneTree(cloned.root);
            return cast cloned.root;
        }
        if (Std.isOfType(original, Component)) {
            var template:Component = cast original;
            if (template.gameObject == null)
                return original;
            var cloned = cloneSubtree(template.gameObject);
            attachClone(cloned.root, position, rotation, parent);
            awakenCloneTree(cloned.root);
            var mapped = cloned.map.get(cast template);
            return mapped != null ? cast mapped : cast original;
        }
        // PORT-NOTE: 其余类型（Sprite/Material 等资源）在移植层是引用类型，直接返回同一实例。
        return original;
    }

    // #region Instantiate 深拷贝辅助
    // PORT-NOTE: 移植层新增（无 C# 对应源码）。Unity 的 Instantiate 会复制：
    //   * 整棵 GameObject 层级（名字/激活/layer/tag、Transform 或 RectTransform 的布局字段）；
    //   * 每个节点上的全部组件（同类型、同顺序）；
    //   * 序列化字段的值，并把指向被拷贝子树内部的引用重映射到克隆体上。
    // 与 Unity 的已知差异（不影响启动链路，记录以便后续补齐）：
    //   * 只复制「Unity 会序列化」的值类别：null / Bool / Int / Float / String / Array / UnityObject。
    //     结构体包装类型（unity.Color / Vector2 / Vector3 等 abstract over class）与非 Unity 类
    //     （FlxSignal / UnityEvent / 委托）不复制——前者保持构造函数默认值，后者保证克隆体拥有
    //     自己的信号实例（Unity 的事件本来也不序列化）。
    //   * 不派发 Awake（旧实现用 AddComponent 同样不派发；场景构建侧也是显式 awakeStep 调用）。
    private static function cloneSubtree(root:GameObject):{root:GameObject, map:Map<UnityObject, UnityObject>} {
        var map = new Map<UnityObject, UnityObject>();
        var nodes:Array<GameObject> = [];
        collectNodes(root, nodes);

        // 1) 建克隆节点，并保留 Transform 的具体类型（RectTransform vs Transform）。
        var clones:Array<GameObject> = [];
        for (node in nodes) {
            var clone = new GameObject(node.name);
            clone.active = node.active;
            clone.layer = node.layer;
            clone.tag = node.tag;
            var origTr = node.transform;
            var newTr:Transform = Type.createInstance(Type.getClass(origTr), []);
            newTr.gameObject = clone;
            newTr.name = origTr.name;
            clone.transform = newTr;
            map.set(cast node, cast clone);
            map.set(cast origTr, cast newTr);
            clones.push(clone);
        }

        // 2) 建组件（Transform 由上面的步骤单独处理，不重复添加）。
        var compClones:Array<Array<Component>> = [];
        for (i in 0...nodes.length) {
            var list:Array<Component> = [];
            for (comp in nodes[i].GetAllComponents()) {
                if (Std.isOfType(comp, Transform))
                    continue;
                var c:Component = clones[i].AddComponent(Type.getClass(comp));
                c.name = comp.name;
                map.set(cast comp, cast c);
                list.push(c);
            }
            compClones.push(list);
        }

        // 3) 复制序列化字段（引用按 map 重映射）+ 变换布局字段。
        for (i in 0...nodes.length) {
            var srcComps = nodes[i].GetAllComponents();
            var dstComps = compClones[i];
            for (j in 0...dstComps.length) {
                copySerializedFields(srcComps[j], dstComps[j], map);
            }
            copyTransformLayout(nodes[i].transform, clones[i].transform);
        }

        // 4) 重建父子关系（父在前，故此时父级克隆已就绪）。
        for (i in 0...nodes.length) {
            var origParent = nodes[i].transform.parent;
            if (origParent == null)
                continue;
            var mapped = map.get(cast origParent);
            if (mapped != null)
                clones[i].transform.SetParent(cast mapped, false);
        }
        return {root: clones[0], map: map};
    }

    private static function collectNodes(go:GameObject, out:Array<GameObject>):Void {
        out.push(go);
        for (child in go.transform.children) {
            if (child != null && child.gameObject != null)
                collectNodes(child.gameObject, out);
        }
    }

    /** 对克隆树的全部组件派发 Awake（Unity Instantiate 语义；逐个 try/catch 隔离）。 */
    private static function awakenCloneTree(root:GameObject):Void {
        if (root == null)
            return;
        for (comp in root.GetAllComponents())
            dispatchLifecycle(comp, "Awake");
        var tr = root.transform;
        if (tr == null)
            return;
        for (child in tr.children.copy()) {
            if (child != null && child.gameObject != null)
                awakenCloneTree(child.gameObject);
        }
    }
    private static function dispatchLifecycle(comp:Component, message:String):Void {
        if (comp == null)
            return;
        var fn = Reflect.field(comp, message);
        if (fn == null || !Reflect.isFunction(fn))
            return;
        try {
            Reflect.callMethod(comp, fn, []);
        } catch (e:Dynamic) {
            Debug.LogWarning('[UnityObject] ${comp.name}.$message 派发出错：$e');
        }
    }

    private static function attachClone(root:GameObject, position:Vector3, rotation:Quaternion, parent:Transform):Void {
        if (parent != null)
            root.transform.SetParent(parent);
        if (position != null)
            root.transform.position = position;
        if (rotation != null)
            root.transform.rotation = rotation;
    }

    private static function copyTransformLayout(src:Transform, dst:Transform):Void {
        // PORT-NOTE: 显式新建 Vector/Quaternion，避免克隆体与模板共享同一个值对象
        //（unity 的 Vector2/Vector3/Quaternion 在移植层是引用类型）。
        dst.localPosition = new Vector3(src.localPosition.x, src.localPosition.y, src.localPosition.z);
        dst.localScale = new Vector3(src.localScale.x, src.localScale.y, src.localScale.z);
        dst.localRotation = new Quaternion(src.localRotation.x, src.localRotation.y, src.localRotation.z, src.localRotation.w);
        dst.position = new Vector3(src.position.x, src.position.y, src.position.z);
        dst.rotation = new Quaternion(src.rotation.x, src.rotation.y, src.rotation.z, src.rotation.w);
        if (Std.isOfType(src, RectTransform) && Std.isOfType(dst, RectTransform)) {
            var s:RectTransform = cast src;
            var d:RectTransform = cast dst;
            d.anchoredPosition = new Vector2(s.anchoredPosition.x, s.anchoredPosition.y);
            d.sizeDelta = new Vector2(s.sizeDelta.x, s.sizeDelta.y);
            d.anchorMin = new Vector2(s.anchorMin.x, s.anchorMin.y);
            d.anchorMax = new Vector2(s.anchorMax.x, s.anchorMax.y);
            d.pivot = new Vector2(s.pivot.x, s.pivot.y);
        }
    }

    private static function copySerializedFields(src:Dynamic, dst:Dynamic, map:Map<UnityObject, UnityObject>):Void {
        var cls = Type.getClass(src);
        if (cls == null)
            return;
        for (field in Type.getInstanceFields(cls)) {
            // 结构字段与运行期状态不复制（Unity 也不序列化它们）。
            if (field == "gameObject" || field == "transform" || field == "coroutineRunner"
                || field == "destroyed" || field == "name")
                continue;
            // 属性访问器对（get_x / set_x）不是字段。
            if (StringTools.startsWith(field, "get_") || StringTools.startsWith(field, "set_"))
                continue;
            var value:Dynamic = Reflect.field(src, field);
            if (!isCopyableValue(value))
                continue;
            Reflect.setField(dst, field, mapValue(value, map));
        }
    }

    private static function isCopyableValue(value:Dynamic):Bool {
        if (value == null)
            return true;
        if (Std.isOfType(value, Bool) || Std.isOfType(value, Int)
            || Std.isOfType(value, Float) || Std.isOfType(value, String))
            return true;
        if (Std.isOfType(value, Array))
            return true;
        return Std.isOfType(value, UnityObject);
    }

    private static function mapValue(value:Dynamic, map:Map<UnityObject, UnityObject>):Dynamic {
        if (value == null)
            return null;
        if (Std.isOfType(value, UnityObject)) {
            var mapped = map.get(cast value);
            return mapped != null ? mapped : value;
        }
        if (Std.isOfType(value, Array)) {
            var source:Array<Dynamic> = cast value;
            var result:Array<Dynamic> = [];
            for (element in source)
                result.push(mapValue(element, map));
            return result;
        }
        return value;
    }
    // #endregion

    public function ToString():String return name;
}

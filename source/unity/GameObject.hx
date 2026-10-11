package unity;

import flixel.group.FlxGroup;

// Minimal UnityEngine.GameObject shim (composes a FlxGroup).
class GameObject extends UnityObject {
    public var active:Bool = true;
    public var activeSelf(get, never):Bool;
    function get_activeSelf():Bool return active;
    public var activeInHierarchy(get, never):Bool;
    function get_activeInHierarchy():Bool return active && (transform == null || transform.parent == null || transform.parent.gameObject.activeInHierarchy);
    public var layer:Int = 0;
    public var tag:String = "Untagged";
    public var transform:Transform;
    public var scene:Dynamic = null;

    private var components:Array<Component> = [];

    public function new(?name:String) {
        super();
        this.name = name != null ? name : "GameObject";
        transform = new Transform();
        transform.gameObject = this;
    }

    public function SetActive(value:Bool):Void {
        if (active == value)
            return;
        // PORT-NOTE: Unity 在 activeInHierarchy 翻转时对整棵子树的组件派发
        // OnEnable / OnDisable（Translator 们正是靠它触发 TranslateComponent.Translate，
        // Collider 靠它注册/注销 shim 物理世界）。移植层原来只翻标志位，于是这些组件
        // 永远休眠（切语言 / 开对话框时文本不刷新）。这里补齐派发：
        //  * 只翻标志（不派发）用于初始化/深拷贝路径（cloneSubtree 直接写 active）；
        //  * 派发用「翻转前后 activeInHierarchy 比较」判定逐节点是否需要派发，
        //    只覆盖 activeInHierarchy 真正发生变化的节点（简化：只处理自身 active 翻转
        //    这一种触发，即 Unity 里外部整体 SetActive 子树的语义）；
        //  * 逐个组件 try/catch 隔离，与 ModelPrefabLoader.callAwake 的容错一致；
        //  * 派发期间的重入 SetActive 只翻标志不再递归派发，防止子树被重复遍历 /
        //    同一组件收到两次 OnEnable。
        var wasActiveInHierarchy = activeInHierarchy;
        active = value;
        if (dispatchDepth > 0)
            return;
        dispatchDepth++;
        try {
            dispatchActiveMessages(value, wasActiveInHierarchy);
        } catch (e:Dynamic) {
            Debug.LogWarning('[GameObject] ${name}.SetActive(${value}) 派发生命周期消息时出错：$e');
        }
        dispatchDepth--;
    }

    /** >0 表示正在派发 OnEnable/OnDisable（此期间重入的 SetActive 只翻标志、不派发）。 */
    private static var dispatchDepth:Int = 0;

    /**
     * 对 activeInHierarchy 发生翻转的子树节点派发 OnEnable（激活）/ OnDisable（失活）。
     *
     * @param activate  本次是激活（true）还是失活（false）。
     * @param wasEnabled 本节点翻转**前**的 activeInHierarchy。
     */
    private function dispatchActiveMessages(activate:Bool, wasEnabled:Bool):Void {
        var nowEnabled = activeInHierarchy;
        if (activate ? (nowEnabled && !wasEnabled) : (wasEnabled && !nowEnabled))
            dispatchComponents(activate ? "OnEnable" : "OnDisable");
        if (transform == null)
            return;
        // PORT-NOTE: 取副本再遍历 —— OnEnable/OnDisable 处理器可能增删子级
        // （与 UnityObject.destroyGameObject 的同一处理）。
        for (child in transform.children.copy()) {
            if (child == null || child.gameObject == null)
                continue;
            // active 翻转只发生在本子树的根上，其余节点的 active 标志未变，因此子节点
            // 翻转前的 activeInHierarchy = 自身 active && 父节点翻转前的 activeInHierarchy。
            child.gameObject.dispatchActiveMessages(activate, child.gameObject.active && wasEnabled);
        }
    }

    /** 按 ModelPrefabLoader.callAwake 同款反射方式给本节点组件派发一条生命周期消息。 */
    private function dispatchComponents(message:String):Void {
        for (comp in components) {
            if (comp == null)
                continue;
            var fn = Reflect.field(comp, message);
            if (fn == null || !Reflect.isFunction(fn))
                continue;
            try {
                Reflect.callMethod(comp, fn, []);
            } catch (e:Dynamic) {
                // PORT-NOTE: Unity 里单个组件的 OnEnable/OnDisable 抛异常只记日志并继续
                // 派发其余组件，不会中断整棵树的遍历。
                var label = comp.name != null && comp.name.length > 0 ? comp.name : Type.getClassName(Type.getClass(comp));
                Debug.LogWarning('[GameObject] ${label} 的 ${message} 抛出异常：$e');
            }
        }
    }

    // PORT-NOTE: 泛型参数不加 `:Component` 约束，以便查询接口类型（如 IModelComponent）。
    public function AddComponent<T>(type:Class<T>):T {
        var c:Dynamic = Type.createInstance(type, []);
        c.gameObject = this;
        c.transform = transform;
        components.push(c);
        // PORT-NOTE: 渲染桥的登记点。Unity 的 AddComponent 会把组件交给引擎（渲染器自动参与绘制），
        // 移植层没有引擎，改为在这里显式登记 SpriteRenderer，由 RenderBridge 每帧同步
        // transform/enabled 到 renderSprite（见 unity/RenderBridge.hx）。
        if (Std.isOfType(c, SpriteRenderer))
            RenderBridge.registerRenderer(cast c);
        // PORT-NOTE: 协程驱动登记点。Unity 由引擎推进场景内**全部** MonoBehaviour 的协程；
        // 移植层原先只有 `MainGameScene.behaviours`（手工 new + attach 的那批）被驱动，
        // 于是 `ScenePrefabLoader` 用 AddComponent 建出来的关卡场景树 / 页面 prefab 子树的协程
        // 永远不会恢复。这里补上同一个登记点（见 unity/BehaviourRegistry.hx）。
        BehaviourRegistry.register(c);
        return c;
    }
    public function GetComponent<T>(type:Class<T>):T {
        if (transform != null && Std.isOfType(transform, type)) return cast transform;
        for (c in components) {
            if (Std.isOfType(c, type)) return cast c;
        }
        return null;
    }
    public function GetComponents<T>(type:Class<T>):Array<T> {
        var result:Array<T> = [];
        for (c in components) {
            if (Std.isOfType(c, type)) result.push(cast c);
        }
        return result;
    }
    public function GetComponentInChildren<T>(type:Class<T>, ?includeInactive:Bool = false):T {
        var c = GetComponent(type);
        if (c != null) return c;
        for (child in transform.children) {
            if (!includeInactive && !child.gameObject.active) continue;
            c = child.gameObject.GetComponentInChildren(type, includeInactive);
            if (c != null) return c;
        }
        return null;
    }
    public function GetComponentsInChildren<T>(type:Class<T>, ?includeInactive:Bool = false):Array<T> {
        var result = GetComponents(type);
        for (child in transform.children) {
            if (!includeInactive && !child.gameObject.active) continue;
            result = result.concat(child.gameObject.GetComponentsInChildren(type, includeInactive));
        }
        return result;
    }
    public function GetComponentInParent<T>(type:Class<T>):T {
        var c = GetComponent(type);
        if (c != null) return c;
        if (transform.parent != null) return transform.parent.gameObject.GetComponentInParent(type);
        return null;
    }
    public function GetComponentsInParent<T>(type:Class<T>, ?includeInactive:Bool = false):Array<T> {
        var result = GetComponents(type);
        if (transform.parent != null) result = result.concat(transform.parent.gameObject.GetComponentsInParent(type, includeInactive));
        return result;
    }
    public function CompareTag(t:String):Bool return tag == t;

    // PORT-NOTE: Unity 的 GameObject 本身没有 gameObject 属性（那是 Component.gameObject）。
    // 移植层若干字段（如 MainmenuUI.backgroundLight、MiscAlmanacPage.entryImageRegion）在 C# 里是
    // Component/RectTransform，移植后类型放宽成了 GameObject，调用点仍写 `.gameObject.SetActive(...)`。
    // 为保持调用点与 C# 一致，这里提供返回自身的自引用。
    public var gameObject(get, never):GameObject;
    function get_gameObject():GameObject return this;

    // PORT-NOTE: exposes the attached components so that shims (e.g. unity.Physics) can
    // dispatch Unity lifecycle messages such as OnTriggerStay.
    public function GetAllComponents():Array<Component> return components;

    public static function instantiate<T:UnityObject>(original:T, ?parent:Transform):T {
        // PORT-NOTE: real prefab instantiation is handled by factories in game code.
        return original;
    }
    public static function find(name:String):GameObject {
        return null; // TODO-PORT: scene-wide lookup requires a scene registry.
    }
}

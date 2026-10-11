package unity;

// Minimal UnityEngine.Transform shim.
class Transform extends Component {
    public var parent:Transform;
    public var children:Array<Transform> = [];

    public var position:Vector3 = new Vector3();
    public var localPosition:Vector3 = new Vector3();
    public var localScale:Vector3 = new Vector3(1, 1, 1);
    public var localRotation:Quaternion = new Quaternion();
    public var rotation:Quaternion = new Quaternion();

    // PORT-NOTE(防堆损坏): 这 5 个 RectTransform 字段上移到 Transform。游戏代码大量
    // `cast transform` 成 RectTransform 后直接写字段（如 Graphic.rectTransform、
    // Tooltip.SetPosition），而 ScenePrefabLoader 对无 rect 数据的节点只建普通
    // Transform。hxcpp 的 cast 不做运行期检查，子类字段写会落在普通 Transform 的
    // 分配边界之外，踩坏相邻 GC 对象（随机段错误的根因之一）。字段上移后两类实例
    // 内存布局一致，这类 cast 在内存层面变为安全。
    public var anchoredPosition:Vector2 = new Vector2(0, 0);
    public var sizeDelta:Vector2 = new Vector2(0, 0);
    public var anchorMin:Vector2 = new Vector2(0.5, 0.5);
    public var anchorMax:Vector2 = new Vector2(0.5, 0.5);
    public var pivot:Vector2 = new Vector2(0.5, 0.5);
    public var eulerAngles(get, set):Vector3;
    function get_eulerAngles():Vector3 return rotation.eulerAngles;
    function set_eulerAngles(v:Vector3):Vector3 {
        rotation = Quaternion.EulerV(v);
        return v;
    }
    public var localEulerAngles(get, set):Vector3;
    function get_localEulerAngles():Vector3 return localRotation.eulerAngles;
    function set_localEulerAngles(v:Vector3):Vector3 {
        localRotation = Quaternion.EulerV(v);
        return v;
    }
    public var lossyScale(get, never):Vector3;
    function get_lossyScale():Vector3 {
        if (parent != null) {
            var ps = parent.lossyScale;
            return new Vector3(ps.x * localScale.x, ps.y * localScale.y, ps.z * localScale.z);
        }
        return localScale;
    }
    public var childCount(get, never):Int;
    function get_childCount():Int return children.length;
    public var root(get, never):Transform;
    function get_root():Transform return parent != null ? parent.root : this;

    public var up(get, never):Vector3;
    function get_up():Vector3 return rotation * new Vector3(0, 1, 0);
    public var right(get, never):Vector3;
    function get_right():Vector3 return rotation * new Vector3(1, 0, 0);
    public var forward(get, never):Vector3;
    function get_forward():Vector3 return rotation * new Vector3(0, 0, 1);

    // C#: public Matrix4x4 localToWorldMatrix { get; }
    // PORT-NOTE: 移植层未做完整层级矩阵级联（rotation 已并入 position），这里按 TRS 直接构造。
    public var localToWorldMatrix(get, never):Matrix4x4;
    function get_localToWorldMatrix():Matrix4x4 {
        var m = new Matrix4x4();
        m.SetTRS(position, rotation, lossyScale);
        return m;
    }
    // C#: public Matrix4x4 worldToLocalMatrix { get; }
    public var worldToLocalMatrix(get, never):Matrix4x4;
    function get_worldToLocalMatrix():Matrix4x4 return localToWorldMatrix.inverse;

    public function new() {
        super();
        // PORT-NOTE: Unity 的 Transform 是 Component，`transform.transform` 返回自身
        // （UnityEngine.Component.transform 对 Transform 组件就是 this）。shim 的
        // Component.transform 是普通字段，若不在此自赋值，任何 `someTransform.transform` 都是 null，
        // 例如 ElementListUI.updateList 的 `_template.transform.parent`（ElementListUI.hx:18）
        // 与 ElementList.updateList 的同名判断会直接空引用。
        this.transform = this;
    }

    // PORT-NOTE: 补全 Transform.Rotate（旋转由渲染层实现，这里仅保留欧拉角累计）。
    // PORT-NOTE: Unity 的 Transform.Rotate(Vector3 axis, float angle) 重载，Haxe 无法重载故改名。
    public function RotateAxis(axis:Vector3, angle:Float):Void {
        Rotate(axis.x * angle, axis.y * angle, axis.z * angle);
    }
    public function Rotate(x:Float, y:Float, z:Float):Void {
        eulerAngles = new Vector3(eulerAngles.x + x, eulerAngles.y + y, eulerAngles.z + z);
    }
    public function SetParent(p:Transform, ?worldPositionStays:Bool = true):Void {
        if (parent != null) parent.children.remove(this);
        parent = p;
        if (p != null) p.children.push(this);
    }
    public function GetChild(index:Int):Transform return children[index];
    public function GetSiblingIndex():Int {
        if (parent == null) return 0;
        return parent.children.indexOf(this);
    }
    public function SetSiblingIndex(index:Int):Void {
        if (parent == null) return;
        parent.children.remove(this);
        parent.children.insert(index, this);
    }
    public function SetAsFirstSibling():Void SetSiblingIndex(0);
    public function SetAsLastSibling():Void SetSiblingIndex(parent != null ? parent.children.length - 1 : 0);
    public function Find(n:String):Transform {
        for (c in children) if (c.name == n) return c;
        return null;
    }
    public function Translate(x:Float, y:Float, ?z:Float = 0):Void {
        position = position + new Vector3(x, y, z);
    }
    public function TransformPoint(p:Vector3):Vector3 {
        return position + p;
    }
    public function InverseTransformPoint(p:Vector3):Vector3 {
        return p - position;
    }
    public function DetachChildren():Void {
        for (c in children) c.parent = null;
        children = [];
    }
}

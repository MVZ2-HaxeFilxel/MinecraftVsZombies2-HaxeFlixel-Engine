package unity;

// Minimal UnityEngine.Vector4 shim.
@:rtti
class Vector4 {
    public var x:Float;
    public var y:Float;
    public var z:Float;
    public var w:Float;

    public static var zero(get, never):Vector4;
    public static var one(get, never):Vector4;

    public function new(x:Float = 0, y:Float = 0, z:Float = 0, w:Float = 0) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    static inline function get_zero():Vector4 return new Vector4(0, 0, 0, 0);
    static inline function get_one():Vector4 return new Vector4(1, 1, 1, 1);

    public function toString():String return '($x, $y, $z, $w)';

    @:op(A + B) public static inline function add(a:Vector4, b:Vector4):Vector4 return new Vector4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w);
    @:op(A - B) public static inline function sub(a:Vector4, b:Vector4):Vector4 return new Vector4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w);
    @:op(A * B) public static inline function mulF(a:Vector4, b:Float):Vector4 return new Vector4(a.x * b, a.y * b, a.z * b, a.w * b);

    public static function Lerp(a:Vector4, b:Vector4, t:Float):Vector4 {
        t = Mathf.Clamp01(t);
        return new Vector4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t);
    }
}

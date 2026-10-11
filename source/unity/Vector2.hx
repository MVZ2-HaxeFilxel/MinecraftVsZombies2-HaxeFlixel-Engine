package unity;

// Minimal UnityEngine.Vector2 shim (value-style class).
@:forward(x, y)
abstract Vector2(Vector2Data) from Vector2Data to Vector2Data {
    // PORT-NOTE: 补全 Unity Vector2 相关的角度旋转辅助（顺时针旋转角度，单位度）。
    public function RotateClockwise(degrees:Float):Vector2 {
        var rad = degrees * Math.PI / 180;
        var c = Math.cos(rad);
        var s2 = Math.sin(rad);
        var px = this.x;
        var py = this.y;
        return new Vector2(px * c - py * s2, px * s2 + py * c);
    }
    public static var zero(get, never):Vector2;
    public static var one(get, never):Vector2;
    public static var up(get, never):Vector2;
    public static var down(get, never):Vector2;
    public static var left(get, never):Vector2;
    public static var right(get, never):Vector2;

    public var magnitude(get, never):Float;
    public var sqrMagnitude(get, never):Float;
    public var normalized(get, never):Vector2;

    public inline function new(x:Float = 0, y:Float = 0) {
        this = new Vector2Data(x, y);
    }

    static inline function get_zero():Vector2 return new Vector2(0, 0);
    static inline function get_one():Vector2 return new Vector2(1, 1);
    static inline function get_up():Vector2 return new Vector2(0, 1);
    static inline function get_down():Vector2 return new Vector2(0, -1);
    static inline function get_left():Vector2 return new Vector2(-1, 0);
    static inline function get_right():Vector2 return new Vector2(1, 0);

    inline function get_magnitude():Float return Math.sqrt(this.x * this.x + this.y * this.y);
    inline function get_sqrMagnitude():Float return this.x * this.x + this.y * this.y;
    function get_normalized():Vector2 {
        var m = get_magnitude();
        if (m > 0) return new Vector2(this.x / m, this.y / m);
        return new Vector2(0, 0);
    }

    public function toString():String return '(${this.x}, ${this.y})';

    @:op(A + B) public static inline function add(a:Vector2, b:Vector2):Vector2 return new Vector2(a.x + b.x, a.y + b.y);
    @:op(A - B) public static inline function sub(a:Vector2, b:Vector2):Vector2 return new Vector2(a.x - b.x, a.y - b.y);
    @:op(A * B) public static inline function mulF(a:Vector2, b:Float):Vector2 return new Vector2(a.x * b, a.y * b);
    @:op(A * B) public static inline function mulF2(a:Float, b:Vector2):Vector2 return new Vector2(a * b.x, a * b.y);
    @:op(A * B) public static inline function mulV(a:Vector2, b:Vector2):Vector2 return new Vector2(a.x * b.x, a.y * b.y);
    @:op(A / B) public static inline function divF(a:Vector2, b:Float):Vector2 return new Vector2(a.x / b, a.y / b);
    @:op(A / B) public static inline function divV(a:Vector2, b:Vector2):Vector2 return new Vector2(a.x / b.x, a.y / b.y);
    @:op(-A) public static inline function neg(a:Vector2):Vector2 return new Vector2(-a.x, -a.y);
    @:op(A == B) public static inline function eq(a:Vector2, b:Vector2):Bool return a != null && b != null && a.x == b.x && a.y == b.y;
    @:op(A != B) public static inline function neq(a:Vector2, b:Vector2):Bool return !eq(a, b);

    public static function Lerp(a:Vector2, b:Vector2, t:Float):Vector2 {
        t = Mathf.Clamp01(t);
        return new Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
    }
    public static function LerpUnclamped(a:Vector2, b:Vector2, t:Float):Vector2 {
        return new Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
    }
    public static function Scale(a:Vector2, b:Vector2):Vector2 return new Vector2(a.x * b.x, a.y * b.y);
    public static function Distance(a:Vector2, b:Vector2):Float {
        var dx = a.x - b.x;
        var dy = a.y - b.y;
        return Math.sqrt(dx * dx + dy * dy);
    }
    public static function Dot(a:Vector2, b:Vector2):Float return a.x * b.x + a.y * b.y;
    public static function SqrMagnitude(a:Vector2):Float return a.x * a.x + a.y * a.y;
    public static function Angle(from:Vector2, to:Vector2):Float {
        var denom = Math.sqrt(from.sqrMagnitude * to.sqrMagnitude);
        if (denom < 1e-15) return 0;
        return Math.acos(Mathf.Clamp(Dot(from, to) / denom, -1, 1)) * 180 / Math.PI;
    }
    public static function SignedAngle(from:Vector2, to:Vector2):Float {
        var unsigned = Angle(from, to);
        return unsigned * (from.x * to.y - from.y * to.x >= 0 ? 1 : -1);
    }
}

@:rtti
class Vector2Data {
    public var x:Float;
    public var y:Float;
    public function new(x:Float = 0, y:Float = 0) {
        this.x = x;
        this.y = y;
    }
}

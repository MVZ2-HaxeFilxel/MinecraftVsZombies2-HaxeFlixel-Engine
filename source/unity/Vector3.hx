package unity;

// PORT-NOTE: ref Vector3 的引用容器 Vector3Ref 声明在 unity.RectTransformUtility 模块中（全包唯一），
// 此处按 Haxe 模块规则显式 import。
import unity.RectTransformUtility.Vector3Ref;

// Minimal UnityEngine.Vector3 shim (value-style class).
@:forward(x, y, z)
abstract Vector3(Vector3Data) from Vector3Data to Vector3Data {
    public static var zero(get, never):Vector3;
    public static var one(get, never):Vector3;
    public static var up(get, never):Vector3;
    public static var down(get, never):Vector3;
    public static var left(get, never):Vector3;
    public static var right(get, never):Vector3;
    public static var forward(get, never):Vector3;
    public static var back(get, never):Vector3;

    public var magnitude(get, never):Float;
    public var sqrMagnitude(get, never):Float;
    public var normalized(get, never):Vector3;

    public inline function new(x:Float = 0, y:Float = 0, z:Float = 0) {
        this = new Vector3Data(x, y, z);
    }

    static inline function get_zero():Vector3 return new Vector3(0, 0, 0);
    static inline function get_one():Vector3 return new Vector3(1, 1, 1);
    static inline function get_up():Vector3 return new Vector3(0, 1, 0);
    static inline function get_down():Vector3 return new Vector3(0, -1, 0);
    static inline function get_left():Vector3 return new Vector3(-1, 0, 0);
    static inline function get_right():Vector3 return new Vector3(1, 0, 0);
    static inline function get_forward():Vector3 return new Vector3(0, 0, 1);
    static inline function get_back():Vector3 return new Vector3(0, 0, -1);

    inline function get_magnitude():Float return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
    inline function get_sqrMagnitude():Float return this.x * this.x + this.y * this.y + this.z * this.z;
    function get_normalized():Vector3 {
        var m = get_magnitude();
        if (m > 0) return new Vector3(this.x / m, this.y / m, this.z / m);
        return new Vector3(0, 0, 0);
    }

    public function toString():String return '(${this.x}, ${this.y}, ${this.z})';

    @:op(A + B) public static inline function add(a:Vector3, b:Vector3):Vector3 return new Vector3(a.x + b.x, a.y + b.y, a.z + b.z);
    @:op(A - B) public static inline function sub(a:Vector3, b:Vector3):Vector3 return new Vector3(a.x - b.x, a.y - b.y, a.z - b.z);
    @:op(A * B) public static inline function mulF(a:Vector3, b:Float):Vector3 return new Vector3(a.x * b, a.y * b, a.z * b);
    @:op(A * B) public static inline function mulF2(a:Float, b:Vector3):Vector3 return new Vector3(a * b.x, a * b.y, a * b.z);
    @:op(A * B) public static inline function mulV(a:Vector3, b:Vector3):Vector3 return new Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
    @:op(A / B) public static inline function divF(a:Vector3, b:Float):Vector3 return new Vector3(a.x / b, a.y / b, a.z / b);
    @:op(A / B) public static inline function divV(a:Vector3, b:Vector3):Vector3 return new Vector3(a.x / b.x, a.y / b.y, a.z / b.z);
    @:op(-A) public static inline function neg(a:Vector3):Vector3 return new Vector3(-a.x, -a.y, -a.z);
    @:op(A == B) public static inline function eq(a:Vector3, b:Vector3):Bool return a != null && b != null && a.x == b.x && a.y == b.y && a.z == b.z;
    @:op(A != B) public static inline function neq(a:Vector3, b:Vector3):Bool return !eq(a, b);

    public static function Lerp(a:Vector3, b:Vector3, t:Float):Vector3 {
        t = Mathf.Clamp01(t);
        return new Vector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
    }
    public static function LerpUnclamped(a:Vector3, b:Vector3, t:Float):Vector3 {
        return new Vector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
    }
    public static function Scale(a:Vector3, b:Vector3):Vector3 return new Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
    public static function Distance(a:Vector3, b:Vector3):Float {
        var dx = a.x - b.x;
        var dy = a.y - b.y;
        var dz = a.z - b.z;
        return Math.sqrt(dx * dx + dy * dy + dz * dz);
    }
    public static function Dot(a:Vector3, b:Vector3):Float return a.x * b.x + a.y * b.y + a.z * b.z;
    // PORT-NOTE: C# 的 `ref Vector3 currentVelocity` → Haxe 引用容器 Vector3Ref；
    // `?maxSpeed:Float = Math.POSITIVE_INFINITY` 不是 Haxe 常量默认值，改用 null 并在函数内回落。
    public static function SmoothDamp(current:Vector3, target:Vector3, currentVelocity:Vector3Ref, smoothTime:Float, ?maxSpeed:Null<Float> = null, ?deltaTime:Float = 0.02):Vector3 {
        // PORT-NOTE: 逐分量使用 Mathf.SmoothDamp。
        var speed = maxSpeed == null ? Math.POSITIVE_INFINITY : maxSpeed;
        var vx:unity.Mathf.FloatRef = {value: currentVelocity.value.x};
        var vy:unity.Mathf.FloatRef = {value: currentVelocity.value.y};
        var vz:unity.Mathf.FloatRef = {value: currentVelocity.value.z};
        var result = new Vector3(
            Mathf.SmoothDamp(current.x, target.x, vx, smoothTime, speed, deltaTime),
            Mathf.SmoothDamp(current.y, target.y, vy, smoothTime, speed, deltaTime),
            Mathf.SmoothDamp(current.z, target.z, vz, smoothTime, speed, deltaTime));
        currentVelocity.value = new Vector3(vx.value, vy.value, vz.value);
        return result;
    }
    // PORT-NOTE: 补全 Vector3.Abs（Unity 静态方法）。
    public static function Abs(v:Vector3):Vector3 return new Vector3(Math.abs(v.x), Math.abs(v.y), Math.abs(v.z));
    // C#: public static Vector3 Max(Vector3 a, Vector3 b)
    public static function Max(a:Vector3, b:Vector3):Vector3 return new Vector3(Math.max(a.x, b.x), Math.max(a.y, b.y), Math.max(a.z, b.z));
    // C#: public static Vector3 Min(Vector3 a, Vector3 b)
    public static function Min(a:Vector3, b:Vector3):Vector3 return new Vector3(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.min(a.z, b.z));

    public static function Cross(a:Vector3, b:Vector3):Vector3 {
        return new Vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
    }
    public static function Reflect(inDirection:Vector3, inNormal:Vector3):Vector3 {
        return inDirection - inNormal * (2 * Dot(inNormal, inDirection));
    }
    // PORT-NOTE: shim 补充（Tools/Unity/PositionTranslator.cs 需要 Vector3.MoveTowards）。
    public static function MoveTowards(current:Vector3, target:Vector3, maxDistanceDelta:Float):Vector3 {
        var delta = target - current;
        var distance = delta.magnitude;
        if (distance <= maxDistanceDelta || distance == 0)
            return target;
        return current + delta * (maxDistanceDelta / distance);
    }
    @:from public static inline function fromVector2(v:Vector2):Vector3 return new Vector3(v.x, v.y, 0);
}

@:rtti
class Vector3Data {
    public var x:Float;
    public var y:Float;
    public var z:Float;
    public function new(x:Float = 0, y:Float = 0, z:Float = 0) {
        this.x = x;
        this.y = y;
        this.z = z;
    }
}

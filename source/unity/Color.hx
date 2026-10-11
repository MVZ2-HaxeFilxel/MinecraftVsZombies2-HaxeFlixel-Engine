package unity;

// PORT-NOTE: (domain C) FloatRef 是 unity.Mathf 模块内的次类型，Haxe 模块规则要求 import 模块路径。
import unity.Mathf.FloatRef;

// Minimal UnityEngine.Color shim (value-style abstract).
// PORT-NOTE: Haxe 的类不支持 @:op 运算符重载（只有 abstract 支持），而移植层的调用点使用
// `color + color` / `color * color`（如 MVZ2 的 armor tint / colorOffset 合成），因此这里与
// Vector2/Vector3 保持一致，改为 abstract Color(ColorData)。
@:forward(r, g, b, a)
abstract Color(ColorData) from ColorData to ColorData {
    public static var white(get, never):Color;
    public static var black(get, never):Color;
    public static var red(get, never):Color;
    public static var green(get, never):Color;
    public static var blue(get, never):Color;
    public static var yellow(get, never):Color;
    public static var cyan(get, never):Color;
    public static var magenta(get, never):Color;
    public static var gray(get, never):Color;
    public static var grey(get, never):Color;
    public static var clear(get, never):Color;

    public inline function new(r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 1) {
        this = new ColorData(r, g, b, a);
    }

    static inline function get_white():Color return new Color(1, 1, 1, 1);
    static inline function get_black():Color return new Color(0, 0, 0, 1);
    static inline function get_red():Color return new Color(1, 0, 0, 1);
    static inline function get_green():Color return new Color(0, 1, 0, 1);
    static inline function get_blue():Color return new Color(0, 0, 1, 1);
    static inline function get_yellow():Color return new Color(1, 235 / 255, 4 / 255, 1);
    static inline function get_cyan():Color return new Color(0, 1, 1, 1);
    static inline function get_magenta():Color return new Color(1, 0, 1, 1);
    static inline function get_gray():Color return new Color(0.5, 0.5, 0.5, 1);
    static inline function get_grey():Color return new Color(0.5, 0.5, 0.5, 1);
    static inline function get_clear():Color return new Color(0, 0, 0, 0);

    public static function Lerp(a:Color, b:Color, t:Float):Color {
        t = Mathf.Clamp01(t);
        return new Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    public static function LerpUnclamped(a:Color, b:Color, t:Float):Color {
        return new Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // UnityEngine.Color.RGBToHSV(Color, out float H, out float S, out float V)
    // PORT-NOTE: C# 的 out 参数用 unity.FloatRef（{value:Float}）承接，与 unity.Mathf.SmoothDamp 的约定一致。
    public static function RGBToHSV(rgbColor:Color, H:FloatRef, S:FloatRef, V:FloatRef):Void {
        var r = rgbColor.r;
        var g = rgbColor.g;
        var b = rgbColor.b;
        var max = Math.max(r, Math.max(g, b));
        var min = Math.min(r, Math.min(g, b));
        var delta = max - min;
        var hue:Float = 0;
        if (delta != 0) {
            if (max == r) hue = ((g - b) / delta) % 6;
            else if (max == g) hue = (b - r) / delta + 2;
            else hue = (r - g) / delta + 4;
            hue /= 6;
            if (hue < 0) hue += 1;
        }
        H.value = hue;
        S.value = max == 0 ? 0 : delta / max;
        V.value = max;
    }

    // UnityEngine.Color.HSVToRGB(float H, float S, float V)
    // PORT-NOTE: 补全 shim —— MVZ2 中有调用点（NoteBlock 等），原 shim 缺少该静态方法。
    public static function HSVToRGB(H:Float, S:Float, V:Float):Color {
        if (S <= 0) {
            return new Color(V, V, V, 1);
        }
        H = (H % 1 + 1) % 1 * 6;
        var i = Math.floor(H);
        var f = H - i;
        var p = V * (1 - S);
        var q = V * (1 - S * f);
        var t = V * (1 - S * (1 - f));
        switch (Std.int(i) % 6) {
            case 0: return new Color(V, t, p, 1);
            case 1: return new Color(q, V, p, 1);
            case 2: return new Color(p, V, t, 1);
            case 3: return new Color(p, q, V, 1);
            case 4: return new Color(t, p, V, 1);
            default: return new Color(V, p, q, 1);
        }
    }

    @:op(A + B) public static inline function add(a:Color, b:Color):Color return new Color(a.r + b.r, a.g + b.g, a.b + b.b, a.a + b.a);
    @:op(A - B) public static inline function sub(a:Color, b:Color):Color return new Color(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a);
    @:op(A * B) public static inline function mulC(a:Color, b:Color):Color return new Color(a.r * b.r, a.g * b.g, a.b * b.b, a.a * b.a);
    @:op(A * B) public static inline function mulF(a:Color, b:Float):Color return new Color(a.r * b, a.g * b, a.b * b, a.a * b);

    public function toString():String return 'RGBA(${this.r}, ${this.g}, ${this.b}, ${this.a})';
}

@:rtti
class ColorData {
    public var r:Float;
    public var g:Float;
    public var b:Float;
    public var a:Float;
    public function new(r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 1) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
}

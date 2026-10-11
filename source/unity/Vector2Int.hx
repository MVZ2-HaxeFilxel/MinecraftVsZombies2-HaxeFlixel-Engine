package unity;

// Minimal UnityEngine.Vector2Int shim.
@:rtti
class Vector2Int {
    public var x:Int;
    public var y:Int;

    public static var zero(get, never):Vector2Int;
    public static var one(get, never):Vector2Int;

    public function new(x:Int = 0, y:Int = 0) {
        this.x = x;
        this.y = y;
    }

    static inline function get_zero():Vector2Int return new Vector2Int(0, 0);
    static inline function get_one():Vector2Int return new Vector2Int(1, 1);

    public function toString():String return '($x, $y)';
}

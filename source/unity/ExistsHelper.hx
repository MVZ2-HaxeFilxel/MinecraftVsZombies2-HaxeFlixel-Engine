package unity;

// Minimal UnityEngine.Object 空引用检查辅助（对应 C# Tools 的 Exists 扩展方法）。
// C#: `unity.UnityObject.exists(obj)` → Haxe: `UnityObject.exists(obj)`（Haxe 无法在 null 上调用实例方法）。
class ExistsHelper {}

typedef RefFloat = {value:Float};

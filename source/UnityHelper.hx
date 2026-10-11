// Ported from: Assets/Scripts/Engine/Tools/Unity/UnityHelper.cs
// PORT-NOTE: 该类型在 C# 中位于全局命名空间（Tools 程序集），因此 Haxe 侧同样不使用 package。
package;

import unity.UnityObject;

/**
 * C#: `public static bool Exists(this UnityEngine.Object? it) => it;`
 * （UnityEngine.Object 重载了 bool 转换，销毁后的对象也视为不存在）
 * PORT-NOTE: Haxe 无法在 null 上调用实例方法，且既有调用点写的是 `unity.UnityObject.exists(obj)`，
 * 因此真正的实现放在 `unity.UnityObject.exists(unity.UnityObject)`（实例方法）与 `tools.ObjectExtensions.Exists`
 * （静态，供 `using tools.ObjectExtensions;` 的调用点使用）。此处保留同签名的静态入口，
 * 语义与 C# 一致：null 或已销毁 → false。
 */
class UnityHelper
{
	public static function Exists(it:UnityObject):Bool
	{
		if (it == null)
			return false;
		return unity.UnityObject.exists(it);
	}
}

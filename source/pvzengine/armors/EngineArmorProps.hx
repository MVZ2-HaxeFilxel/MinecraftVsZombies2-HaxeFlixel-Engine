// Ported from: Assets/Scripts/Engine/Level/Armors/EngineArmorProps.cs
// PORT-NOTE: C# [PropertyRegistryRegion(PropertyRegions.armor)] → @:propertyRegistryRegion（与上层 Vanilla*Props 的约定一致）。
// PORT-NOTE: C# PropertyMeta<T> 到 PropertyKey<T> 的隐式转换由移植层 pvzengine.PropertyMeta 的转换定义承担。
// PORT-NOTE: C# 的扩展方法（GetShellID / GetTint / SetTint / GetColorOffset / SetColorOffset / GetMaxHealth）
//   移植为静态方法（首参数为目标对象），可用 `using pvzengine.armors.EngineArmorProps;` 以实例形式调用；
//   既有调用点（armor.GetTint() 等，文件里没有 using）由 Armor.hx 的兼容转发方法满足。
// PORT-NOTE: C# 重载 GetShellID(ArmorDefinition) / GetShellID(Armor, bool) 在 Haxe 中合并为一个 Dynamic 形参的方法。
package pvzengine.armors;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import unity.Color;

@:propertyRegistryRegion(PropertyRegions.armor)
class EngineArmorProps
{
	private static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var TINT:PropertyMeta<Color> = Get("tint", Color.white);
	public static var COLOR_OFFSET:PropertyMeta<Color> = Get("colorOffset", new Color(0, 0, 0, 0));
	public static var MAX_HEALTH:PropertyMeta<Float> = Get("maxHealth", 0.0);
	public static var SHELL:PropertyMeta<NamespaceID> = Get("shell");
	// C#: NamespaceID? GetShellID(this ArmorDefinition definition) / NamespaceID? GetShellID(this Armor armor, bool ignoreBuffs = false)
	public static function GetShellID(target:Dynamic, ignoreBuffs:Bool = false):Null<NamespaceID>
	{
		if (Std.isOfType(target, ArmorDefinition))
		{
			var definition:ArmorDefinition = cast target;
			return definition.GetProperty(SHELL);
		}
		var armor:Armor = cast target;
		return armor.GetProperty(SHELL, ignoreBuffs);
	}
	public static function GetTint(armor:Armor, ignoreBuffs:Bool = false):Color
	{
		return armor.GetProperty(TINT, ignoreBuffs);
	}
	public static function SetTint(armor:Armor, value:Color):Void
	{
		armor.SetProperty(TINT, value);
	}
	public static function GetColorOffset(armor:Armor, ignoreBuffs:Bool = false):Color
	{
		return armor.GetProperty(COLOR_OFFSET, ignoreBuffs);
	}
	public static function SetColorOffset(armor:Armor, value:Color):Void
	{
		armor.SetProperty(COLOR_OFFSET, value);
	}
	public static function GetMaxHealth(armor:Armor, ignoreBuffs:Bool = false):Float
	{
		return armor.GetProperty(MAX_HEALTH, ignoreBuffs);
	}
}

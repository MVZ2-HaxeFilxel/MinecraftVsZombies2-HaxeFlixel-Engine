// Ported from: Assets/Scripts/Logic/Armors/LogicArmorProps.cs
package mvz2logic.armors;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.armors.Armor;
import pvzengine.armors.ArmorDefinition;

@:propertyRegistryRegion(PropertyRegions.armor)
class LogicArmorProps
{
	static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	public static var ARMOR_TYPE:PropertyMeta<NamespaceID> = Get("armor_type");
	// PORT-NOTE: C# 扩展方法 this ArmorDefinition armor -> 静态方法
	public static function GetArmorType(armor:ArmorDefinition):Null<NamespaceID>
	{
		return armor.GetProperty(ARMOR_TYPE);
	}
	public static function SetArmorType(armor:ArmorDefinition, value:Null<NamespaceID>):Void
	{
		armor.SetProperty(ARMOR_TYPE, value);
	}

	public static var IGNORED:PropertyMeta<Bool> = Get("ignored", false);
	public static function IsIgnoredArmorDefinition(armor:ArmorDefinition):Bool
	{
		return armor.GetProperty(IGNORED);
	}
	public static function IsIgnoredArmor(armor:Armor):Bool
	{
		return armor.GetProperty(IGNORED);
	}
	public static function SetIgnored(armor:ArmorDefinition, value:Bool):Void
	{
		armor.SetProperty(IGNORED, value);
	}
}

// Ported from: Assets/Scripts/Logic/Blueprints/LogicSeedOptionProps.cs
package mvz2logic.blueprints;

import mvz2logic.LogicPropertyRegions;
import mvz2logic.resources.SpriteReference;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;

@:propertyRegistryRegion(LogicPropertyRegions.seedOption)
class LogicSeedOptionProps
{
	static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var NAME:PropertyMeta<String> = Get("name");
	public static function GetOptionName(definition:SeedOptionDefinition):Null<String>
	{
		return definition.GetProperty(NAME);
	}
	public static var TOOLTIP:PropertyMeta<String> = Get("tooltip");
	public static function GetOptionTooltip(definition:SeedOptionDefinition):Null<String>
	{
		return definition.GetProperty(TOOLTIP);
	}
	public static var ICON:PropertyMeta<SpriteReference> = Get("icon");
	public static function GetIcon(definition:SeedOptionDefinition):Null<SpriteReference>
	{
		return definition.GetProperty(ICON);
	}
	public static var MOBILE_ICON:PropertyMeta<SpriteReference> = Get("mobile_icon");
	public static function GetMobileIcon(definition:SeedOptionDefinition):Null<SpriteReference>
	{
		return definition.GetProperty(MOBILE_ICON);
	}

	public static var MODEL_ID:PropertyMeta<NamespaceID> = Get("model_id");
	public static function GetModelID(definition:SeedOptionDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(MODEL_ID);
	}

	public static var COST:PropertyMeta<Int> = Get("cost", 0);
	public static function GetCost(definition:SeedOptionDefinition):Int
	{
		return definition.GetProperty(COST);
	}

	private function new() {}
}

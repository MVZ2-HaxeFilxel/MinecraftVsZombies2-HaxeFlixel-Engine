// Ported from: Assets/Scripts/Logic/Difficulty/LogicDifficultyProps.cs
package mvz2logic.difficulties;

import mvz2logic.resources.SpriteReference;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.difficulties.DifficultyDefinition;

@:propertyRegistryRegion(PropertyRegions.difficulty)
class LogicDifficultyProps
{
	public static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var NAME:PropertyMeta<String> = Get("name");
	// PORT-NOTE: C# 扩展方法 -> 静态方法
	public static function GetName(def:DifficultyDefinition):Null<String> return def.GetProperty(NAME);
	public static var VALUE:PropertyMeta<Int> = Get("value", 0);
	public static function GetValue(def:DifficultyDefinition):Int return def.GetProperty(VALUE);
	public static var CLEAR_MONEY:PropertyMeta<Int> = Get("clear_money", 0);
	public static function GetClearMoney(def:DifficultyDefinition):Int return def.GetProperty(CLEAR_MONEY);
	public static var CART_CONVERT_MONEY:PropertyMeta<Int> = Get("cart_convert_money", 0);
	public static function GetCartConvertMoney(def:DifficultyDefinition):Int return def.GetProperty(CART_CONVERT_MONEY);
	public static var RERUN_CLEAR_MONEY:PropertyMeta<Int> = Get("rerun_clear_money", 0);
	public static function GetRerunClearMoney(def:DifficultyDefinition):Int return def.GetProperty(RERUN_CLEAR_MONEY);

	public static var PUZZLE_MONEY:PropertyMeta<Int> = Get("puzzle_money", 0);
	public static function GetPuzzleMoney(def:DifficultyDefinition):Int return def.GetProperty(PUZZLE_MONEY);

	public static var BUFF_ID:PropertyMeta<NamespaceID> = Get("buff_id");
	public static function GetBuffID(def:DifficultyDefinition):Null<NamespaceID> return def.GetProperty(BUFF_ID);
	public static var I_ZOMBIE_BUFF_ID:PropertyMeta<NamespaceID> = Get("i_zombie_buff_id");
	public static function GetIZombieBuffID(def:DifficultyDefinition):Null<NamespaceID> return def.GetProperty(I_ZOMBIE_BUFF_ID);

	public static var MAP_BUTTON_BORDER_BACK:PropertyMeta<SpriteReference> = Get("map_button_border_back");
	public static function GetMapButtonBorderBack(def:DifficultyDefinition):Null<SpriteReference> return def.GetProperty(MAP_BUTTON_BORDER_BACK);
	public static var MAP_BUTTON_BORDER_BOTTOM:PropertyMeta<SpriteReference> = Get("map_button_border_bottom");
	public static function GetMapButtonBorderBottom(def:DifficultyDefinition):Null<SpriteReference> return def.GetProperty(MAP_BUTTON_BORDER_BOTTOM);
	public static var MAP_BUTTON_BORDER_OVERLAY:PropertyMeta<SpriteReference> = Get("map_button_border_overlay");
	public static function GetMapButtonBorderOverlay(def:DifficultyDefinition):Null<SpriteReference> return def.GetProperty(MAP_BUTTON_BORDER_OVERLAY);
	public static var ARCADE_ICON:PropertyMeta<SpriteReference> = Get("arcade_icon");
	public static function GetArcadeIcon(def:DifficultyDefinition):Null<SpriteReference> return def.GetProperty(ARCADE_ICON);
}

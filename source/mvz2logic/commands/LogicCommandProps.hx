// Ported from: Assets/Scripts/Logic/Command/LogicCommandProps.cs
package mvz2logic.commands;

import mvz2logic.LogicPropertyRegions;
import pvzengine.PropertyMeta;

@:propertyRegistryRegion(LogicPropertyRegions.command)
class LogicCommandProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	// #region 描述
	public static var DESCRIPTION:PropertyMeta<String> = Get("description");
	// PORT-NOTE: C# 扩展方法 -> 静态方法
	public static function GetDescription(def:CommandDefinition):Null<String> return def.GetProperty(DESCRIPTION);
	public static function SetDescription(def:CommandDefinition, value:String):Void def.SetProperty(DESCRIPTION, value);
	// #endregion

	// #region 必须在关卡中
	public static var MUST_IN_LEVEL:PropertyMeta<Bool> = Get("must_in_level", false);
	public static function MustInLevel(def:CommandDefinition):Bool return def.GetProperty(MUST_IN_LEVEL);
	// #endregion

	// #region 变体
	public static var VARIANTS:PropertyMeta<Array<ICommandVariantMeta>> = Get("variants");
	public static function GetVariants(def:CommandDefinition):Null<Array<ICommandVariantMeta>> return def.GetProperty(VARIANTS);
	// #endregion
}

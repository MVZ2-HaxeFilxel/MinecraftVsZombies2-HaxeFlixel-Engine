// Ported from: Assets/Scripts/Logic/Options/LogicOptionWidgetProps.cs
// PORT-NOTE: 原文 namespace 为 MVZ2Logic.Commands（虽然文件位于 Options 目录），因此目标包为 mvz2logic.commands。
package mvz2logic.commands;

import mvz2logic.LogicPropertyRegions;
import mvz2logic.options.OptionWidgetDefinition;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;

@:propertyRegistryRegion(LogicPropertyRegions.optionWidget)
class LogicOptionWidgetProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	// #region 标签
	public static var LABEL:PropertyMeta<String> = Get("label");
	// PORT-NOTE: C# 扩展方法 -> 静态方法
	public static function GetLabel(def:OptionWidgetDefinition):Null<String> return def.GetProperty(LABEL);
	// #endregion

	// #region 工具提示
	public static var TOOLTIP:PropertyMeta<String> = Get("tooltip");
	public static function GetTooltip(def:OptionWidgetDefinition):Null<String> return def.GetProperty(TOOLTIP);
	// #endregion

	// #region 分类ID
	public static var CATEGORY_ID:PropertyMeta<NamespaceID> = Get("category_id");
	public static function GetCategoryID(def:OptionWidgetDefinition):Null<NamespaceID> return def.GetProperty(CATEGORY_ID);
	// #endregion

	// #region 滑动条
	public static var SLIDER_WHOLE_NUMBERS:PropertyMeta<Bool> = Get("slider_whole_numbers", false);
	public static function IsSliderWholeNumbers(def:OptionWidgetDefinition):Bool return def.GetProperty(SLIDER_WHOLE_NUMBERS);
	public static var SLIDER_MIN_VALUE:PropertyMeta<Float> = Get("slider_min_value", 0.0);
	public static function GetSliderMinValue(def:OptionWidgetDefinition):Float return def.GetProperty(SLIDER_MIN_VALUE);
	public static var SLIDER_MAX_VALUE:PropertyMeta<Float> = Get("slider_max_value", 0.0);
	public static function GetSliderMaxValue(def:OptionWidgetDefinition):Float return def.GetProperty(SLIDER_MAX_VALUE);
	// #endregion

	// #region 工具提示
	public static var ORDER:PropertyMeta<Int> = Get("order", 0);
	public static function GetOrder(def:OptionWidgetDefinition):Int return def.GetProperty(ORDER);
	// #endregion

}

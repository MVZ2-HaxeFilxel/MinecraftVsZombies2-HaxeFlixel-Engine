// Ported from: Assets/Scripts/Vanilla/Frameworks/Level/VanillaAreaProps.cs
package mvz2.vanilla.level;

import mvz2logic.Global;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.level.LevelEngine;
import unity.Color;

// PORT-NOTE: C# 的扩展方法 Global.Options.HasBloodAndGore() → LogicOptionExt.HasBloodAndGore(options)，沿用扩展方法调用形式。
using mvz2logic.options.LogicOptionExt;

@:propertyRegistryRegion(PropertyRegions.level)
class VanillaAreaProps
{
    static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }

    //region 水颜色
    public static var WATER_COLOR:PropertyMeta<Color> = Get("waterColor", new Color(0, 0, 0, 0));
    public static var WATER_COLOR_CENSORED:PropertyMeta<Color> = Get("waterColorCensored", new Color(0, 0, 0, 0));
    public static function GetWaterColorNormal(game:LevelEngine):Color
    {
        return game.GetProperty(WATER_COLOR);
    }
    public static function GetWaterColorCensored(game:LevelEngine):Color
    {
        return game.GetProperty(WATER_COLOR_CENSORED);
    }
    public static function GetWaterColor(game:LevelEngine):Color
    {
        return Global.Options.HasBloodAndGore() ? GetWaterColorNormal(game) : GetWaterColorCensored(game);
    }
    //endregion
}

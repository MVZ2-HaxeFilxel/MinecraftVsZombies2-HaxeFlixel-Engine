// Ported from: Assets/Scripts/Vanilla/Frameworks/Level/VanillaLevelProps.cs
package mvz2.vanilla.level;

import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.level.LevelEngine;

@:propertyRegistryRegion(PropertyRegions.level)
class VanillaLevelProps
{
    static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }

    //region 雕像数量
    public static var STATUE_COUNT:PropertyMeta<Int> = Get("statueCount", 0);
    public static function GetStatueCount(level:LevelEngine):Int
    {
        return level.GetProperty(STATUE_COUNT);
    }
    //endregion

    //region 刷怪笼数量
    public static var SPAWNER_COUNT:PropertyMeta<Int> = Get("spawnerCount", 0);
    public static function GetSpawnerCount(level:LevelEngine):Int
    {
        return level.GetProperty(SPAWNER_COUNT);
    }
    //endregion

    //region 上帝模式
    public static var GRID_FIRE_ADVICED:PropertyMeta<Bool> = Get("grid_fire_adviced", false);
    public static function IsGridFireAdviced(level:LevelEngine):Bool
    {
        return level.GetProperty(GRID_FIRE_ADVICED);
    }
    public static function SetGridFireAdviced(level:LevelEngine, value:Bool):Void
    {
        level.SetProperty(GRID_FIRE_ADVICED, value);
    }
    //endregion
}

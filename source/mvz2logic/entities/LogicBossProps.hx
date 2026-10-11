// Ported from: Assets/Scripts/Logic/Entities/LogicBossProps.cs
package mvz2logic.entities;

import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;

@:propertyRegistryRegion(PropertyRegions.entity)
class LogicBossProps
{
	static function Get<T>(name:String, ?defaultValue:T, ?obsoleteNames:Array<String>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue, obsoleteNames);
	}

	//region 无害
	public static var DONT_COUNT_BOSS_HP:PropertyMeta<Bool> = Get("dont_count_boss_hp", false);
	public static function DontCountBossHP(enemy:Entity):Bool
	{
		return enemy.GetProperty(DONT_COUNT_BOSS_HP);
	}
	//endregion

	private function new() {}
}

// Ported from: Assets/Scripts/Vanilla/Frameworks/Enemies/VanillaEnemyProps.cs
package mvz2.vanilla.enemies;

import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;

@:propertyRegistryRegion(PropertyRegions.entity)
class VanillaEnemyProps
{
    private static function Get<T>(name:String, ?defaultValue:T, ?obsoleteNames:Array<String>):PropertyMeta<T>
    {
        return new VanillaEntityPropertyMeta<T>(name, defaultValue, obsoleteNames);
    }
    public static var SPEED:PropertyMeta<Float> = Get("speed", 0.0);
    public static var CAN_ARMOR:PropertyMeta<Bool> = Get("canArmor", false);
    public static var MAX_ATTACK_HEIGHT:PropertyMeta<Float> = Get("maxAttackHeight", 0.0);
    public static var NO_REWARD:PropertyMeta<Bool> = Get("noReward", false);
    public static var DEATH_MESSAGE:PropertyMeta<String> = Get("deathMessage");
    public static var IS_NEUTRALIZED:PropertyMeta<Bool> = Get("isNeutralized", false);
    public static var EXCLUDED_AREA_TAGS:PropertyMeta<Array<NamespaceID>> = Get("excludedAreaTags");
    // C#: extension method GetSpeed(this Entity enemy, bool ignoreBuffs = false)
    public static function GetSpeed(enemy:Entity, ignoreBuffs:Bool = false):Float
    {
        return enemy.GetProperty(SPEED, ignoreBuffs);
    }
    // C#: extension method GetMaxAttackHeight(this Entity enemy)
    public static function GetMaxAttackHeight(enemy:Entity):Float
    {
        return enemy.GetProperty(MAX_ATTACK_HEIGHT);
    }
    // C#: extension method HasNoReward(this Entity enemy)
    public static function HasNoReward(enemy:Entity):Bool
    {
        return enemy.GetProperty(NO_REWARD);
    }
    // C#: extension method SetNeutralized(this Entity enemy, bool value)
    public static function SetNeutralized(enemy:Entity, value:Bool):Void
    {
        enemy.SetProperty(IS_NEUTRALIZED, value);
    }
    // C#: extension method IsNeutralized(this Entity enemy)
    public static function IsNeutralized(enemy:Entity):Bool
    {
        return enemy.GetProperty(IS_NEUTRALIZED);
    }
    // C#: extension method GetExcludedAreaTags(this EntityDefinition definition)
    public static function GetExcludedAreaTags(definition:EntityDefinition):Null<Array<NamespaceID>>
    {
        return definition.GetProperty(EXCLUDED_AREA_TAGS);
    }
    // #region 初始盔甲
    public static var STARTING_ARMOR:PropertyMeta<NamespaceID> = Get("starting_armor");
    // C#: extension method GetStartingArmor(this EntityDefinition definition)
    public static function GetStartingArmorOfDefinition(definition:EntityDefinition):Null<NamespaceID>
    {
        return definition.GetProperty(STARTING_ARMOR);
    }
    // C#: extension method GetStartingArmor(this Entity enemy)
    // PORT-NOTE: Haxe has no method overloading; overloads split by parameter type.
    public static function GetStartingArmor(enemy:Entity):Null<NamespaceID>
    {
        return enemy.GetProperty(STARTING_ARMOR);
    }
    // #endregion

    // #region 初始护盾
    public static var STARTING_SHIELD:PropertyMeta<NamespaceID> = Get("starting_shield");
    // C#: extension method GetStartingShield(this EntityDefinition definition)
    public static function GetStartingShieldOfDefinition(definition:EntityDefinition):Null<NamespaceID>
    {
        return definition.GetProperty(STARTING_SHIELD);
    }
    // C#: extension method GetStartingShield(this Entity enemy)
    public static function GetStartingShield(enemy:Entity):Null<NamespaceID>
    {
        return enemy.GetProperty(STARTING_SHIELD);
    }
    // #endregion

    // #region 低矮
    public static var LOW_ENEMY:PropertyMeta<Bool> = Get("low_enemy", false);
    // C#: extension method IsLowEnemy(this EntityDefinition enemy)
    public static function IsLowEnemy(enemy:EntityDefinition):Bool
    {
        return enemy.GetProperty(LOW_ENEMY);
    }
    // #endregion

    // #region 飞行
    public static var FLYING_ENEMY:PropertyMeta<Bool> = Get("flying_enemy", false);
    // C#: extension method IsFlyingEnemy(this EntityDefinition enemy)
    public static function IsFlyingEnemy(enemy:EntityDefinition):Bool
    {
        return enemy.GetProperty(FLYING_ENEMY);
    }
    // #endregion

    // #region 不与行对齐
    public static var NO_ALIGN_TO_LANE:PropertyMeta<Bool> = Get("no_align_to_lane", false);
    // C#: extension method NoAlignToLane(this Entity enemy)
    public static function NoAlignToLane(enemy:Entity):Bool
    {
        return enemy.GetProperty(NO_ALIGN_TO_LANE);
    }
    // C#: extension method NoAlignToLane(this EntityDefinition enemy)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to NoAlignToLaneOfDefinition.
    public static function NoAlignToLaneOfDefinition(enemy:EntityDefinition):Bool
    {
        return enemy.GetProperty(NO_ALIGN_TO_LANE);
    }
    // #endregion

    // #region 状态覆盖
    public static var STATE_OVERRIDE:PropertyMeta<Int> = Get("state_override", -1);
    // C#: extension method GetStateOverride(this Entity enemy)
    public static function GetStateOverride(enemy:Entity):Int
    {
        return enemy.GetProperty(STATE_OVERRIDE);
    }
    // #endregion

    // #region 施法
    public static var CASTING:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("casting");
    // C#: extension method IsCasting(this Entity enemy)
    public static function IsCasting(enemy:Entity):Bool
    {
        return enemy.GetProperty(CASTING);
    }
    // C#: extension method SetCasting(this Entity enemy, bool value)
    public static function SetCasting(enemy:Entity, value:Bool):Void
    {
        enemy.SetProperty(CASTING, value);
    }
    // #endregion

    public static var IMMUNE_VORTEX:PropertyMeta<Bool> = Get("immuneVortex", false);
    // C#: extension method ImmuneVortex(this Entity enemy)
    public static function ImmuneVortex(enemy:Entity):Bool
    {
        return enemy.GetProperty(IMMUNE_VORTEX);
    }

    // #region 免疫减速
    public static var IMMUNE_SLOWING:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("immune_slowing");
    // C#: extension method ImmuneSlowing(this Entity enemy)
    public static function ImmuneSlowing(enemy:Entity):Bool
    {
        return enemy.GetProperty(IMMUNE_SLOWING);
    }
    // C#: extension method SetImmuneSlowing(this Entity enemy, bool value)
    public static function SetImmuneSlowing(enemy:Entity, value:Bool):Void
    {
        enemy.SetProperty(IMMUNE_SLOWING, value);
    }
    // #endregion
}

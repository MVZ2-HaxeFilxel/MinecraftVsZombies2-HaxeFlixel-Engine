// Ported from: Assets/Scripts/Vanilla/Frameworks/Entities/VanillaEntityProps.cs
package mvz2.vanilla.entities;

import mvz2logic.Global;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;
import unity.Color;
import unity.Mathf;
import unity.Vector3;

// PORT-NOTE: C# 的扩展方法 Global.Options.HasBloodAndGore() → LogicOptionExt.HasBloodAndGore(options)，沿用扩展方法调用形式。
using mvz2logic.options.LogicOptionExt;

@:propertyRegistryRegion(PropertyRegions.entity)
class VanillaEntityProps
{
    private static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }
    public static var MASS:PropertyMeta<Float> = Get("mass", 0.0);
    // C#: extension method SetMass(this Entity entity, float value)
    public static function SetMass(entity:Entity, value:Float):Void
    {
        entity.SetProperty(MASS, value);
    }
    // C#: extension method GetMass(this EntityDefinition definition)
    public static function GetMassOfDefinition(definition:EntityDefinition):Float
    {
        return definition.GetProperty(MASS);
    }
    // C#: extension method GetMass(this Entity entity)
    // PORT-NOTE: Haxe has no method overloading; overloads split by first parameter type.
    public static function GetMass(entity:Entity):Float
    {
        return entity.GetProperty(MASS);
    }
    // C#: extension method GetKnockbackMultiplier(this Entity entity, float massMultiplier)
    public static function GetKnockbackMultiplier(entity:Entity, massMultiplier:Float):Float
    {
        var mass = GetMass(entity);
        return Mathf.Max(0, 2 - Mathf.Pow(2, mass * massMultiplier));
    }
    // C#: extension method GetWeakKnockbackMultiplier(this Entity entity) => entity.GetKnockbackMultiplier(1)
    public static function GetWeakKnockbackMultiplier(entity:Entity):Float
    {
        return GetKnockbackMultiplier(entity, 1);
    }
    // C#: extension method GetStrongKnockbackMultiplier(this Entity entity) => entity.GetKnockbackMultiplier(0.5f)
    public static function GetStrongKnockbackMultiplier(entity:Entity):Float
    {
        return GetKnockbackMultiplier(entity, 0.5);
    }

    // #region 吹动质量
    public static var BLOW_MASS_OFFSET:PropertyMeta<Float> = Get("blow_mass_offset", 0.0);
    // C#: extension method SetBlowMassOffset(this Entity entity, float value)
    public static function SetBlowMassOffset(entity:Entity, value:Float):Void
    {
        entity.SetProperty(BLOW_MASS_OFFSET, value);
    }
    // C#: extension method GetBlowMassOffset(this EntityDefinition definition)
    public static function GetBlowMassOffsetOfDefinition(definition:EntityDefinition):Float
    {
        return definition.GetProperty(BLOW_MASS_OFFSET);
    }
    // C#: extension method GetBlowMassOffset(this Entity entity)
    public static function GetBlowMassOffset(entity:Entity):Float
    {
        return entity.GetProperty(BLOW_MASS_OFFSET);
    }
    // #endregion

    // #region 射击
    public static var SHOT_PIVOT_DEFAULT:Vector3 = new Vector3(0.5, 0.5, 0.5);
    public static var SHOT_PIVOT_BOTTOM:Vector3 = new Vector3(0.5, 0, 0.5);
    public static var RANGE:PropertyMeta<Float> = Get("range", 0.0);
    public static var SHOT_VELOCITY:PropertyMeta<Vector3> = Get("shotVelocity", new Vector3(0, 0, 0));
    public static var SHOT_OFFSET:PropertyMeta<Vector3> = Get("shotOffset", new Vector3(0, 0, 0));
    public static var SHOT_PIVOT:PropertyMeta<Vector3> = Get("shot_pivot", SHOT_PIVOT_DEFAULT);
    public static var SHOOT_SOUND:PropertyMeta<NamespaceID> = Get("shootSound");
    public static var PROJECTILE_ID:PropertyMeta<NamespaceID> = Get("projectileId");
    // C#: extension method SetRange(this Entity entity, float value)
    public static function SetRange(entity:Entity, value:Float):Void
    {
        entity.SetProperty(RANGE, value);
    }
    // C#: extension method GetRange(this Entity entity)
    public static function GetRange(entity:Entity):Float
    {
        return entity.GetProperty(RANGE);
    }
    // C#: extension method GetShotVelocity(this Entity entity)
    public static function GetShotVelocity(entity:Entity):Vector3
    {
        return entity.GetProperty(SHOT_VELOCITY);
    }
    // C#: extension method GetShotOffset(this Entity entity, bool ignoreBuffs = false)
    public static function GetShotOffset(entity:Entity, ignoreBuffs:Bool = false):Vector3
    {
        return entity.GetProperty(SHOT_OFFSET, ignoreBuffs);
    }
    // C#: extension method GetShotPivot(this Entity entity, bool ignoreBuffs = false)
    public static function GetShotPivot(entity:Entity, ignoreBuffs:Bool = false):Vector3
    {
        return entity.GetProperty(SHOT_PIVOT, ignoreBuffs);
    }
    // C#: extension method GetShootSound(this Entity entity)
    public static function GetShootSound(entity:Entity):Null<NamespaceID>
    {
        return entity.GetProperty(SHOOT_SOUND);
    }
    // C#: extension method GetProjectileID(this Entity entity)
    public static function GetProjectileID(entity:Entity):Null<NamespaceID>
    {
        return entity.GetProperty(PROJECTILE_ID);
    }
    // #endregion

    // #region 攻击
    public static var DAMAGE:PropertyMeta<Float> = Get("damage", 0.0);
    public static var ATTACK_SPEED:PropertyMeta<Float> = Get("attackSpeed", 0.0);

    // C#: extension method GetDamage(this EntityDefinition entity)
    public static function GetDamageOfDefinition(entity:EntityDefinition):Float
    {
        return entity.GetProperty(DAMAGE);
    }
    // C#: extension method GetDamage(this Entity entity, bool ignoreBuffs = false)
    public static function GetDamage(entity:Entity, ignoreBuffs:Bool = false):Float
    {
        return entity.GetProperty(DAMAGE, ignoreBuffs);
    }
    // C#: extension method SetDamage(this Entity entity, float value)
    public static function SetDamage(entity:Entity, value:Float):Void
    {
        entity.SetProperty(DAMAGE, value);
    }
    // C#: extension method GetAttackSpeed(this Entity entity, bool ignoreBuffs = false)
    public static function GetAttackSpeed(entity:Entity, ignoreBuffs:Bool = false):Float
    {
        return entity.GetProperty(ATTACK_SPEED, ignoreBuffs);
    }
    // #endregion

    // #region 摔落
    public static var FALL_RESISTANCE:PropertyMeta<Float> = Get("fallResistance", 0.0);
    // C#: extension method GetFallResistance(this Entity entity)
    public static function GetFallResistance(entity:Entity):Float
    {
        return entity.GetProperty(FALL_RESISTANCE);
    }
    // C#: extension method SetFallResistance(this Entity entity, float value)
    public static function SetFallResistance(entity:Entity, value:Float):Void
    {
        entity.SetProperty(FALL_RESISTANCE, value);
    }
    // #endregion

    // #region 沉没
    public static var WATER_INTERACTION:PropertyMeta<Int> = Get("waterInteraction", 0);
    // C#: extension method GetWaterInteraction(this EntityDefinition entityDef)
    public static function GetWaterInteractionOfDefinition(entityDef:EntityDefinition):Int
    {
        return entityDef.GetProperty(WATER_INTERACTION);
    }
    // C#: extension method GetWaterInteraction(this Entity entity)
    public static function GetWaterInteraction(entity:Entity):Int
    {
        return entity.GetProperty(WATER_INTERACTION);
    }
    // C#: extension method SetWaterInteraction(this Entity entity, int value)
    public static function SetWaterInteraction(entity:Entity, value:Int):Void
    {
        entity.SetProperty(WATER_INTERACTION, value);
    }
    // #endregion

    // #region 沉没（空中）
    public static var AIR_INTERACTION:PropertyMeta<Int> = Get("airInteraction", 0);
    // C#: extension method GetAirInteraction(this EntityDefinition entityDef)
    public static function GetAirInteractionOfDefinition(entityDef:EntityDefinition):Int
    {
        return entityDef.GetProperty(AIR_INTERACTION);
    }
    // C#: extension method GetAirInteraction(this Entity entity)
    public static function GetAirInteraction(entity:Entity):Int
    {
        return entity.GetProperty(AIR_INTERACTION);
    }
    // C#: extension method SetAirInteraction(this Entity entity, int value)
    public static function SetAirInteraction(entity:Entity, value:Int):Void
    {
        entity.SetProperty(AIR_INTERACTION, value);
    }
    // #endregion

    // #region 车辆
    public static var VEHICLE_INTERACTION:PropertyMeta<Int> = Get("vehicleInteraction", 0);
    // C#: extension method GetVehicleInteraction(this Entity entity)
    public static function GetVehicleInteraction(entity:Entity):Int
    {
        return entity.GetProperty(VEHICLE_INTERACTION);
    }
    // #endregion

    // #region 虚无
    public static var ETHEREAL:PropertyMeta<Bool> = Get("ethereal", false);
    // C#: extension method IsEthereal(this Entity entity)
    public static function IsEthereal(entity:Entity):Bool
    {
        return entity.GetProperty(ETHEREAL);
    }
    // #endregion

    // #region 生产
    public static var PRODUCE_SPEED:PropertyMeta<Float> = Get("produceSpeed", 0.0);
    // C#: extension method GetProduceSpeed(this Entity entity)
    public static function GetProduceSpeed(entity:Entity):Float
    {
        return entity.GetProperty(PRODUCE_SPEED);
    }
    // #endregion

    // #region 索敌
    public static var INVISIBLE:PropertyMeta<Bool> = Get("invisible", false);
    public static var AI_FROZEN:PropertyMeta<Bool> = Get("aiFrozen", false);

    // C#: extension method IsInvisible(this Entity entity)
    public static function IsInvisible(entity:Entity):Bool
    {
        return entity.GetProperty(INVISIBLE);
    }
    // C#: extension method IsAIFrozen(this Entity entity)
    public static function IsAIFrozen(entity:Entity):Bool
    {
        return entity.GetProperty(AI_FROZEN);
    }
    // #endregion

    // #region 换行
    public static var CHANGE_LANE_SPEED:PropertyMeta<Float> = Get("changeLaneSpeed", 0.0);
    // C#: extension method GetChangeLaneSpeed(this Entity entity) => entity.GetProperty<float>(VanillaEntityProps.CHANGE_LANE_SPEED)
    public static function GetChangeLaneSpeed(entity:Entity):Float
    {
        return entity.GetProperty(VanillaEntityProps.CHANGE_LANE_SPEED);
    }
    // #endregion

    // #region 时限
    public static var MAX_TIMEOUT:PropertyMeta<Int> = Get("maxTimeout", 0);
    // C#: extension method GetMaxTimeout(this Entity entity)
    public static function GetMaxTimeout(entity:Entity):Int
    {
        return entity.GetProperty(MAX_TIMEOUT);
    }
    // #endregion

    // #region 亡灵
    public static var IS_UNDEAD:PropertyMeta<Bool> = Get("undead", false);
    // C#: extension method SetIsUndead(this Entity entity, bool value)
    public static function SetIsUndead(entity:Entity, value:Bool):Void
    {
        entity.SetProperty(IS_UNDEAD, value);
    }
    // C#: extension method IsUndead(this EntityDefinition definition)
    public static function IsUndeadOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(IS_UNDEAD);
    }
    // C#: extension method IsUndead(this Entity entity)
    public static function IsUndead(entity:Entity):Bool
    {
        return entity.GetProperty(IS_UNDEAD);
    }
    // #endregion

    // #region 炸药
    public static var DYNAMITE:PropertyMeta<Bool> = Get("dynamite", false);
    // C#: extension method IsDynamite(this EntityDefinition definition)
    public static function IsDynamiteOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(DYNAMITE);
    }
    // C#: extension method IsDynamite(this Entity entity)
    public static function IsDynamite(entity:Entity):Bool
    {
        return entity.GetProperty(DYNAMITE);
    }
    // #endregion

    // #region 火焰
    public static var IS_FIRE:PropertyMeta<Bool> = Get("isFire", false);
    // C#: extension method SetIsFire(this Entity entity, bool value)
    public static function SetIsFire(entity:Entity, value:Bool):Void
    {
        entity.SetProperty(IS_FIRE, value);
    }
    // C#: extension method IsFire(this EntityDefinition definition)
    public static function IsFireOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(IS_FIRE);
    }
    // C#: extension method IsFire(this Entity entity)
    public static function IsFire(entity:Entity):Bool
    {
        return entity.GetProperty(IS_FIRE);
    }
    // #endregion

    // #region 冰霜
    public static var IS_FROST:PropertyMeta<Bool> = Get("is_frost", false);
    // C#: extension method SetIsFrost(this Entity entity, bool value)
    public static function SetIsFrost(entity:Entity, value:Bool):Void
    {
        entity.SetProperty(IS_FROST, value);
    }
    // C#: extension method IsFrost(this EntityDefinition definition)
    public static function IsFrostOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(IS_FROST);
    }
    // C#: extension method IsFrost(this Entity entity)
    public static function IsFrost(entity:Entity):Bool
    {
        return entity.GetProperty(IS_FROST);
    }
    // #endregion

    // #region 血液
    public static var BLOOD_COLOR:PropertyMeta<Color> = Get("bloodColor", new Color(0, 0, 0, 0));
    public static var BLOOD_COLOR_CENSORED:PropertyMeta<Color> = Get("bloodColorCensored", new Color(0, 0, 0, 0));
    // C#: extension method GetBloodColorNormal(this Entity entity)
    public static function GetBloodColorNormal(entity:Entity):Color
    {
        return entity.GetProperty(BLOOD_COLOR);
    }
    // C#: extension method GetBloodColorCensored(this Entity entity)
    public static function GetBloodColorCensored(entity:Entity):Color
    {
        return entity.GetProperty(BLOOD_COLOR_CENSORED);
    }
    // C#: extension method GetBloodColor(this Entity entity)
    public static function GetBloodColor(entity:Entity):Color
    {
        return Global.Options.HasBloodAndGore() ? GetBloodColorNormal(entity) : GetBloodColorCensored(entity);
    }
    // #endregion

    // #region 升级
    public static var UPGRADE_FROM:PropertyMeta<NamespaceID> = Get("upgradeFrom");
    // C#: extension method GetUpgradeFromEntity(this EntityDefinition entity)
    public static function GetUpgradeFromEntity(entity:EntityDefinition):Null<NamespaceID>
    {
        return entity.GetProperty(UPGRADE_FROM);
    }
    // #endregion

    // #region 摩擦力
    public static var KEEP_GROUND_FRICTION:PropertyMeta<Bool> = Get("KeepGroundFriction", false);
    // C#: extension method KeepGroundFriction(this Entity entity)
    public static function KeepGroundFriction(entity:Entity):Bool
    {
        return entity.GetProperty(KEEP_GROUND_FRICTION);
    }
    // #endregion

    // #region 忠诚
    public static var LOYAL:PropertyMeta<Bool> = Get("loyal", false);
    // C#: extension method IsLoyal(this EntityDefinition definition)
    public static function IsLoyalOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(LOYAL);
    }
    // C#: extension method IsLoyal(this Entity entity)
    public static function IsLoyal(entity:Entity):Bool
    {
        return entity.GetProperty(LOYAL);
    }
    // #endregion

    // #region 无视红线放置
    public static var IGNORE_REDLINE_PLACEMENT:PropertyMeta<Bool> = Get("ignore_redline_placement", false);
    // C#: extension method IgnoreRedlinePlacement(this EntityDefinition definition)
    public static function IgnoreRedlinePlacementOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(IGNORE_REDLINE_PLACEMENT);
    }
    // C#: extension method IgnoreRedlinePlacement(this Entity entity)
    public static function IgnoreRedlinePlacement(entity:Entity):Bool
    {
        return entity.GetProperty(IGNORE_REDLINE_PLACEMENT);
    }
    // #endregion

    public static var CAN_DEACTIVE:PropertyMeta<Bool> = Get("canDeactive", false);
    // C#: extension method CanDeactive(this EntityDefinition definition)
    public static function CanDeactiveOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(CAN_DEACTIVE);
    }
    // C#: extension method CanDeactive(this Entity entity)
    public static function CanDeactive(entity:Entity):Bool
    {
        return entity.GetProperty(CAN_DEACTIVE);
    }
    // C#: extension method SetCanDeactive(this Entity entity, bool value)
    public static function SetCanDeactive(entity:Entity, value:Bool):Void
    {
        entity.SetProperty(CAN_DEACTIVE, value);
    }

    public static var NO_HELD_TARGET:PropertyMeta<Bool> = Get("noHeldTarget", false);
    // C#: extension method NoHeldTarget(this Entity entity)
    public static function NoHeldTarget(entity:Entity):Bool
    {
        return entity.GetProperty(NO_HELD_TARGET);
    }

    public static var TAKEN_CRUSH_DAMAGE:PropertyMeta<Float> = Get("takenCrushDamage", 0.0);
    // C#: extension method GetTakenCrushDamage(this Entity entity)
    public static function GetTakenCrushDamage(entity:Entity):Float
    {
        return entity.GetProperty(TAKEN_CRUSH_DAMAGE);
    }

    // #region 无视传动力板
    public static var IGNORE_FORCE_PAD:PropertyMeta<Bool> = Get("ignore_force_pad", false);
    // C#: extension method IgnoreForcePad(this EntityDefinition definition)
    public static function IgnoreForcePadOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(IGNORE_FORCE_PAD);
    }
    // C#: extension method IgnoreForcePad(this Entity entity)
    public static function IgnoreForcePad(entity:Entity):Bool
    {
        return entity.GetProperty(IGNORE_FORCE_PAD);
    }
    // #endregion

    // #region 禁止爆炸
    public static var NO_EXPLOSION:PropertyMeta<Bool> = Get("no_explosion", false);
    // C#: extension method NoExplosion(this Entity entity)
    public static function NoExplosion(entity:Entity):Bool
    {
        return entity.GetProperty(NO_EXPLOSION);
    }
    // #endregion
}

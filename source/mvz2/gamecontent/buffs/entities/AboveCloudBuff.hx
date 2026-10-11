// Ported from: Assets/Scripts/Vanilla/GameContent/Buffs/Entity/Chapter5/AboveCloudBuff.cs
// PORT-NOTE: C# 的 `FloatInteraction(Entity, out float gravityAddition)` 使用 out 参数；
// Haxe 无 out 参数，改为返回 Float。
package mvz2.gamecontent.buffs.entities;

import mvz2.gamecontent.buffs.VanillaBuffNames;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.entities.WaterInteraction.AirInteraction;
import mvz2.vanilla.modifiers.VanillaModifierPriorities;
import mvz2.vanilla.properties.VanillaBuffPropertyMeta;
import mvz2logic.entities.LogicEnemyProps;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEntityProps;
import pvzengine.buffs.Buff;
import pvzengine.damages.DamageEffectList;
import pvzengine.definitions.BuffDefinition;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.modifiers.BooleanModifier;
import pvzengine.modifiers.FloatModifier;
import pvzengine.modifiers.NumberOperator;
import unity.Mathf;
import unity.UnityObject;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.WaterInteractionParams;
using mvz2.vanilla.entities.VanillaEntityProps;

@:autoBuffDefinition(VanillaBuffNames.Entity_aboveCloud)
class AboveCloudBuff extends BuffDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new FloatModifier(EngineEntityProps.GRAVITY, NumberOperator.AddMultiple, PROP_GRAVITY_ADDITION, VanillaModifierPriorities.WATER_GRAVITY));
        AddModifier(new FloatModifier(EngineEntityProps.FRICTION, NumberOperator.Multiply, PROP_FRICTION_MULTI));
        AddModifier(new FloatModifier(EngineEntityProps.GROUND_LIMIT_OFFSET, NumberOperator.Add, PROP_GROUND_LIMIT_OFFSET));
        AddModifier(new FloatModifier(LogicEntityProps.SHADOW_ALPHA, NumberOperator.Multiply, PROP_SHADOW_ALPHA));
        AddModifier(new BooleanModifier(LogicEnemyProps.HARMLESS, PROP_FALLING));
        AddModifier(new BooleanModifier(LogicEntityProps.DEPTH_TEST, true));
    }
    public override function PostAdd(buff:Buff):Void
    {
        super.PostAdd(buff);
        buff.SetProperty(PROP_GROUND_LIMIT_OFFSET, MIN_GROUND_LIMIT_OFFSET);
    }
    public override function PostRemove(buff:Buff):Void
    {
        super.PostRemove(buff);
        var entity = buff.GetEntity();
        if (entity == null)
            return;
        CheckInteractionCallback(entity, buff, false);
    }
    public override function PostUpdate(buff:Buff):Void
    {
        super.PostUpdate(buff);
        var entity = buff.GetEntity();
        if (entity == null)
            return;
        UpdateInCloud(entity, buff);
    }
    private function UpdateInCloud(entity:Entity, buff:Buff):Void
    {
        var frictionMulti:Float = 1;
        var gravityAddition:Float = 0;
        var groundLimitOffset:Float = 0;
        var shadowAlpha:Float = 0.25;
        var falling = false;

        var groundY = entity.GetGroundY();
        var interaction = entity.GetAirInteraction();
        var noneInteraction = interaction == AirInteraction.NONE;
        var insideCloud = entity.Position.y < groundY && !noneInteraction;
        if (!noneInteraction)
        {
            groundLimitOffset = MIN_GROUND_LIMIT_OFFSET;
        }
        if (insideCloud)
        {
            // 低于地面
            shadowAlpha = 0;
            frictionMulti = 0.2;
            falling = entity.IsDead || interaction == AirInteraction.FALL_OFF;
            if (interaction == AirInteraction.REMOVE)
            {
                // 移除
                RemoveInteraction(entity);
            }
            else if (falling)
            {
                // 跌落
                FallInteraction(entity);
            }
            else if (interaction == AirInteraction.FLOAT)
            {
                // 漂浮
                gravityAddition = FloatInteraction(entity);
            }
        }
        buff.SetProperty(PROP_FRICTION_MULTI, frictionMulti);
        buff.SetProperty(PROP_GRAVITY_ADDITION, gravityAddition);
        buff.SetProperty(PROP_GROUND_LIMIT_OFFSET, groundLimitOffset);
        buff.SetProperty(PROP_SHADOW_ALPHA, shadowAlpha);
        buff.SetProperty(PROP_FALLING, falling);
        CheckInteractionCallback(entity, buff, insideCloud);
    }
    private function RemoveInteraction(entity:Entity):Void
    {
        VanillaEntityExt.PlayAirSplashEffect(entity);
        VanillaEntityExt.PlayAirSplashSound(entity);
        if (LogicEntityExt.IsVulnerableEntity(entity) && !entity.IsDead)
        {
            VanillaEntityExt.RemoveDie(entity);
        }
        if (unity.UnityObject.exists(entity))
        {
            entity.Remove();
        }
        TriggerAirInteraction(entity, AirInteraction.ACTION_REMOVE);
    }
    private function FallInteraction(entity:Entity):Void
    {
        if (entity.Position.y <= FALL_OFF_Y && !entity.IsDead)
        {
            entity.Die(new DamageEffectList([VanillaDamageEffects.FALL_OFF, VanillaDamageEffects.REMOVE_ON_DEATH, VanillaDamageEffects.NO_DEATH_EFFECTS, VanillaDamageEffects.NO_REVIVAL]), entity);
        }
    }
    private function FloatInteraction(entity:Entity):Float
    {
        var groundY = entity.GetGroundY();
        var height = entity.GetScaledSize().y;
        var sinkPercentage = (groundY - entity.Position.y) / height;
        var t = sinkPercentage / FLOAT_THRESOLD;
        var verticalFriction = Mathf.Lerp(1, 0.5, t);

        var gravityAddition = Mathf.LerpUnclamped(0, -1, t);

        var velocity = entity.Velocity;
        velocity.y *= verticalFriction;
        entity.Velocity = velocity;
        return gravityAddition;
    }
    private function CheckInteractionCallback(entity:Entity, buff:Buff, inside:Bool):Void
    {
        if (inside != buff.GetProperty(PROP_INSIDE_CLOUD))
        {
            buff.SetProperty(PROP_INSIDE_CLOUD, inside);
            VanillaEntityExt.PlayAirSplashSound(entity);
            if (inside)
            {
                TriggerAirInteraction(entity, AirInteraction.ACTION_ENTER);
            }
            else
            {
                TriggerAirInteraction(entity, AirInteraction.ACTION_EXIT);
            }
        }
    }
    private function TriggerAirInteraction(entity:Entity, action:Int):Void
    {
        // TODO-PORT: WaterInteractionParams（mvz2.vanilla.callbacks.VanillaLevelCallbacks）缺少无参构造函数，
        //   暂用 Type.createEmptyInstance 构造（字段随后逐个赋值，语义等价）；该域补 `public function new() {}` 后可改回 new。
        var callbackParam = Type.createEmptyInstance(WaterInteractionParams);
        callbackParam.entity = entity;
        callbackParam.action = action;
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_AIR_INTERACTION, callbackParam, action);
    }
    public static inline var FLOAT_THRESOLD:Float = 0.3333333;
    public static inline var MIN_GROUND_LIMIT_OFFSET:Float = -1000;
    public static inline var FALL_OFF_Y:Float = -600;
    public static var PROP_FRICTION_MULTI:VanillaBuffPropertyMeta<Float> = new VanillaBuffPropertyMeta<Float>("friction_multi");
    public static var PROP_GROUND_LIMIT_OFFSET:VanillaBuffPropertyMeta<Float> = new VanillaBuffPropertyMeta<Float>("ground_limit_offset");
    public static var PROP_SHADOW_ALPHA:VanillaBuffPropertyMeta<Float> = new VanillaBuffPropertyMeta<Float>("shadow_alpha");
    public static var PROP_GRAVITY_ADDITION:VanillaBuffPropertyMeta<Float> = new VanillaBuffPropertyMeta<Float>("GravityAddition");
    public static var PROP_FALLING:VanillaBuffPropertyMeta<Bool> = new VanillaBuffPropertyMeta<Bool>("falling");
    public static var PROP_INSIDE_CLOUD:VanillaBuffPropertyMeta<Bool> = new VanillaBuffPropertyMeta<Bool>("inside_cloud");
}

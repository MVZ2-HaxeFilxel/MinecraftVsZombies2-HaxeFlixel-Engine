// Ported from: Assets/Scripts/Vanilla/GameContent/GlobalCallbacks/WaterGlobalCallbacks.cs
package mvz2.gamecontent.globalcallbacks;

import unity.UnityObject;
import mvz2.gamecontent.buffs.entities.InWaterBuff;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.modding.Mod;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.EntityCallbackParams;
import pvzengine.callbacks.LevelCallbacks;
import pvzengine.entities.Entity;
import mvz2.vanilla.entities.WaterInteraction;
using mvz2.vanilla.entities.VanillaEntityProps;

@:modGlobalCallbacks
class WaterGlobalCallbacks extends VanillaGlobalCallbacks
{
    public override function Apply(mod:Mod):Void
    {
        mod.AddTrigger(LevelCallbacks.POST_ENTITY_UPDATE, EntityUpdateCallback);
    }
    function EntityUpdateCallback(param:EntityCallbackParams, result:CallbackResult):Void
    {
        var entity = param.entity;
        // 头目、掉落物、特效：无效果。

        // 敌人：可以游泳的，在水中漂浮；不能游泳但支持在水中的动画的，沉入水中淹死；不支持在水中动画的，直接沉没。
        // 射弹：可以在水中漂浮的，漂浮（木球）；不能漂浮但支持在水中的动画的，沉入水中淹没（大雪球、石球）；不支持在水中动画的，直接沉没。（箭矢）

        // 器械：如果重力大于0，不是水生的，并且没有睡莲，沉没。否则漂在水面上。
        // 障碍物、小推车：如果重力大于0，沉没。否则漂在水面上。
        UpdateWater(entity);
    }
    function TriggerWaterInteraction(entity:Entity, action:Int):Void
    {
        // TODO-PORT: WaterInteractionParams（mvz2.vanilla.callbacks.VanillaLevelCallbacks 内联类）缺少无参构造函数，
        //   暂用 Type.createEmptyInstance 构造（字段随后逐个赋值，与原 C# `new WaterInteractionParams { ... }` 语义等价）；
        //   该域补 `public function new() {}` 后可改回 new。
        var callbackParam = Type.createEmptyInstance(WaterInteractionParams);
        callbackParam.entity = entity;
        callbackParam.action = action;
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_WATER_INTERACTION, callbackParam, action);
    }
    function UpdateWater(entity:Entity):Void
    {
        var water = VanillaEntityExt.IsOnWater(entity);
        if (!water)
        {
            if (entity.HasBuff(InWaterBuff))
            {
                // 不在水上，但有水上buff，说明之前在水上，现在离开了水面。
                entity.RemoveBuffs(InWaterBuff);
                TriggerWaterInteraction(entity, WaterInteraction.ACTION_EXIT);
                entity.SetAnimationBool("InWater", false);
                entity.SetModelProperty("InWater", false);
            }
            return;
        }

        // 在水面之上
        var interaction = entity.GetWaterInteraction();
        var inWater = entity.IsOnGround;

        if (interaction == WaterInteraction.REMOVE)
        {
            // 遇水移除
            if (inWater)
            {
                // 在水中
                VanillaEntityExt.PlaySplashEffect(entity);
                VanillaEntityExt.PlaySplashSound(entity);
                if (LogicEntityExt.IsVulnerableEntity(entity) && !entity.IsDead)
                {
                    VanillaEntityExt.RemoveDie(entity);
                }
                if (unity.UnityObject.exists(entity))
                {
                    entity.Remove();
                }
                TriggerWaterInteraction(entity, WaterInteraction.ACTION_REMOVE);
            }
            return;
        }
        // 不移除


        if (interaction == WaterInteraction.NONE)
        {
            inWater = false;
        }

        if (inWater != entity.HasBuff(InWaterBuff))
        {
            VanillaEntityExt.PlaySplashEffect(entity);
            if (inWater)
            {
                entity.AddBuff(InWaterBuff);
                VanillaEntityExt.PlaySplashSound(entity);
                TriggerWaterInteraction(entity, WaterInteraction.ACTION_ENTER);
            }
            else
            {
                entity.RemoveBuffs(InWaterBuff);
                LogicEntityExt.PlaySound(entity, VanillaSoundID.water);
                TriggerWaterInteraction(entity, WaterInteraction.ACTION_EXIT);
            }
        }
        entity.SetAnimationBool("InWater", inWater);
        entity.SetModelProperty("InWater", inWater);
    }
}

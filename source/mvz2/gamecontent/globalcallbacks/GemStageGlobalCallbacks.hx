// Ported from: Assets/Scripts/Vanilla/GameContent/GlobalCallbacks/GemStageGlobalCallbacks.cs
package mvz2.gamecontent.globalcallbacks;

import unity.UnityObject;
import mvz2.gamecontent.buffs.enemies.GemCarrierBuff;
import mvz2.gamecontent.stages.GemStageBehaviour;
import mvz2.vanilla.enemies.VanillaEnemyProps;
import mvz2.vanilla.pickups.VanillaPickupExt;
import mvz2.vanilla.properties.VanillaLevelPropertyMeta;
import mvz2.vanilla.unlocks.VanillaUnlockID;
import mvz2logic.Global;
import mvz2logic.level.LogicLevelExt;
import mvz2logic.modding.Mod;
import pvzengine.EntityID;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.EntityCallbackParams;
import pvzengine.callbacks.LevelCallbackParams;
import pvzengine.callbacks.LevelCallbacks;
import pvzengine.entities.EntityTypes;
import mvz2.vanilla.pickups.VanillaPickupProps;

@:modGlobalCallbacks
class GemStageGlobalCallbacks extends VanillaGlobalCallbacks
{
    public override function Apply(mod:Mod):Void
    {
        mod.AddTrigger(LevelCallbacks.POST_ENTITY_INIT, Gem_PostPickupInitCallback, 0, EntityTypes.PICKUP);
        mod.AddTrigger(LevelCallbacks.POST_ENTITY_INIT, Gem_PostEnemyInitCallback, 0, EntityTypes.ENEMY);
        mod.AddTrigger(LevelCallbacks.POST_LEVEL_UPDATE, Gem_PostUpdateCallback);
    }
    function Gem_PostUpdateCallback(param:LevelCallbackParams, result:CallbackResult):Void
    {
        var level = param.level;
        var firstGem:Null<EntityID> = level.GetProperty(FIRST_GEM);
        if (firstGem == null)
            return;
        var gem = firstGem.GetEntity(level);
        if (gem == null || !unity.UnityObject.exists(gem) || VanillaPickupExt.IsCollected(gem))
        {
            var adviceContext = CONTEXT_ADVICE_COLLECT_MONEY;
            var adviceText = ADVICE_COLLECT_MONEY_1;
            // PORT-NOTE: C# ShowAdvice(context, textKey, priority, timeout, params string[] args) 的
            // 可变参数在 Haxe 侧是必填的 Array<String>，无参数时传空数组。
            level.ShowAdvice(adviceContext, adviceText, 1000, 90, []);
            level.SetProperty(FIRST_GEM, null);
            level.HideHintArrow();
        }
    }
    function Gem_PostPickupInitCallback(param:EntityCallbackParams, result:CallbackResult):Void
    {
        var pickup = param.entity;
        if (VanillaPickupProps.GetMoneyValue(pickup) <= 0)
            return;
        var level = pickup.Level;
        if (!LogicLevelExt.HasBehaviourType(level, GemStageBehaviour))
            return;
        if (!Global.Saves.IsUnlocked(VanillaUnlockID.money))
        {
            Global.Saves.Unlock(VanillaUnlockID.money);
            Global.Saves.SaveToFile(); // 解锁宝石后保存游戏。
            level.SetHintArrowPointToEntity(pickup);
            level.SetProperty(FIRST_GEM, new EntityID(pickup));
            var adviceContext = CONTEXT_ADVICE_COLLECT_MONEY;
            var adviceText = ADVICE_COLLECT_MONEY_0;
            level.ShowAdvice(adviceContext, adviceText, 1000, -1, []);
        }
    }
    function Gem_PostEnemyInitCallback(param:EntityCallbackParams, result:CallbackResult):Void
    {
        var enemy = param.entity;
        var level = enemy.Level;
        if (!LogicLevelExt.HasBehaviourType(level, GemStageBehaviour))
            return;
        if (VanillaEnemyProps.HasNoReward(enemy))
            return;
        var spawnGem = false;
        if (Global.Saves.IsUnlocked(VanillaUnlockID.money))
        {
            spawnGem = enemy.DropRNG.Next(10) < 1;
        }
        else
        {
            var currentWave = level.CurrentWave;
            var totalFlags = level.GetTotalFlags();
            if (currentWave >= totalFlags * level.GetWavesPerFlag() / 2)
            {
                spawnGem = true;
            }
        }
        if (spawnGem)
        {
            enemy.AddBuff(GemCarrierBuff);
        }
    }
    public static inline var REGION_NAME:String = "gem_stage";
    @:levelPropertyRegistry("gem_stage")
    public static var FIRST_GEM:VanillaLevelPropertyMeta<EntityID> = new VanillaLevelPropertyMeta<EntityID>("firstGem");
    public static inline var CONTEXT_ADVICE_COLLECT_MONEY:String = "advice.collect_money";
    // [TranslateMsg("拾取宝石的帮助提示", CONTEXT_ADVICE_COLLECT_MONEY)]
    public static inline var ADVICE_COLLECT_MONEY_0:String = "点击收集宝石！";
    // [TranslateMsg("拾取宝石的帮助提示", CONTEXT_ADVICE_COLLECT_MONEY)]
    public static inline var ADVICE_COLLECT_MONEY_1:String = "收集宝石来获得更酷的道具吧！";
}

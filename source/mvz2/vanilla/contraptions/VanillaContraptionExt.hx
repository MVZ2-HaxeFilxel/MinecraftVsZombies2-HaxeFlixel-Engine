// Ported from: Assets/Scripts/Vanilla/GameContent/Contraptions/VanillaContraptionExt.cs
package mvz2.vanilla.contraptions;

import unity.UnityObject;
import mvz2.gamecontent.buffs.contraptions.ImitatedBuff;
import mvz2.gamecontent.buffs.contraptions.NocturnalBuff;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.entities.IEmptyHandClickEntity;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.grids.VanillaGridExt;
import mvz2.vanilla.grids.VanillaGridLayers;
import mvz2logic.Global;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.grids.LogicGridExt;
import pvzengine.NamespaceID;
import pvzengine.buffs.BuffExt;
import pvzengine.callbacks.EntityCallbackParams;
import pvzengine.definitions.EntityDefinition;
import pvzengine.entities.Entity;

// PORT-NOTE: C# 的扩展方法在本移植中为静态方法；调用点沿用扩展方法风格，故以 `using` 引入对应模块。
using mvz2.vanilla.contraptions.VanillaContraptionExt;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2.vanilla.grids.VanillaGridExt;
using mvz2logic.entities.LogicEntityExt;
using mvz2logic.entities.LogicEntityProps;
using mvz2logic.grids.LogicGridExt;
using pvzengine.buffs.BuffExt;

class VanillaContraptionExt
{
    // PORT-NOTE: EntityDefinition.GetBehaviour<T>/GetBehaviours<T> 的 T 受限于 EntityBehaviourDefinition 类，
    //   而 C# 此处传入的是行为接口（IContraptionEvokeBehaviour / ITriggerableContraption / IEmptyHandClickEntity）。
    //   Haxe 的 interface 不能继承 class，故沿用 VanillaArmorExt.TryDestroyBySpikes 的既有做法，
    //   以 GetBehaviourAt()/GetBehaviourCount() + Std.isOfType 在运行期按接口筛选。
    private static function GetBehaviourOfType<T>(definition:EntityDefinition, type:Class<T>):Null<T>
    {
        for (i in 0...definition.GetBehaviourCount())
        {
            var behaviour = definition.GetBehaviourAt(i);
            if (Std.isOfType(behaviour, type))
            {
                return cast behaviour;
            }
        }
        return null;
    }
    private static function GetBehavioursOfType<T>(definition:EntityDefinition, type:Class<T>):Array<T>
    {
        var result:Array<T> = [];
        for (i in 0...definition.GetBehaviourCount())
        {
            var behaviour = definition.GetBehaviourAt(i);
            if (Std.isOfType(behaviour, type))
            {
                result.push(cast behaviour);
            }
        }
        return result;
    }
    public static function CanEvoke(contraption:Entity):Bool
    {
        var evokable = GetBehaviourOfType(contraption.Definition, IContraptionEvokeBehaviour);
        if (evokable == null)
            return false;
        return evokable.CanEvoke(contraption);
    }
    public static function Evoke(contraption:Entity):Void
    {
        contraption.Spawn(VanillaEffectID.evocationStar, contraption.GetCenter());
        for (evokable in GetBehavioursOfType(contraption.Definition, IContraptionEvokeBehaviour))
        {
            evokable.Evoke(contraption);
        }
        var param = new EntityCallbackParams(contraption);
        contraption.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_CONTRAPTION_EVOKE, param, contraption.GetDefinitionID());
    }
    public static function HasPassenger(contraption:Entity):Bool
    {
        if (contraption == null)
            return false;
        var game = Global.Game;
        var grids = contraption.GetGridsToTake();
        for (grid in grids)
        {
            if (grid == null)
                continue;
            if (grid.GetCarrierEntity() == contraption)
            {
                // 选取当前实体所占有图格的非承载层。
                var layers = grid.GetLayers();
                var carryingLayers = Lambda.filter(layers, l -> l != VanillaGridLayers.carrier);

                for (layer in carryingLayers)
                {
                    var target = grid.GetLayerEntity(layer);
                    if (target != null && unity.UnityObject.exists(target) && target != contraption)
                        return true;
                }
            }
        }
        return false;
    }
    public static function GetFirstProtectingTarget(contraption:Entity):Null<Entity>
    {
        if (contraption == null)
            return null;
        var grids = contraption.GetGridsToTake();
        for (grid in grids)
        {
            if (grid == null)
                continue;
            if (grid.GetProtectorEntity() == contraption)
            {
                var protectingLayers = VanillaGridLayers.protectedLayers;

                for (layer in protectingLayers)
                {
                    var target = grid.GetLayerEntity(layer);
                    if (target != null && unity.UnityObject.exists(target) && target != contraption)
                        return target;
                }
            }
        }
        return null;
    }
    public static function GetProtectingTargets(contraption:Entity):Array<Entity>
    {
        if (contraption == null)
            return [];

        var targets:Array<Entity> = [];
        var grids = contraption.GetGridsToTake();
        for (grid in grids)
        {
            if (grid == null)
                continue;
            if (grid.GetProtectorEntity() == contraption)
            {
                var protectingLayers = VanillaGridLayers.protectedLayers;

                for (layer in protectingLayers)
                {
                    var target = grid.GetLayerEntity(layer);
                    if (target != null && unity.UnityObject.exists(target) && target != contraption)
                    {
                        targets.push(target);
                    }
                }
            }
        }
        return targets;
    }
    public static function GetProtector(contraption:Entity):Null<Entity>
    {
        if (contraption == null)
            return null;
        var grids = contraption.GetGridsToTake();
        for (grid in grids)
        {
            if (grid == null)
                continue;
            var protector = grid.GetProtectorEntity();
            if (protector != null && unity.UnityObject.exists(protector) && protector != contraption)
                return protector;
        }
        return null;
    }
    public static function CanTrigger(contraption:Entity):Bool
    {
        var triggerable = GetBehaviourOfType(contraption.Definition, ITriggerableContraption);
        if (triggerable == null)
            return false;
        return triggerable.CanTrigger(contraption);
    }
    public static function Trigger(contraption:Entity):Void
    {
        for (triggerable in GetBehavioursOfType(contraption.Definition, ITriggerableContraption))
        {
            triggerable.Trigger(contraption);
        }
        contraption.Level.Triggers.RunCallback(VanillaLevelCallbacks.POST_CONTRAPTION_TRIGGER, new EntityCallbackParams(contraption));
    }
    public static function CanEmptyHandClick(contraption:Entity):Bool
    {
        var behaviour = GetBehaviourOfType(contraption.Definition, IEmptyHandClickEntity);
        if (behaviour == null)
            return false;
        return behaviour.CanEmptyHandClick(contraption);
    }
    public static function EmptyHandClick(contraption:Entity):Void
    {
        for (behaviour in GetBehavioursOfType(contraption.Definition, IEmptyHandClickEntity))
        {
            behaviour.EmptyHandClick(contraption);
        }
        contraption.Level.Triggers.RunCallback(VanillaLevelCallbacks.POST_CONTRAPTION_EMPTY_HAND_CLICK, new EntityCallbackParams(contraption));
    }
    public static function CanUpgradeToContraption(contraption:Entity, target:EntityDefinition):Bool
    {
        var id = target.GetUpgradeFromEntity();
        if (id == null)
            return false;
        return contraption.IsEntityOf(id);
    }
    public static function UpgradeToContraption(contraption:Entity, target:NamespaceID, extraEntities:Array<Entity>):Null<Entity>
    {
        var grid = contraption.GetGrid();
        if (grid == null)
            return null;
        var awake = !contraption.HasBuff(NocturnalBuff);
        contraption.Remove();
        for (ent in extraEntities)
        {
            ent.Remove();
        }
        var upgraded = grid.SpawnPlacedEntity(target);
        if (upgraded == null)
            return null;
        if (awake)
        {
            upgraded.RemoveBuffs(NocturnalBuff);
        }
        upgraded.DestroyConflictGridEntities();
        return upgraded;
    }
    public static function FirstAid(contraption:Entity):Void
    {
        contraption.HealEffects(contraption.GetMaxHealth(), contraption);
        var grid = contraption.GetGrid();
        var soundID = grid != null ? grid.GetPlaceSound(contraption) : null;
        if (soundID != null)
            contraption.PlaySound(soundID);
        contraption.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_OBSIDIAN_FIRST_AID, new EntityCallbackParams(contraption), contraption.GetDefinitionID());
    }
    //region 命令方块
    public static function IsImitated(contraption:Entity):Bool
    {
        return contraption.HasBuff(ImitatedBuff);
    }
    //endregion
}

// Ported from: Assets/Scripts/Vanilla/GameContent/HeldItems/Behaviours/Entity/BlueprintPickupHeldItemBehaviour.cs
package mvz2.gamecontent.helditems;

import unity.UnityObject;
import mvz2.gamecontent.pickups.BlueprintPickup;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2logic.Global;
import mvz2logic.blueprints.LogicSeedProps;
import mvz2logic.blueprints.SeedTypes;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.games.LogicGameExt;
import mvz2logic.grids.LogicGridExt;
import mvz2logic.helditems.HeldHighlight;
import mvz2logic.helditems.HeldItemTargetBlueprint;
import mvz2logic.helditems.HeldItemTargetEntity;
import mvz2logic.helditems.HeldItemTargetGrid;
import mvz2logic.helditems.HeldItemTargetLawn;
import mvz2logic.helditems.HeldTargetFlag;
import mvz2logic.helditems.IEntityTwinklePlaceMethod;
import mvz2logic.helditems.IHeldItemData;
import mvz2logic.helditems.IHeldItemTarget;
import mvz2logic.helditems.IHeldTwinkleEntityBehaviour;
import mvz2logic.inputs.PointerHelper;
import mvz2logic.inputs.PointerInteraction;
import mvz2logic.inputs.PointerInteractionData;
import mvz2logic.inputs.PointerTypes;
import mvz2logic.level.LogicLevelExt;
import mvz2logic.localization.LogicStrings;
import mvz2logic.models.SortingLayers.ShaderProperties;
import pvzengine.NamespaceID;
import pvzengine.callbacks.CallbackResult;
import pvzengine.entities.Entity;
import pvzengine.entities.EngineEntityProps;
import pvzengine.level.LevelEngine;
import pvzengine.models.IModelInterface;
import pvzengine.seedpacks.SeedDefinition;
import tools.Ref;

@:autoHeldItemBehaviourDefinition(VanillaHeldItemBehaviourNames.blueprintPickup)
class BlueprintPickupHeldItemBehaviour extends EntityHeldItemBehaviour implements IHeldTwinkleEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    public override function GetHeldTargetMask(level:LevelEngine):HeldTargetFlag
    {
        return HeldTargetFlag.Pickup;
    }
    public override function IsValidFor(target:IHeldItemTarget, data:IHeldItemData, pointer:PointerInteractionData):Bool
    {
        if (Std.isOfType(target, HeldItemTargetGrid))
            return true;
        if (Std.isOfType(target, HeldItemTargetLawn))
            return true;
        if (Std.isOfType(target, HeldItemTargetBlueprint))
            return true;
        var entity = GetEntity(target.GetLevel(), data);
        if (Std.isOfType(target, HeldItemTargetEntity))
        {
            var ent = cast(target, HeldItemTargetEntity);
            if (ent.Target == entity)
            {
                if (pointer.pointer.type == PointerTypes.TOUCH && !IgnoresTouchRaycast(entity))
                {
                    return true;
                }
            }
        }
        return false;
    }

    public override function GetHighlight(target:IHeldItemTarget, data:IHeldItemData, pointer:PointerInteractionData):HeldHighlight
    {
        if (!Std.isOfType(target, HeldItemTargetGrid))
            return HeldHighlight.None;

        var gridTarget = cast(target, HeldItemTargetGrid);
        var grid = gridTarget.Target;

        var level = grid.Level;
        var entity = GetEntity(level, data);
        if (entity == null)
            return HeldHighlight.None;
        var seedDef = GetSeedDefinition(entity);
        return LogicGridExt.GetSeedHeldHighlight(grid, seedDef);
    }

    public override function OnPointerEvent(target:IHeldItemTarget, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        if (PointerHelper.IsInvalidClickButton(pointerParams))
            return;
        OnHeldItemMainPointerEvent(target, data, pointerParams);
    }
    private function OnHeldItemMainPointerEvent(target:IHeldItemTarget, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        if (Std.isOfType(target, HeldItemTargetGrid))
        {
            OnHeldItemPointerEventGrid(cast(target, HeldItemTargetGrid), data, pointerParams);
        }
        else if (Std.isOfType(target, HeldItemTargetEntity))
        {
            OnHeldItemPointerEventEntity(cast(target, HeldItemTargetEntity), data, pointerParams);
        }
        else if (Std.isOfType(target, HeldItemTargetLawn))
        {
            OnHeldItemPointerEventLawn(cast(target, HeldItemTargetLawn), data, pointerParams);
        }
        else if (Std.isOfType(target, HeldItemTargetBlueprint))
        {
            OnHeldItemPointerEventBlueprint(cast(target, HeldItemTargetBlueprint), data, pointerParams);
        }
    }
    private function OnHeldItemPointerEventGrid(target:HeldItemTargetGrid, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        if (PointerHelper.IsInvalidReleaseAction(pointerParams))
            return;
        var entity = GetEntity(target.GetLevel(), data);
        if (entity == null)
            return;
        var seedDef = GetSeedDefinition(entity);
        if (seedDef != null)
        {
            var grid = target.Target;
            var level = grid.Level;
            var error:Ref<Null<NamespaceID>> = Ref.to(null);
            if (LogicGridExt.CanPlaceBlueprintByID(grid, seedDef.GetID(), error))
            {
                if (LogicSeedProps.GetSeedType(seedDef) == SeedTypes.ENTITY)
                {
                    var type = data.Type;
                    var commandBlock = IsCommandBlock(entity);
                    entity.Remove();
                    LogicGridExt.UseEntityBlueprintDefinition(grid, seedDef, data, commandBlock);
                    ResetHeldItemIfType(level, type);
                    return;
                }
            }
            else if (error.value != null)
            {
                var message = LogicGameExt.GetGridErrorMessage(Global.Game, error.value);
                if (message != null && message != "")
                {
                    LogicLevelExt.ShowAdvice(level, LogicStrings.CONTEXT_ADVICE, message, 0, 150, []);
                }
            }
        }
        SetIgnoreTouchRaycast(entity, false);
    }
    private function OnHeldItemPointerEventEntity(target:HeldItemTargetEntity, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        var targetEntity = target.Target;
        var entity = GetEntity(target.GetLevel(), data);
        if (targetEntity != entity)
            return;
        if (pointerParams.pointer.type != PointerTypes.TOUCH)
            return;
        switch (pointerParams.interaction)
        {
            case PointerInteraction.Down:
                var level = target.GetLevel();
                if (LogicLevelExt.CancelHeldItem(level))
                {
                    LogicLevelExt.PlaySound(level, VanillaSoundID.tap);
                }
            case PointerInteraction.BeginDrag:
                SetIgnoreTouchRaycast(entity, true);
            default:
                // PORT-NOTE: C# 的 switch 无 default，其余交互不处理；Haxe 需显式列出。
        }
    }
    private function OnHeldItemPointerEventLawn(target:HeldItemTargetLawn, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        if (PointerHelper.IsInvalidReleaseAction(pointerParams))
            return;
        var entity = GetEntity(target.GetLevel(), data);
        if (entity != null)
        {
            SetIgnoreTouchRaycast(entity, false);
        }
        var level = target.Level;
        if (LogicLevelExt.CancelHeldItem(level))
        {
            LogicLevelExt.PlaySound(level, VanillaSoundID.tap);
        }
    }
    private function OnHeldItemPointerEventBlueprint(target:HeldItemTargetBlueprint, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        if (PointerHelper.IsInvalidReleaseAction(pointerParams))
            return;
        var entity = GetEntity(target.GetLevel(), data);
        if (entity != null)
        {
            SetIgnoreTouchRaycast(entity, false);
        }
        var level = target.Level;
        if (LogicLevelExt.CancelHeldItem(level))
        {
            LogicLevelExt.PlaySound(level, VanillaSoundID.tap);
        }
    }
    public override function GetModelID(level:LevelEngine, data:IHeldItemData, result:CallbackResult):Void
    {
        var entity = GetEntity(level, data);
        if (entity == null)
            return;
        var seedDef = GetSeedDefinition(entity);
        if (seedDef == null)
            return;
        result.SetFinalValue(LogicSeedProps.GetModelID(seedDef));
    }
    public override function OnSetModel(level:LevelEngine, data:IHeldItemData, model:Null<IModelInterface>):Void
    {
        if (model == null)
            return;
        var entity = GetEntity(level, data);
        if (entity == null)
            return;
        if (IsCommandBlock(entity))
        {
            model.SetShaderInt(ShaderProperties.GRAYSCALE, 1);
            model.ApplyShaderProperties();
        }
    }
    public override function OnUpdate(level:LevelEngine, data:IHeldItemData):Void
    {
        var entity = GetEntity(level, data);
        if (entity == null || !unity.UnityObject.exists(entity))
        {
            LogicLevelExt.ResetHeldItem(level);
        }
    }
    public static function IsCommandBlock(entity:Entity):Bool return BlueprintPickup.IsCommandBlock(entity);
    public static function GetSeedDefinition(entity:Entity):Null<SeedDefinition> return BlueprintPickup.GetSeedDefinition(entity);
    public static function IgnoresTouchRaycast(entity:Entity):Bool return BlueprintPickup.IgnoresTouchRaycast(entity);
    public static function SetIgnoreTouchRaycast(entity:Entity, value:Bool):Void BlueprintPickup.SetIgnoreTouchRaycast(entity, value);

    public function ShouldMakeEntityTwinkle(entity:Entity, data:IHeldItemData):Bool
    {
        var level = entity.Level;
        var blueprintPickup = GetEntity(level, data);
        if (blueprintPickup == null)
            return false;
        var seedEntityID = BlueprintPickup.GetSeedEntityID(blueprintPickup);
        var entityDef = level.Content.GetEntityDefinition(seedEntityID);
        if (entityDef == null)
            return false;
        var placementID = EngineEntityProps.GetPlacementID(entityDef);
        var placementDef = level.Content.GetPlacementDefinition(placementID);
        if (placementDef == null)
            return false;
        // TODO-PORT: C# 泛型方法 GetMethod<T>()，Haxe 无法在无参情况下推断泛型参数，改为传入类型。
        var method = placementDef.GetMethod(IEntityTwinklePlaceMethod);
        if (method == null)
            return false;
        return method.ShouldMakeEntityTwinkle(placementDef, entity, entityDef);
    }
}

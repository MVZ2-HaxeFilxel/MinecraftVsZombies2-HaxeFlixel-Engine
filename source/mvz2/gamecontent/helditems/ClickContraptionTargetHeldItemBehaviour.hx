// Ported from: Assets/Scripts/Vanilla/GameContent/HeldItems/Behaviours/Entity/ClickContraptionTargetHeldItemBehaviour.cs
package mvz2.gamecontent.helditems;

import unity.UnityObject;
import mvz2.gamecontent.models.VanillaModelID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2logic.helditems.HeldHighlight;
import mvz2logic.helditems.HeldItemTargetBlueprint;
import mvz2logic.helditems.HeldItemTargetGrid;
import mvz2logic.helditems.HeldItemTargetLawn;
import mvz2logic.helditems.IHeldItemData;
import mvz2logic.helditems.IHeldItemTarget;
import mvz2logic.helditems.IHeldTwinkleEntityBehaviour;
import mvz2logic.inputs.PointerHelper;
import mvz2logic.inputs.PointerInteractionData;
import mvz2logic.level.LawnArea;
import mvz2logic.level.LogicLevelExt;
import pvzengine.callbacks.CallbackResult;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;

// abstract
class ClickContraptionTargetHeldItemBehaviour extends EntityHeldItemBehaviour implements IHeldTwinkleEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    public override function IsValidFor(target:IHeldItemTarget, data:IHeldItemData, pointer:PointerInteractionData):Bool
    {
        return Std.isOfType(target, HeldItemTargetGrid) || Std.isOfType(target, HeldItemTargetLawn) || Std.isOfType(target, HeldItemTargetBlueprint);
    }
    public override function GetHighlight(target:IHeldItemTarget, data:IHeldItemData, pointer:PointerInteractionData):HeldHighlight
    {
        if (!Std.isOfType(target, HeldItemTargetGrid))
            return HeldHighlight.None;
        var targetGrid = cast(target, HeldItemTargetGrid);
        return HeldHighlight.Green(targetGrid.Target);
    }
    public override function GetModelID(level:LevelEngine, data:IHeldItemData, result:CallbackResult):Void
    {
        result.SetFinalValue(VanillaModelID.targetHeldItem);
    }
    public override function OnUpdate(level:LevelEngine, data:IHeldItemData):Void
    {
        var entity = GetEntity(level, data);
        if (entity == null || !unity.UnityObject.exists(entity) || VanillaEntityProps.IsAIFrozen(entity))
        {
            LogicLevelExt.ResetHeldItem(level);
            return;
        }
    }
    public override function OnPointerEvent(target:IHeldItemTarget, data:IHeldItemData, pointerParams:PointerInteractionData):Void
    {
        if (PointerHelper.IsInvalidClickButton(pointerParams) || PointerHelper.IsInvalidReleaseAction(pointerParams))
            return;
        if (Std.isOfType(target, HeldItemTargetGrid))
        {
            var targetGrid = cast(target, HeldItemTargetGrid);
            if (targetGrid.Target == null)
                return;
            var level = targetGrid.GetLevel();
            OnUseOnGrid(targetGrid, data, pointerParams);
            LogicLevelExt.ResetHeldItem(level);
        }
        else if (Std.isOfType(target, HeldItemTargetLawn))
        {
            var targetLawn = cast(target, HeldItemTargetLawn);
            if (targetLawn.Area != LawnArea.Main)
            {
                if (LogicLevelExt.CancelHeldItem(targetLawn.Level))
                {
                    LogicLevelExt.PlaySound(targetLawn.Level, VanillaSoundID.tap);
                }
            }
        }
        else if (Std.isOfType(target, HeldItemTargetBlueprint))
        {
            var level = target.GetLevel();
            if (LogicLevelExt.CancelHeldItem(level))
            {
                LogicLevelExt.PlaySound(level, VanillaSoundID.tap);
            }
        }
    }

    public function ShouldMakeEntityTwinkle(entity:Entity, data:IHeldItemData):Bool
    {
        var current = GetEntity(entity.Level, data);
        return entity == current;
    }
    // abstract
    public function OnUseOnGrid(targetGrid:HeldItemTargetGrid, data:IHeldItemData, pointerParams:PointerInteractionData):Void throw "abstract";
}

// Ported from: Assets/Scripts/Vanilla/GameContent/HeldItems/Behaviours/Entity/ForcePadHeldItemBehaviour.cs
package mvz2.gamecontent.helditems;

import unity.UnityObject;
import mvz2.gamecontent.contraptions.ForcePad;
import mvz2.gamecontent.models.VanillaModelID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.helditems.HeldHighlight;
import mvz2logic.helditems.HeldItemTargetGrid;
import mvz2logic.helditems.IHeldItemData;
import mvz2logic.helditems.IHeldItemTarget;
import mvz2logic.inputs.PointerHelper;
import mvz2logic.inputs.PointerInteractionData;
import mvz2logic.level.LogicLevelExt;
import pvzengine.callbacks.CallbackResult;
import pvzengine.level.LevelEngine;

@:autoHeldItemBehaviourDefinition(VanillaHeldItemBehaviourNames.forcePad)
class ForcePadHeldItemBehaviour extends EntityHeldItemBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    public override function IsValidFor(target:IHeldItemTarget, data:IHeldItemData, pointer:PointerInteractionData):Bool
    {
        return Std.isOfType(target, HeldItemTargetGrid);
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
        if (!Std.isOfType(target, HeldItemTargetGrid))
            return;
        var targetGrid = cast(target, HeldItemTargetGrid);
        if (targetGrid.Target == null)
            return;
        var level = target.GetLevel();
        var entity = GetEntity(level, data);
        if (entity != null)
        {
            ForcePad.SetDragTargetLocked(entity, true);
            ForcePad.SetDragTarget(entity, targetGrid.Target.GetEntityPosition());
            ForcePad.SetDragTimeout(entity, 30);
            LogicEntityExt.PlaySound(entity, VanillaSoundID.magnetic);
        }
        LogicLevelExt.ResetHeldItem(level);
    }
}

// Ported from: Assets/Scripts/Vanilla/GameContent/Stages/Definitions/BreakoutStage.cs
package mvz2.gamecontent.stages;

import mvz2.gamecontent.effects.BreakoutBoard;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.helditems.VanillaHeldTypes;
import mvz2.gamecontent.seeds.VanillaBlueprintID;
import mvz2.gamecontent.stages.RedstoneStageBehaviour.RedstoneDropStageBehaviour;
import mvz2logic.helditems.HeldItemBuilder;
import mvz2logic.helditems.LogicHeldTypes;
import mvz2logic.level.LogicLevelExt;
import pvzengine.NamespaceID;
import pvzengine.definitions.StageDefinition;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
import unity.Vector3;
import unity.UnityObject;

@:autoStageDefinition(VanillaStageNames.breakout)
class BreakoutStage extends StageDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddBehaviour(new WaveStageBehaviour(this));
        AddBehaviour(new FinalWaveClearBehaviour(this));
        AddBehaviour(new GemStageBehaviour(this));
        AddBehaviour(new RedstoneDropStageBehaviour(this));
        AddBehaviour(new SpeedUpStageBehaviour(this, 1, 2));
    }
    override public function OnSetup(level:LevelEngine):Void
    {
        super.OnSetup(level);
        SpawnBoard(level);
    }
    override public function OnStart(level:LevelEngine):Void
    {
        super.OnStart(level);
        level.SetSeedSlotCount(3);
        LogicLevelExt.FillSeedPacks(level, [
            VanillaBlueprintID.returnPearl,
            VanillaBlueprintID.lengthenBoard,
            VanillaBlueprintID.addPearl
        ]);
        LogicLevelExt.SetPickaxeActive(level, false);
        LogicLevelExt.SetStarshardActive(level, false);
        LogicLevelExt.SetTriggerActive(level, false);
    }
    override public function OnUpdate(level:LevelEngine):Void
    {
        super.OnUpdate(level);
        var board = level.FindFirstEntity(VanillaEffectID.breakoutBoard);
        if (board == null || !unity.UnityObject.exists(board))
        {
            board = SpawnBoard(level);
        }
        if (board == null)
            return;
        if (LogicLevelExt.GetHeldItemType(level) == LogicHeldTypes.none)
        {
            var builder = new HeldItemBuilder(VanillaHeldTypes.breakoutBoard, 100);
            builder.SetEntityID(board.ID);
            builder.SetCannotCancel(true);
            LogicLevelExt.SetHeldItem(level, builder);
        }
    }
    private function SpawnBoard(level:LevelEngine):Null<Entity>
    {
        var x = level.GetEntityColumnX(1);
        var z = level.GetEntityLaneZ(2);
        var y = 32;
        var pos = new Vector3(x, y, z);
        var board = level.Spawn(VanillaEffectID.breakoutBoard, pos, null);
        if (board != null)
        {
            BreakoutBoard.SpawnPearl(board);
        }
        return board;
    }
}

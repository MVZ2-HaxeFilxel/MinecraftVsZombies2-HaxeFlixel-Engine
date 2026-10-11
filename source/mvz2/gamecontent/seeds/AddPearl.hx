// Ported from: Assets/Scripts/Vanilla/GameContent/Seeds/AddPearl.cs
package mvz2.gamecontent.seeds;

import unity.UnityObject;
import mvz2.gamecontent.effects.BreakoutBoard;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.seeds.VanillaBlueprintID.VanillaBlueprintNames;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2logic.blueprints.LogicBlueprintErrors;
import mvz2logic.blueprints.SeedOptionDefinition;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.level.LevelEngine;
import pvzengine.seedpacks.EngineSeedProps;
import pvzengine.seedpacks.SeedDefinition;
import pvzengine.seedpacks.SeedPack;

@:autoSeedOptionDefinition(VanillaBlueprintNames.addPearl)
class AddPearl extends SeedOptionDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }
    public override function Update(seedPack:SeedPack, rechargeSpeed:Float):Void
    {
        super.Update(seedPack, rechargeSpeed);
        seedPack.SetProperty(EngineSeedProps.DISABLE_ID, IsValid(seedPack) ? null : LogicBlueprintErrors.invalid);
    }
    public override function Use(seedPack:SeedPack):Void
    {
        super.Use(seedPack);
        UseLevel(seedPack.Level);
    }
    // PORT-NOTE: Haxe has no method overloading; C# 重载 Use(LevelEngine, SeedDefinition) → UseWithDefinition。
    public override function UseWithDefinition(level:LevelEngine, seedDef:SeedDefinition):Void
    {
        super.UseWithDefinition(level, seedDef);
        // TODO-PORT: 原 C# 此处为 `Use(level, seedDef)` 自递归调用，疑似上游笔误，按 1:1 保留。
        UseWithDefinition(level, seedDef);
    }
    function UseLevel(level:LevelEngine):Void
    {
        var board = level.FindFirstEntity(e -> e.IsEntityOf(VanillaEffectID.breakoutBoard) && (e.Target == null || !unity.UnityObject.exists(e.Target)));
        if (board == null)
            return;
        BreakoutBoard.SpawnPearl(board);
        LogicEntityExt.PlaySound(board, VanillaSoundID.starshardUse);
    }
    function IsValid(seedPack:SeedPack):Bool
    {
        var level = seedPack.Level;
        var board = level.FindFirstEntity(e -> e.IsEntityOf(VanillaEffectID.breakoutBoard) && (e.Target == null || !unity.UnityObject.exists(e.Target)));
        if (board == null)
            return false;
        return true;
    }
}

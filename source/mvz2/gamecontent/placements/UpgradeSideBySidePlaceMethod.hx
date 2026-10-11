// Ported from: Assets/Scripts/Vanilla/GameContent/Placements/PlaceMethods/UpgradeSideBySidePlaceMethod.cs
package mvz2.gamecontent.placements;

import unity.UnityObject;
import mvz2.gamecontent.buffs.contraptions.ImitatedBuff;
import mvz2.vanilla.contraptions.VanillaContraptionExt;
import mvz2.vanilla.grids.VanillaGridStatus;
import mvz2logic.entities.LogicContraptionProps;
import mvz2logic.helditems.IEntityTwinklePlaceMethod;
import mvz2logic.placements.LogicPlaceProps;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;
import pvzengine.grids.LawnGrid;
import pvzengine.placements.PlaceMethod;
import pvzengine.placements.PlaceOutput;
import pvzengine.placements.PlaceParams;
import pvzengine.placements.PlacementDefinition;
using mvz2.vanilla.contraptions.VanillaContraptionExt;
using mvz2logic.entities.LogicEntityExt;
using mvz2logic.entities.LogicEntityProps;

class UpgradeSideBySidePlaceMethod extends PlaceMethod implements IEntityTwinklePlaceMethod
{
    public function new() {}
    public function ShouldMakeEntityTwinkle(placement:PlacementDefinition, entity:Entity, toPlace:EntityDefinition):Bool
    {
        if (!LogicContraptionProps.IsUpgradeBlueprintOfDefinition(toPlace))
            return false;
        if (!IsCellOfUpgrade(entity, toPlace))
            return false;
        return IsSideBySide(entity, toPlace);
    }
    public override function GetPlaceError(placement:PlacementDefinition, grid:LawnGrid, toPlace:EntityDefinition):Null<NamespaceID>
    {
        var entity = GetTargetEntity(grid, toPlace);
        if (entity == null || !unity.UnityObject.exists(entity))
            return VanillaGridStatus.onlyUpgrade;

        var sideEntity = GetRightEntity(grid, toPlace);
        if (sideEntity == null || !unity.UnityObject.exists(sideEntity))
            return VanillaGridStatus.onlyUpgrade;

        return null;
    }
    public override function PlaceEntity(placement:PlacementDefinition, grid:LawnGrid, toPlace:EntityDefinition, param:PlaceParams):PlaceOutput
    {
        var entity = GetTargetEntity(grid, toPlace);
        if (entity == null || !unity.UnityObject.exists(entity))
            return PlaceOutput.InvalidOutput;

        var sideEntity = GetRightEntity(grid, toPlace);
        if (sideEntity == null || !unity.UnityObject.exists(sideEntity))
            return PlaceOutput.InvalidOutput;

        var isCommandBlock = LogicPlaceProps.IsCommandBlock(param);
        var ent = VanillaContraptionExt.UpgradeToContraption(entity, toPlace.GetID(), [sideEntity]);
        if (ent != null)
        {
            if (isCommandBlock)
            {
                ent.AddBuff(ImitatedBuff);
            }
            ent.SetVariant(LogicPlaceProps.GetVariant(param));
        }
        // PORT-NOTE: C# 对象初始化器 new PlaceOutput(e, d) { f = v } → 逐字段赋值。
        var output = new PlaceOutput(ent, toPlace);
        output.isCommandBlock = isCommandBlock;
        output.increaseTakenConveyorSeed = true;
        return output;
    }
    function IsSideBySide(entity:Entity, toPlace:EntityDefinition):Bool
    {
        var column = entity.GetColumn();
        var lane = entity.GetLane();
        var gridRight = entity.Level.GetGrid(column + 1, lane);
        if (GetTargetEntity(gridRight, toPlace) != null)
            return true;
        var gridLeft = entity.Level.GetGrid(column - 1, lane);
        if (GetTargetEntity(gridLeft, toPlace) != null)
            return true;
        return false;
    }
    function IsCellOfUpgrade(entity:Entity, toPlace:EntityDefinition):Bool
    {
        return VanillaContraptionExt.CanUpgradeToContraption(entity, toPlace) && entity.GetProtector() == null && entity.IsFriendlyEntity();
    }
    function GetTargetEntity(grid:Null<LawnGrid>, toPlace:EntityDefinition):Null<Entity>
    {
        if (grid == null)
            return null;
        var entities = grid.GetEntities();
        for (ent in entities)
        {
            if (IsCellOfUpgrade(ent, toPlace))
                return ent;
        }
        return null;
    }
    function GetRightEntity(grid:LawnGrid, toPlace:EntityDefinition):Null<Entity>
    {
        var column = grid.Column;
        var lane = grid.Lane;
        var gridRight = grid.Level.GetGrid(column + 1, lane);
        return GetTargetEntity(gridRight, toPlace);
    }
}

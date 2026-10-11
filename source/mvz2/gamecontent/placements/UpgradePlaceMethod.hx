// Ported from: Assets/Scripts/Vanilla/GameContent/Placements/PlaceMethods/UpgradePlaceMethod.cs
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
using mvz2logic.entities.LogicEntityExt;
using mvz2logic.entities.LogicEntityProps;

class UpgradePlaceMethod extends PlaceMethod implements IEntityTwinklePlaceMethod
{
    public function new() {}
    public function ShouldMakeEntityTwinkle(placement:PlacementDefinition, entity:Entity, entityDef:EntityDefinition):Bool
    {
        return LogicContraptionProps.IsUpgradeBlueprintOfDefinition(entityDef) && VanillaContraptionExt.CanUpgradeToContraption(entity, entityDef) && entity.IsFriendlyEntity();
    }
    public override function GetPlaceError(placement:PlacementDefinition, grid:LawnGrid, entity:EntityDefinition):Null<NamespaceID>
    {
        var entities = grid.GetEntities();
        if (entities.length <= 0 || !Lambda.exists(entities, e -> VanillaContraptionExt.CanUpgradeToContraption(e, entity) && e.IsFriendlyEntity()))
        {
            return VanillaGridStatus.onlyUpgrade;
        }
        return null;
    }
    public override function PlaceEntity(placement:PlacementDefinition, grid:LawnGrid, entityDef:EntityDefinition, param:PlaceParams):PlaceOutput
    {
        var entity = Lambda.find(grid.GetEntities(), e -> VanillaContraptionExt.CanUpgradeToContraption(e, entityDef));
        if (entity != null && unity.UnityObject.exists(entity))
        {
            var isCommandBlock = LogicPlaceProps.IsCommandBlock(param);
            var ent = VanillaContraptionExt.UpgradeToContraption(entity, entityDef.GetID(), []);
            if (ent != null)
            {
                if (isCommandBlock)
                {
                    ent.AddBuff(ImitatedBuff);
                }
                ent.SetVariant(LogicPlaceProps.GetVariant(param));
            }
            // PORT-NOTE: C# 对象初始化器 new PlaceOutput(e, d) { f = v } → 逐字段赋值。
            var output = new PlaceOutput(ent, entityDef);
            output.isCommandBlock = isCommandBlock;
            output.increaseTakenConveyorSeed = true;
            return output;
        }
        return PlaceOutput.InvalidOutput;
    }
}

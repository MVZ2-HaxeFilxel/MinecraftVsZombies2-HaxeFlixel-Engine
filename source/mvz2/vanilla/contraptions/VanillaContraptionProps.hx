// Ported from: Assets/Scripts/Vanilla/Frameworks/Contraptions/VanillaContraptionProps.cs
package mvz2.vanilla.contraptions;

import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;

@:propertyRegistryRegion(PropertyRegions.entity)
class VanillaContraptionProps
{
    private static function Get<T>(name:String, ?defaultValue:T, ?obsoleteNames:Array<String>):PropertyMeta<T>
    {
        return new VanillaEntityPropertyMeta<T>(name, defaultValue, obsoleteNames);
    }

    // #region 可攀爬
    public static var NO_CLIMB:PropertyMeta<Bool> = Get("noClimb", false);
    // C#: extension method NoClimb(this Entity contraption)
    public static function NoClimb(contraption:Entity):Bool
    {
        return contraption.GetProperty(NO_CLIMB);
    }
    // #endregion

    // #region 防御性
    public static var DEFENSIVE:PropertyMeta<Bool> = Get("defensive", false);
    // C#: extension method IsDefensive(this Entity contraption)
    public static function IsDefensive(contraption:Entity):Bool
    {
        return contraption.GetProperty(DEFENSIVE);
    }
    // C#: extension method IsDefensive(this EntityDefinition contraptionDef)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to IsDefensiveOfDefinition.
    public static function IsDefensiveOfDefinition(contraptionDef:EntityDefinition):Bool
    {
        return contraptionDef.GetProperty(DEFENSIVE);
    }
    // #endregion

    // #region 生产者
    public static var PRODUCER:PropertyMeta<Bool> = Get("producer", false);
    // C#: extension method IsProducer(this EntityDefinition contraption)
    public static function IsProducer(contraption:EntityDefinition):Bool
    {
        return contraption.GetProperty(PRODUCER);
    }
    // #endregion

    // #region 阻挡跳跃
    public static var BLOCKS_JUMP:PropertyMeta<Bool> = Get("blocksJump", false);
    // C#: extension method BlocksJump(this Entity contraption)
    public static function BlocksJump(contraption:Entity):Bool
    {
        return contraption.GetProperty(BLOCKS_JUMP);
    }
    // C#: extension method BlocksJump(this EntityDefinition definition)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to BlocksJumpOfDefinition.
    public static function BlocksJumpOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(BLOCKS_JUMP);
    }
    // #endregion

    // #region 地板器械
    public static var IS_FLOOR:PropertyMeta<Bool> = Get("isFloor", false);
    // C#: extension method IsFloor(this Entity contraption)
    public static function IsFloor(contraption:Entity):Bool
    {
        return contraption.GetProperty(IS_FLOOR);
    }
    // C#: extension method IsFloor(this EntityDefinition definition)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to IsFloorOfDefinition.
    public static function IsFloorOfDefinition(definition:EntityDefinition):Bool
    {
        return definition.GetProperty(IS_FLOOR);
    }
    // #endregion

    // #region 碎片ID
    public static var FRAGMENT_ID:PropertyMeta<NamespaceID> = Get("fragmentId");
    // C#: extension method GetFragmentID(this Entity entity)
    public static function GetFragmentID(entity:Entity):Null<NamespaceID>
    {
        return entity.GetProperty(FRAGMENT_ID);
    }
    // #endregion

    // #region 不能绑架
    public static var NO_ABDUCTION:PropertyMeta<Bool> = Get("no_abduction", false);
    // C#: extension method IsNoAbduction(this Entity entity)
    public static function IsNoAbduction(entity:Entity):Bool
    {
        return entity.GetProperty(NO_ABDUCTION);
    }
    // #endregion

    // #region 不能使用吞噬者
    public static var NO_DEVOURER:PropertyMeta<Bool> = Get("no_devourer", false);
    // C#: extension method IsNoDevourer(this Entity entity)
    public static function IsNoDevourer(entity:Entity):Bool
    {
        return entity.GetProperty(NO_DEVOURER);
    }
    // #endregion
}

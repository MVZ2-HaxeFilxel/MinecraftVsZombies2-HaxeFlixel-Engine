// Ported from: Assets/Scripts/Vanilla/Frameworks/Pickups/VanillaPickupProps.cs
package mvz2.vanilla.pickups;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;

@:propertyRegistryRegion(PropertyRegions.entity)
class VanillaPickupProps
{
    private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }
    public static var COLLECTED_TIME:PropertyMeta<Int> = Get("collectedTime", 0);
    public static var IMPORTANT:PropertyMeta<Bool> = Get("important", false);
    public static var NO_AUTO_COLLECT:PropertyMeta<Bool> = Get("noAutoCollect", false);
    public static var DROP_SOUND:PropertyMeta<NamespaceID> = Get("dropSound");
    public static var COLLECT_SOUND:PropertyMeta<NamespaceID> = Get("collectSound");
    public static var ENERGY_VALUE:PropertyMeta<Int> = Get("energyValue", 0);
    public static var MONEY_VALUE:PropertyMeta<Int> = Get("moneyValue", 0);
    public static var REMOVE_ON_COLLECT:PropertyMeta<Bool> = Get("removeOnCollect", false);
    // C#: extension method IsImportantPickup(this Entity entity)
    public static function IsImportantPickup(entity:Entity):Bool
    {
        return entity.GetProperty(IMPORTANT);
    }
    // C#: extension method GetCollectedTime(this Entity entity)
    public static function GetCollectedTime(entity:Entity):Int
    {
        return entity.GetProperty(COLLECTED_TIME);
    }
    // C#: extension method SetCollectedTime(this Entity entity, int value)
    public static function SetCollectedTime(entity:Entity, value:Int):Void
    {
        entity.SetProperty(COLLECTED_TIME, value);
    }
    // C#: extension method AddPickupCollectedTime(this Entity entity, int value)
    public static function AddPickupCollectedTime(entity:Entity, value:Int):Void
    {
        SetCollectedTime(entity, GetCollectedTime(entity) + value);
    }
    // C#: extension method NoAutoCollect(this Entity pickup)
    public static function NoAutoCollect(pickup:Entity):Bool
    {
        return pickup.GetProperty(NO_AUTO_COLLECT);
    }
    public static var NO_PICKUP_STOLEN:PropertyMeta<Bool> = Get("no_pickup_stolen", false);
    // C#: extension method NoPickupStolen(this Entity pickup)
    public static function NoPickupStolen(pickup:Entity):Bool
    {
        return pickup.GetProperty(NO_PICKUP_STOLEN);
    }
    // C#: extension method GetDropSound(this Entity entity)
    public static function GetDropSound(entity:Entity):Null<NamespaceID>
    {
        return entity.GetProperty(DROP_SOUND);
    }
    // C#: extension method SetCollectSound(this Entity entity, NamespaceID value)
    public static function SetCollectSound(entity:Entity, value:NamespaceID):Void
    {
        entity.SetProperty(COLLECT_SOUND, value);
    }
    // C#: extension method GetCollectSound(this Entity entity)
    public static function GetCollectSound(entity:Entity):Null<NamespaceID>
    {
        return entity.GetProperty(COLLECT_SOUND);
    }
    // C#: extension method GetMoneyValue(this Entity entity)
    public static function GetMoneyValue(entity:Entity):Int
    {
        return entity.GetProperty(MONEY_VALUE);
    }
    // C#: extension method GetEnergyValue(this Entity entity)
    public static function GetEnergyValue(entity:Entity):Int
    {
        return entity.GetProperty(ENERGY_VALUE);
    }
    // C#: extension method GetEnergyValue(this EntityDefinition definition)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to GetEnergyValueOfDefinition.
    public static function GetEnergyValueOfDefinition(definition:EntityDefinition):Int
    {
        return definition.GetProperty(ENERGY_VALUE);
    }
    // C#: extension method RemoveOnCollect(this Entity entity)
    public static function RemoveOnCollect(entity:Entity):Bool
    {
        return entity.GetProperty(REMOVE_ON_COLLECT);
    }
    public static var NO_COLLECT:PropertyMeta<Bool> = Get("noCollect", false);
    // C#: extension method NoCollect(this Entity pickup)
    public static function NoCollect(pickup:Entity):Bool
    {
        return pickup.GetProperty(NO_COLLECT);
    }
    public static var NO_LIMIT_IN_SCREEN:PropertyMeta<Bool> = Get("no_limit_in_screen", false);
    // C#: extension method NoLimitInScreen(this Entity pickup)
    public static function NoLimitInScreen(pickup:Entity):Bool
    {
        return pickup.GetProperty(NO_LIMIT_IN_SCREEN);
    }
    public static var CONTENT_ID:PropertyMeta<NamespaceID> = Get("content_id");
    // C#: extension method GetPickupContentID(this Entity pickup)
    public static function GetPickupContentID(pickup:Entity):Null<NamespaceID>
    {
        return pickup.GetProperty(CONTENT_ID);
    }
    // C#: extension method SetPickupContentID(this Entity pickup, NamespaceID? value)
    public static function SetPickupContentID(pickup:Entity, value:Null<NamespaceID>):Void
    {
        pickup.SetProperty(CONTENT_ID, value);
    }
    public static var PLAY_RANDOM_PITCH_ON_COLLECT:PropertyMeta<Bool> = Get("play_random_pitch_on_collect", false);
    // C#: extension method PlayRandomPitchOnCollect(this Entity pickup)
    public static function PlayRandomPitchOnCollect(pickup:Entity):Bool
    {
        return pickup.GetProperty(PLAY_RANDOM_PITCH_ON_COLLECT);
    }
}

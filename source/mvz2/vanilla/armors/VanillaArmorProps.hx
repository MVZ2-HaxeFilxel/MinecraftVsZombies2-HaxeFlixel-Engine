// Ported from: Assets/Scripts/Vanilla/Frameworks/Armors/VanillaArmorProps.cs
package mvz2.vanilla.armors;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.armors.Armor;

@:propertyRegistryRegion(PropertyRegions.armor)
class VanillaArmorProps
{
    static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }
    public static var NO_DISCARD:PropertyMeta<Bool> = Get("noDiscard", false);
    public static function HasNoDiscard(armor:Armor):Bool
    {
        return armor.GetProperty(NO_DISCARD);
    }
    public static var HIT_SOUND:PropertyMeta<NamespaceID> = Get("hitSound");
    public static function GetHitSound(armor:Armor):Null<NamespaceID>
    {
        return armor.GetProperty(HIT_SOUND);
    }
    public static var DEATH_SOUND:PropertyMeta<NamespaceID> = Get("deathSound");
    public static function GetDeathSound(armor:Armor):Null<NamespaceID>
    {
        return armor.GetProperty(DEATH_SOUND);
    }
}

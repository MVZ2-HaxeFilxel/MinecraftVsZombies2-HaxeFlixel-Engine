// Ported from: Assets/Scripts/Vanilla/GameContent/Buffs/VanillaBuffProps.cs
package mvz2.gamecontent.buffs;

import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;

@:propertyRegistryRegion(PropertyRegions.buff)
class VanillaBuffProps
{
    private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }
}

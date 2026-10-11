// Ported from: Assets/Scripts/Vanilla/Frameworks/Shells/VanillaShellProps.cs
package mvz2.vanilla.shells;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.shells.ShellDefinition;

@:propertyRegistryRegion(PropertyRegions.shell)
class VanillaShellProps
{
    static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
    {
        return new PropertyMeta<T>(name, defaultValue);
    }
    public static var SLICE_CRITICAL:PropertyMeta<Bool> = Get("sliceCritical", false);
    public static var BLOCKS_FIRE:PropertyMeta<Bool> = Get("blocksFire", false);
    public static var HIT_SOUND:PropertyMeta<NamespaceID> = Get("hitSound");
    public static var BLOCKS_SLICE:PropertyMeta<Bool> = Get("blocks_slice", false);

    public static function IsSliceCritical(shell:ShellDefinition):Bool
    {
        return shell.GetProperty(SLICE_CRITICAL);
    }
    public static function BlocksFire(shell:ShellDefinition):Bool
    {
        return shell.GetProperty(BLOCKS_FIRE);
    }
    public static function BlocksSlice(shell:ShellDefinition):Bool
    {
        return shell.GetProperty(BLOCKS_SLICE);
    }
    public static function GetHitSound(shell:ShellDefinition):Null<NamespaceID>
    {
        return shell.GetProperty(HIT_SOUND);
    }
}

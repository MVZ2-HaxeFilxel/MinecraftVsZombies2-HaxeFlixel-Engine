// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Prologue/Fragment.cs
package mvz2.gamecontent.effects;

import unity.UnityObject;
import mvz2.vanilla.contraptions.VanillaContraptionProps;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;

@:autoEntityBehaviourDefinition(VanillaEffectNames.fragment)
class Fragment extends EffectBehaviour
{
    // #region 公有方法
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }
    public override function Update(entity:Entity):Void
    {
        super.Update(entity);
        var parent = entity.Parent;
        if (parent != null && unity.UnityObject.exists(parent))
        {
            entity.Timeout = 30;
            entity.Position = parent.Position;
            UpdateFragmentID(entity);
        }
        entity.SetModelProperty("EmitSpeed", GetEmitSpeed(entity));
        SetEmitSpeed(entity, 0);
    }
    public static function GetEmitSpeed(entity:Entity):Float
    {
        return entity.GetBehaviourFieldNS(ID, PROP_EMIT_SPEED);
    }
    public static function SetEmitSpeed(entity:Entity, value:Float):Void
    {
        entity.SetBehaviourFieldNS(ID, PROP_EMIT_SPEED, value);
    }
    public static function AddEmitSpeed(entity:Entity, value:Float):Void
    {
        SetEmitSpeed(entity, GetEmitSpeed(entity) + value);
    }
    public static function GetFragmentID(entity:Entity):Null<NamespaceID>
    {
        return entity.GetProperty(PROP_FRAGMENT_ID);
    }
    public static function SetFragmentID(entity:Entity, value:Null<NamespaceID>):Void
    {
        entity.SetProperty(PROP_FRAGMENT_ID, value);
        entity.SetModelProperty("FragmentID", value);
    }
    public static function UpdateFragmentID(entity:Entity):Void
    {
        var parent = entity.Parent;
        // C#: parent?.GetFragmentID() ?? parent?.GetDefinitionID()
        var fragmentID:Null<NamespaceID> = parent != null ? VanillaContraptionProps.GetFragmentID(parent) : null;
        if (fragmentID == null && parent != null)
        {
            fragmentID = parent.GetDefinitionID();
        }
        var current = GetFragmentID(entity);
        if (fragmentID != current)
        {
            SetFragmentID(entity, fragmentID);
        }
    }
    // #endregion
    private static var ID:NamespaceID = VanillaEffectID.fragment;
    public static var PROP_FRAGMENT_ID:VanillaEntityPropertyMeta<NamespaceID> = new VanillaEntityPropertyMeta<NamespaceID>("fragment_id");
    public static var PROP_EMIT_SPEED:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("EmitSpeed");
}

// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Chapter2/HealParticles.cs
package mvz2.gamecontent.effects;

import unity.UnityObject;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import pvzengine.entities.Entity;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;
using mvz2.vanilla.entities.VanillaEntityProps;

@:autoEntityBehaviourDefinition(VanillaEffectNames.healParticles)
class HealParticles extends EffectBehaviour
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
            entity.Timeout = entity.GetMaxTimeout();
            entity.Position = parent.Position;
        }
        entity.SetModelProperty("EmitSpeed", GetEmitSpeed(entity));
        entity.SetModelProperty("Size", entity.GetScaledSize());
        SetEmitSpeed(entity, 0);
    }
    public static function GetEmitSpeed(entity:Entity):Float
    {
        return entity.GetBehaviourField(PROP_EMIT_SPEED);
    }
    public static function SetEmitSpeed(entity:Entity, value:Float):Void
    {
        entity.SetBehaviourField(PROP_EMIT_SPEED, value);
    }
    public static function AddEmitSpeed(entity:Entity, value:Float):Void
    {
        SetEmitSpeed(entity, GetEmitSpeed(entity) + value);
    }
    // #endregion

    public static var PROP_EMIT_SPEED:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("EmitSpeed");
}

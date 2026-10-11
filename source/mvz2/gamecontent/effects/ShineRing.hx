// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Chapter1/ShineRing.cs
package mvz2.gamecontent.effects;

import unity.UnityObject;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.entities.Entity;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;
using mvz2logic.entities.LogicEntityProps;

@:autoEntityBehaviourDefinition(VanillaEffectNames.shineRing)
class ShineRing extends EffectBehaviour
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
        if (parent == null || !unity.UnityObject.exists(parent) || parent.IsDead)
        {
            entity.Remove();
            return;
        }
        if (!parent.IsLightSource())
        {
            entity.Remove();
            return;
        }
        entity.Position = parent.GetCenter();
        var color = parent.GetLightColor();
        color.a *= 0.3;
        entity.SetTint(color);
        var lightRange = parent.GetLightRange() / 100.0;
        lightRange.y = lightRange.z;
        entity.SetDisplayScale(lightRange);
    }
    // #endregion
}

// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Chapter2/DarkMatterParticles.cs
package mvz2.gamecontent.effects;

import unity.UnityObject;
import pvzengine.entities.Entity;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;

@:autoEntityBehaviourDefinition(VanillaEffectNames.darkMatterParticles)
class DarkMatterParticles extends EffectBehaviour
{
    // #region 公有方法
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }
    public override function Update(entity:Entity):Void
    {
        super.Update(entity);
        if (entity.Parent != null && unity.UnityObject.exists(entity.Parent))
        {
            entity.Position = entity.Parent.Position;
        }
    }
    // #endregion
}

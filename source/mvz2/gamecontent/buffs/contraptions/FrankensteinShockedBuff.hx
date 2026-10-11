// Ported from: Assets/Scripts/Vanilla/GameContent/Buffs/Contraption/Chapter1/FrankensteinShockedBuff.cs
package mvz2.gamecontent.buffs.contraptions;

import unity.UnityObject;
import mvz2.gamecontent.buffs.VanillaBuffNames;
import mvz2.gamecontent.models.VanillaModelID;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.models.VanillaModelKeys;
import mvz2.vanilla.properties.VanillaBuffPropertyMeta;
import mvz2logic.models.LogicModelHelper;
import pvzengine.buffs.Buff;
import pvzengine.definitions.BuffDefinition;
import pvzengine.modifiers.BooleanModifier;

@:autoBuffDefinition(VanillaBuffNames.Contraption_frankensteinShocked)
class FrankensteinShockedBuff extends BuffDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new BooleanModifier(VanillaEntityProps.AI_FROZEN, true));
        AddModelInsertion(LogicModelHelper.ANCHOR_CENTER, VanillaModelKeys.shortCircuit, VanillaModelID.shortCircuit);
        AddModelInsertion(LogicModelHelper.ANCHOR_CENTER, VanillaModelKeys.staticParticles, VanillaModelID.staticParticles);
    }
    public override function PostUpdate(buff:Buff):Void
    {
        super.PostUpdate(buff);
        UpdateShocked(buff);
    }
    function UpdateShocked(buff:Buff):Void
    {
        var timeout = buff.GetProperty(PROP_TIMEOUT);
        timeout--;
        buff.SetProperty(PROP_TIMEOUT, timeout);
        if (timeout <= 0)
        {
            buff.Remove();
            return;
        }
        var entity = buff.GetEntity();
        if (entity == null || !unity.UnityObject.exists(entity) || entity.IsDead)
        {
            buff.Remove();
            return;
        }
    }
    public static var PROP_TIMEOUT:VanillaBuffPropertyMeta<Int> = new VanillaBuffPropertyMeta<Int>("Timeout");
}

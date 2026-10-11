// Ported from: Assets/Scripts/Vanilla/GameContent/Buffs/Entity/Chapter3/CharmBuff.cs
package mvz2.gamecontent.buffs.entities;

import mvz2.gamecontent.buffs.VanillaBuffNames;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.properties.VanillaBuffPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.buffs.Buff;
import pvzengine.definitions.BuffDefinition;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityID;
import pvzengine.modifiers.ColorModifier;
import pvzengine.modifiers.IntModifier;
import pvzengine.modifiers.IntegerOperator;
import unity.Color;
import unity.UnityObject;

@:autoBuffDefinition(VanillaBuffNames.Entity_charm)
class CharmBuff extends BuffDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new ColorModifier(EngineEntityProps.COLOR_OFFSET, new Color(1, 0, 1, 0.5)));
        AddModifier(new IntModifier(EngineEntityProps.FACTION, IntegerOperator.Set, PROP_FACTION));
    }
    public override function PostUpdate(buff:Buff):Void
    {
        super.PostUpdate(buff);
        var entity = buff.GetEntity();
        if (entity == null)
            return;

        var mode = buff.GetProperty(PROP_MODE);
        var targetFaction = buff.GetProperty(PROP_FACTION);
        if (mode == CharmModes.SOURCE)
        {
            var sourceID = buff.GetProperty(PROP_SOURCE);
            var source = sourceID == null ? null : sourceID.GetEntity(buff.Level);
            if (source == null || !unity.UnityObject.exists(source) || source.IsDead)
            {
                LogicEntityExt.PlaySound(entity, VanillaSoundID.mindClear);
                buff.Remove();
                return;
            }
            else
            {
                targetFaction = source.GetFaction();
                buff.SetProperty(PROP_FACTION, targetFaction);
            }
        }
    }

    public static function SetPermanent(buff:Buff, faction:Int):Void
    {
        buff.SetProperty(PROP_MODE, CharmModes.PERMANENT);
        buff.SetProperty(PROP_FACTION, faction);
    }
    public static function SetController(buff:Buff, source:Entity):Void
    {
        buff.SetProperty(PROP_MODE, CharmModes.SOURCE);
        buff.SetProperty(PROP_SOURCE, new EntityID(source));
    }
    public static function CloneCharm(buff:Buff, target:Entity):Void
    {
        var targetBuff = target.GetFirstBuff(CharmBuff);
        if (targetBuff == null)
        {
            targetBuff = target.AddBuff(CharmBuff);
        }
        targetBuff.SetProperty(PROP_MODE, buff.GetProperty(PROP_MODE));
        targetBuff.SetProperty(PROP_FACTION, buff.GetProperty(PROP_FACTION));
        var oldSource = buff.GetProperty(PROP_SOURCE);
        var newSource = oldSource != null ? new EntityID(oldSource.ID) : null;
        targetBuff.SetProperty(PROP_SOURCE, newSource);
    }

    public static var PROP_MODE:VanillaBuffPropertyMeta<Int> = new VanillaBuffPropertyMeta<Int>("Mode");
    public static var PROP_FACTION:VanillaBuffPropertyMeta<Int> = new VanillaBuffPropertyMeta<Int>("Faction");
    public static var PROP_SOURCE:VanillaBuffPropertyMeta<EntityID> = new VanillaBuffPropertyMeta<EntityID>("Source");
}

class CharmModes
{
    public static inline var PERMANENT:Int = 0;
    public static inline var SOURCE:Int = 1;
    public static inline var TIMEOUT:Int = 2;
}

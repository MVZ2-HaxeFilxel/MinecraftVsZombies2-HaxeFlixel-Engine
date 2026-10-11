// Ported from: Assets/Scripts/Vanilla/GameContent/Buffs/Entity/Chapter6/PetrifiedBuff.cs
package mvz2.gamecontent.buffs.entities;

import mvz2.gamecontent.buffs.VanillaBuffNames;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.fragments.VanillaFragmentID;
import mvz2.gamecontent.models.VanillaModelID;
import mvz2.gamecontent.shells.VanillaShellID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.models.VanillaModelKeys;
import mvz2.vanilla.properties.VanillaBuffPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.models.LogicModelHelper;
import pvzengine.buffs.Buff;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.LevelCallbacks;
import pvzengine.definitions.BuffDefinition;
import pvzengine.entities.EngineEntityProps;
import pvzengine.modifiers.BooleanModifier;
import pvzengine.modifiers.FloatModifier;
import pvzengine.modifiers.NamespaceIDModifier;
import pvzengine.modifiers.NumberOperator;
import pvzengine.modifiers.SetOperator;
import pvzengine.modifiers.Vector3Modifier;
import tools.FrameTimer;
import unity.Vector3;
import unity.UnityObject;
import pvzengine.callbacks.LevelCallbacks.EntityDeathParams;
import mvz2.vanilla.effects.FragmentExt;

@:autoBuffDefinition(VanillaBuffNames.Entity_petrified)
class PetrifiedBuff extends BuffDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModelInsertion(LogicModelHelper.ANCHOR_ROOT, VanillaModelKeys.petrifiedFeet, VanillaModelID.petrifiedFeet);
        AddModifier(new BooleanModifier(VanillaEntityProps.AI_FROZEN, true));
        AddModifier(new BooleanModifier(LogicEntityProps.REMOVE_ON_DEATH, true));
        AddModifier(new BooleanModifier(LogicEntityProps.NO_DEATH_EFFECTS, true));
        AddModifier(new BooleanModifier(LogicEntityProps.KILL_BY_PICKAXE, true));
        AddModifier(new NamespaceIDModifier(EngineEntityProps.SHELL, SetOperator.Set, VanillaShellID.stone));
        AddModifier(new FloatModifier(LogicEntityProps.ANIMATION_SPEED, NumberOperator.Multiply, 0));
        AddModifier(new Vector3Modifier(LogicEntityProps.HSV_OFFSET, NumberOperator.Add, new Vector3(0, -100, 0)));
        AddTrigger(LevelCallbacks.POST_ENTITY_DEATH, PostEntityDeathCallback);
    }
    public override function OnCreate(buff:Buff):Void
    {
        super.OnCreate(buff);
        buff.SetProperty(PROP_TIMER, new FrameTimer(0));
    }
    public override function PostRemove(buff:Buff):Void
    {
        super.PostRemove(buff);
        var entity = buff.GetEntity();
        if (entity != null && unity.UnityObject.exists(entity))
        {
            entity.Spawn(VanillaEffectID.petrifiedShards, entity.Position);
            LogicEntityExt.PlaySound(entity, VanillaSoundID.rockCrumble);
        }
    }
    public override function PostUpdate(buff:Buff):Void
    {
        super.PostUpdate(buff);
        var timer = buff.GetProperty(PROP_TIMER);
        if (timer == null)
        {
            buff.Remove();
            return;
        }
        timer.Run();
        if (timer.Expired)
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
    private function PostEntityDeathCallback(param:EntityDeathParams, result:CallbackResult):Void
    {
        var entity = param.entity;
        if (!entity.HasBuff(PetrifiedBuff))
            return;
        FragmentExt.CreateFragmentAndPlay(entity, VanillaFragmentID.furnace);
        LogicEntityExt.PlaySound(entity, VanillaSoundID.rockCrumble);
    }
    public static function SetTime(buff:Buff, value:Int):Void
    {
        var timer = buff.GetProperty(PROP_TIMER);
        if (timer == null)
            return;
        timer.ResetTime(value);
    }
    public static function MaxTime(buff:Buff, value:Int):Void
    {
        var timer = buff.GetProperty(PROP_TIMER);
        if (timer == null || timer.Frame > value)
            return;
        timer.ResetTime(value);
    }
    public static var PROP_TIMER:VanillaBuffPropertyMeta<FrameTimer> = new VanillaBuffPropertyMeta<FrameTimer>("Timer");
}

// Ported from: Assets/Scripts/Vanilla/GameContent/Buffs/Enemies/Chapter1/StunBuff.cs
package mvz2.gamecontent.buffs.enemies;

import unity.UnityObject;
import mvz2.gamecontent.buffs.VanillaBuffNames;
import mvz2.gamecontent.effects.StunStars;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.properties.VanillaBuffPropertyMeta;
import pvzengine.buffs.Buff;
import pvzengine.definitions.BuffDefinition;
import pvzengine.entities.EntityID;
import pvzengine.modifiers.BooleanModifier;
import tools.FrameTimer;

@:autoBuffDefinition(VanillaBuffNames.Enemy_stun)
class StunBuff extends BuffDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new BooleanModifier(VanillaEntityProps.AI_FROZEN, true));
    }
    public override function PostAdd(buff:Buff):Void
    {
        super.PostAdd(buff);
        UpdateStunStars(buff);
        buff.SetProperty(PROP_TIMER, new FrameTimer(0));
    }
    public override function PostRemove(buff:Buff):Void
    {
        super.PostRemove(buff);
        var starsID = GetStunStars(buff);
        var stars = starsID == null ? null : starsID.GetEntity(buff.Level);
        if (stars != null && unity.UnityObject.exists(stars))
        {
            stars.Remove();
        }
    }
    public override function PostUpdate(buff:Buff):Void
    {
        super.PostUpdate(buff);
        UpdateStun(buff);
        UpdateStunStars(buff);
    }
    private function UpdateStun(buff:Buff):Void
    {
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
    private function UpdateStunStars(buff:Buff):Void
    {
        var entity = buff.GetEntity();
        if (entity == null)
            return;
        var starsID = GetStunStars(buff);
        var stars = starsID == null ? null : starsID.GetEntity(entity.Level);
        if (stars == null || !unity.UnityObject.exists(stars))
        {
            // C#: buff.Level.Spawn(...)?.Let(e => { e.SetParent(entity); SetStunStars(...); });
            var spawned = buff.Level.Spawn(VanillaEffectID.stunStars, StunStars.GetPosition(entity), entity);
            if (spawned != null)
            {
                spawned.SetParent(entity);
                SetStunStars(buff, new EntityID(spawned));
            }
        }
    }
    public static function SetStunTime(buff:Buff, value:Int):Void
    {
        var timer = buff.GetProperty(PROP_TIMER);
        if (timer == null)
            return;
        timer.ResetTime(value);
    }
    public static function GetStunStars(buff:Buff):Null<EntityID> return buff.GetProperty(PROP_STUN_STARS);
    public static function SetStunStars(buff:Buff, value:EntityID):Void buff.SetProperty(PROP_STUN_STARS, value);
    public static var PROP_TIMER:VanillaBuffPropertyMeta<FrameTimer> = new VanillaBuffPropertyMeta<FrameTimer>("Timer");
    public static var PROP_STUN_STARS:VanillaBuffPropertyMeta<EntityID> = new VanillaBuffPropertyMeta<EntityID>("StunStars");
}

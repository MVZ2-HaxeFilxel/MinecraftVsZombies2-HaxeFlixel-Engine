// Ported from: Assets/Scripts/Vanilla/GameContent/Projectiles/Chapter5/ExplosiveLargeFireball.cs
// PORT-NOTE: 该 C# 源文件为 ISO-8859（GBK）编码，移植时按 GBK 解码后照原样翻译，注释保持中文。
package mvz2.gamecontent.projectiles;

import mvz2.gamecontent.bosses.RedDragon;
import mvz2.gamecontent.bosses.RedDragon.RedDragonStunHelper;
import mvz2.gamecontent.bosses.VanillaBossID;
import mvz2.gamecontent.contraptions.GridFire;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.effects.Explosion;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.IBeBlownBehaviour;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEntityProps;
import pvzengine.damages.DamageEffectList;
import pvzengine.definitions.EntityBehaviourDefinition;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityTypes;
import pvzengine.modifiers.FloatModifier;
import pvzengine.modifiers.NumberOperator;
import pvzengine.modifiers.Vector3Modifier;
import tools.FrameTimer;
import tools.Ticks;
import tools.TimerHelper;
import unity.Color;
import unity.Vector3;
import unity.UnityObject;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaProjectileNames.explosiveLargeFireball)
class ExplosiveLargeFireball extends EntityBehaviourDefinition implements IBeBlownBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new Vector3Modifier(EngineEntityProps.SCALE, NumberOperator.Multiply, PROP_SCALE_MULTIPLIER));
        AddModifier(new Vector3Modifier(EngineEntityProps.DISPLAY_SCALE, NumberOperator.Multiply, PROP_SCALE_MULTIPLIER));
        AddModifier(new Vector3Modifier(LogicEntityProps.SHADOW_SCALE, NumberOperator.Multiply, PROP_SCALE_MULTIPLIER));
        AddModifier(new FloatModifier(EngineEntityProps.FRICTION, NumberOperator.Add, PROP_FRICTION_ADDITION));
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        SetTriggerTimer(entity, TimerHelper.NewSecondTimer(TRIGGER_SECONDS));
        entity.CollisionMaskHostile |= EntityCollisionHelper.MASK_BOSS;
    }
    public override function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        if (state == EntityCollisionHelper.STATE_EXIT)
            return;
        var self = collision.Entity;
        var other = collision.Other;
        if (other.Type != EntityTypes.BOSS || !self.IsHostile(other))
            return;
        if (!unity.UnityObject.exists(self))
            return;
        Explode(self);
    }
    public override function Update(entity:Entity):Void
    {
        super.Update(entity);
        var scaleMulti = entity.GetProperty(PROP_SCALE_MULTIPLIER, true);
        // PORT-NOTE: C# 的 Ticks.SmoothDamp 有 float 与 Vector3 两个重载，移植层把向量版本命名为 SmoothDampVector。
        scaleMulti = Ticks.SmoothDampVector(scaleMulti, Vector3.one, 0.1);
        entity.SetProperty(PROP_SCALE_MULTIPLIER, scaleMulti);

        var triggered = entity.GetProperty(PROP_TRIGGERED);
        var triggerTimer = entity.GetProperty(PROP_TRIGGER_TIMER);
        if (!triggered)
        {
            if (pvzengine.TimerHelper.RunToExpiredAndNotNull(triggerTimer))
            {
                Trigger(entity);
            }
        }
        else
        {
            if (pvzengine.TimerHelper.RunToExpiredAndNotNull(triggerTimer))
            {
                Explode(entity);
            }
        }
        entity.SetProperty(PROP_FRICTION_ADDITION, triggered ? 1.0 : 0);
    }
    public static function Trigger(entity:Entity):Void
    {
        entity.TriggerAnimation("Trigger");
        entity.PlaySound(VanillaSoundID.fireCharge, 0.5);
        entity.SetProperty(PROP_TRIGGERED, true);
        var triggerTimer = entity.GetProperty(PROP_TRIGGER_TIMER);
        if (triggerTimer != null)
        {
            triggerTimer.ResetSeconds(EXPLODE_SECONDS);
        }
    }
    public static function Explode(entity:Entity):Void
    {
        var level = entity.Level;
        var position = entity.GetCenter();
        var range = entity.GetRange();
        // 造成伤害
        var effects = new DamageEffectList([VanillaDamageEffects.FIRE, VanillaDamageEffects.EXPLOSION, VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN]);
        var damageOutputs = entity.Explode(position, range, entity.GetFaction(), entity.GetDamage(), effects);
        for (output in damageOutputs)
        {
            if (output == null || !output.HasDamageAmount())
                continue;
            var target = output.Entity;
            if (target.IsEntityOf(VanillaBossID.redDragon))
            {
                target.PlaySound(VanillaSoundID.dragonHit);
                RedDragonStunHelper.Stun(target, 5);
            }
        }

        // 留下火焰
        var column = entity.GetColumn();
        var lane = entity.GetLane();
        for (x in (column - 1)...(column + 2))
        {
            for (y in (lane - 1)...(lane + 2))
            {
                var grid = level.GetGrid(x, y);
                if (grid == null)
                    continue;
                var param = entity.GetSpawnParams();
                GridFire.Spawn(grid, entity, param);
            }
        }
        // 创建特效
        // C#: Explosion.Spawn(entity, position, range)?.Let(e => { e.SetTint(new Color(1, 0.2f, 0, 1)); })
        var explosion = Explosion.Spawn(entity, position, range);
        if (explosion != null)
        {
            explosion.SetTint(new Color(1, 0.2, 0, 1));
        }
        level.ShakeScreen(20, 0, 30);
        entity.PlaySound(VanillaSoundID.meteorLand);
        // 移除
        entity.Remove();
    }
    public function BeBlown(entity:Entity, source:Entity):Void
    {
        entity.SetFaction(source.GetFaction());
        entity.Velocity = source.GetFacingDirection() * 10;
    }
    public static function SetTriggerTime(entity:Entity, seconds:Float):Void
    {
        var timer = GetTriggerTimer(entity);
        if (timer == null)
        {
            return;
        }
        timer.ResetSeconds(seconds);
    }
    public static function SetTriggerTimer(entity:Entity, value:Null<FrameTimer>):Void entity.SetProperty(PROP_TRIGGER_TIMER, value);
    public static function GetTriggerTimer(entity:Entity):Null<FrameTimer> return entity.GetProperty(PROP_TRIGGER_TIMER);
    public static inline var TRIGGER_SECONDS:Float = 10;
    public static inline var EXPLODE_SECONDS:Float = 1;
    public static inline var FIRE_DAMAGE_DIVISOR:Float = 600;
    public static var PROP_SCALE_MULTIPLIER:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("scale_multiplier", Vector3.zero);
    public static var PROP_TRIGGER_TIMER:VanillaEntityPropertyMeta<FrameTimer> = new VanillaEntityPropertyMeta<FrameTimer>("trigger_timer");
    public static var PROP_TRIGGERED:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("triggered");
    public static var PROP_FRICTION_ADDITION:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("friction_addition");
}

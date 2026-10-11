// Ported from: Assets/Scripts/Vanilla/GameContent/Bosses/Frankenstein.cs
// Ported from: Assets/Scripts/Vanilla/GameContent/Bosses/Frankenstein_States.cs
// PORT-NOTE: the C# `partial class Frankenstein` spans Frankenstein.cs and Frankenstein_States.cs;
// per PORTING.md partial classes are merged into a single Haxe module.
// PORT-NOTE: members that the C# nested state classes accessed as private class members are `public`
// here, because Haxe module types do not share class-level private visibility.
package mvz2.gamecontent.bosses;

import Lambda;
import mvz2.gamecontent.buffs.bosses.FrankensteinSteelBuff;
import mvz2.gamecontent.buffs.bosses.FrankensteinTransformingBuff;
import mvz2.gamecontent.contraptions.TNT;
import mvz2.gamecontent.contraptions.VanillaContraptionID;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.detections.FrankensteinGunDetector;
import mvz2.gamecontent.effects.ElectricArc;
import mvz2.gamecontent.effects.Explosion;
import mvz2.gamecontent.effects.FrankensteinHead;
import mvz2.gamecontent.projectiles.VanillaProjectileID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.bosses.VanillaBossExt;
import mvz2.vanilla.bosses.VanillaBossStates;
import mvz2.vanilla.detection.Detection;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.level.VanillaLevelExt;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2.vanilla.statemachine.EntityStateMachine;
import mvz2.vanilla.statemachine.EntityStateMachineState;
import pvzengine.entities.EntityTypes;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.level.LogicLevelExt;
import pvzengine.NamespaceID;
import pvzengine.RandomGenerator;
import pvzengine.buffs.Buff;
import pvzengine.damages.DamageEffectList;
import pvzengine.damages.DeathInfo;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.entities.EntitySourceReference;
import pvzengine.grids.LawnGrid;
import tools.EnumerableExt;
import tools.FrameTimer;
import unity.Mathf;
import unity.Vector2;
import unity.Vector3;
import unity.UnityObject;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2logic.entities.LogicEntityExt;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.difficulties.VanillaDifficultyLevelProps;

@:autoEntityBehaviourDefinition(VanillaBossNames.frankenstein)
class Frankenstein extends BossBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    // #region 回调
    override public function Init(boss:Entity):Void
    {
        super.Init(boss);
        SetDetectTimer(boss, new FrameTimer());
        SetShockRNG(boss, new RandomGenerator(boss.RNG.Next()));
        SetBulletRNG(boss, new RandomGenerator(boss.RNG.Next()));
        SetJumpRNG(boss, new RandomGenerator(boss.RNG.Next()));

        stateMachine.Init(boss);
        stateMachine.StartState(boss, STATE_WAKING);

        if (VanillaDifficultyLevelProps.FrankensteinInstantSteelPhase(boss.Level))
        {
            EnterSteelPhase(boss);
        }
    }
    override public function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);

        if (entity.IsDead)
            return;
        if (CanTransformPhase(entity) && entity.State != STATE_FAINT)
        {
            stateMachine.StartState(entity, STATE_FAINT);
            var substateTimer = stateMachine.GetSubStateTimer(entity);
            if (substateTimer != null)
                substateTimer.ResetTime(60);
            entity.PlaySound(VanillaSoundID.powerOff);
        }
        stateMachine.UpdateAI(entity);
    }
    override public function UpdateLogic(entity:Entity):Void
    {
        super.UpdateLogic(entity);
        UpdateAim(entity);
        stateMachine.UpdateLogic(entity);
        entity.SetAnimationBool("MissileVisible", entity.State == STATE_MISSILE && stateMachine.GetSubState(entity) == SUBSTATE_MISSILE_AIM);
        entity.SetAnimationFloat("ActionSpeed", GetFrankensteinActionSpeed(entity));
    }
    override public function PostDeath(boss:Entity, damageInfo:DeathInfo):Void
    {
        super.PostDeath(boss, damageInfo);
        stateMachine.StartState(boss, STATE_DEAD);
    }
    // #endregion 事件

    public static function EnterSteelPhase(boss:Entity):Void
    {
        boss.PlaySound(VanillaSoundID.bloody);
        var level = boss.Level;
        var center = boss.Position + new Vector3(-50, 80, 0);

        level.Spawn(VanillaEffectID.gore, center, boss);
        var bloodParticles = level.Spawn(VanillaEffectID.bloodParticles, center, boss);
        if (bloodParticles != null)
        {
            var bloodColor = VanillaEntityProps.GetBloodColor(boss);
            bloodParticles.SetTint(bloodColor);
        }

        SetSteelPhase(boss, true);
    }
    private function UpdateAim(boss:Entity):Void
    {
        var target:Entity = boss.Target;
        var substate = stateMachine.GetSubState(boss);
        // 内手臂，发射子弹
        var innerArmRootPosition = boss.Position + innerArmRootOffset;

        var innerDir = VanillaEntityExt.GetFacingDirection(boss);
        if (boss.State == STATE_GUN && target != null)
        {
            innerDir = (target.GetCenter() - innerArmRootPosition).normalized;
        }
        var gunDir = GetGunDirection(boss);
        SetGunDirection(boss, Vector3.Lerp(gunDir, innerDir, 0.3));
        // 外手臂，发射火箭
        var outerArmRootPosition = boss.Position + innerArmRootOffset;

        var outerDir = VanillaEntityExt.GetFacingDirection(boss);
        if (boss.State == STATE_MISSILE && substate == SUBSTATE_MISSILE_AIM && target != null)
        {
            outerDir = (target.GetCenter() - outerArmRootPosition).normalized;
        }
        var missileDir = GetMissileDirection(boss);
        SetMissileDirection(boss, Vector3.Lerp(missileDir, outerDir, 0.3));
    }
    public static function FindMissileTarget(boss:Entity):Null<Entity>
    {
        return missileDetector.DetectEntityWithTheMost(DetectionParams.fromEntity(boss), function(t) return Mathf.Abs(boss.Position.x - t.GetCenter().x));
    }
    public static function FindPunchTarget(boss:Entity):Null<Entity>
    {
        return boss.Level.FindFirstEntity(function(e) return IsPunchable(boss, e));
    }

    /// <summary>
    /// 寻找机枪目标。
    /// </summary>
    public static function FindGunTarget(boss:Entity):Null<Entity>
    {
        return gunDetector.DetectEntityWithTheLeast(DetectionParams.fromEntity(boss), function(t) return Mathf.Abs(boss.Position.x - t.GetCenter().x));
    }
    public static function FindShockingTarget(boss:Entity):Null<Entity>
    {
        return boss.Level.FindFirstEntity(function(e) return IsShockable(boss, e));
    }
    public static function IsPunchable(boss:Entity, target:Entity):Bool
    {
        if (!LogicEntityExt.IsVulnerableEntity(target))
            return false;
        return boss.IsHostile(target) && Detection.IsAheadOfRange(target, boss, 20, 110) && target.GetLane() == boss.GetLane();
    }
    public static function IsShockable(boss:Entity, target:Entity):Bool
    {
        if (target.IsEntityOf(VanillaContraptionID.tnt))
            return true;
        return target.Type == EntityTypes.PLANT && boss.IsHostile(target) && Detection.IsAheadOf(target, boss, 20) && VanillaEntityProps.CanDeactive(target);
    }

    public static function DoTransformationEffects(boss:Entity):Void
    {
        // 震动特效
        var centerPos = boss.Position + awakeOffset;

        var level = boss.Level;
        level.Thunder();
        boss.PlaySound(VanillaSoundID.thunder);
        boss.PlaySound(VanillaSoundID.smash);
        level.Spawn(VanillaEffectID.thunderBolt, centerPos, boss);

        Explosion.Spawn(boss, centerPos, 60);

        var arcCounts = 8;
        var arcAngle = 360 / arcCounts;

        for (i in 0...arcCounts)
        {
            var rad = i * arcAngle * Mathf.Deg2Rad;

            var arc = level.Spawn(VanillaEffectID.electricArc, centerPos + Vector3.up, boss);
            if (arc != null)
            {
                var arcTargetPos = centerPos + new Vector3(Mathf.Sin(rad), 0, Mathf.Cos(rad)) * 100;
                ElectricArc.Connect(arc, arcTargetPos);
                ElectricArc.UpdateArc(arc);
            }
        }

        level.ShakeScreen(20, 0, 15);
    }
    public static function Paralyze(boss:Entity, source:Entity):Void
    {
        boss.TakeDamage(1200, new DamageEffectList([VanillaDamageEffects.LIGHTNING, VanillaDamageEffects.MUTE]), source);
        if (!boss.IsDead)
        {
            SetParalyzed(boss, true);
            stateMachine.StartState(boss, STATE_FAINT);
            var substateTimer = stateMachine.GetSubStateTimer(boss);
            if (substateTimer != null)
                substateTimer.ResetTime(300);
            boss.PlaySound(VanillaSoundID.powerOff);
        }
    }
    public static function CanTransformPhase(boss:Entity):Bool
    {
        if (VanillaDifficultyLevelProps.FrankensteinNoSteelPhase(boss.Level))
            return false;
        return boss.Health <= boss.GetMaxHealth() * 0.5 && !IsSteelPhase(boss);
    }

    public static function GetFrankensteinActionSpeed(boss:Entity):Float
    {
        return VanillaDifficultyLevelProps.GetFrankensteinSpeed(boss.Level);
    }

    // #region 属性
    public static function IsParalyzed(boss:Entity):Bool
    {
        return boss.GetBehaviourField(PROP_PARALYZED);
    }
    public static function SetParalyzed(boss:Entity, value:Bool):Void
    {
        boss.SetBehaviourField(PROP_PARALYZED, value);
    }

    public static function IsSteelPhase(boss:Entity):Bool
    {
        return boss.GetBehaviourField(PROP_STEEL_PHASE);
    }
    public static function SetSteelPhase(boss:Entity, value:Bool):Void
    {
        boss.SetBehaviourField(PROP_STEEL_PHASE, value);
        if (value)
        {
            boss.AddBuff(FrankensteinSteelBuff);
        }
        else
        {
            boss.RemoveBuffs(FrankensteinSteelBuff);
        }
        boss.SetAnimationBool("Steel", value);
    }

    public static function GetDetectTimer(boss:Entity):Null<FrameTimer>
    {
        return boss.GetBehaviourField(PROP_DETECT_TIMER);
    }
    public static function SetDetectTimer(boss:Entity, value:FrameTimer):Void
    {
        boss.SetBehaviourField(PROP_DETECT_TIMER, value);
    }

    public static function GetShockRNG(boss:Entity):Null<RandomGenerator>
    {
        return boss.GetBehaviourField(PROP_SHOCK_RNG);
    }
    public static function SetShockRNG(boss:Entity, value:RandomGenerator):Void
    {
        boss.SetBehaviourField(PROP_SHOCK_RNG, value);
    }

    public static function GetJumpRNG(boss:Entity):Null<RandomGenerator>
    {
        return boss.GetBehaviourField(PROP_JUMP_RNG);
    }
    public static function SetJumpRNG(boss:Entity, value:Null<RandomGenerator>):Void
    {
        boss.SetBehaviourField(PROP_JUMP_RNG, value);
    }

    public static function GetBulletRNG(boss:Entity):Null<RandomGenerator>
    {
        return boss.GetBehaviourField(PROP_BULLET_RNG);
    }
    public static function SetBulletRNG(boss:Entity, value:Null<RandomGenerator>):Void
    {
        boss.SetBehaviourField(PROP_BULLET_RNG, value);
    }

    public static function GetGunDirection(boss:Entity):Vector3
    {
        return boss.GetBehaviourField(PROP_GUN_DIRECTION);
    }
    public static function SetGunDirection(boss:Entity, direction:Vector3):Void
    {
        boss.SetBehaviourField(PROP_GUN_DIRECTION, direction);
        direction.x *= VanillaEntityExt.GetFacingX(boss);
        var innerAngle = Mathf.Repeat(Vector2.SignedAngle(Vector2.right, new Vector2(direction.x, direction.y)), 360);
        boss.SetAnimationFloat("InnerArmAngle", innerAngle);
    }

    public static function GetMissileDirection(boss:Entity):Vector3
    {
        return boss.GetBehaviourField(PROP_MISSILE_DIRECTION);
    }
    public static function SetMissileDirection(boss:Entity, direction:Vector3):Void
    {
        boss.SetBehaviourField(PROP_MISSILE_DIRECTION, direction);
        direction.x *= VanillaEntityExt.GetFacingX(boss);
        var innerAngle = Mathf.Repeat(Vector2.SignedAngle(Vector2.right, new Vector2(direction.x, direction.y)), 360);
        boss.SetAnimationFloat("OuterArmAngle", innerAngle);
    }

    public static function GetJumpTarget(boss:Entity):Vector3
    {
        return boss.GetBehaviourField(PROP_JUMP_TARGET);
    }
    public static function SetJumpTarget(boss:Entity, target:Vector3):Void
    {
        boss.SetBehaviourField(PROP_JUMP_TARGET, target);
    }
    // #endregion 属性

    // #region 常量
    public static var ID:NamespaceID = VanillaBossID.frankenstein;
    public static inline var detectIntervalFrames:Int = 3;
    public static inline var shootingPeriodFrames:Int = 60;
    public static inline var jumpFlyingTime:Float = 15;
    //private const float bulletSpeed = 10;
    //private const float missileSpeed = 8;
    public static inline var upperArmLength:Float = 60;
    public static var innerArmRootOffset:Vector3 = new Vector3(-12, 150, 0);
    public static var outerArmRootOffset:Vector3 = new Vector3(10, 134, 0);
    public static var headOffset:Vector3 = new Vector3(-12.5, 153, 0);
    public static var awakeOffset:Vector3 = new Vector3(-50, 0, 0);
    public static var gunDetector:Detector = new FrankensteinGunDetector(VanillaProjectileID.bullet);
    public static var missileDetector:Detector = new FrankensteinGunDetector(VanillaProjectileID.missile);

    public static var PROP_PARALYZED:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("Paralyzed");

    public static var PROP_JUMP_TARGET:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("JumpTarget");
    public static var PROP_STEEL_PHASE:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("SteelPhase");

    public static var PROP_GUN_DIRECTION:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("GunDirection");
    public static var PROP_MISSILE_DIRECTION:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("MissileDirection");

    public static var PROP_DETECT_TIMER:VanillaEntityPropertyMeta<FrameTimer> = new VanillaEntityPropertyMeta<FrameTimer>("DetectTimer");

    public static var PROP_SHOCK_RNG:VanillaEntityPropertyMeta<RandomGenerator> = new VanillaEntityPropertyMeta<RandomGenerator>("ShockRNG");
    public static var PROP_JUMP_RNG:VanillaEntityPropertyMeta<RandomGenerator> = new VanillaEntityPropertyMeta<RandomGenerator>("JumpRNG");
    public static var PROP_BULLET_RNG:VanillaEntityPropertyMeta<RandomGenerator> = new VanillaEntityPropertyMeta<RandomGenerator>("BulletRNG");

    public static inline var STATE_IDLE:Int = VanillaBossStates.IDLE;
    public static inline var STATE_WAKING:Int = VanillaBossStates.APPEAR;
    public static inline var STATE_FAINT:Int = VanillaBossStates.STUNNED;
    public static inline var STATE_DEAD:Int = VanillaBossStates.DEATH;
    public static inline var STATE_JUMP:Int = VanillaBossStates.FRANKENSTEIN_JUMP;
    public static inline var STATE_GUN:Int = VanillaBossStates.FRANKENSTEIN_GUN;
    public static inline var STATE_MISSILE:Int = VanillaBossStates.FRANKENSTEIN_MISSILE;
    public static inline var STATE_PUNCH:Int = VanillaBossStates.FRANKENSTEIN_PUNCH;
    public static inline var STATE_SHOCK:Int = VanillaBossStates.FRANKENSTEIN_SHOCK;

    public static inline var SUBSTATE_AWAKE_START:Int = 0;
    public static inline var SUBSTATE_AWAKE_LAUGH:Int = 1;
    public static inline var SUBSTATE_AWAKE_RISE:Int = 2;

    public static inline var SUBSTATE_GUN_READY:Int = 0;
    public static inline var SUBSTATE_GUN_FIRE:Int = 1;

    public static inline var SUBSTATE_DEAD_STAND:Int = 0;
    public static inline var SUBSTATE_DEAD_HEAD_DROPPED:Int = 1;

    public static inline var SUBSTATE_MISSILE_AIM:Int = 0;
    public static inline var SUBSTATE_MISSILE_FIRED:Int = 1;

    public static inline var SUBSTATE_PUNCH_READY:Int = 0;
    public static inline var SUBSTATE_PUNCH_FIRE:Int = 1;
    public static inline var SUBSTATE_PUNCH_FINISHED:Int = 2;

    public static inline var SUBSTATE_SHOCK_READY:Int = 0;
    public static inline var SUBSTATE_SHOCK_FINISHED:Int = 1;

    public static inline var SUBSTATE_JUMP_READY:Int = 0;
    public static inline var SUBSTATE_JUMP_IN_AIR:Int = 1;
    // #endregion 常量

    public static var stateMachine:FrankensteinStateMachine = new FrankensteinStateMachine();

    public static inline var ANIMATION_STATE_IDLE:Int = 0;
    public static inline var ANIMATION_STATE_AWAKE:Int = 1;
    public static inline var ANIMATION_STATE_JUMP:Int = 2;
    public static inline var ANIMATION_STATE_DEATH:Int = 3;
    public static inline var ANIMATION_STATE_GUN:Int = 4;
    public static inline var ANIMATION_STATE_MISSILE:Int = 5;
    public static inline var ANIMATION_STATE_PUNCH:Int = 6;
    public static inline var ANIMATION_STATE_SHOCK:Int = 7;
    public static inline var ANIMATION_STATE_FAINT:Int = 8;
}

// #region 状态机
private class FrankensteinStateMachine extends EntityStateMachine
{
    public function new()
    {
        super();
        AddState(new IdleState());
        AddState(new JumpState());
        AddState(new GunState());
        AddState(new DeadState());
        AddState(new MissileState());
        AddState(new PunchState());
        AddState(new ShockState());
        AddState(new AwakeState());
        AddState(new FaintState());
    }
    override public function GetSpeed(entity:Entity):Float
    {
        return Frankenstein.GetFrankensteinActionSpeed(entity);
    }
    override public function OnEnterState(entity:Entity, state:Int):Void
    {
        super.OnEnterState(entity, state);
        if (state == Frankenstein.STATE_WAKING || (state == Frankenstein.STATE_FAINT && !Frankenstein.IsParalyzed(entity)))
        {
            entity.AddBuff(FrankensteinTransformingBuff);
        }
        else
        {
            entity.RemoveBuffs(FrankensteinTransformingBuff);
        }
        entity.SetAnimationBool("EyelightStable", state != Frankenstein.STATE_FAINT && state != Frankenstein.STATE_DEAD);

        var detectTimer = Frankenstein.GetDetectTimer(entity);
        if (detectTimer != null)
            detectTimer.Stop();
    }
}
// #endregion

// #region 状态
private class IdleState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_IDLE, Frankenstein.ANIMATION_STATE_IDLE);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var stateTimer = stateMachine.GetStateTimer(entity);
        if (stateTimer != null)
            stateTimer.ResetTime(90);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var nextStateTimer = stateMachine.GetStateTimer(entity);
        if (nextStateTimer == null || !nextStateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
            return;

        var lastState = stateMachine.GetPreviousState(entity);
        if (Frankenstein.IsSteelPhase(entity))
        {
            if (lastState == Frankenstein.STATE_JUMP)
            {
                lastState = Frankenstein.STATE_PUNCH;
                entity.Target = Frankenstein.FindPunchTarget(entity);
                if (entity.Target != null)
                {
                    stateMachine.StartState(entity, lastState);
                    stateMachine.SetPreviousState(entity, lastState);
                    return;
                }
            }

            if (lastState == Frankenstein.STATE_PUNCH)
            {
                lastState = Frankenstein.STATE_SHOCK;
                entity.Target = Frankenstein.FindShockingTarget(entity);
                if (entity.Target != null)
                {
                    stateMachine.StartState(entity, lastState);
                    stateMachine.SetPreviousState(entity, lastState);
                    return;
                }
            }
        }
        if (lastState != Frankenstein.STATE_GUN)
        {
            lastState = Frankenstein.STATE_GUN;
            entity.Target = Frankenstein.FindGunTarget(entity);
            if (entity.Target != null)
            {
                stateMachine.StartState(entity, lastState);
                stateMachine.SetPreviousState(entity, lastState);
                return;
            }
        }

        lastState = Frankenstein.STATE_JUMP;
        stateMachine.StartState(entity, lastState);
        stateMachine.SetPreviousState(entity, lastState);
    }
}
private class AwakeState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_WAKING, Frankenstein.ANIMATION_STATE_AWAKE);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        Frankenstein.SetParalyzed(entity, false);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(30);
        entity.PlaySound(VanillaSoundID.powerOn);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);

        if (substateTimer == null || !substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
            return;

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case Frankenstein.SUBSTATE_AWAKE_START:
                entity.PlaySound(Frankenstein.IsSteelPhase(entity) ? VanillaSoundID.frankensteinSteelLaugh : VanillaSoundID.frankensteinLaugh);
                stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_AWAKE_LAUGH);
                substateTimer.ResetTime(60);

            case Frankenstein.SUBSTATE_AWAKE_LAUGH:
                stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_AWAKE_RISE);
                substateTimer.ResetTime(100);

            case Frankenstein.SUBSTATE_AWAKE_RISE:
                stateMachine.StartState(entity, Frankenstein.STATE_IDLE);
        }
    }
}
private class DeadState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_DEAD, Frankenstein.ANIMATION_STATE_DEATH);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);

        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(90);

        entity.SetAnimationBool("Sparks", true);
        LogicLevelExt.AddLoopSoundEntity(entity.Level, VanillaSoundID.electricSpark, entity.ID);
    }
    override public function OnUpdateLogic(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer.RunToExpiredAndNotNull())
        {
            var substate = stateMachine.GetSubState(entity);
            switch (substate)
            {
                case Frankenstein.SUBSTATE_DEAD_STAND:
                    DropHead(entity);
                    stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_DEAD_HEAD_DROPPED);
                    substateTimer.ResetTime(120);
                case Frankenstein.SUBSTATE_DEAD_HEAD_DROPPED:
                    Explosion.Spawn(entity, entity.GetCenter(), 120);

                    entity.PlaySound(VanillaSoundID.explosion);
                    entity.Level.ShakeScreen(10, 0, 15);
                    entity.Remove();
            }
        }
    }
    private function DropHead(boss:Entity):Void
    {
        var level = boss.Level;
        var headPos = boss.Position + Frankenstein.headOffset;
        var headEffect = level.Spawn(VanillaEffectID.frankensteinHead, headPos, boss);
        if (headEffect != null)
        {
            headEffect.Velocity += new Vector3(VanillaEntityExt.GetFacingX(boss) * 5, 1, 0);
            headEffect.SetDisplayScale(new Vector3(-VanillaEntityExt.GetFacingX(boss), 1, 1));
            FrankensteinHead.SetSteelPhase(headEffect, Frankenstein.IsSteelPhase(boss));
        }

        level.ShakeScreen(5, 0, 15);
        boss.PlaySound(VanillaSoundID.explosion);
        boss.PlaySound(VanillaSoundID.powerOff);

        Explosion.Spawn(boss, headPos, 30);
    }
}
private class FaintState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_FAINT, Frankenstein.ANIMATION_STATE_FAINT);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null && substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
        {
            if (Frankenstein.CanTransformPhase(entity))
            {
                Frankenstein.EnterSteelPhase(entity);
                Frankenstein.DoTransformationEffects(entity);
            }
            stateMachine.StartState(entity, Frankenstein.STATE_WAKING);
        }
    }
}
private class GunState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_GUN, Frankenstein.ANIMATION_STATE_GUN);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(30);
        var detectTimer = Frankenstein.GetDetectTimer(entity);
        if (detectTimer != null)
            detectTimer.Reset();
        Frankenstein.SetGunDirection(entity, VanillaEntityExt.GetFacingDirection(entity));

        entity.PlaySound(VanillaSoundID.gunReload);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substate = stateMachine.GetSubState(entity);
        // 如果没有开火，计时器结束时开火。
        if (substate == Frankenstein.SUBSTATE_GUN_READY)
        {
            var substateTimer = stateMachine.GetSubStateTimer(entity);
            if (substateTimer != null && substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
            {
                substate = Frankenstein.SUBSTATE_GUN_FIRE;
                substateTimer.ResetTime(Frankenstein.shootingPeriodFrames);
                stateMachine.StartSubState(entity, substate);
            }
        }
        // 寻找机枪目标
        var detectTimer = Frankenstein.GetDetectTimer(entity);
        if (detectTimer != null)
        {
            detectTimer.Run(stateMachine.GetSpeed(entity));
            if (detectTimer.Expired || entity.Target == null || !unity.UnityObject.exists(entity.Target))
            {
                detectTimer.ResetTime(Frankenstein.detectIntervalFrames);
                entity.Target = Frankenstein.FindGunTarget(entity);
            }
        }

        substate = stateMachine.GetSubState(entity);
        // 如果有目标，并且正在开火，则发射子弹
        if (entity.Target != null && unity.UnityObject.exists(entity.Target))
        {
            if (substate == Frankenstein.SUBSTATE_GUN_FIRE)
            {
                ShootBullets(stateMachine, entity);
            }
        }
        // 如果没有目标，结束开火。
        else
        {
            EndFiringBullets(stateMachine, entity);
        }
    }
    /// <summary>
    /// 停止发射子弹。
    /// </summary>
    private function EndFiringBullets(stateMachine:EntityStateMachine, boss:Entity):Void
    {
        boss.Target = Frankenstein.FindMissileTarget(boss);
        if (boss.Target != null)
        {
            stateMachine.StartState(boss, Frankenstein.STATE_MISSILE);
        }
        else
        {
            stateMachine.StartState(boss, Frankenstein.STATE_IDLE);
        }
    }

    /// <summary>
    /// 发射一颗子弹。
    /// </summary>
    private function ShootABullet(boss:Entity):Void
    {
        var armRootPosition = boss.Position + Frankenstein.innerArmRootOffset;

        var rng = Frankenstein.GetBulletRNG(boss);
        var gunDirection = Frankenstein.GetGunDirection(boss);
        if (rng != null)
        {
            gunDirection.x = gunDirection.x * rng.Next(95, 110) / 100;
            gunDirection.y = gunDirection.y * rng.Next(95, 110) / 100;
            gunDirection.z = gunDirection.z * rng.Next(95, 110) / 100;
        }
        gunDirection = gunDirection.normalized;
        Frankenstein.SetGunDirection(boss, gunDirection);

        var gunPosition = armRootPosition + gunDirection * Frankenstein.upperArmLength;

        var param = VanillaProjectileExt.GetShootParams(boss);
        param.projectileID = VanillaProjectileID.bullet;
        param.position = gunPosition;
        param.velocity = gunDirection * VanillaEntityProps.GetShotVelocity(boss).magnitude;
        param.damage = VanillaEntityProps.GetDamage(boss) * 0.1;
        param.soundID = VanillaSoundID.gunShot;
        var bullet = VanillaProjectileExt.ShootProjectile(boss, param);
        boss.TriggerAnimation("GunFire");
        boss.TriggerModel("GunFire");
    }

    /// <summary>
    /// 持续发射子弹。
    /// </summary>
    private function ShootBullets(stateMachine:EntityStateMachine, boss:Entity):Void
    {
        var substateTimer = stateMachine.GetSubStateTimer(boss);
        if (substateTimer == null)
            return;
        substateTimer.Run(stateMachine.GetSpeed(boss));
        var intervalCount = substateTimer.PassedIntervalCount(1);
        for (i in 0...intervalCount)
        {
            ShootABullet(boss);
        }
        if (substateTimer.Expired)
        {
            EndFiringBullets(stateMachine, boss);
        }
    }
}
private class MissileState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_MISSILE, Frankenstein.ANIMATION_STATE_MISSILE);
    }

    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        var detectTimer = Frankenstein.GetDetectTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(30);
        if (detectTimer != null)
            detectTimer.ResetTime(Frankenstein.detectIntervalFrames);
        Frankenstein.SetMissileDirection(entity, VanillaEntityExt.GetFacingDirection(entity));
        entity.PlaySound(VanillaSoundID.gunReload);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var detectTimer = Frankenstein.GetDetectTimer(entity);
        if (detectTimer != null)
        {
            detectTimer.Run(stateMachine.GetSpeed(entity));
            if (detectTimer.Expired)
            {
                detectTimer.ResetTime(Frankenstein.detectIntervalFrames);
                entity.Target = Frankenstein.FindMissileTarget(entity);
            }
        }
        if (entity.Target == null || !unity.UnityObject.exists(entity.Target))
        {
            stateMachine.StartState(entity, Frankenstein.STATE_IDLE);
            return;
        }

        var substate = stateMachine.GetSubState(entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null && substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
        {
            switch (substate)
            {
                case Frankenstein.SUBSTATE_MISSILE_AIM:
                    FireMissile(stateMachine, entity);
                case Frankenstein.SUBSTATE_MISSILE_FIRED:
                    stateMachine.StartState(entity, Frankenstein.STATE_IDLE);
            }
        }
    }

    private function FireMissile(stateMachine:EntityStateMachine, boss:Entity):Void
    {
        stateMachine.StartSubState(boss, Frankenstein.SUBSTATE_MISSILE_FIRED);
        var substateTimer = stateMachine.GetSubStateTimer(boss);
        if (substateTimer != null)
            substateTimer.ResetTime(9);

        var armRootPosition = boss.Position + Frankenstein.outerArmRootOffset;
        var missileDirection = Frankenstein.GetMissileDirection(boss);
        var missilePosition = armRootPosition + missileDirection * 80;
        var missileSpeed = VanillaEntityProps.GetShotVelocity(boss).magnitude * 0.8;

        var param = VanillaProjectileExt.GetShootParams(boss);
        param.projectileID = VanillaProjectileID.missile;
        param.position = missilePosition;
        param.velocity = missileDirection * missileSpeed;
        param.damage = VanillaEntityProps.GetDamage(boss) * 2;
        param.soundID = VanillaSoundID.missile;
        var missile = VanillaProjectileExt.ShootProjectile(boss, param);
    }
}
private class JumpState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_JUMP, Frankenstein.ANIMATION_STATE_JUMP);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(24);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null && substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
        {
            var substate = stateMachine.GetSubState(entity);
            switch (substate)
            {
                case Frankenstein.SUBSTATE_JUMP_READY:
                    stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_JUMP_IN_AIR);
                    Jump(entity);

                case Frankenstein.SUBSTATE_JUMP_IN_AIR:
                    var target = Frankenstein.GetJumpTarget(entity);
                    var pos = entity.Position;
                    pos.x = pos.x * 0.8 + target.x * 0.2;
                    pos.z = pos.z * 0.8 + target.z * 0.2;
                    entity.Position = pos;

                    var spawnParam = entity.GetSpawnParams();
                    spawnParam.SetProperty(EngineEntityProps.FLIP_X, entity.IsFlipX());
                    spawnParam.SetProperty(EngineEntityProps.SCALE, entity.GetScale());
                    spawnParam.SetProperty(EngineEntityProps.DISPLAY_SCALE, entity.GetDisplayScale());
                    entity.Level.Spawn(VanillaEffectID.frankensteinJumpTrail, entity.GetCenter(), entity, spawnParam);
                    if (entity.IsOnGround)
                    {
                        Land(stateMachine, entity);
                    }
            }
        }
    }
    private function Jump(boss:Entity):Void
    {
        var grid = SearchJumpPlace(boss);
        Frankenstein.SetJumpTarget(boss, grid != null ? grid.GetEntityPosition() : boss.Position);

        var velocity = boss.Velocity;
        velocity.y = boss.GetGravity() * Frankenstein.jumpFlyingTime;
        boss.Velocity = velocity;
        boss.PlaySound(VanillaSoundID.thunder);
    }

    private function Land(stateMachine:EntityStateMachine, boss:Entity):Void
    {
        stateMachine.StartState(boss, Frankenstein.STATE_IDLE);

        var level = boss.Level;
        var bossColumn = boss.GetColumn();
        var bossLane = boss.GetLane();
        for (ent in level.GetEntities())
        {
            if (!LogicEntityExt.IsVulnerableEntity(ent) || !boss.IsHostile(ent) || ent.GetColumn() != bossColumn || ent.GetLane() != bossLane)
                continue;
            var damage = VanillaEntityProps.GetTakenCrushDamage(ent);
            var damageOutput = ent.TakeDamage(damage, new DamageEffectList([VanillaDamageEffects.IMPACT, VanillaDamageEffects.IGNORE_ARMOR]), boss);
            if (ent.Type == EntityTypes.PLANT)
            {
                if (damageOutput != null && damageOutput.BodyResult != null && damageOutput.BodyResult.Fatal)
                {
                    boss.PlaySound(VanillaSoundID.smash);
                }
            }
        }
        level.ShakeScreen(5, 0, 15);
        boss.PlaySound(VanillaSoundID.thump);
        if (Frankenstein.IsSteelPhase(boss))
        {
            boss.PlaySound(VanillaSoundID.anvil);
        }
    }

    private function SearchJumpPlace(boss:Entity):Null<LawnGrid>
    {
        var level = boss.Level;
        var maxColumn = level.GetMaxColumnCount();
        var maxLane = level.GetMaxLaneCount();

        var column = 0;
        var lane = 0;
        // C#: level.GetEntities().Where(...).GroupBy(e => e.GetLane())
        var laneEnemyGroups:Map<Int, Array<Entity>> = new Map();
        var laneOrder:Array<Int> = [];
        for (e in level.GetEntities())
        {
            if (!LogicEntityExt.IsVulnerableEntity(e) || !boss.IsHostile(e) || e.GetLane() < 0 || e.GetLane() >= maxLane || e.GetLane() == boss.GetLane())
                continue;
            var laneIndex = e.GetLane();
            if (!laneEnemyGroups.exists(laneIndex))
            {
                laneEnemyGroups.set(laneIndex, []);
                laneOrder.push(laneIndex);
            }
            laneEnemyGroups.get(laneIndex).push(e);
        }
        if (laneOrder.length == 0)
        {
            if (boss.IsFacingLeft())
            {
                column = boss.RNG.Next(maxColumn - 3, maxColumn);
            }
            else
            {
                column = boss.RNG.Next(0, 3);
            }
            lane = boss.RNG.Next(0, maxLane);
            return level.GetGrid(column, lane);
        }
        var maxEnemyCount = 0;
        for (laneIndex in laneOrder)
        {
            maxEnemyCount = Std.int(Math.max(maxEnemyCount, laneEnemyGroups.get(laneIndex).length));
        }
        var maxCountGroups:Array<Array<Entity>> = [];
        for (laneIndex in laneOrder)
        {
            if (laneEnemyGroups.get(laneIndex).length == maxEnemyCount)
                maxCountGroups.push(laneEnemyGroups.get(laneIndex));
        }
        var jumpRNG = Frankenstein.GetJumpRNG(boss);
        var targetLaneGroup = jumpRNG != null ? EnumerableExt.Random(maxCountGroups, jumpRNG) : maxCountGroups[0];
        if (boss.IsFacingLeft())
        {
            var target = EnumerableExt.OrderByDescending(targetLaneGroup, function(e) return e.GetColumn())[0];
            column = Mathf.ClampInt(target.GetColumn() + 1, maxColumn - 3, maxColumn - 1);
            lane = target.GetLane();
        }
        else
        {
            var target = EnumerableExt.OrderBy(targetLaneGroup, function(e) return e.GetColumn())[0];
            column = Mathf.ClampInt(target.GetColumn() - 1, 0, 2);
            lane = target.GetLane();
        }
        return level.GetGrid(column, lane);
    }
}
private class PunchState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_PUNCH, Frankenstein.ANIMATION_STATE_PUNCH);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        return substate;
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(30);
        entity.PlaySound(VanillaSoundID.teslaPower);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null && substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
        {
            var substate = stateMachine.GetSubState(entity);
            switch (substate)
            {
                case Frankenstein.SUBSTATE_PUNCH_READY:
                    stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_PUNCH_FIRE);
                    substateTimer.ResetTime(3);

                case Frankenstein.SUBSTATE_PUNCH_FIRE:
                    stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_PUNCH_FINISHED);
                    substateTimer.ResetTime(15);
                    Punch(entity);

                case Frankenstein.SUBSTATE_PUNCH_FINISHED:
                    stateMachine.StartState(entity, Frankenstein.STATE_IDLE);
            }
        }
    }
    private function Punch(boss:Entity):Void
    {
        for (ent in boss.Level.FindEntities(function(e) return Frankenstein.IsPunchable(boss, e)))
        {
            var damage = VanillaEntityProps.GetTakenCrushDamage(ent);
            ent.TakeDamage(damage, new DamageEffectList([VanillaDamageEffects.IMPACT, VanillaDamageEffects.IGNORE_ARMOR]), boss);
        }
        boss.Level.ShakeScreen(5, 0, 15);
        boss.PlaySound(VanillaSoundID.teslaAttack);
        boss.PlaySound(VanillaSoundID.smash);
    }
}
private class ShockState extends EntityStateMachineState
{
    public function new()
    {
        super(Frankenstein.STATE_SHOCK, Frankenstein.ANIMATION_STATE_SHOCK);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null)
            substateTimer.ResetTime(30);
        entity.PlaySound(VanillaSoundID.teslaPower);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        if (substateTimer != null && substateTimer.RunToExpired(stateMachine.GetSpeed(entity)))
        {
            var substate = stateMachine.GetSubState(entity);
            switch (substate)
            {
                case Frankenstein.SUBSTATE_SHOCK_READY:
                    stateMachine.StartSubState(entity, Frankenstein.SUBSTATE_SHOCK_FINISHED);
                    entity.Target = Frankenstein.FindShockingTarget(entity);
                    if (entity.Target != null)
                    {
                        Shock(entity);
                    }
                    substateTimer.ResetTime(15);

                case Frankenstein.SUBSTATE_SHOCK_FINISHED:
                    stateMachine.StartState(entity, Frankenstein.STATE_IDLE);
            }
        }
    }

    private function Shock(boss:Entity):Void
    {
        var level = boss.Level;
        var shockables = level.FindEntities(function(e) return Frankenstein.IsShockable(boss, e));
        var targetsID = Lambda.map(shockables, function(e) return e.GetDefinitionID());
        if (targetsID.length <= 0)
            return;

        var rng = Frankenstein.GetShockRNG(boss);
        var contrapId = rng != null ? EnumerableExt.Random(targetsID, rng) : (targetsID.length > 0 ? targetsID[0] : null);

        var soundPlayed = false;
        // 再次遍历可以电击的器械。
        for (contraption in shockables)
        {
            if (contraption.IsEntityOf(VanillaContraptionID.tnt))
            {
                TNT.Charge(contraption);
                var arc = level.Spawn(VanillaEffectID.electricArc, boss.Position + Frankenstein.outerArmRootOffset + Vector3.left * 100, boss);
                if (arc != null)
                {
                    ElectricArc.Connect(arc, contraption.Position);
                    ElectricArc.UpdateArc(arc);
                }
            }
            else if (contrapId != null && contraption.IsEntityOf(contrapId))
            {
                VanillaEntityExt.ShortCircuit(contraption, 150, new EntitySourceReference(boss));
                if (!soundPlayed)
                {
                    contraption.PlaySound(VanillaSoundID.powerOff);
                    soundPlayed = true;
                }
                var arc = level.Spawn(VanillaEffectID.electricArc, boss.Position + Frankenstein.outerArmRootOffset + Vector3.left * 100, boss);
                if (arc != null)
                {
                    ElectricArc.Connect(arc, contraption.Position);
                    ElectricArc.UpdateArc(arc);
                }
            }
        }
        boss.PlaySound(VanillaSoundID.teslaAttack);
    }
}
// #endregion

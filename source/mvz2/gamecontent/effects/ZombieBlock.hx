// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Chapter4/ZombieBlock.cs
package mvz2.gamecontent.effects;

import mvz2.gamecontent.detections.CollisionDetector;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.collisions.IEntityCollider;
import pvzengine.damages.DamageEffectList;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import tools.FrameTimer;
import tools.ObjectExtensions;
import unity.Mathf;
import unity.Vector3;
import unity.UnityObject;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;
import mvz2.vanilla.detection.Detector.DetectionParams;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaEffectNames.zombieBlock)
class ZombieBlock extends EffectBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        SetMoveCooldownTimer(entity, new FrameTimer(0));
        entity.CollisionMaskHostile |= EntityCollisionHelper.MASK_VULNERABLE;
    }
    public override function Update(entity:Entity):Void
    {
        super.Update(entity);
        var parent = entity.Parent;
        if (parent == null || !unity.UnityObject.exists(parent))
        {
            entity.Remove();
            return;
        }


        var mode = GetMode(entity);
        switch (mode)
        {
            case MODE_FLY, MODE_TRANSFORM:
                {
                    var cooldownTimer = GetMoveCooldownTimer(entity);
                    // PORT-NOTE: C# FrameTimer.RunToExpiredAndNotNull() 在 tools.FrameTimer shim 中未提供，按语义拆成显式判空。
                    if (cooldownTimer != null && cooldownTimer.RunToExpired())
                    {
                        var targetPosition = GetTargetPosition(entity);
                        if (!IsReached(entity))
                        {
                            var vel = (targetPosition - entity.Position).normalized * MOVE_SPEED;
                            entity.Velocity = vel;
                        }
                        else
                        {
                            entity.Velocity = Vector3.zero;
                            entity.Position = entity.Position * 0.7 + targetPosition * 0.3;
                        }
                    }
                    else
                    {
                        var startPosition = GetStartPosition(entity);
                        entity.Position = entity.Position * 0.7 + startPosition * 0.3;
                    }
                }
            case MODE_JUMP:
                {
                    var cooldownTimer = GetMoveCooldownTimer(entity);
                    if (cooldownTimer != null && cooldownTimer.RunToExpired())
                    {
                        if (entity.IsOnGround)
                        {
                            var targetPosition = GetTargetPosition(entity);
                            if (IsReached(entity))
                            {
                                entity.Velocity = Vector3.zero;
                            }
                            else
                            {
                                var jumpDistance = GetJumpDistance(entity);

                                var gravity = entity.GetGravity();
                                var distance = targetPosition - entity.Position;

                                jumpDistance *= Mathf.Sign(distance.x);
                                if (distance.x > 0 && jumpDistance > distance.x)
                                {
                                    jumpDistance = distance.x;
                                }
                                else if (distance.x < 0 && jumpDistance < distance.x)
                                {
                                    jumpDistance = distance.x;
                                }
                                var nextX = entity.Position.x + jumpDistance;
                                var nextColumn = entity.Level.GetColumn(nextX);
                                nextX = entity.Level.GetEntityColumnX(nextColumn);
                                var nextZ = entity.Position.z;
                                var nextY = entity.Level.GetGroundY(nextX, nextZ);
                                var nextPosition = new Vector3(nextX, nextY, nextZ);

                                var maxY = nextY + 80;

                                entity.Velocity = VanillaProjectileExt.GetLobVelocity(entity.Position, nextPosition, maxY, gravity);
                            }

                            jumpBuffer.resize(0);
                            jumpDetector.DetectMultiple(DetectionParams.fromEntity(entity), jumpBuffer);
                            for (collider in jumpBuffer)
                            {
                                var other = collider.Entity;
                                if (entity.IsHostile(other))
                                {
                                    collider.TakeDamage(entity.GetDamage(), new DamageEffectList([]), entity);
                                }
                            }
                        }
                    }
                    else
                    {
                        var startPosition = GetStartPosition(entity);
                        entity.Position = entity.Position * 0.7 + startPosition * 0.3;
                    }
                }
            case MODE_SNAKE_FOOD:
                {
                    var startPosition = GetStartPosition(entity);
                    entity.Position = entity.Position * 0.7 + startPosition * 0.3;
                }
            default:
        }
    }
    public override function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        if (state != EntityCollisionHelper.STATE_ENTER)
            return;
        var block = collision.Entity;
        var other = collision.Other;
        var mode = GetMode(block);
        switch (mode)
        {
            case MODE_FLY:
                if (block.IsHostile(other) && other.CanDeactive())
                {
                    other.Stun(STUN_DURATION);
                    other.PlaySound(VanillaSoundID.punch);
                }
            default:
        }
    }
    public static function IsReached(entity:Entity):Bool
    {
        var targetPos = GetTargetPosition(entity);
        return (targetPos - entity.Position).sqrMagnitude <= MOVE_SPEED * MOVE_SPEED;
    }
    public static function SetMoveCooldown(entity:Entity, time:Int):Void
    {
        var moveTimer = GetMoveCooldownTimer(entity);
        if (moveTimer == null)
            return;
        moveTimer.ResetTime(time);
    }
    public static function GetMode(entity:Entity):Int return entity.GetBehaviourField(PROP_MODE);
    public static function SetMode(entity:Entity, value:Int):Void entity.SetBehaviourField(PROP_MODE, value);
    public static function GetMoveCooldownTimer(entity:Entity):Null<FrameTimer> return entity.GetBehaviourField(PROP_MOVE_COOLDOWN_TIMER);
    public static function SetMoveCooldownTimer(entity:Entity, value:FrameTimer):Void entity.SetBehaviourField(PROP_MOVE_COOLDOWN_TIMER, value);
    public static function GetJumpDistance(entity:Entity):Float return entity.GetBehaviourField(PROP_JUMP_DISTANCE);
    public static function SetJumpDistance(entity:Entity, value:Float):Void entity.SetBehaviourField(PROP_JUMP_DISTANCE, value);
    public static function GetStartPosition(entity:Entity):Vector3 return entity.GetBehaviourField(PROP_START_POSITION);
    public static function SetStartPosition(entity:Entity, value:Vector3):Void entity.SetBehaviourField(PROP_START_POSITION, value);
    public static function SetStartGrid(entity:Entity, column:Int, lane:Int):Void SetStartPosition(entity, entity.Level.GetEntityGridPosition(column, lane));
    public static function GetTargetPosition(entity:Entity):Vector3 return entity.GetBehaviourField(PROP_TARGET_POSITION);
    public static function SetTargetPosition(entity:Entity, value:Vector3):Void entity.SetBehaviourField(PROP_TARGET_POSITION, value);
    public static function SetTargetGrid(entity:Entity, column:Int, lane:Int):Void entity.SetBehaviourField(PROP_TARGET_POSITION, entity.Level.GetEntityGridPosition(column, lane));

    public static inline var MOVE_SPEED:Float = 20;
    public static inline var STUN_DURATION:Int = 90;

    public static inline var MODE_FLY:Int = 0;
    public static inline var MODE_JUMP:Int = 1;
    public static inline var MODE_TRANSFORM:Int = 2;
    public static inline var MODE_SNAKE_FOOD:Int = 3;

    private var jumpDetector:Detector = new CollisionDetector(true);
    private var jumpBuffer:Array<IEntityCollider> = [];

    private static var PROP_MODE:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("Mode");
    private static var PROP_MOVE_COOLDOWN_TIMER:VanillaEntityPropertyMeta<FrameTimer> = new VanillaEntityPropertyMeta<FrameTimer>("MoveCooldownTimer");
    private static var PROP_JUMP_DISTANCE:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("JumpDistance");
    private static var PROP_START_POSITION:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("StartPosition");
    private static var PROP_TARGET_POSITION:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("TargetPosition");
}

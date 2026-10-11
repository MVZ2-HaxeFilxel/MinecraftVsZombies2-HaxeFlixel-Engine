// Ported from: Assets/Scripts/Vanilla/GameContent/Enemies/Chapter2/Spider.cs
package mvz2.gamecontent.enemies;

import mvz2.gamecontent.buffs.enemies.SpiderClimbBuff;
import mvz2.gamecontent.entities.AIEntityBehaviour;
import mvz2.vanilla.contraptions.VanillaContraptionExt;
import mvz2.vanilla.detection.Detection;
import mvz2.vanilla.enemies.VanillaEnemyStates;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.EntityID;
import pvzengine.NamespaceID;
import pvzengine.buffs.BuffExt;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityTypes;
import unity.Mathf;
import unity.UnityObject;
using mvz2.vanilla.contraptions.VanillaContraptionProps;
using mvz2.vanilla.detection.Detection;
using mvz2.vanilla.enemies.VanillaEnemyProps;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityProps;

@:autoEntityBehaviourDefinition(VanillaEnemyNames.spider)
class Spider extends AIEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }
    override function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);

        if (entity.State == STATE_CLIMB)
        {
            var climbTarget = Spider.GetClimbTarget(entity);
            if (climbTarget.ExistsAndAlive())
            {
                // 正在垂直攀爬，修改位置。
                var peak = Spider.GetClimbTargetPeak(climbTarget);
                if (entity.Position.y < peak)
                {
                    var position = entity.Position;
                    position.y = Mathf.Min(position.y + (0.83 * entity.GetSpeed()), peak);
                    entity.Position = position;
                }
            }
        }
    }
    override function UpdateLogic(entity:Entity):Void
    {
        super.UpdateLogic(entity);

        // 攀爬目标不合适，那就取消。
        var climbTarget = GetClimbTarget(entity);
        if (climbTarget != null && !ValidateClimbTarget(entity, climbTarget))
        {
            climbTarget = null;
            SetClimbTarget(entity, null);
        }
        if (climbTarget.ExistsAndAlive())
        {
            // 攀爬目标合适。
            // 没有攀爬BUFF，那就加上一个。
            if (!entity.HasBuff(SpiderClimbBuff))
            {
                entity.AddBuff(SpiderClimbBuff);
            }
            if (entity.State == STATE_CLIMB)
            {
                // 正在攀爬目标上行走。
                var velocity = entity.Velocity;
                velocity.y = Mathf.Max(0, velocity.y);
                entity.Velocity = velocity;
            }
        }
        else
        {
            // 没有正在攀爬，移除增益。
            if (entity.HasBuff(SpiderClimbBuff))
            {
                entity.RemoveBuffs(SpiderClimbBuff);
            }
        }
    }
    public override function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        if (collision.Collider.IsForMain() && collision.OtherCollider.IsForMain())
        {
            var enemy = collision.Entity;
            var other = collision.Other;
            if (state != EntityCollisionHelper.STATE_EXIT)
            {
                // 可以成为攀爬目标。
                if (CanClimb(enemy, other))
                {
                    // 如果目标可以爬，并且两者之间的关系处在可以爬的状态，那就设置为攀爬目标
                    var currentTarget = GetClimbTarget(enemy);
                    if (!(currentTarget != null && ValidateClimbTarget(enemy, currentTarget)) && ValidateClimbTarget(enemy, other))
                    {
                        SetClimbTarget(enemy, other);
                    }
                }
            }
            else
            {
                // 离开碰撞时，如果对面就是攀爬目标，取消攀爬目标。
                if (GetClimbTarget(enemy) == other)
                {
                    SetClimbTarget(enemy, null);
                }
            }
        }
    }
    public static function IsClimbingVertically(spider:Entity):Bool
    {
        var target = GetClimbTarget(spider);
        if (target == null)
            return false;

        return spider.Position.y < GetClimbTargetPeak(target);
    }
    public static function GetClimbTargetPeak(target:Entity):Float
    {
        return target.GetBounds().max.y - 5;
    }
    public static function CanClimb(enemy:Entity, target:Entity):Bool
    {
        if (target == null || !unity.UnityObject.exists(target) || target.IsDead)
            return false;
        if (!enemy.IsHostile(target))
            return false;
        if (!Detection.IsInSameRow(enemy, target))
            return false;
        if (!Detection.CanDetect(target))
            return false;
        if (target.Type != EntityTypes.PLANT)
            return false;
        if (target.IsFloor() || !target.IsDefensive() || target.NoClimb())
            return false;
        return true;
    }
    function ValidateClimbTarget(enemy:Entity, target:Entity):Bool
    {
        return CanClimb(enemy, target) && !enemy.IsAIFrozen() && !enemy.IsDead && target.IsAheadOf(enemy, -enemy.GetScaledSize().x * 0.25);
    }

    public static function GetClimbTarget(spider:Entity):Null<Entity>
    {
        var id = spider.GetBehaviourFieldNS(ID, PROP_CLIMB_TARGET_ID);
        if (id == null)
            return null;
        return id.GetEntity(spider.Level);
    }
    public static function SetClimbTarget(spider:Entity, value:Null<Entity>):Void
    {
        spider.SetBehaviourFieldNS(ID, PROP_CLIMB_TARGET_ID, value != null ? new EntityID(value) : null);
    }
    public static var ID:NamespaceID = VanillaEnemyID.spider;
    public static var PROP_CLIMB_TARGET_ID:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("ClimbTargetID");
    public static inline var STATE_CLIMB:Int = VanillaEnemyStates.SPIDER_CLIMB;
}

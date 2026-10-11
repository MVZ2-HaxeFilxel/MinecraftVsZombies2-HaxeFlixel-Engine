// Ported from: Assets/Scripts/Vanilla/GameContent/Enemies/Melee/EnemyMeleeBehaviour.cs
package mvz2.gamecontent.enemies;

import unity.UnityObject;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.entities.AIEntityBehaviour;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.contraptions.VanillaContraptionExt;
import mvz2.vanilla.detection.Detection;
import mvz2.vanilla.entities.VanillaEntityBehaviourNames;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEnemyStates;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.level.LogicLevelExt;
import pvzengine.EntityID;
import pvzengine.damages.DamageEffectList;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityTypes;
using mvz2.vanilla.contraptions.VanillaContraptionExt;
using mvz2.vanilla.contraptions.VanillaContraptionProps;
using mvz2.vanilla.enemies.VanillaEnemyProps;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;

@:autoEntityBehaviourDefinition(VanillaEntityBehaviourNames.enemyMelee)
class EnemyMeleeBehaviour extends AIEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    //region 更新
    override function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);
        if (!MeleeEnabled(entity))
            return;
        var targetID = GetMeleeTarget(entity);
        if (targetID != null && !ValidateMeleeTarget(entity, targetID.GetEntity(entity.Level)))
        {
            SetMeleeTarget(entity, null);
        }

        if (entity.State == STATE_MELEE_ATTACK)
        {
            MeleeAttack(entity);
        }
    }
    //endregion

    //region 碰撞
    public override function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        var entity = collision.Entity;
        if (!MeleeEnabled(entity))
            return;
        if (!collision.Collider.IsForMain() || !collision.OtherCollider.IsForMain())
            return;
        if (state != EntityCollisionHelper.STATE_EXIT)
        {
            CollisionStay(entity, collision.Other);
        }
        else
        {
            CollisionExit(entity, collision.Other);
        }
    }
    function CollisionStay(enemy:Entity, other:Entity):Void
    {
        var targetID = GetMeleeTarget(enemy);
        var currentTarget = targetID != null ? targetID.GetEntity(enemy.Level) : null;
        if (ValidateMeleeTarget(enemy, currentTarget))
            return;
        if (ValidateMeleeTarget(enemy, other))
        {
            SetMeleeTarget(enemy, new EntityID(other));
        }
    }
    function CollisionExit(enemy:Entity, other:Entity):Void
    {
        var meleeTarget = GetMeleeTarget(enemy);
        if (meleeTarget != null && meleeTarget.ID == other.ID)
        {
            SetMeleeTarget(enemy, null);
        }
    }
    //endregion

    //region 检验目标
    function ValidateMeleeTarget(enemy:Entity, target:Null<Entity>):Bool
    {
        if (target == null || !unity.UnityObject.exists(target) || target.IsDead)
            return false;
        if (!enemy.IsHostile(target))
            return false;
        if (!Detection.CanDetect(target))
            return false;
        if (target.Position.y > enemy.Position.y + enemy.GetMaxAttackHeight())
            return false;
        if (target.Type == EntityTypes.PLANT || target.Type == EntityTypes.OBSTACLE)
        {
            if (target.IsFloor())
                return false;
            var protector = target.GetProtector();
            if (protector != null && unity.UnityObject.exists(protector) && !protector.IsFriendly(enemy))
                return false;
        }
        return true;
    }
    //endregion

    //region 攻击
    public function MeleeEnabled(entity:Entity):Bool
    {
        return true;
    }
    public static function HasMeleeTarget(enemy:Entity):Bool
    {
        var meleeTarget = GetMeleeTarget(enemy);
        return meleeTarget != null && meleeTarget.Exists(enemy.Level);
    }
    public static function IsMeleeAttacking(entity:Entity):Bool
    {
        return entity.State == STATE_MELEE_ATTACK;
    }
    // PORT-NOTE: C# 的 MeleeAttack(Entity) / MeleeAttack(Entity, Entity) 重载在 Haxe 中合并为带可选参数的一个方法。
    public static function MeleeAttack(enemy:Entity, ?target:Entity):Void
    {
        if (target == null)
        {
            var meleeTargetID = GetMeleeTarget(enemy);
            var meleeTarget = meleeTargetID != null ? meleeTargetID.GetEntity(enemy.Level) : null;
            if (meleeTarget != null)
            {
                MeleeAttack(enemy, meleeTarget);
            }
            return;
        }
        var vel = enemy.Velocity;
        // PORT-NOTE: C# 中 `<` 优先级高于 `==`（即 IsFacingLeft() == (vel.x < 0)）；Haxe 的同级比较运算符
        // 从左往右结合，会解析成 (IsFacingLeft() == vel.x) < 0，故补上显式括号。
        if (enemy.IsFacingLeft() == (vel.x < 0))
        {
            vel.x *= 0.8;
        }
        enemy.Velocity = vel;
        var damage = enemy.GetDamage() * enemy.GetAttackSpeed() / 30;
        target.TakeDamage(damage, new DamageEffectList([VanillaDamageEffects.MUTE, VanillaDamageEffects.ENEMY_MELEE]), enemy);
        enemy.Level.Triggers.RunCallback(VanillaLevelCallbacks.POST_ENEMY_MELEE_ATTACK, new EnemyMeleeAttackParams(enemy, target, damage));
    }
    //endregion

    //region 属性
    public static function GetMeleeTarget(entity:Entity):Null<EntityID> return entity.GetProperty(PROP_MELEE_TARGET);
    public static function SetMeleeTarget(entity:Entity, value:Null<EntityID>):Void entity.SetProperty(PROP_MELEE_TARGET, value);
    public static var PROP_MELEE_TARGET:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("melee_target");
    //endregion

    public static inline var STATE_MELEE_ATTACK:Int = LogicEnemyStates.MELEE_ATTACK;
}

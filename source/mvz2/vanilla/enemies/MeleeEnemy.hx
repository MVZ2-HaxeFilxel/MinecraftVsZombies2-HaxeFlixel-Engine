// Ported from: Assets/Scripts/Vanilla/GameContent/Enemies/Common/MeleeEnemy.cs
package mvz2.vanilla.enemies;

import unity.UnityObject;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.EnemyMeleeAttackParams;
import mvz2.vanilla.contraptions.VanillaContraptionExt;
import mvz2.vanilla.contraptions.VanillaContraptionProps;
import mvz2.vanilla.detection.Detection;
import mvz2.vanilla.entities.VanillaColliderExt;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.enemies.VanillaEnemyProps;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.damages.DamageEffectList;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityTypes;

// PORT-NOTE: C# 的扩展方法在本移植中为静态方法；调用点沿用扩展方法风格，故以 `using` 引入对应模块。
using mvz2.vanilla.contraptions.VanillaContraptionExt;
using mvz2.vanilla.contraptions.VanillaContraptionProps;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2.vanilla.enemies.VanillaEnemyProps;

// [Obsolete]
// abstract
class MeleeEnemy extends StateEnemy
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    override function UpdateAI(enemy:Entity):Void
    {
        if (!ValidateMeleeTarget(enemy, enemy.Target))
            enemy.Target = null;
        super.UpdateAI(enemy);
    }
    public override function PostCollision(collision:EntityCollision, state:Int):Void
    {
        if (!collision.Collider.IsForMain())
            return;
        if (!collision.OtherCollider.IsForMain())
            return;
        if (state != EntityCollisionHelper.STATE_EXIT)
        {
            MeleeCollision(collision.Entity, collision.Other);
        }
        else
        {
            CancelMeleeAttack(collision.Entity, collision.Other);
        }
    }
    function MeleeCollision(enemy:Entity, other:Entity):Void
    {
        if (ValidateMeleeTarget(enemy, enemy.Target))
            return;
        var target = other;
        var protector = target.GetProtector();
        if (protector != null && unity.UnityObject.exists(protector) && !protector.IsFriendly(enemy))
        {
            target = protector;
        }
        if (ValidateMeleeTarget(enemy, target))
        {
            enemy.Target = other;
        }
    }
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
    function CancelMeleeAttack(enemy:Entity, other:Entity):Void
    {
        if (enemy.Target == other)
        {
            enemy.Target = null;
        }
    }
    override function UpdateStateAttack(enemy:Entity):Void
    {
        if (enemy.Target != null)
        {
            MeleeAttack(enemy, enemy.Target);
        }
    }
    function MeleeAttack(enemy:Entity, target:Entity):Void
    {
        var vel = enemy.Velocity;
        // PORT-NOTE: C# 中 `<` 优先于 `==`；Haxe 的比较运算符同级左结合，故显式加括号保持原语义。
        if (enemy.IsFacingLeft() == (vel.x < 0))
        {
            vel.x *= 0.8;
        }
        enemy.Velocity = vel;
        var damage = enemy.GetDamage() * enemy.GetAttackSpeed() / 30;
        target.TakeDamage(damage, new DamageEffectList([VanillaDamageEffects.MUTE, VanillaDamageEffects.ENEMY_MELEE]), enemy);
        enemy.Level.Triggers.RunCallback(VanillaLevelCallbacks.POST_ENEMY_MELEE_ATTACK, new EnemyMeleeAttackParams(enemy, target, damage));
    }
}

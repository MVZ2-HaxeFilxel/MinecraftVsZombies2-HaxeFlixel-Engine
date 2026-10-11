// Ported from: Assets/Scripts/Vanilla/GameContent/Enemies/Chapter6/WispFly_SelfDestruct.cs
package mvz2.gamecontent.enemies;

import unity.UnityObject;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.entities.AIEntityBehaviour;
import mvz2.vanilla.contraptions.VanillaContraptionExt;
import mvz2.vanilla.detection.Detection;
import mvz2.vanilla.entities.VanillaEntityBehaviourNames;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.damages.DamageEffectList;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityTypes;
using mvz2.gamecontent.difficulties.VanillaDifficultyLevelProps;
using mvz2.vanilla.contraptions.VanillaContraptionExt;
using mvz2.vanilla.contraptions.VanillaContraptionProps;
using mvz2.vanilla.enemies.VanillaEnemyProps;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;

@:autoEntityBehaviourDefinition(VanillaEntityBehaviourNames.wispFly_SelfDestruct)
class WispFly_SelfDestruct extends AIEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    public override function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        var entity = collision.Entity;
        if (!collision.Collider.IsForMain() || !collision.OtherCollider.IsForMain())
            return;
        if (state != EntityCollisionHelper.STATE_EXIT)
        {
            CollisionStay(entity, collision.Other);
        }
    }
    function CollisionStay(enemy:Entity, other:Entity):Void
    {
        if (ValidateMeleeTarget(enemy, other) && !enemy.IsAIFrozen())
        {
            SelfDestruct(enemy);
        }
    }
    function ValidateMeleeTarget(enemy:Entity, target:Null<Entity>):Bool
    {
        if (!target.ExistsAndAlive())
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
    public static function SelfDestruct(enemy:Entity):Void
    {
        var damage = enemy.GetDamage() * enemy.Level.GetWispFlyDamageMultiplier();
        var explosionDamageEffects = new DamageEffectList([VanillaDamageEffects.FIRE]);
        enemy.Explode(enemy.GetCenter(), EXPLOSION_RADIUS, enemy.GetFaction(), damage, explosionDamageEffects);

        var selfDamageEffects = new DamageEffectList([VanillaDamageEffects.SELF_DAMAGE, VanillaDamageEffects.INSTA_KILL]);
        enemy.Die(selfDamageEffects, enemy);
    }
    public static inline var EXPLOSION_RADIUS:Float = 20;
}

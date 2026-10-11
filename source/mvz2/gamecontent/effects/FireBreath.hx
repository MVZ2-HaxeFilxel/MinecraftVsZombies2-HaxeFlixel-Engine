// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Chapter2/FireBreath.cs
package mvz2.gamecontent.effects;

import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.level.LogicLevelExt;
import pvzengine.damages.DamageEffectList;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.modifiers.NumberOperator;
import pvzengine.modifiers.Vector3Modifier;
import unity.Mathf;
import unity.Vector3;
import unity.UnityObject;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityProps;

@:autoEntityBehaviourDefinition(VanillaEffectNames.fireBreath)
class FireBreath extends EffectBehaviour
{
    // #region 公有方法
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new Vector3Modifier(LogicEntityProps.LIGHT_RANGE, NumberOperator.Multiply, PROP_LIGHT_RANGE_MULTIPLIER));
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        entity.CollisionMaskHostile = EntityCollisionHelper.MASK_PLANT | EntityCollisionHelper.MASK_ENEMY | EntityCollisionHelper.MASK_OBSTACLE | EntityCollisionHelper.MASK_BOSS;
        entity.Level.AddLoopSoundEntity(VanillaSoundID.fireBreath, entity.ID);
    }
    public override function Update(entity:Entity):Void
    {
        super.Update(entity);
        var parent = entity.Parent;
        var existing = parent != null && unity.UnityObject.exists(parent);
        if (existing)
        {
            entity.Timeout = MAX_TIMEOUT;
            var cooldown = GetDamageCooldown(entity);
            cooldown--;
            if (cooldown <= 0)
            {
                collisionBuffer.resize(0);
                entity.GetCurrentCollisions(collisionBuffer);
                for (collision in collisionBuffer)
                {
                    collision.OtherCollider.TakeDamage(entity.GetDamage(), new DamageEffectList([VanillaDamageEffects.FIRE]), entity);
                }
                cooldown = DAMAGE_COOLDOWN;
            }
            SetDamageCooldown(entity, cooldown);
        }
        entity.SetAnimationBool("Burning", existing);
        var lightPercentage = Mathf.Max(0, (entity.Timeout / (MAX_TIMEOUT : Float)) * 3 - 2);
        entity.SetProperty(PROP_LIGHT_RANGE_MULTIPLIER, Vector3.one * lightPercentage);
    }
    public static function GetDamageCooldown(entity:Entity):Int
    {
        return entity.GetBehaviourField(PROP_DAMAGE_COOLDOWN);
    }
    public static function SetDamageCooldown(entity:Entity, value:Int):Void
    {
        entity.SetBehaviourField(PROP_DAMAGE_COOLDOWN, value);
    }
    // #endregion
    public static inline var DAMAGE_COOLDOWN:Int = 15;
    public static inline var MAX_TIMEOUT:Int = 30;
    public static var PROP_LIGHT_RANGE_MULTIPLIER:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("LightRangeMultiplier");
    private static var PROP_DAMAGE_COOLDOWN:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("DamageCooldown");
    private var collisionBuffer:Array<EntityCollision> = [];
}

// Ported from: Assets/Scripts/Vanilla/GameContent/Bosses/TheGiantSnakeTail.cs
package mvz2.gamecontent.bosses;

import unity.UnityObject;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.NamespaceID;
import pvzengine.callbacks.CallbackResult;
import pvzengine.collisions.EntityCollisionHelper;
import pvzengine.damages.DamageEffectList;
import pvzengine.damages.DamageInput;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityID;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityExt;

@:autoEntityBehaviourDefinition(VanillaBossNames.theGiantSnakeTail)
class TheGiantSnakeTail extends BossBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
    }

    // #region 回调
    override public function Init(boss:Entity):Void
    {
        super.Init(boss);
        boss.CollisionMaskHostile |=
            EntityCollisionHelper.MASK_PLANT |
            EntityCollisionHelper.MASK_ENEMY |
            EntityCollisionHelper.MASK_OBSTACLE |
            EntityCollisionHelper.MASK_BOSS;
        boss.CollisionMaskFriendly |= EntityCollisionHelper.MASK_BOSS;
        // PORT-NOTE: C# 的 Entity.GetGridIndex() 在 Haxe 侧同样是 Entity 的实例方法（见 pvzengine.entities.Entity）。
        SetTargetGridIndex(boss, boss.GetGridIndex());
    }
    override public function UpdateLogic(entity:Entity):Void
    {
        super.UpdateLogic(entity);
        var parent = entity.Parent;
        if (parent == null || !unity.UnityObject.exists(parent))
        {
            entity.Remove();
            return;
        }
    }
    override public function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        var other = collision.Other;
        var self = collision.Entity;
        if (self.IsDead)
            return;
        if (!unity.UnityObject.exists(other))
            return;
        if (other.IsEntityOf(VanillaBossID.theGiant) && TheGiant.IsSnake(other) && (other.GetCenter() - self.GetCenter()).magnitude < KILL_SNAKE_DISTANCE)
        {
            other.TakeDamage(COLLIDE_SELF_DAMAGE, new DamageEffectList([VanillaDamageEffects.MUTE]), self);
            TheGiant.KillSnake(other);
            return;
        }
        if (other.IsHostile(self))
        {
            var damageEffects = new DamageEffectList([VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN, VanillaDamageEffects.MUTE]);
            collision.OtherCollider.TakeDamage(VanillaEntityProps.GetDamage(self), damageEffects, self);
        }
    }
    override public function PreTakeDamage(damageInfo:DamageInput, result:CallbackResult):Void
    {
        super.PreTakeDamage(damageInfo, result);
        var self = damageInfo.Entity;
        var parent = self.Parent;
        if (parent != null && unity.UnityObject.exists(parent))
        {
            // C#: oldEffects.Union(transferDamageExtraEffects).ToArray()
            var oldEffects = damageInfo.Effects.GetEffects();
            var newEffects:Array<NamespaceID> = oldEffects.copy();
            for (e in transferDamageExtraEffects)
            {
                if (newEffects.indexOf(e) < 0)
                    newEffects.push(e);
            }
            var effects = new DamageEffectList(newEffects);
            parent.TakeDamageSourced(damageInfo.Amount, effects, damageInfo.Source, damageInfo.ShieldTarget);
            LogicEntityExt.DamageBlink(self);
            result.SetFinalValue(false);
        }
    }
    public static function PassTargetGrids(parent:Entity, gridIndex:Int):Void
    {
        var childID = GetChildTail(parent);
        var child = childID != null ? childID.GetEntity(parent.Level) : null;
        if (child != null)
        {
            var targetGridIndex = GetTargetGridIndex(child);
            PassTargetGrids(child, targetGridIndex);
            SetTargetGridIndex(child, gridIndex);
        }
    }
    public static function MoveTail(parent:Entity, speed:Float):Void
    {
        var childID = GetChildTail(parent);
        var child = childID != null ? childID.GetEntity(parent.Level) : null;
        if (child != null)
        {
            MoveTail(child, speed);

            var targetGridIndex = GetTargetGridIndex(child);
            if (targetGridIndex >= 0)
            {
                VanillaEntityExt.MoveOrthogonally(child, targetGridIndex, speed);
            }
        }
    }
    public static function FindTail(parent:Entity):Entity
    {
        var childID = GetChildTail(parent);
        var child = childID != null ? childID.GetEntity(parent.Level) : null;
        if (child == null)
            return parent;
        return FindTail(child);
    }
    public static function GetFullSnake(segment:Entity, entities:Array<Entity>):Void
    {
        var tail = FindTail(segment);
        if (tail == null)
            return;
        entities.push(tail);
        GetAllParents(tail, entities);
    }
    public static function GetAllParents(segment:Entity, entities:Array<Entity>):Void
    {
        var parent = segment.Parent;
        if (parent == null || entities.indexOf(parent) >= 0)
            return;
        entities.push(parent);
        GetAllParents(parent, entities);
    }
    // #endregion 事件
    public static function GetChildTail(entity:Entity):Null<EntityID>
    {
        return entity.GetBehaviourField(PROP_CHILD_TAIL);
    }
    public static function SetChildTail(entity:Entity, value:Null<EntityID>):Void
    {
        entity.SetBehaviourField(PROP_CHILD_TAIL, value);
    }
    public static function GetTargetGridIndex(entity:Entity):Int
    {
        return entity.GetBehaviourField(PROP_TARGET_GRID_INDEX);
    }
    public static function SetTargetGridIndex(entity:Entity, value:Int):Void
    {
        entity.SetBehaviourField(PROP_TARGET_GRID_INDEX, value);
    }

    // #region 常量
    public static inline var KILL_SNAKE_DISTANCE:Float = 32;
    public static inline var COLLIDE_SELF_DAMAGE:Float = 600;
    public static var PROP_CHILD_TAIL:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("ChildTail");
    public static var PROP_TARGET_GRID_INDEX:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("TargetGridIndex");
    public static var transferDamageExtraEffects:Array<NamespaceID> = [VanillaDamageEffects.TRANSFERRED, VanillaDamageEffects.NO_DAMAGE_BLINK];
    // #endregion
}

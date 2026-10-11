// Ported from: Assets/Scripts/Vanilla/GameContent/Contraptions/Upgrades/ForcePad.cs
package mvz2.gamecontent.contraptions;

import mvz2.gamecontent.buffs.VanillaBuffID;
import mvz2.gamecontent.buffs.projectiles.ProjectileKnockbackBuff;
import mvz2.gamecontent.buffs.entities.WhiteFlashBuff;
import mvz2.gamecontent.detections.ForcePadDetector;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.helditems.VanillaHeldTypes;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.helditems.HeldItemBuilder;
import mvz2logic.level.LogicLevelExt;
import pvzengine.NamespaceID;
import pvzengine.auras.AuraEffect;
import pvzengine.auras.AuraEffectDefinition;
import pvzengine.auras.IBuffTarget;
import pvzengine.buffs.BuffExt;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityID;
import pvzengine.entities.EntityTypes;
import unity.Vector3;
import unity.UnityObject;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2logic.entities.LogicContraptionProps;
using mvz2logic.entities.LogicEntityExt;
using mvz2logic.level.LogicHeldItemProps;

@:autoEntityBehaviourDefinition(VanillaContraptionNames.forcePad)
class ForcePad extends ContraptionBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddAura(new DragAura());
        enemyDetector = new ForcePadDetector(EntityCollisionHelper.MASK_ENEMY, AFFECT_HEIGHT, 1);
        projectileDetector = new ForcePadDetector(EntityCollisionHelper.MASK_PROJECTILE, AFFECT_HEIGHT, 0.5);
    }
    override function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);
        UpdateGeneralAbility(entity);
    }
    override function UpdateLogic(entity:Entity):Void
    {
        super.UpdateLogic(entity);
        if (entity.IsEvoked())
        {
            EvokedUpdate(entity);
        }
        entity.SetAnimationBool("IsOn", !entity.IsAIFrozen());
        entity.SetAnimationInt("ForceState", GetAnimationState(entity));
    }
    override function OnEvoke(entity:Entity):Void
    {
        super.OnEvoke(entity);
        // 开始拉取敌人。
        SetDragTarget(entity, Vector3.zero);
        SetDragTargetLocked(entity, false);
        var targets = entity.Level.FindEntities(e -> CanDrag(entity, e));
        if (targets.length > 0)
        {
            var level = entity.Level;
            var lines:Array<EntityID> = [];
            lines.resize(targets.length);
            for (i in 0...targets.length)
            {
                var target = targets[i];
                // C#: level.Spawn(...)?.Let(e => { ... })
                var e = level.Spawn(VanillaEffectID.magneticLine, entity.Position, entity);
                if (e != null)
                {
                    e.SetParent(entity);
                    e.Target = target;
                    lines[i] = new EntityID(e);
                }
            }
            SetDraggingLines(entity, lines);
            SetDraggingEntities(entity, [for (e in targets) new EntityID(e)]);
            SetDragTimeout(entity, MAX_DRAG_TIMEOUT);
            entity.SetEvoked(true);

            var builder = new HeldItemBuilder(VanillaHeldTypes.forcePad, 100);
            builder.SetEntityID(entity.ID);
            builder.SetCannotCancel(true);
            entity.Level.SetHeldItem(builder);
        }
        else
        {
            SetDraggingLines(entity, null);
            SetDraggingEntities(entity, null);
            SetDragTimeout(entity, 0);
        }
        entity.PlaySound(VanillaSoundID.magnetic);
    }
    override function OnTrigger(entity:Entity):Void
    {
        super.OnTrigger(entity);
        var padDirection = GetPadDirection(entity);
        padDirection = (padDirection + 1) % 4;
        SetPadDirection(entity, padDirection);
        var affectedEntities = GetAffectedEntities(entity);
        if (affectedEntities != null)
        {
            affectedEntities = [];
        }
        WhiteFlashBuff.AddToEntity(entity, 15);
        entity.PlaySound(VanillaSoundID.wakeup);
    }
    function UpdateGeneralAbility(entity:Entity):Void
    {
        var level = entity.Level;
        var affectedEntities = GetAffectedEntities(entity);
        if (affectedEntities == null)
        {
            affectedEntities = [];
            SetAffectedEntities(entity, affectedEntities);
        }
        detectBuffer = [];
        enemyDetector.DetectEntities(DetectionParams.fromEntity(entity), detectBuffer);
        projectileDetector.DetectEntities(DetectionParams.fromEntity(entity), detectBuffer);
        for (target in detectBuffer)
        {
            var start = false;
            if (!Lambda.exists(affectedEntities, e -> e.ID == target.ID))
            {
                start = true;
                affectedEntities.push(new EntityID(target));
            }
            AffectEntity(entity, target, start);
        }
        // C#: affectedEntities.RemoveAll(predicate)
        var removed = Lambda.filter(affectedEntities, function(e)
        {
            var ent = e.GetEntity(level);
            if (ent == null)
                return true;
            return !detectBuffer.contains(ent);
        });
        for (e in removed)
        {
            affectedEntities.remove(e);
        }
    }
    function AffectEntity(pad:Entity, target:Entity, start:Bool):Void
    {
        if (target.Type == EntityTypes.ENEMY)
        {
            AffectEnemyWalkedOn(pad, target, start);
        }
        else if (target.Type == EntityTypes.PROJECTILE)
        {
            AffectProjectile(pad, target, start);
        }
    }
    function AffectEnemyWalkedOn(pad:Entity, target:Entity, start:Bool):Void
    {
        var direction = GetPadDirection(pad);
        var up = direction == DIRECTION_UP;
        var down = direction == DIRECTION_DOWN;
        var right = direction == DIRECTION_RIGHT;
        var left = direction == DIRECTION_LEFT;
        if (left || right)
        {
            // Horizontal.
            var facingX = pad.GetFacingX();
            var pointX = (right ? 1 : -1) * facingX;
            target.Position += MOVE_ENEMY_SPEED * facingX * new Vector3(pointX, 0, 0);
        }
        else if (up || down)
        {
            // Vertical.
            var pointZ = (up ? 1 : -1);
            if (start)
            {
                target.StartChangingLane(pad.GetLane() - pointZ);
            }
        }
    }
    function AffectProjectile(pad:Entity, projectile:Entity, start:Bool):Void
    {
        if (!start)
            return;
        var direction = GetPadDirection(pad);
        var projVelocity = projectile.Velocity;

        var up = direction == DIRECTION_UP;
        var down = direction == DIRECTION_DOWN;
        var right = direction == DIRECTION_RIGHT;
        var left = direction == DIRECTION_LEFT;
        var sameDirection = false;
        var velocityDir = Vector3.right;
        if (left || right)
        {
            // Horizontal.
            var facingX = pad.GetFacingX();
            var pointX = (right ? 1 : -1) * facingX;
            sameDirection = projVelocity.x * pointX > 0;
            velocityDir = new Vector3(pointX, 0, 0);
        }
        else if (up || down)
        {
            // Vertical.
            var pointZ = (up ? 1 : -1);
            sameDirection = projVelocity.z * pointZ > 0;
            velocityDir = new Vector3(0, 0, pointZ);
        }

        // 相同方向，增加击退效果并提升弹速
        if (sameDirection)
        {
            if (!projectile.HasBuff(ProjectileKnockbackBuff))
                projectile.AddBuff(ProjectileKnockbackBuff);
            projectile.Velocity += PROJECTILE_SPEED_BOOST * velocityDir;
        }
        else
        {
            // 不同方向，转移方向。
            projectile.Velocity = velocityDir * projectile.Velocity.magnitude;
            projectile.StopChangingLane();
        }
    }
    function EvokedUpdate(pad:Entity):Void
    {
        // 正在拖动目标。
        var locked = IsDragTargetLocked(pad);
        var targetPosition = GetDragTarget(pad);
        var draggingEntities = GetDraggingEntities(pad);
        var hasValidEntity = false;
        if (draggingEntities != null)
        {
            for (targetID in draggingEntities)
            {
                var target = targetID.GetEntity(pad.Level);
                // 不存在或者死亡的目标被排除在外。
                if (target == null || !unity.UnityObject.exists(target) || target.IsDead)
                    continue;
                hasValidEntity = true;

                // 拖动目标到指定位置。
                var pos = target.Position;
                if (locked)
                {
                    pos = targetPosition;
                }
                pos.y = pad.Level.GetGroundY(pos.x, pos.z) + 10;
                target.Position = target.Position * 0.5 + pos * 0.5;
                target.StopChangingLane();
            }
        }
        // 拖动倒计时。
        var dragTimeout = GetDragTimeout(pad);
        dragTimeout--;
        SetDragTimeout(pad, dragTimeout);

        // 倒计时结束，或者没有在手持该器械，或者已经没有有效的实体了
        // 结束大招。
        var level = pad.Level;
        var heldItemData = level.GetHeldItemData();
        var holdingThis = heldItemData != null && heldItemData.Type == VanillaHeldTypes.forcePad && heldItemData.GetEntityID() == pad.ID;
        if (dragTimeout <= 0 || (!holdingThis && !locked) || !hasValidEntity)
        {
            if (holdingThis)
            {
                pad.Level.ResetHeldItem();
            }
            pad.SetEvoked(false);

            if (draggingEntities != null)
            {
                for (targetID in draggingEntities)
                {
                    var target = targetID.GetEntity(pad.Level);
                    // 不存在或者死亡的目标被排除在外。
                    if (!target.ExistsAndAlive())
                        continue;
                    // 清空移速
                    target.Velocity = Vector3.zero;
                }
            }

            // 删除所有连接线。
            var draggingLines = GetDraggingLines(pad);
            if (draggingLines != null)
            {
                for (lineID in draggingLines)
                {
                    var line = lineID.GetEntity(pad.Level);
                    if (line == null)
                        continue;
                    line.Remove();
                }
            }
            SetDraggingLines(pad, null);
            SetDraggingEntities(pad, null);
            SetDragTimeout(pad, 0);
            SetDragTarget(pad, Vector3.zero);
            SetDragTargetLocked(pad, false);
        }
    }
    function CanDrag(self:Entity, target:Entity):Bool
    {
        return target.Type == EntityTypes.ENEMY && !target.IsDead && self.IsHostile(target) && Vector3.Distance(self.Position, target.Position) < DRAG_RADIUS;
    }

    //region 属性
    public static function GetPadDirection(pad:Entity):Int return pad.GetBehaviourFieldNS(ID, PROP_PAD_DIRECTION);
    public static function SetPadDirection(pad:Entity, direction:Int):Void pad.SetBehaviourFieldNS(ID, PROP_PAD_DIRECTION, direction);
    public static function GetAffectedEntities(pad:Entity):Null<Array<EntityID>> return pad.GetBehaviourFieldNS(ID, PROP_AFFECTED_ENTITIES);
    public static function SetAffectedEntities(pad:Entity, value:Array<EntityID>):Void pad.SetBehaviourFieldNS(ID, PROP_AFFECTED_ENTITIES, value);

    //region 拖拽
    public static function GetDraggingEntities(pad:Entity):Null<Array<EntityID>> return pad.GetBehaviourFieldNS(ID, PROP_DRAGGING_ENTITIES);
    public static function SetDraggingEntities(pad:Entity, value:Null<Array<EntityID>>):Void pad.SetBehaviourFieldNS(ID, PROP_DRAGGING_ENTITIES, value);
    public static function GetDraggingLines(pad:Entity):Null<Array<EntityID>> return pad.GetBehaviourFieldNS(ID, PROP_DRAGGING_LINES);
    public static function SetDraggingLines(pad:Entity, value:Null<Array<EntityID>>):Void pad.SetBehaviourFieldNS(ID, PROP_DRAGGING_LINES, value);
    public static function IsDragTargetLocked(pad:Entity):Bool return pad.GetBehaviourFieldNS(ID, PROP_DRAG_TARGET_LOCKED);
    public static function SetDragTargetLocked(pad:Entity, value:Bool):Void pad.SetBehaviourFieldNS(ID, PROP_DRAG_TARGET_LOCKED, value);
    public static function GetDragTarget(pad:Entity):Vector3 return pad.GetBehaviourFieldNS(ID, PROP_DRAG_TARGET);
    public static function SetDragTarget(pad:Entity, position:Vector3):Void pad.SetBehaviourFieldNS(ID, PROP_DRAG_TARGET, position);
    public static function GetDragTimeout(pad:Entity):Int return pad.GetBehaviourFieldNS(ID, PROP_DRAG_TIMEOUT);
    public static function SetDragTimeout(pad:Entity, value:Int):Void pad.SetBehaviourFieldNS(ID, PROP_DRAG_TIMEOUT, value);
    //endregion

    //endregion
    function GetAnimationState(pad:Entity):Int
    {
        if (pad.IsEvoked())
            return 4;
        return GetPadDirection(pad);
    }
    public static var PROP_PAD_DIRECTION:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("PadDirection");
    public static var PROP_AFFECTED_ENTITIES:VanillaEntityPropertyMeta<Array<EntityID>> = new VanillaEntityPropertyMeta<Array<EntityID>>("AffectedEntities");
    public static var PROP_DRAG_TARGET:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("DragTarget");
    public static var PROP_DRAG_TARGET_LOCKED:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("DragTargetLocked");
    public static var PROP_DRAGGING_LINES:VanillaEntityPropertyMeta<Array<EntityID>> = new VanillaEntityPropertyMeta<Array<EntityID>>("DraggingLines");
    public static var PROP_DRAGGING_ENTITIES:VanillaEntityPropertyMeta<Array<EntityID>> = new VanillaEntityPropertyMeta<Array<EntityID>>("DraggingEntities");
    public static var PROP_DRAG_TIMEOUT:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("DragTimeout");
    public static inline var DRAG_RADIUS:Float = 150;
    public static inline var MAX_DRAG_TIMEOUT:Int = 150;

    public static inline var AFFECT_HEIGHT:Float = 64;
    public static inline var MIN_HEIGHT:Float = 5;
    public static inline var MOVE_ENEMY_SPEED:Float = 0.233333;
    public static inline var DIRECTION_RIGHT:Int = 0;
    public static inline var DIRECTION_DOWN:Int = 1;
    public static inline var DIRECTION_LEFT:Int = 2;
    public static inline var DIRECTION_UP:Int = 3;
    public static inline var PROJECTILE_SPEED_BOOST:Float = 1;
    public static var ID:NamespaceID = VanillaContraptionID.forcePad;
    var enemyDetector:Detector;
    var projectileDetector:Detector;
    var detectBuffer:Array<Entity> = [];
}

class DragAura extends AuraEffectDefinition
{
    public function new()
    {
        super(VanillaBuffID.Enemy.forcePadDrag);
    }

    public override function GetAuraTargets(auraEffect:AuraEffect, results:Array<IBuffTarget>):Void
    {
        var sourceEnt = auraEffect.Source != null ? auraEffect.Source.GetEntity() : null;
        if (sourceEnt == null)
            return;
        if (!sourceEnt.IsEvoked())
            return;
        var draggingEntities = ForcePad.GetDraggingEntities(sourceEnt);
        if (draggingEntities == null)
            return;
        for (entID in draggingEntities)
        {
            var ent = entID.GetEntity(sourceEnt.Level);
            if (!ent.ExistsAndAlive())
                continue;
            results.push(ent);
        }
    }
}

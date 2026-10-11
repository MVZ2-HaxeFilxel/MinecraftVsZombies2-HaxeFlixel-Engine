// Ported from: Assets/Scripts/Vanilla/GameContent/Bosses/TheGiant.cs
// Ported from: Assets/Scripts/Vanilla/GameContent/Bosses/TheGiant_States.cs
// PORT-NOTE: the C# `partial class TheGiant` spans TheGiant.cs and TheGiant_States.cs;
// per PORTING.md partial classes are merged into a single Haxe module.
// PORT-NOTE: members accessed by the C# nested state classes are `public` here,
// because Haxe module types do not share class-level private visibility.
package mvz2.gamecontent.bosses;

import Lambda;
import mvz2.gamecontent.buffs.bosses.TheGiantInactiveBuff;
import mvz2.gamecontent.buffs.bosses.TheGiantPacmanBuff;
import mvz2.gamecontent.buffs.bosses.TheGiantPacmanKilledBuff;
import mvz2.gamecontent.buffs.bosses.TheGiantPhase3Buff;
import mvz2.gamecontent.buffs.bosses.TheGiantSnakeBuff;
import mvz2.gamecontent.contraptions.VanillaContraptionID;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.detections.DevourerEvokedDetector;
import mvz2.gamecontent.detections.TheGiantArmDetector;
import mvz2.gamecontent.detections.TheGiantEyeDetector;
import mvz2.gamecontent.effects.Explosion;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.effects.ZombieBlock;
import mvz2.gamecontent.enemies.VanillaEnemyID;
import mvz2.gamecontent.projectiles.VanillaProjectileID;
import mvz2.vanilla.VanillaMod;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.bosses.VanillaBossExt;
import mvz2.vanilla.bosses.VanillaBossStates;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.enemies.VanillaEnemyProps;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.gamecontent.difficulties.VanillaDifficultyLevelProps;
import mvz2.vanilla.level.VanillaLevelExt;
import mvz2.vanilla.modifiers.VanillaModifierPriorities;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2.vanilla.statemachine.EntityStateMachine;
import mvz2.vanilla.statemachine.EntityStateMachineState;
import pvzengine.entities.EntityTypes;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicContraptionProps;
import mvz2logic.entities.LogicEnemyProps;
import mvz2logic.level.LevelPositions;
import pvzengine.RandomGenerator;
import pvzengine.base.ArrayBuffer;
import pvzengine.buffs.Buff;
import pvzengine.collisions.EntityCollisionHelper;
import pvzengine.collisions.IEntityCollider;
import pvzengine.damages.DamageEffectList;
import pvzengine.damages.DamageOutput;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.EngineEntityExt;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityID;
import pvzengine.grids.LawnGrid;
import pvzengine.level.LevelEngine;
import pvzengine.modifiers.BooleanModifier;
import tools.EnumerableExt;
import tools.FrameTimer;
import unity.Mathf;
import unity.Vector2Int;
import unity.Vector3;
import unity.UnityObject;

using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.projectiles.VanillaProjectileExt;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaBossNames.theGiant)
class TheGiant extends BossBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new BooleanModifier(EngineEntityProps.FLIP_X, PROP_FLIP_X, VanillaModifierPriorities.FORCE));
    }

    // #region 回调
    override public function Init(boss:Entity):Void
    {
        super.Init(boss);
        stateMachine.Init(boss);
        stateMachine.StartState(boss, STATE_IDLE);

        boss.CollisionMaskHostile |=
            EntityCollisionHelper.MASK_PLANT |
            EntityCollisionHelper.MASK_ENEMY |
            EntityCollisionHelper.MASK_OBSTACLE |
            EntityCollisionHelper.MASK_BOSS |
            EntityCollisionHelper.MASK_CART;
    }
    override public function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);

        stateMachine.UpdateAI(entity);
        if (entity.IsDead)
            return;

        if (!entity.HasBuff(TheGiantInactiveBuff) && entity.IsTimeInterval(CRY_INTERVAL))
        {
            entity.PlaySound(VanillaSoundID.zombieCry, 0.5);
        }
    }
    override public function UpdateLogic(entity:Entity):Void
    {
        super.UpdateLogic(entity);
        stateMachine.UpdateLogic(entity);

        if (GetPhase(entity) == PHASE_3)
        {
            var malleable = GetMalleable(entity);
            malleable = Mathf.Max(0, malleable - MALLEABLE_DECAY_PHASE_3);
            SetMalleable(entity, malleable);
        }
    }
    override public function PostCollision(collision:EntityCollision, state:Int):Void
    {
        super.PostCollision(collision, state);
        var other = collision.Other;
        var self = collision.Entity;
        if (self.IsDead)
            return;
        if (!unity.UnityObject.exists(other) || !other.IsHostile(self))
            return;
        if (self.State == STATE_SNAKE)
        {
            var substate = stateMachine.GetSubState(self);
            if (substate != SnakeState.SUBSTATE_SNAKE)
                return;
            if (other.IsInvincible())
                return;
            var damageEffects = new DamageEffectList([VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN, VanillaDamageEffects.MUTE]);
            collision.OtherCollider.TakeDamage(VanillaEntityProps.GetDamage(self) * SNAKE_DAMAGE_MULTIPLIER, damageEffects, self);
            return;
        }
        if (self.State == STATE_PACMAN)
        {
            if (IsPacmanGhost(other) && IsPacman(self))
            {
                var damageEffects = new DamageEffectList([VanillaDamageEffects.MUTE]);
                self.TakeDamage(PACMAN_GHOST_DAMAGE, damageEffects, other);
                KillPacman(self);
                return;
            }
            if (!other.IsInvincible() && !IsPacmanPanic(self))
            {
                var damageEffects = new DamageEffectList([VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN, VanillaDamageEffects.REMOVE_ON_DEATH, VanillaDamageEffects.NO_DEATH_EFFECTS, VanillaDamageEffects.MUTE]);
                var result = collision.OtherCollider.TakeDamage(VanillaEntityProps.GetDamage(self) * PACMAN_DAMAGE_MULTIPLIER, damageEffects, self);
                if (result != null)
                {
                    var level = self.Level;
                    VanillaEntityExt.HealEffects(self, result.GetTotalSpendAmount() * PACMAN_HEAL_MULTIPLIER, other);
                    if (!level.IsPlayingSound(VanillaSoundID.pacmanAttack))
                    {
                        level.PlaySound(VanillaSoundID.pacmanAttack);
                    }
                    if (result.HasAnyFatal())
                    {
                        other.PlaySound(VanillaSoundID.pacmanKill);
                    }
                }
            }
            return;
        }
        if (other.Type == EntityTypes.CART)
        {
            other.Die(self);
            other.PlaySound(VanillaSoundID.smash);
            return;
        }
        var otherCollider = collision.OtherCollider;
        if (!other.IsInvincible() && other.Type == EntityTypes.PLANT)
        {
            var crushDamage = VanillaMod.INSTA_DAMAGE_AMOUNT;
            var result = otherCollider.TakeDamage(crushDamage, new DamageEffectList([VanillaDamageEffects.GRIND, VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN]), self);
            if (result != null && result.HasAnyFatal())
            {
                other.PlaySound(VanillaSoundID.smash);
            }
        }
    }
    override public function PostTakeDamage(result:DamageOutput):Void
    {
        super.PostTakeDamage(result);
        var entity = result.Entity;
        if (!VanillaDifficultyLevelProps.TheGiantIsMalleable(entity.Level))
            return;
        var bodyResult = result.BodyResult;
        if (bodyResult != null)
        {
            var malleable = GetMalleable(entity);
            SetMalleable(entity, malleable + bodyResult.Amount);
        }
    }
    // #endregion 事件

    // #region 字段
    public static function GetPhase(entity:Entity):Int
    {
        return entity.GetBehaviourField(PROP_PHASE);
    }
    public static function SetPhase(entity:Entity, value:Int):Void
    {
        entity.SetBehaviourField(PROP_PHASE, value);
    }
    public static function IsFlipX(entity:Entity):Bool
    {
        return entity.GetBehaviourField(PROP_FLIP_X);
    }
    public static function SetFlipX(entity:Entity, value:Bool):Void
    {
        entity.SetBehaviourField(PROP_FLIP_X, value);
    }
    public static function GetTargetGridIndex(entity:Entity):Int
    {
        return entity.GetBehaviourField(PROP_TARGET_GRID_INDEX);
    }
    public static function SetTargetGridIndex(entity:Entity, value:Int):Void
    {
        entity.SetBehaviourField(PROP_TARGET_GRID_INDEX, value);
    }
    public static function GetAttackFlag(entity:Entity):Int
    {
        return entity.GetBehaviourField(PROP_ATTACK_FLAG);
    }
    public static function SetAttackFlag(entity:Entity, value:Int):Void
    {
        entity.SetBehaviourField(PROP_ATTACK_FLAG, value);
    }
    public static function GetMalleable(entity:Entity):Float
    {
        return entity.GetBehaviourField(PROP_MALLEABLE);
    }
    public static function SetMalleable(entity:Entity, value:Float):Void
    {
        entity.SetBehaviourField(PROP_MALLEABLE, value);
    }
    public static function ResetMalleable(entity:Entity):Void
    {
        SetMalleable(entity, 0);
    }

    // #region 僵尸块
    public static function GetZombieBlocks(entity:Entity):Null<Array<EntityID>>
    {
        return entity.GetBehaviourField(PROP_ZOMBIE_BLOCKS);
    }
    public static function SetZombieBlocks(entity:Entity, value:Array<EntityID>):Void
    {
        entity.SetBehaviourField(PROP_ZOMBIE_BLOCKS, value);
    }
    public static function AddZombieBlock(entity:Entity, value:EntityID):Void
    {
        var blocks = GetZombieBlocks(entity);
        if (blocks == null)
        {
            blocks = [];
            SetZombieBlocks(entity, blocks);
        }
        blocks.push(value);
    }
    public static function RemoveZombieBlock(entity:Entity, value:EntityID):Bool
    {
        var blocks = GetZombieBlocks(entity);
        if (blocks == null)
        {
            return false;
        }
        return blocks.remove(value);
    }
    public static function HasZombieBlock(entity:Entity, value:EntityID):Bool
    {
        var blocks = GetZombieBlocks(entity);
        if (blocks == null)
        {
            return false;
        }
        return blocks.indexOf(value) >= 0;
    }
    public static function ClearZombieBlocks(entity:Entity):Void
    {
        var blocks = GetZombieBlocks(entity);
        if (blocks == null)
        {
            return;
        }
        blocks.resize(0);
    }
    // #endregion

    // #region 贪吃蛇尾巴
    public static function GetSnakeTails(entity:Entity):Null<Array<EntityID>>
    {
        return entity.GetBehaviourField(PROP_SNAKE_TAILS);
    }
    public static function SetSnakeTails(entity:Entity, value:Array<EntityID>):Void
    {
        entity.SetBehaviourField(PROP_SNAKE_TAILS, value);
    }
    public static function AddSnakeTail(entity:Entity, value:EntityID):Void
    {
        var blocks = GetSnakeTails(entity);
        if (blocks == null)
        {
            blocks = [];
            SetSnakeTails(entity, blocks);
        }
        blocks.push(value);
    }
    public static function RemoveSnakeTail(entity:Entity, value:EntityID):Bool
    {
        var blocks = GetSnakeTails(entity);
        if (blocks == null)
        {
            return false;
        }
        return blocks.remove(value);
    }
    public static function HasSnakeTail(entity:Entity, value:EntityID):Bool
    {
        var blocks = GetSnakeTails(entity);
        if (blocks == null)
        {
            return false;
        }
        return blocks.indexOf(value) >= 0;
    }
    public static function ClearSnakeTails(entity:Entity):Void
    {
        var blocks = GetSnakeTails(entity);
        if (blocks == null)
        {
            return;
        }
        blocks.resize(0);
    }
    // #endregion

    // #endregion

    public static function SetInactive(entity:Entity, value:Bool):Void
    {
        entity.SetAnimationBool("Active", !value);
        if (value)
        {
            if (!entity.HasBuff(TheGiantInactiveBuff))
                entity.AddBuff(TheGiantInactiveBuff);
        }
        else
        {
            entity.RemoveBuffs(TheGiantInactiveBuff);
        }
    }
    public static function AtLeft(entity:Entity):Bool
    {
        return entity.Position.x < LevelPositions.LAWN_CENTER_X;
    }
    public static function CanBeStunned(entity:Entity):Bool
    {
        return unstunnableStates.indexOf(entity.State) < 0;
    }

    // #region 僵尸块
    public static function GetZombieBlockLeftStartColumn(entity:Entity):Int
    {
        return ZOMBIE_BLOCK_LEFT_COLUMN_START + ZOMBIE_BLOCK_COLUMNS - 1;
    }
    public static function GetZombieBlockRightStartColumn(entity:Entity):Int
    {
        return entity.Level.GetMaxColumnCount() - ZOMBIE_BLOCK_COLUMNS;
    }
    public static function GetZombieBlockStartColumn(entity:Entity, x:Int, atLeft:Bool):Int
    {
        var column:Int;
        if (atLeft)
        {
            column = GetZombieBlockLeftStartColumn(entity) - x;
        }
        else
        {
            column = GetZombieBlockRightStartColumn(entity) + x;
        }
        return column;
    }
    public static function GetZombieBlockEndColumn(entity:Entity, x:Int, atLeft:Bool):Int
    {
        var columnEnd:Int;
        if (atLeft)
        {
            columnEnd = GetZombieBlockRightStartColumn(entity) - x + (ZOMBIE_BLOCK_COLUMNS - 1);
        }
        else
        {
            columnEnd = GetZombieBlockLeftStartColumn(entity) + x - (ZOMBIE_BLOCK_COLUMNS - 1);
        }
        return columnEnd;
    }
    public static function GetZombieBlockPosition(entity:Entity, index:Int, atLeft:Bool):Vector3
    {
        var x = index % ZOMBIE_BLOCK_COLUMNS;
        var y = Std.int(index / ZOMBIE_BLOCK_COLUMNS);
        var column = GetZombieBlockStartColumn(entity, x, atLeft);
        var columnEnd = GetZombieBlockEndColumn(entity, x, atLeft);
        var lane = y;
        return entity.Level.GetEntityGridPosition(column, lane);
    }
    public static function SpawnZombieBlock(spawner:Entity, position:Vector3):Null<Entity>
    {
        var e = spawner.Spawn(VanillaEffectID.zombieBlock, position, spawner.GetSpawnParams());
        if (e != null)
        {
            e.SetParent(spawner);
            AddZombieBlock(spawner, new EntityID(e));
        }
        return e;
    }
    public static function AreAllZombieBlocksReached(parent:Entity):Bool
    {
        var blocks = GetZombieBlocks(parent);
        if (blocks == null)
            return true;
        for (blockID in blocks)
        {
            var block = blockID.GetEntity(parent.Level);
            if (!EngineEntityExt.ExistsAndAlive(block))
                continue;
            if (!ZombieBlock.IsReached(block))
                return false;
        }
        return true;
    }
    public static function RemoveAllZombieBlocks(parent:Entity):Void
    {
        var blocks = GetZombieBlocks(parent);
        if (blocks == null)
            return;
        for (blockID in blocks)
        {
            var block = blockID.GetEntity(parent.Level);
            if (block == null || !unity.UnityObject.exists(block))
                continue;
            block.Remove();
        }
        blocks.resize(0);
    }
    // #endregion

    // #region 蛇尾
    public static function SpawnSnakeTail(spawner:Entity, position:Vector3, parent:Entity):Null<Entity>
    {
        var e = spawner.Spawn(VanillaBossID.theGiantSnakeTail, position, spawner.GetSpawnParams());
        if (e != null)
        {
            e.SetParent(parent);
            TheGiantSnakeTail.SetChildTail(parent, new EntityID(e));
            AddSnakeTail(spawner, new EntityID(e));
        }
        return e;
    }
    public static function RemoveAllSnakeTails(parent:Entity):Void
    {
        var tails = GetSnakeTails(parent);
        if (tails == null)
            return;
        for (tailID in tails)
        {
            var tail = tailID.GetEntity(parent.Level);
            if (tail == null || !unity.UnityObject.exists(tail))
                continue;
            tail.Remove();
        }
        tails.resize(0);
    }
    // #endregion

    // #region 拼合位置
    public static function GetCombineX(entity:Entity, atLeft:Bool):Float
    {
        var level = entity.Level;
        var startColumn:Int;
        var endColumn:Int;
        if (atLeft)
        {
            startColumn = GetZombieBlockLeftStartColumn(entity);
            endColumn = startColumn - ZOMBIE_BLOCK_COLUMNS;
        }
        else
        {
            startColumn = GetZombieBlockRightStartColumn(entity);
            endColumn = startColumn + ZOMBIE_BLOCK_COLUMNS;
        }
        var startX = level.GetEntityColumnX(startColumn);
        var endX = level.GetEntityColumnX(endColumn);
        return (startX + endX) * 0.5;
    }
    public static function GetCombineZ(entity:Entity):Float
    {
        return entity.Level.GetLawnCenterZ();
    }
    public static function GetCombinePosition(entity:Entity, atLeft:Bool):Vector3
    {
        var level = entity.Level;
        var x = GetCombineX(entity, atLeft);
        var z = GetCombineZ(entity);
        var y = level.GetGroundY(x, z);
        return new Vector3(x, y, z);
    }
    // #endregion

    public static function FindEyeBulletTarget(entity:Entity, outerEye:Bool):Null<Entity>
    {
        var detector = outerEye ? outerEyeBulletDetector : innerEyeBulletDetector;
        return detector.DetectEntityWithTheLeast(DetectionParams.fromEntity(entity), function(e) return e.Position.x - entity.Position.x);
    }
    public static function Smash(entity:Entity, outer:Bool):Void
    {
        var detector = outer ? outerArmDamageDetector : innerArmDamageDetector;
        smashDetectBuffer = new ArrayBuffer(8);
        detector.DetectMultipleIntoBuffer(DetectionParams.fromEntity(entity), smashDetectBuffer);
        var damaged = false;
        for (i in 0...smashDetectBuffer.Count)
        {
            var collider = smashDetectBuffer.Get(i);
            var damage = VanillaEntityProps.GetTakenCrushDamage(collider.Entity);
            var output = collider.TakeDamage(damage, new DamageEffectList([VanillaDamageEffects.IMPACT, VanillaDamageEffects.DAMAGE_BOTH_ARMOR_AND_BODY]), entity);
            if (output.HasAnyFatal())
            {
                damaged = true;
            }
        }
        if (damaged)
        {
            entity.PlaySound(VanillaSoundID.smash);
        }
        entity.Level.ShakeScreen(10, 0, 15);
        entity.PlaySound(VanillaSoundID.thump);
    }
    public static function CanArmsAttack(entity:Entity):Bool
    {
        return outerArmDetector.DetectExists(DetectionParams.fromEntity(entity)) || innerArmDetector.DetectExists(DetectionParams.fromEntity(entity));
    }

    // #region 吃豆人
    public static function IsPacman(entity:Entity):Bool
    {
        var state = stateMachine.GetStateNumber(entity);
        var subState = stateMachine.GetSubState(entity);
        return state == STATE_PACMAN && subState == PacmanState.SUBSTATE_PACMAN;
    }
    public static function IsPacmanPanic(entity:Entity):Bool
    {
        return entity.Target != null && IsPacmanGhost(entity.Target);
    }
    public static function GetPacmanPanicDevourer(entity:Entity):Null<Entity>
    {
        return entity.Level.FindFirstEntityWithTheLeast(IsPacmanGhost, function(e) return (e.Position - entity.Position).sqrMagnitude);
    }
    public static function IsPacmanGhost(entity:Entity):Bool
    {
        return EngineEntityExt.ExistsAndAlive(entity) && entity.IsEntityOf(VanillaContraptionID.devourer) && LogicContraptionProps.IsEvoked(entity);
    }
    public static function KillPacman(entity:Entity):Void
    {
        if (!IsPacman(entity))
            return;
        stateMachine.StartSubState(entity, PacmanState.SUBSTATE_PACMAN_DEATH);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.ResetTime(60);
        entity.PlaySound(VanillaSoundID.pacmanFail);
        entity.AddBuff(TheGiantPacmanKilledBuff);
    }
    public static function GetPacmanBlockPosition(entity:Entity, index:Int, atLeft:Bool):Vector3
    {
        var level = entity.Level;
        var gridPositionOffset = pacmanBlockGridOffsets[index];
        var originX = level.GetEntityColumnX(atLeft ? 0 : (level.GetMaxColumnCount() - 1));
        var originZ = entity.Position.z;
        var xOffset = gridPositionOffset.x * level.GetGridWidth();
        var x = originX + (atLeft ? xOffset : -xOffset);
        var z = originZ + gridPositionOffset.y * level.GetGridHeight();
        var y = level.GetGroundY(x, z);
        return new Vector3(x, y, z);
    }
    // #endregion

    // #region 贪吃蛇
    public static function IsSnake(entity:Entity):Bool
    {
        var state = stateMachine.GetStateNumber(entity);
        var subState = stateMachine.GetSubState(entity);
        return state == STATE_SNAKE && subState == SnakeState.SUBSTATE_SNAKE;
    }
    public static function CanAttractByBlackhole(entity:Entity):Bool
    {
        var state = stateMachine.GetStateNumber(entity);
        var subState = stateMachine.GetSubState(entity);
        return state == STATE_SNAKE && (subState == SnakeState.SUBSTATE_SNAKE || subState == SnakeState.SUBSTATE_SNAKE_DEATH);
    }
    public static function KillSnake(entity:Entity):Void
    {
        if (!IsSnake(entity))
            return;
        stateMachine.StartSubState(entity, SnakeState.SUBSTATE_SNAKE_DEATH);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.ResetTime(30);
        entity.PlaySound(VanillaSoundID.pacmanFail);
    }
    public static function GetSnakeBlockPosition(entity:Entity, index:Int, atLeft:Bool):Vector3
    {
        var level = entity.Level;
        var lanes = level.GetMaxLaneCount();
        var col = Std.int(index / lanes);
        var lane = index % lanes;
        var column = atLeft ? col : (level.GetMaxColumnCount() - 1 - col);
        var pos = level.GetEntityGridPosition(column, lane);
        if (index >= SNAKE_COMBINE_ZOMBIE_BLOCK_COUNT)
        {
            pos.y += 600;
        }
        return pos;
    }
    // #endregion

    // #region 常量
    public static var PROP_PHASE:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("Phase");
    public static var PROP_ZOMBIE_BLOCKS:VanillaEntityPropertyMeta<Array<EntityID>> = new VanillaEntityPropertyMeta<Array<EntityID>>("ZombieBlocks");
    public static var PROP_SNAKE_TAILS:VanillaEntityPropertyMeta<Array<EntityID>> = new VanillaEntityPropertyMeta<Array<EntityID>>("SnakeTails");
    public static var PROP_FLIP_X:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("FlipX");
    public static var PROP_ATTACK_FLAG:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("AttackFlag");
    public static var PROP_TARGET_GRID_INDEX:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("TargetGridIndex");
    public static var PROP_MALLEABLE:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("Malleable");


    public static var OUTER_EYE_BULLET_OFFSET:Vector3 = new Vector3(70, 140, 0);
    public static var INNER_EYE_BULLET_OFFSET:Vector3 = new Vector3(140, 140, 0);

    public static inline var STATE_IDLE:Int = VanillaBossStates.IDLE;
    public static inline var STATE_APPEAR:Int = VanillaBossStates.APPEAR;
    public static inline var STATE_STUNNED:Int = VanillaBossStates.STUNNED;
    public static inline var STATE_DEATH:Int = VanillaBossStates.DEATH;
    public static inline var STATE_DISASSEMBLY:Int = VanillaBossStates.THE_GIANT_DISASSEMBLY;
    public static inline var STATE_EYES:Int = VanillaBossStates.THE_GIANT_EYES;
    public static inline var STATE_ROAR:Int = VanillaBossStates.THE_GIANT_ROAR;
    public static inline var STATE_ARMS:Int = VanillaBossStates.THE_GIANT_ARMS;
    public static inline var STATE_BREATH:Int = VanillaBossStates.THE_GIANT_BREATH;
    public static inline var STATE_PACMAN:Int = VanillaBossStates.THE_GIANT_PACMAN;
    public static inline var STATE_SNAKE:Int = VanillaBossStates.THE_GIANT_SNAKE;
    public static inline var STATE_FAINT:Int = VanillaBossStates.THE_GIANT_FAINT;
    public static inline var STATE_CHASE:Int = VanillaBossStates.THE_GIANT_CHASE;

    public static inline var ANIMATION_STATE_IDLE:Int = 0;
    public static inline var ANIMATION_STATE_DISASSEMBLY:Int = 1;
    public static inline var ANIMATION_STATE_EYES:Int = 2;
    public static inline var ANIMATION_STATE_ARMS:Int = 3;
    public static inline var ANIMATION_STATE_ROAR:Int = 4;
    public static inline var ANIMATION_STATE_BREATH:Int = 5;
    public static inline var ANIMATION_STATE_CHASE:Int = 6;
    public static inline var ANIMATION_STATE_PACMAN:Int = 7;
    public static inline var ANIMATION_STATE_SNAKE:Int = 8;
    public static inline var ANIMATION_STATE_STUNNED:Int = 100;
    public static inline var ANIMATION_STATE_FAINT:Int = 101;
    public static inline var ANIMATION_STATE_DEATH:Int = 102;

    public static inline var PHASE_1:Int = 0;
    public static inline var PHASE_2:Int = 1;
    public static inline var PHASE_3:Int = 2;

    public static inline var ZOMBIE_BLOCK_COLUMNS:Int = 2;
    public static inline var ZOMBIE_BLOCK_LEFT_COLUMN_START:Int = -1;
    public static inline var ZOMBIE_BLOCK_MOVE_INTERVAL:Int = 10;
    public static inline var DARK_HOLE_EFFECT_SCALE:Float = 2.5;

    public static inline var EYE_BULLET_INTERVAL:Int = 30;
    public static inline var EYE_BULLET_COUNT:Int = 4;
    public static inline var EYE_BULLET_DAMAGE_MULTIPLIER:Float = 3;
    public static inline var EYE_BULLET_SPEED:Float = 30;
    public static inline var ROAR_STUN_TIME:Int = 150;

    public static inline var PACMAN_BLOCK_COUNT:Int = 8;
    public static inline var PACMAN_DURATION:Int = 300;
    public static inline var PACMAN_MOVE_SPEED:Float = 3;
    public static inline var PACMAN_DAMAGE_MULTIPLIER:Float = 0.01;
    public static inline var PACMAN_HEAL_MULTIPLIER:Float = 2;
    public static inline var PACMAN_GHOST_DAMAGE:Float = 600;

    public static inline var SNAKE_BLOCK_COUNT:Int = 8;
    public static inline var SNAKE_MOVE_SPEED:Float = 6;
    public static inline var SNAKE_DAMAGE_MULTIPLIER:Float = 0.03;
    public static inline var SNAKE_SELF_EAT_DAMAGE:Float = 600;
    public static inline var SNAKE_COMBINE_ZOMBIE_BLOCK_COUNT:Float = 3;
    public static inline var SNAKE_MAX_EAT_COUNT:Float = 8;

    public static inline var MAX_MALLEABLE_DAMAGE:Float = 3000;
    public static inline var MALLEABLE_DECAY_PHASE_3:Float = 10;

    public static inline var CRY_INTERVAL:Int = 300;

    public static var unstunnableStates:Array<Int> = [
        STATE_DISASSEMBLY,
        STATE_PACMAN,
        STATE_SNAKE,
        STATE_STUNNED,
        STATE_FAINT
    ];
    public static var pacmanBlockGridOffsets:Array<Vector2Int> = [
        new Vector2Int(0, 0),
        new Vector2Int(0, 1),
        new Vector2Int(0, -1),
        new Vector2Int(1, 0),
        new Vector2Int(1, 1),
        new Vector2Int(1, -1),
        new Vector2Int(2, 1),
        new Vector2Int(2, -1)
    ];
    public static var outerEyeBulletDetector:Detector = new TheGiantEyeDetector(true);
    public static var innerEyeBulletDetector:Detector = new TheGiantEyeDetector(false);
    public static var outerArmDetector:Detector = new TheGiantArmDetector(true);
    public static var innerArmDetector:Detector = new TheGiantArmDetector(false);
    public static var outerArmDamageDetector:Detector = new TheGiantArmDetector(true);
    public static var innerArmDamageDetector:Detector = new TheGiantArmDetector(false);
    public static var pacmanDetector:Detector = new DevourerEvokedDetector();
    public static var smashDetectBuffer:ArrayBuffer<IEntityCollider> = new ArrayBuffer<IEntityCollider>(8);

    // #endregion 常量

    public static var stateMachine:TheGiantStateMachine = new TheGiantStateMachine();

    public static function Stun(entity:Entity, duration:Int):Void
    {
        if (entity.IsDead)
            return;
        if (!CanBeStunned(entity))
            return;
        entity.PlaySound(VanillaSoundID.zombieHurt, 0.5);
        var vel = entity.Velocity;
        vel.x = 0;
        entity.Velocity = vel;
        stateMachine.StartState(entity, STATE_STUNNED);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.ResetTime(duration);
    }
    public static function SetAppear(entity:Entity):Void
    {
        if (entity.IsDead)
            return;
        entity.Health = 1;
        stateMachine.StartState(entity, STATE_APPEAR);
    }
    public static function SpawnDarkHole(entity:Entity):Void
    {
        var param = entity.GetSpawnParams();
        param.SetProperty(EngineEntityProps.DISPLAY_SCALE, Vector3.one * DARK_HOLE_EFFECT_SCALE);
        entity.Spawn(VanillaEffectID.darkHole, entity.Position, param);
        entity.PlaySound(VanillaSoundID.odd);
    }
    public static function RoarLoop(entity:Entity):Void
    {
        entity.Level.ShakeScreen(15, 0, 5);
        VanillaBossExt.BossRoar(entity, ROAR_STUN_TIME);
    }
    public static function CanCrawl(entity:Entity):Bool
    {
        return entity.GetBounds().min.x > LevelPositions.GetAttackBorderX(false);
    }
    public static function CheckDeath(entity:Entity):Void
    {
        if (!entity.IsDead)
            return;
        if (GetPhase(entity) != PHASE_3)
        {
            stateMachine.StartState(entity, STATE_FAINT);
        }
        else
        {
            stateMachine.StartState(entity, STATE_DEATH);
        }
    }
    public static function ReformToIdle(entity:Entity):Void
    {
        stateMachine.StartState(entity, STATE_IDLE);
        stateMachine.StartSubState(entity, TheGiantIdleState.SUBSTATE_REFORMED);
        ResetMalleable(entity);
    }
}

private class TheGiantStateMachine extends EntityStateMachine
{
    public function new()
    {
        super();
        AddState(new TheGiantIdleState());
        AddState(new GiantAppearState());
        AddState(new DisassemblyState());
        AddState(new EyeState());
        AddState(new ArmsState());
        AddState(new RoarState());
        AddState(new BreathState());
        AddState(new PacmanState());
        AddState(new SnakeState());
        AddState(new GiantStunState());
        AddState(new GiantFaintState());
        AddState(new ChaseState());
        AddState(new GiantDeathState());
    }
}

// #region 状态
private class TheGiantIdleState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_IDLE, TheGiant.ANIMATION_STATE_IDLE);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var stateTimer = stateMachine.GetStateTimer(entity);
        stateTimer.ResetTime(60);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        if (TheGiant.GetPhase(entity) == TheGiant.PHASE_3)
        {
            if (TheGiant.CanCrawl(entity))
            {
                if (TheGiant.IsFlipX(entity))
                {
                    stateMachine.StartState(entity, TheGiant.STATE_DISASSEMBLY);
                }
                else
                {
                    stateMachine.StartState(entity, TheGiant.STATE_CHASE);
                }
            }
            else
            {
                if (entity.IsTimeInterval(15))
                {
                    var level = entity.Level;
                    var bounds = entity.GetBounds();
                    var minLane = Mathf.MaxInt(0, level.GetLane(bounds.max.z));
                    var maxLane = Mathf.MinInt(level.GetMaxLaneCount() - 1, level.GetLane(bounds.min.z));
                    var targetLane = entity.RNG.Next(minLane, maxLane + 1);
                    var position = entity.Position;
                    position.z = level.GetEntityLaneZ(targetLane);
                    position.y += 20;
                    entity.SpawnWithParams(VanillaEnemyID.zombie, position);
                }
            }
            return;
        }
        else
        {
            if (entity.IsDead)
            {
                stateMachine.StartState(entity, TheGiant.STATE_FAINT);
                return;
            }
        }
        if (TheGiant.GetPhase(entity) == TheGiant.PHASE_1 && entity.Health <= entity.GetMaxHealth() * 0.5)
        {
            TheGiant.Stun(entity, 30);
            return;
        }
        UpdateStateSwitch(stateMachine, entity);
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    private function UpdateStateSwitch(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        var stateTimer = stateMachine.GetStateTimer(entity);
        stateTimer.Run(stateMachine.GetSpeed(entity));
        if (stateTimer.Expired)
        {
            var substate = stateMachine.GetSubState(entity);
            if (substate != SUBSTATE_REFORMED)
            {
                stateMachine.StartState(entity, TheGiant.STATE_DISASSEMBLY);
            }
            else
            {
                var nextState = GetNextState(stateMachine, entity);
                stateMachine.StartState(entity, nextState);
            }
        }
    }
    private function GetNextState(stateMachine:EntityStateMachine, entity:Entity):Int
    {
        var lastState = stateMachine.GetPreviousState(entity);

        var atLeft = TheGiant.AtLeft(entity);
        var phase2 = TheGiant.GetPhase(entity) == TheGiant.PHASE_2;
        var attackFlag = TheGiant.GetAttackFlag(entity);
        if (atLeft)
        {
            var attack1Used = (attackFlag & 1) != 0;
            attackFlag ^= 1;
            TheGiant.SetAttackFlag(entity, attackFlag);
            if (attack1Used)
            {
                if (!phase2)
                {
                    lastState = TheGiant.STATE_BREATH;
                    return lastState;
                }
                else
                {
                    lastState = TheGiant.STATE_SNAKE;
                    return lastState;
                }
            }
            lastState = TheGiant.STATE_EYES;
            var innerTarget = TheGiant.FindEyeBulletTarget(entity, false);
            var outerTarget = TheGiant.FindEyeBulletTarget(entity, true);
            if (EngineEntityExt.ExistsAndAlive(innerTarget) || EngineEntityExt.ExistsAndAlive(outerTarget))
            {
                return lastState;
            }
        }
        else
        {
            var attack1Used = (attackFlag & 2) != 0;
            attackFlag ^= 2;
            TheGiant.SetAttackFlag(entity, attackFlag);
            if (attack1Used)
            {
                if (!phase2)
                {
                    lastState = TheGiant.STATE_ROAR;
                    if (entity.Level.EntityExists(function(e) return VanillaBossExt.CanBossRoarStun(entity, e)))
                    {
                        return lastState;
                    }
                }
                else
                {
                    lastState = TheGiant.STATE_PACMAN;
                    return lastState;
                }
            }
            lastState = TheGiant.STATE_ARMS;
            if (TheGiant.CanArmsAttack(entity))
            {
                return lastState;
            }
        }
        return TheGiant.STATE_IDLE;
    }
    public static inline var SUBSTATE_REFORMED:Int = 1;
}
private class GiantAppearState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_APPEAR, TheGiant.ANIMATION_STATE_IDLE);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var stateTimer = stateMachine.GetStateTimer(entity);
        stateTimer.ResetTime(30);

        TheGiant.SetInactive(entity, true);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var stateTimer = stateMachine.GetStateTimer(entity);
        stateTimer.Run(stateMachine.GetSpeed(entity));
        entity.Health = stateTimer.GetPassedPercentage() * entity.GetMaxHealth();
        if (stateTimer.Expired)
        {
            TheGiant.SetInactive(entity, true);
            stateMachine.StartState(entity, TheGiant.STATE_DISASSEMBLY);
        }
    }
}
private class DisassemblyState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_DISASSEMBLY, TheGiant.ANIMATION_STATE_DISASSEMBLY);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_RESTORE:
                return ANIMATION_SUBSTATE_RESTORE;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(10);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_CURL:
                if (substateTimer.Expired)
                {
                    TheGiant.SetInactive(entity, true);
                    // 分离。
                    var atLeft = TheGiant.AtLeft(entity);
                    var targetState = atLeft ? SUBSTATE_TO_RIGHT : SUBSTATE_TO_LEFT;
                    stateMachine.StartSubState(entity, targetState);
                    substateTimer.ResetTime(30);

                    var level = entity.Level;
                    var rng = entity.RNG;
                    var lanes = level.GetMaxLaneCount();
                    var validLanes:Array<Int> = [];
                    for (i in 0...lanes) validLanes.push(i);
                    var phase2 = TheGiant.GetPhase(entity) == TheGiant.PHASE_2;
                    for (x in 0...TheGiant.ZOMBIE_BLOCK_COLUMNS)
                    {
                        var column = TheGiant.GetZombieBlockStartColumn(entity, x, atLeft);
                        var columnEnd = TheGiant.GetZombieBlockEndColumn(entity, x, atLeft);
                        var lanesPool = EnumerableExt.Randomize(validLanes, rng);
                        for (y in 0...lanes)
                        {
                            var i = y + x * lanes;
                            var lane = lanesPool[y];

                            var block = TheGiant.SpawnZombieBlock(entity, entity.Position);
                            if (block != null)
                            {
                                var e = block;
                                if (!phase2)
                                {
                                    ZombieBlock.SetMode(e, ZombieBlock.MODE_FLY);
                                }
                                else
                                {
                                    ZombieBlock.SetMode(e, ZombieBlock.MODE_JUMP);
                                    var gravity = 3;
                                    var distance = (rng.Next(2) + 1) * level.GetGridWidth();
                                    e.SetGravity(gravity);
                                    ZombieBlock.SetJumpDistance(e, distance);
                                }
                                ZombieBlock.SetStartGrid(e, column, lane);
                                ZombieBlock.SetTargetGrid(e, columnEnd, lane);
                                ZombieBlock.SetMoveCooldown(e, 30 + i * TheGiant.ZOMBIE_BLOCK_MOVE_INTERVAL);
                            }
                        }
                    }
                    TheGiant.SpawnDarkHole(entity);
                    entity.Position = TheGiant.GetCombinePosition(entity, !atLeft);
                }
            case SUBSTATE_TO_LEFT, SUBSTATE_TO_RIGHT:
                if (substateTimer.Expired)
                {
                    var blocks = TheGiant.GetZombieBlocks(entity);
                    // PORT-NOTE: C# 的 break 用于跳出 switch 分支，Haxe 无此语义，改为 if/else。
                    if (!TheGiant.AreAllZombieBlocksReached(entity))
                    {
                        substateTimer.Reset();
                    }
                    else
                    {
                        stateMachine.StartSubState(entity, SUBSTATE_COMBINE);
                        substateTimer.ResetTime(15);
                        if (blocks != null)
                        {
                            for (blockID in blocks)
                            {
                                var block = blockID.GetEntity(entity.Level);
                                if (block == null || !unity.UnityObject.exists(block))
                                    continue;
                                ZombieBlock.SetMode(block, ZombieBlock.MODE_TRANSFORM);
                                ZombieBlock.SetTargetPosition(block, entity.Position);
                            }
                        }
                    }
                    }
            case SUBSTATE_COMBINE:
                if (substateTimer.Expired)
                {
                    TheGiant.RemoveAllZombieBlocks(entity);
                    TheGiant.SpawnDarkHole(entity);
                    TheGiant.SetInactive(entity, false);
                    TheGiant.SetFlipX(entity, TheGiant.AtLeft(entity));
                    TheGiant.ResetMalleable(entity);

                    if (entity.IsDead)
                    {
                        stateMachine.StartState(entity, TheGiant.STATE_FAINT);
                    }
                    else
                    {
                        stateMachine.StartSubState(entity, SUBSTATE_RESTORE);
                        substateTimer.ResetTime(30);
                    }
                }
            case SUBSTATE_RESTORE:
                if (substateTimer.Expired)
                {
                    if (TheGiant.GetPhase(entity) == TheGiant.PHASE_3)
                    {
                        if (TheGiant.IsFlipX(entity))
                        {
                            stateMachine.StartState(entity, TheGiant.STATE_DISASSEMBLY);
                        }
                        else
                        {
                            stateMachine.StartState(entity, TheGiant.STATE_CHASE);
                        }
                    }
                    else
                    {
                        TheGiant.ReformToIdle(entity);
                    }
                }
        }
    }
    public static inline var SUBSTATE_CURL:Int = 0;
    public static inline var SUBSTATE_TO_LEFT:Int = 1;
    public static inline var SUBSTATE_TO_RIGHT:Int = 2;
    public static inline var SUBSTATE_COMBINE:Int = 3;
    public static inline var SUBSTATE_RESTORE:Int = 4;
    public static inline var ANIMATION_SUBSTATE_RESTORE:Int = 1;
}
private class EyeState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_EYES, TheGiant.ANIMATION_STATE_EYES);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_CLOSE:
                return ANIMATION_SUBSTATE_CLOSE;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(30);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_OPEN:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_FIRE);
                    substateTimer.ResetTime(TheGiant.EYE_BULLET_INTERVAL * TheGiant.EYE_BULLET_COUNT);
                }
            case SUBSTATE_FIRE:
                for (i in 0...substateTimer.PassedIntervalCount(TheGiant.EYE_BULLET_INTERVAL))
                {
                    var outerEye = Std.int(substateTimer.Frame / TheGiant.EYE_BULLET_INTERVAL) % 2 == 0;
                    var target = TheGiant.FindEyeBulletTarget(entity, outerEye);
                    if (EngineEntityExt.ExistsAndAlive(target))
                    {
                        ShootBullet(entity, target, outerEye);
                        continue;
                    }
                    outerEye = !outerEye;
                    target = TheGiant.FindEyeBulletTarget(entity, outerEye);
                    if (EngineEntityExt.ExistsAndAlive(target))
                    {
                        ShootBullet(entity, target, outerEye);
                        continue;
                    }
                    substateTimer.Frame = 0;
                }
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_CLOSE);
                    substateTimer.ResetTime(30);
                }
            case SUBSTATE_CLOSE:
                if (substateTimer.Expired)
                {
                    stateMachine.StartState(entity, TheGiant.STATE_IDLE);
                }
        }
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    private function ShootBullet(entity:Entity, target:Entity, outerEye:Bool):Void
    {
        entity.Level.ShakeScreen(5, 0, 5);
        var param = entity.GetShootParams();
        var offset = outerEye ? TheGiant.OUTER_EYE_BULLET_OFFSET : TheGiant.INNER_EYE_BULLET_OFFSET;
        offset = VanillaProjectileExt.ModifyShotOffset(entity, offset);
        param.position = entity.Position + offset;
        param.soundID = null;
        param.damage = VanillaEntityProps.GetDamage(entity) * TheGiant.EYE_BULLET_DAMAGE_MULTIPLIER;
        param.projectileID = VanillaProjectileID.reflectionBullet;
        param.velocity = (target.GetCenter() - param.position).normalized * TheGiant.EYE_BULLET_SPEED;
        var spawnParam = param.spawnParam;
        spawnParam.SetProperty(EngineEntityProps.SCALE, Vector3.one * 2);
        spawnParam.SetProperty(EngineEntityProps.DISPLAY_SCALE, Vector3.one * 2);
        var bullet = VanillaProjectileExt.ShootProjectile(entity, param);
        if (bullet != null)
        {
            bullet.PlaySound(VanillaSoundID.reflection, 0.5);
            bullet.PlaySound(VanillaSoundID.mineExplode, 0.5);
        }
    }
    public static inline var SUBSTATE_OPEN:Int = 0;
    public static inline var SUBSTATE_FIRE:Int = 1;
    public static inline var SUBSTATE_CLOSE:Int = 2;
    public static inline var ANIMATION_SUBSTATE_CLOSE:Int = 1;
}
private class ArmsState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_ARMS, TheGiant.ANIMATION_STATE_ARMS);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_OUTER_LIFT:
                return ANIMATION_SUBSTATE_OUTER_LIFT;
            case SUBSTATE_OUTER_SMASH, SUBSTATE_OUTER_SMASHED:
                return ANIMATION_SUBSTATE_OUTER_SMASH;
            case SUBSTATE_INNER_LIFT:
                return ANIMATION_SUBSTATE_INNER_LIFT;
            case SUBSTATE_INNER_SMASH, SUBSTATE_INNER_SMASHED:
                return ANIMATION_SUBSTATE_INNER_SMASH;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(30);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_OUTER_LIFT:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_OUTER_SMASH);
                    substateTimer.ResetTime(5);
                }
            case SUBSTATE_OUTER_SMASH:
                if (substateTimer.Expired)
                {
                    TheGiant.Smash(entity, true);
                    stateMachine.StartSubState(entity, SUBSTATE_OUTER_SMASHED);
                    substateTimer.ResetTime(25);
                }
            case SUBSTATE_OUTER_SMASHED:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_INNER_LIFT);
                    substateTimer.ResetTime(30);
                }
            case SUBSTATE_INNER_LIFT:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_INNER_SMASH);
                    substateTimer.ResetTime(5);
                }
            case SUBSTATE_INNER_SMASH:
                if (substateTimer.Expired)
                {
                    TheGiant.Smash(entity, false);
                    stateMachine.StartSubState(entity, SUBSTATE_INNER_SMASHED);
                    substateTimer.ResetTime(25);
                }
            case SUBSTATE_INNER_SMASHED:
                if (substateTimer.Expired)
                {
                    stateMachine.StartState(entity, TheGiant.STATE_IDLE);
                }
        }
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    public static inline var SUBSTATE_OUTER_LIFT:Int = 0;
    public static inline var SUBSTATE_OUTER_SMASH:Int = 1;
    public static inline var SUBSTATE_OUTER_SMASHED:Int = 2;
    public static inline var SUBSTATE_INNER_LIFT:Int = 3;
    public static inline var SUBSTATE_INNER_SMASH:Int = 4;
    public static inline var SUBSTATE_INNER_SMASHED:Int = 5;
    public static inline var ANIMATION_SUBSTATE_OUTER_LIFT:Int = 0;
    public static inline var ANIMATION_SUBSTATE_OUTER_SMASH:Int = 1;
    public static inline var ANIMATION_SUBSTATE_INNER_LIFT:Int = 2;
    public static inline var ANIMATION_SUBSTATE_INNER_SMASH:Int = 3;
}
private class RoarState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_ROAR, TheGiant.ANIMATION_STATE_ROAR);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_LOOP:
                return ANIMATION_SUBSTATE_LOOP;
            case SUBSTATE_END:
                return ANIMATION_SUBSTATE_END;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(15);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_START:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_LOOP);
                    substateTimer.ResetTime(90);
                    entity.PlaySound(VanillaSoundID.giantRoar);
                }
            case SUBSTATE_LOOP:
                TheGiant.RoarLoop(entity);
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_END);
                    substateTimer.ResetTime(15);
                }
            case SUBSTATE_END:
                if (substateTimer.Expired)
                {
                    stateMachine.StartState(entity, TheGiant.STATE_IDLE);
                }
        }
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    public static inline var SUBSTATE_START:Int = 0;
    public static inline var SUBSTATE_LOOP:Int = 1;
    public static inline var SUBSTATE_END:Int = 2;
    public static inline var ANIMATION_SUBSTATE_START:Int = 0;
    public static inline var ANIMATION_SUBSTATE_LOOP:Int = 1;
    public static inline var ANIMATION_SUBSTATE_END:Int = 2;
}
private class BreathState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_BREATH, TheGiant.ANIMATION_STATE_BREATH);
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(30);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_START:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_BREATH);
                    substateTimer.ResetTime(45);
                    entity.PlaySound(VanillaSoundID.poisonCast);
                    for (lane in 0...entity.Level.GetMaxLaneCount())
                    {
                        var x = entity.Position.x + 80 * VanillaEntityExt.GetFacingX(entity);
                        var z = entity.Level.GetEntityLaneZ(lane);
                        var y = entity.Level.GetGroundY(x, z);
                        var param = entity.GetSpawnParams();
                        var gas = entity.Spawn(VanillaEffectID.mummyGas, new Vector3(x, y, z), param);
                        if (gas != null)
                        {
                            gas.Velocity = VanillaEntityExt.GetFacingDirection(entity) * 1;
                        }
                    }
                }
            case SUBSTATE_BREATH:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_END);
                    substateTimer.ResetTime(15);
                }
            case SUBSTATE_END:
                if (substateTimer.Expired)
                {
                    stateMachine.StartState(entity, TheGiant.STATE_IDLE);
                }
        }
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    public static inline var SUBSTATE_START:Int = 0;
    public static inline var SUBSTATE_BREATH:Int = 1;
    public static inline var SUBSTATE_END:Int = 2;
}
private class PacmanState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_PACMAN, TheGiant.ANIMATION_STATE_PACMAN);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_REFORMED:
                return ANIMATION_SUBSTATE_REFROMED;
            case SUBSTATE_PACMAN, SUBSTATE_PACMAN_DEATH, SUBSTATE_PACMAN_END:
                return ANIMATION_SUBSTATE_PACMAN;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(10);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_CURL:
                if (substateTimer.Expired)
                {
                    TheGiant.SetInactive(entity, true);
                    // 分离。
                    var atLeft = false;
                    var targetState = SUBSTATE_FORM;
                    stateMachine.StartSubState(entity, targetState);
                    substateTimer.ResetTime(30);

                    var level = entity.Level;
                    var rng = entity.RNG;
                    var lanes = level.GetMaxLaneCount();
                    var validLanes:Array<Int> = [];
                    for (i in 0...lanes) validLanes.push(i);
                    for (i in 0...TheGiant.PACMAN_BLOCK_COUNT)
                    {
                        var startPosition = TheGiant.GetZombieBlockPosition(entity, i, atLeft);
                        var targetPosition = TheGiant.GetPacmanBlockPosition(entity, i, atLeft);
                        var e = TheGiant.SpawnZombieBlock(entity, entity.Position);
                        if (e != null)
                        {
                            ZombieBlock.SetMode(e, ZombieBlock.MODE_TRANSFORM);
                            ZombieBlock.SetStartPosition(e, startPosition);
                            ZombieBlock.SetTargetPosition(e, targetPosition);
                            ZombieBlock.SetMoveCooldown(e, 30);
                        }
                    }
                    TheGiant.SpawnDarkHole(entity);
                    entity.Position = TheGiant.GetCombinePosition(entity, atLeft);
                }
            case SUBSTATE_FORM:
                if (substateTimer.Expired)
                {
                    // PORT-NOTE: C# 的 break 用于跳出 switch 分支，Haxe 无此语义，改为 if/else。
                    if (!TheGiant.AreAllZombieBlocksReached(entity))
                    {
                        substateTimer.Reset();
                    }
                    else
                    {
                        TheGiant.RemoveAllZombieBlocks(entity);

                        var atLeft = false;
                        TheGiant.SpawnDarkHole(entity);
                        TheGiant.SetInactive(entity, false);
                        TheGiant.SetFlipX(entity, atLeft);
                        TheGiant.ResetMalleable(entity);

                        stateMachine.StartSubState(entity, SUBSTATE_PACMAN);
                        substateTimer.ResetTime(TheGiant.PACMAN_DURATION);
                        entity.PlaySound(VanillaSoundID.pacmanStart, 0.75);
                        entity.AddBuff(TheGiantPacmanBuff);
                        FindPacmanTarget(entity);
                    }
                    }
            case SUBSTATE_PACMAN:
                UpdatePacman(entity);
                if ((!TheGiant.IsPacmanPanic(entity) && substateTimer.Expired) || entity.IsDead)
                {
                    EndPacman(entity);
                }
            case SUBSTATE_PACMAN_DEATH:
                entity.SetAnimationInt("PacmanRotation", 4);
                entity.SetAnimationInt("PacmanState", 2);
                if (substateTimer.Expired)
                {
                    EndPacman(entity);
                }
            case SUBSTATE_PACMAN_END:
                if (substateTimer.Expired)
                {
                    // PORT-NOTE: C# 的 break 用于跳出 switch 分支，Haxe 无此语义，改为 if/else。
                    if (!TheGiant.AreAllZombieBlocksReached(entity))
                    {
                        substateTimer.Reset();
                    }
                    else
                    {
                        stateMachine.StartSubState(entity, SUBSTATE_COMBINE);
                        substateTimer.ResetTime(15);
                        var blocks = TheGiant.GetZombieBlocks(entity);
                        if (blocks != null)
                        {
                            for (blockID in blocks)
                            {
                                var block = blockID.GetEntity(entity.Level);
                                if (block == null || !unity.UnityObject.exists(block))
                                    continue;
                                ZombieBlock.SetMode(block, ZombieBlock.MODE_TRANSFORM);
                                ZombieBlock.SetTargetPosition(block, entity.Position);
                            }
                        }
                    }
                    }
            case SUBSTATE_COMBINE:
                if (substateTimer.Expired)
                {
                    var atLeft = true;
                    TheGiant.RemoveAllZombieBlocks(entity);
                    TheGiant.SpawnDarkHole(entity);
                    TheGiant.SetInactive(entity, false);
                    TheGiant.SetFlipX(entity, atLeft);
                    TheGiant.ResetMalleable(entity);
                    if (entity.IsDead)
                    {
                        stateMachine.StartState(entity, TheGiant.STATE_FAINT);
                    }
                    else
                    {
                        stateMachine.StartSubState(entity, SUBSTATE_REFORMED);
                        substateTimer.ResetTime(30);
                    }
                }
            case SUBSTATE_REFORMED:
                if (substateTimer.Expired)
                {
                    TheGiant.ReformToIdle(entity);
                }
        }
    }
    public function UpdatePacman(entity:Entity):Void
    {
        var level = entity.Level;
        var targetGridIndex = TheGiant.GetTargetGridIndex(entity);
        var targetGridPosition = level.GetEntityGridPositionByIndex(targetGridIndex);
        var targetGridDistance = targetGridPosition - entity.Position;
        var reached = VanillaEntityExt.MoveOrthogonally(entity, targetGridIndex, TheGiant.PACMAN_MOVE_SPEED);
        if (reached)
        {
            FindPacmanTarget(entity);
        }

        entity.SetAnimationInt("PacmanRotation", GetPacmanRotation(targetGridDistance));
        entity.SetAnimationInt("PacmanState", TheGiant.IsPacmanPanic(entity) ? 1 : 0);
    }
    public static function EndPacman(entity:Entity):Void
    {
        for (i in 0...TheGiant.PACMAN_BLOCK_COUNT)
        {
            var targetPosition = TheGiant.GetZombieBlockPosition(entity, i, true);
            var e = TheGiant.SpawnZombieBlock(entity, entity.Position);
            if (e != null)
            {
                ZombieBlock.SetMode(e, ZombieBlock.MODE_TRANSFORM);
                ZombieBlock.SetStartPosition(e, entity.Position);
                ZombieBlock.SetTargetPosition(e, targetPosition);
            }
        }
        TheGiant.SpawnDarkHole(entity);
        TheGiant.SetInactive(entity, true);
        entity.RemoveBuffs(TheGiantPacmanBuff);
        entity.RemoveBuffs(TheGiantPacmanKilledBuff);
        TheGiant.stateMachine.StartSubState(entity, SUBSTATE_PACMAN_END);
        var substateTimer = TheGiant.stateMachine.GetSubStateTimer(entity);
        substateTimer.ResetTime(30);
        entity.Position = TheGiant.GetCombinePosition(entity, true);
    }
    public static function GetPacmanRotation(direction:Vector3):Int
    {
        var dir = direction.normalized;
        if (Mathf.Abs(dir.z) > Mathf.Abs(dir.x))
        {
            if (direction.z < 0)
            {
                return 3; // Down.
            }
            return 1; // Up.
        }
        if (direction.x > 0)
        {
            return 2; // Right.
        }
        return 0; // Left.
    }
    public static function FindPacmanTarget(entity:Entity):Void
    {
        var devourer = TheGiant.GetPacmanPanicDevourer(entity);
        if (devourer != null)
        {
            entity.Target = devourer;
            var grid = VanillaEntityExt.GetEvadeTargetGridDefaultValidator(entity, devourer);
            if (grid != null)
                TheGiant.SetTargetGridIndex(entity, grid.GetIndex());
        }
        else
        {
            var level = entity.Level;
            var target = TheGiant.pacmanDetector.DetectEntityWithTheLeast(DetectionParams.fromEntity(entity), function(e) return (e.Position - entity.Position).sqrMagnitude);
            entity.Target = target;
            var grid = VanillaEntityExt.GetChaseTargetGridDefaultValidator(entity, entity.Target);
            if (grid != null)
                TheGiant.SetTargetGridIndex(entity, grid.GetIndex());
        }
    }
    public static inline var SUBSTATE_CURL:Int = 0;
    public static inline var SUBSTATE_FORM:Int = 1;
    public static inline var SUBSTATE_PACMAN:Int = 2;
    public static inline var SUBSTATE_PACMAN_END:Int = 3;
    public static inline var SUBSTATE_COMBINE:Int = 4;
    public static inline var SUBSTATE_REFORMED:Int = 5;
    public static inline var SUBSTATE_PACMAN_DEATH:Int = 6;
    public static inline var ANIMATION_SUBSTATE_CURL:Int = 0;
    public static inline var ANIMATION_SUBSTATE_PACMAN:Int = 1;
    public static inline var ANIMATION_SUBSTATE_REFROMED:Int = 2;
}
private class SnakeState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_SNAKE, TheGiant.ANIMATION_STATE_SNAKE);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_REFORMED:
                return ANIMATION_SUBSTATE_REFROMED;
            case SUBSTATE_SNAKE, SUBSTATE_SNAKE_DEATH, SUBSTATE_SNAKE_END:
                return ANIMATION_SUBSTATE_SNAKE;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(10);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_CURL:
                if (substateTimer.Expired)
                {
                    TheGiant.SetInactive(entity, true);
                    // 分离。
                    var atLeft = TheGiant.AtLeft(entity);
                    var targetState = SUBSTATE_FORM;
                    stateMachine.StartSubState(entity, targetState);
                    substateTimer.ResetTime(30);

                    var level = entity.Level;
                    var rng = entity.RNG;
                    var lanes = level.GetMaxLaneCount();
                    var validLanes:Array<Int> = [];
                    for (i in 0...lanes) validLanes.push(i);
                    for (i in 0...TheGiant.SNAKE_BLOCK_COUNT)
                    {
                        var startPosition = TheGiant.GetZombieBlockPosition(entity, i, true);
                        var targetPosition = TheGiant.GetSnakeBlockPosition(entity, i, true);
                        var e = TheGiant.SpawnZombieBlock(entity, entity.Position);
                        if (e != null)
                        {
                            ZombieBlock.SetMode(e, ZombieBlock.MODE_TRANSFORM);
                            ZombieBlock.SetStartPosition(e, startPosition);
                            ZombieBlock.SetTargetPosition(e, targetPosition);
                            ZombieBlock.SetMoveCooldown(e, 30);
                        }
                    }
                    TheGiant.SpawnDarkHole(entity);
                    entity.Position = TheGiant.GetCombinePosition(entity, !atLeft);
                }
            case SUBSTATE_FORM:
                if (substateTimer.Expired)
                {
                    // PORT-NOTE: C# 的 break 用于跳出 switch 分支，Haxe 无此语义，改为 if/else。
                    if (!TheGiant.AreAllZombieBlocksReached(entity))
                    {
                        substateTimer.Reset();
                    }
                    else
                    {
                        var blocks = TheGiant.GetZombieBlocks(entity);
                        if (blocks != null)
                        {
                            var lastSnakeTail:Entity = entity;
                            for (i in 0...blocks.length)
                            {
                                var blockID = blocks[i];
                                var block = blockID.GetEntity(entity.Level);
                                if (block == null || !unity.UnityObject.exists(block))
                                    continue;
                                if (i == 0)
                                {
                                    entity.Position = block.Position;
                                }
                                else if (i < TheGiant.SNAKE_COMBINE_ZOMBIE_BLOCK_COUNT)
                                {
                                    var tail = TheGiant.SpawnSnakeTail(entity, block.Position, lastSnakeTail);
                                    if (tail != null)
                                    {
                                        lastSnakeTail = tail;
                                    }
                                }
                            }
                        }
                        TheGiant.RemoveAllZombieBlocks(entity);

                        TheGiant.SpawnDarkHole(entity);
                        TheGiant.SetInactive(entity, false);
                        TheGiant.SetFlipX(entity, false);
                        TheGiant.ResetMalleable(entity);

                        stateMachine.StartSubState(entity, SUBSTATE_SNAKE);
                        entity.AddBuff(TheGiantSnakeBuff);

                        TheGiant.SetTargetGridIndex(entity, entity.GetGridIndex());
                        FindSnakeTarget(entity);
                    }
                    }
            case SUBSTATE_SNAKE:
                // PORT-NOTE: C# 的 break 用于跳出 switch 分支，Haxe 无此语义，改为 if/else。
                if (IsSnakeFull(entity) || entity.IsDead)
                {
                    EndSnake(entity);
                }
                else
                {
                    UpdateSnake(entity);
                }
            case SUBSTATE_SNAKE_DEATH:
                entity.SetAnimationInt("SnakeState", 1);
                if (substateTimer.Expired)
                {
                    EndSnake(entity);
                }
            case SUBSTATE_SNAKE_END:
                if (substateTimer.Expired)
                {
                    // PORT-NOTE: C# 的 break 用于跳出 switch 分支，Haxe 无此语义，改为 if/else。
                    if (!TheGiant.AreAllZombieBlocksReached(entity))
                    {
                        substateTimer.Reset();
                    }
                    else
                    {
                        stateMachine.StartSubState(entity, SUBSTATE_COMBINE);
                        substateTimer.ResetTime(15);
                        var blocks = TheGiant.GetZombieBlocks(entity);
                        if (blocks != null)
                        {
                            for (blockID in blocks)
                            {
                                var block = blockID.GetEntity(entity.Level);
                                if (block == null || !unity.UnityObject.exists(block))
                                    continue;
                                ZombieBlock.SetMode(block, ZombieBlock.MODE_TRANSFORM);
                                ZombieBlock.SetTargetPosition(block, entity.Position);
                            }
                        }
                    }
                    }
            case SUBSTATE_COMBINE:
                if (substateTimer.Expired)
                {
                    TheGiant.RemoveAllZombieBlocks(entity);
                    TheGiant.SpawnDarkHole(entity);
                    TheGiant.SetInactive(entity, false);
                    TheGiant.SetFlipX(entity, false);
                    TheGiant.ResetMalleable(entity);

                    if (entity.IsDead)
                    {
                        stateMachine.StartState(entity, TheGiant.STATE_FAINT);
                    }
                    else
                    {
                        stateMachine.StartSubState(entity, SUBSTATE_REFORMED);
                        substateTimer.ResetTime(30);
                    }
                }
            case SUBSTATE_REFORMED:
                if (substateTimer.Expired)
                {
                    TheGiant.ReformToIdle(entity);
                }
        }
    }
    public function UpdateSnake(entity:Entity):Void
    {
        TheGiantSnakeTail.MoveTail(entity, TheGiant.SNAKE_MOVE_SPEED);
        var level = entity.Level;
        var targetGridIndex = TheGiant.GetTargetGridIndex(entity);
        var targetGridPosition = level.GetEntityGridPositionByIndex(targetGridIndex);
        var targetGridDistance = targetGridPosition - entity.Position;
        var reached = VanillaEntityExt.MoveOrthogonally(entity, targetGridIndex, TheGiant.SNAKE_MOVE_SPEED);
        if (reached)
        {
            OnSnakeMovedToTarget(entity);
        }
        entity.SetAnimationInt("SnakeRotation", GetSnakeRotation(targetGridDistance));
        entity.SetAnimationInt("SnakeState", 0);
    }
    public function EndSnake(entity:Entity):Void
    {
        TheGiant.RemoveAllZombieBlocks(entity);
        TheGiant.RemoveAllSnakeTails(entity);

        var atLeft = false;
        for (i in 0...TheGiant.SNAKE_BLOCK_COUNT)
        {
            var targetPosition = TheGiant.GetZombieBlockPosition(entity, i, atLeft);
            var e = TheGiant.SpawnZombieBlock(entity, entity.Position);
            if (e != null)
            {
                ZombieBlock.SetMode(e, ZombieBlock.MODE_TRANSFORM);
                ZombieBlock.SetStartPosition(e, entity.Position);
                ZombieBlock.SetTargetPosition(e, targetPosition);
            }
        }

        TheGiant.SpawnDarkHole(entity);
        TheGiant.SetInactive(entity, true);
        entity.RemoveBuffs(TheGiantSnakeBuff);
        TheGiant.stateMachine.StartSubState(entity, SUBSTATE_SNAKE_END);
        var substateTimer = TheGiant.stateMachine.GetSubStateTimer(entity);
        substateTimer.ResetTime(30);
        entity.Position = TheGiant.GetCombinePosition(entity, atLeft);
    }
    public static function GetSnakeRotation(direction:Vector3):Int
    {
        var dir = direction.normalized;
        if (Mathf.Abs(dir.z) > Mathf.Abs(dir.x))
        {
            if (direction.z < 0)
            {
                return 3; // Down.
            }
            return 1; // Up.
        }
        if (direction.x > 0)
        {
            return 2; // Right.
        }
        return 0; // Left.
    }
    public static function OnSnakeMovedToTarget(entity:Entity):Void
    {
        FindSnakeTarget(entity);
    }
    public static function FindSnakeTarget(entity:Entity):Void
    {
        var level = entity.Level;

        // Eat Food.
        var gridPosition = entity.GetGridPosition();
        var blocks = GetGridZombieBlocks(level, gridPosition);
        for (block in blocks)
        {
            if (block == null || !unity.UnityObject.exists(block))
                continue;
            block.Remove();
            entity.PlaySound(VanillaSoundID.pacmanKill);
            var tail = TheGiantSnakeTail.FindTail(entity);
            if (tail != null)
            {
                TheGiant.SpawnSnakeTail(entity, tail.Position, tail);
            }
        }

        // Find Next Target.
        var target = level.FindFirstEntityWithTheLeast(function(e) return e.IsEntityOf(VanillaEffectID.zombieBlock), function(e) return (e.Position - entity.Position).sqrMagnitude);
        if (target == null)
        {
            target = SpawnZombieBlockAtRandomGrid(entity);
        }

        entity.Target = target;
        var grid = VanillaEntityExt.GetChaseTargetGrid(entity, entity.Target, GridValidator);

        var gridIndex = TheGiant.GetTargetGridIndex(entity);
        TheGiantSnakeTail.PassTargetGrids(entity, gridIndex);
        if (grid != null)
            TheGiant.SetTargetGridIndex(entity, grid.GetIndex());
    }
    public static function SpawnZombieBlockAtRandomGrid(entity:Entity):Null<Entity>
    {
        var level = entity.Level;
        var grids = level.GetAllGrids();
        var validGrids = Lambda.array(Lambda.filter(grids, function(g) return !GridHasTail(g)));
        if (validGrids.length <= 0)
            return null;
        var grid = EnumerableExt.Random(validGrids, entity.RNG);
        var pos = grid.GetEntityPosition();
        var spawnPos = pos;
        spawnPos.y = 800;
        var e = TheGiant.SpawnZombieBlock(entity, spawnPos);
        if (e != null)
        {
            ZombieBlock.SetMode(e, ZombieBlock.MODE_SNAKE_FOOD);
            ZombieBlock.SetStartPosition(e, pos);
        }
        return e;
    }
    public static function GridHasTail(grid:LawnGrid):Bool
    {
        var level = grid.Level;
        return level.EntityExists(function(e) return e.IsEntityOf(VanillaBossID.theGiantSnakeTail) && e.GetGrid() == grid);
    }
    // C#: GridHasTail(LevelEngine level, Vector2Int position)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to GridHasTailAt.
    public static function GridHasTailAt(level:LevelEngine, position:Vector2Int):Bool
    {
        return level.EntityExists(function(e) return e.IsEntityOf(VanillaBossID.theGiantSnakeTail) && e.GetColumn() == position.x && e.GetLane() == position.y);
    }
    public static function GetGridZombieBlocks(level:LevelEngine, position:Vector2Int):Array<Entity>
    {
        return level.FindEntities(function(e) return e.IsEntityOf(VanillaEffectID.zombieBlock) && ZombieBlock.GetMode(e) == ZombieBlock.MODE_SNAKE_FOOD && e.GetColumn() == position.x && e.GetLane() == position.y);
    }
    public static function IsSnakeFull(head:Entity):Bool
    {
        var tails = TheGiant.GetSnakeTails(head);
        return tails != null && tails.length >= TheGiant.SNAKE_MAX_EAT_COUNT - 1;
    }
    public static function GridValidator(entity:Entity, position:Vector2Int):Bool
    {
        if (!entity.Level.ValidateGridOutOfBounds(position))
            return false;
        if (GridHasTailAt(entity.Level, position))
            return false;
        return true;
    }
    public static inline var SUBSTATE_CURL:Int = 0;
    public static inline var SUBSTATE_FORM:Int = 1;
    public static inline var SUBSTATE_SNAKE:Int = 2;
    public static inline var SUBSTATE_SNAKE_END:Int = 3;
    public static inline var SUBSTATE_COMBINE:Int = 4;
    public static inline var SUBSTATE_REFORMED:Int = 5;
    public static inline var SUBSTATE_SNAKE_DEATH:Int = 6;
    public static inline var ANIMATION_SUBSTATE_CURL:Int = 0;
    public static inline var ANIMATION_SUBSTATE_SNAKE:Int = 1;
    public static inline var ANIMATION_SUBSTATE_REFROMED:Int = 2;
}
private class GiantStunState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_STUNNED, TheGiant.ANIMATION_STATE_STUNNED);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_RESTORE:
                return ANIMATION_SUBSTATE_RESTORE;
        }
        return 0;
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_STUNNED:
                if (substateTimer.PassedFrame(substateTimer.MaxFrame - 18))
                {
                    entity.Level.ShakeScreen(5, 0, 10);
                    entity.PlaySound(VanillaSoundID.thump);
                }
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_RESTORE);
                    substateTimer.ResetTime(30);
                }
            case SUBSTATE_RESTORE:
                if (substateTimer.Expired)
                {
                    stateMachine.StartState(entity, TheGiant.STATE_IDLE);
                    if (TheGiant.GetPhase(entity) == TheGiant.PHASE_1 && entity.Health <= entity.GetMaxHealth() * 0.5)
                    {
                        TheGiant.SetPhase(entity, TheGiant.PHASE_2);
                    }
                }
        }
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    public static inline var SUBSTATE_STUNNED:Int = 0;
    public static inline var SUBSTATE_RESTORE:Int = 1;
    public static inline var ANIMATION_SUBSTATE_RESTORE:Int = 1;
}
private class GiantFaintState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_FAINT, TheGiant.ANIMATION_STATE_FAINT);
    }
    override public function GetAnimationSubstate(substate:Int):Int
    {
        switch (substate)
        {
            case SUBSTATE_ROAR:
                return ANIMATION_SUBSTATE_ROAR;
            case SUBSTATE_ROAR_END:
                return ANIMATION_SUBSTATE_ROAR_END;
        }
        return 0;
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(90);
    }
    override public function OnUpdateLogic(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_FAINT:
                if (substateTimer.PassedFrame(substateTimer.MaxFrame - 18))
                {
                    entity.Level.ShakeScreen(5, 0, 10);
                    entity.PlaySound(VanillaSoundID.thump);
                }
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_HEAL);
                    substateTimer.ResetTime(30);
                    entity.AddBuff(TheGiantPhase3Buff);
                }
            case SUBSTATE_HEAL:
                TheGiant.SetPhase(entity, TheGiant.PHASE_3);
                entity.Health = entity.GetMaxHealth() * substateTimer.GetPassedPercentage();
                if (substateTimer.Expired)
                {
                    if (entity.IsDead)
                    {
                        entity.Revive();
                    }
                    stateMachine.StartSubState(entity, SUBSTATE_ROAR);
                    substateTimer.ResetTime(90);
                    entity.PlaySound(VanillaSoundID.giantRoar);
                }
            case SUBSTATE_ROAR:
                TheGiant.RoarLoop(entity);
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_ROAR_END);
                    substateTimer.ResetTime(30);
                }
            case SUBSTATE_ROAR_END:
                if (substateTimer.Expired)
                {
                    if (TheGiant.IsFlipX(entity))
                    {
                        stateMachine.StartState(entity, TheGiant.STATE_DISASSEMBLY);
                    }
                    else
                    {
                        stateMachine.StartState(entity, TheGiant.STATE_CHASE);
                    }
                }
        }
    }
    public static inline var SUBSTATE_FAINT:Int = 0;
    public static inline var SUBSTATE_HEAL:Int = 1;
    public static inline var SUBSTATE_ROAR:Int = 2;
    public static inline var SUBSTATE_ROAR_END:Int = 3;
    public static inline var ANIMATION_SUBSTATE_ROAR:Int = 1;
    public static inline var ANIMATION_SUBSTATE_ROAR_END:Int = 2;
}
private class ChaseState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_CHASE, TheGiant.ANIMATION_STATE_CHASE);
    }
    override public function OnEnter(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(machine, entity);
        var substateTimer = machine.GetSubStateTimer(entity);
        substateTimer.ResetTime(10);
    }
    override public function OnUpdateAI(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateAI(stateMachine, entity);
        var substateTimer = stateMachine.GetSubStateTimer(entity);
        substateTimer.Run(stateMachine.GetSpeed(entity));

        var substate = stateMachine.GetSubState(entity);
        switch (substate)
        {
            case SUBSTATE_CRAWL_START:
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_CRAWL);
                    substateTimer.ResetTime(10);
                    entity.Level.ShakeScreen(5, 0, 10);
                    entity.PlaySound(VanillaSoundID.thump);
                }
            case SUBSTATE_CRAWL:
                entity.Velocity = VanillaEntityExt.GetFacingDirection(entity) * 1;
                if (substateTimer.Expired)
                {
                    stateMachine.StartSubState(entity, SUBSTATE_CRAWL_END);
                    substateTimer.ResetTime(10);
                }
            case SUBSTATE_CRAWL_END:
                if (substateTimer.Expired)
                {
                    if (TheGiant.IsFlipX(entity))
                    {
                        stateMachine.StartState(entity, TheGiant.STATE_DISASSEMBLY);
                    }
                    else
                    {
                        if (!TheGiant.CanCrawl(entity))
                        {
                            stateMachine.StartState(entity, TheGiant.STATE_IDLE);
                        }
                        else
                        {
                            stateMachine.StartSubState(entity, SUBSTATE_CRAWL_START);
                            substateTimer.ResetTime(10);
                        }
                    }
                }
        }
    }
    override public function OnUpdateLogic(machine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(machine, entity);
        TheGiant.CheckDeath(entity);
    }
    public static inline var SUBSTATE_CRAWL_START:Int = 0;
    public static inline var SUBSTATE_CRAWL:Int = 1;
    public static inline var SUBSTATE_CRAWL_END:Int = 2;
}
private class GiantDeathState extends EntityStateMachineState
{
    public function new()
    {
        super(TheGiant.STATE_DEATH, TheGiant.ANIMATION_STATE_DEATH);
    }
    override public function OnEnter(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnEnter(stateMachine, entity);
        var stateTimer = stateMachine.GetStateTimer(entity);
        stateTimer.ResetTime(120);
        entity.PlaySound(VanillaSoundID.giantRoar);
    }
    override public function OnUpdateLogic(stateMachine:EntityStateMachine, entity:Entity):Void
    {
        super.OnUpdateLogic(stateMachine, entity);

        entity.Level.ShakeScreen(5, 5, 1);
        var stateTimer = stateMachine.GetStateTimer(entity);
        stateTimer.Run(stateMachine.GetSpeed(entity));

        if (stateTimer.Expired)
        {
            entity.PlaySound(VanillaSoundID.zombieDeath, 0.5);

            entity.PlaySound(VanillaSoundID.explosion);

            Explosion.Spawn(entity, entity.GetCenter(), 120);
            entity.Level.ShakeScreen(20, 0, 30);

            for (i in 0...50)
            {
                var zombieParam = entity.GetSpawnParams();
                zombieParam.SetProperty(LogicEnemyProps.HARMLESS, true);
                zombieParam.SetProperty(VanillaEnemyProps.NO_REWARD, true);
                zombieParam.SetProperty(VanillaEntityProps.FALL_RESISTANCE, -10000);
                var e = entity.Spawn(VanillaEnemyID.zombie, entity.GetCenter(), zombieParam);
                if (e != null)
                {
                    var xSpeed = e.RNG.NextFloat() * 20 - 10;
                    var ySpeed = e.RNG.NextFloat() * 10 + 3;
                    var zSpeed = e.RNG.NextFloat() * 20 - 10;
                    e.Velocity = new Vector3(xSpeed, ySpeed, zSpeed);
                }
                entity.Remove();
            }
        }
    }
}
// #endregion

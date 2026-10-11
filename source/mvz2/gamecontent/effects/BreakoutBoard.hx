// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/Chapter2/BreakoutBoard.cs
package mvz2.gamecontent.effects;

import mvz2.gamecontent.buffs.effects.BreakoutBoardUpgradeBuff;
import mvz2.gamecontent.projectiles.VanillaProjectileID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.effects.VanillaEffectStates;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.Global;
import mvz2logic.callbacks.LogicCallbacks;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.inputs.PointerPhase;
import mvz2logic.inputs.PointerTypes;
import mvz2logic.level.LogicLevelExt;
import mvz2logic.level.LevelPositions;
import pvzengine.NamespaceID;
import pvzengine.buffs.BuffExt;
import pvzengine.callbacks.CallbackResult;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollisionHelper;
import tools.Ref;
import unity.Bounds;
import unity.Mathf;
import unity.Vector3;
import unity.UnityObject;
import mvz2logic.callbacks.LogicCallbacks.PostPointerActionParams;
import mvz2.gamecontent.effects.VanillaEffectID.VanillaEffectNames;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaEffectNames.breakoutBoard)
class BreakoutBoard extends EffectBehaviour
{
    // #region 公有方法
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddTrigger(LogicCallbacks.POST_POINTER_ACTION, PostPointerActionCallback);
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        entity.CollisionMaskFriendly = EntityCollisionHelper.MASK_PROJECTILE;
    }
    public override function Update(entity:Entity):Void
    {
        super.Update(entity);
        var level = entity.Level;

        var nextDisplacement = GetBoardNextDisplacement(entity);
        if (nextDisplacement.sqrMagnitude > 0)
        {
            entity.Position += nextDisplacement;
            SetBoardNextDisplacement(entity, Vector3.zero);
        }

        var pearlExists = true;
        var target = entity.Target;
        if (target != null && unity.UnityObject.exists(target))
        {
            var targetPosition = entity.Position + Vector3.right * 40;
            if (target.State == STATE_RETURN)
            {
                target.Velocity = (targetPosition - target.Position) * 0.5;
            }
            else if (target.State == STATE_IDLE)
            {
                target.Position = targetPosition;
                target.Velocity = Vector3.zero;
            }
        }
        else
        {
            if (!level.EntityExists(VanillaProjectileID.breakoutPearl))
            {
                pearlExists = false;
            }
        }

        bulletBuffer.resize(0);
        level.FindEntitiesNonAlloc(e -> e != entity.Target && entity.IsFriendly(e) && e.IsEntityOf(VanillaProjectileID.breakoutPearl), bulletBuffer);
        for (pearl in bulletBuffer)
        {
            ResolveCollision(entity, pearl, entity.Position - entity.PreviousPosition);
        }


        if (!pearlExists)
        {
            var countdown = GetRespawnCountdown(entity);
            countdown--;
            if (countdown <= 0)
            {
                countdown = MAX_RESPAWN_COUNTDOWN;
                SpawnPearl(entity);
                entity.SetModelProperty("Countdown", 0);
            }
            else
            {
                entity.SetModelProperty("Countdown", countdown);
            }
            SetRespawnCountdown(entity, countdown);
        }
        else
        {
            SetRespawnCountdown(entity, MAX_RESPAWN_COUNTDOWN);
            entity.SetModelProperty("Countdown", 0);
        }
        entity.SetAnimationBool("Upgraded", IsUpgraded(entity));
    }
    private function PostPointerActionCallback(param:PostPointerActionParams, result:CallbackResult):Void
    {
        var type = param.type;
        var phase = param.phase;
        var screenPosition = param.screenPos;
        var button = param.button;
        var delta = param.delta;
        var level = Global.Level.GetLevel();
        if (level == null)
            return;
        if (!level.IsGameRunning())
            return;
        boardsBuffer.resize(0);
        level.FindEntitiesNonAlloc(e -> e.IsEntityOf(VanillaEffectID.breakoutBoard), boardsBuffer);
        for (board in boardsBuffer)
        {
            var position:Vector3 = board.Position + GetBoardNextDisplacement(board);
            if (type == PointerTypes.TOUCH)
            {
                if (phase == PointerPhase.Press || phase == PointerPhase.Hold)
                {
                    var lastScreenPosition = screenPosition - delta;
                    var pointerPosition = level.ScreenToLawnPositionByY(screenPosition, 32);
                    var lastPointerPosition = level.ScreenToLawnPositionByY(lastScreenPosition, 32);
                    position += pointerPosition - lastPointerPosition;
                }
            }
            else if (type == PointerTypes.MOUSE)
            {
                var pointerPosition = level.ScreenToLawnPositionByY(screenPosition, 32);
                position = pointerPosition;
            }
            position.x = Mathf.Clamp(position.x, MIN_X, MAX_X);
            position.z = Mathf.Clamp(position.z, level.GetGridBottomZ(), level.GetGridTopZ());
            SetBoardNextDisplacement(board, position - board.Position);
        }
    }
    // #endregion
    public static function SpawnPearl(board:Entity):Null<Entity>
    {
        var level = board.Level;
        var pearl = level.Spawn(VanillaProjectileID.breakoutPearl, board.Position + Vector3.right * 40, board);
        if (pearl != null)
        {
            pearl.SetParent(board);
        }
        board.Target = pearl;
        board.State = STATE_IDLE;
        return pearl;
    }
    public static function ReturnPearl(board:Entity, pearl:Entity):Void
    {
        var level = board.Level;
        board.Target = pearl;
        pearl.SetParent(board);
        board.State = STATE_RETURN;
    }
    public static function FirePearl(board:Entity):Void
    {
        var pearl = board.Target;
        if (pearl != null && unity.UnityObject.exists(pearl))
        {
            board.Target = null;
            pearl.SetParent(null);
            pearl.Velocity = Vector3.right * PEARL_SPEED;
            board.State = STATE_FIRED;
        }
    }
    public static function IsUpgraded(board:Entity):Bool
    {
        return board.HasBuff(BreakoutBoardUpgradeBuff);
    }
    public static function Upgrade(board:Entity):Void
    {
        if (!IsUpgraded(board))
            board.AddBuff(BreakoutBoardUpgradeBuff);
    }
    public static function GetRespawnCountdown(board:Entity):Int
    {
        return board.GetBehaviourFieldNS(ID, PROP_RESPAWN_COUNTDOWN);
    }
    public static function SetRespawnCountdown(board:Entity, value:Int):Void
    {
        board.SetBehaviourFieldNS(ID, PROP_RESPAWN_COUNTDOWN, value);
    }
    public static function GetBoardNextDisplacement(board:Entity):Vector3
    {
        return board.GetBehaviourFieldNS(ID, PROP_NEXT_DISPLACEMENT);
    }
    public static function SetBoardNextDisplacement(board:Entity, value:Vector3):Void
    {
        board.SetBehaviourFieldNS(ID, PROP_NEXT_DISPLACEMENT, value);
    }
    /// <summary>
    /// 计算碰撞后移动矩形B的位置，防止穿过静止矩形A
    /// </summary>
    public static function ResolveCollision(board:Entity, bullet:Entity, boardDisplacement:Vector3):Void
    {
        var currentA = board.GetBounds();
        var currentB = bullet.GetBounds();
        var prevA = currentA;
        prevA.center -= boardDisplacement;

        var velocity = bullet.Velocity - boardDisplacement;

        var normal = new Ref<Vector3>(Vector3.zero);
        var collisionTime = SweptAABB(prevA, currentB, velocity, normal);

        if (collisionTime >= 1.0)
        {
            return;
        }
        var finalPosition = currentB.center + velocity * collisionTime + boardDisplacement;
        bullet.SetCenter(finalPosition);

        // 设置子弹移速
        var targetVelocity:Vector3 = bullet.Position - board.Position;
        if (targetVelocity.x * boardDisplacement.x > 0)
        {
            targetVelocity.x += boardDisplacement.x;
        }
        if (targetVelocity.z * boardDisplacement.z > 0)
        {
            targetVelocity.z += boardDisplacement.z;
        }
        targetVelocity.y = 0;
        bullet.Velocity = targetVelocity.normalized * PEARL_SPEED;

        board.PlaySound(VanillaSoundID.reflection);
    }
    /// <summary>
    /// 执行扫掠式AABB碰撞检测
    /// 参数：
    ///   b：移动矩形
    ///   velocity：B在本帧的移动量（速度向量，假设时间步长为1）
    ///   a：静止矩形
    ///   normal：碰撞法向量（输出）
    /// 返回值：碰撞发生时的时间因子 t（0~1之间），若返回1表示本帧无碰撞
    /// </summary>
    // PORT-NOTE: C# 的 out 参数改用 tools.Ref<Vector3>；
    // C# 使用 Vector3 的索引器（a.min[i] 等），Haxe 的 unity.Vector3 无索引器，改为逐分量数组。
    public static function SweptAABB(a:Bounds, b:Bounds, velocity:Vector3, normal:Ref<Vector3>):Float
    {
        normal.value = Vector3.zero;

        var velocityC = [velocity.x, velocity.y, velocity.z];
        var aMinC = [a.min.x, a.min.y, a.min.z];
        var aMaxC = [a.max.x, a.max.y, a.max.z];
        var bMinC = [b.min.x, b.min.y, b.min.z];
        var bMaxC = [b.max.x, b.max.y, b.max.z];

        var invEntryC = [0.0, 0.0, 0.0];
        var invExitC = [0.0, 0.0, 0.0];
        var entryC = [0.0, 0.0, 0.0];
        var exitC = [0.0, 0.0, 0.0];

        for (i in 0...3)
        {
            // 计算沿X和Y方向的反向进入距离与离开距离
            if (velocityC[i] > 0.0)
            {
                invEntryC[i] = aMinC[i] - bMaxC[i];
                invExitC[i] = aMaxC[i] - bMinC[i];
            }
            else
            {
                invEntryC[i] = aMaxC[i] - bMinC[i];
                invExitC[i] = aMinC[i] - bMaxC[i];
            }
            // 计算进入时间与离开时间
            if (velocityC[i] == 0.0)
            {
                entryC[i] = Math.NEGATIVE_INFINITY;
                exitC[i] = Math.POSITIVE_INFINITY;
            }
            else
            {
                entryC[i] = invEntryC[i] / velocityC[i];
                exitC[i] = invExitC[i] / velocityC[i];
            }
        }

        // 找到整体的进入时间与离开时间
        var entryTime = Mathf.Max(Mathf.Max(entryC[0], entryC[1]), entryC[2]);
        var exitTime = Mathf.Min(Mathf.Min(exitC[0], exitC[1]), exitC[2]);

        // 如果无碰撞，条件如下：
        // 1. 进入时间大于离开时间，说明两个矩形间存在分离
        // 2. 进入时间均为负，说明碰撞发生在上一帧
        // 3. 进入时间大于1，表示本帧内不会发生碰撞
        if (entryTime > exitTime || entryTime < 0 || entryTime > 1.0)
        {
            return 1.0;
        }

        // 根据哪个轴先碰撞确定碰撞法向量
        if (entryTime == entryC[0])
        {
            normal.value = (invEntryC[0] < 0.0) ? new Vector3(1, 0, 0) : new Vector3(-1, 0, 0);
        }
        else if (entryTime == entryC[1])
        {
            normal.value = (invEntryC[1] < 0.0) ? new Vector3(0, 1, 0) : new Vector3(0, -1, 0);
        }
        else
        {
            normal.value = (invEntryC[2] < 0.0) ? new Vector3(0, 0, 1) : new Vector3(0, 0, -1);
        }

        return entryTime;
    }

    public static var ID:NamespaceID = VanillaEffectID.breakoutBoard;
    public static var PROP_RESPAWN_COUNTDOWN:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("RespawnCountdown");
    public static var PROP_NEXT_DISPLACEMENT:VanillaEntityPropertyMeta<Vector3> = new VanillaEntityPropertyMeta<Vector3>("NextDisplacement");
    public static inline var MAX_RESPAWN_COUNTDOWN:Int = 90;
    public static inline var PEARL_SPEED:Float = 15;
    public static inline var STATE_IDLE:Int = VanillaEffectStates.IDLE;
    public static inline var STATE_RETURN:Int = VanillaEffectStates.BREAKOUT_BOARD_RETURN;
    public static inline var STATE_FIRED:Int = VanillaEffectStates.BREAKOUT_BOARD_FIRED;
    public static inline var MAX_X:Float = LevelPositions.RIGHT_BORDER - 40;
    public static inline var MIN_X:Float = LevelPositions.LEFT_BORDER + 40;
    private var boardsBuffer:Array<Entity> = [];
    private var bulletBuffer:Array<Entity> = [];
}

// Ported from: Assets/Scripts/Vanilla/GameContent/Entities/VanillaEntityExt.cs
package mvz2.vanilla.entities;

import mvz2.gamecontent.areas.VanillaAreaID;
import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.buffs.VanillaBuffID;
import mvz2.gamecontent.buffs.contraptions.FrankensteinShockedBuff;
import mvz2.gamecontent.buffs.entities.BurningBuff;
import mvz2.gamecontent.buffs.entities.ChangeGridBuff;
import mvz2.gamecontent.buffs.entities.ChangeLaneBuff;
import mvz2.gamecontent.buffs.entities.CharmBuff;
import mvz2.gamecontent.buffs.entities.PetrifiedBuff;
import mvz2.gamecontent.buffs.entities.TransfenserGlowingBuff;
import mvz2.gamecontent.buffs.entities.WitheredBuff;
import mvz2.gamecontent.buffs.enemies.EnemyWeaknessBuff;
import mvz2.gamecontent.buffs.enemies.GravelOnFaceBuff;
import mvz2.gamecontent.buffs.enemies.SlowBuff;
import mvz2.gamecontent.buffs.enemies.StunBuff;
import mvz2.gamecontent.contraptions.IHellfireIgniteBehaviour;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.pickups.VanillaPickupID;
import mvz2.gamecontent.seeds.EntitySeed;
import mvz2.vanilla.armors.VanillaArmorProps;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PreTakeDamageParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostTakeDamageParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PreBodyTakeDamageParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostBodyTakeDamageParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PreHealParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostHealParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PreApplyStatusEffectParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostApplyStatusEffectParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PreRemoveStatusEffectParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostRemoveStatusEffectParams;
import mvz2.vanilla.contraptions.IExplodeContraptionBehaviour;
import mvz2.vanilla.contraptions.VanillaContraptionExt;
import mvz2.vanilla.enemies.VanillaEnemyProps;
import mvz2.vanilla.effects.FragmentExt;
import mvz2.vanilla.level.VanillaAreaProps;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2.vanilla.shells.VanillaShellProps;
import mvz2logic.Global;
import mvz2logic.armors.LogicArmorSlots;
import mvz2logic.armors.LogicArmorProps;
import mvz2logic.contents.enemies.LogicEnemyExt;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.entities.LogicEnemyProps;
import mvz2logic.grids.LogicGridProps;
import mvz2logic.level.LogicLevelExt;
import pvzengine.EntityID;
import pvzengine.NamespaceID;
import pvzengine.armors.Armor;
import pvzengine.buffs.Buff;
import pvzengine.buffs.BuffDefinition;
import pvzengine.callbacks.CallbackResult;
import pvzengine.collisions.IEntityCollider;
import pvzengine.damages.ArmorDamageResult;
import pvzengine.damages.BodyDamageResult;
import pvzengine.damages.DamageEffectList;
import pvzengine.damages.DamageInput;
import pvzengine.damages.DamageOutput;
import pvzengine.damages.DamageResult;
import pvzengine.damages.DamageStates;
import pvzengine.damages.DeathInfo;
import pvzengine.damages.EntitySourceReference;
import pvzengine.damages.HealInput;
import pvzengine.damages.HealOutput;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityTypes;
import pvzengine.entities.SpawnParams;
import pvzengine.grids.LawnGrid;
import pvzengine.level.ILevelSourceReference;
import pvzengine.shells.ShellDefinition;
import pvzengine.base.ListUpdater;
import tools.EnumerableExt;
import tools.RandomGenerator;
import unity.Color;
import unity.Mathf;
import unity.Vector2;
import unity.Vector2Int;
import unity.Vector3;
import unity.UnityObject;

// PORT-NOTE: C# 扩展方法 → 以 Entity / DamageOutput / ShellDefinition 为首参的静态方法（PORTING.md §扩展方法）。
// PORT-NOTE: C# `using GridLayerData = System.Tuple<LawnGrid, NamespaceID>;` → 模块子类型 GridLayerData。
class VanillaEntityExt
{
    // #region 面朝方向
    public static function GetFacingX(entity:Entity):Int
    {
        return entity.IsFacingLeft() ? -1 : 1;
    }
    public static function GetFacingDirection(entity:Entity):Vector3
    {
        return entity.IsFacingLeft() ? Vector3.left : Vector3.right;
    }
    // #endregion

    // #region 血量
    public static function SetModelDamagePercent(entity:Entity):Void
    {
        SetModelDamagePercentWithHealth(entity, entity.Health, entity.GetMaxHealth());
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to SetModelDamagePercentWithHealth.
    public static function SetModelDamagePercentWithHealth(entity:Entity, health:Float, maxHealth:Float):Void
    {
        SetModelDamagePercentValue(entity, 1 - health / maxHealth);
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to SetModelDamagePercentValue.
    public static function SetModelDamagePercentValue(entity:Entity, percent:Float):Void
    {
        entity.SetModelProperty("DamagePercent", percent);
    }
    // #endregion

    // #region 伤害
    public static function TakeDamageNoSource(entity:Entity, amount:Float, effects:DamageEffectList, ?armorSlot:Null<NamespaceID>):DamageOutput
    {
        return TakeDamageSourced(entity, amount, effects, null, armorSlot);
    }
    public static function TakeDamage(entity:Entity, amount:Float, effects:DamageEffectList, source:Entity, ?armorSlot:Null<NamespaceID>):DamageOutput
    {
        return TakeDamageSourced(entity, amount, effects, new EntitySourceReference(source), armorSlot);
    }
    public static function TakeDamageSourced(entity:Entity, amount:Float, effects:DamageEffectList, source:Null<ILevelSourceReference>, ?armorSlot:Null<NamespaceID>):DamageOutput
    {
        return TakeDamageFromInput(new DamageInput(amount, effects, entity, source, armorSlot));
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload TakeDamage(DamageInput) to TakeDamageFromInput.
    public static function TakeDamageFromInput(input:DamageInput):DamageOutput
    {
        var output = new DamageOutput(input.Entity);
        if (input == null)
            return output;
        if (input.Entity.IsInvincible() || input.Entity.IsDead)
            return output;
        if (!PreTakeDamage(input, output))
            return output;
        if (!NamespaceID.IsValid(input.ShieldTarget))
        {
            var armor = GetMainArmor(input.Entity);
            // PORT-NOTE: C# 的 static Armor.Exists(Armor?) 因与实例方法 Exists() 同名，在 Haxe 中更名为 Armor.ExistsArmor。
            if (Armor.ExistsArmor(armor) && !LogicArmorProps.IsIgnoredArmor(armor) && !input.Effects.HasEffect(VanillaDamageEffects.IGNORE_ARMOR))
            {
                ArmoredTakeDamage(armor, input, output);
            }
            else
            {
                output.BodyResult = BodyTakeDamage(input);
            }
        }
        else
        {
            var armor = input.Entity.GetArmorAtSlot(input.ShieldTarget);
            if (Armor.ExistsArmor(armor) && !LogicArmorProps.IsIgnoredArmor(armor))
            {
                output.ShieldResult = mvz2.vanilla.armors.VanillaArmorExt.TakeDamage(armor, input);
                output.ShieldTarget = input.ShieldTarget;
            }
        }
        ApplyDamageSpecialEffects(output);
        if (output.HasDamageAmount())
        {
            PostTakeDamage(output);
        }
        return output;
    }


    static function PreTakeDamage(damageInfo:DamageInput, output:DamageOutput):Bool
    {
        var entity = damageInfo.Entity;
        if (entity == null)
            return false;
        var result = new CallbackResult(true);
        entity.Definition.PreTakeDamage(damageInfo, result);
        if (!result.IsBreakRequested)
        {
            var param = new PreTakeDamageParams(damageInfo, output);
            damageInfo.Entity.Level.Triggers.RunCallbackWithResultFiltered(VanillaLevelCallbacks.PRE_ENTITY_TAKE_DAMAGE, param, result, entity.Type);
        }
        return result.GetValue();
    }
    static function ApplyDamageSpecialEffects(output:DamageOutput):Void
    {
        var entity = output.Entity;
        if (entity == null)
            return;
        var param = new PostTakeDamageParams(output);
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.APPLY_DAMAGE_SPECIAL_EFFECTS, param, entity.Type);
    }
    static function PostTakeDamage(output:DamageOutput):Void
    {
        var entity = output.Entity;
        if (entity == null)
            return;
        entity.Definition.PostTakeDamage(output);
        var param = new PostTakeDamageParams(output);
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_ENTITY_TAKE_DAMAGE, param, entity.Type);
    }
    static function ArmoredTakeDamage(armor:Armor, info:DamageInput, result:DamageOutput):Void
    {
        var entity = info.Entity;
        var armorResult = mvz2.vanilla.armors.VanillaArmorExt.TakeDamage(armor, info);
        result.ArmorResult = armorResult;

        if (info.HasEffect(VanillaDamageEffects.DAMAGE_BOTH_ARMOR_AND_BODY))
        {
            result.BodyResult = BodyTakeDamage(info);
            return;
        }

        if (info.HasEffect(VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN) && !Armor.ExistsArmor(GetMainArmor(entity)))
        {
            var armorSpendAmount = armorResult != null ? armorResult.SpendAmount : 0;
            var overkillDamage = info.Amount - armorSpendAmount;
            if (overkillDamage > 0)
            {
                var overkillInfo = new DamageInput(overkillDamage, info.Effects, entity, info.Source);
                result.BodyResult = BodyTakeDamage(overkillInfo);
            }
            return;
        }
    }


    static function PreBodyTakeDamage(entity:Entity, input:DamageInput, result:BodyDamageResult):Int
    {
        var callbackResult = new CallbackResult(DamageStates.CONTINUE);
        if (!callbackResult.IsBreakRequested)
        {
            var param = new PreBodyTakeDamageParams(input, result);
            input.Entity.Level.Triggers.RunCallbackWithResultFiltered(VanillaLevelCallbacks.PRE_BODY_TAKE_DAMAGE, param, callbackResult, entity.Definition.GetID());
        }
        return callbackResult.GetValue();
    }
    static function PostBodyTakeDamage(entity:Entity, result:BodyDamageResult):Void
    {
        var param = new PostBodyTakeDamageParams(result);
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_BODY_TAKE_DAMAGE, param, entity.Definition.GetID());
    }
    static function BodyTakeDamage(info:DamageInput):Null<BodyDamageResult>
    {
        var entity = info.Entity;
        var shell = entity.GetShellDefinition();

        var result = new BodyDamageResult(info, shell);

        var damageState = PreBodyTakeDamage(entity, info, result);
        if (damageState == DamageStates.BREAK)
        {
            return null;
        }
        else if (damageState == DamageStates.RETURN)
        {
            return result;
        }

        if (shell != null)
            shell.EvaluateDamage(info);

        // Apply Damage.
        var amount = info.Amount;
        if (amount > 0)
        {
            var hpBefore = entity.Health;
            entity.Health -= amount;

            result.Amount = amount;
            result.SpendAmount = Mathf.Min(hpBefore, amount);
            result.Fatal = hpBefore > 0 && entity.Health <= 0;
        }
        else
        {
            result.Amount = amount;
            result.SpendAmount = amount;
        }

        if (entity.Health <= 0)
        {
            entity.Die(info.Effects, info.Source, result.GetValues());
        }
        if (result.HasDamageAmount())
        {
            PostBodyTakeDamage(entity, result);
        }

        return result;
    }
    // #endregion

    // #region 投射物
    public static function ModifyProjectileVelocity(entity:Entity, velocity:Vector3):Vector3
    {
        return velocity;
    }
    // #endregion

    // #region 光照
    public static function IsIlluminated(entity:Entity):Bool
    {
        return LogicLevelExt.IsIlluminated(entity.Level, entity);
    }
    // #endregion

    // #region 特效
    public static function UpdateShineRing(entity:Entity):Void
    {
        var lightSource = LogicEntityProps.IsLightSource(entity);
        if (!lightSource)
            return;
        var shineRingID:Null<EntityID> = entity.GetProperty(PROP_SHINE_RING);
        var shineRing = shineRingID != null ? shineRingID.GetEntity(entity.Level) : null;
        if (shineRing != null && unity.UnityObject.exists(shineRing))
            return;
        shineRing = entity.Level.FindFirstEntity(e -> e.IsEntityOf(VanillaEffectID.shineRing) && e.Parent == entity);
        if (shineRing == null || !unity.UnityObject.exists(shineRing))
        {
            // PORT-NOTE: C# `?.Let(e => {...})` → 显式判空块。
            shineRing = entity.Level.Spawn(VanillaEffectID.shineRing, entity.Position, entity);
            if (shineRing != null)
            {
                shineRing.SetParent(entity);
                entity.SetProperty(PROP_SHINE_RING, new EntityID(shineRing));
            }
        }
    }
    // #endregion

    // #region 爆炸和溅射
    public static function Explode(entity:Entity, center:Vector3, radius:Float, faction:Int, amount:Float, effects:DamageEffectList, ?filter:IEntityCollider->Bool):Array<DamageOutput>
    {
        return mvz2.vanilla.level.VanillaLevelExt.Explode(entity.Level, center, radius, faction, amount, effects, entity, filter);
    }
    public static function ExplodeAgainstFriendly(entity:Entity, center:Vector3, radius:Float, faction:Int, amount:Float, effects:DamageEffectList):Array<DamageOutput>
    {
        return mvz2.vanilla.level.VanillaLevelExt.ExplodeAgainstFriendly(entity.Level, center, radius, faction, amount, effects, entity);
    }
    public static function SplashDamage(entity:Entity, excludeCollider:IEntityCollider, center:Vector3, radius:Float, faction:Int, amount:Float, effects:DamageEffectList):Array<DamageOutput>
    {
        return mvz2.vanilla.level.VanillaLevelExt.SplashDamage(entity.Level, excludeCollider, center, radius, faction, amount, effects, entity);
    }
    // #endregion

    // #region 音效
    public static function PlayHitSound(damage:DamageOutput):Void
    {
        if (damage == null)
            return;
        var entity = damage.Entity;

        var shieldResult = damage.ShieldResult;
        if (shieldResult != null)
            PlayArmorHitSound(entity, shieldResult);

        var armorResult = damage.ArmorResult;
        if (armorResult != null)
            PlayArmorHitSound(entity, armorResult);

        var bodyResult = damage.BodyResult;
        if (bodyResult != null && !bodyResult.Effects.HasEffect(VanillaDamageEffects.MUTE))
        {
            var shell = bodyResult.ShellDefinition;
            var hitSound:Null<NamespaceID> = null;
            var specialSound = shell != null ? GetSpecialShellHitSound(shell, bodyResult, false) : null;
            if (specialSound != null && NamespaceID.IsValid(specialSound))
            {
                hitSound = specialSound;
            }
            else
            {
                var specificSound = LogicEntityProps.GetHitSound(entity);
                if (specificSound != null && NamespaceID.IsValid(specificSound))
                {
                    hitSound = specificSound;
                }
                else
                {
                    var shellSound = shell != null ? VanillaShellProps.GetHitSound(shell) : null;
                    if (shellSound != null && NamespaceID.IsValid(shellSound))
                    {
                        hitSound = shellSound;
                    }
                }
            }
            if (NamespaceID.IsValid(hitSound))
            {
                LogicEntityExt.PlaySound(entity, hitSound);
            }
        }
    }
    public static function PlayArmorHitSound(entity:Entity, result:ArmorDamageResult):Void
    {
        if (!result.Effects.HasEffect(VanillaDamageEffects.MUTE))
        {
            var armor = result.Armor;
            var shell = result.ShellDefinition;
            var hitSound:Null<NamespaceID> = null;
            var specialSound = shell != null ? GetSpecialShellHitSound(shell, result, true) : null;
            if (specialSound != null && NamespaceID.IsValid(specialSound))
            {
                hitSound = specialSound;
            }
            else
            {
                var specificSound = VanillaArmorProps.GetHitSound(armor);
                if (specificSound != null && NamespaceID.IsValid(specificSound))
                {
                    hitSound = specificSound;
                }
                else
                {
                    var shellSound = shell != null ? VanillaShellProps.GetHitSound(shell) : null;
                    if (shellSound != null && NamespaceID.IsValid(shellSound))
                    {
                        hitSound = shellSound;
                    }
                }
            }
            if (NamespaceID.IsValid(hitSound))
            {
                LogicEntityExt.PlaySound(entity, hitSound);
            }
        }
    }
    public static function GetSpecialShellHitSound(shell:ShellDefinition, result:DamageResult, isArmor:Bool):Null<NamespaceID>
    {
        var damageEffects = result.Effects;
        if (!isArmor)
        {
            if (damageEffects.HasEffect(VanillaDamageEffects.WHACK))
            {
                return VanillaSoundID.bonk;
            }
            else if (damageEffects.HasEffect(VanillaDamageEffects.FALL_DAMAGE))
            {
                return result.Amount > 100 ? VanillaSoundID.fallBig : VanillaSoundID.fallSmall;
            }
        }

        if (damageEffects.HasEffect(VanillaDamageEffects.FIRE) && !VanillaShellProps.BlocksFire(shell))
        {
            return VanillaSoundID.fire;
        }
        else if (damageEffects.HasEffect(VanillaDamageEffects.SLICE) && VanillaShellProps.IsSliceCritical(shell))
        {
            return VanillaSoundID.slice;
        }
        else if (damageEffects.HasEffect(VanillaDamageEffects.TINY))
        {
            return VanillaSoundID.smallHit;
        }
        else if (damageEffects.HasEffect(VanillaDamageEffects.LIGHTNING))
        {
            return VanillaSoundID.zap;
        }
        return null;
    }
    public static function EmitBlood(entity:Entity):Void
    {
        // PORT-NOTE: C# `?.Let(e => {...})` → 显式判空块。
        var e = entity.Level.Spawn(VanillaEffectID.bloodParticles, entity.GetCenter(), entity);
        if (e != null)
        {
            var bloodColor = VanillaEntityProps.GetBloodColor(entity);
            e.SetTint(bloodColor);
        }
    }
    // #endregion

    // #region 换行
    public static function RandomChangeAdjacentLane(entity:Entity, rng:RandomGenerator):Void
    {
        var lane = entity.GetLane();
        var laneDir:Int;
        if (lane <= 0)
        {
            laneDir = 1;
        }
        else if (lane >= entity.Level.GetMaxLaneCount() - 1)
        {
            laneDir = -1;
        }
        else
        {
            // PORT-NOTE: C# RandomGenerator.Next(int) 返回 int；移植层的 Next 返回 Dynamic，故显式取整。
            laneDir = Std.int(rng.Next(2)) * 2 - 1;
        }
        var targetLane = lane + laneDir;
        StartChangingLane(entity, targetLane);
    }
    public static function IsChangingLane(entity:Entity):Bool
    {
        // PORT-NOTE: C# 泛型方法 HasBuff<T>() 在 Haxe 无法书写类型实参，改为传入类对象（与既有调用点一致）。
        return entity.HasBuff(ChangeLaneBuff);
    }
    public static function StartChangingLane(entity:Entity, target:Int):Void
    {
        StartChangingLaneWithSpeed(entity, target, VanillaEntityProps.GetChangeLaneSpeed(entity));
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to StartChangingLaneWithSpeed.
    public static function StartChangingLaneWithSpeed(entity:Entity, target:Int, speed:Float):Void
    {
        var level = entity.Level;
        // PORT-NOTE: C# Math.Clamp(int,int,int) → Haxe Math.max/min + Std.int。
        target = Std.int(Math.max(0, Math.min(level.GetMaxLaneCount() - 1, target)));
        var source = entity.GetLane();
        var buff = entity.GetFirstBuff(ChangeLaneBuff);
        if (buff == null)
        {
            buff = entity.AddBuff(ChangeLaneBuff);
        }
        ChangeLaneBuff.Start(buff, target, source, speed);
    }
    public static function StopChangingLane(entity:Entity):Void
    {
        var buff = entity.GetFirstBuff(ChangeLaneBuff);
        if (buff == null)
        {
            return;
        }
        ChangeLaneBuff.Stop(buff);
    }
    // #endregion

    // #region 换格
    public static function StartChangingGrid(entity:Entity, column:Int, lane:Int, destroyConflict:Bool = true):Void
    {
        var buff = entity.GetFirstBuff(ChangeGridBuff);
        if (buff == null)
        {
            buff = entity.AddBuff(ChangeGridBuff);
        }
        var level = entity.Level;
        column = Std.int(Math.max(0, Math.min(level.GetMaxColumnCount() - 1, column)));
        lane = Std.int(Math.max(0, Math.min(level.GetMaxLaneCount() - 1, lane)));
        ChangeGridBuff.Start(buff, column, lane);

        if (destroyConflict)
        {
            var grid = level.GetGrid(column, lane);
            var layers = LogicEntityProps.GetGridLayersToTake(entity);
            if (grid != null && layers != null)
            {
                DestroyConflictGridEntitiesOnGrid(entity, grid, layers);
            }
        }
    }
    public static function StopChangingGrid(entity:Entity):Void
    {
        var buff = entity.GetFirstBuff(ChangeGridBuff);
        if (buff == null)
            return;
        ChangeGridBuff.Stop(buff);
    }
    // #endregion
    public static function CanEntityEnterHouse(entity:Entity):Bool
    {
        return entity.Type == EntityTypes.ENEMY && !entity.IsDead && !LogicEnemyProps.IsHarmless(entity) && entity.IsHostile(entity.Level.Option.LeftFaction);
    }
    public static function GetEntitySeedDefinition(entity:Entity):Null<EntitySeed>
    {
        var game = Global.Game;
        var seedDef = game.GetSeedDefinition(entity.GetDefinitionID());
        return Std.isOfType(seedDef, EntitySeed) ? (cast seedDef : EntitySeed) : null;
    }
    public static function Stun(entity:Entity, timeout:Int):Void
    {
        if (entity == null)
            return;
        var buff = entity.GetFirstBuff(StunBuff);
        if (buff == null)
        {
            buff = entity.AddBuff(StunBuff);
        }
        StunBuff.SetStunTime(buff, timeout);
    }

    // #region 阻挡火焰
    public static function WillDamageBlockFire(damage:DamageOutput):Bool
    {
        if (damage == null)
            return false;
        for (result in damage.GetAllResults())
        {
            if (result == null)
                continue;
            var shell = result.ShellDefinition;
            if (shell == null)
                continue;
            if (VanillaShellProps.BlocksFire(shell))
            {
                return true;
            }
        }
        return false;
    }
    // #endregion


    // #region 网格
    public static function UpdateTakenGrids(entity:Entity):Void
    {
        targetGridLayerDataBuffer = [];
        takenGridLayerDataBuffer = [];
        GetTargetGridLayersToTakeNonAlloc(entity, targetGridLayerDataBuffer);
        GetCurrentGridLayersToTakeNonAlloc(entity, takenGridLayerDataBuffer);
        entityGridUpdater.Update(targetGridLayerDataBuffer, takenGridLayerDataBuffer, g -> entity.TakeGrid(g.Item1, g.Item2), g -> entity.ReleaseGrid(g.Item1, g.Item2));
    }
    public static function DestroyConflictGridEntitiesOnLand(entity:Entity):Void
    {
        entity.AddBuff(VanillaBuffID.Entity.destroyConflictGridEntitiesOnLand);
    }
    public static function DestroyConflictGridEntities(entity:Entity):Void
    {
        UpdateTakenGrids(entity);

        var grids = LogicEntityProps.GetGridsToTake(entity);
        for (grid in grids)
        {
            if (grid == null)
                continue;
            var takenLayers = LogicEntityProps.GetGridLayersToTake(entity);
            if (takenLayers != null)
            {
                DestroyConflictGridEntitiesOnGrid(entity, grid, takenLayers);
            }
        }
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to DestroyConflictGridEntitiesOnGrid.
    public static function DestroyConflictGridEntitiesOnGrid(entity:Entity, grid:LawnGrid, layers:Array<NamespaceID>):Void
    {
        // 找到目标地格上冲突的实体。
        var conflictEntities:Map<Entity, Bool> = new Map();
        for (layer in layers)
        {
            var layerEntities = grid.GetLayerEntities(layer);
            for (ent in layerEntities)
            {
                if (ent == entity)
                    continue;
                conflictEntities.set(ent, true);
            }
        }
        // 如果目标地格有冲突的实体，秒杀冲突的实体。
        for (conflict in conflictEntities.keys())
        {
            conflict.Die(entity);
        }
    }
    static function GetTargetGridLayersToTakeNonAlloc(entity:Entity, buffer:Array<GridLayerData>):Void
    {
        if (!entity.ExistsAndAlive())
            return;

        var grids = LogicEntityProps.GetGridsToTake(entity);
        if (grids == null)
            return;

        var layers = LogicEntityProps.GetGridLayersToTake(entity);
        if (layers == null)
            return;

        for (grid in grids)
        {
            if (grid == null)
                continue;
            if (!CanTakeGrid(entity, grid))
                continue;
            for (layer in layers)
            {
                buffer.push(new GridLayerData(grid, layer));
            }
        }
    }
    static function GetCurrentGridLayersToTakeNonAlloc(entity:Entity, buffer:Array<GridLayerData>):Void
    {
        takenGridBuffer = [];
        entity.GetTakenGridsNonAlloc(takenGridBuffer);

        for (grid in takenGridBuffer)
        {
            takenGridLayersBuffer = [];
            entity.GetTakingGridLayersNonAlloc(grid, takenGridLayersBuffer);

            for (layer in takenGridLayersBuffer)
            {
                buffer.push(new GridLayerData(grid, layer));
            }
        }
    }
    static function CanTakeGrid(entity:Entity, grid:LawnGrid):Bool
    {
        if (grid == null)
            return false;
        if (!entity.ExistsAndAlive())
            return false;
        if (entity.GetRelativeY() > leaveGridHeight)
            return false;
        return true;
    }
    inline static var leaveGridHeight:Float = 64;
    static var entityGridUpdater:ListUpdater<GridLayerData> = new ListUpdater<GridLayerData>();
    static var targetGridLayerDataBuffer:Array<GridLayerData> = [];
    static var takenGridLayerDataBuffer:Array<GridLayerData> = [];
    static var takenGridBuffer:Array<LawnGrid> = [];
    static var takenGridLayersBuffer:Array<NamespaceID> = [];
    // #endregion


    // #region 治疗
    public static function HealEffects(entity:Entity, amount:Float, source:Null<Entity>):Null<HealOutput>
    {
        return HealEffectsSourced(entity, amount, source == null ? null : new EntitySourceReference(source));
    }
    public static function HealEffectsSourced(entity:Entity, amount:Float, source:Null<ILevelSourceReference>):Null<HealOutput>
    {
        var result = HealSourced(entity, amount, source);
        if (result == null)
            return null;
        if (result.RealAmount >= 0)
        {
            FragmentExt.AddTickHealing(entity, result.RealAmount);
        }
        return result;
    }

    public static function Heal(entity:Entity, amount:Float, source:Null<Entity>):Null<HealOutput>
    {
        return HealSourced(entity, amount, source == null ? null : new EntitySourceReference(source));
    }
    public static function HealSourced(entity:Entity, amount:Float, source:Null<ILevelSourceReference>):Null<HealOutput>
    {
        return HealFromInput(new HealInput(amount, entity, source));
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload Heal(HealInput) to HealFromInput.
    public static function HealFromInput(info:HealInput):Null<HealOutput>
    {
        if (info.Entity.IsDead)
            return null;
        if (!PreHeal(info))
            return null;
        if (info.Amount <= 0)
            return null;
        var result:HealOutput;
        if (info.ToArmor && info.Armor != null)
        {
            result = ArmorHeal(info.Armor, info);
        }
        else
        {
            result = BodyHeal(info);
        }
        PostHeal(result);
        return result;
    }
    static function PreHeal(info:HealInput):Bool
    {
        var entity = info.Entity;
        if (entity == null)
            return false;
        var result = new CallbackResult(true);
        var param = new PreHealParams();
        param.input = info;
        entity.Level.Triggers.RunCallbackWithResult(VanillaLevelCallbacks.PRE_ENTITY_HEAL, param, result);
        return result.GetValue();
    }
    static function PostHeal(output:HealOutput):Void
    {
        var entity = output.Entity;
        if (entity == null)
            return;
        var param = new PostHealParams();
        param.output = output;
        entity.Level.Triggers.RunCallback(VanillaLevelCallbacks.POST_ENTITY_HEAL, param);
    }
    static function ArmorHeal(armor:Armor, info:HealInput):HealOutput
    {
        // Apply Healing.
        var hpBefore = armor.Health;
        var maxHealth = armor.GetMaxHealth();
        if (armor.Health < maxHealth)
        {
            armor.Health = Mathf.Min(armor.Health + info.Amount, maxHealth);
        }

        var output = new HealOutput(armor.Owner, info.Source);
        output.OriginalAmount = info.OriginalAmount;
        output.Amount = info.Amount;
        output.RealAmount = armor.Health - hpBefore;
        output.Armor = armor;
        output.ToArmor = true;
        return output;
    }
    static function BodyHeal(info:HealInput):HealOutput
    {
        var entity = info.Entity;

        // Apply Healing.
        var hpBefore = entity.Health;
        var maxHealth = entity.GetMaxHealth();
        if (entity.Health < maxHealth)
        {
            entity.Health = Mathf.Min(entity.Health + info.Amount, maxHealth);
        }

        var output = new HealOutput(entity, info.Source);
        output.OriginalAmount = info.OriginalAmount;
        output.Amount = info.Amount;
        output.RealAmount = entity.Health - hpBefore;
        return output;
    }
    // #endregion

    // #region 沉没
    public static inline var SPLASH_SIZE_UNIT:Int = 110592; //48^3
    public static function IsOnWater(entity:Entity):Bool
    {
        var grid = entity.GetGrid();
        return grid != null && LogicGridProps.IsWater(grid);
    }
    public static function IsInWater(entity:Entity):Bool
    {
        return IsOnWater(entity) && entity.IsOnGround;
    }
    public static function IsAboveCloud(entity:Entity):Bool
    {
        var grid = entity.GetGrid();
        if (grid != null && LogicGridProps.IsCloud(grid))
            return true;
        if (entity.Level.AreaID == VanillaAreaID.ship)
        {
            var column = entity.GetColumn();
            var lane = entity.GetLane();
            if (column >= 0 && column < entity.Level.GetMaxColumnCount() && (lane < 0 || lane >= entity.Level.GetMaxLaneCount()))
            {
                return true;
            }
        }
        return false;
    }
    public static function IsInCloud(entity:Entity):Bool
    {
        return IsAboveCloud(entity) && entity.IsOnGround;
    }
    public static function IsAboveLand(entity:Entity):Bool
    {
        var grid = entity.GetGrid();
        return grid == null || (!LogicGridProps.IsWater(grid) && !LogicGridProps.IsCloud(grid));
    }
    public static function PlaySplashEffect(entity:Entity):Void
    {
        var size = entity.GetScaledSize();
        var scale = Mathf.Clamp(size.x * size.y * size.z / SPLASH_SIZE_UNIT, 1, 5);
        PlaySplashEffectWithScale(entity, scale * Vector3.one);
    }
    // PORT-NOTE: Haxe has no method overloading; PlaySplashEffect 的 4 个重载拆分为带后缀的方法。
    public static function PlaySplashEffectWithScale(entity:Entity, scale:Vector3):Void
    {
        PlaySplashEffectWithScaleAndColor(entity, scale, VanillaAreaProps.GetWaterColor(entity.Level));
    }
    public static function PlayAirSplashEffect(entity:Entity):Void
    {
        var size = entity.GetScaledSize();
        var scale = Mathf.Clamp(size.x * size.y * size.z / SPLASH_SIZE_UNIT, 1, 5);
        PlayAirSplashEffectWithScale(entity, scale * Vector3.one);
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to PlayAirSplashEffectWithScale.
    public static function PlayAirSplashEffectWithScale(entity:Entity, scale:Vector3):Void
    {
        PlaySplashEffectWithScaleAndColor(entity, scale, new Color(1, 1, 1, 0.5));
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to PlaySplashEffectWithScaleAndColor.
    public static function PlaySplashEffectWithScaleAndColor(entity:Entity, scale:Vector3, color:Color):Void
    {
        var level = entity.Level;
        var pos = entity.Position;
        pos.y = entity.GetGroundY();
        // PORT-NOTE: C# `?.Let(e => {...})` → 显式判空块。
        var e = level.Spawn(VanillaEffectID.splashParticles, pos, entity);
        if (e != null)
        {
            e.SetTint(color);
            e.SetDisplayScale(scale);
        }
    }

    public static function PlayAirSplashSound(entity:Entity):Void
    {
        var sound = VanillaSoundID.cloth;
        LogicEntityExt.PlaySound(entity, sound);
    }
    public static function PlaySplashSound(entity:Entity):Void
    {
        var level = entity.Level;
        var size = entity.GetScaledSize();
        var sound = VanillaSoundID.splash;
        if (entity.Type == EntityTypes.ENEMY)
        {
            sound = VanillaSoundID.water;
        }
        if (size.x * size.y * size.z / SPLASH_SIZE_UNIT > 1)
        {
            sound = VanillaSoundID.splashBig;
        }
        LogicEntityExt.PlaySound(entity, sound);
    }
    // #endregion

    // #region 护甲
    public static function GetMainArmor(entity:Entity):Null<Armor>
    {
        return entity.GetArmorAtSlot(LogicArmorSlots.main);
    }
    public static function EquipMainArmor(entity:Entity, id:NamespaceID):Armor
    {
        return entity.EquipArmorTo(LogicArmorSlots.main, id);
    }
    // #endregion

    // #region 寻路
    public static function MoveOrthogonally(entity:Entity, targetGridIndex:Int, speed:Float):Bool
    {
        var level = entity.Level;
        var targetGridPosition = level.GetEntityGridPositionByIndex(targetGridIndex);
        var targetGridDistance = targetGridPosition - entity.Position;
        var distance2D = new Vector2(targetGridDistance.x, targetGridDistance.z);

        var position = entity.Position;
        if (distance2D.magnitude <= speed)
        {
            // 更新目标。
            position.x = targetGridPosition.x;
            position.z = targetGridPosition.z;
            entity.Position = position;
            return true;
        }
        else
        {
            var velocity = distance2D.normalized * speed;
            position.x += velocity.x;
            position.z += velocity.y;
            entity.Position = position;
            return false;
        }
    }
    public static function GetChaseTargetGrid(entity:Entity, target:Null<Entity>, gridValidator:Entity->Vector2Int->Bool):Null<LawnGrid>
    {
        var level = entity.Level;
        var lane = entity.GetLane();
        var column = entity.GetColumn();

        var currentGrid = new Vector2Int(column, lane);
        var newTargetGridOffset = Vector2Int.zero;
        // PORT-NOTE: C# LINQ Where/OrderBy/ThenBy/FirstOrDefault → Lambda.filter + Array.sort。
        var possibleDirections = Lambda.array(Lambda.filter(adjacentGridOffsets, o -> gridValidator(entity, AddGridOffset(currentGrid, o))));
        if (possibleDirections.length <= 0)
            return entity.GetGrid();

        if (target.ExistsAndAlive() && possibleDirections.length > 0)
        {
            var targetLane = target.GetLane();
            var currentDistanceY = currentGrid.y - targetLane;
            var currentDistanceX = entity.Position.x - target.Position.x;
            possibleDirections.sort(function(a, b)
            {
                var ka = Mathf.Abs(currentDistanceY + a.y) - Mathf.Abs(currentDistanceY);
                var kb = Mathf.Abs(currentDistanceY + b.y) - Mathf.Abs(currentDistanceY);
                if (ka != kb) return ka < kb ? -1 : 1;
                var ja = Mathf.Abs(currentDistanceX + a.x * level.GetGridWidth()) - Mathf.Abs(currentDistanceX);
                var jb = Mathf.Abs(currentDistanceX + b.x * level.GetGridWidth()) - Mathf.Abs(currentDistanceX);
                if (ja != jb) return ja < jb ? -1 : 1;
                return 0;
            });
            newTargetGridOffset = possibleDirections[0];
        }
        else
        {
            var rng = entity.RNG;
            // PORT-NOTE: C# Tools 扩展方法 Random(this IEnumerable<T>, RandomGenerator) → EnumerableExt.Random(数组, rng)。
            newTargetGridOffset = EnumerableExt.Random(possibleDirections, rng);
        }
        var targetGrid = level.GetGrid(AddGridOffset(currentGrid, newTargetGridOffset));
        return targetGrid != null ? targetGrid : entity.GetGrid();
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to GetChaseTargetGridDefaultValidator.
    public static function GetChaseTargetGridDefaultValidator(entity:Entity, target:Null<Entity>):Null<LawnGrid>
    {
        return GetChaseTargetGrid(entity, target, (e, p) -> LogicLevelExt.ValidateGridOutOfBounds(e.Level, p));
    }
    public static function GetEvadeTargetGrid(entity:Entity, target:Entity, gridValidator:Entity->Vector2Int->Bool):Null<LawnGrid>
    {
        var level = entity.Level;
        var lane = entity.GetLane();
        var column = entity.GetColumn();

        var currentGrid = new Vector2Int(column, lane);
        var newTargetGridOffset = Vector2Int.zero;
        var possibleDirections = Lambda.array(Lambda.filter(adjacentGridOffsets, o -> gridValidator(entity, AddGridOffset(currentGrid, o))));
        if (possibleDirections.length <= 0)
            return entity.GetGrid();

        if (target.ExistsAndAlive() && possibleDirections.length > 0)
        {
            var targetLane = target.GetLane();
            var currentDistanceY = currentGrid.y - targetLane;
            var currentDistanceX = entity.Position.x - target.Position.x;
            possibleDirections.sort(function(a, b)
            {
                var ka = Mathf.Abs(currentDistanceY + a.y) - Mathf.Abs(currentDistanceY);
                var kb = Mathf.Abs(currentDistanceY + b.y) - Mathf.Abs(currentDistanceY);
                if (ka != kb) return ka > kb ? -1 : 1;
                var ja = Mathf.Abs(currentDistanceX + a.x * level.GetGridWidth()) - Mathf.Abs(currentDistanceX);
                var jb = Mathf.Abs(currentDistanceX + b.x * level.GetGridWidth()) - Mathf.Abs(currentDistanceX);
                if (ja != jb) return ja > jb ? -1 : 1;
                return 0;
            });
            newTargetGridOffset = possibleDirections[0];
        }
        else
        {
            var rng = entity.RNG;
            // PORT-NOTE: C# Tools 扩展方法 Random(this IEnumerable<T>, RandomGenerator) → EnumerableExt.Random(数组, rng)。
            newTargetGridOffset = EnumerableExt.Random(possibleDirections, rng);
        }
        var targetGrid = level.GetGrid(AddGridOffset(currentGrid, newTargetGridOffset));
        return targetGrid != null ? targetGrid : entity.GetGrid();
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to GetEvadeTargetGridDefaultValidator.
    public static function GetEvadeTargetGridDefaultValidator(entity:Entity, target:Entity):Null<LawnGrid>
    {
        return GetEvadeTargetGrid(entity, target, (e, p) -> LogicLevelExt.ValidateGridOutOfBounds(e.Level, p));
    }
    // PORT-NOTE: unity.Vector2Int shim 未提供 C# 的 operator+(Vector2Int, Vector2Int) 与
    //   up/down/left/right 静态属性，故在本文件内以等价形式表达（结果均为新实例，语义与 struct 一致）。
    private static inline function AddGridOffset(a:Vector2Int, b:Vector2Int):Vector2Int
    {
        return new Vector2Int(a.x + b.x, a.y + b.y);
    }
    public static var adjacentGridOffsets:Array<Vector2Int> = [
        new Vector2Int(0, -1),
        new Vector2Int(0, 1),
        new Vector2Int(1, 0),
        new Vector2Int(-1, 0)
    ];
    // #endregion

    // #region 蓝图掉落物
    public static function IsBlueprintPickup(entity:Entity):Bool
    {
        return entity != null && entity.IsEntityOf(VanillaPickupID.blueprintPickup);
    }
    // #endregion

    // #region 状态效果
    public static function PreApplyStatusEffect(entity:Entity, buff:BuffDefinition, source:Null<ILevelSourceReference>):Bool
    {
        var param = new PreApplyStatusEffectParams(entity, buff, source);
        var result = new CallbackResult(true);
        entity.Level.Triggers.RunCallbackWithResultFiltered(VanillaLevelCallbacks.PRE_APPLY_STATUS_EFFECT, param, result, buff.GetID());
        return result.GetValue();
    }
    public static function PostApplyStatusEffect(entity:Entity, buff:Buff, source:Null<ILevelSourceReference>):Void
    {
        var param = new PostApplyStatusEffectParams(entity, buff, source);
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_APPLY_STATUS_EFFECT, param, buff.Definition.GetID());
    }
    public static function PreRemoveStatusEffect(entity:Entity, definition:BuffDefinition, source:Null<ILevelSourceReference>):Bool
    {
        var param = new PreRemoveStatusEffectParams(entity, definition, source);
        var result = new CallbackResult(true);
        entity.Level.Triggers.RunCallbackWithResultFiltered(VanillaLevelCallbacks.PRE_REMOVE_STATUS_EFFECT, param, result, definition.GetID());
        return result.GetValue();
    }
    public static function PostRemoveStatusEffect(entity:Entity, definition:BuffDefinition, source:Null<ILevelSourceReference>):Void
    {
        var param = new PostRemoveStatusEffectParams(entity, definition, source);
        entity.Level.Triggers.RunCallbackFiltered(VanillaLevelCallbacks.POST_REMOVE_STATUS_EFFECT, param, definition.GetID());
    }
    public static function InflictBurning(entity:Entity, time:Int, source:Null<ILevelSourceReference>, damage:Float = 20.0):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.burning);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff:Null<Buff> = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        BurningBuff.MaxTime(buff, time);
        BurningBuff.MaxDamage(buff, damage);
        PostApplyStatusEffect(entity, buff, source);
    }
    public static function InflictWither(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.withered);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff:Null<Buff> = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        buff.SetProperty(WitheredBuff.PROP_TIMEOUT, time);
        PostApplyStatusEffect(entity, buff, source);
    }

    public static function InflictWeakness(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Enemy.enemyWeakness);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff:Null<Buff> = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        buff.SetProperty(EnemyWeaknessBuff.PROP_TIMEOUT, time);
        PostApplyStatusEffect(entity, buff, source);
    }
    public static function InflictGlowing(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.transfenserGlowing);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        // PORT-NOTE: C# LINQ FirstOrDefault → Lambda.find。
        var buff:Null<Buff> = Lambda.find(entity.GetBuffs(buffDefinition), e -> !e.IsFromAura);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        TransfenserGlowingBuff.MaxTime(buff, time);
        PostApplyStatusEffect(entity, buff, source);
    }

    public static function InflictGravel(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Enemy.gravelOnFace);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff:Null<Buff> = Lambda.find(entity.GetBuffs(buffDefinition), e -> !e.IsFromAura);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        GravelOnFaceBuff.MaxTime(buff, time);
        PostApplyStatusEffect(entity, buff, source);
    }
    public static function InflictPetrified(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.petrified);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff:Null<Buff> = Lambda.find(entity.GetBuffs(buffDefinition), e -> !e.IsFromAura);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        PetrifiedBuff.MaxTime(buff, time);
        PostApplyStatusEffect(entity, buff, source);
    }


    public static function ShortCircuit(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Contraption.frankensteinShocked);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        buff.SetProperty(FrankensteinShockedBuff.PROP_TIMEOUT, time);
        PostApplyStatusEffect(entity, buff, source);
    }

    public static function InflictSlow(entity:Entity, time:Int, source:Null<ILevelSourceReference>):Void
    {
        if (VanillaEnemyProps.ImmuneSlowing(entity))
            return;
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Enemy.slow);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            LogicEntityExt.PlaySound(entity, VanillaSoundID.freeze);
            buff = entity.AddBuff(buffDefinition);
        }
        SlowBuff.SetTimeout(buff, time);
        PostApplyStatusEffect(entity, buff, source);
    }

    public static function Unfreeze(entity:Entity, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Enemy.slow);
        if (buffDefinition == null || !PreRemoveStatusEffect(entity, buffDefinition, source))
            return;
        entity.RemoveBuffs(buffDefinition);
        PostRemoveStatusEffect(entity, buffDefinition, source);
    }
    // #region 魅惑
    public static function CharmPermanent(entity:Entity, faction:Int, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.charm);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        CharmBuff.SetPermanent(buff, faction);
        buff.Update();
        PostApplyStatusEffect(entity, buff, source);
    }

    public static function CharmWithController(entity:Entity, controller:Entity, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.charm);
        if (buffDefinition == null || !PreApplyStatusEffect(entity, buffDefinition, source))
            return;
        var buff = entity.GetFirstBuff(buffDefinition);
        if (buff == null)
        {
            buff = entity.AddBuff(buffDefinition);
        }
        CharmBuff.SetController(buff, controller);
        buff.Update();
        PostApplyStatusEffect(entity, buff, source);
    }
    public static function RemoveCharm(entity:Entity, source:Null<ILevelSourceReference>):Void
    {
        var buffDefinition = entity.Level.Content.GetBuffDefinition(VanillaBuffID.Entity.charm);
        if (buffDefinition == null || !PreRemoveStatusEffect(entity, buffDefinition, source))
            return;
        entity.RemoveBuffs(buffDefinition);
        PostRemoveStatusEffect(entity, buffDefinition, source);
    }
    public static function IsCharmed(entity:Entity):Bool
    {
        return entity.HasBuff(CharmBuff);
    }
    // #endregion

    // #endregion

    // #region 强力冲击
    public static function ApplyStrongImpact(target:Entity):Void
    {
        var passenger = LogicEnemyExt.GetRideablePassenger(target);
        if (passenger != null)
        {
            Stun(passenger, 90);
            LogicEnemyExt.GetOffHorse(target);
        }
    }
    // #endregion

    // #region 移除性死亡
    public static function RemoveDie(entity:Entity):Void
    {
        RemoveDieWithSource(entity, cast null);
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to RemoveDieWithSource.
    public static function RemoveDieWithSource(entity:Entity, source:Null<Entity>):Void
    {
        RemoveDieWithSourceRef(entity, source != null ? new EntitySourceReference(source) : null);
    }
    // PORT-NOTE: Haxe has no method overloading; renamed overload to RemoveDieWithSourceRef.
    public static function RemoveDieWithSourceRef(entity:Entity, source:Null<ILevelSourceReference>):Void
    {
        var effects = new DamageEffectList(VanillaDamageEffects.REMOVE_ON_DEATH, VanillaDamageEffects.NO_DEATH_EFFECTS);
        entity.Die(effects, source);
    }
    public static function DieOrRemove(entity:Entity, deathEffects:DamageEffectList, source:Null<Entity>):Void
    {
        if (entity.IsDead)
        {
            entity.Remove();
        }
        else
        {
            entity.Die(deathEffects, source);
        }
    }
    // #endregion

    // #region 获取指针目标
    public static function FindPointerTargetEntity(entity:Entity, pointerPositionY:Float, screenPosition:Vector2, predicate:Entity->Bool):Entity
    {
        var protector = entity;
        var protectTargets = VanillaContraptionExt.GetProtectingTargets(entity);
        if (protectTargets != null && protectTargets.length > 0)
        {
            var gridPosition = LogicLevelExt.ScreenToLawnPositionByRelativeY(entity.Level, screenPosition, 0);
            var column = entity.Level.GetColumn(gridPosition.x);
            var lane = entity.Level.GetLane(gridPosition.z);

            // 存在保护中的目标。
            var canUseOnProtector = predicate(protector);
            // PORT-NOTE: C# LINQ OrderBy/ThenBy/FirstOrDefault → Array.sort + Lambda.find。
            var orderedTargets = Lambda.array(protectTargets);
            orderedTargets.sort(function(a, b)
            {
                var ka = Mathf.Abs(a.GetColumn() - column);
                var kb = Mathf.Abs(b.GetColumn() - column);
                if (ka != kb) return ka < kb ? -1 : 1;
                var ja = Mathf.Abs(a.GetLane() - lane);
                var jb = Mathf.Abs(b.GetLane() - lane);
                if (ja != jb) return ja < jb ? -1 : 1;
                return 0;
            });
            var firstValidMainTarget = Lambda.find(orderedTargets, t -> predicate(t));

            // 主要层器械可以使用。
            // 保护层器械不能使用，或者指向保护层器械上方。
            if (firstValidMainTarget != null && (!canUseOnProtector || pointerPositionY >= 0.5))
            {
                return firstValidMainTarget;
            }
            // 内部器械不能使用，或者可以给保护层器械使用并且光标位置位于下方。
        }
        // 没有保护中的目标：
        // 可能是没有保护的器械，也可能是不能保护器械。
        // 直接选中当前器械。
        return entity;
    }
    // #endregion

    // #region 被尖刺摧毁
    public static function TryDestroyBySpikes(entity:Entity, source:Entity):Bool
    {
        var destroyed = false;
        var definition = entity.Definition;
        var count = definition.GetBehaviourCount();
        for (i in 0...count)
        {
            var behaviour = definition.GetBehaviourAt(i);
            if (!Std.isOfType(behaviour, IDestroyBySpikesEntityBehaviour))
                continue;
            var entityBehaviour:IDestroyBySpikesEntityBehaviour = cast behaviour;
            if (entityBehaviour.CanBeDestroyedBySpikes(entity, source))
            {
                entityBehaviour.DestroyBySpikes(entity, source);
                destroyed = true;
            }
        }
        return destroyed;
    }
    // #endregion

    // #region 是否触发死亡效果
    public static function ShouldTriggerDeathEffects(entity:Entity, deathInfo:DeathInfo):Bool
    {
        return !deathInfo.HasEffect(VanillaDamageEffects.NO_DEATH_EFFECTS) && !LogicEntityProps.HasNoDeathEffects(entity);
    }
    public static function WillRemoveOnDeath(entity:Entity, deathInfo:DeathInfo):Bool
    {
        return deathInfo.HasEffect(VanillaDamageEffects.REMOVE_ON_DEATH) || LogicEntityProps.IsRemoveOnDeath(entity);
    }
    // #endregion

    // #region 爆炸
    public static function BehaviourExplode(entity:Entity, range:Float, damage:Float):Void
    {
        for (behaviour in entity.Definition.GetBehaviours())
        {
            if (!Std.isOfType(behaviour, IExplodeContraptionBehaviour))
                continue;
            var explodeBehaviour:IExplodeContraptionBehaviour = cast behaviour;
            explodeBehaviour.Explode(entity, range, damage);
        }
    }
    // #endregion

    // #region 地狱火
    public static function HellfireIgnite(target:Entity, hellfire:Entity, cursed:Bool):Void
    {
        var rawBehaviour = target.Definition != null ? target.Definition.GetBehaviour() : null;
        var behaviour:Null<IHellfireIgniteBehaviour> = Std.isOfType(rawBehaviour, IHellfireIgniteBehaviour) ? (cast rawBehaviour : IHellfireIgniteBehaviour) : null;
        if (behaviour == null)
            return;
        behaviour.Ignite(target, hellfire, cursed);
    }
    // #endregion

    public static function GetRealGroundLimitY(entity:Entity):Float
    {
        return entity.GetGroundLimitOffset() + entity.GetGroundY();
    }
    public static function GetSpawnParams(entity:Entity):SpawnParams
    {
        var param = new SpawnParams();
        param.SetProperty(EngineEntityProps.FACTION, entity.GetFaction());
        return param;
    }
    public static function SpawnWithParams(entity:Entity, id:NamespaceID, pos:Vector3):Null<Entity>
    {
        var param = GetSpawnParams(entity);
        return entity.Spawn(id, pos, param);
    }
    public static function SpawnUnlockArtifactPickup(entity:Entity, areaID:NamespaceID, unlockID:NamespaceID, artifactID:NamespaceID, position:Vector3):Null<Entity>
    {
        return mvz2.vanilla.level.VanillaLevelExt.SpawnUnlockArtifactPickup(entity.Level, areaID, unlockID, artifactID, position, entity);
    }

    static inline var PROP_REGION:String = "entities";
    @:entityPropertyRegistry("entities")
    public static var PROP_SHINE_RING:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("LightShineRing");
}

// PORT-NOTE: C# `using GridLayerData = System.Tuple<LawnGrid, NamespaceID>;` → Haxe 模块子类型。
class GridLayerData
{
    public var Item1:LawnGrid;
    public var Item2:NamespaceID;
    public function new(item1:LawnGrid, item2:NamespaceID)
    {
        this.Item1 = item1;
        this.Item2 = item2;
    }
}

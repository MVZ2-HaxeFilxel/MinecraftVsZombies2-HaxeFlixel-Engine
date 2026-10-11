// Ported from: Assets/Scripts/Engine/Level/Entities/Entity.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Armor.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Aura.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Buff.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Collision.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Grids.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Model.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Modifiers.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Physics.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Properties.cs
// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Serialize.cs
// PORT-NOTE: C# 中 Entity 为 partial class（11 个文件），按 PORTING.md「partial class 合并为一个类文件」合并到本文件；
//   下面各 region 的注释标出了对应的源文件。
// PORT-NOTE: C# 的显式接口实现（LevelEngine ILevelObject.GetLevel()、IBuffList IBuffTarget.Buffs 等）在 Haxe 中为普通公开成员。
// PORT-NOTE: C# event Action<...>? → FlxTypedSignal<...->Void>，+= / -= → add / remove，Invoke → dispatch。
// PORT-NOTE: C# 的扩展方法（EngineEntityExt / EngineEntityProps / LogicEntityExt 等）通过类型上的 `@:using` 提供，
//   以便既有调用点继续以 entity.GetMaxHealth()、entity.Spawn(...) 的形式调用。
package pvzengine.entities;

import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Int64;
import pvzengine.IPropertyKey;
import pvzengine.NamespaceID;
import pvzengine.PropertyKey;
import pvzengine.RandomGenerator;
import pvzengine.armors.Armor;
import pvzengine.armors.ArmorDefinition;
import pvzengine.armors.ArmorDestroyInfo;
import pvzengine.auras.AuraEffect;
import pvzengine.auras.AuraEffectDefinition;
import pvzengine.auras.AuraEffectList;
import pvzengine.auras.IAuraSource;
import pvzengine.base.MissingDefinitionException;
import pvzengine.buffs.Buff;
import pvzengine.buffs.BuffList;
import pvzengine.buffs.BuffReference;
import pvzengine.buffs.BuffReference.BuffReferenceEntity;
import pvzengine.buffs.IBuffList;
import pvzengine.buffs.IBuffTarget;
import pvzengine.buffs.IModeledBuffTarget;
import pvzengine.buffs.ModelInsertion;
import pvzengine.buffs.SerializableBuffList;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.EntityCallbackParams;
import pvzengine.callbacks.LevelCallbacks;
import pvzengine.callbacks.LevelCallbacks.ArmorParams;
import pvzengine.callbacks.LevelCallbacks.EntityDeathParams;
import pvzengine.callbacks.LevelCallbacks.PostArmorDestroyParams;
import pvzengine.callbacks.LevelCallbacks.PostEntityCollisionParams;
import pvzengine.callbacks.LevelCallbacks.PostEntityContactGroundParams;
import pvzengine.callbacks.LevelCallbacks.PreEntityCollisionParams;
import pvzengine.collisions.ColliderConstructor;
import pvzengine.collisions.IEntityCollider;
import pvzengine.damages.DamageEffectList;
import pvzengine.damages.DamageResultValues;
import pvzengine.damages.DeathInfo;
import pvzengine.damages.SerializableDeathInfo;
import pvzengine.grids.LawnGrid;
import pvzengine.level.ILevelObject;
import pvzengine.level.ILevelSourceReference;
import pvzengine.level.ILevelSourceTarget;
import pvzengine.level.IModifiablePropertyTarget;
import pvzengine.level.ISerializableSourceReference;
import pvzengine.level.LevelEngine;
import pvzengine.level.PropertyBlock;
import pvzengine.models.IModelInterface;
import pvzengine.modifiers.IModifierProvider;
import pvzengine.modifiers.IModifierSource;
import pvzengine.modifiers.ModifierLibrary;
import pvzengine.modifiers.ModifierSourceItem;
import tools.GenericHelper;
import tools.ObjectExtensions;
import unity.Bounds;
import unity.Debug;
import unity.Mathf;
import unity.Vector2Int;
import unity.Vector3;
using pvzengine.ContentProviderHelper;

@:using(pvzengine.entities.EngineEntityExt)
@:using(pvzengine.entities.EngineEntityProps)
// PORT-NOTE: C# 的 TimerHelper.IsSecondsInterval(this Entity entity, ...) 是扩展方法，既有上层调用点写作
//   `entity.IsSecondsInterval(1)`（4 个文件 6 处），Entity 自身未声明该方法，故在此标注 @:using。
@:using(pvzengine.TimerHelper)
// PORT-NOTE: C# 中 Entity 实现 IModifierSource（其 GetProperty<T>(PropertyKey<T>) 为单参形式），
//   而既有调用点大量使用 C# 的 `GetProperty<T>(name, ignoreBuffs = false)`（如
//   mvz2/vanilla/entities/VanillaEntityProps.hx 的 `entity.GetProperty(SHOT_OFFSET, ignoreBuffs)`）。
//   Haxe 不支持重载，两者无法同名共存；按「以既有调用点为准」，Entity 保留双参 GetProperty，
//   IModifierSource 由内部适配器 EntityModifierSource 承担（ModifierSourceItem / ModifierLibrary 均使用同一实例）。
class Entity implements ILevelSourceTarget implements IAuraSource implements IModeledBuffTarget implements IModifierProvider implements IModifiablePropertyTarget
{
	// #region 构造器 (Entity.cs)
	public function new(level:LevelEngine, id:Int64, definition:EntityDefinition, ?spawnerSource:Null<ILevelSourceReference>, ?seed:Null<Int>)
	{
		Cache = new EntityCache();
		modifierSource = new EntityModifierSource(this);
		properties = new PropertyBlock(this, buffs);
		modifierLibrary = new ModifierLibrary();
		modifierLibrary.OnModifiedPropertyNeedsUpdate.add(OnModifiedPropertyNeedsUpdateCallback);
		InitBuffEvents();

		Level = level;

		ID = id;
		SpawnerReference = spawnerSource;

		Definition = definition;
		ModelID = definition.GetModelID();
		Type = definition.Type;
		TypeCollisionFlag = EntityCollisionHelper.GetTypeMask(Type);
		// 光环
		CreateAuraEffects();

		RNG = null;
		DropRNG = null;

		// PORT-NOTE: C# 区分「公开构造器（带 seed）」与「私有构造器（不带 seed）」两个重载；
		//   Haxe 无重载，这里用可选参数合并，仅在传入 seed 时执行公开构造器的额外初始化。
		if (seed != null)
		{
			InitSeed = seed;
			RNG = new RandomGenerator(seed);
			DropRNG = new RandomGenerator(RNG.Next());
			ReevaluateModifierCaches();
			Cache.UpdateAll(this);
		}
	}
	// #endregion

	// #region 生命周期 (Entity.cs)
	public function Init():Void
	{
		PreviousPosition = Position;
		IsOnGround = GetRelativeY() <= Mathf.Epsilon;

		Health = this.GetMaxHealth();
		UpdateAllModifiedProperties(true);
		Definition.Init(this);
		Level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_ENTITY_INIT, new EntityCallbackParams(this), Type);
		PostInit.dispatch();
	}
	public function Update():Void
	{
		try
		{
			UpdatePhysics(1);
			LimitHealth();
			Definition.Update(this);
			UpdateArmors();
			UpdateAuras();
			UpdateBuffs();
			Level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_ENTITY_UPDATE, new EntityCallbackParams(this), Type);
		}
		catch (ex:Dynamic)
		{
			Debug.LogError('更新实体时出现错误：${ex}');
		}
		time++;
	}
	public function Exists():Bool
	{
		return !Removed;
	}
	public function Remove():Void
	{
		if (!Removed)
		{
			Removed = true;
			Level.RemoveEntity(this);

			// 将取用的传送带种子放回传送带池中。
			ClearTakenConveyorSeeds();

			// 触发实体移除回调。
			Definition.PostRemove(this);
			Level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_ENTITY_REMOVE, new EntityCallbackParams(this), Type);
		}
	}
	// #endregion

	// #region 父子级 (Entity.cs)
	public function SetParent(parent:Null<Entity>):Void
	{
		var oldParent = Parent;
		if (oldParent != null)
		{
			oldParent.children = oldParent.children.filter(r -> r.ID != ID);
		}
		Parent = parent;
		if (parent != null)
		{
			parent.children.push(this);
		}
	}
	public function GetChildren():Array<Entity>
	{
		return children.copy();
	}
	// #endregion

	// #region 死亡 (Entity.cs)
	// PORT-NOTE: C# 有 Die() / Die(Entity?, DamageResultValues?) / Die(DamageEffectList, Entity?, DamageResultValues?) /
	//   Die(DamageEffectList, ILevelSourceReference?, DamageResultValues?) / Die(DeathInfo) 五个重载，Haxe 无重载，
	//   合并为一个按运行期实参类型分派的方法（既有调用点均使用原名 Die）。
	public function Die(?arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic):Void
	{
		if (arg1 == null)
		{
			DieWithInfo(new DeathInfo(this, new DamageEffectList(), null, null));
			return;
		}
		if (Std.isOfType(arg1, DeathInfo))
		{
			DieWithInfo(cast arg1);
			return;
		}
		if (Std.isOfType(arg1, DamageEffectList))
		{
			var effects:DamageEffectList = cast arg1;
			var damage:Null<DamageResultValues> = cast arg3;
			if (arg2 == null)
			{
				DieWithInfo(new DeathInfo(this, effects, null, damage));
			}
			else if (Std.isOfType(arg2, Entity))
			{
				DieWithInfo(new DeathInfo(this, effects, new EntitySourceReference(cast arg2), damage));
			}
			else
			{
				DieWithInfo(new DeathInfo(this, effects, cast arg2, damage));
			}
			return;
		}
		// arg1 为 Entity 源、arg2 为 DamageResultValues。
		DieWithInfo(new DeathInfo(this, new DamageEffectList(), new EntitySourceReference(cast arg1), cast arg2));
	}
	public function DieWithSource(effects:DamageEffectList, source:Null<ILevelSourceReference>, ?damage:Null<DamageResultValues>):Void
	{
		DieWithInfo(new DeathInfo(this, effects, source, damage));
	}
	public function DieWithInfo(info:DeathInfo):Void
	{
		if (IsDead)
			return;
		if (!PreDeath(info))
			return;
		IsDead = true;
		lethalDeathInfo = info;
		PostDeath(info);
	}
	private function PreDeath(info:DeathInfo):Bool
	{
		var param = new EntityDeathParams(this, info);
		var callbackResult = new CallbackResult(true);
		Definition.PreDeath(this, info, callbackResult);
		if (!callbackResult.IsBreakRequested)
		{
			Level.Triggers.RunCallbackWithResultFiltered(LevelCallbacks.PRE_ENTITY_DEATH, param, callbackResult, Type);
		}
		return callbackResult.GetValue();
	}
	private function PostDeath(info:DeathInfo):Void
	{
		var param = new EntityDeathParams(this, info);
		Definition.PostDeath(this, info);
		Level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_ENTITY_DEATH, param, Type);
	}
	public function Revive():Void
	{
		if (!IsDead)
			return;
		IsDead = false;
		lethalDeathInfo = null;
		Level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_ENTITY_REVIVE, new EntityCallbackParams(this), Type);
	}
	private function LimitHealth():Void
	{
		Health = Mathf.Min(Health, this.GetMaxHealth());
	}
	public function GetLethalDeathInfo():Null<DeathInfo>
	{
		return lethalDeathInfo;
	}
	// #endregion

	// #region 阵营 (Entity.cs)
	public function GetFaction():Int
	{
		return Cache.Faction;
	}
	// PORT-NOTE: C# 有 IsFriendly(Entity) / IsFriendly(int) 两个重载（IsHostile 同理），Haxe 无重载，
	//   合并为一个按运行期实参类型分派的方法；既有调用点传入 Entity 或 Int 两种实参。
	public function IsFriendly(other:Dynamic):Bool
	{
		if (other == null)
			return false;
		if (Std.isOfType(other, Entity))
			return IsFriendlyFaction((cast other:Entity).GetFaction());
		return IsFriendlyFaction(cast(other, Int));
	}
	public function IsFriendlyFaction(faction:Int):Bool
	{
		return EngineEntityExt.IsFriendly(GetFaction(), faction);
	}
	public function IsHostile(other:Dynamic):Bool
	{
		if (other == null)
			return false;
		if (Std.isOfType(other, Entity))
			return IsHostileFaction((cast other:Entity).GetFaction());
		return IsHostileFaction(cast(other, Int));
	}
	public function IsHostileFaction(faction:Int):Bool
	{
		return EngineEntityExt.IsHostile(GetFaction(), faction);
	}
	// #endregion

	// #region 时间 (Entity.cs)
	public function GetEntityTime():Int64
	{
		return time;
	}
	// PORT-NOTE: C# `long offset = 0` 的默认值在 Haxe 的 haxe.Int64 上无法表达，改用可空形参后补默认值。
	public function IsTimeInterval(interval:Int64, ?offset:Int64):Bool
	{
		if (offset == null)
			offset = haxe.Int64.ofInt(0);
		return time % interval == offset;
	}
	// #endregion

	// #region 传送带 (Entity.cs)
	public function AddTakenConveyorSeed(id:NamespaceID):Void
	{
		if (takenConveyorSeeds.exists(id))
		{
			takenConveyorSeeds.set(id, takenConveyorSeeds.get(id) + 1);
		}
		else
		{
			takenConveyorSeeds.set(id, 1);
		}
	}
	public function RemoveTakenConveyorSeed(id:NamespaceID):Bool
	{
		if (!takenConveyorSeeds.exists(id))
		{
			return false;
		}
		takenConveyorSeeds.set(id, takenConveyorSeeds.get(id) - 1);
		if (takenConveyorSeeds.get(id) <= 0)
		{
			takenConveyorSeeds.remove(id);
		}
		return true;
	}
	public function ClearTakenConveyorSeeds():Void
	{
		for (key in takenConveyorSeeds.keys())
		{
			Level.PutSeedToConveyorDiscardPile(key, takenConveyorSeeds.get(key));
		}
		takenConveyorSeeds.clear();
	}
	// #endregion

	// #region 行为 (Entity.cs)
	public function HasBehaviour(behaviour:Dynamic):Bool
	{
		return Definition.HasBehaviour(behaviour);
	}
	// #endregion

	// #region 杂项 (Entity.cs)
	public function IsEntityOf(id:NamespaceID):Bool
	{
		return Definition.GetID() == id;
	}
	public function IsFacingLeft():Bool
	{
		return this.FaceLeftAtDefault() != (Cache.GetFinalScale().x < 0);
	}
	public function toString():String
	{
		return '${ID}(${this.Definition.GetID()})';
	}
	// #endregion

	// #region 事件回调 (Entity.cs)
	private function OnContactGround(velocity:Vector3):Void
	{
		Definition.PostContactGround(this, velocity);
		// PORT-NOTE: C# 的对象初始化器（`new LevelCallbacks.PostEntityContactGroundParams() { ... }`）依赖结构体的
		//   默认构造器；Haxe 侧 pvzengine.callbacks 的 Params 类未声明构造函数，无法 `new`，
		//   故用 CreateParams 生成实例后逐字段赋值（语义等价）。
		var param = CreateParams(PostEntityContactGroundParams);
		param.entity = this;
		param.velocity = velocity;
		Level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_ENTITY_CONTACT_GROUND, param, Definition.GetID());
	}
	private function OnLeaveGround():Void
	{
		Definition.PostLeaveGround(this);
		// PORT-NOTE: C# 用对象初始化器 `new EntityCallbackParams() { entity = this }`；
		// Haxe 的该类型有 (Entity) 构造函数。
		var param = new EntityCallbackParams(this);
		Level.Triggers.RunCallback(LevelCallbacks.POST_ENTITY_LEAVE_GROUND, param);
	}
	// #endregion

	// #region ILevelObject接口实现 (Entity.cs)
	public function GetLevel():LevelEngine
	{
		return Level;
	}
	public function GetEntity():Null<Entity>
	{
		return this;
	}
	public function GetChildrenObjects():Array<ILevelObject>
	{
		var result:Array<ILevelObject> = [];
		for (armor in armorDict)
		{
			result.push(armor);
		}
		for (buff in buffs)
		{
			result.push(buff);
		}
		return result;
	}
	public function OnAddToLevel(level:LevelEngine):Void
	{
		auras.PostAdd();
	}
	public function OnRemoveFromLevel(level:LevelEngine):Void
	{
		auras.PostRemove();
	}
	// #endregion

	// #region 护甲 (Entity_Armor.cs)
	public function IsEquippingArmor(armor:Armor):Bool
	{
		for (a in armorDict)
		{
			if (a == armor)
				return true;
		}
		return false;
	}
	// PORT-NOTE: C# 泛型重载 EquipArmorTo<T>(NamespaceID) 在 Haxe 中无法以显式类型参数调用，
	//   改名为 EquipArmorToType（类型以 Class<T> 传入）。
	public function EquipArmorToType<T:ArmorDefinition>(slot:NamespaceID, ?type:Class<T>):Armor
	{
		// PORT-NOTE: 对应 C# `Level.Content.GetArmorDefinition<T>()`（按定义类型查找）；
		//   Haxe 无法按 System.Type 构造泛型查找，改为遍历全部护甲定义后按类型过滤。
		var definition:ArmorDefinition = null;
		for (d in Level.Content.GetAllArmorDefinitions())
		{
			if (type == null || Std.isOfType(d, type))
			{
				definition = cast d;
				break;
			}
		}
		return EquipArmorToDefinition(slot, definition);
	}
	public function EquipArmorTo(slot:NamespaceID, arg:Dynamic):Armor
	{
		// PORT-NOTE: C# 的 EquipArmorTo(NamespaceID, NamespaceID) / (NamespaceID, ArmorDefinition) /
		//   (NamespaceID, Armor) 三个重载在 Haxe 中合并，按运行期类型分派。
		if (Std.isOfType(arg, Armor))
		{
			EquipArmorToArmor(slot, cast arg);
			return cast arg;
		}
		var definition:ArmorDefinition;
		if (Std.isOfType(arg, ArmorDefinition))
		{
			definition = cast arg;
		}
		else
		{
			definition = Level.Content.GetArmorDefinition(cast(arg, NamespaceID));
			if (definition == null)
				throw new MissingDefinitionException('Trying to create an armor with missing definition ${arg}');
		}
		return EquipArmorToDefinition(slot, definition);
	}
	public function EquipArmorToDefinition(slot:NamespaceID, definition:ArmorDefinition):Armor
	{
		var armor = new Armor(this, slot, definition);
		EquipArmorToArmor(slot, armor);
		return armor;
	}
	public function EquipArmorToArmor(slot:NamespaceID, armor:Armor):Void
	{
		if (armor == null)
			return;
		var oldShield = armorDict.get(slot);
		if (oldShield != null)
		{
			oldShield.Destroy();
		}
		armorDict.set(slot, armor);

		// 创建碰撞体
		CreateCollidersForArmor(slot, armor);

		Definition.PostEquipArmor(this, slot, armor);
		// PORT-NOTE: 同 OnContactGround 处 CreateParams 的说明（C# 对象初始化器）。
		var param = CreateParams(ArmorParams);
		param.entity = this;
		param.slot = slot;
		param.armor = armor;
		Level.Triggers.RunCallback(LevelCallbacks.POST_EQUIP_ARMOR, param);
		OnEquipArmor.dispatch(slot, armor);
		Level.IncreaseLevelObjectChildReference(this, armor);
	}
	public function RemoveArmor(slot:NamespaceID):Void
	{
		if (!armorDict.exists(slot))
			return;
		var armor = armorDict.get(slot);
		if (armor == null)
			return;
		armorDict.remove(slot);

		// 移除碰撞体
		RemoveCollidersFromArmor(slot, armor);

		Definition.PostRemoveArmor(this, slot, armor);
		// PORT-NOTE: 同 OnContactGround 处 CreateParams 的说明（C# 对象初始化器）。
		var param = CreateParams(ArmorParams);
		param.entity = this;
		param.slot = slot;
		param.armor = armor;
		Level.Triggers.RunCallback(LevelCallbacks.POST_REMOVE_ARMOR, param);
		OnRemoveArmor.dispatch(slot, armor);

		Level.DecreaseLevelObjectChildReference(this, armor);
	}
	public function DestroyArmor(slot:NamespaceID, info:ArmorDestroyInfo):Void
	{
		if (!armorDict.exists(slot))
			return;
		var armor = armorDict.get(slot);
		if (armor == null)
			return;
		Definition.PostDestroyArmor(this, slot, armor, info);
		// PORT-NOTE: 同 OnContactGround 处 CreateParams 的说明（C# 对象初始化器）。
		var param = CreateParams(PostArmorDestroyParams);
		param.entity = this;
		param.slot = slot;
		param.armor = armor;
		param.info = info;
		Level.Triggers.RunCallback(LevelCallbacks.POST_DESTROY_ARMOR, param);
	}
	public function GetArmorAtSlot(slot:NamespaceID):Null<Armor>
	{
		return armorDict.exists(slot) ? armorDict.get(slot) : null;
	}
	public function GetActiveArmorSlots():Array<NamespaceID>
	{
		var result:Array<NamespaceID> = [];
		for (key in armorDict.keys())
		{
			result.push(key);
		}
		return result;
	}
	public function ActivateArmorColliders(slot:NamespaceID):Void
	{
		for (collider in GetArmorColliders(slot))
		{
			collider.SetEnabled(true);
		}
	}
	public function DeactivateArmorColliders(slot:NamespaceID):Void
	{
		for (collider in GetArmorColliders(slot))
		{
			collider.SetEnabled(false);
		}
	}
	private function CreateCollidersForArmor(slot:NamespaceID, armor:Armor):Void
	{
		for (cons in armor.GetColliderConstructors(this, slot))
		{
			var info = cons;
			info.name = GetArmorColliderName(slot, cons.name);
			info.armorSlot = slot;
			CreateCollider(info);
		}
	}
	private function RemoveCollidersFromArmor(slot:NamespaceID, armor:Armor):Void
	{
		for (cons in armor.GetColliderConstructors(this, slot))
		{
			var name = GetArmorColliderName(slot, cons.name);
			RemoveCollider(name);
		}
	}
	private function GetArmorColliders(slot:NamespaceID):Array<IEntityCollider>
	{
		var result:Array<IEntityCollider> = [];
		var armor = GetArmorAtSlot(slot);
		if (armor == null)
			return result;
		for (cons in armor.GetColliderConstructors(this, slot))
		{
			var name = GetArmorColliderName(slot, cons.name);
			var collider = GetCollider(name);
			if (collider == null)
				continue;
			result.push(collider);
		}
		return result;
	}
	private static function GetArmorColliderName(slot:NamespaceID, name:String):String
	{
		return '${slot}/${name}';
	}
	private function UpdateArmors():Void
	{
		var armors:Array<Armor> = [];
		for (a in armorDict)
		{
			armors.push(a);
		}
		for (armor in armors)
		{
			armor.Update();
		}
	}
	// #endregion

	// #region 护甲序列化 (Entity_Armor.cs)
	private function InitArmorsFromSerializable(seri:SerializableEntity):Void
	{
		armorDict.clear();
		if (seri.armors != null)
		{
			for (key in seri.armors.keys())
			{
				var value = seri.armors.get(key);
				if (value == null)
					continue;
				var slot = NamespaceID.ParseStrict(key);
				var armor = Armor.CreateFromSerializable(value, this);
				if (armor == null)
					continue;
				armorDict.set(slot, armor);
			}
		}
	}
	private function LoadArmorsFromSerializable(seri:SerializableEntity):Void
	{
		for (key in armorDict.keys())
		{
			var armor = armorDict.get(key);
			if (armor == null || seri.armors == null)
				continue;
			var seriArmor = Lambda.find(seri.armors, a -> a.slot == key);
			if (seriArmor == null)
				continue;
			armor.LoadFromSerializable(seriArmor);
		}
	}
	// #endregion

	// #region 护甲事件 (Entity_Armor.cs)
	public var OnEquipArmor:FlxTypedSignal<NamespaceID->Armor->Void> = new FlxTypedSignal();
	public var OnRemoveArmor:FlxTypedSignal<NamespaceID->Armor->Void> = new FlxTypedSignal();
	// #endregion

	// #region 光环 (Entity_Aura.cs)
	private function CreateAuraEffects():Void
	{
		var auraDefs = Definition.GetAuras();
		for (i in 0...auraDefs.length)
		{
			var auraDef = auraDefs[i];
			auras.Add(Level, new AuraEffect(auraDef, i, this));
		}
	}
	private function UpdateAuras():Void
	{
		auras.Update();
	}
	// PORT-NOTE: C# 泛型 GetAuraEffect<T>() 在 Haxe 中改以 Class<T> 形参传入（调用点可省略，退化为取第一个光环，
	//   见 pvzengine/auras/AuraEffectList.hx 的 PORT-NOTE）。
	public function GetAuraEffect<T:AuraEffectDefinition>(?type:Class<T>):AuraEffect
	{
		return auras.GetOfType(type);
	}
	public function GetAuraEffects():Array<AuraEffect>
	{
		return auras.GetAll();
	}
	// #endregion

	// #region 光环序列化 (Entity_Aura.cs)
	private function WriteAurasToSerializable(seri:SerializableEntity):Void
	{
		seri.auras = [for (a in auras.GetAll()) a.ToSerializable()];
	}
	private function LoadAurasFromSerializable(seri:SerializableEntity):Void
	{
		if (seri.auras == null)
			return;
		auras.LoadFromSerializable(Level, cast seri.auras);
	}
	// #endregion

	// #region 增益 (Entity_Buff.cs)
	private function InitBuffEvents():Void
	{
		buffs.OnModelInsertionAdded.add(OnModelInsertionAddedCallback);
		buffs.OnModelInsertionRemoved.add(OnModelInsertionRemovedCallback);
	}
	private function UpdateBuffs():Void
	{
		buffs.Update();
	}
	public function GetBuffReference(buff:Buff):BuffReference
	{
		return new BuffReferenceEntity(ID, buff.ID);
	}
	// #endregion

	// #region 增益序列化 (Entity_Buff.cs)
	private function InitBuffsFromSerializable(seri:SerializableEntity):Void
	{
		buffs.InitFromSerializable(seri.buffs, Level, this);
	}
	private function LoadBuffsFromSerializable(seri:SerializableEntity):Void
	{
		if (seri.buffs != null)
			buffs.LoadFromSerializable(seri.buffs);
	}
	// #endregion

	// #region 增益事件回调 (Entity_Buff.cs)
	private function OnModelInsertionAddedCallback(insertion:ModelInsertion):Void
	{
		OnModelInsertionAdded.dispatch(insertion);
	}
	private function OnModelInsertionRemovedCallback(insertion:ModelInsertion):Void
	{
		OnModelInsertionRemoved.dispatch(insertion);
	}
	// #endregion

	// #region 增益事件 (Entity_Buff.cs)
	public var OnModelInsertionAdded:FlxTypedSignal<ModelInsertion->Void> = new FlxTypedSignal();
	public var OnModelInsertionRemoved:FlxTypedSignal<ModelInsertion->Void> = new FlxTypedSignal();
	// #endregion

	// #region 碰撞 (Entity_Collision.cs)
	public function UpdateCollision():Void
	{
		UpdateCollisionDetection();
		UpdateCollisionPosition();
		UpdateCollisionSize();
	}
	public function UpdateCollisionDetection():Void
	{
		Level.UpdateEntityCollisionDetection(this);
	}
	public function UpdateCollisionPosition():Void
	{
		Level.UpdateEntityCollisionPosition(this);
	}
	public function UpdateCollisionSize():Void
	{
		Level.UpdateEntityCollisionSize(this);
	}
	public function CreateCollider(info:ColliderConstructor):Null<IEntityCollider>
	{
		return Level.AddEntityCollider(this, info);
	}
	public function RemoveCollider(name:String):Bool
	{
		return Level.RemoveEntityCollider(this, name);
	}
	public function GetCollider(name:String):Null<IEntityCollider>
	{
		return Level.GetEntityCollider(this, name);
	}
	public function GetCurrentCollisions(collisions:Array<EntityCollision>):Void
	{
		Level.GetEntityCurrentCollisions(this, collisions);
	}
	public function PreCollision(collision:EntityCollision):Bool
	{
		var result = new CallbackResult(true);
		Definition.PreCollision(collision, result);
		if (!result.IsBreakRequested)
		{
			// PORT-NOTE: 同 OnContactGround 处 CreateParams 的说明（C# 对象初始化器）。
			var param = CreateParams(PreEntityCollisionParams);
			param.collision = collision;
			Level.Triggers.RunCallbackWithResult(LevelCallbacks.PRE_ENTITY_COLLISION, param, result);
		}
		return result.GetValue();
	}
	public function PostCollision(collision:EntityCollision, state:Int):Void
	{
		Definition.PostCollision(collision, state);
		// PORT-NOTE: 同 OnContactGround 处 CreateParams 的说明（C# 对象初始化器）。
		var param = CreateParams(PostEntityCollisionParams);
		param.collision = collision;
		param.state = state;
		Level.Triggers.RunCallback(LevelCallbacks.POST_ENTITY_COLLISION, param);
	}
	// #endregion

	// #region 碰撞序列化 (Entity_Collision.cs)
	private function LoadCollisionFromSerializable(seri:SerializableEntity):Void
	{
		CollisionMaskHostile = seri.collisionMaskHostile;
		CollisionMaskFriendly = seri.collisionMaskFriendly;
	}
	// #endregion

	// #region 网格位置 (Entity_Grids.cs)
	public function GetColumn():Int
	{
		var gridPivotOffset = Cache.GridPivotOffset;
		return Level.GetColumn(Position.x + gridPivotOffset.x);
	}
	public function GetLane():Int
	{
		var gridPivotOffset = Cache.GridPivotOffset;
		return Level.GetLane(Position.z + gridPivotOffset.y);
	}
	public function GetGridIndex():Int
	{
		return Level.GetGridIndex(GetColumn(), GetLane());
	}
	public function GetGrid():Null<LawnGrid>
	{
		return Level.GetGrid(GetColumn(), GetLane());
	}
	public function GetGridPosition():Vector2Int
	{
		return new Vector2Int(GetColumn(), GetLane());
	}
	// #endregion

	// #region 占据网格 (Entity_Grids.cs)
	public function HasTakenGrid():Bool
	{
		return takenGrids.length > 0;
	}
	public function GetTakenGrids():Array<LawnGrid>
	{
		return takenGrids.copy();
	}
	public function GetTakenGridsNonAlloc(results:Array<LawnGrid>):Void
	{
		results = results.concat(takenGrids);
	}
	public function GetTakingGridLayers(grid:LawnGrid):Array<NamespaceID>
	{
		return grid.GetEntityLayers(this);
	}
	public function GetTakingGridLayersNonAlloc(grid:LawnGrid, results:Array<NamespaceID>):Void
	{
		grid.GetEntityLayersNonAlloc(this, results);
	}
	public function IsTakingGridLayer(grid:LawnGrid, layer:NamespaceID):Bool
	{
		return grid.IsEntityOnLayer(this, layer);
	}
	public function TakeGrid(grid:LawnGrid, layer:NamespaceID):Void
	{
		grid.AddLayerEntity(layer, this);
		if (!takenGrids.contains(grid))
		{
			takenGrids.push(grid);
		}
	}
	public function ReleaseGrid(grid:LawnGrid, layer:NamespaceID):Void
	{
		grid.RemoveLayerEntity(layer, this);
		if (!grid.HasEntity(this))
		{
			takenGrids.remove(grid);
		}
	}
	public function ClearTakenGrids():Void
	{
		for (grid in takenGrids)
		{
			grid.RemoveGridEntity(this);
		}
		takenGrids = [];
	}
	// #endregion

	// #region 网格序列化 (Entity_Grids.cs)
	private function LoadGridsFromSerializable(seri:SerializableEntity):Void
	{
		// C#: #pragma warning disable CS0612 // 类型或成员已过时
		if (seri.takenGridIndexes != null)
		{
			for (index in seri.takenGridIndexes)
			{
				// PORT-NOTE: C# `Level.GetGrid(int index)`；Haxe 侧 LevelEngine 同时存在 GetGrid(column, lane)
				//   重载，故按 C# 定义（index = lane * maxColumnCount + column）换算后调用二参版本。
				var grid = Level.GetGrid(Level.GetGridColumnByIndex(index), Level.GetGridLaneByIndex(index));
				if (grid == null)
					continue;
				takenGrids.push(grid);
			}
		}
		else if (seri.takenGrids != null)
		{
			for (info in seri.takenGrids)
			{
				if (info == null || info.layers == null)
					continue;
				var grid = Level.GetGrid(Level.GetGridColumnByIndex(info.grid), Level.GetGridLaneByIndex(info.grid));
				if (grid == null)
					continue;
				takenGrids.push(grid);
			}
		}
		// C#: #pragma warning restore CS0612
	}
	// #endregion

	// #region 模型 (Entity_Model.cs)
	public function SetModelInterface(model:Null<IModelInterface>):Void
	{
		modelInterface = model;
	}
	public function GetModelInterface():Null<IModelInterface>
	{
		return modelInterface;
	}
	public function ChangeModel(modelID:NamespaceID):Void
	{
		ModelID = modelID;
		OnChangeModel.dispatch(modelID);
	}
	// C#: IModeledBuffTarget.GetInsertedModel(NamespaceID key) => this.GetChildModel(key);
	// PORT-NOTE: C# 的接口默认实现在 Haxe 中必须由实现类提供（与 pvzengine.armors.Armor、
	//   pvzengine.grids.LawnGrid 的移植写法一致）。
	public function GetInsertedModel(key:NamespaceID):Null<IModelInterface>
	{
		return this.GetChildModel(key);
	}
	// #endregion

	// #region 模型序列化 (Entity_Model.cs)
	private function LoadModelFromSerializable(seri:SerializableEntity):Void
	{
		ModelID = seri.modelID != null ? seri.modelID : Definition.GetID();
	}
	// #endregion

	// #region 模型事件 (Entity_Model.cs)
	public var OnChangeModel:FlxTypedSignal<NamespaceID->Void> = new FlxTypedSignal();
	// #endregion

	// #region 修改器 (Entity_Modifiers.cs)
	private function ReevaluateModifierCaches():Void
	{
		modifierLibrary.ClearModifierCaches();
		var items:Array<ModifierSourceItem> = [];
		for (m in Definition.GetModifiers())
		{
			items.push(new ModifierSourceItem(modifierSource, m));
		}
		modifierLibrary.AddModifierCaches(items);
	}
	private function OnModifiedPropertyNeedsUpdateCallback(name:IPropertyKey):Void
	{
		OnModifiedPropertyNeedsUpdate.dispatch(name);
	}
	// PORT-NOTE: C# `T? IModifierSource.GetProperty<T>(PropertyKey<T>)` 由下方的 GetProperty 满足。
	public function GetModifiedProperties():Array<IPropertyKey>
	{
		return modifierLibrary.GetModifyPropertyKeys();
	}
	public function GetModifiersForProperty(name:IPropertyKey, results:Array<ModifierSourceItem>):Void
	{
		modifierLibrary.GetModifierItemsForProperty(name, results);
	}
	// #endregion

	// #region 修改器事件 (Entity_Modifiers.cs)
	public var OnModifiedPropertyNeedsUpdate:FlxTypedSignal<IPropertyKey->Void> = new FlxTypedSignal();
	// #endregion

	// #region 物理 (Entity_Physics.cs)
	public function GetCenter():Vector3
	{
		var center = Position + Cache.BoundsOffset;

		var pivot = Cache.BoundsPivot;
		var size = Cache.Size;
		var scale = Cache.GetFinalScale();

		var scaledSize = Vector3.Scale(size, scale);
		var scaledPivot = Vector3.Scale(pivot, scale);

		center += Vector3.Scale(Vector3.one * 0.5 - pivot, scaledSize);

		return center;
	}
	public function GetScaledSize():Vector3
	{
		// PORT-NOTE: C# `size.Scale(scale)` 是 Unity 的 Vector3 实例方法（值语义、就地修改）；
		//   Haxe 的 unity.Vector3 是「引用语义的 abstract」，就地修改会污染 EntityCache 的缓存值，
		//   故改用静态 Vector3.Scale + ObjectExtensions.Abs 生成新值。
		var size = Vector3.Scale(Cache.Size, Cache.GetFinalScale());
		return ObjectExtensions.Abs(size);
	}
	public function SetCenter(center:Vector3):Void
	{
		var offset = GetCenter() - Position;
		Position = center - offset;
	}
	public function GetBounds():Bounds
	{
		return new Bounds(GetCenter(), GetScaledSize());
	}
	public function GetGroundY():Float
	{
		return Level.GetGroundY(Position.x, Position.z);
	}
	public function GetRelativeY():Float
	{
		return Position.y - GetGroundY();
	}
	public function SetRelativeY(value:Float):Void
	{
		var pos = Position;
		pos.y = value + GetGroundY();
		Position = pos;
	}
	private function GetNextPosition(simulationSpeed:Float = 1):Vector3
	{
		var velocity = GetNextVelocity(simulationSpeed);
		// PORT-NOTE: C# `velocity.Scale(...)`（Vector3 值语义就地修改）→ Haxe 用静态 Vector3.Scale 生成新值。
		velocity = Vector3.Scale(velocity, Vector3.one - Cache.VelocityDampen);
		var nextPos = Position + velocity * simulationSpeed;
		return nextPos;
	}
	private function GetNextVelocity(simulationSpeed:Float = 1):Vector3
	{
		// PORT-NOTE: C# Vector3 为值类型，赋值即拷贝；Haxe 的 unity.Vector3 为引用语义，
		//   下面的就地改动会污染 Entity.Velocity，故显式复制一份。
		var velocity = new Vector3(Velocity.x, Velocity.y, Velocity.z);

		// Friction.
		var frictionMulti = Mathf.Pow(Mathf.Max(0, 1 - Cache.Friction), simulationSpeed);
		velocity = new Vector3(velocity.x * frictionMulti, velocity.y, velocity.z * frictionMulti);

		// Gravity.
		velocity.y -= Cache.Gravity * simulationSpeed;

		return velocity;
	}
	public function UpdatePhysics(simulationSpeed:Float = 1):Void
	{
		var nextVelocity = GetNextVelocity(simulationSpeed);
		var nextPos = GetNextPosition(simulationSpeed);

		// 地面限制。
		var groundY = Level.GetGroundY(nextPos.x, nextPos.z);
		var groundLimit = groundY + Cache.GroundLimitOffset;
		var contactingGround = nextPos.y <= groundY;
		var contactVelocity = nextVelocity;
		if (nextPos.y <= groundLimit)
		{
			nextPos.y = groundLimit;
			nextVelocity.y = Mathf.Max(nextVelocity.y, 0);
		}

		PreviousPosition = Position;
		Position = nextPos;
		Velocity = nextVelocity;

		if (contactingGround)
		{
			if (!IsOnGround)
			{
				OnContactGround(contactVelocity);
				IsOnGround = true;
			}
		}
		else
		{
			if (IsOnGround)
			{
				OnLeaveGround();
				IsOnGround = false;
			}
		}
	}
	// #endregion

	// #region 物理序列化 (Entity_Physics.cs)
	private function LoadPhysicsFromSerializable(seri:SerializableEntity):Void
	{
		PreviousPosition = seri.previousPosition;
		Position = seri.position;
		IsOnGround = seri.isOnGround;
		Velocity = seri.velocity;
	}
	// #endregion

	// #region 属性 (Entity_Properties.cs)
	public function GetProperty<T>(name:PropertyKey<T>, ignoreBuffs:Bool = false):Null<T>
	{
		return properties.GetProperty(name, ignoreBuffs);
	}
	public function SetProperty<T>(name:PropertyKey<T>, value:Null<T>):Void
	{
		properties.SetProperty(name, value);
	}
	public function SetPropertyObject(name:IPropertyKey, value:Dynamic):Void
	{
		properties.SetPropertyObject(name, value);
	}
	private function UpdateAllModifiedProperties(triggersEvaluation:Bool):Void
	{
		properties.UpdateAllModifiedProperties(triggersEvaluation);
	}
	// #endregion

	// #region 属性接口实现 (Entity_Properties.cs)
	public function GetFallbackProperty(name:IPropertyKey, value:{value:Dynamic}):Bool
	{
		if (Definition == null)
		{
			value.value = null;
			return false;
		}
		if (Definition.TryGetPropertyObject(name, value))
		{
			return true;
		}

		var behaviourCount = Definition.GetBehaviourCount();
		for (i in 0...behaviourCount)
		{
			var behaviour = Definition.GetBehaviourAt(i);
			if (behaviour.TryGetPropertyObject(name, value))
			{
				return true;
			}
		}
		value.value = null;
		return false;
	}
	public function OnPropertyChanged(name:IPropertyKey, beforeValue:Dynamic, afterValue:Dynamic, triggersEvaluation:Bool):Void
	{
		if (triggersEvaluation)
		{
			// PORT-NOTE: C# `name == ((PropertyKey<float>)EngineEntityProps.MAX_HEALTH)`（隐式转换后比较键值）。
			if (name == EngineEntityProps.MAX_HEALTH)
			{
				var before:Float = GenericHelper.ToGeneric(beforeValue);
				var after:Float = GenericHelper.ToGeneric(afterValue);
				Health = Mathf.Min(after, Health * (after / before));
			}
		}
		Cache.UpdateProperty(this, name, beforeValue, afterValue);
		PostPropertyChanged.dispatch(name, beforeValue, afterValue);
		modifierLibrary.CallPropertyChanged(modifierSource, name);
	}
	// #endregion

	// #region 属性序列化 (Entity_Properties.cs)
	private function LoadPropertiesFromSerializable(seri:SerializableEntity):Void
	{
		properties.LoadFromSerializable(seri.properties);
	}
	// #endregion

	// #region 属性事件 (Entity_Properties.cs)
	public var PostPropertyChanged:FlxTypedSignal<IPropertyKey->Dynamic->Dynamic->Void> = new FlxTypedSignal();
	// #endregion

	// #region 序列化 (Entity_Serialize.cs)
	public function ToSerializable():SerializableEntity
	{
		var seri = new SerializableEntity();
		seri.id = ID;
		seri.time = time;
		seri.initSeed = InitSeed;
		seri.spawnerSource = SpawnerReference;
		seri.state = State;
		seri.rng = RNG.ToSerializable();
		seri.dropRng = DropRNG.ToSerializable();
		seri.target = Target != null ? Target.ID : haxe.Int64.ofInt(0);

		seri.definitionID = Definition.GetID();
		seri.modelID = ModelID;
		seri.parent = Parent != null ? Parent.ID : haxe.Int64.ofInt(0);
		seri.previousPosition = PreviousPosition;
		seri.position = Position;
		seri.velocity = Velocity;
		seri.collisionMaskHostile = CollisionMaskHostile;
		seri.collisionMaskFriendly = CollisionMaskFriendly;
		seri.renderRotation = RenderRotation;
		var conveyorSeeds:Map<String, Int> = new Map();
		for (key in takenConveyorSeeds.keys())
		{
			conveyorSeeds.set(key.toString(), takenConveyorSeeds.get(key));
		}
		seri.takenConveyorSeeds = conveyorSeeds;
		seri.timeout = Timeout;

		// 护盾
		seri.armors = new Map();
		for (key in armorDict.keys())
		{
			var armor = armorDict.get(key);
			if (armor == null)
				continue;
			seri.armors.set(key.toString(), armor.ToSerializable());
		}

		seri.isDead = IsDead;
		seri.lethalDeathInfo = lethalDeathInfo != null ? new SerializableDeathInfo(lethalDeathInfo) : null;
		seri.health = Health;
		seri.isOnGround = IsOnGround;
		seri.properties = properties.ToSerializable();
		seri.buffs = buffs.ToSerializable();
		seri.children = [for (e in children) e != null ? e.ID : haxe.Int64.ofInt(0)];
		seri.takenGridIndexes = [];
		for (grid in takenGrids)
		{
			seri.takenGridIndexes.push(grid.GetIndex());
		}

		WriteAurasToSerializable(seri);
		return seri;
	}
	public static function CreateFromSerializable(seri:SerializableEntity, level:LevelEngine):Null<Entity>
	{
		var definition = level.Content.GetEntityDefinition(seri.definitionID);
		if (definition == null)
		{
			var exception = new MissingDefinitionException('Trying to deserialize an entity with missing definition ${seri.definitionID}.');
			Debug.LogException(exception);
			return null;
		}
		var entity = new Entity(level, seri.id, definition, seri.spawnerSource);
		entity.InitFromSerializable(seri);
		return entity;
	}
	private function InitFromSerializable(seri:SerializableEntity):Void
	{
		State = seri.state;
		RenderRotation = seri.renderRotation;
		takenConveyorSeeds = new Map();
		if (seri.takenConveyorSeeds != null)
		{
			for (key in seri.takenConveyorSeeds.keys())
			{
				takenConveyorSeeds.set(NamespaceID.ParseStrict(key), seri.takenConveyorSeeds.get(key));
			}
		}
		Timeout = seri.timeout;
		time = seri.time;

		// 生命
		IsDead = seri.isDead;
		Health = seri.health;

		// 随机数
		InitSeed = seri.initSeed;
		RNG = seri.rng != null ? RandomGenerator.FromSerializable(seri.rng) : new RandomGenerator(InitSeed);
		DropRNG = seri.dropRng != null ? RandomGenerator.FromSerializable(seri.dropRng) : new RandomGenerator(InitSeed);

		// 增益
		InitBuffsFromSerializable(seri);
		// 模型
		LoadModelFromSerializable(seri);
		// 物理
		LoadPhysicsFromSerializable(seri);
		// 碰撞
		LoadCollisionFromSerializable(seri);
		// 护甲
		InitArmorsFromSerializable(seri);
		// 属性
		LoadPropertiesFromSerializable(seri);
		// 地格
		LoadGridsFromSerializable(seri);
	}
	public function LoadFromSerializable(seri:SerializableEntity):Void
	{
		// 其他实体引用
		LoadEntityReferencesFromSerializable(seri);
		// 光环
		LoadAurasFromSerializable(seri);
		// 增益
		LoadBuffsFromSerializable(seri);
		// 护甲
		LoadArmorsFromSerializable(seri);
		// 加载后更新
		UpdateAfterLoadFinished();
	}
	private function LoadEntityReferencesFromSerializable(seri:SerializableEntity):Void
	{
		Parent = Level.FindEntityByID(seri.parent);
		Target = Level.FindEntityByID(seri.target);
		if (seri.children != null)
		{
			for (id in seri.children)
			{
				var child = Level.FindEntityByID(id);
				if (child != null)
					children.push(child);
			}
		}
		lethalDeathInfo = seri.lethalDeathInfo != null ? new DeathInfo(Level, seri.lethalDeathInfo) : null;
	}
	private function UpdateAfterLoadFinished():Void
	{
		ReevaluateModifierCaches();
		UpdateAllModifiedProperties(false);
		Cache.UpdateAll(this);
	}
	// #endregion

	// #region 事件 (Entity.cs)
	public var PostInit:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	// #endregion

	// #region 属性字段 (Entity.cs / 各 partial 文件)
	public var ID(default, null):Int64;
	public var InitSeed(default, null):Int;
	public var RNG(default, null):RandomGenerator;
	public var DropRNG(default, null):RandomGenerator;
	public var Removed(default, null):Bool;
	public var Definition(default, null):EntityDefinition;
	public var SpawnerReference(default, null):Null<ILevelSourceReference>;
	public var Parent(default, null):Null<Entity>;
	public var Level(default, null):LevelEngine;
	public var RenderRotation:Vector3 = Vector3.zero;

	public var Timeout:Int = -1;
	public var IsDead:Bool;
	public var Health:Float;
	public var Type(default, null):Int;
	public var State:Int;
	public var Target:Null<Entity>;
	// PORT-NOTE: C# `internal EntityCache Cache { get; }` —— Haxe 无 internal，改为 public（逻辑层需要访问）。
	public var Cache(default, null):EntityCache;

	private var time:Int64 = haxe.Int64.ofInt(0);
	private var children:Array<Entity> = [];
	private var takenConveyorSeeds:Map<NamespaceID, Int> = new Map();
	private var lethalDeathInfo:Null<DeathInfo>;
	// #endregion

	// #region 属性字段 (Entity_Armor.cs)
	private var armorDict:Map<NamespaceID, Armor> = new Map();
	// #endregion

	// #region 属性字段 (Entity_Aura.cs)
	private var auras:AuraEffectList = new AuraEffectList();
	// #endregion

	// #region 属性字段 (Entity_Buff.cs)
	private var buffs:BuffList = new BuffList();
	public var Buffs(get, never):IBuffList;
	function get_Buffs():IBuffList
	{
		return buffs;
	}
	// #endregion

	// #region 属性字段 (Entity_Collision.cs)
	public var CollisionMaskHostile:Int;
	public var CollisionMaskFriendly:Int;
	// PORT-NOTE: C# `internal int TypeCollisionFlag { get; }`
	public var TypeCollisionFlag(default, null):Int;
	// #endregion

	// #region 属性字段 (Entity_Grids.cs)
	private var takenGrids:Array<LawnGrid> = [];
	// #endregion

	// #region 属性字段 (Entity_Model.cs)
	public var ModelID(default, null):NamespaceID;
	private var modelInterface:Null<IModelInterface>;
	// #endregion

	// #region 属性字段 (Entity_Modifiers.cs)
	private var modifierLibrary:ModifierLibrary;
	private var modifierSource:EntityModifierSource;
	// #endregion

	// #region 属性字段 (Entity_Physics.cs)
	public var PreviousPosition(default, null):Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；LevelEngine.SpawnSourced 在 Entity.Init()（首个赋值点）之前就 InitEntityCollision，无初值会 null 解引用（GetCollisionRect 崩）
	public var Position(get, set):Vector3;
	function get_Position():Vector3
	{
		return _position;
	}
	function set_Position(value:Vector3):Vector3
	{
		var updates = _position != value;
		_position = value;
		if (updates)
		{
			UpdateCollisionPosition();
		}
		return value;
	}
	public var Velocity:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var IsOnGround(default, null):Bool = true;
	private var _position:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	// #endregion

	// #region 属性字段 (Entity_Properties.cs)
	private var properties:PropertyBlock;
	// #endregion
}

// Ported from: Assets/Scripts/Engine/Level/Entities/Entity_Modifiers.cs (IModifierSource 适配器)
// PORT-NOTE: 见 Entity 类声明处的 PORT-NOTE。
private class EntityModifierSource implements IModifierSource
{
	public function new(entity:Entity)
	{
		this.entity = entity;
	}
	public function GetProperty<T>(name:PropertyKey<T>):Null<T>
	{
		return entity.GetProperty(name);
	}
	private var entity:Entity;
}

// C# 用对象初始化器构造 pvzengine.callbacks 下的 Params（结构体默认构造器）；
// Haxe 侧这些类未声明构造函数，无法 `new`，故用本辅助方法生成实例后逐字段赋值。
// TODO-PORT: 若 pvzengine.callbacks 的 Params 类补上 `public function new() {}`，可改回直接的 new 写法。
private inline function CreateParams<T>(cls:Class<T>):T
{
	return Type.createEmptyInstance(cls);
}

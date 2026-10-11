// Ported from: Assets/Scripts/Engine/Level/Level/LevelEngine.cs
//             以及同目录的 LevelEngine_Buff.cs / LevelEngine_Collision.cs / LevelEngine_Conveyor.cs /
//             LevelEngine_Energy.cs / LevelEngine_Entities.cs / LevelEngine_Grids.cs / LevelEngine_Modifiers.cs /
//             LevelEngine_Progress.cs / LevelEngine_Properties.cs / LevelEngine_Random.cs / LevelEngine_SeedPack.cs /
//             LevelEngine_Serialize.cs / LevelEngine_Triggers.cs
//
// PORT-NOTE: C# 的 partial class 分部类无法跨文件实现，按 PORTING.md §partial class 合并为本文件，
//   各 region 前的 `// ===== <文件名>.cs =====` 标注该段来自哪个 C# 文件，成员顺序与原文件一致。
//
// PORT-NOTE: C# 中作用在 LevelEngine 上的扩展方法（EngineAreaProps / EngineLevelProps / EngineStageProps /
//   BuffTargetExt，以及 mvz2logic / mvz2 层的 LogicLevelExt / LogicLevelProps / LogicAreaProps /
//   LogicStageProps / VanillaLevelExt）被既有上层代码以「实例方法」形式调用，且这些调用点所在文件多数
//   没有写 `using <扩展类>`（如 mvz2/level/LevelController.hx 的 `level.GetMoney()` /
//   `level.OnEntitySpawn.add(...)`、mvz2/gamecontent/commands/Cheat.hx 的 `level.HasBuff(...)`）。
//   按移植层既有做法（见 pvzengine.grids.LawnGrid、pvzengine.seedpacks.SeedPack），用 `@:using` 把这些
//   静态扩展挂到本类上，从而同时支持 `Ext.Foo(level, ...)` 与 `level.Foo(...)` 两种写法。
//
// PORT-NOTE: C# 的多个重载在 Haxe 中合并为「单方法名 + Dynamic 形参 + 运行期分派」：
//   Spawn / SpawnSourced / FindEntities / FindFirstEntity / EntityExists / GetEntityCount / GetGrid /
//   GetGroundY / GetRandomEnemySpawnLane / AddTrigger / CreateBuff / GetSeedPackIndex /
//   GetConveyorSeedPackIndex。分派依据见各方法上的 PORT-NOTE。
//
// PORT-NOTE: C# 的 `SortedDictionary<long, Entity>` 用 haxe.ds.BalancedTree<Int, Entity> 表达
//   （按键升序迭代，等价）；键为 haxe.Int64.toInt(id)（关卡内实体 ID 从 1 递增，不会超出 Int 范围）。
package pvzengine.level;

import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Int64;
import pvzengine.IGameContent;
import pvzengine.IGameTriggerSystem;
import pvzengine.IPropertyKey;
import pvzengine.NamespaceID;
import pvzengine.PropertyKey;
import pvzengine.base.ArrayBuffer;
import pvzengine.base.MissingDefinitionException;
import pvzengine.base.MissingSerializeDataException;
import pvzengine.buffs.Buff;
import pvzengine.buffs.BuffDefinition;
import pvzengine.buffs.BuffList;
import pvzengine.buffs.BuffReference;
import pvzengine.buffs.BuffReference.BuffReferenceLevel;
import pvzengine.buffs.BuffTargetExt;
import pvzengine.buffs.IBuffList;
import pvzengine.buffs.IBuffTarget;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.CallbackType;
import pvzengine.callbacks.ITrigger;
import pvzengine.callbacks.LevelCallbackParams;
import pvzengine.callbacks.LevelCallbacks;
// PORT-NOTE: PostGameOverParams / PostWaveParams 等是模块 pvzengine.callbacks.LevelCallbacks 的子类型，
// 跨模块引用须按 `模块.子类型` 形式 import（同 mvz2logic/level/LogicLevelExt.hx 的既有做法）。
import pvzengine.callbacks.LevelCallbacks.PostGameOverParams;
import pvzengine.callbacks.Trigger;
import pvzengine.collisions.ColliderConstructor;
import pvzengine.collisions.IEntityCollider;
import pvzengine.collisions.level.ICollisionSystem;
import pvzengine.collisions.level.ISerializableCollisionSystem;
import pvzengine.collisions.level.OverlapParams;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityDefinition;
import pvzengine.entities.EntitySourceReference;
import pvzengine.entities.SerializableEntity;
import pvzengine.grids.LawnGrid;
import pvzengine.modifiers.IModifierProvider;
import pvzengine.modifiers.IModifierSource;
import pvzengine.modifiers.ModifierLibrary;
import pvzengine.modifiers.ModifierSourceItem;
// PORT-NOTE: C# 的 PropertyBlock 命名空间为 PVZEngine.Level，实现位于 pvzengine/level/PropertyBlock.hx，
// 与本文件同包，无需 import。
import pvzengine.seedpacks.ClassicSeedPack;
import pvzengine.seedpacks.ConveyorSeedPack;
import pvzengine.seedpacks.EngineSeedProps;
import pvzengine.seedpacks.SeedPack;
import pvzengine.seedpacks.SerializableSeedPack.SerializableClassicSeedPack;
import pvzengine.seedpacks.SerializableSeedPack.SerializableConveyorSeedPack;
// PORT-NOTE: SerializableDelayedEnergy 与 SerializableLevel 同处模块 pvzengine.level.SerializableLevel，
// 跨模块引用须按 `模块.子类型` 形式 import。
import pvzengine.level.SerializableLevel.SerializableDelayedEnergy;
import tools.LinqHelper;
import tools.RandomGenerator;
import tools.mathematics.MathTool;
import unity.Debug;
import unity.Mathf;
import unity.Vector2Int;
import unity.Vector3;
import unity.UnityObject;
using pvzengine.ContentProviderHelper;

@:using(pvzengine.buffs.BuffTargetExt)
@:using(pvzengine.level.EngineAreaProps)
@:using(pvzengine.level.EngineLevelProps)
@:using(pvzengine.level.EngineStageProps)
@:using(mvz2logic.level.LogicAreaProps)
@:using(mvz2logic.level.LogicLevelExt)
@:using(mvz2logic.level.LogicLevelProps)
@:using(mvz2logic.level.LogicStageProps)
@:using(mvz2.vanilla.level.VanillaLevelExt)
class LevelEngine implements IBuffTarget implements IModifierProvider
{
	// ===================== LevelEngine.cs =====================

	// #region 构造器
	public function new(contentProvider:IGameContent, triggers:IGameTriggerSystem, collisionSystem:ICollisionSystem)
	{
		Content = contentProvider;
		Triggers = triggers;
		InitBuffList();
		propertyTarget = new LevelPropertyTarget(this);
		properties = new PropertyBlock(propertyTarget, [this, buffs]);
		modifierLibrary = new ModifierLibrary();
		modifierSource = new LevelModifierSource(this);
		modifierLibrary.OnModifiedPropertyNeedsUpdate.add(OnModifiedPropertyNeedsUpdateCallback);
		this.collisionSystem = collisionSystem;
	}
	public function Dispose():Void
	{
		RemoveTriggers(addedTriggers);
	}
	// #endregion

	// #region 组件
	public function AddComponent(component:ILevelComponent):Void
	{
		component.PostAttach(this);
		levelComponents.push(component);
	}
	public function GetComponents():Array<ILevelComponent>
	{
		return levelComponents.copy();
	}
	// PORT-NOTE: C# 泛型方法 GetComponent<T>() where T : ILevelComponent，按工程既有约定
	// （同 unity.GameObject.GetComponent、IGameContent.GetDefinition）改为传入类型对象：
	// 既有调用点写作 `level.GetComponent(IHeldItemComponent)`。
	public function GetComponent<T:ILevelComponent>(typeClass:Class<T>):Null<T>
	{
		for (comp in levelComponents)
		{
			if (Std.isOfType(comp, typeClass))
				return cast comp;
		}
		return null;
	}
	// #endregion

	// #region 生命周期
	public function Init(areaId:NamespaceID, stageId:NamespaceID, option:LevelOption, seed:Int = 0):Void
	{
		Option = option;
		InitRandom(seed);

		ChangeArea(areaId);
		ChangeStage(stageId);

		Energy = EngineLevelProps.GetStartEnergy(this);

		InitGrids(AreaDefinition);
	}
	public function Setup():Void
	{
		AreaDefinition.Setup(this);
		StageDefinition.Setup(this);
		Triggers.RunCallback(LevelCallbacks.POST_LEVEL_SETUP, new LevelCallbackParams(this));
	}
	public function Start():Void
	{
		for (component in levelComponents)
		{
			component.OnStart();
		}
		StageDefinition.Start(this);
		Triggers.RunCallback(LevelCallbacks.POST_LEVEL_START, new LevelCallbackParams(this));
	}
	public function SetDifficulty(difficulty:NamespaceID):Void
	{
		Difficulty = difficulty;
	}
	public function ChangeStage(stageId:NamespaceID):Void
	{
		var definition = Content.GetStageDefinition(stageId);
		if (definition != null)
		{
			var oldDefinition = StageDefinition;
			if (oldDefinition != null)
			{
				modifierLibrary.RemoveModifierCaches([for (m in oldDefinition.GetModifiers()) new ModifierSourceItem(modifierSource, m)]);
			}

			StageID = stageId;
			StageDefinition = definition;
			properties.ClearFallbackCaches();

			modifierLibrary.AddModifierCaches([for (m in definition.GetModifiers()) new ModifierSourceItem(modifierSource, m)]);
		}
		else
		{
			var exception = new MissingDefinitionException('Trying to set a missing stage definition ${stageId} to the LevelEngine.');
			Debug.LogException(exception);
		}
	}
	public function ChangeArea(areaId:NamespaceID):Void
	{
		var definition = Content.GetAreaDefinition(areaId);
		if (definition != null)
		{
			// PORT-NOTE: 原文如此——C# 这里取的同样是 StageDefinition（不是 AreaDefinition），此处保持 1:1。
			var oldDefinition = StageDefinition;
			if (oldDefinition != null)
			{
				modifierLibrary.RemoveModifierCaches([for (m in oldDefinition.GetModifiers()) new ModifierSourceItem(modifierSource, m)]);
			}

			AreaID = areaId;
			AreaDefinition = definition;
			properties.ClearFallbackCaches();

			modifierLibrary.AddModifierCaches([for (m in definition.GetModifiers()) new ModifierSourceItem(modifierSource, m)]);
		}
		else
		{
			var exception = new MissingDefinitionException('Trying to set a missing area definition ${areaId} to the LevelEngine.');
			Debug.LogException(exception);
		}
	}
	public function Update():Void
	{
		ClearEntityTrash();

		var rechargeSpeed = EngineLevelProps.GetRechargeSpeed(this);
		UpdateClassicSeedPacks(rechargeSpeed);
		UpdateConveyorSeedPacks(rechargeSpeed);

		for (component in levelComponents)
		{
			component.Update();
		}

		UpdateDelayedEnergyEntities();
		UpdateGrids();
		UpdateEntities();
		CollisionUpdate();

		buffs.Update();
		AreaDefinition.Update(this);
		StageDefinition.Update(this);
		Triggers.RunCallback(LevelCallbacks.POST_LEVEL_UPDATE, new LevelCallbackParams(this));
		AddLevelTime();
	}
	// #endregion

	// #region 时间
	public function GetSecondTicks(second:Float):Int
	{
		return Mathf.CeilToInt(second * TPS);
	}
	// #endregion

	// #region 引用计数
	public function IncreaseLevelObjectReference(obj:ILevelObject, loadLevel:Bool = false):Void
	{
		if (levelObjectReferences.exists(obj))
		{
			levelObjectReferences.set(obj, levelObjectReferences.get(obj) + 1);
		}
		else
		{
			levelObjectReferences.set(obj, 1);
			// 加载关卡的过程中不触发加入关卡事件
			if (!loadLevel)
			{
				obj.OnAddToLevel(this);
			}
		}
		for (child in obj.GetChildrenObjects())
		{
			IncreaseLevelObjectReference(child, loadLevel);
		}
	}
	public function IncreaseLevelObjectChildReference(parent:ILevelObject, child:ILevelObject, loadLevel:Bool = false):Void
	{
		if (parent == this || HasLevelObjectReference(parent))
		{
			IncreaseLevelObjectReference(child, loadLevel);
		}
	}
	public function DecreaseLevelObjectReference(obj:ILevelObject):Void
	{
		if (levelObjectReferences.exists(obj))
		{
			var count = levelObjectReferences.get(obj) - 1;
			if (count <= 0)
			{
				levelObjectReferences.remove(obj);
				for (child in obj.GetChildrenObjects())
				{
					DecreaseLevelObjectReference(child);
				}
				obj.OnRemoveFromLevel(this);
			}
			else
			{
				levelObjectReferences.set(obj, count);
			}
		}
	}
	public function DecreaseLevelObjectChildReference(parent:ILevelObject, child:ILevelObject):Void
	{
		if (parent == this || HasLevelObjectReference(parent))
		{
			DecreaseLevelObjectReference(child);
		}
	}
	public function HasLevelObjectReference(obj:ILevelObject):Bool
	{
		return levelObjectReferences.exists(obj);
	}
	// #endregion

	// #region ILevelObject接口实现
	// PORT-NOTE: C# 的显式接口实现（`LevelEngine ILevelObject.GetLevel()` 等）在 Haxe 中只能写成普通公开方法
	//（同 pvzengine.grids.LawnGrid、pvzengine.entities.Entity）。
	public function GetLevel():LevelEngine return this;
	public function GetEntity():Null<Entity> return null;
	public function Exists():Bool return true;
	public function OnAddToLevel(level:LevelEngine):Void
	{
	}
	public function OnRemoveFromLevel(level:LevelEngine):Void
	{
	}
	public function GetChildrenObjects():Array<ILevelObject>
	{
		var result:Array<ILevelObject> = [];
		for (obj in levelObjectReferences.keys())
		{
			result.push(obj);
		}
		return result;
	}
	// #endregion

	// #region 属性字段
	public var Content(default, null):IGameContent;
	public var StageID(default, null):NamespaceID;
	public var StageDefinition(default, null):StageDefinition;
	public var AreaID(default, null):NamespaceID;
	public var AreaDefinition(default, null):AreaDefinition;
	public var Difficulty:NamespaceID;
	public var IsRerun:Bool;
	public var TPS(get, never):Int;
	inline function get_TPS():Int return Option.TPS;
	public var Option(default, null):LevelOption;

	private var levelComponents:Array<ILevelComponent> = [];
	private var levelObjectReferences:Map<ILevelObject, Int> = new Map();
	// #endregion

	// ===================== LevelEngine_Triggers.cs =====================

	// #region 公有方法
	// PORT-NOTE: C# 有两个 AddTrigger 重载：AddTrigger<TArgs>(Trigger<TArgs>) 与
	//   AddTrigger<TArgs>(CallbackType<TArgs>, Action<TArgs, CallbackResult>, int, object?)。
	//   Haxe 无重载，保留既有调用点使用的后者（`level.AddTrigger(LevelCallbacks.POST_WAVE_FINISHED, cb)`），
	//   前者改名为 AddTriggerObject。
	public function AddTrigger<TArgs>(callbackID:CallbackType<TArgs>, action:TArgs->CallbackResult->Void, priority:Int = 0, filter:Dynamic = null):Void
	{
		AddTriggerObject(new Trigger<TArgs>(callbackID, action, priority, filter));
	}
	public function AddTriggerObject(trigger:ITrigger):Void
	{
		Triggers.AddTrigger(trigger);
		addedTriggers.push(trigger);
	}
	public function RemoveTrigger(trigger:ITrigger):Bool
	{
		if (Triggers.RemoveTrigger(trigger))
		{
			addedTriggers.remove(trigger);
			return true;
		}
		return false;
	}
	public function RemoveTriggers(triggers:Iterable<ITrigger>):Int
	{
		var value = 0;
		for (trigger in Lambda.array(triggers))
		{
			value += RemoveTrigger(trigger) ? 1 : 0;
		}
		return value;
	}
	// #endregion

	// #region 属性字段
	public var Triggers(default, null):IGameTriggerSystem;
	private var addedTriggers:Array<ITrigger> = [];
	// #endregion

	// ===================== LevelEngine_Energy.cs =====================

	public function SetEnergy(value:Float):Void
	{
		Energy = Mathf.Clamp(value, 0, Option.MaxEnergy);
	}
	public function AddEnergy(value:Float):Void
	{
		SetEnergy(Energy + value);
	}
	public function AddEnergyDelayed(source:Entity, value:Float):Void
	{
		if (value == 0)
			return;
		var before = Energy;
		AddEnergy(value);
		var added = Energy - before;
		delayedEnergyEntities.set(source, added);
	}
	public function RemoveEnergyDelayedEntity(entity:Entity):Bool
	{
		return delayedEnergyEntities.remove(entity);
	}
	public function ClearEnergyDelayedEntities():Void
	{
		delayedEnergyEntities.clear();
	}
	public function GetDelayedEnergy():Float
	{
		var sum = 0.0;
		for (value in delayedEnergyEntities)
		{
			sum += value;
		}
		return sum;
	}
	private function UpdateDelayedEnergyEntities():Void
	{
		var entities = [for (e in delayedEnergyEntities.keys()) if (!unity.UnityObject.exists(e)) e];
		for (entity in entities)
		{
			delayedEnergyEntities.remove(entity);
		}
	}
	public var Energy(default, null):Float;
	private var delayedEnergyEntities:Map<Entity, Float> = new Map();
	// #endregion

	// ===================== LevelEngine_Properties.cs =====================

	// #region 属性
	// PORT-NOTE: C# 的 `GetProperty<T>(PropertyKey<T> name, bool ignoreBuffs = false)` 既要满足既有调用点，
	//   又要满足 IModifierSource 的单参签名；Haxe 不允许用「多一个可选参数」的方法实现接口方法
	//   （会报 Different number of function arguments），故与 pvzengine.entities.Entity 采用同一方案：
	//   保留 C# 的双参形式，IModifierSource 由内部适配器 LevelModifierSource 承担。
	public function GetProperty<T>(name:PropertyKey<T>, ignoreBuffs:Bool = false):Null<T>
	{
		return properties.GetProperty(name, ignoreBuffs);
	}
	public function TryGetProperty<T>(name:PropertyKey<T>, value:Dynamic, ignoreBuffs:Bool = false):Bool
	{
		return properties.TryGetProperty(name, value, ignoreBuffs);
	}
	public function SetProperty<T>(name:PropertyKey<T>, value:Null<T>):Void
	{
		properties.SetProperty(name, value);
	}
	private function UpdateAllModifiedProperties(triggersEvaluation:Bool):Void
	{
		properties.UpdateAllModifiedProperties(triggersEvaluation);
	}
	// #endregion

	// #region 接口实现
	// PORT-NOTE: C# 中 LevelEngine 直接实现 IModifiablePropertyTarget，同时还有
	//   `public event Action<IPropertyKey, object?, object?, bool>? OnPropertyChanged` 事件——C# 用「显式接口实现」
	//   让接口方法与事件同名共存；Haxe 不允许同名成员共存。
	//   为同时保住 C# 的两个公开名（既有调用点 mvz2/level/LevelController.hx:1910 使用
	//   `level.OnPropertyChanged.add(...)`，接口的 OnPropertyChanged 又必须存在），与
	//   pvzengine.entities.Entity 的 EntityModifierSource 采用同一方案：用一个内部适配器
	//   （LevelPropertyTarget）承担 IModifiablePropertyTarget，LevelEngine 仍暴露同名事件。
	// #endregion

	// #region 序列化
	private function WritePropertiesToSerializable(seri:SerializableLevel):Void
	{
		seri.properties = properties.ToSerializable();
	}
	private function ReadPropertiesFromSerializable(seri:SerializableLevel):Void
	{
		properties.LoadFromSerializable(seri.properties);
	}
	// #endregion

	// #region 事件
	public var OnPropertyChanged:FlxTypedSignal<IPropertyKey->Dynamic->Dynamic->Bool->Void> = new FlxTypedSignal();
	// #endregion

	// #region 属性字段
	// PORT-NOTE: C# 为 `private PropertyBlock properties;`，其 container 是 LevelEngine 自身；
	// Haxe 中 container 用适配器 propertyTarget（见上面的说明）。
	private var properties:PropertyBlock;
	private var propertyTarget:LevelPropertyTarget;
	// #endregion

	// ===================== LevelEngine_Modifiers.cs =====================

	private function ReevaluateModifierCaches():Void
	{
		modifierLibrary.ClearModifierCaches();
		modifierLibrary.AddModifierCaches([for (m in AreaDefinition.GetModifiers()) new ModifierSourceItem(modifierSource, m)]);
		modifierLibrary.AddModifierCaches([for (m in StageDefinition.GetModifiers()) new ModifierSourceItem(modifierSource, m)]);
	}
	private function OnModifiedPropertyNeedsUpdateCallback(name:IPropertyKey):Void
	{
		OnModifiedPropertyNeedsUpdate.dispatch(name);
	}
	// PORT-NOTE: C# 的显式实现 `T? IModifierSource.GetProperty<T>(PropertyKey<T>)` 由上面的
	//   GetProperty<T>(name, ignoreBuffs = false) 承担（同 pvzengine.entities.Entity.hx 的既有做法）。
	public function GetModifiedProperties():Array<IPropertyKey>
	{
		return modifierLibrary.GetModifyPropertyKeys();
	}
	public function GetModifiersForProperty(name:IPropertyKey, results:Array<ModifierSourceItem>):Void
	{
		modifierLibrary.GetModifierItemsForProperty(name, results);
	}
	public var OnModifiedPropertyNeedsUpdate:FlxTypedSignal<IPropertyKey->Void> = new FlxTypedSignal();
	private var modifierLibrary:ModifierLibrary;
	// PORT-NOTE: C# 中 LevelEngine 自身实现 IModifierSource（显式实现转发到 GetProperty(name)）。
	// Haxe 中 LevelEngine 的 GetProperty 是 C# 的双参形式（ignoreBuffs 有默认值），无法同时满足
	// IModifierSource 的单参签名，故与 pvzengine.entities.Entity 采用同一方案：
	// 用内部适配器 LevelModifierSource 承担 IModifierSource，ModifierSourceItem / ModifierLibrary 都用它。
	private var modifierSource:LevelModifierSource;
	// #endregion

	// ===================== LevelEngine_Buff.cs =====================

	// #region 增益
	public function GetBuffReference(buff:Buff):BuffReference
	{
		return new BuffReferenceLevel(buff.ID);
	}
	// PORT-NOTE: C# 泛型重载 CreateBuff<T>(long buffID) 在 Haxe 中无法由类型参数取定义，
	// 按工程既有约定改为传入类型对象，并改名为 CreateBuffFromType 以避开下面的重载合并。
	public function CreateBuffFromType<T:BuffDefinition>(typeClass:Class<T>, buffID:Int64):Buff
	{
		var buffDefinition = Content.GetBuffDefinitionByType(typeClass);
		return CreateBuffObject(buffDefinition, buffID);
	}
	// PORT-NOTE: C# 的 CreateBuff(NamespaceID, long) 与 CreateBuff(BuffDefinition, long) 合并为
	//   单方法 + Dynamic 形参分派（既有调用点无 CreateBuff 调用，仅内部/未来使用）。
	public function CreateBuff(key:Dynamic, buffID:Int64):Buff
	{
		if (Std.isOfType(key, BuffDefinition))
		{
			return CreateBuffObject(cast key, buffID);
		}
		var definition = Content.GetBuffDefinition(key);
		if (definition == null)
			throw new MissingDefinitionException('Trying to create a buff with missing definition ${key}');
		return CreateBuffObject(definition, buffID);
	}
	private function CreateBuffObject(buffDef:BuffDefinition, buffID:Int64):Buff
	{
		return new Buff(this, buffDef, buffID);
	}
	private function InitBuffList():Void
	{
	}
	// #endregion

	// #region 序列化
	private function WriteBuffsToSerializable(seri:SerializableLevel):Void
	{
		seri.buffs = buffs.ToSerializable();
	}
	private function InitBuffsFromSerializable(seri:SerializableLevel):Void
	{
		buffs.InitFromSerializable(seri.buffs, this, this);
	}
	private function LoadBuffsFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.buffs != null)
		{
			buffs.LoadFromSerializable(seri.buffs);
			// 关卡拥有的所有BUFF引用计数+1
			for (buff in buffs)
			{
				IncreaseLevelObjectReference(buff, true);
			}
		}
	}
	// #endregion

	// #region 属性字段
	public var Buffs(get, never):IBuffList;
	function get_Buffs():IBuffList return buffs;

	private var buffs:BuffList = new BuffList();
	// #endregion

	// ===================== LevelEngine_Collision.cs =====================

	// #region 碰撞检测
	private function InitEntityCollision(entity:Entity):Void
	{
		collisionSystem.InitEntity(entity);
	}
	private function RemoveEntityCollision(entity:Entity):Void
	{
		collisionSystem.DestroyEntity(entity);
	}
	public function UpdateEntityCollisionDetection(entity:Entity):Void
	{
		collisionSystem.UpdateEntityDetection(entity);
	}
	public function UpdateEntityCollisionPosition(entity:Entity):Void
	{
		collisionSystem.UpdateEntityPosition(entity);
	}
	public function UpdateEntityCollisionSize(entity:Entity):Void
	{
		collisionSystem.UpdateEntitySize(entity);
	}
	public function OverlapBox(center:Vector3, size:Vector3, param:OverlapParams):Array<IEntityCollider>
	{
		return collisionSystem.OverlapBox(center, size, param);
	}
	public function OverlapBoxNonAlloc(center:Vector3, size:Vector3, param:OverlapParams, results:Array<IEntityCollider>):Void
	{
		collisionSystem.OverlapBoxNonAlloc(center, size, param, results);
	}
	public function OverlapSphere(center:Vector3, radius:Float, param:OverlapParams):Array<IEntityCollider>
	{
		return collisionSystem.OverlapSphere(center, radius, param);
	}
	public function OverlapSphereNonAlloc(center:Vector3, radius:Float, param:OverlapParams, results:Array<IEntityCollider>):Void
	{
		collisionSystem.OverlapSphereNonAlloc(center, radius, param, results);
	}
	public function OverlapCapsule(point0:Vector3, point1:Vector3, radius:Float, param:OverlapParams):Array<IEntityCollider>
	{
		return collisionSystem.OverlapCapsule(point0, point1, radius, param);
	}
	public function OverlapCapsuleNonAlloc(point0:Vector3, point1:Vector3, radius:Float, param:OverlapParams, results:Array<IEntityCollider>):Void
	{
		collisionSystem.OverlapCapsuleNonAlloc(point0, point1, radius, param, results);
	}
	public function AddEntityCollider(entity:Entity, info:ColliderConstructor):Null<IEntityCollider>
	{
		return collisionSystem.CreateCustomCollider(entity, info);
	}
	public function RemoveEntityCollider(entity:Entity, name:String):Bool
	{
		return collisionSystem.RemoveCollider(entity, name);
	}
	public function GetEntityCollider(entity:Entity, name:String):Null<IEntityCollider>
	{
		return collisionSystem.GetCollider(entity, name);
	}
	public function GetEntityCurrentCollisions(entity:Entity, collisions:Array<EntityCollision>):Void
	{
		collisionSystem.GetCurrentCollisions(entity, collisions);
	}
	// #endregion

	// #region 碰撞
	private function CollisionUpdate():Void
	{
		collisionSystem.Update();
	}
	// #endregion

	// #region 序列化
	private function WriteCollisionToSerializable(seri:SerializableLevel):Void
	{
		seri.collisionSystem = collisionSystem.ToSerializable();
	}
	private function ReadCollisionFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.collisionSystem != null)
			collisionSystem.LoadFromSerializable(this, seri.collisionSystem);
	}
	// #endregion

	private var collisionSystem:ICollisionSystem;

	// ===================== LevelEngine_Random.cs =====================

	// #region 随机数
	public function CreateRNG():RandomGenerator
	{
		return new RandomGenerator(levelRandom.NextInt());
	}
	public function GetSpawnRNG():RandomGenerator
	{
		return spawnRandom;
	}
	public function GetRoundRNG():RandomGenerator
	{
		return roundRandom;
	}
	public function GetConveyorRNG():RandomGenerator
	{
		return conveyorRandom;
	}
	public function NewEntitySeed():Int
	{
		return entityRandom.NextInt();
	}
	// #endregion
	public function InitRandom(seed:Int):Void
	{
		// PORT-NOTE: C# 为 `seed == 0 ? Guid.NewGuid().GetHashCode() : seed`。
		// Haxe 无 Guid，改用等价的「随机非零种」实现（Std.random 的取值范围内不包含 0 以外的约束差异可忽略）。
		Seed = seed == 0 ? Std.random(0x7FFFFFFF) : seed;
		levelRandom = new RandomGenerator(Seed);
		entityRandom = CreateRNG();
		effectRandom = CreateRNG();
		roundRandom = CreateRNG();
		spawnRandom = CreateRNG();
		conveyorRandom = CreateRNG();

		miscRandom = CreateRNG();
	}
	public function WriteRandomToSerializable(level:SerializableLevel):Void
	{
		level.seed = Seed;
		level.levelRandom = levelRandom.ToSerializable();
		level.entityRandom = entityRandom.ToSerializable();
		level.effectRandom = effectRandom.ToSerializable();
		level.roundRandom = roundRandom.ToSerializable();
		level.spawnRandom = spawnRandom.ToSerializable();
		level.conveyorRandom = conveyorRandom.ToSerializable();
		level.miscRandom = miscRandom.ToSerializable();
	}
	public function ReadRandomFromSerializable(seri:SerializableLevel):Void
	{
		Seed = seri.seed;
		levelRandom = seri.levelRandom != null ? RandomGenerator.FromSerializable(seri.levelRandom) : new RandomGenerator(Seed);
		entityRandom = seri.entityRandom != null ? RandomGenerator.FromSerializable(seri.entityRandom) : new RandomGenerator(Seed);
		effectRandom = seri.effectRandom != null ? RandomGenerator.FromSerializable(seri.effectRandom) : new RandomGenerator(Seed);
		roundRandom = seri.roundRandom != null ? RandomGenerator.FromSerializable(seri.roundRandom) : new RandomGenerator(Seed);
		spawnRandom = seri.spawnRandom != null ? RandomGenerator.FromSerializable(seri.spawnRandom) : new RandomGenerator(Seed);
		conveyorRandom = seri.conveyorRandom != null ? RandomGenerator.FromSerializable(seri.conveyorRandom) : new RandomGenerator(Seed);
		miscRandom = seri.miscRandom != null ? RandomGenerator.FromSerializable(seri.miscRandom) : new RandomGenerator(Seed);
	}
	public var Seed(default, null):Int;
	private var levelRandom:RandomGenerator;

	private var entityRandom:RandomGenerator;
	private var effectRandom:RandomGenerator;

	private var roundRandom:RandomGenerator;
	private var spawnRandom:RandomGenerator;
	private var conveyorRandom:RandomGenerator;

	private var miscRandom:RandomGenerator;

	// ===================== LevelEngine_Progress.cs =====================

	// #region 关卡时间
	public function GetLevelTime():Int64
	{
		return levelTime;
	}
	private function AddLevelTime():Void
	{
		levelTime++;
	}
	// PORT-NOTE: C# 的 `long interval, long offset = 0` 在 Haxe 中无法写常量默认值（haxe.Int64 的默认值
	// 必须是常量），故把 offset 改为可空参数，缺省时按 0 处理。
	public function IsTimeInterval(interval:Int64, ?offset:Null<Int64>):Bool
	{
		var off = offset == null ? Int64.ofInt(0) : offset;
		return levelTime % interval == off;
	}
	// #endregion

	// #region 关卡事件
	public function PrepareForBattle():Void
	{
		StageDefinition.PrepareForBattle(this);
		var param = new LevelCallbackParams(this);
		Triggers.RunCallback(LevelCallbacks.POST_PREPARE_FOR_BATTLE, param);
	}
	public function RunFinalWaveEvent():Void
	{
		StageDefinition.PostFinalWaveEvent(this);
		var param = new LevelCallbackParams(this);
		Triggers.RunCallback(LevelCallbacks.POST_FINAL_WAVE_EVENT, param);
	}
	public function RunHugeWaveEvent():Void
	{
		StageDefinition.PostHugeWaveEvent(this);
		var param = new LevelCallbackParams(this);
		Triggers.RunCallback(LevelCallbacks.POST_HUGE_WAVE_EVENT, param);
	}
	// #endregion

	// #region 已生成的怪物
	public function AddSpawnedEnemyID(enemyId:NamespaceID):Void
	{
		if (IsEnemySpawned(enemyId))
			return;
		spawnedID.push(enemyId);
	}
	public function RemoveSpawnedEnemyID(enemyId:NamespaceID):Bool
	{
		return spawnedID.remove(enemyId);
	}
	public function GetSpawnedEnemiesID():Array<NamespaceID>
	{
		return spawnedID.copy();
	}
	public function IsEnemySpawned(enemyId:NamespaceID):Bool
	{
		return spawnedID.contains(enemyId);
	}
	// #endregion

	// #region 随机行
	// PORT-NOTE: C# 的 GetRandomEnemySpawnLane() / GetRandomEnemySpawnLane(IEnumerable<int>)
	// 合并为一个带可选参数的 Haxe 方法。
	public function GetRandomEnemySpawnLane(?lanes:Iterable<Int>):Int
	{
		if (lanes == null)
		{
			var length = GetMaxLaneCount();
			return GetRandomEnemySpawnLane([for (i in 0...length) i]);
		}
		var laneList = Lambda.array(lanes);
		if (laneList.length <= 0)
			return -1;
		var possibleLanes = Lambda.filter(laneList, l -> !spawnedLanes.contains(l));
		if (possibleLanes.length <= 0)
		{
			spawnedLanes.resize(0);
			possibleLanes = laneList;
		}
		var row = LinqHelper.Random(possibleLanes, GetSpawnRNG());
		spawnedLanes.push(row);
		return row;
	}
	// #endregion

	// #region 游戏结束
	public function Clear():Void
	{
		IsCleared = true;
		OnClear.dispatch();
		Triggers.RunCallback(LevelCallbacks.POST_LEVEL_CLEAR, new LevelCallbackParams(this));
	}
	public function GameOver(type:Int, killer:Null<Entity>, message:Null<String>):Void
	{
		KillerEnemy = killer;
		OnGameOver.dispatch(type, killer, message);
		// PORT-NOTE: pvzengine.callbacks 下的 Params 类没有声明构造函数（C# 是结构体默认构造 + 对象初始化器），
		// 与 pvzengine.entities.Entity 的 CreateParams 采用同一方案：Type.createEmptyInstance + 逐字段赋值。
		var param = Type.createEmptyInstance(PostGameOverParams);
		param.level = this;
		param.type = type;
		param.killer = killer;
		param.message = message;
		Triggers.RunCallbackFiltered(LevelCallbacks.POST_GAME_OVER, param, type);
	}
	// #endregion

	// #region 序列化
	private function WriteProgressToSerializable(seri:SerializableLevel):Void
	{
		seri.isCleared = IsCleared;
		seri.levelTime = levelTime;
		seri.spawnedLanes = spawnedLanes;
		seri.spawnedID = spawnedID;
		seri.currentWave = CurrentWave;
		seri.currentFlag = CurrentFlag;
		seri.waveState = WaveState;
		seri.levelProgressVisible = LevelProgressVisible;
	}
	private function ReadProgressFromSerializable(seri:SerializableLevel):Void
	{
		levelTime = seri.levelTime;
		IsCleared = seri.isCleared;
		if (seri.spawnedLanes != null)
			spawnedLanes = seri.spawnedLanes;
		if (seri.spawnedID != null)
			spawnedID = seri.spawnedID;
		CurrentWave = seri.currentWave;
		CurrentFlag = seri.currentFlag;
		WaveState = seri.waveState;
		LevelProgressVisible = seri.levelProgressVisible;
	}
	// #endregion

	public var OnGameOver:FlxTypedSignal<Int->Entity->String->Void> = new FlxTypedSignal();
	public var OnClear:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var CurrentWave:Int;
	public var CurrentFlag:Int;
	public var WaveState:Int;
	public var LevelProgressVisible:Bool;
	public var IsCleared(default, null):Bool;
	public var KillerEnemy(default, null):Null<Entity>;
	// C#: private string? deathMessage;（原文中未被使用）
	private var deathMessage:Null<String>;
	private var levelTime:Int64 = Int64.ofInt(0);
	private var spawnedLanes:Array<Int> = [];
	private var spawnedID:Array<NamespaceID> = [];

	// ===================== LevelEngine_Grids.cs =====================

	// #region 初始化
	private function InitGrids(area:AreaDefinition):Void
	{
		gridWidth = area.GetProperty(EngineAreaProps.GRID_WIDTH);
		gridHeight = area.GetProperty(EngineAreaProps.GRID_HEIGHT);
		gridLeftX = area.GetProperty(EngineAreaProps.GRID_LEFT_X);
		gridBottomZ = area.GetProperty(EngineAreaProps.GRID_BOTTOM_Z);
		entityLaneZOffset = area.GetProperty(EngineAreaProps.ENTITY_LANE_Z_OFFSET);
		maxLaneCount = area.GetProperty(EngineAreaProps.MAX_LANE_COUNT);
		maxColumnCount = area.GetProperty(EngineAreaProps.MAX_COLUMN_COUNT);

		// Initalize current stage info.
		grids = [];
		grids.resize(maxColumnCount * maxLaneCount);

		var layout = area.GetGridLayout();
		for (i in 0...layout.length)
		{
			var id = layout[i];
			if (id == null)
				continue;
			var definition = Content.GetGridDefinition(id);
			if (definition == null)
			{
				var exception = new MissingDefinitionException('Trying to create a grid with missing definition ${id}.');
				Debug.LogException(exception);
				continue;
			}
			var lane = Mathf.FloorToInt(i / maxColumnCount);
			var column = i % maxColumnCount;
			var grid = new LawnGrid(this, definition, lane, column);
			grids[i] = grid;
		}
	}
	// #endregion

	// #region 序列化
	private function WriteGridsToSerializable(level:SerializableLevel):Void
	{
		level.grids = [for (g in grids) g.ToSerializable()];
	}
	private function InitGridsFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.grids == null)
			return;
		var count = Mathf.MinInt(grids.length, seri.grids.length);
		for (i in 0...count)
		{
			grids[i].InitFromSerializable(seri.grids[i]);
		}
	}
	private function ReadGridsFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.grids == null)
			return;
		for (i in 0...grids.length)
		{
			var grid = grids[i];
			var seriGrid = seri.grids[i];
			grid.LoadFromSerializable(seriGrid);
			IncreaseLevelObjectReference(grid, true);
		}
	}
	// #endregion

	// #region 坐标相关方法
	public function GetMaxLaneCount():Int return maxLaneCount;
	public function GetMaxColumnCount():Int return maxColumnCount;
	public function GetGridLeftX():Float return gridLeftX;
	public function GetGridRightX():Float
	{
		return GetGridLeftX() + GetMaxColumnCount() * GetGridWidth();
	}
	public function GetGridBottomZ():Float return gridBottomZ;
	public function GetGridTopZ():Float
	{
		return GetGridBottomZ() + GetMaxLaneCount() * GetGridHeight();
	}
	public function GetGridWidth():Float return gridWidth;
	public function GetGridHeight():Float return gridHeight;
	public function GetNearestEntityLane(z:Float):Int
	{
		return GetLane(z - entityLaneZOffset + GetGridHeight() * 0.5);
	}
	public function GetEntityLaneZ(lane:Int):Float return GetEntityLaneZFloat(lane);
	public function GetLaneCenterZ(lane:Int):Float return GetLaneCenterZFloat(lane);
	public function GetLaneZ(lane:Int):Float return GetLaneZFloat(lane);
	public function GetEntityLaneZFloat(lane:Float):Float
	{
		return GetLaneZFloat(lane) + entityLaneZOffset;
	}
	public function GetLaneCenterZFloat(lane:Float):Float
	{
		return GetLaneZFloat(lane) + GetGridHeight() * 0.5;
	}
	public function GetLaneZFloat(lane:Float):Float
	{
		return GetGridTopZ() - (lane + 1) * GetGridHeight();
	}
	public function GetGridLaneByIndex(index:Int):Int
	{
		return Std.int(index / GetMaxColumnCount());
	}
	public function GetGridColumnByIndex(index:Int):Int
	{
		return index % GetMaxColumnCount();
	}
	public function GetLawnCenterX():Float
	{
		return (GetGridLeftX() + GetGridRightX()) * 0.5;
	}
	public function GetLawnCenterZ():Float
	{
		return (GetGridBottomZ() + GetGridTopZ()) * 0.5;
	}
	public function GetLawnCenter():Vector3
	{
		var x = GetLawnCenterX();
		var z = GetLawnCenterZ();
		var y = GetGroundY(x, z);
		return new Vector3(x, y, z);
	}
	public function GetLane(z:Float):Int
	{
		return Mathf.FloorToInt((GetGridTopZ() - z) / GetGridHeight());
	}
	public function GetColumn(x:Float):Int
	{
		return Mathf.FloorToInt((x - GetGridLeftX()) / GetGridWidth());
	}
	public function GetEntityColumnX(column:Int):Float return GetEntityColumnXFloat(column);
	public function GetColumnCenterX(column:Int):Float return GetColumnCenterXFloat(column);
	public function GetColumnX(column:Int):Float return GetColumnXFloat(column);
	public function GetEntityColumnXFloat(column:Float):Float
	{
		return GetColumnXFloat(column) + GetGridWidth() * 0.5;
	}
	public function GetColumnCenterXFloat(column:Float):Float
	{
		return GetColumnXFloat(column) + GetGridWidth() * 0.5;
	}
	public function GetColumnXFloat(column:Float):Float
	{
		return GetGridLeftX() + column * GetGridWidth();
	}
	public function GetEntityGridPosition(column:Int, lane:Int):Vector3
	{
		var x = GetEntityColumnX(column);
		var z = GetEntityLaneZ(lane);
		var y = GetGroundY(x, z);
		return new Vector3(x, y, z);
	}
	public function GetEntityGridPositionByIndex(index:Int):Vector3
	{
		var column = GetGridColumnByIndex(index);
		var lane = GetGridLaneByIndex(index);
		return GetEntityGridPosition(column, lane);
	}
	// PORT-NOTE: C# 的 GetGroundY(Vector3) 与 GetGroundY(float, float) 两个重载合并为单方法 + Dynamic 分派
	//   （既有调用点两种形式并存：mvz2/gamecontent/bosses/Seija.hx 的 `Level.GetGroundY(pos)`、
	//   mvz2/gamecontent/enemies/ZombieCloud.hx 的 `Level.GetGroundY(position)`，以及大量 `GetGroundY(x, z)`）。
	// PORT-NOTE: unity.Vector3 是 abstract，不能作为运行期值参与 Std.isOfType，
	//   改用其底层类型 unity.Vector3.Vector3Data 判断（yield 与原 overload 分派一致）。
	public function GetGroundY(xOrPos:Dynamic, ?z:Float):Float
	{
		if (Std.isOfType(xOrPos, unity.Vector3.Vector3Data))
		{
			var pos:Vector3 = cast xOrPos;
			return GetGroundYOfPosition(pos.x, pos.z);
		}
		return GetGroundYOfPosition(cast xOrPos, z);
	}
	private function GetGroundYOfPosition(x:Float, z:Float):Float
	{
		return AreaDefinition.GetGroundY(this, x, z);
	}
	// #endregion

	public function UpdateGrids():Void
	{
		for (i in 0...grids.length)
		{
			var grid = grids[i];
			grid.Update();
		}
	}

	// #region 网格
	// PORT-NOTE: C# 有三个 GetGrid 重载：GetGrid(int index) / GetGrid(int column, int lane) / GetGrid(Vector2Int pos)。
	// Haxe 无重载，合并为单方法：第一实参为 Vector2Int 时按坐标查，第二实参缺省时按索引查，否则按 (column, lane) 查。
	public function GetGrid(a:Dynamic, ?lane:Int):Null<LawnGrid>
	{
		if (Std.isOfType(a, Vector2Int))
		{
			var pos:Vector2Int = cast a;
			return GetGrid(pos.x, pos.y);
		}
		var column:Int = cast a;
		if (lane == null)
		{
			if (column < 0 || column >= GetMaxColumnCount() * GetMaxLaneCount())
				return null;
			return grids[column];
		}
		if (column < 0 || column >= GetMaxColumnCount() || lane < 0 || lane >= GetMaxLaneCount())
			return null;
		return GetGrid(lane * GetMaxColumnCount() + column);
	}
	public function GetAllGrids():Array<LawnGrid>
	{
		return grids.copy();
	}
	public function GetGridAt(position:Vector3):Null<LawnGrid>
	{
		var column = GetColumn(position.x);
		var lane = GetLane(position.z);
		return GetGrid(column, lane);
	}
	public function GetGridIndex(column:Int, lane:Int):Int
	{
		return column + lane * GetMaxColumnCount();
	}
	// #endregion

	private var grids:Array<LawnGrid> = [];
	private var gridWidth:Float;
	private var gridHeight:Float;
	private var gridLeftX:Float;
	private var gridBottomZ:Float;
	private var entityLaneZOffset:Float;
	private var maxLaneCount:Int;
	private var maxColumnCount:Int;

	// ===================== LevelEngine_Entities.cs =====================

	private function FindEntityInTrash(id:Int64):Null<Entity>
	{
		return entityTrash.get(Int64.toInt(id));
	}
	private function ClearEntityTrash():Void
	{
		entityTrash.clear();
	}
	private function UpdateEntities():Void
	{
		entityUpdateBuffer.Clear();
		// C#: entities.OrderBy(e => e.Key).Select(e => e.Value)；BalancedTree 本身就按键升序迭代。
		entityUpdateBuffer.CopyFrom([for (e in entities) e]);
		for (i in 0...entityUpdateBuffer.Count)
		{
			var entity = entityUpdateBuffer.Get(i);
			entity.Update();
		}
	}

	private function WriteEntitiesToSerializable(seri:SerializableLevel):Void
	{
		seri.currentEntityID = currentEntityID;
		seri.entities = [for (e in entities) e.ToSerializable()];
		seri.entityTrash = [for (e in entityTrash) e.ToSerializable()];
	}
	private function CreateEntitiesFromSerializable(seri:SerializableLevel):Void
	{
		currentEntityID = seri.currentEntityID;
		if (seri.entities != null)
		{
			for (ent in seri.entities)
			{
				var entity = Entity.CreateFromSerializable(ent, this);
				if (entity != null)
				{
					entities.set(Int64.toInt(ent.id), entity);
				}
			}
		}
		if (seri.entityTrash != null)
		{
			for (ent in seri.entityTrash)
			{
				var entity = Entity.CreateFromSerializable(ent, this);
				if (entity != null)
					entityTrash.set(Int64.toInt(ent.id), entity);
			}
		}
	}
	private function ReadEntitiesFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.entities != null)
		{
			for (i in 0...entitiesCount())
			{
				var seriEnt = seri.entities[i];
				var id = Int64.toInt(seriEnt.id);
				if (entities.exists(id))
				{
					var entity = entities.get(id);
					entity.LoadFromSerializable(seriEnt);
					IncreaseLevelObjectReference(entity, true);
				}
			}
		}
		if (seri.entityTrash != null)
		{
			for (i in 0...entityTrashCount())
			{
				var seriEnt = seri.entityTrash[i];
				var id = Int64.toInt(seriEnt.id);
				if (entityTrash.exists(id))
				{
					var entity = entityTrash.get(id);
					entity.LoadFromSerializable(seriEnt);
				}
			}
		}
	}
	// PORT-NOTE: C# 的循环边界为 `entities.Count` / `entityTrash.Count`（Dictionary 的元素个数），
	// 与之对应的是元素个数而非实体 ID 上界。
	private function entitiesCount():Int
	{
		var count = 0;
		for (e in entities)
			count++;
		return count;
	}
	private function entityTrashCount():Int
	{
		var count = 0;
		for (e in entityTrash)
			count++;
		return count;
	}
	// #region 生成
	private function AllocEntityID():Int64
	{
		var id = currentEntityID;
		currentEntityID++;
		return id;
	}
	// PORT-NOTE: C# 的三个 SpawnSourced 重载合并为单方法：defOrRef 可为 EntityDefinition 或 NamespaceID，
	//   可选 seed 与 param 各自缺省。
	public function SpawnSourced(defOrRef:Dynamic, pos:Vector3, source:Null<ILevelSourceReference>, ?seed:Null<Int>, ?param:Null<SpawnParams>):Null<Entity>
	{
		var entityDef:EntityDefinition = null;
		if (Std.isOfType(defOrRef, EntityDefinition))
		{
			entityDef = cast defOrRef;
		}
		else
		{
			entityDef = Content.GetEntityDefinition(defOrRef);
			if (entityDef == null)
			{
				var exception = new MissingDefinitionException('Trying to spawn an entity with a missing entity definition ${defOrRef}.');
				Debug.LogException(exception);
				return null;
			}
		}
		var realSeed = seed == null ? NewEntitySeed() : seed;
		var id = AllocEntityID();
		var spawned = new Entity(this, id, entityDef, source, realSeed);
		spawned.Position = pos;
		InitEntityCollision(spawned);
		if (param != null)
		{
			param.Apply(spawned);
		}
		entities.set(Int64.toInt(id), spawned);
		OnEntitySpawn.dispatch(spawned);
		spawned.Init();
		IncreaseLevelObjectReference(spawned);
		PostEntityEnabled.dispatch(spawned);
		return spawned;
	}
	// PORT-NOTE: C# 的四个 Spawn 重载（EntityDefinition / NamespaceID × 有无 seed 参数）合并为单方法：
	//   第 4 实参既可为 int seed，也可为 SpawnParams（既有调用点 `level.Spawn(id, pos, spawner, param)`）。
	public function Spawn(defOrRef:Dynamic, pos:Vector3, spawner:Null<Entity>, ?seedOrParams:Dynamic, ?param:Null<SpawnParams>):Null<Entity>
	{
		var seed:Null<Int> = null;
		var spawnParam:Null<SpawnParams> = param;
		if (seedOrParams != null)
		{
			if (Std.isOfType(seedOrParams, SpawnParams))
				spawnParam = cast seedOrParams;
			else
				seed = cast seedOrParams;
		}
		var def:EntityDefinition = null;
		var ref:Null<NamespaceID> = null;
		if (Std.isOfType(defOrRef, EntityDefinition))
		{
			def = cast defOrRef;
		}
		else
		{
			ref = defOrRef;
			def = Content.GetEntityDefinition(ref);
			if (def == null)
			{
				var exception = new MissingDefinitionException('Trying to spawn an entity with a missing entity definition ${ref}.');
				Debug.LogException(exception);
				return null;
			}
		}
		var source:Null<ILevelSourceReference> = spawner == null ? null : new EntitySourceReference(spawner);
		return SpawnSourced(def, pos, source, seed, spawnParam);
	}
	// #endregion

	// #region 移除
	// PORT-NOTE: C# 为 internal，Haxe 没有 internal 访问级别，改为普通公开方法（同 Entity.Remove 的调用）。
	public function RemoveEntity(entity:Entity):Void
	{
		var id = entity.ID;
		entities.remove(Int64.toInt(id));
		entityTrash.set(Int64.toInt(id), entity);
		RemoveEntityCollision(entity);
		DecreaseLevelObjectReference(entity);
		OnEntityRemove.dispatch(entity);
		PostEntityDisabled.dispatch(entity);
	}
	// #endregion

	// #region 查询实体列表
	public function EnumerateEntities():Iterator<Entity>
	{
		return [for (e in entities) e].iterator();
	}
	// PORT-NOTE: C# 的 `params int[] filterTypes` → Haxe 可变参数缺失，取既有调用点的两种形式
	//   （`GetEntities()` 与 `GetEntities(EntityTypes.X)`）。多类型过滤未在既有代码中出现，如需请扩展为 Array<Int>。
	public function GetEntities(?filterType:Null<Int>):Array<Entity>
	{
		if (filterType == null)
			return [for (e in entities) e];
		return FindEntities(e -> e.Type == filterType);
	}
	// PORT-NOTE: C# 的 FindEntities(Func<Entity, bool>) / FindEntities(EntityDefinition) / FindEntities(NamespaceID)
	//   合并为单方法 + Dynamic 分派（既有调用点混用三种形式）。
	public function FindEntities(filter:Dynamic):Array<Entity>
	{
		var results:Array<Entity> = [];
		if (Std.isOfType(filter, EntityDefinition))
		{
			var def:EntityDefinition = cast filter;
			for (e in entities)
			{
				if (e.Definition == def)
					results.push(e);
			}
			return results;
		}
		if (Reflect.isFunction(filter))
		{
			var predicate:Entity->Bool = cast filter;
			for (e in entities)
			{
				if (predicate(e))
					results.push(e);
			}
			return results;
		}
		var id:NamespaceID = cast filter;
		if (!NamespaceID.IsValid(id))
			return [];
		for (e in entities)
		{
			if (e.IsEntityOf(id))
				results.push(e);
		}
		return results;
	}
	public function FindEntitiesNonAlloc(predicate:Entity->Bool, results:Array<Entity>):Void
	{
		for (e in entities)
		{
			if (predicate(e))
			{
				results.push(e);
			}
		}
	}
	// #endregion

	// #region 查询实体数量
	public function GetEntityCount(filter:Dynamic):Int
	{
		var count = 0;
		if (Std.isOfType(filter, EntityDefinition))
		{
			var def:EntityDefinition = cast filter;
			for (e in entities)
			{
				if (e.Definition == def)
					count++;
			}
			return count;
		}
		if (Reflect.isFunction(filter))
		{
			var predicate:Entity->Bool = cast filter;
			for (e in entities)
			{
				if (predicate(e))
					count++;
			}
			return count;
		}
		var id:NamespaceID = cast filter;
		if (!NamespaceID.IsValid(id))
			return 0;
		for (e in entities)
		{
			if (e.IsEntityOf(id))
				count++;
		}
		return count;
	}
	// #endregion

	// #region 查询单个实体
	public function FindEntityByID(id:Int64):Null<Entity>
	{
		var key = Int64.toInt(id);
		if (entities.exists(key))
			return entities.get(key);
		return FindEntityInTrash(id);
	}
	// PORT-NOTE: C# 的 FindFirstEntity(EntityDefinition) / FindFirstEntity(NamespaceID) / FindFirstEntity(Func)
	//   合并为单方法 + Dynamic 分派。
	public function FindFirstEntity(filter:Dynamic):Null<Entity>
	{
		if (Std.isOfType(filter, EntityDefinition))
		{
			var def:EntityDefinition = cast filter;
			for (e in entities)
			{
				if (e.Definition == def)
					return e;
			}
			return null;
		}
		if (Reflect.isFunction(filter))
		{
			var predicate:Entity->Bool = cast filter;
			for (e in entities)
			{
				if (predicate(e))
					return e;
			}
			return null;
		}
		var id:NamespaceID = cast filter;
		for (e in entities)
		{
			if (e.IsEntityOf(id))
				return e;
		}
		return null;
	}
	public function FindFirstEntityWithTheLeast<TKey>(predicate:Entity->Bool, keySelector:Entity->TKey):Null<Entity>
	{
		// PORT-NOTE: C# 使用 Comparer<TKey>.Default + Tools.Mathematics 的 GetLessOne 扩展方法；
		// Haxe 无 IComparer，按 MathTool 的移植签名传入 Reflect.compare 比较函数，ref 参数用 {value:...} 承载。
		var comparer:Dynamic->Dynamic->Int = Reflect.compare;
		var targetEntity:{value:Null<Entity>} = {value: null};
		var targetKey:{value:Null<TKey>} = {value: null};
		for (e in entities)
		{
			if (!predicate(e))
				continue;
			var key = keySelector(e);
			MathTool.GetLessOne(comparer, e, targetEntity, key, targetKey);
		}
		return targetEntity.value;
	}
	public function FindFirstEntityWithTheMost<TKey>(predicate:Entity->Bool, keySelector:Entity->TKey):Null<Entity>
	{
		var comparer:Dynamic->Dynamic->Int = Reflect.compare;
		var targetEntity:{value:Null<Entity>} = {value: null};
		var targetKey:{value:Null<TKey>} = {value: null};
		for (e in entities)
		{
			if (!predicate(e))
				continue;
			var key = keySelector(e);
			MathTool.GetGreaterOne(comparer, e, targetEntity, key, targetKey);
		}
		return targetEntity.value;
	}
	// #endregion

	// #region 查询实体存在
	// PORT-NOTE: C# 的 EntityExists(Predicate<Entity>) / (long id) / (EntityDefinition) / (NamespaceID)
	//   合并为单方法 + Dynamic 分派（既有调用点混用「谓词」与「NamespaceID」两种形式）。
	public function EntityExists(filter:Dynamic):Bool
	{
		if (Std.isOfType(filter, EntityDefinition))
		{
			var def:EntityDefinition = cast filter;
			for (e in entities)
			{
				if (e.Definition == def)
					return true;
			}
			return false;
		}
		if (Reflect.isFunction(filter))
		{
			var predicate:Entity->Bool = cast filter;
			for (e in entities)
			{
				if (predicate(e))
					return true;
			}
			return false;
		}
		if (Std.isOfType(filter, String))
		{
			// PORT-NOTE: NamespaceID 是 abstract，不能作为运行期值判断，改用底层 String 判断
			//   （NamespaceID 底层即 String，语义等价）。
			var id:NamespaceID = cast filter;
			for (e in entities)
			{
				if (e.IsEntityOf(id))
					return true;
			}
			return false;
		}
		// PORT-NOTE: haxe.Int64 是 abstract，无法用 Std.isOfType 判断，故把 long id 作为兜底分支
		//   （其余类型已先后由 EntityDefinition / 谓词 / NamespaceID 分支消化）。
		var id:Int64 = Std.isOfType(filter, Int) ? haxe.Int64.ofInt(cast filter) : cast filter;
		for (e in entities)
		{
			if (e.ID == id)
				return true;
		}
		return false;
	}
	// #endregion

	// #region 事件
	public var OnEntitySpawn:FlxTypedSignal<Entity->Void> = new FlxTypedSignal();
	public var OnEntityRemove:FlxTypedSignal<Entity->Void> = new FlxTypedSignal();
	public var PostEntityEnabled:FlxTypedSignal<Entity->Void> = new FlxTypedSignal();
	public var PostEntityDisabled:FlxTypedSignal<Entity->Void> = new FlxTypedSignal();
	// #endregion

	private var currentEntityID:Int64 = Int64.ofInt(1);
	private var entities:haxe.ds.BalancedTree<Int, Entity> = new haxe.ds.BalancedTree();
	private var entityTrash:Map<Int, Entity> = new Map();
	private var entityUpdateBuffer:ArrayBuffer<Entity> = new ArrayBuffer<Entity>(2048);

	// ===================== LevelEngine_SeedPack.cs =====================

	// #region 创建种子包
	public function CreateSeedPack(id:NamespaceID):Null<ClassicSeedPack>
	{
		var def = Content.GetSeedDefinition(id);
		if (def == null)
			return null;
		return new ClassicSeedPack(this, def, AllocSeedPackID());
	}
	public function InsertSeedPackAt(index:Int, seed:ClassicSeedPack):Void
	{
		if (index < 0 || index >= seedPacks.length)
			return;
		if (seedPacks[index] != null)
			return;
		seedPacks[index] = seed;
		IncreaseLevelObjectReference(seed);
		OnSeedAdded.dispatch(index);
	}
	private function AllocSeedPackID():Int64
	{
		var id = currentSeedPackID;
		currentSeedPackID++;
		return id;
	}
	// #endregion

	// #region 移除种子包
	public function RemoveSeedPackAt(index:Int):Bool
	{
		if (index < 0 || index >= seedPacks.length)
			return false;
		var seedPack = seedPacks[index];
		if (seedPack == null)
			return false;
		seedPacks[index] = null;
		DecreaseLevelObjectReference(seedPack);
		OnSeedRemoved.dispatch(index);
		return true;
	}
	public function ClearSeedPacks():Void
	{
		for (i in 0...GetSeedSlotCount())
		{
			RemoveSeedPackAt(i);
		}
	}
	// #endregion

	// #region 替换种子包
	public function ReplaceSeedPackAt(index:Int, seed:Null<ClassicSeedPack>):Void
	{
		if (index < 0 || index >= GetSeedSlotCount())
			return;
		RemoveSeedPackAt(index);
		if (seed != null)
			InsertSeedPackAt(index, seed);
	}
	public function ReplaceSeedPacks(targetsID:Iterable<ClassicSeedPack>):Void
	{
		var targetList = Lambda.array(targetsID);
		var targetCount = targetList.length;
		for (i in 0...GetSeedSlotCount())
		{
			var seed = i < targetCount ? targetList[i] : null;
			ReplaceSeedPackAt(i, seed);
		}
	}
	// #endregion

	// #region 获取种子包位置
	// PORT-NOTE: C# 的 GetSeedPackIndex(ClassicSeedPack) 与 GetSeedPackIndex(NamespaceID) 重载合并为
	//   单方法 + Dynamic 分派（既有调用点两种形式并存：mvz2logic/helditems/LogicHeldItemExt.hx 的
	//   `level.GetSeedPackIndex(classic)` 与 `level.GetSeedPackIndex(id)`、
	//   mvz2/gamecontent/helditems/SelectBlueprintHeldItemBehaviour.hx 的 `level.GetSeedPackIndex(cast(blueprint, ClassicSeedPack))`）。
	public function GetSeedPackIndex(key:Dynamic):Int
	{
		if (Std.isOfType(key, ClassicSeedPack))
			return GetSeedPackIndexBySeedPack(cast key);
		return GetSeedPackIndexByDefinition(key);
	}
	// PORT-NOTE: 该方法名由 pvzengine/seedpacks/ClassicSeedPack.hx 的 GetIndex() 调用（该文件不可改），保留。
	public function GetSeedPackIndexBySeedPack(seed:ClassicSeedPack):Int
	{
		return seedPacks.indexOf(seed);
	}
	public function GetSeedPackIndexByDefinition(id:NamespaceID):Int
	{
		var index = 0;
		for (s in seedPacks)
		{
			if (s != null && s.GetDefinitionID() == id)
				return index;
			index++;
		}
		return -1;
	}
	// #endregion

	// #region 获取种子包数量
	public function GetSeedPackCount():Int
	{
		var count = 0;
		for (s in seedPacks)
		{
			if (s != null)
				count++;
		}
		return count;
	}
	public function GetSeedSlotCount():Int
	{
		return seedPacks.length;
	}
	public function SetSeedSlotCount(count:Int):Void
	{
		if (count < seedPacks.length)
		{
			for (i in count...seedPacks.length)
			{
				RemoveSeedPackAt(i);
			}
		}
		// C#: Array.Resize(ref seedPacks, count)
		seedPacks.resize(count);
		OnSeedSlotCountChanged.dispatch(count);
	}
	// #endregion

	// #region 获取种子包
	public function GetAllSeedPacks():Array<Null<ClassicSeedPack>>
	{
		return seedPacks.copy();
	}
	public function GetSeedPackAt(index:Int):Null<ClassicSeedPack>
	{
		if (index < 0 || index >= seedPacks.length)
			return null;
		return seedPacks[index];
	}
	public function GetSeedPack(seedRef:NamespaceID):Null<ClassicSeedPack>
	{
		return Lambda.find(seedPacks, r -> r != null && r.GetDefinitionID() == seedRef);
	}
	public function GetSeedPackByID(id:Int64):Null<ClassicSeedPack>
	{
		return Lambda.find(seedPacks, s -> s != null && s.ID == id);
	}
	// #endregion

	// #region 更新
	private function UpdateClassicSeedPacks(rechargeSpeed:Float):Void
	{
		for (seedPack in seedPacks)
		{
			if (seedPack == null)
				continue;
			seedPack.Update(rechargeSpeed);
		}
	}
	// #endregion

	// #region 充能
	// 重置所有卡牌重装填进度。
	public function ResetAllRechargeProgress():Void
	{
		for (seedPack in seedPacks)
		{
			if (seedPack == null)
				continue;
			EngineSeedProps.SetStartRecharge(seedPack, true);
			EngineSeedProps.ResetRecharge(seedPack);
		}
	}
	public function FullRechargeAll():Void
	{
		for (seedPack in seedPacks)
		{
			if (seedPack == null)
				continue;
			EngineSeedProps.FullRecharge(seedPack);
		}
	}
	// #endregion

	// #region 序列化
	private function WriteSeedPacksToSerializable(seri:SerializableLevel):Void
	{
		seri.currentSeedPackID = currentSeedPackID;
		seri.seedPacks = [for (g in seedPacks) g != null ? g.ToSerializable() : null];
	}
	private function CreateSeedPacksFromSerializable(seri:SerializableLevel):Void
	{
		currentSeedPackID = seri.currentSeedPackID;
		seedPacks = [for (g in seri.seedPacks) g != null ? ClassicSeedPack.CreateFromSerializable(g, this) : null];
	}
	private function ReadSeedPacksFromSerializable(seri:SerializableLevel):Void
	{
		for (seed in seedPacks)
		{
			if (seed == null)
				continue;
			var seriSeed = Lambda.find(seri.seedPacks, s -> s != null && s.id == seed.ID);
			if (seriSeed == null)
				continue;
			seed.LoadFromSerializable(this, seriSeed);
			IncreaseLevelObjectReference(seed, true);
		}
	}
	// #endregion

	public var OnSeedAdded:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnSeedRemoved:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnSeedSlotCountChanged:FlxTypedSignal<Int->Void> = new FlxTypedSignal();

	private var currentSeedPackID:Int64 = Int64.ofInt(1);
	private var seedPacks:Array<Null<ClassicSeedPack>> = [];

	// ===================== LevelEngine_Conveyor.cs =====================

	// #region 添加种子包
	public function CanConveySeedPack():Bool
	{
		return conveyorSeedPacks.length < GetConveyorSlotCount();
	}
	public function AddConveyorSeedPack(id:NamespaceID):Null<ConveyorSeedPack>
	{
		return InsertConveyorSeedPackAt(conveyorSeedPacks.length, id);
	}
	public function InsertConveyorSeedPackAt(index:Int, id:NamespaceID):Null<ConveyorSeedPack>
	{
		if (index < 0 || index > conveyorSeedPacks.length || index >= GetConveyorSlotCount())
			return null;
		var seedDefinition = Content.GetSeedDefinition(id);
		if (seedDefinition == null)
			return null;
		var seedPack = new ConveyorSeedPack(this, seedDefinition, AllocSeedPackID());
		conveyorSeedPacks.insert(index, seedPack);
		IncreaseLevelObjectReference(seedPack);
		OnConveyorSeedAdded.dispatch(index);
		return seedPack;
	}
	// #endregion

	// #region 删除种子包
	public function RemoveConveyorSeedPackAt(index:Int):Bool
	{
		if (index < 0 || index >= conveyorSeedPacks.length)
			return false;
		var seedPack = conveyorSeedPacks[index];
		conveyorSeedPacks.splice(index, 1);
		DecreaseLevelObjectReference(seedPack);
		OnConveyorSeedRemoved.dispatch(index);
		return true;
	}
	public function ClearConveyorSeedPacks():Void
	{
		var i = conveyorSeedPacks.length - 1;
		while (i >= 0)
		{
			RemoveConveyorSeedPackAt(i);
			i--;
		}
	}
	// #endregion

	// #region 更新种子包
	public function UpdateConveyorSeedPacks(rechargeSpeed:Float):Void
	{
		for (seedPack in conveyorSeedPacks)
		{
			if (seedPack == null)
				continue;
			seedPack.Update(rechargeSpeed);
		}
	}
	// #endregion

	// #region 获取种子包位置
	// PORT-NOTE: C# 的 GetConveyorSeedPackIndex(ConveyorSeedPack) 与 GetConveyorSeedPackIndex(NamespaceID)
	//   重载合并为单方法 + Dynamic 分派（既有调用点：pvzengine/seedpacks/ConveyorSeedPack.hx 的
	//   `Level.GetConveyorSeedPackIndex(this)`、mvz2logic/helditems/LogicHeldItemExt.hx 的 `(conveyor)`、
	//   mvz2/gamecontent/helditems/SelectBlueprintHeldItemBehaviour.hx 的 `(cast(blueprint, ConveyorSeedPack))`）。
	public function GetConveyorSeedPackIndex(key:Dynamic):Int
	{
		if (Std.isOfType(key, ConveyorSeedPack))
			return conveyorSeedPacks.indexOf(cast key);
		return GetConveyorSeedPackIndexOfDefinition(key);
	}
	public function GetConveyorSeedPackIndexOfDefinition(id:NamespaceID):Int
	{
		var index = 0;
		for (s in conveyorSeedPacks)
		{
			if (s.GetDefinitionID() == id)
				return index;
			index++;
		}
		return -1;
	}
	// #endregion

	// #region 获取种子包数量
	public function GetConveyorSeedPackCount():Int
	{
		var count = 0;
		for (s in conveyorSeedPacks)
		{
			if (s != null)
				count++;
		}
		return count;
	}
	// #endregion

	// #region 获取种子包
	public function GetAllConveyorSeedPacks():Array<ConveyorSeedPack>
	{
		return conveyorSeedPacks.copy();
	}
	public function GetConveyorSeedPackAt(index:Int):Null<ConveyorSeedPack>
	{
		if (index < 0 || index >= conveyorSeedPacks.length)
			return null;
		return conveyorSeedPacks[index];
	}
	public function GetConveyorSeedPack(seedRef:NamespaceID):Null<ConveyorSeedPack>
	{
		return Lambda.find(conveyorSeedPacks, r -> r != null && r.GetDefinitionID() == seedRef);
	}
	public function GetConveyorSeedPackByID(id:Int64):Null<ConveyorSeedPack>
	{
		return Lambda.find(conveyorSeedPacks, s -> s.ID == id);
	}
	// #endregion

	// #region 上限
	public function GetConveyorSlotCount():Int
	{
		return conveyorSlotCount;
	}
	public function SetConveyorSlotCount(value:Int):Void
	{
		conveyorSlotCount = value;
		OnConveyorSeedSlotCountChanged.dispatch(value);
	}
	// #endregion

	// #region 占用情况
	public function ConveyRandomSeedPack(entries:Array<IConveyorPoolEntry>):Null<SeedPack>
	{
		if (CanConveySeedPack())
		{
			var id = DrawConveyorSeed(entries);
			if (id == null)
				return null;
			var seedPack = AddConveyorSeedPack(id);
			if (seedPack != null)
			{
				EngineSeedProps.SetDrawnConveyorSeed(seedPack, seedPack.GetDefinitionID());
				return seedPack;
			}
			else
			{
				PutSeedToConveyorDrawPile(id);
			}
		}
		return null;
	}
	public function DrawConveyorSeed(entries:Array<IConveyorPoolEntry>):Null<NamespaceID>
	{
		if (entries.length <= 0)
			return null;
		var rng = GetConveyorRNG();
		if (IsConveyorPoolEmpty(entries))
		{
			RefillConveyorPool(entries);
		}
		if (IsConveyorPoolEmpty(entries))
		{
			return null;
		}
		var weights:Array<Dynamic> = [for (e in entries) GetSeedCountFromConveyorDrawPile(e.ID, e.Count)];
		var index = rng.WeightedRandom(weights);
		var entry = entries[index];
		TakeSeedFromConveyorDrawPile(entry.ID);
		return entry.ID;
	}
	public function IsConveyorPoolEmpty(entries:Array<IConveyorPoolEntry>):Bool
	{
		// C#: entries.All(e => GetSeedCountFromConveyorDrawPile(e.ID, e.Count) <= 0)
		// PORT-NOTE: Haxe 的 Lambda 没有 forall，改为显式循环。
		for (e in entries)
		{
			if (GetSeedCountFromConveyorDrawPile(e.ID, e.Count) > 0)
				return false;
		}
		return true;
	}
	public function RefillConveyorPool(entries:Array<IConveyorPoolEntry>):Void
	{
		for (entry in entries)
		{
			var id = entry.ID;
			var discardCount = GetSeedCountInConveyorDiscardPile(id);
			// PORT-NOTE: C# 为 Mathf.Max(int, int)；Haxe 的 unity.Mathf 把整型版本命名为 MaxInt。
			var fillCount = Mathf.MaxInt(entry.MinCount, discardCount);
			if (fillCount > 0)
			{
				TakeSeedFromConveyorDiscardPile(id, fillCount);
				PutSeedToConveyorDrawPile(id, fillCount);
			}
		}
	}
	public function PutSeedToConveyorDiscardPile(seedID:NamespaceID, value:Int = 1):Void
	{
		conveyorSeedSpendRecord.AddToDiscardPile(seedID, value);
	}
	public function TakeSeedFromConveyorDiscardPile(seedID:NamespaceID, value:Int = 1):Void
	{
		conveyorSeedSpendRecord.AddToDiscardPile(seedID, -value);
	}
	public function GetSeedCountInConveyorDiscardPile(seedID:NamespaceID):Int
	{
		return conveyorSeedSpendRecord.GetSeedCountInDiscardPile(seedID);
	}
	public function PutSeedToConveyorDrawPile(seedID:NamespaceID, value:Int = 1):Void
	{
		conveyorSeedSpendRecord.AddSpendValue(seedID, -value);
	}
	public function TakeSeedFromConveyorDrawPile(seedID:NamespaceID, value:Int = 1):Void
	{
		conveyorSeedSpendRecord.AddSpendValue(seedID, value);
	}
	public function GetSeedCountFromConveyorDrawPile(seedID:NamespaceID, entryCount:Int):Int
	{
		return entryCount - conveyorSeedSpendRecord.GetSpendValue(seedID);
	}
	// #endregion

	// #region 序列化
	public function WriteConveyorToSerializable(seri:SerializableLevel):Void
	{
		seri.conveyorSeedPacks = [for (s in conveyorSeedPacks) s.ToSerializable()];
		seri.conveyorSlotCount = conveyorSlotCount;
		seri.conveyorSeedSpendRecord = conveyorSeedSpendRecord.ToSerializable();
	}
	public function CreateConveyorFromSerializable(seri:SerializableLevel):Void
	{
		conveyorSlotCount = seri.conveyorSlotCount;
		conveyorSeedSpendRecord = ConveyorSeedSpendRecords.ToDeserialized(seri.conveyorSeedSpendRecord);
		// C#: Select(...).OfType<ConveyorSeedPack>().ToList() —— OfType 在此等价于过滤掉 null。
		conveyorSeedPacks = [];
		for (s in seri.conveyorSeedPacks)
		{
			var pack:Null<ConveyorSeedPack> = ConveyorSeedPack.CreateFromSerializable(s, this);
			if (pack != null)
				conveyorSeedPacks.push(pack);
		}
	}
	public function ReadConveyorFromSerializable(seri:SerializableLevel):Void
	{
		for (seed in conveyorSeedPacks)
		{
			if (seed == null)
				continue;
			var seriSeed = Lambda.find(seri.conveyorSeedPacks, s -> s != null && s.id == seed.ID);
			if (seriSeed == null)
				continue;
			seed.LoadFromSerializable(this, seriSeed);
			IncreaseLevelObjectReference(seed, true);
		}
	}
	// #endregion

	public var OnConveyorSeedAdded:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnConveyorSeedRemoved:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnConveyorSeedSlotCountChanged:FlxTypedSignal<Int->Void> = new FlxTypedSignal();

	private var conveyorSlotCount:Int = 10;
	private var conveyorSeedPacks:Array<ConveyorSeedPack> = [];
	private var conveyorSeedSpendRecord:ConveyorSeedSpendRecords = new ConveyorSeedSpendRecords();

	// ===================== LevelEngine_Serialize.cs =====================

	// #region 序列化
	public function ToSerializable():SerializableLevel
	{
		var level = new SerializableLevel();
		level.stageDefinitionID = StageDefinition.GetID();
		level.areaDefinitionID = AreaDefinition.GetID();
		level.difficulty = Difficulty;
		level.Option = Option.Serialize();

		level.components = new Map();
		for (c in levelComponents)
		{
			level.components.set(c.GetID().ToString(), c.ToSerializable());
		}

		WriteEnergyToSerializable(level);
		WriteBuffsToSerializable(level);
		WriteCollisionToSerializable(level);
		WritePropertiesToSerializable(level);
		WriteSeedPacksToSerializable(level);
		WriteConveyorToSerializable(level);
		WriteEntitiesToSerializable(level);
		WriteProgressToSerializable(level);
		WriteRandomToSerializable(level);
		WriteGridsToSerializable(level);
		return level;
	}
	public static function CreateFromSerializable(seri:SerializableLevel, provider:IGameContent, triggers:IGameTriggerSystem, collisionSystem:ICollisionSystem):LevelEngine
	{
		if (!NamespaceID.IsValid(seri.stageDefinitionID))
			throw MissingSerializeDataException.Property("stageDefinitionID");
		if (!NamespaceID.IsValid(seri.areaDefinitionID))
			throw MissingSerializeDataException.Property("areaDefinitionID");
		if (!NamespaceID.IsValid(seri.difficulty))
			throw MissingSerializeDataException.Property("difficulty");
		if (seri.Option == null)
			throw MissingSerializeDataException.Property("Option");

		var level = new LevelEngine(provider, triggers, collisionSystem);
		level.ChangeStage(seri.stageDefinitionID);
		level.ChangeArea(seri.areaDefinitionID);
		level.Difficulty = seri.difficulty;
		level.Option = LevelOption.Deserialize(seri.Option);
		level.InitFromSerializable(seri);
		return level;
	}
	private function InitFromSerializable(seri:SerializableLevel):Void
	{
		ReadProgressFromSerializable(seri);
		ReadRandomFromSerializable(seri);
		ReadPropertiesFromSerializable(seri);

		// 加载所有关卡物体。
		ReadLevelObjectsFromSerializable(seri);

		// 在实体加载后面
		// 碰撞
		ReadCollisionFromSerializable(seri);
		// 能量
		ReadEnergyFromSerializable(seri);

		// 加载后更新
		UpdateAfterReadFromSerializable(seri);
	}
	private function ReadLevelObjectsFromSerializable(seri:SerializableLevel):Void
	{
		// 初始化所有地格。
		InitGrids(AreaDefinition);
		InitGridsFromSerializable(seri);
		// 创建所有种子包。
		CreateSeedPacksFromSerializable(seri);
		CreateConveyorFromSerializable(seri);
		// 创建所有实体。
		CreateEntitiesFromSerializable(seri);
		// 创建所有BUFF。
		InitBuffsFromSerializable(seri);
		// 所有实体、种子包和BUFF都已加载完毕。


		// 加载所有种子包、实体、BUFF的详细信息。
		// 因为有光环这种东西的存在，可能会引用buff，所以需要在buff加载完之后加载。
		ReadSeedPacksFromSerializable(seri);
		ReadConveyorFromSerializable(seri);
		// 加载所有实体的属性。
		ReadEntitiesFromSerializable(seri);
		// 加载所有网格的属性。
		ReadGridsFromSerializable(seri);
		LoadBuffsFromSerializable(seri);
	}
	private function WriteEnergyToSerializable(seri:SerializableLevel):Void
	{
		seri.energy = Energy;
		seri.delayedEnergyEntities = [
			// PORT-NOTE: Haxe 中 `for (x in map)` 迭代的是value，键值对须用 keyValueIterator()。
			for (d in delayedEnergyEntities.keyValueIterator())
			{
				var item = new SerializableDelayedEnergy();
				item.entityId = d.key.ID;
				item.energy = d.value;
				item;
			}
		];
	}
	private function ReadEnergyFromSerializable(seri:SerializableLevel):Void
	{
		Energy = seri.energy;
		delayedEnergyEntities.clear();
		if (seri.delayedEnergyEntities != null)
		{
			for (item in seri.delayedEnergyEntities)
			{
				var key = FindEntityByID(item.entityId);
				if (key == null)
					continue;
				delayedEnergyEntities.set(key, item.energy);
			}
		}
	}
	private function UpdateAfterReadFromSerializable(seri:SerializableLevel):Void
	{
		ReevaluateModifierCaches();
		UpdateAllModifiedProperties(false);
	}
	public function InitComponentsFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.components != null)
		{
			for (key in seri.components.keys())
			{
				var seriComp = seri.components.get(key);
				var comp:Null<ILevelComponent> = null;
				for (c in levelComponents)
				{
					if (c.GetID().ToString() == key)
					{
						comp = c;
						break;
					}
				}
				if (comp == null)
					continue;
				comp.InitFromSerializable(seriComp);
			}
		}
	}
	public function LoadComponentsFromSerializable(seri:SerializableLevel):Void
	{
		if (seri.components != null)
		{
			for (key in seri.components.keys())
			{
				var seriComp = seri.components.get(key);
				var comp:Null<ILevelComponent> = null;
				for (c in levelComponents)
				{
					if (c.GetID().ToString() == key)
					{
						comp = c;
						break;
					}
				}
				if (comp == null)
					continue;
				comp.LoadFromSerializable(seriComp);
			}
		}
	}
	// #endregion
}

// Ported from: Assets/Scripts/Engine/Level/Level/LevelEngine_Modifiers.cs (IModifierSource 的实现)
// PORT-NOTE: 见 LevelEngine.modifierSource 上的说明（与 pvzengine.entities.Entity 的 EntityModifierSource 同方案）。
private class LevelModifierSource implements IModifierSource
{
	public function new(level:LevelEngine)
	{
		this.level = level;
	}
	public function GetProperty<T>(name:PropertyKey<T>):Null<T>
	{
		return level.GetProperty(name);
	}
	private var level:LevelEngine;
}

// PORT-NOTE: C# 中 `void IModifiablePropertyTarget.OnPropertyChanged(...)`（显式接口实现）与
//   `public event Action<IPropertyKey, object?, object?, bool>? OnPropertyChanged` 同名；Haxe 不允许同名成员共存，
//   故与 pvzengine.entities.Entity 的 EntityModifierSource 同方案，用一个内部适配器承担 IModifiablePropertyTarget。
//   `out object? value` 按工程约定移植为引用容器结构 `{ value:Dynamic }`
//   （Haxe 不支持 `{var value:Dynamic}` 这种写法，那会被解析为块表达式）。
private class LevelPropertyTarget implements IModifiablePropertyTarget
{
	public function new(level:LevelEngine)
	{
		this.level = level;
	}
	public function GetFallbackProperty(name:IPropertyKey, value:{ value:Dynamic }):Bool
	{
		if (level.StageDefinition != null && level.StageDefinition.TryGetPropertyObject(name, value))
			return true;
		if (level.AreaDefinition != null && level.AreaDefinition.TryGetPropertyObject(name, value))
			return true;
		value.value = null;
		return false;
	}
	public function OnPropertyChanged(name:IPropertyKey, beforeValue:Dynamic, afterValue:Dynamic, triggersEvaluation:Bool):Void
	{
		level.OnPropertyChanged.dispatch(name, beforeValue, afterValue, triggersEvaluation);
	}
	private var level:LevelEngine;
}

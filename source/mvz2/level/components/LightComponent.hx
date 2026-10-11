// Ported from: Assets/Scripts/MVZ2/Level/Components/Light/LightComponent.cs
package mvz2.level.components;

import haxe.Int64;
import mvz2.level.LevelController;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2logic.Global;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.level.components.ComponentInterfaces.ILightComponent;import pvzengine.NamespaceID;
import pvzengine.collisions.IEntityCollider;
import pvzengine.collisions.EntityCollisionHelper;
import pvzengine.collisions.level.OverlapParams;
import pvzengine.entities.Entity;
import pvzengine.level.ISerializableLevelComponent;
import pvzengine.level.LevelEngine;
import tools.geometrical.Geometry;
import tools.geometrical.RoundCube;
import unity.Mathf;
import unity.Vector3;
import unity.Debug;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.components.LightSourceInfo.SerializableLightSourceInfo;
// PORT-NOTE: C# 的扩展方法（this 参数形式）在 Haxe 中需显式 using 才能以 `obj.Method()` 调用。
using mvz2logic.entities.LogicEntityProps;         // IsLightSource / GetLitMask / GetLightRange / ReceivesLightByType
using mvz2.vanilla.entities.VanillaColliderExt;    // IsForMain(this IEntityCollider)

class LightComponent extends MVZ2Component implements ILightComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, componentID, controller);
		level.PostEntityEnabled.add(PostEntityEnabledCallback);
		level.PostEntityDisabled.add(PostEntityDisabledCallback);
	}
	override public function Update():Void
	{
		super.Update();
		if (Level.IsTimeInterval(4) || lightDirty)
		{
			UpdateLighting();
		}
	}

	// #region 序列化
	override public function ToSerializable():ISerializableLevelComponent
	{
		var seriLightSources:Array<SerializableLightSourceInfo> = [];
		for (pair in lightToEntities.keyValueIterator())
		{
			var info = new SerializableLightSourceInfo();
			info.id = pair.key;
			info.illuminatingEntities = [for (k in pair.value.keys()) k];
			seriLightSources.push(info);
		}
		var comp = new SerializableLightComponent();
		comp.lightSources = seriLightSources;
		return comp;
	}
	override public function InitFromSerializable(seri:ISerializableLevelComponent):Void
	{
		super.InitFromSerializable(seri);
		if (!Std.isOfType(seri, SerializableLightComponent))
			return;
		var serializable:SerializableLightComponent = cast seri;
		if (serializable.lightSources == null)
			return;
		for (info in serializable.lightSources)
		{
			if (info == null || info.illuminatingEntities == null)
				continue;
			var lightSourceID = info.id;
			if (!lightToEntities.exists(lightSourceID))
			{
				lightToEntities.set(lightSourceID, new Map());
			}
			var lightSourceSet = lightToEntities.get(lightSourceID);
			for (belitID in info.illuminatingEntities)
			{
				lightSourceSet.set(belitID, true);

				if (!entityToLights.exists(belitID))
				{
					entityToLights.set(belitID, new Map());
				}
				entityToLights.get(belitID).set(lightSourceID, true);
			}
		}
	}
	// #endregion

	// #region 获取信息
	public function IsIlluminated(entity:Entity):Bool
	{
		return entityToLights.exists(entity.ID)
			&& setCount(entityToLights.get(entity.ID)) > 0;
	}

	public function IsIlluminatedBy(entity:Entity, lightSourceID:Int64):Bool
	{
		return entityToLights.exists(entity.ID)
			&& entityToLights.get(entity.ID).exists(lightSourceID);
	}

	public function GetIlluminationLightSources(entity:Entity):Array<Int64>
	{
		var result:Array<Int64> = [];
		if (entityToLights.exists(entity.ID))
		{
			for (id in entityToLights.get(entity.ID).keys())
				result.push(id);
		}
		return result;
	}

	public function GetIlluminationLightSourcesNonAlloc(entity:Entity, results:Map<Int64, Bool>):Void
	{
		if (entityToLights.exists(entity.ID))
		{
			for (id in entityToLights.get(entity.ID).keys())
				results.set(id, true);
		}
	}
	public function GetIlluminatingEntities(lightSourceID:Int64):Array<Int64>
	{
		var result:Array<Int64> = [];
		if (lightToEntities.exists(lightSourceID))
		{
			for (id in lightToEntities.get(lightSourceID).keys())
				result.push(id);
		}
		return result;
	}
	public function GetIlluminatingEntitiesNonAlloc(lightSourceID:Int64, results:Map<Int64, Bool>):Void
	{
		if (lightToEntities.exists(lightSourceID))
		{
			for (id in lightToEntities.get(lightSourceID).keys())
				results.set(id, true);
		}
	}

	public function GetIlluminationCount(targetID:Int64):Int
	{
		return entityToLights.exists(targetID) ? setCount(entityToLights.get(targetID)) : 0;
	}
	// #endregion

	// #region 事件回调
	// PORT-NOTE: Haxe 的 Map 没有 C# HashSet.Count 的等价属性，这里提供计数辅助方法。
	private static function setCount<T>(set:Map<T, Bool>):Int
	{
		var n = 0;
		for (_ in set.keys())
			n++;
		return n;
	}
	private function PostEntityEnabledCallback(entity:Entity):Void
	{
		if (entity.IsLightSource() || entity.GetLitMask() != 0)
		{
			lightDirty = true;
		}
	}
	private function PostEntityDisabledCallback(entity:Entity):Void
	{
		RemoveIlluminationForEntity(entity);
	}
	// #endregion

	// #region 更新光照
	public function RemoveIlluminationForEntity(entity:Entity):Void
	{
		var id = entity.ID;

		// 如果是光源：移除它照亮的实体
		if (lightToEntities.exists(id))
		{
			var litSet = lightToEntities.get(id);
			for (targetID in litSet.keys())
			{
				if (entityToLights.exists(targetID))
					entityToLights.get(targetID).remove(id);
			}
			lightToEntities.remove(id);
		}

		// 如果是被照亮实体：移除照亮它的光源
		if (entityToLights.exists(id))
		{
			var lightSet = entityToLights.get(id);
			for (lightID in lightSet.keys())
			{
				if (lightToEntities.exists(lightID))
					lightToEntities.get(lightID).remove(id);
			}
			entityToLights.remove(id);
		}
	}
	private function UpdateLighting():Void
	{
		lightDirty = false;
		CollectEntities();
		UpdateIllumination();
	}
	private function CollectEntities():Void
	{
		lightSources = [];
		Level.FindEntitiesNonAlloc(function(e:Entity) return e.IsLightSource(), lightSources);
	}
	private function UpdateIllumination():Void
	{
		// 清空索引
		for (set in entityToLights)
		{
			set.clear();
		}
		for (set in lightToEntities)
		{
			set.clear();
		}

		for (entity in lightSources)
		{
			UpdateIlluminationForLightSource(entity);
		}
	}
	public function UpdateIlluminationForLightSource(lightSource:Entity):Void
	{
		var lightSourceID = lightSource.ID;

		// 1. 先从 entityToLights 中移除该光源的旧影响
		if (!lightToEntities.exists(lightSourceID))
		{
			lightToEntities.set(lightSourceID, new Map());
		}
		var lightSourceSet = lightToEntities.get(lightSourceID);

		// 2. 重新计算
		ComputeLight(lightSource, lightSourceSet);

		// 3. 写回反向索引
		for (targetID in lightSourceSet.keys())
		{
			if (!entityToLights.exists(targetID))
			{
				entityToLights.set(targetID, new Map());
			}
			entityToLights.get(targetID).set(lightSourceID, true);
		}
	}
	private function ComputeLight(light:Entity, results:Map<Int64, Bool>):Void
	{
		var center = light.GetCenter();
		var range = light.GetLightRange();

		// PORT-NOTE: Unity 的 Mathf.Min(params float[]) 在 shim 中只有 2 参数版本，故嵌套调用。
		var minRange = Mathf.Min(Mathf.Min(range.x, range.y), range.z);
		var radius = minRange * 0.5;

		// PORT-NOTE: C# 的 Vector3 运算符在 Haxe 侧是 abstract 的运算符重载（无 subtract/add/multiplyScalar 方法）。
		var coreSize = range - Vector3.one * minRange;
		// TODO-PORT: unity.Vector3 shim 缺少静态 Vector3.Max/Min，这里按分量取最大值等价实现。
		coreSize = new Vector3(Math.max(coreSize.x, 0), Math.max(coreSize.y, 0), Math.max(coreSize.z, 0));

		var overlapSize = coreSize + Vector3.one * minRange;

		var roundCube = new RoundCube(center, coreSize, radius);
		var mask = EntityCollisionHelper.MASK_ALL;

		overlapResults = [];

		var overlapParam = OverlapParams.AnyFaction(mask);
		overlapParam.includeIgnored = true;
		Level.OverlapBoxNonAlloc(center, overlapSize, overlapParam, overlapResults);
		var lightType = light.Type;
		for (collider in overlapResults)
		{
			if (!collider.IsForMain())
				continue;
			var targetEntity = collider.Entity;
			if (targetEntity == null || !targetEntity.ReceivesLightByType(lightType))
				continue;

			if (!Geometry.CollideBetweenCubeAndRoundCube(roundCube, collider.GetBoundingBox()))
				continue;

			results.set(targetEntity.ID, true);
		}
	}
	// #endregion

	// #region 属性字段
	// 光源 -> 被照亮实体
	private var lightToEntities:Map<Int64, Map<Int64, Bool>> = new Map();

	// 实体 -> 光源
	private var entityToLights:Map<Int64, Map<Int64, Bool>> = new Map();

	// 缓冲区（避免 GC）
	private var lightSources:Array<Entity> = [];
	private var overlapResults:Array<IEntityCollider> = [];
	private var lightDirty:Bool = false;

	// PORT-NOTE: C# 的 static readonly 字段是首次使用时才初始化；hxcpp 会在 main() 之前执行全部静态初始化
	// （__boot_all()），那时 Global.Game / MainManager.Instance 仍为 null，直接求值会段错误。
	// 此处改为惰性 getter（结果缓存一次，等价于 C# 的 readonly static），还原 C# 语义。
	public static var componentID(get, never):NamespaceID;
	private static var _componentID:NamespaceID;
	static function get_componentID():NamespaceID
	{
		if (_componentID == null) _componentID = new NamespaceID(Global.BuiltinNamespace, "lighting");
		return _componentID;
	}
	// #endregion
}

@:rtti
class SerializableLightComponent implements ISerializableLevelComponent
{
	public var lightSources:Array<SerializableLightSourceInfo>;
	public function new() {}
}

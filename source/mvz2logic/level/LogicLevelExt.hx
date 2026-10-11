// Ported from: Assets/Scripts/Logic/Level/LogicLevelExt.cs
// PORT-NOTE: C# 中 LogicLevelExt 是以 partial class 分散在 14 个文件中的，按 PORTING.md
// “partial class → 合并为一个类文件” 的规则，全部合并到本文件，方法顺序与原文件一致：
//   LogicLevelExt.cs, LogicLevelExt_Advice.cs, LogicLevelExt_Area.cs, LogicLevelExt_Artifacts.cs,
//   LogicLevelExt_Behaviour.cs, LogicLevelExt_Blueprint.cs, LogicLevelExt_HeldItem.cs,
//   LogicLevelExt_Lighting.cs, LogicLevelExt_Logic.cs, LogicLevelExt_Money.cs,
//   LogicLevelExt_Music.cs, LogicLevelExt_Sound.cs, LogicLevelExt_Talk.cs, LogicLevelExt_UI.cs
// PORT-NOTE: C# 的扩展方法 (this LevelEngine level) 在 Haxe 中改为静态方法，level 作为第一个参数；
// 其他文件中调用时使用静态调用形式 LogicLevelExt.Xxx(level, ...)。
package mvz2logic.level;

import Lambda;
import mvz2logic.Global;
import mvz2logic.artifacts.Artifact;
import mvz2logic.artifacts.ArtifactDefinition;
import mvz2logic.blueprints.BlueprintChooseItem;
import mvz2logic.blueprints.LogicSeedProps;
import mvz2logic.callbacks.LogicLevelCallbacks;
import mvz2logic.callbacks.LogicLevelCallbacks.CalculateSpawnPointParams;
import mvz2logic.callbacks.LogicLevelCallbacks.GetBlueprintNotRecommondedParams;
import mvz2logic.callbacks.LogicLevelCallbacks.PostHeldItemEventParams;
import mvz2logic.callbacks.LogicLevelCallbacks.WaveEnemySpawnParams;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.entities.LogicEnemyProps;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.grids.LogicGridProps;
import mvz2logic.helditems.HeldHighlight;
import mvz2logic.helditems.HeldItemBuilder;
import mvz2logic.helditems.IHeldItemBuilder;
import mvz2logic.helditems.IHeldItemData;
import mvz2logic.helditems.IHeldItemTarget;
import mvz2logic.helditems.HeldItemDefinition;
import mvz2logic.helditems.LogicHeldItemExt;
import mvz2logic.helditems.IHeldTwinkleEntityBehaviour;
import mvz2logic.helditems.LogicHeldTypes;
import mvz2logic.inputs.PointerInteractionData;
import mvz2logic.inputs.PointerData;
import mvz2logic.level.LevelSpawnPointParams;
import mvz2logic.level.components.ComponentInterfaces.IAdviceComponent;
import mvz2logic.saves.LogicSaveExt;
import mvz2logic.level.components.ComponentInterfaces.IAreaComponent;
import mvz2logic.level.components.ComponentInterfaces.IArtifactComponent;
import mvz2logic.level.components.ComponentInterfaces.IBlueprintComponent;
import mvz2logic.level.components.ComponentInterfaces.IHeldItemComponent;
import mvz2logic.level.components.ComponentInterfaces.ILightComponent;
import mvz2logic.level.components.ComponentInterfaces.ILogicComponent;
import mvz2logic.level.components.ComponentInterfaces.IMoneyComponent;
import mvz2logic.level.components.ComponentInterfaces.IMusicComponent;
import mvz2logic.level.components.ComponentInterfaces.ISoundComponent;
import mvz2logic.level.components.ComponentInterfaces.ITalkComponent;
import mvz2logic.level.components.ComponentInterfaces.IUIComponent;
import mvz2logic.games.LogicGameDefinitionsExt;
import mvz2logic.spawns.LogicSpawnProps;
import mvz2logic.talk.ITalkController.ITalkControllerHelper;
import pvzengine.NamespaceID;
import pvzengine.PropertyKey;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.EntityCallbackParams;
import pvzengine.callbacks.LevelCallbacks;
import pvzengine.callbacks.LevelCallbacks.PostWaveParams;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityTypes;
import pvzengine.grids.LawnGrid;
import pvzengine.level.IConveyorPoolEntry;
import pvzengine.level.LevelEngine;
import pvzengine.level.SpawnParams;
import pvzengine.level.StageBehaviour;
import pvzengine.models.IModelInterface;
import pvzengine.seedpacks.ClassicSeedPack;
import pvzengine.seedpacks.SeedPack;
import pvzengine.spawns.SpawnDefinition;
import system.threading.tasks.Task;
import tools.LinqHelper;
import tools.RandomGenerator;
import tools.Ref;
import unity.Mathf;
import unity.Random;
import unity.Rect;
import unity.Vector2;
import unity.Vector2Int;
import unity.Vector3;

class LogicLevelExt
{
	//region 行为字段（已废弃）
	// [Obsolete]
	// TODO-PORT: C# 重载 SetBehaviourField<T>(this LevelEngine, NamespaceID, PropertyKey<T>, T?)，Haxe 不支持重载，重命名为 SetBehaviourFieldWithID
	public static function SetBehaviourFieldWithID<T>(level:LevelEngine, id:NamespaceID, name:PropertyKey<T>, value:Null<T>):Void
	{
		level.SetProperty(name, value);
	}
	// [Obsolete]
	public static function GetBehaviourFieldWithID<T>(level:LevelEngine, id:NamespaceID, name:PropertyKey<T>):Null<T>
	{
		return level.GetProperty(name);
	}
	// [Obsolete]
	public static function SetBehaviourField<T>(level:LevelEngine, name:PropertyKey<T>, value:Null<T>):Void
	{
		level.SetProperty(name, value);
	}
	// [Obsolete]
	public static function GetBehaviourField<T>(level:LevelEngine, name:PropertyKey<T>):Null<T>
	{
		return level.GetProperty(name);
	}
	//endregion

	//region 蓝图
	public static function IsBlueprintNotRecommmended(level:LevelEngine, blueprint:NamespaceID):Bool
	{
		var result = new CallbackResult(false);
		var param = new GetBlueprintNotRecommondedParams(level, blueprint);
		level.Triggers.RunCallbackWithResultFiltered(LogicLevelCallbacks.GET_BLUEPRINT_NOT_RECOMMONDED, param, result, blueprint);
		// TODO-PORT: C# 为 result.GetValue<bool>()，Haxe 无法在无参情况下推断泛型参数，按非泛型形式调用。
		return result.GetValue();
	}
	public static function SetupBattleBlueprints(level:LevelEngine, items:Array<BlueprintChooseItem>):Void
	{
		var oldSeedPacks = level.GetAllSeedPacks();
		for (i in 0...level.GetSeedSlotCount())
		{
			var blueprintID:Null<NamespaceID> = null;
			var commandBlock = false;
			if (i < items.length)
			{
				var item = items[i];
				blueprintID = item.id;
				commandBlock = item.isCommandBlock;
			}
			if (blueprintID == null)
			{
				level.RemoveSeedPackAt(i);
				continue;
			}
			var seedPack = GetLastBlueprint(level, blueprintID, commandBlock, oldSeedPacks);
			if (seedPack == null)
			{
				seedPack = level.CreateSeedPack(blueprintID);
				if (seedPack != null)
				{
					var s = seedPack;
					if (level.CurrentFlag <= 0)
					{
						s.SetStartRecharge(true);
					}
					else
					{
						s.FullRecharge();
					}
					LogicSeedProps.SetCommandBlockOfPack(s, commandBlock);
				}
			}
			level.ReplaceSeedPackAt(i, seedPack);
		}
	}
	public static function FillSeedPacks(level:LevelEngine, seedPacks:Iterable<NamespaceID>):Void
	{
		var oldSeedPacks = level.GetAllSeedPacks();
		var seedPackList = Lambda.array(seedPacks);
		var count = seedPackList.length;
		for (i in 0...count)
		{
			var id = seedPackList[i];
			var seedPack = GetLastBlueprint(level, id, false, oldSeedPacks);
			if (seedPack == null)
			{
				seedPack = level.CreateSeedPack(id);
				if (seedPack != null)
				{
					seedPack.SetStartRecharge(true);
				}
			}
			level.ReplaceSeedPackAt(i, seedPack);
		}
	}
	public static function GetLastBlueprint(level:LevelEngine, blueprintID:NamespaceID, commandBlock:Bool, oldSeedPacks:Iterable<Null<ClassicSeedPack>>):Null<ClassicSeedPack>
	{
		return Lambda.find(Lambda.array(oldSeedPacks), function(s) return s != null && s.GetDefinitionID() == blueprintID && LogicSeedProps.IsCommandBlockOfPack(s) == commandBlock);
	}
	//endregion

	//region 通关检查
	public static function GetFirstAliveEnemy(level:LevelEngine):Null<Entity>
	{
		return level.FindFirstEntity(function(e) return LogicEntityExt.IsAliveEnemy(e));
	}
	public static function HasNoAliveEnemy(level:LevelEngine):Bool
	{
		var first = GetFirstAliveEnemy(level);
		if (first != null)
			return false;
		if (LogicLevelProps.AssumeHasEnemies(level))
			return false;
		return true;
	}
	//endregion

	//region 检验地格
	public static function ValidateGridOutOfBounds(level:LevelEngine, position:Vector2Int):Bool
	{
		if (position.x < 0 || position.y < 0)
			return false;
		if (position.x >= level.GetMaxColumnCount() || position.y >= level.GetMaxLaneCount())
			return false;
		return true;
	}
	//endregion

	//region 障碍物生成
	public static function FindObstacleSpawnGrids(level:LevelEngine, layersToTake:Null<Array<NamespaceID>>, rng:RandomGenerator, count:Int, minColumn:Int, weightGetter:LawnGrid->Float):Array<LawnGrid>
	{
		if (count <= 0 || rng == null || weightGetter == null)
			return [];
		var allPossible = new Map<LawnGrid, Bool>();
		var allPreferred = new Map<LawnGrid, Bool>();
		FindAllObstacleSpawnGrids(level, layersToTake, minColumn, allPossible, allPreferred);

		// PORT-NOTE: C# 的 Dictionary.Keys 是 IEnumerable；Haxe Map.keys() 是 Iterator（非 Iterable），故先收集成数组。
		var preferredList:Array<LawnGrid> = [for (k in allPreferred.keys()) k];
		var possibleList:Array<LawnGrid> = [for (k in allPossible.keys()) k];
		var preferredCount = Mathf.MinInt(preferredList.length, count);
		var possibleCount = Mathf.MinInt(possibleList.length, count - preferredCount);

		var results:Array<LawnGrid> = [];
		if (preferredCount > 0)
		{
			var weights = [for (g in preferredList) weightGetter(g)];
			results = results.concat(LinqHelper.WeightedRandomTake(preferredList, weights, preferredCount, rng));
		}
		if (possibleCount > 0)
		{
			var weights = [for (g in possibleList) weightGetter(g)];
			results = results.concat(LinqHelper.WeightedRandomTake(possibleList, weights, possibleCount, rng));
		}
		return results;
	}
	static function FindAllObstacleSpawnGrids(level:LevelEngine, layersToTake:Null<Array<NamespaceID>>, minColumn:Int, possible:Map<LawnGrid, Bool>, preferred:Map<LawnGrid, Bool>):Void
	{
		for (col in minColumn...level.GetMaxColumnCount())
		{
			for (lane in 0...level.GetMaxLaneCount())
			{
				var grid = level.GetGrid(col, lane);
				if (grid == null)
					continue;

				var isPossible = true;
				var isPrefered = true;
				if (layersToTake != null)
				{
					for (layer in layersToTake)
					{
						var layerEntity = grid.GetLayerEntity(layer);
						if (layerEntity != null)
						{
							isPrefered = false;
							if (layerEntity.Type != EntityTypes.PLANT)
							{
								isPossible = false;
							}
						}
					}
				}
				if (isPrefered)
				{
					preferred.set(grid, true);
				}
				else if (isPossible) // 如果是优先选择的地格，则不可以出现在所有可能的地格中，否则可能会导致两个障碍物生成在一起。
				{
					possible.set(grid, true);
				}
			}
		}
	}
	public static function IsPossibleGridForObstacleSpawn(grid:LawnGrid, layersToTake:Array<NamespaceID>):Bool
	{
		return !Lambda.exists(layersToTake, function(l)
		{
			var ent = grid.GetLayerEntity(l);
			return ent != null && ent.Type != EntityTypes.PLANT;
		});
	}
	public static function IsPreferredGridForObstacleSpawn(grid:LawnGrid, layersToTake:Array<NamespaceID>):Bool
	{
		return !Lambda.exists(layersToTake, function(l)
		{
			var ent = grid.GetLayerEntity(l);
			return ent != null;
		});
	}
	//endregion

	//region 预览敌人
	// TODO-PORT: C# 重载 CreatePreviewEnemies(this LevelEngine, Rect)，Haxe 不支持重载，重命名为 CreatePreviewEnemiesFromEnemyPool
	public static function CreatePreviewEnemies(level:LevelEngine, spawnsID:Iterable<NamespaceID>, region:Rect):Void
	{
		var spawnToCreate:Array<SpawnDefinition> = [];
		for (spawnID in spawnsID)
		{
			var spawnDefinition = level.Content.GetSpawnDefinition(spawnID);
			if (spawnDefinition == null)
				continue;
			var count = LogicSpawnProps.GetPreviewCount(spawnDefinition);

			for (i in 0...count)
			{
				spawnToCreate.push(spawnDefinition);
			}
		}

		var createdEnemies:Array<Entity> = [];
		var radius:Float = 80;
		while (spawnToCreate.length > 0)
		{
			var creatingSpawnDef = spawnToCreate.copy();
			for (spawnDef in creatingSpawnDef)
			{
				var x = Random.Range(region.xMin, region.xMax);
				var z = Random.Range(region.yMin, region.yMax);
				var y = level.GetGroundY(x, z);
				var pos = new Vector3(x, y, z);

				if (radius > 0 && Lambda.exists(createdEnemies, function(e) return Vector3.Distance(e.Position, pos) < radius))
					continue;

				var param = new SpawnParams();
				param.SetProperty(LogicEnemyProps.PREVIEW_ENEMY, true);
				var enm = spawnDef.SpawnPreviewEntity(level, pos, param);
				if (enm != null)
				{
					createdEnemies.push(enm);
				}

				spawnToCreate.remove(spawnDef);
			}
			radius--;
		}
	}
	public static function CreatePreviewEnemiesFromEnemyPool(level:LevelEngine, region:Rect):Void
	{
		var pool = LogicStageProps.GetEnemyPool(level);
		// PORT-NOTE: 教学关（prologue）等没有配置 enemyPool，属性取不到值为 null。
		// C# 侧该数组由关卡数据写入；缺失时直接跳过预览敌人生成（无预览敌人）。
		if (pool == null)
			return;
		var spawnIDs = Lambda.filter(pool, function(e) return e != null && NamespaceID.IsValid(e));
		CreatePreviewEnemies(level, spawnIDs, region);
	}
	public static function RemovePreviewEnemies(level:LevelEngine):Void
	{
		for (enemy in level.FindEntities(function(e) return LogicEnemyProps.IsPreviewEnemy(e)))
		{
			enemy.Remove();
		}
	}
	//endregion

	//region 波次
	public static function PostWaveFinished(level:LevelEngine, wave:Int):Void
	{
		if (level.IsHugeWave(wave))
		{
			level.CurrentFlag++;
		}
		level.Triggers.RunCallbackFiltered(LevelCallbacks.POST_WAVE_FINISHED, new PostWaveParams(level, wave), wave);
	}
	public static function NextWave(level:LevelEngine):Void
	{
		PostWaveFinished(level, level.CurrentWave);
		level.CurrentWave++;
		RunWave(level);
	}
	public static function RunWave(level:LevelEngine):Void
	{
		SpawnWaveEnemies(level, level.CurrentWave);

		var wave = level.CurrentWave;
		level.StageDefinition.PostWave(level, wave);
		level.Triggers.RunCallback(LevelCallbacks.POST_WAVE, new PostWaveParams(level, wave));
	}
	public static function GetLevelTotalWaves(level:LevelEngine, wave:Int, flags:Int):Int
	{
		var wavesPerFlag = level.GetWavesPerFlag();
		var waveModular = (wave - 1) % wavesPerFlag + 1;
		// TODO-PORT: C# 使用 checked 并在 OverflowException 时返回 int.MaxValue；
		// Haxe 的 Int 溢出会静默回绕，无法捕获，此处保留原式的计算结果。
		return waveModular + flags * wavesPerFlag;
	}
	//endregion

	//region 生成怪物
	/// <summary>
	/// 波次生成敌人所需要的总等级花费。
	/// </summary>
	public static function CalculateSpawnPoints(level:LevelEngine, wave:Int, flags:Int):Float
	{
		var totalWave = GetLevelTotalWaves(level, wave, flags);
		var basePoints:Float = Std.int(Mathf.FloorToInt(totalWave * 0.8) / 2) + 1;
		var param = new LevelSpawnPointParams();
		param.basePoints = basePoints;
		param.addition = LogicLevelProps.GetSpawnPointAddition(level);
		param.multiplier = LogicLevelProps.GetSpawnPointMultiplier(level);
		param.power = LogicLevelProps.GetSpawnPointPower(level);
		param.maxPoints = 500;

		var args = new CalculateSpawnPointParams(level, wave, flags, param);
		level.Triggers.RunCallback(LogicLevelCallbacks.CALCULATE_SPAWN_POINTS, args);
		return param.Calculate();
	}
	// TODO-PORT: C# 重载 CalculateSpawnPoints(this LevelEngine)，Haxe 不支持重载，重命名为 CalculateCurrentSpawnPoints
	public static function CalculateCurrentSpawnPoints(level:LevelEngine):Float
	{
		return CalculateSpawnPoints(level, level.CurrentWave, level.CurrentFlag);
	}
	/// <summary>
	/// 本波用于限制生成怪物的数值，防止前期生成无法处理的怪物。
	/// </summary>
	public static function GetCurrentSpawnLimitWave(level:LevelEngine, wave:Int, flags:Int):Float
	{
		var rounds = flags / level.GetTotalFlags();
		// 每经过一轮，当前波数视为+1。
		return wave + rounds;
	}
	public static function SpawnWaveEnemies(level:LevelEngine, wave:Int):Void
	{
		// 获取本波的生成点数。
		var maxPoints = CalculateCurrentSpawnPoints(level);
		var totalPoints = maxPoints;

		// 波数限制，防止前期生成无法处理的怪物。
		var currentWaveLevelLimit = GetCurrentSpawnLimitWave(level, wave, level.CurrentFlag);

		// 当前的有效敌人池。
		var pool = LogicStageProps.GetEnemyPool(level);
		var spawnDefs = Lambda.filter(Lambda.array(Lambda.map(pool, function(id) return level.Content.GetSpawnDefinition(id))), function(def) return def != null);
		for (spawnDef in spawnDefs)
		{
			var pointsRef = Ref.to(totalPoints);
			spawnDef.PreSpawnAtWave(level, wave, maxPoints, pointsRef);
			totalPoints = pointsRef.value;
		}
		var preResult = new CallbackResult(totalPoints);
		var preArgs = new WaveEnemySpawnParams(level, wave, maxPoints);
		level.Triggers.RunCallbackWithResult(LogicLevelCallbacks.PRE_WAVE_ENEMY_SPAWN, preArgs, preResult);
		// TODO-PORT: C# 为 preResult.GetValue<float>()，Haxe 无法在无参情况下推断泛型参数，按非泛型形式调用。
		totalPoints = preResult.GetValue();

		var validSpawnDefs = Lambda.filter(spawnDefs, function(def) return def.CanSpawnInLevel(level));

		// 已生成怪物数量。
		var spawnedCount = 0;

		// 没有剩余点数，或者生成的敌人数量大于50只，则中断。
		while (totalPoints > 0 && spawnedCount < 50)
		{
			// 当前所有可以生成的敌人。
			// 不被当前波次限制。
			var possibleSpawnDefs = Lambda.filter(validSpawnDefs, function(def) return LogicSpawnProps.GetSpawnLevel(def) <= totalPoints);

			// 没有可生成的敌人了，跳出
			if (Lambda.count(possibleSpawnDefs) <= 0)
				break;

			var finalSpawnPool:Array<SpawnDefinition> = possibleSpawnDefs;
			// 根据当前波次限制获取有效的敌人。
			var limitedSpawnDefs = Lambda.filter(possibleSpawnDefs, function(def) return LogicSpawnProps.GetMinSpawnWave(def) <= currentWaveLevelLimit);

			// 如果根据当前波次限制之后，没有可以生成的敌人，则不进行限制。
			if (Lambda.count(limitedSpawnDefs) > 0)
			{
				finalSpawnPool = limitedSpawnDefs;
			}

			// 随机生成一个敌人。
			var rng = level.GetSpawnRNG();
			var spawnDef = LinqHelper.WeightedRandom(finalSpawnPool, function(i) return i.GetWeight(level), rng);
			SpawnEnemyAtRandomLane(level, spawnDef);
			totalPoints -= LogicSpawnProps.GetSpawnLevel(spawnDef);
			spawnedCount++;
		}

		if (level.IsFinalWave(wave))
		{
			// 最后一波如果还有没生成过的敌人，强制全部生成一次
			var notSpawnedDefs = Lambda.filter(validSpawnDefs, function(def) return !level.IsEnemySpawned(def.GetID()));
			for (notSpawnedDef in notSpawnedDefs)
			{
				SpawnEnemyAtRandomLane(level, notSpawnedDef);
			}
		}

		// 生成怪物之后。
		for (spawnDef in spawnDefs)
		{
			var pointsRef = Ref.to(totalPoints);
			spawnDef.PostSpawnAtWave(level, wave, maxPoints, pointsRef);
			totalPoints = pointsRef.value;
		}
		var postResult = new CallbackResult(totalPoints);
		var postArgs = new WaveEnemySpawnParams(level, wave, maxPoints);
		level.Triggers.RunCallbackWithResult(LogicLevelCallbacks.POST_WAVE_ENEMY_SPAWN, postArgs, postResult);
	}
	public static function WillEnemySpawn(level:LevelEngine, spawnID:NamespaceID):Bool
	{
		var pool = LogicStageProps.GetEnemyPool(level);
		if (pool == null)
			return false;
		return Lambda.exists(pool, function(e) return e == spawnID);
	}
	public static function SpawnEnemyAtRandomLane(level:LevelEngine, spawnDef:SpawnDefinition):Null<Entity>
	{
		var lane = spawnDef.GetRandomSpawnLane(level);
		// PORT-NOTE: C# 重载 SpawnEnemy(level, spawnDef, lane) → Haxe 重命名版 SpawnEnemyOnLane。
		return SpawnEnemyOnLane(level, spawnDef, lane);
	}
	// TODO-PORT: C# 重载 SpawnEnemyAtRandomLane(this LevelEngine, NamespaceID)，Haxe 不支持重载，重命名为 SpawnEnemyAtRandomLaneByID
	public static function SpawnEnemyAtRandomLaneByID(level:LevelEngine, spawnID:NamespaceID):Null<Entity>
	{
		var spawnDef = level.Content.GetSpawnDefinition(spawnID);
		if (spawnDef == null)
			return null;
		var x = level.GetEnemySpawnX();
		return SpawnEnemyAtRandomLane(level, spawnDef);
	}
	// TODO-PORT: C# 重载 SpawnEnemy(this LevelEngine, NamespaceID, int)，Haxe 不支持重载，重命名为 SpawnEnemyByID
	public static function SpawnEnemyByID(level:LevelEngine, spawnID:NamespaceID, lane:Int):Null<Entity>
	{
		var spawnDef = level.Content.GetSpawnDefinition(spawnID);
		if (spawnDef == null)
			return null;
		var x = level.GetEnemySpawnX();
		return SpawnEnemyAt(level, spawnDef, lane, x);
	}
	// TODO-PORT: C# 重载 SpawnEnemy(this LevelEngine, SpawnDefinition, int, float)，Haxe 不支持重载，重命名为 SpawnEnemyAt
	public static function SpawnEnemyAt(level:LevelEngine, spawnDef:SpawnDefinition, lane:Int, x:Float):Null<Entity>
	{
		var spawnEntityID = LogicSpawnProps.GetSpawnEntity(spawnDef);
		var entityDef = level.Content.GetEntityDefinition(spawnEntityID);
		if (entityDef == null)
			return null;
		var z = level.GetEntityLaneZ(lane);
		var y = level.GetGroundY(x, z);
		var pos = new Vector3(x, y, z) + LogicEntityProps.GetStartingPositionOffset(entityDef);
		var enm = level.Spawn(entityDef, pos, null);
		if (enm != null)
		{
			TriggerEnemySpawned(level, spawnDef.GetID(), enm);
		}
		return enm;
	}
	// TODO-PORT: C# 重载 SpawnEnemy(this LevelEngine, SpawnDefinition, int)，Haxe 不支持重载，重命名为 SpawnEnemyOnLane
	public static function SpawnEnemyOnLane(level:LevelEngine, spawnDef:SpawnDefinition, lane:Int):Null<Entity>
	{
		var x = level.GetEnemySpawnX();
		return SpawnEnemyAt(level, spawnDef, lane, x);
	}
	public static function TriggerEnemySpawned(level:LevelEngine, spawnID:NamespaceID, enemy:Entity):Void
	{
		level.AddSpawnedEnemyID(spawnID);
		level.StageDefinition.PostEnemySpawned(enemy);
		level.Triggers.RunCallback(LevelCallbacks.POST_ENEMY_SPAWNED, new EntityCallbackParams(enemy));
	}
	//endregion

	//region 存档
	public static function UpdatePersistentLevelUnlocks(level:LevelEngine):Void
	{
		var saves = Global.Saves;
		level.SetSeedSlotCount(LogicSaveExt.GetBlueprintSlots(saves));
		LogicLevelProps.SetStarshardSlotCount(level, LogicSaveExt.GetStarshardSlots(saves));
		level.SetArtifactSlotCount(LogicSaveExt.GetArtifactSlots(saves));
	}
	//endregion

	//region 全路
	public static function GetAllLanes(level:LevelEngine):Array<Int>
	{
		return [for (i in 0...level.GetMaxLaneCount()) i];
	}
	//endregion

	//region 水路
	public static function GetWaterLanes(level:LevelEngine):Array<Int>
	{
		return Lambda.filter(GetAllLanes(level), function(l) return IsWaterLane(level, l));
	}
	public static function IsWaterLane(level:LevelEngine, lane:Int):Bool
	{
		for (column in 0...level.GetMaxColumnCount())
		{
			var grid = level.GetGrid(column, lane);
			if (grid == null)
				continue;
			if (LogicGridProps.IsWater(grid))
				return true;
		}
		return false;
	}
	public static function IsWaterGrid(level:LevelEngine, column:Int, lane:Int):Bool
	{
		var grid = level.GetGrid(column, lane);
		if (grid == null)
			return false;
		return LogicGridProps.IsWater(grid);
	}
	public static function IsWaterAt(level:LevelEngine, x:Float, z:Float):Bool
	{
		var column = level.GetColumn(x);
		var lane = level.GetLane(z);
		return IsWaterGrid(level, column, lane);
	}
	//endregion

	//region 空路
	public static function GetAirLanes(level:LevelEngine):Array<Int>
	{
		return Lambda.filter(GetAllLanes(level), function(l) return IsAirLane(level, l));
	}
	public static function IsAirLane(level:LevelEngine, lane:Int):Bool
	{
		for (column in 0...level.GetMaxColumnCount())
		{
			var grid = level.GetGrid(column, lane);
			if (grid == null)
				continue;
			if (LogicGridProps.IsCloud(grid))
				return true;
		}
		return false;
	}
	public static function IsAirGrid(level:LevelEngine, column:Int, lane:Int):Bool
	{
		var grid = level.GetGrid(column, lane);
		if (grid == null)
			return false;
		return LogicGridProps.IsCloud(grid);
	}
	public static function IsAirAt(level:LevelEngine, x:Float, z:Float):Bool
	{
		var column = level.GetColumn(x);
		var lane = level.GetLane(z);
		return IsAirGrid(level, column, lane);
	}
	//endregion

	//region 昼夜
	public static function IsDay(level:LevelEngine):Bool
	{
		var dayNightCycle = LogicLevelProps.GetDayNightCycleOverride(level);
		if (dayNightCycle != LogicDayNightCycles.NONE)
		{
			return dayNightCycle == LogicDayNightCycles.DAY;
		}
		var areaTags = level.GetAreaTags();
		return areaTags.contains(LogicAreaTags.day);
	}
	//endregion

	//region 传送带
	public static function ConveyRandomSeedPack(level:LevelEngine):Null<SeedPack>
	{
		var pool = LogicStageProps.GetConveyorPool(level);
		if (pool == null)
			return null;
		return level.ConveyRandomSeedPack(pool);
	}
	//endregion

	//region 首次冒险模式
	public static function IsFirstAdventure(level:LevelEngine):Bool
	{
		return LogicStageProps.IsAdventure(level) && !level.IsRerun;
	}
	//endregion

	//region 手持物品
	public static function GetHeldItemComponent(level:LevelEngine):Null<IHeldItemComponent>
	{
		return level.GetComponent(IHeldItemComponent);
	}
	public static function SetHeldItem(level:LevelEngine, builder:IHeldItemBuilder):Void
	{
		var component = GetHeldItemComponent(level);
		if (component == null) return;
		component.SetHeldItem(builder);
	}
	// TODO-PORT: C# 重载 SetHeldItem(this LevelEngine, NamespaceID, int, Action<IHeldItemBuilder>)，Haxe 不支持重载，重命名为 SetHeldItemByType
	public static function SetHeldItemByType(level:LevelEngine, type:NamespaceID, priority:Int = 0, ?action:IHeldItemBuilder->Void):Void
	{
		var builder = new HeldItemBuilder(type, priority);
		if (action != null)
		{
			action(builder);
		}
		SetHeldItem(level, builder);
	}
	public static function ResetHeldItem(level:LevelEngine):Void
	{
		var component = GetHeldItemComponent(level);
		if (component == null) return;
		component.ResetHeldItem();
	}
	public static function CancelHeldItem(level:LevelEngine):Bool
	{
		var component = GetHeldItemComponent(level);
		if (component == null) return false;
		return component.CancelHeldItem();
	}
	public static function GetHeldItemType(level:LevelEngine):Null<NamespaceID>
	{
		var data = GetHeldItemData(level);
		if (data == null)
			return null;
		return data.Type;
	}
	public static function GetHeldItemDefinition(level:LevelEngine):Null<HeldItemDefinition>
	{
		var data = GetHeldItemData(level);
		if (data == null)
			return null;
		return LogicHeldItemExt.GetDefinition(data, level);
	}
	public static function GetHeldItemData(level:LevelEngine):Null<IHeldItemData>
	{
		var component = GetHeldItemComponent(level);
		if (component == null)
			return null;
		return component.Data;
	}
	public static function GetHeldHighlight(level:LevelEngine, target:IHeldItemTarget, pointer:PointerData):HeldHighlight
	{
		var data = GetHeldItemData(level);
		var heldItemDef = GetHeldItemDefinition(level);
		if (data == null || heldItemDef == null)
			return HeldHighlight.None;
		return heldItemDef.GetHighlight(target, data, pointer);
	}
	public static function DoHeldItemPointerEvent(level:LevelEngine, target:IHeldItemTarget, pointerParams:PointerInteractionData):Void
	{
		var data = GetHeldItemData(level);
		var heldItemDef = GetHeldItemDefinition(level);
		if (data == null || heldItemDef == null)
			return;
		heldItemDef.DoPointerEvent(target, data, pointerParams);

		var args = new PostHeldItemEventParams(level, target, data, pointerParams);
		level.Triggers.RunCallbackFiltered(LogicLevelCallbacks.POST_HELD_ITEM_EVENT, args, heldItemDef.GetID());
	}
	public static function GetHeldItemModelInterface(level:LevelEngine):Null<IModelInterface>
	{
		var component = GetHeldItemComponent(level);
		if (component == null) return null;
		return component.GetHeldItemModelInterface();
	}
	public static function ShouldHeldItemMakeEntityTwinkle(level:LevelEngine, entity:Entity):Bool
	{
		var heldDef = GetHeldItemDefinition(level);
		var heldItemData = GetHeldItemData(level);
		if (heldItemData == null || heldDef == null)
			return false;
		var behaviours = heldDef.GetBehaviours();
		for (behaviour in behaviours)
		{
			if (Std.isOfType(behaviour, IHeldTwinkleEntityBehaviour) && (cast behaviour:IHeldTwinkleEntityBehaviour).ShouldMakeEntityTwinkle(entity, heldItemData))
				return true;
		}
		return false;
	}
	public static function IsHoldingExclusiveItem(level:LevelEngine):Bool
	{
		if (!IsHoldingItem(level))
			return false;
		var holdingDefinition = GetHeldItemDefinition(level);
		if (holdingDefinition == null)
			return false;
		return holdingDefinition.Exclusive;
	}
	public static function IsHoldingItem(level:LevelEngine):Bool
	{
		var type = GetHeldItemType(level);
		return NamespaceID.IsValid(type) && type != LogicHeldTypes.none;
	}
	public static function IsHoldingPickaxe(level:LevelEngine):Bool
	{
		return GetHeldItemType(level) == LogicHeldTypes.pickaxe;
	}
	public static function IsHoldingStarshard(level:LevelEngine):Bool
	{
		return GetHeldItemType(level) == LogicHeldTypes.starshard;
	}
	public static function IsHoldingTrigger(level:LevelEngine):Bool
	{
		return GetHeldItemType(level) == LogicHeldTypes.trigger;
	}
	public static function IsHoldingSword(level:LevelEngine):Bool
	{
		return GetHeldItemType(level) == LogicHeldTypes.sword;
	}
	public static function IsHoldingBlueprint(level:LevelEngine, seedPack:SeedPack):Bool
	{
		var data = GetHeldItemData(level);
		if (data == null)
			return false;
		return LogicHeldItemExt.IsHoldingBlueprint(data, level, seedPack);
	}
	public static function IsHoldingClassicBlueprint(level:LevelEngine, i:Int):Bool
	{
		var data = GetHeldItemData(level);
		if (data == null)
			return false;
		return LogicHeldItemExt.IsHoldingClassicBlueprint(data, i);
	}
	public static function IsHoldingConveyorBlueprint(level:LevelEngine, i:Int):Bool
	{
		var data = GetHeldItemData(level);
		if (data == null)
			return false;
		return LogicHeldItemExt.IsHoldingConveyorBlueprint(data, i);
	}
	public static function GetHoldingEntity(level:LevelEngine):Null<Entity>
	{
		var data = GetHeldItemData(level);
		if (data == null)
			return null;
		return LogicHeldItemExt.GetHoldingEntity(data, level);
	}
	public static function IsHoldingEntity(level:LevelEngine, entity:Entity):Bool
	{
		return GetHoldingEntity(level) == entity;
	}
	//endregion

	//region 建议
	public static function GetAdviceComponent(level:LevelEngine):Null<IAdviceComponent>
	{
		return level.GetComponent(IAdviceComponent);
	}
	public static function ShowAdvice(level:LevelEngine, context:String, textKey:String, priority:Int, timeout:Int, args:Array<String>):Void
	{
		var component = GetAdviceComponent(level);
		if (component == null) return;
		component.ShowAdvice(context, textKey, priority, timeout, args);
	}
	public static function ShowAdvicePlural(level:LevelEngine, context:String, textKey:String, textPlural:String, n:haxe.Int64, priority:Int, timeout:Int, args:Array<String>):Void
	{
		var component = GetAdviceComponent(level);
		if (component == null) return;
		component.ShowAdvicePlural(context, textKey, textPlural, n, priority, timeout, args);
	}
	// TODO-PORT: C# 重载 ShowAdvicePlural(this LevelEngine, string, string, long, int, int, params string[])，Haxe 不支持重载，重命名为 ShowAdvicePluralUsingKey
	public static function ShowAdvicePluralUsingKey(level:LevelEngine, context:String, textKey:String, n:haxe.Int64, priority:Int, timeout:Int, args:Array<String>):Void
	{
		ShowAdvicePlural(level, context, textKey, textKey, n, priority, timeout, args);
	}
	public static function HideAdvice(level:LevelEngine):Void
	{
		var component = GetAdviceComponent(level);
		if (component == null) return;
		component.HideAdvice();
	}
	//endregion

	//region 场地
	public static function GetAreaComponent(level:LevelEngine):Null<IAreaComponent>
	{
		return level.GetComponent(IAreaComponent);
	}
	public static function GetAreaModelInterface(level:LevelEngine):Null<IModelInterface>
	{
		var component = GetAreaComponent(level);
		if (component == null) return null;
		return component.GetAreaModelInterface();
	}
	//endregion

	//region 制品
	public static function GetArtifactComponent(level:LevelEngine):Null<IArtifactComponent>
	{
		return level.GetComponent(IArtifactComponent);
	}
	public static function SetArtifactSlotCount(level:LevelEngine, count:Int):Void
	{
		var component = GetArtifactComponent(level);
		if (component == null) return;
		component.SetSlotCount(count);
	}
	public static function GetArtifactSlotCount(level:LevelEngine):Int
	{
		var component = GetArtifactComponent(level);
		if (component == null) return 0;
		return component.GetSlotCount();
	}
	public static function ReplaceArtifacts(level:LevelEngine, definitions:Null<Array<Null<ArtifactDefinition>>>):Void
	{
		var component = GetArtifactComponent(level);
		if (component == null) return;
		component.ReplaceArtifacts(definitions);
	}
	public static function ReplaceArtifact(level:LevelEngine, slot:Int, definition:Null<ArtifactDefinition>):Void
	{
		var component = GetArtifactComponent(level);
		if (component == null) return;
		component.ReplaceArtifact(slot, definition);
	}
	public static function SetArtifact(level:LevelEngine, slot:Int, artifact:Null<Artifact>):Void
	{
		var component = GetArtifactComponent(level);
		if (component == null) return;
		component.SetArtifact(slot, artifact);
	}
	public static function GetArtifacts(level:LevelEngine):Array<Null<Artifact>>
	{
		var component = GetArtifactComponent(level);
		if (component == null) return [];
		return component.GetArtifacts();
	}
	public static function HasArtifact(level:LevelEngine, artifactID:NamespaceID):Bool
	{
		var component = GetArtifactComponent(level);
		if (component == null) return false;
		return component.HasArtifact(artifactID);
	}
	// TODO-PORT: C# 重载 GetArtifactIndex(this LevelEngine, NamespaceID)，Haxe 不支持重载，重命名为 GetArtifactIndexByID
	public static function GetArtifactIndexByID(level:LevelEngine, artifactID:NamespaceID):Int
	{
		var component = GetArtifactComponent(level);
		if (component == null) return -1;
		return component.GetArtifactIndexByID(artifactID);
	}
	public static function GetArtifactIndex(level:LevelEngine, artifact:Artifact):Int
	{
		var component = GetArtifactComponent(level);
		if (component == null) return -1;
		return component.GetArtifactIndex(artifact);
	}
	public static function GetArtifactAt(level:LevelEngine, index:Int):Null<Artifact>
	{
		var component = GetArtifactComponent(level);
		if (component == null) return null;
		return component.GetArtifactAt(index);
	}
	// TODO-PORT: C# 重载 ReplaceArtifacts(this LevelEngine, NamespaceID?[]?)，Haxe 不支持重载，重命名为 ReplaceArtifactsByIDs
	public static function ReplaceArtifactsByIDs(level:LevelEngine, idList:Null<Array<Null<NamespaceID>>>):Void
	{
		var definitions:Null<Array<Null<ArtifactDefinition>>>;
		if (idList == null)
		{
			definitions = null;
		}
		else
		{
			definitions = [for (id in idList) NamespaceID.IsValid(id) ? LogicGameDefinitionsExt.GetArtifactDefinition(level.Content, id) : null];
		}
		ReplaceArtifacts(level, definitions);
	}
	public static function GetArtifact(level:LevelEngine, artifactID:NamespaceID):Null<Artifact>
	{
		var index = GetArtifactIndexByID(level, artifactID);
		if (index < 0)
			return null;
		return GetArtifactAt(level, index);
	}
	//endregion

	//region 关卡行为
	// TODO-PORT: C# 泛型重载 HasBehaviour<T>(this LevelEngine)，Haxe 不支持重载，重命名为 HasBehaviourType
	public static function HasBehaviourType<T:StageBehaviour>(level:LevelEngine, type:Class<T>):Bool
	{
		return level.StageDefinition.HasBehaviour(type);
	}
	public static function HasBehaviour(level:LevelEngine, behaviour:StageBehaviour):Bool
	{
		return level.StageDefinition.HasBehaviour(behaviour);
	}
	//endregion

	//region 蓝图组件
	public static function GetBlueprintComponent(level:LevelEngine):Null<IBlueprintComponent>
	{
		return level.GetComponent(IBlueprintComponent);
	}
	public static function SetConveyorMode(level:LevelEngine, value:Bool):Void
	{
		var component = GetBlueprintComponent(level);
		if (component == null) return;
		component.SetConveyorMode(value);
	}
	public static function IsConveyorMode(level:LevelEngine):Bool
	{
		var component = GetBlueprintComponent(level);
		if (component == null) return false;
		return component.IsConveyorMode();
	}
	//endregion

	//region 光照
	public static function GetLightComponent(level:LevelEngine):Null<ILightComponent>
	{
		return level.GetComponent(ILightComponent);
	}
	public static function IsIlluminated(level:LevelEngine, entity:Entity):Bool
	{
		var component = GetLightComponent(level);
		if (component == null) return false;
		return component.IsIlluminated(entity);
	}
	public static function GetIlluminationLightSources(level:LevelEngine, entity:Entity):Array<haxe.Int64>
	{
		var component = GetLightComponent(level);
		if (component == null) return [];
		return component.GetIlluminationLightSources(entity);
	}
	public static function GetIlluminationLightSourcesNonAlloc(level:LevelEngine, entity:Entity, results:Map<haxe.Int64, Bool>):Void
	{
		var component = GetLightComponent(level);
		if (component == null) return;
		component.GetIlluminationLightSourcesNonAlloc(entity, results);
	}
	public static function GetIlluminatiingEntitiesNonAlloc(level:LevelEngine, entity:Entity, results:Map<haxe.Int64, Bool>):Void
	{
		var component = GetLightComponent(level);
		if (component == null) return;
		component.GetIlluminatingEntitiesNonAlloc(entity.ID, results);
	}
	//endregion

	//region 关卡逻辑
	public static function GetLogicComponent(level:LevelEngine):Null<ILogicComponent>
	{
		return level.GetComponent(ILogicComponent);
	}
	public static function BeginLevel(level:LevelEngine):Void
	{
		var component = GetLogicComponent(level);
		if (component == null) return;
		component.BeginLevel();
	}
	public static function StopLevel(level:LevelEngine):Void
	{
		var component = GetLogicComponent(level);
		if (component == null) return;
		component.StopLevel();
	}
	public static function SaveStateData(level:LevelEngine):Void
	{
		var component = GetLogicComponent(level);
		if (component == null) return;
		component.SaveStateData();
	}
	public static function ReloadLevel(level:LevelEngine):Task
	{
		var component = GetLogicComponent(level);
		if (component == null) return Task.CompletedTask;
		return component.ReloadLevel();
	}
	public static function IsGamePaused(level:LevelEngine):Bool
	{
		var component = GetLogicComponent(level);
		if (component == null) return false;
		return component.IsGamePaused();
	}
	public static function IsGameStarted(level:LevelEngine):Bool
	{
		var component = GetLogicComponent(level);
		if (component == null) return false;
		return component.IsGameStarted();
	}
	public static function IsGameOver(level:LevelEngine):Bool
	{
		var component = GetLogicComponent(level);
		if (component == null) return false;
		return component.IsGameOver();
	}
	public static function IsGameRunning(level:LevelEngine):Bool
	{
		var component = GetLogicComponent(level);
		if (component == null) return false;
		return component.IsGameRunning();
	}
	//endregion

	//region 金钱
	public static function GetMoneyComponent(level:LevelEngine):Null<IMoneyComponent>
	{
		return level.GetComponent(IMoneyComponent);
	}
	public static function AddMoney(level:LevelEngine, value:Int):Void
	{
		var component = GetMoneyComponent(level);
		if (component == null) return;
		component.AddMoney(value);
	}
	public static function GetMoney(level:LevelEngine):Int
	{
		var component = GetMoneyComponent(level);
		if (component == null) return 0;
		return component.GetMoney();
	}
	public static function AddDelayedMoney(level:LevelEngine, entity:Entity, value:Int):Void
	{
		var component = GetMoneyComponent(level);
		if (component == null) return;
		component.AddDelayedMoney(entity, value);
	}
	public static function RemoveDelayedMoney(level:LevelEngine, entity:Entity):Bool
	{
		var component = GetMoneyComponent(level);
		if (component == null) return false;
		return component.RemoveDelayedMoney(entity);
	}
	public static function GetDelayedMoney(level:LevelEngine):Int
	{
		var component = GetMoneyComponent(level);
		if (component == null) return 0;
		return component.GetDelayedMoney();
	}
	public static function ClearDelayedMoney(level:LevelEngine):Void
	{
		var component = GetMoneyComponent(level);
		if (component == null) return;
		component.ClearDelayedMoney();
	}
	//endregion

	//region 音乐
	public static function GetMusicComponent(level:LevelEngine):Null<IMusicComponent>
	{
		return level.GetComponent(IMusicComponent);
	}
	public static function IsPlayingMusic(level:LevelEngine, id:NamespaceID):Bool
	{
		var component = GetMusicComponent(level);
		if (component == null) return false;
		return component.IsPlayingMusic(id);
	}
	public static function SetPlayingMusic(level:LevelEngine, id:NamespaceID):Void
	{
		var component = GetMusicComponent(level);
		if (component == null) return;
		component.SetPlayingMusic(id);
	}
	public static function PlayMusic(level:LevelEngine, id:NamespaceID):Void
	{
		var component = GetMusicComponent(level);
		if (component == null) return;
		component.Play(id);
	}
	public static function StopMusic(level:LevelEngine):Void
	{
		var component = GetMusicComponent(level);
		if (component == null) return;
		component.Stop();
	}
	public static function SetMusicVolume(level:LevelEngine, volume:Float):Void
	{
		var component = GetMusicComponent(level);
		if (component == null) return;
		component.SetMusicVolume(volume);
	}
	public static function GetMusicVolume(level:LevelEngine):Float
	{
		var component = GetMusicComponent(level);
		if (component == null) return 0;
		return component.GetMusicVolume();
	}
	public static function SetSubtrackWeight(level:LevelEngine, weight:Float):Void
	{
		var component = GetMusicComponent(level);
		if (component == null) return;
		component.SetSubtrackWeight(weight);
	}
	public static function GetSubtrackWeight(level:LevelEngine):Float
	{
		var component = GetMusicComponent(level);
		if (component == null) return 0;
		return component.GetSubtrackWeight();
	}
	//endregion

	//region 音效
	public static function GetSoundComponent(level:LevelEngine):Null<ISoundComponent>
	{
		return level.GetComponent(ISoundComponent);
	}
	// TODO-PORT: C# 中为名为 PlaySound 的重载之一（带 position），Haxe 不支持重载，与 ISoundComponent 一致命名为 PlaySoundAt
	public static function PlaySoundAt(level:LevelEngine, id:NamespaceID, position:Vector3, pitch:Float = 1, volume:Float = 1):Void
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return;
		component.PlaySoundAt(id, position, pitch, volume);
	}
	public static function PlaySound(level:LevelEngine, id:NamespaceID, pitch:Float = 1, volume:Float = 1):Void
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return;
		component.PlaySound(id, pitch, volume);
	}
	public static function PlaySoundIfNotNull(level:LevelEngine, id:Null<NamespaceID>, pitch:Float = 1, volume:Float = 1):Void
	{
		if (id == null)
			return;
		PlaySound(level, id, pitch, volume);
	}
	public static function AddLoopSoundEntity(level:LevelEngine, soundID:NamespaceID, id:haxe.Int64):Void
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return;
		component.AddLoopSoundEntity(soundID, id);
	}
	public static function RemoveLoopSoundEntity(level:LevelEngine, soundID:NamespaceID, id:haxe.Int64):Void
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return;
		component.RemoveLoopSoundEntity(soundID, id);
	}
	public static function HasLoopSoundEntities(level:LevelEngine, id:NamespaceID):Bool
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return false;
		return component.HasLoopSoundEntities(id);
	}
	public static function HasLoopSoundEntity(level:LevelEngine, soundID:NamespaceID, id:haxe.Int64):Bool
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return false;
		return component.HasLoopSoundEntity(soundID, id);
	}
	public static function StopAllLoopSounds(level:LevelEngine):Void
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return;
		component.StopAllLoopSounds();
	}
	public static function IsPlayingSound(level:LevelEngine, id:NamespaceID):Bool
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return false;
		return component.IsPlayingSound(id);
	}
	public static function IsPlayingLoopSound(level:LevelEngine, id:NamespaceID):Bool
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return false;
		return component.IsPlayingLoopSound(id);
	}
	public static function GetLoopSounds(level:LevelEngine):Array<NamespaceID>
	{
		var component = GetSoundComponent(level);
		if (component == null)
			return [];
		return component.GetLoopSounds();
	}
	//endregion

	//region 对话
	public static function GetTalkComponent(level:LevelEngine):Null<ITalkComponent>
	{
		return level.GetComponent(ITalkComponent);
	}
	public static function StartTalk(level:LevelEngine, groupId:NamespaceID, section:Int, delay:Float = 0, ?onEnd:Void->Void):Void
	{
		var component = GetTalkComponent(level);
		if (component == null) return;
		component.StartTalk(groupId, section, delay, onEnd);
	}
	public static function SkipAllTalks(level:LevelEngine, groupId:NamespaceID, section:Int, ?onSkipped:Void->Void):Void
	{
		var component = GetTalkComponent(level);
		if (component == null) return;
		component.AutoSkipTalks(groupId, section, onSkipped);
	}
	public static function SimpleStartTalk(level:LevelEngine, groupId:NamespaceID, section:Int, delay:Float = 0, ?onSkipped:Void->Void, ?onStarted:Void->Void, ?onEnd:Void->Void):Void
	{
		var component = GetTalkComponent(level);
		if (component == null) return;
		// PORT-NOTE: C# 接口默认方法 ITalkController.SimpleStartTalk → Haxe 静态辅助 ITalkControllerHelper.SimpleStartTalk。
		ITalkControllerHelper.SimpleStartTalk(component, groupId, section, delay, onSkipped, onStarted, onEnd);
	}
	//endregion

	//region UI
	public static function GetUIComponent(level:LevelEngine):Null<IUIComponent>
	{
		return level.GetComponent(IUIComponent);
	}
	public static function ScreenToLawnPositionByZ(level:LevelEngine, screenPosition:Vector2, z:Float):Vector3
	{
		var component = GetUIComponent(level);
		if (component == null) return Vector3.zero;
		return component.ScreenToLawnPositionByZ(screenPosition, z);
	}
	public static function ScreenToLawnPositionByY(level:LevelEngine, screenPosition:Vector2, y:Float):Vector3
	{
		var component = GetUIComponent(level);
		if (component == null) return Vector3.zero;
		return component.ScreenToLawnPositionByY(screenPosition, y);
	}
	public static function ScreenToLawnPositionByRelativeY(level:LevelEngine, screenPosition:Vector2, relativeY:Float):Vector3
	{
		var component = GetUIComponent(level);
		if (component == null) return Vector3.zero;
		return component.ScreenToLawnPositionByRelativeY(screenPosition, relativeY);
	}
	public static function SetMoneyFade(level:LevelEngine, fade:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetMoneyFade(fade);
	}
	public static function ShowMoney(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.ShowMoney();
	}
	public static function SetEnergyActive(level:LevelEngine, visible:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetEnergyActive(visible);
	}
	public static function IsEnergyActive(level:LevelEngine):Bool
	{
		var component = GetUIComponent(level);
		if (component == null) return false;
		return component.IsEnergyActive();
	}
	public static function SetBlueprintsActive(level:LevelEngine, visible:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetBlueprintsActive(visible);
	}
	public static function AreBlueprintsActive(level:LevelEngine):Bool
	{
		var component = GetUIComponent(level);
		if (component == null) return false;
		return component.AreBlueprintsActive();
	}
	public static function SetPickaxeActive(level:LevelEngine, visible:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetPickaxeActive(visible);
	}
	public static function IsPickaxeActive(level:LevelEngine):Bool
	{
		var component = GetUIComponent(level);
		if (component == null) return false;
		return component.IsPickaxeActive();
	}
	public static function SetStarshardActive(level:LevelEngine, visible:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetStarshardActive(visible);
	}
	public static function IsStarshardActive(level:LevelEngine):Bool
	{
		var component = GetUIComponent(level);
		if (component == null) return false;
		return component.IsStarshardActive();
	}
	public static function SetTriggerActive(level:LevelEngine, visible:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetTriggerActive(visible);
	}
	public static function IsTriggerActive(level:LevelEngine):Bool
	{
		var component = GetUIComponent(level);
		if (component == null) return false;
		return component.IsTriggerActive();
	}
	public static function ShakeScreen(level:LevelEngine, startAmplitude:Float, endAmplitude:Float, time:Int):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.ShakeScreen(startAmplitude, endAmplitude, time);
	}
	public static function SetHintArrowPointToBlueprint(level:LevelEngine, index:Int):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetHintArrowPointToBlueprint(index);
	}
	public static function SetHintArrowPointToPickaxe(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetHintArrowPointToPickaxe();
	}
	public static function SetHintArrowPointToTrigger(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetHintArrowPointToTrigger();
	}
	public static function SetHintArrowPointToStarshard(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetHintArrowPointToStarshard();
	}
	public static function SetHintArrowPointToEntity(level:LevelEngine, entity:Entity):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetHintArrowPointToEntity(entity);
	}
	public static function HideHintArrow(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.HideHintArrow();
	}
	public static function SetProgressBarToBoss(level:LevelEngine, barStyle:NamespaceID):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetProgressBarToBoss(barStyle);
	}
	public static function SetProgressBarToStage(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetProgressBarToStage();
	}
	public static function PauseGame(level:LevelEngine, pauseLevel:Int = 0):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.PauseGame(pauseLevel);
	}
	public static function ResumeGame(level:LevelEngine, pauseLevel:Int = 0):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.ResumeGame(pauseLevel);
	}
	public static function ResumeGameDelayed(level:LevelEngine, pauseLevel:Int = 0):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.ResumeGameDelayed(pauseLevel);
	}
	public static function SetUIAndInputDisabled(level:LevelEngine, value:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetUIAndInputDisabled(value);
	}
	public static function ShowDialog(level:LevelEngine, title:String, desc:String, options:Array<String>, ?onSelect:Int->Void):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.ShowDialog(title, desc, options, onSelect);
	}
	public static function SetAreaModelPreset(level:LevelEngine, preset:String):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetAreaModelPreset(preset);
	}
	public static function TriggerModelAnimator(level:LevelEngine, name:String):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.TriggerModelAnimator(name);
	}
	public static function SetModelAnimatorBool(level:LevelEngine, name:String, value:Bool):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetModelAnimatorBool(name, value);
	}
	public static function SetModelAnimatorInt(level:LevelEngine, name:String, value:Int):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetModelAnimatorInt(name, value);
	}
	public static function SetModelAnimatorFloat(level:LevelEngine, name:String, value:Float):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.SetModelAnimatorFloat(name, value);
	}
	public static function UpdateLevelName(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.UpdateLevelName();
	}
	public static function FlickerEnergy(level:LevelEngine):Void
	{
		var component = GetUIComponent(level);
		if (component == null) return;
		component.FlickerEnergy();
	}
	//endregion

	private function new() {}
}

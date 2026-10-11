// Ported from: Assets/Scripts/MVZ2/Managers/ResourceManager.cs
//             合并了 ResourceManager_*.cs 全部分部（partial）文件。
// PORT-NOTE: 原工程通过 Unity Addressables（AssetReference / IResourceLocator / AsyncOperationHandle）
// 加载 MOD 资源。Haxe 侧用 unity.addressables 兼容层实现等价流程（见 source/unity/addressables/）。
package mvz2.managers;

import haxe.ds.GenericStack;
// PORT-NOTE: 原 import 写作 mvz2.IO.*，但 Haxe 无法解析含大写字母的包路径（首个大写段会被当作类型名），
// 且 source/mvz2/IO/ 内的文件本身声明的是 `package mvz2.io;`，故统一改用小写包路径。
import mvz2.io.PathHelper;
import mvz2.metas.*;
import mvz2.modding.ModResource;
import mvz2.talkdata.TalkMeta;
// PORT-NOTE: 原 import 写作 mvz2logic.Serialization.*（Haxe 无法解析含大写字母的包段）；
// C# 源码位于 Assets/Scripts/MVZ2/Metas/，移植后类在 mvz2.metas。
import mvz2.metas.XMLCondition;
import mvz2.metas.XMLConditionList;
import pvzengine.*;
import system.threading.tasks.Task;
import unity.*;
import unity.Debug;
// PORT-NOTE: 原 import 使用 unity.addressables.* / unity.resourcemanagement.* 路径，但 shim 目录实为
// unity/addressableassets。MergeMode 与 AsyncOperationHandle 已由 shim 提供。
// TODO-PORT: unity.addressableassets.IResourceLocator / IResourceLocation 两个 shim 类型仍不存在，
// 而 import 一个不存在的类型会让 Haxe 立刻中止编译（连其他错误都看不到），故这里不再 import 它们，
// 统一改用 Dynamic（本工程既有约定，见 pvzengine.collisions.ISerializableCollisionCollider.Collisions；
// ModInfo.ResourceLocator 本身也是 Dynamic，所以定位符查询在运行期语义不变）。
// 待 unity shim 补齐这两个接口后，可把 ResourceManager 中标注 "TODO-PORT: 定位符类型" 的 Dynamic 换回接口类型。
import unity.addressableassets.Addressables;
import unity.addressableassets.Addressables.AsyncOperationHandle;
import unity.addressableassets.Addressables.MergeMode;
// PORT-NOTE: 移植层新增：地图模型（MapModel 标签）的最小兼容路径要用清单定位资源文件、
// 用已转换的 scene/model 数据装配 GameObject 层级（见本文件末尾的 MapModelPrefabBuilder）。
import unity.addressableassets.ResourceLocation;
import unity.addressableassets.ResourceManifest;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.managers.MainManager.PipelineTask;
import mvz2.managers.MainManager.TaskProgress;
import mvz2.gamecontent.commands.Unlock;
import mvz2.gamecontent.contraptions.VanillaContraptionID;
import mvz2.gamecontent.maps.VanillaMapID;
import mvz2.level.LevelManager;
import mvz2.localization.LanguageManager;
import mvz2.map.MapElement;
import mvz2.map.MapModel;
import mvz2.modding.ModManager;
import mvz2.models.AreaModel;
import mvz2.models.Model;
import mvz2.models.ModelManager;
// PORT-NOTE: 移植层新增：MapModel 标签的最小兼容路径要用模型 prefab 加载器装配地图上的装饰模型，
// 用场景 prefab 加载器装配 MapModelBase/MapButton（见本文件末尾的 MapModelPrefabBuilder）。
import mvz2.models.ModelPrefabLoader;
import mvz2.models.ModelUpdater;
import mvz2.scenes.ScenePrefabLoader;
import mvz2.scenes.ScenePrefabData.ScenePrefabFile;
import mvz2.ui.map.MapButton;
import mvz2.options.Options;
import mvz2.options.OptionsManager;
import mvz2.saves.SaveManager;
import mvz2.sprites.GeneratedSpriteManifest;
import mvz2.sprites.SpriteManifest;
// PORT-NOTE: 移植层新增：从预生成的 assets/sprites_manifest.json 重建 SpriteManifest。
import mvz2.sprites.SpriteManifestLoader;
import mvz2.talkdata.TalkGroup;
import mvz2.talkdata.TalkSection;
import mvz2.talkdata.TalkSentence;
import mvz2.ui.Blueprint.BlueprintViewData;
import mvz2.unlocks.UnlockGroupMeta;
import mvz2logic.Global;
import mvz2logic.almanac.LogicAlmanacCategories;
import mvz2logic.blueprints.LogicBlueprintStyles;
import mvz2logic.callbacks.LogicCallbacks;
import mvz2logic.callbacks.LogicCallbacks.GetBlueprintStyleParams;
import mvz2logic.localization.LogicStrings;
import mvz2logic.resources.SpriteReference;
import pvzengine.base.Definition;
import pvzengine.callbacks.CallbackResult;
import system.io.Path;
import unity.networking.UnityWebRequest.Result;
import unity.networking.UnityWebRequest;
import Main;
import unity.Coroutine.CoroutineContext;
import unity.UnityObject;
import mvz2.io.XMLHelper;
import system.io.MemoryStream;
// PORT-NOTE: C# 的扩展方法在 Haxe 中需显式 using 才能以 `obj.Method()` 形式调用。
using mvz2logic.games.LogicGameExt;                // GetEntityName / GetEntityTooltip / GetArtifactName / GetBlueprintName 等
using mvz2logic.level.LogicStageProps;             // IsEndless(this LevelEngine)
using mvz2logic.options.LogicOptionExt;            // SkipAllTalks(this IGlobalOptions)
using mvz2logic.saves.LogicSaveExt;                // IsDebugUserName(this IGlobalSaveData)
using mvz2logic.serialization.SerializeHelper;
using mvz2.metas.MetaXMLParser;                    // LoadMetaList(this ModResource, ...)
using mvz2logic.blueprints.LogicSeedProps;         // IsUpgradeBlueprint / GetMobileIcon / GetIcon / GetModelID / IsCommandBlockOfPack
using mvz2logic.entities.LogicEntityProps;         // HideInStats(this EntityDefinition)

class ResourceManager extends MonoBehaviour
{
	// #region 公有方法

	// #region Mod资源
	public function ClearResources():Void
	{
		modResources = [];
		spriteReferenceCacheDict.clear();
		talksCacheDict.clear();
		achievementCacheDict.clear();
		mainmenuViewCacheDict.clear();
		ClearResources_Store();
		noteCache = [];
		unlockConditionList = new Map();
	}
	public function Init():Task
	{
		Init_Sprites();
		ClearResources();
		var task:Task = Task.CompletedTask;
		for (mod in main.ModManager.GetAllModInfos())
		{
			var nsp = mod.Namespace;
			var modResource = new ModResource(nsp);
			modResources.push(modResource);
			task = LoadModResourcesInit(nsp, modResource);
		}
		return task;
	}
	public function LoadAllModResourcesMain(progress:TaskProgress):Task
	{
		var infos = main.ModManager.GetAllModInfos();

		var childProgresses = progress.AddChildren(infos.length);
		var task:Task = Task.CompletedTask;
		for (i in 0...infos.length)
		{
			var mod = infos[i];
			var nsp = mod.Namespace;
			var modResource = GetModResource(nsp);
			if (modResource == null)
			{
				Debug.LogWarning('Cannot find the mod resource with namespace $nsp.');
				continue;
			}
			progress.SetCurrentTaskName('Mod $nsp');
			task = LoadModResourcesMain(nsp, modResource, childProgresses[i]);
		}
		return task;
	}
	public function GetModResource(spaceName:String):ModResource
	{
		return Lambda.find(modResources, m -> m.Namespace == spaceName);
	}
	// #endregion

	// #region 路径
	public function GetNamespaceDirectory(nsp:String):String
	{
		if (nsp == main.BuiltinNamespace)
		{
			return PathHelper.combine(Application.dataPath, "GameContent");
		}
		return PathHelper.combine(Application.streamingAssetsPath, "Mods", nsp);
	}
	public function GetContentDirectory(nsp:String):String
	{
		return PathHelper.combine(GetNamespaceDirectory(nsp), "Content");
	}
	public function GetResourcesDirectory(nsp:String):String
	{
		return PathHelper.combine(GetNamespaceDirectory(nsp), "Res");
	}
	public static function CombinePath(paths:Array<String>):String
	{
		return PathHelper.combine(paths).split("\\").join("/");
	}
	// #endregion

	// #endregion

	// #region 私有方法
	private function OnApplicationQuit():Void
	{
		if (generatedSpriteManifest != null && Application.isEditor)
		{
			generatedSpriteManifest.Reset();
		}
	}
	private function LoadModResourcesInit(modNamespace:String, modResource:ModResource):Task
	{
		LoadMetaLists(modNamespace);
		LoadInitModMusicClips(modNamespace);
		LoadInitModSoundClips(modNamespace);
		LoadInitSpriteManifests(modNamespace);

		if (modResource.ArmorMetaList != null)
		{
			for (meta in modResource.ArmorMetaList.slots)
			{
				armorSlotsCacheDict.set(new NamespaceID(modNamespace, meta.Name), meta);
			}
			for (meta in modResource.ArmorMetaList.metas)
			{
				armorsCacheDict.set(new NamespaceID(modNamespace, meta.ID), meta);
			}
		}
		if (modResource.AchievementMetaList != null)
		{
			for (meta in modResource.AchievementMetaList.metas)
			{
				achievementCacheDict.set(new NamespaceID(modNamespace, meta.ID), meta);
			}
		}
		if (modResource.MainmenuViewMetaList != null)
		{
			for (meta in modResource.MainmenuViewMetaList.Metas)
			{
				mainmenuViewCacheDict.set(new NamespaceID(modNamespace, meta.ID), meta);
			}
		}
		PostLoadMod_Store(modNamespace, modResource);
		if (modResource.NoteMetaList != null)
		{
			for (meta in modResource.NoteMetaList.metas)
			{
				noteCache.push(new NamespaceID(modNamespace, meta.id));
			}
		}
		// PORT-NOTE: Haxe 中 `for (x in map)` 迭代的是值；要用 KeyValuePair 必须显式 keyValueIterator()。
		for (pair in modResource.TalkMetas.keyValueIterator())
		{
			for (group in pair.value.groups)
			{
				talksCacheDict.set(new NamespaceID(modNamespace, group.id), group);
			}
		}
		if (modResource.ArcadeMetaList != null)
		{
			for (meta in modResource.ArcadeMetaList.metas)
			{
				if (meta.ID != null && meta.ID != "")
				{
					arcadeCache.push(new NamespaceID(modNamespace, meta.ID));
				}
			}
		}
		LoadModResourceUnlocks(modResource);
		return Task.CompletedTask;
	}
	// PORT-NOTE: C# 用「局部函数」（local function）实现这 6 个加载步骤，且声明在使用之后。
	// Haxe 不会把局部函数提升到块作用域前方，故此处把局部函数整体前移到方法体开头，
	// 逻辑与 C# 完全一致（包括 C# 中同名成员方法 LoadSprites 被局部函数遮蔽这一点）。
	private function LoadModResourcesMain(modNamespace:String, modResource:ModResource, progress:TaskProgress):Task
	{
		function LoadMusicClips(progress:TaskProgress):Task
		{
			progress.SetCurrentTaskName("Waiting");
			return LoadMainModMusicClips(modNamespace, progress);
		}
		function LoadSoundClips(progress:TaskProgress):Task
		{
			progress.SetCurrentTaskName("Waiting");
			return LoadMainModSoundClips(modNamespace, progress);
		}
		function LoadSprites(progress:TaskProgress):Task
		{
			var loadProgress = progress.AddChild();
			loadProgress.SetCurrentTaskName("Waiting");

			LoadMainSpriteManifests(modNamespace, loadProgress);
			loadProgress.SetProgress(1, "Finished");
			return Task.CompletedTask;
		}
		function LoadModels(progress:TaskProgress):Task
		{
			var loadProgress = progress.AddChild();
			var shotProgress = progress.AddChild();
			loadProgress.SetCurrentTaskName("Waiting");
			shotProgress.SetCurrentTaskName("Waiting");

			LoadModModels(modNamespace, loadProgress);
			loadProgress.SetProgress(1, "Finished");

			var enumerator = ShotModelIcons(modNamespace, shotProgress, 8);
			Main.CoroutineManager.ToTask(enumerator);
			shotProgress.SetProgress(1, "Finished");
			return Task.CompletedTask;
		}
		function LoadMapModels(progress:TaskProgress):Task
		{
			progress.SetCurrentTaskName("Waiting");
			return LoadModMapModels(modNamespace, progress);
		}
		function LoadAreaModels(progress:TaskProgress):Task
		{
			progress.SetCurrentTaskName("Waiting");
			return LoadModAreaModels(modNamespace, progress);
		}

		var tasks:Array<PipelineTask> = [];

		tasks.push(new PipelineTask("Music Clips", LoadMusicClips, progress.AddChild()));
		tasks.push(new PipelineTask("Sound Clips", LoadSoundClips, progress.AddChild()));
		tasks.push(new PipelineTask("Sprites", LoadSprites, progress.AddChild()));
		tasks.push(new PipelineTask("Models", LoadModels, progress.AddChild()));
		tasks.push(new PipelineTask("Map Models", LoadMapModels, progress.AddChild()));
		tasks.push(new PipelineTask("Area Models", LoadAreaModels, progress.AddChild()));

		for (i in 0...tasks.length)
		{
			var task = tasks[i];
			var startTime = Time.time;
			var name = task.GetName();
			progress.SetCurrentTaskName(name);
			task.Run();
			Debug.Log('加载$name花费的时间：${Time.time - startTime}');
		}
		return Task.CompletedTask;
	}
	private function LoadSingleMetaList(modResource:ModResource, resID:NamespaceID, resource:TextAsset):Void
	{
		var talksDirectory = "talks/";

		// PORT-NOTE: C# `using var memoryStream = new MemoryStream(resource.bytes); document = memoryStream.ReadXmlDocument();`
		// Haxe 侧 XmlHelper 已改名为 mvz2.io.XMLHelper，Stream 重载为 ReadXmlDocumentFromStream。
		var memoryStream = new MemoryStream(resource.bytes);
		var document = XMLHelper.ReadXmlDocumentFromStream(memoryStream);
		var metaPath = resID.Path.split("\\").join("/");
		var defaultNsp = main.BuiltinNamespace;
		if (metaPath.indexOf(talksDirectory) == 0)
		{
			var talkRelativePath = metaPath.substr(talksDirectory.length);
			var meta = TalkMeta.FromXmlDocument(document, defaultNsp);
			modResource.TalkMetas.set(talkRelativePath, meta);
		}
		else
		{
			modResource.LoadMetaList(metaPath, document, defaultNsp);
		}
	}
	private function LoadMetaLists(modNamespace:String):Task
	{
		var modResource = GetModResource(modNamespace);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResources(TextAsset, modNamespace, "Meta");
		for (pair in resources)
		{
			LoadSingleMetaList(modResource, pair.key, pair.resource);
		}
		return Task.CompletedTask;
	}
	// TODO-PORT: C# 泛型方法 `GetLabeledResourceLocations<T>(string, string)` 在 Haxe 中以
	// 显式 Class<T> 参数代替泛型类型参数（Haxe 运行期无泛型类型信息）。
	private function GetLabeledResourceLocations<T>(type:Class<T>, modNamespace:String, label:String):Array<Dynamic>
	{
		var locator = Main.ModManager.GetModInfo(modNamespace).ResourceLocator;
		// PORT-NOTE: 移植层的 ModInfo.ResourceLocator 目前恒为 null（见 ModManager.LoadModInfos），
		// 原工程此时会由 Addressables 返回该标签下的定位符。这里判空后返回空列表，
		// 使没有定位符的资源类型退化为「未找到」而不是空引用崩溃。
		// TODO-PORT: 待 Addressables 定位符（工作包 ②）落地后，此分支不再被走到。
		if (locator == null)
		{
			Debug.LogWarning('ResourceManager: MOD $modNamespace 没有资源定位符，标签 $label 的资源不可用。');
			return [];
		}
		// PORT-NOTE: C# 通过反射把 T 规约为数组/列表的元素类型；Haxe 中由调用方直接传入元素类型。
		return locator.Locate(label, type);
	}
	// TODO-PORT: C# 同名重载 `GetLabeledResourceLocations<T>(string, MergeMode, params string[] labels)`。
	private function GetLabeledResourceLocationsMulti<T>(type:Class<T>, modNamespace:String, mergeMode:MergeMode, labels:Array<String>):Array<Dynamic>
	{
		var locator = Main.ModManager.GetModInfo(modNamespace).ResourceLocator;

		var locations:Array<Dynamic> = [];
		if (mergeMode == MergeMode.None)
			return null;
		// PORT-NOTE: 同 GetLabeledResourceLocations，定位符缺失时按「无匹配资源」处理。
		if (locator == null)
		{
			Debug.LogWarning('ResourceManager: MOD $modNamespace 没有资源定位符，标签 ${labels.join(",")} 的资源不可用。');
			return [];
		}
		for (i in 0...labels.length)
		{
			var label = labels[i];
			// PORT-NOTE: ModInfo.ResourceLocator 是 Dynamic，Haxe 无法在其结果上直接迭代，
			// 显式标注为 Array<Dynamic> 后再用。
			var locs:Array<Dynamic> = locator.Locate(label, type);
			if (locs == null)
				continue;
			switch (mergeMode)
			{
				case MergeMode.UseFirst:
					continue;
				case MergeMode.Union:
					for (l in locs)
						addUniqueLocation(locations, l);
				case MergeMode.Intersection:
					if (i > 0)
					{
						var kept:Array<Dynamic> = [];
						for (l in locations)
						{
							if (containsLocation(locs, l))
								kept.push(l);
						}
						locations = kept;
					}
					else
					{
						for (l in locs)
							addUniqueLocation(locations, l);
					}
				case MergeMode.None:
			}
		}
		return locations;
	}
	private function addUniqueLocation(locations:Array<Dynamic>, loc:Dynamic):Void
	{
		for (l in locations)
		{
			if (l.PrimaryKey == loc.PrimaryKey && l.ResourceType == loc.ResourceType && l.InternalId == loc.InternalId)
				return;
		}
		locations.push(loc);
	}
	private function containsLocation(locations:Array<Dynamic>, loc:Dynamic):Bool
	{
		for (l in locations)
		{
			if (l.PrimaryKey == loc.PrimaryKey && l.ResourceType == loc.ResourceType && l.InternalId == loc.InternalId)
				return true;
		}
		return false;
	}
	private function LoadResourcesByLocations<T>(type:Class<T>, locations:Array<Dynamic>, ?progress:TaskProgress):Array<ResourceLoadPair<T>>
	{
		if (locations == null)
			return [];
		var loaded:Array<ResourceLoadPair<T>> = [];
		var loadedCount = 0;
		var maxConcurrency = Mathf.Max(3, Std.int(locations.length / 10));
		var yieldCounter = 0;
		var maxYieldCount = maxConcurrency;

		// PORT-NOTE: C# 使用 SemaphoreSlim + async/await 控制并发。
		// Haxe 侧 Task shim 无异步调度，这里退化为顺序加载，其余逻辑（进度、错误处理）保持一致。
		// TODO-PORT: 并发加载在 Haxe 中没有等价实现。
		for (loc in locations)
		{
			// PORT-NOTE(防段错误): 移植层部分清单条目没有 PrimaryKey（坏条目/未还原资产），
			// 直接传给 NamespaceID.Parse 会 null.indexOf 段错误；按缺失跳过。
			if (loc == null || loc.PrimaryKey == null)
			{
				Debug.LogWarning('资源定位符为空或缺少 PrimaryKey，跳过。');
				continue;
			}
			// PORT-NOTE: C# 是 `Addressables.LoadAssetAsync<T>(loc)`（按定位符加载具体文件；同一个
			// address 可能有多条定位符，如 mvz2:castle 的 areamodel/mapmodel）。Haxe 泛型在运行期无类型
			// 信息，T 由调用方的变量类型标注固定为 Dynamic；定位符本身继续按位置传入，避免按地址取歧义。
			var handle:AsyncOperationHandle<Dynamic> = Addressables.LoadAssetAsyncByLocation(loc);
			if (progress != null)
				progress.SetCurrentTaskName('Loading ${loc.PrimaryKey}');
			var resID = NamespaceID.Parse(loc.PrimaryKey, Main.BuiltinNamespace);
			try
			{
				// PORT-NOTE: C# 为 `handle.Result`；Haxe 的 AsyncOperationHandle shim 提供等价的 WaitForCompletion()。
				var res:T = cast handle.WaitForCompletion();
				// PORT-NOTE: 移植层的 ResourceManifest 对「无法在移植层还原的资产」按约定返回 null + 警告、
				// 不抛异常（见 unity/addressableassets/ResourceManifest.hx 类注释；典型例子是
				// mvz2:init/init_manifest、mvz2:manifest 这类 spritemanifests/*.asset Unity 专有格式）。
				// C# 侧 Addressables 不会给出 null，因此所有调用方都没有判空——直接放进 ResourceLoadPair
				// 会让 LoadInitSpriteManifests(:1798)/LoadMainSpriteManifests(:1812) 等把 null 传进
				// LoadSpriteManifest（:1828 `manifest.spriteEntries`）造成空引用崩溃。
				// 这里按「资源缺失 = 无匹配资源」处理（与 GetLabeledResourceLocations 无定位符时的语义一致）。
				if (res == null)
				{
					Debug.LogWarning('资源（$type）$resID 在移植层无法还原，按缺失处理。');
				}
				else
				{
					// PORT-NOTE: C# 的元组 (NamespaceID resID, T resource) 在 Haxe 中由 ResourceLoadPair<T> 表达。
					loaded.push(new ResourceLoadPair<T>(resID, res));
				}
			}
			catch (e:Dynamic)
			{
				Debug.LogError('资源（${type}）$resID加载失败：$e');
			}
			loadedCount++;
			if (progress != null)
				progress.SetProgress(loadedCount / locations.length);
			yieldCounter++;
			if (yieldCounter > maxYieldCount)
			{
				yieldCounter = 0;
			}
		}
		if (progress != null)
			progress.SetProgress(1, "Finished");
		return loaded;
	}
	private function LoadLabeledResources<T>(type:Class<T>, modNamespace:String, label:String, ?progress:TaskProgress):Array<ResourceLoadPair<T>>
	{
		var locs = GetLabeledResourceLocations(type, modNamespace, label);
		return LoadResourcesByLocations(type, locs, progress);
	}
	// TODO-PORT: C# 重载 `LoadLabeledResources<T>(string, MergeMode, TaskProgress?, params string[])`。
	private function LoadLabeledResourcesMulti<T>(type:Class<T>, modNamespace:String, mergeMode:MergeMode, progress:Null<TaskProgress>, labels:Array<String>):Array<ResourceLoadPair<T>>
	{
		var locs = GetLabeledResourceLocationsMulti(type, modNamespace, mergeMode, labels);
		return LoadResourcesByLocations(type, locs, progress);
	}
	private function LoadModResource<T>(id:NamespaceID, resourceType:ResourceType):T
	{
		if (id == null)
			return null;
		return LoadModResourceByPath(id.SpaceName, id.Path, resourceType);
	}
	// TODO-PORT: C# 重载 `LoadModResource<T>(string nsp, string path, ResourceType)`。
	private function LoadModResourceByPath<T>(nsp:String, path:String, resourceType:ResourceType):T
	{
		var modResource = GetModResource(nsp);
		var locator = Main.ModManager.GetModInfo(nsp).ResourceLocator;
		return LoadAddressableResource(locator, path);
	}
	private function FindInMods<T>(id:Null<NamespaceID>, dictionaryGetter:ModResource->Map<String, T>):T
	{
		if (id == null)
			return null;
		for (mod in modResources)
		{
			if (mod.Namespace != id.SpaceName)
				continue;
			var dict = dictionaryGetter(mod);
			if (dict != null && dict.exists(id.Path))
			{
				return dict.get(id.Path);
			}
		}
		return null;
	}
	private function LoadAddressableResource<T>(locator:Dynamic, key:String):T
	{
		var locs = locator.Locate(key, null);
		if (locs == null)
			return null;
		var loc = locs.length > 0 ? locs[0] : null;
		if (loc == null)
			return null;
		// PORT-NOTE: 同 LoadResourcesByLocations，按定位符（locs[0]，与 C# 的 FirstOrDefault() 一致）
		// 加载具体文件并 cast 回 T。
		var handle:AsyncOperationHandle<Dynamic> = Addressables.LoadAssetAsyncByLocation(loc);
		return cast handle.WaitForCompletion();
	}
	// #endregion
	// #region ResourceManager_Achievements.cs
	public function GetAchievementMetaList(spaceName:String):AchievementMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.AchievementMetaList;
	}
	public function GetModAchievementMetas(spaceName:String):Array<AchievementMeta>
	{
		var stageMetalist = GetAchievementMetaList(spaceName);
		if (stageMetalist == null)
			return null;
		return stageMetalist.metas;
	}
	public function GetAllAchievements():Array<NamespaceID>
	{
		return [for (k in achievementCacheDict.keys()) k];
	}
	public function GetAchievementMeta(entityID:NamespaceID):AchievementMeta
	{
		return achievementCacheDict.exists(entityID) ? achievementCacheDict.get(entityID) : null;
	}
	private function LoadUnlocks_Achievements(resource:ModResource):Void
	{
		if (resource.AchievementMetaList != null)
		{
			for (meta in resource.AchievementMetaList.metas)
			{
				AddConditionListUnlocks(meta.Unlock);
			}
		}
	}
	private var achievementCacheDict:Map<NamespaceID, AchievementMeta> = new Map();
	// #endregion

	// #region ResourceManager_Almanac.cs
	public function GetAlmanacMetaList(nsp:String):AlmanacMetaList
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.AlmanacMetaList;
	}
	public function GetAlmanacMetaEntry(type:String, id:NamespaceID):AlmanacMetaEntry
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var metaList = GetAlmanacMetaList(id.SpaceName);
		if (metaList == null)
			return null;
		// PORT-NOTE: C# `TryGetCategory(string name, out AlmanacCategory category)`；out 参数在
		// Haxe 侧按工程约定用可变结构 `{ value : AlmanacCategory }` 表达。
		var categoryRef = { value: (null : AlmanacCategory) };
		if (!metaList.TryGetCategory(type, categoryRef))
			return null;
		var entries = categoryRef.value;
		var entry = Lambda.find(entries.entries, e -> e.id == id);
		if (entry != null)
			return entry;
		for (g in entries.groups)
		{
			var found = Lambda.find(g.entries, e -> e.id == id);
			if (found != null)
				return found;
		}
		return null;
	}
	public function GetAlmanacMetaEntries(category:String):Array<AlmanacMetaEntry>
	{
		var list:Array<AlmanacMetaEntry> = [];
		for (modResource in modResources)
		{
			var metaList = modResource.AlmanacMetaList;
			if (metaList == null)
				continue;
			for (categoryMeta in metaList.categories)
			{
				if (categoryMeta.name != category || categoryMeta.entries == null)
					continue;
				list = list.concat(categoryMeta.entries);
			}
		}
		return list;
	}
	public function GetAlmanacMetaGroups(category:String):Array<AlmanacMetaGroup>
	{
		var list:Array<AlmanacMetaGroup> = [];
		for (modResource in modResources)
		{
			var metaList = modResource.AlmanacMetaList;
			if (metaList == null)
				continue;
			for (categoryMeta in metaList.categories)
			{
				if (categoryMeta.name != category || categoryMeta.groups == null)
					continue;
				list = list.concat(categoryMeta.groups);
			}
		}
		return list;
	}
	public function GetAlmanacTagMeta(id:NamespaceID):AlmanacTagMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var metaList = GetAlmanacMetaList(id.SpaceName);
		if (metaList == null)
			return null;
		return Lambda.find(metaList.tags, e -> e.id == id.Path);
	}
	public function GetAlmanacGlobalVariable(id:NamespaceID):AlmanacVariable
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var metaList = GetAlmanacMetaList(id.SpaceName);
		if (metaList == null)
			return null;
		return Lambda.find(metaList.globalVariables, e -> e.name == id.Path);
	}
	public function GetAlmanacTagEnumMeta(id:NamespaceID):AlmanacTagEnumMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var metaList = GetAlmanacMetaList(id.SpaceName);
		if (metaList == null)
			return null;
		return Lambda.find(metaList.enums, e -> e.id == id.Path);
	}
	public function GetAllAlmanacTagMetas():Array<AlmanacTagMeta>
	{
		var result:Array<AlmanacTagMeta> = [];
		for (modResource in modResources)
		{
			var metaList = modResource.AlmanacMetaList;
			if (metaList == null)
				continue;
			for (tag in metaList.tags)
			{
				result.push(tag);
			}
		}
		return result;
	}
	public function GetAllAlmanacTagEnumMetas():Array<AlmanacTagEnumMeta>
	{
		var result:Array<AlmanacTagEnumMeta> = [];
		for (modResource in modResources)
		{
			var metaList = modResource.AlmanacMetaList;
			if (metaList == null)
				continue;
			for (tagEnum in metaList.enums)
			{
				result.push(tagEnum);
			}
		}
		return result;
	}
	public function IsContraptionInAlmanac(id:NamespaceID):Bool
	{
		var entry = GetAlmanacMetaEntry(LogicAlmanacCategories.CONTRAPTIONS, id);
		return entry != null && entry.index >= 0;
	}
	public function IsEnemyInAlmanac(id:NamespaceID):Bool
	{
		var entry = GetAlmanacMetaEntry(LogicAlmanacCategories.ENEMIES, id);
		return entry != null && entry.index >= 0;
	}
	private function LoadUnlocks_Almanac(resource:ModResource):Void
	{
		if (resource.AlmanacMetaList == null)
			return;
		for (category in resource.AlmanacMetaList.categories)
		{
			if (category.entries != null)
			{
				for (entry in category.entries)
				{
					AddConditionListUnlocks(entry.unlock);
					AddConditionListUnlocks(entry.encounterUnlock);
					AddConditionListUnlocks(entry.silhouetteUnlock);
				}
			}
			if (category.groups != null)
			{
				for (group in category.groups)
				{
					for (entry in group.entries)
					{
						AddConditionListUnlocks(entry.unlock);
						AddConditionListUnlocks(entry.encounterUnlock);
						AddConditionListUnlocks(entry.silhouetteUnlock);
					}
				}
			}
		}
	}
	// #endregion

	// #region ResourceManager_Arcade.cs
	// #region 元数据列表
	public function GetArcadeMetaList(nsp:String):ArcadeMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.ArcadeMetaList;
	}
	// #endregion

	// #region 元数据
	public function GetArcadeMeta(arcade:NamespaceID):ArcadeMeta
	{
		if (!NamespaceID.IsValid(arcade))
			return null;
		var modResource = main.ResourceManager.GetModResource(arcade.SpaceName);
		if (modResource == null || modResource.ArcadeMetaList == null)
			return null;
		return Lambda.find(modResource.ArcadeMetaList.metas, m -> m.ID == arcade.Path);
	}
	// #endregion
	public function GetAllArcadeItems():Array<NamespaceID>
	{
		return arcadeCache.copy();
	}
	private function LoadUnlocks_Arcade(resource:ModResource):Void
	{
		if (resource.ArcadeMetaList == null)
			return;
		for (meta in resource.ArcadeMetaList.metas)
		{
			AddConditionListUnlocks(meta.HiddenUntil);
		}
	}
	private var arcadeCache:Array<NamespaceID> = [];
	// #endregion

	// #region ResourceManager_Areas.cs
	public function GetAreaMetaList(spaceName:String):AreaMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.AreaMetaList;
	}
	public function GetModAreaMetas(spaceName:String):Array<AreaMeta>
	{
		var stageMetalist = GetAreaMetaList(spaceName);
		if (stageMetalist == null)
			return [];
		return stageMetalist.metas.copy();
	}
	public function GetAreaMeta(mapID:NamespaceID):AreaMeta
	{
		if (mapID == null)
			return null;
		var stageMetalist = GetAreaMetaList(mapID.SpaceName);
		if (stageMetalist == null)
			return null;
		return Lambda.find(stageMetalist.metas, m -> m.ID == mapID.Path);
	}
	// #region 模型
	public function GetAreaModel(id:NamespaceID):AreaModel
	{
		return FindInMods(id, mod -> mod.AreaModels);
	}
	// #endregion


	// #region 私有方法
	private function LoadModAreaModels(nsp:String, progress:TaskProgress):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResources(GameObject, nsp, "AreaModel", progress);
		for (pair in resources)
		{
			// PORT-NOTE: 同 LoadModModels —— AreaModel 标签的资源在移植层是 haxe.io.Bytes
			// （Unity prefab 专有格式尚未转换），不是 GameObject；C# 原文无需判断。
			if (!Std.isOfType(pair.resource, GameObject))
				continue;
			var model = pair.resource.GetComponent(AreaModel);
			modResource.AreaModels.set(pair.key.Path, model);
		}
		return Task.CompletedTask;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Armors.cs
	// #region 元数据列表
	public function GetArmorMetaList(nsp:String):ArmorMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.ArmorMetaList;
	}
	public function GetModArmorMetas(nsp:String):Array<ArmorMeta>
	{
		var metaList = GetArmorMetaList(nsp);
		if (metaList == null)
			return [];
		return metaList.metas.copy();
	}
	public function GetModArmorSlotMetas(nsp:String):Array<ArmorSlotMeta>
	{
		var metaList = GetArmorMetaList(nsp);
		if (metaList == null)
			return [];
		return metaList.slots.copy();
	}
	// #endregion

	// #region 元数据
	public function GetArmorSlotMeta(armorID:NamespaceID):ArmorSlotMeta
	{
		return armorSlotsCacheDict.exists(armorID) ? armorSlotsCacheDict.get(armorID) : null;
	}
	public function GetArmorMeta(armorID:NamespaceID):ArmorMeta
	{
		return armorsCacheDict.exists(armorID) ? armorsCacheDict.get(armorID) : null;
	}
	// #endregion

	private var armorsCacheDict:Map<NamespaceID, ArmorMeta> = new Map();
	private var armorSlotsCacheDict:Map<NamespaceID, ArmorSlotMeta> = new Map();
	// #endregion

	// #region ResourceManager_Artifacts.cs
	// #region 元数据列表
	public function GetArtifactMetaList(nsp:String):ArtifactMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.ArtifactMetaList;
	}
	public function GetModArtifactMetas(nsp:String):Array<ArtifactMeta>
	{
		var metaList = GetArtifactMetaList(nsp);
		if (metaList == null)
			return [];
		return metaList.metas.copy();
	}
	// #endregion

	// #region 元数据
	public function GetArtifactName(entityID:NamespaceID):String
	{
		return Main.Game.GetArtifactName(entityID);
	}
	public function GetArtifactTooltip(entityID:NamespaceID):String
	{
		return Main.Game.GetArtifactTooltip(entityID);
	}
	// #endregion
	private function LoadUnlocks_Artifacts(resource:ModResource):Void
	{
		if (resource.ArtifactMetaList == null)
			return;
		for (meta in resource.ArtifactMetaList.metas)
		{
			AddConditionListUnlocks(meta.UnlockConditions);
		}
	}
	// #endregion

	// #region ResourceManager_Buffs.cs
	// #region 生成
	public function GetBuffMetaList(spaceName:String):BuffMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.BuffMetaList;
	}
	public function GetModBuffMetas(spaceName:String):Array<BuffMeta>
	{
		var metalist = GetBuffMetaList(spaceName);
		if (metalist == null)
			return null;
		return metalist.metas.copy();
	}
	public function GetBuffMeta(id:NamespaceID):BuffMeta
	{
		if (id == null)
			return null;
		var metalist = GetBuffMetaList(id.SpaceName);
		if (metalist == null)
			return null;
		return Lambda.find(metalist.metas, m -> m.ID == id.Path);
	}
	// #endregion
	// #endregion

	// #region ResourceManager_ChapterTransitions.cs
	public function GetAllChapterTransitions():Array<NamespaceID>
	{
		var result:Array<NamespaceID> = [];
		for (modResource in modResources)
		{
			if (modResource == null || modResource.ChapterTransitionMetaList == null)
				continue;
			var nsp = modResource.Namespace;
			for (meta in modResource.ChapterTransitionMetaList.Metas)
			{
				result.push(new NamespaceID(nsp, meta.ID));
			}
		}
		return result;
	}
	public function GetChapterTransitionMetaList(spaceName:String):ChapterTransitionMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.ChapterTransitionMetaList;
	}
	public function GetModChapterTransitionMetas(spaceName:String):Array<ChapterTransitionMeta>
	{
		var metalist = GetChapterTransitionMetaList(spaceName);
		if (metalist == null)
			return null;
		return metalist.Metas.copy();
	}
	public function GetChapterTransitionMeta(id:NamespaceID):ChapterTransitionMeta
	{
		if (id == null)
			return null;
		var metalist = GetChapterTransitionMetaList(id.SpaceName);
		if (metalist == null)
			return null;
		return Lambda.find(metalist.Metas, m -> m.ID == id.Path);
	}
	// #endregion

	// #region ResourceManager_Characters.cs
	// #region 元数据列表
	public function GetCharacterMetaList(nsp:String):TalkCharacterMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.TalkCharacterMetaList;
	}
	// #endregion

	// #region 元数据
	public function GetCharacterMeta(characterID:NamespaceID):TalkCharacterMeta
	{
		if (!NamespaceID.IsValid(characterID))
			return null;
		var modResource = main.ResourceManager.GetModResource(characterID.SpaceName);
		if (modResource == null || modResource.TalkCharacterMetaList == null)
			return null;
		return Lambda.find(modResource.TalkCharacterMetaList.metas, m -> m.id == characterID.Path);
	}
	// #endregion

	public function GetCharacterName(characterID:NamespaceID):String
	{
		var character = GetCharacterMeta(characterID);
		return GetCharacterNameByKey(character != null && character.name != null ? character.name : "");
	}
	// TODO-PORT: C# 重载 GetCharacterName(string nameKey)，重命名以区分。
	public function GetCharacterNameByKey(nameKey:String):String
	{
		return main.LanguageManager._p(LogicStrings.CONTEXT_CHARACTER_NAME, nameKey);
	}


	private function LoadUnlocks_Characters(resource:ModResource):Void
	{
		if (resource.TalkCharacterMetaList == null)
			return;
		for (meta in resource.TalkCharacterMetaList.metas)
		{
			for (variant in meta.variants)
			{
				AddConditionListUnlocks(variant.unlock);
			}
		}
	}
	// #endregion

	// #region ResourceManager_Commands.cs
	public function GetModCommandMetas(nsp:String):Array<CommandMeta>
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null || modResource.CommandMetaList == null)
			return [];
		return modResource.CommandMetaList.metas.copy();
	}
	// #endregion

	// #region ResourceManager_Credits.cs
	// #region 元数据列表
	public function GetCreditsMetaList(nsp:String):CreditMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.CreditsMetaList;
	}
	// #endregion

	// #region 分类
	public function GetAllCreditsCategories():Array<CreditsCategoryMeta>
	{
		var categories:Array<CreditsCategoryMeta> = [];
		for (modResource in modResources)
		{
			var creditsMetaList = modResource != null ? modResource.CreditsMetaList : null;
			if (creditsMetaList == null)
				continue;
			categories = categories.concat(creditsMetaList.categories);
		}
		return categories;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Difficulties.cs
	// #region 元数据列表
	public function GetModDifficultyMetas(nsp:String):Array<DifficultyMeta>
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null || modResource.DifficultyMetaList == null)
			return [];
		return modResource.DifficultyMetaList.metas;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Entities.cs
	// #region 元数据列表
	public function GetEntityMetaList(nsp:String):EntityMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.EntityMetaList;
	}
	public function GetModEntityMetas(nsp:String):Array<EntityMeta>
	{
		var metaList = GetEntityMetaList(nsp);
		if (metaList == null)
			return [];
		return metaList.metas.copy();
	}
	// #endregion

	// #region 元数据
	public function GetEntityDeathMessage(entityID:NamespaceID):String
	{
		return Main.Game.GetEntityDeathMessage(entityID);
	}
	public function GetEntityName(entityID:NamespaceID):String
	{
		return Main.Game.GetEntityName(entityID);
	}
	public function GetEntityTooltip(entityID:NamespaceID):String
	{
		return Main.Game.GetEntityTooltip(entityID);
	}
	// #endregion

	// #region 实体对策
	public function GetModEntityCounterMetas(nsp:String):Array<EntityCounterMeta>
	{
		var modResource = GetModResource(nsp);
		if (modResource == null || modResource.EntityMetaList == null)
			return [];
		return modResource.EntityMetaList.counters;
	}
	// #endregion
	private function LoadUnlocks_Entities(resource:ModResource):Void
	{
		if (resource.EntityMetaList == null)
			return;
		for (meta in resource.EntityMetaList.metas)
		{
			AddConditionListUnlocks(meta.Unlock);
		}
	}
	// #endregion

	// #region ResourceManager_Fragments.cs
	// #region 元数据
	public function GetFragmentMetaList(nsp:String):FragmentMetaList
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.FragmentMetaList;
	}
	// #endregion

	// #region 碎片渐变
	public function GetFragmentGradient(id:NamespaceID):Gradient
	{
		var meta = GetFragmentMetaList(id.SpaceName);
		if (meta == null)
			return null;
		var fragment = Lambda.find(meta.metas, m -> m.ID == id.Path);
		return fragment != null ? fragment.Gradient : null;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Grids.cs
	// #region 层
	public function GetGridMeta(id:NamespaceID):GridMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var modResource = main.ResourceManager.GetModResource(id.SpaceName);
		if (modResource == null || modResource.GridMetaList == null)
			return null;
		return Lambda.find(modResource.GridMetaList.metas, m -> m.ID == id.Path);
	}
	// #endregion

	// #region 层
	public function GetModGridLayerMetas(nsp:String):Array<GridLayerMeta>
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null || modResource.GridMetaList == null)
			return [];
		return modResource.GridMetaList.layers;
	}
	// #endregion

	// #region 错误
	public function GetModGridErrorMetas(nsp:String):Array<GridErrorMeta>
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null || modResource.GridMetaList == null)
			return [];
		return modResource.GridMetaList.errors;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_MainmenuView.cs
	public function GetMainmenuViewMetaList(spaceName:String):MainmenuViewMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.MainmenuViewMetaList;
	}
	public function GetModMainmenuViewMetas(spaceName:String):Array<MainmenuViewMeta>
	{
		var metaList = GetMainmenuViewMetaList(spaceName);
		if (metaList == null)
			return null;
		return metaList.Metas;
	}
	public function GetAllMainmenuViews():Array<NamespaceID>
	{
		return [for (k in mainmenuViewCacheDict.keys()) k];
	}
	public function GetMainmenuViewMeta(id:NamespaceID):MainmenuViewMeta
	{
		return mainmenuViewCacheDict.exists(id) ? mainmenuViewCacheDict.get(id) : null;
	}
	private function LoadUnlocks_MainmenuView(resource:ModResource):Void
	{
		if (resource.MainmenuViewMetaList == null)
			return;
		for (meta in resource.MainmenuViewMetaList.Metas)
		{
			AddConditionListUnlocks(meta.Conditions);
		}
	}
	private var mainmenuViewCacheDict:Map<NamespaceID, MainmenuViewMeta> = new Map();
	// #endregion

	// #region ResourceManager_Maps.cs
	public function GetFirstMapID():NamespaceID
	{
		for (mod in modResources)
		{
			var stageMetalist = mod.MapMetaList;
			if (stageMetalist == null)
				continue;
			var meta = stageMetalist.metas.length > 0 ? stageMetalist.metas[0] : null;
			if (meta == null)
				continue;
			return new NamespaceID(mod.Namespace, meta.id);
		}
		return VanillaMapID.halloween;
	}
	public function GetModMapMetaList(spaceName:String):MapMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.MapMetaList;
	}
	public function GetModMapMetas(spaceName:String):Array<MapMeta>
	{
		var stageMetalist = GetModMapMetaList(spaceName);
		if (stageMetalist == null)
			return null;
		return stageMetalist.metas.copy();
	}
	public function GetMapMeta(mapID:NamespaceID):MapMeta
	{
		if (mapID == null)
			return null;
		var stageMetalist = GetModMapMetaList(mapID.SpaceName);
		if (stageMetalist == null)
			return null;
		return Lambda.find(stageMetalist.metas, m -> m.id == mapID.Path);
	}

	// #region 模型
	public function GetMapModel(id:NamespaceID):MapModel
	{
		return FindInMods(id, mod -> mod.MapModels);
	}
	// #endregion

	// #region 元素
	public function GetModMapElementMetas(spaceName:String):Array<MapElementMeta>
	{
		var metalist = GetModMapMetaList(spaceName);
		if (metalist == null)
			return [];
		return metalist.elements.copy();
	}
	// #endregion

	// #region 私有方法
	private function LoadModMapModels(nsp:String, progress:TaskProgress):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResources(GameObject, nsp, "MapModel", progress);
		for (pair in resources)
		{
			// PORT-NOTE: 同 LoadModModels，未还原成 GameObject 的 prefab 字节按缺失跳过。
			if (!Std.isOfType(pair.resource, GameObject))
				continue;
			var model = pair.resource.GetComponent(MapModel);
			modResource.MapModels.set(pair.key.Path, model);
		}
		return Task.CompletedTask;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Models.cs
	// #region 元数据列表
	public function GetModelMetaList(nsp:String):ModelMetaList
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.ModelMetaList;
	}
	public function GetModModelMetas(nsp:String):Array<ModelMeta>
	{
		var metaList = GetModelMetaList(nsp);
		if (metaList == null)
			return [];
		return metaList.metas.copy();
	}
	// #endregion

	// #region 元数据
	public function GetModelMeta(id:NamespaceID):ModelMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var meta = GetModelMetaList(id.SpaceName);
		if (meta == null)
			return null;
		return Lambda.find(meta.metas, m -> EngineModelID.ConcatName(m.Type, m.Name) == id.Path);
	}
	// #endregion


	// #region 元数据
	public function GetModelArmorConfigMeta(id:NamespaceID):ModelArmorConfigMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var meta = GetModelMetaList(id.SpaceName);
		if (meta == null)
			return null;
		return Lambda.find(meta.armorConfigs, c -> c.ID == id.Path);
	}
	// #endregion

	// #region 模型
	public function GetModelByPath(nsp:String, path:String):Model
	{
		return GetModel(new NamespaceID(nsp, path));
	}
	// TODO-PORT: C# 重载 GetModel(NamespaceID id)，重命名以区分。
	public function GetModel(id:NamespaceID):Model
	{
		return FindInMods(id, mod -> mod.Models);
	}
	// #endregion

	// #region 模型图标
	public function GetModelIcon(id:NamespaceID):Sprite
	{
		return FindInMods(id, mod -> mod.ModelIcons);
	}
	// #endregion

	// #region 私有方法
	private function LoadModModels(nsp:String, progress:TaskProgress):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResources(GameObject, nsp, "Model", progress);

		for (pair in resources)
		{
			// PORT-NOTE: 移植层 Model 标签的资源由 ResourceManifest 返回 haxe.io.Bytes
			// （Unity prefab 专有格式尚未转换，见 ResourceManifest.hx 的 KIND_MODEL 分派），
			// 不是 GameObject；C# 的 Addressables 只会返回真 prefab，故原文没有这个判断。
			// 按本文件 :448 已有的约定「移植层无法还原 = 无匹配资源」跳过；模型的实际创建
			// 由 ModelBuilder 经 ModelPrefabLoader 走 assets/models_manifest.json 完成。
			if (!Std.isOfType(pair.resource, GameObject))
				continue;
			var model = pair.resource.GetComponent(Model);
			modResource.Models.set(pair.key.Path, model);
		}
		return Task.CompletedTask;
	}
	private function ShotModelIcons(modNamespace:String, progress:TaskProgress, maxYieldCount:Int = 4):Coroutine
	{
		return Coroutine.create(function(co:CoroutineContext)
		{
			var modResource = GetModResource(modNamespace);
			if (modResource == null)
				return;
			var metaList = modResource.ModelMetaList;
			if (metaList == null)
				return;

			var metas = metaList.metas;
			var count = metas.length;
			var yieldCounter = 0;
			for (i in 0...count)
			{
				var meta = metas[i];

				var modelID = meta.Path;
				var metaPath = EngineModelID.ConcatName(meta.Type, meta.Name);
				var metaID = new NamespaceID(modNamespace, metaPath);
				var spritePath = 'model_icon/$metaPath';
				var modelSprite:Sprite;
				if (NamespaceID.IsValid(modelID))
				{
					var sprite:Sprite = null;
					if (meta.Shot)
					{
						// TODO-PORT: C# 的 `unity.UnityObject.exists(sprite)` 是 Unity 隐式 bool 转换（判断非 null 且对象未被销毁），
						// Haxe 侧以 null 判断代替，见 unity.UnityObject.exists(unity.Sprite)。
						sprite = main.ModelManager.ShotIcon(metaID, meta.Width, meta.Height, new Vector2(meta.XOffset, meta.YOffset), metaID.toString());
					}
					if (!unity.UnityObject.exists(sprite))
					{
						sprite = GetDefaultSpriteClone();
					}
					modelSprite = sprite;
				}
				else
				{
					modelSprite = GetDefaultSpriteClone();
					Debug.LogWarning('Model prefab $metaID is missing.');
				}
				modResource.ModelIcons.set(metaPath, modelSprite);
				modResource.Sprites.set(spritePath, modelSprite);

				progress.SetProgress(1 / count, metaID.toString());
				yieldCounter++;
				if (yieldCounter >= maxYieldCount)
				{
					yieldCounter = 0;
					co.waitFrames(1);
				}
			}
			progress.SetProgress(1, "Finished");
		});
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Music.cs
	// #region 元数据列表
	public function GetMusicMetaList(nsp:String):MusicMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.MusicMetaList;
	}
	// #endregion

	// #region 元数据
	public function GetMusicMeta(music:NamespaceID):MusicMeta
	{
		if (music == null)
			return null;
		var modResource = GetModResource(music.SpaceName);
		if (modResource == null || modResource.MusicMetaList == null)
			return null;
		return Lambda.find(modResource.MusicMetaList.metas, m -> m.ID == music.Path);
	}
	public function GetAllMusicID():Array<NamespaceID>
	{
		var list:Array<NamespaceID> = [];
		for (modResource in modResources)
		{
			if (modResource == null || modResource.MusicMetaList == null)
				continue;
			for (m in modResource.MusicMetaList.metas)
			{
				list.push(new NamespaceID(modResource.Namespace, m.ID));
			}
		}
		return list;
	}
	// #endregion

	// #region 音频片段
	public function GetMusicClip(path:NamespaceID):AudioClip
	{
		return FindInMods(path, mod -> mod.Musics);
	}
	// #endregion
	public function GetMusicName(musicID:NamespaceID):String
	{
		if (NamespaceID.IsValid(musicID))
		{
			var meta = GetMusicMeta(musicID);
			if (meta != null)
			{
				return main.LanguageManager._p(LogicStrings.CONTEXT_MUSIC_NAME, meta.Name);
			}
		}
		return main.LanguageManager._p(LogicStrings.CONTEXT_MUSIC_NAME, LogicStrings.MUSIC_NAME_NONE);
	}

	// #region 私有方法
	private function LoadInitModMusicClips(nsp:String):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResourcesMulti(AudioClip, nsp, MergeMode.Intersection, null, ["Init", "Music"]);
		for (pair in resources)
		{
			modResource.Musics.set(pair.key.Path, pair.resource);
		}
		return Task.CompletedTask;
	}
	private function LoadMainModMusicClips(nsp:String, progress:TaskProgress):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResourcesMulti(AudioClip, nsp, MergeMode.Intersection, progress, ["Main", "Music"]);
		for (pair in resources)
		{
			modResource.Musics.set(pair.key.Path, pair.resource);
		}
		return Task.CompletedTask;
	}
	private function LoadUnlocks_Music(resource:ModResource):Void
	{
		if (resource.MusicMetaList == null)
			return;
		for (meta in resource.MusicMetaList.metas)
		{
			AddConditionListUnlocks(meta.UnlockConditions);
		}
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Notes.cs
	// #region 元数据列表
	public function GetNoteMetaList(nsp:String):NoteMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.NoteMetaList;
	}
	// #endregion

	// #region 元数据
	public function GetNoteMeta(note:NamespaceID):NoteMeta
	{
		var modResource = main.ResourceManager.GetModResource(note.SpaceName);
		if (modResource == null || modResource.NoteMetaList == null)
			return null;
		return Lambda.find(modResource.NoteMetaList.metas, m -> m.id == note.Path);
	}
	// #endregion
	public function GetAllNotes():Array<NamespaceID>
	{
		return noteCache.copy();
	}
	private var noteCache:Array<NamespaceID> = [];
	// #endregion

	// #region ResourceManager_Options.cs
	public function GetOptionItemMeta(id:NamespaceID):OptionItemMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var modResource = GetModResource(id.SpaceName);
		if (modResource == null || modResource.OptionMetaList == null)
			return null;
		return Lambda.find(modResource.OptionMetaList.items, i -> i.ID == id.Path);
	}
	public function GetAllOptionItemsID():Array<NamespaceID>
	{
		var idList:Array<NamespaceID> = [];
		for (resource in modResources)
		{
			if (resource == null || resource.OptionMetaList == null)
				continue;
			for (item in resource.OptionMetaList.items)
			{
				idList.push(new NamespaceID(resource.Namespace, item.ID));
			}
		}
		return idList;
	}
	public function GetOptionCategoryMeta(id:NamespaceID):OptionCategoryMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var modResource = GetModResource(id.SpaceName);
		if (modResource == null || modResource.OptionMetaList == null)
			return null;
		return Lambda.find(modResource.OptionMetaList.categories, i -> i.ID == id.Path);
	}
	public function GetOptionWidgetMeta(id:NamespaceID):OptionWidgetMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var modResource = GetModResource(id.SpaceName);
		if (modResource == null || modResource.OptionMetaList == null)
			return null;
		return Lambda.find(modResource.OptionMetaList.widgets, i -> i.ID == id.Path);
	}
	// #endregion

	// #region ResourceManager_ProgressBars.cs
	public function GetProgressBarMetaList(spaceName:String):ProgressBarMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.ProgressBarMetaList;
	}
	public function GetModProgressBarMetas(spaceName:String):Array<ProgressBarMeta>
	{
		var barMetalist = GetProgressBarMetaList(spaceName);
		if (barMetalist == null)
			return null;
		return barMetalist.metas.copy();
	}
	public function GetProgressBarMeta(progressBarID:NamespaceID):ProgressBarMeta
	{
		if (progressBarID == null)
			return null;
		var barMetalist = GetProgressBarMetaList(progressBarID.SpaceName);
		if (barMetalist == null)
			return null;
		return Lambda.find(barMetalist.metas, m -> m.ID == progressBarID.Path);
	}
	// #endregion

	// #region ResourceManager_Shapes.cs
	public function GetShapeMetaList(nsp:String):ShapeMetaList
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.ShapeMetaList;
	}
	public function GetShapeMeta(id:NamespaceID):ShapeMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var list = GetShapeMetaList(id.SpaceName);
		if (list == null)
			return null;
		return Lambda.find(list.metas, m -> m.ID == id.Path);
	}
	public function GetModShapeMetas(nsp:String):Array<ShapeMeta>
	{
		var metaList = GetShapeMetaList(nsp);
		if (metaList == null)
			return [];
		return metaList.metas.copy();
	}
	// #endregion

	// #region ResourceManager_Sounds.cs
	// #region 元数据列表
	public function GetSoundMetaList(nsp:String):SoundMetaList
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.SoundMetaList;
	}
	// #endregion

	// #region 元数据
	public function GetSoundMeta(id:NamespaceID):SoundMeta
	{
		var soundMeta = GetSoundMetaList(id.SpaceName);
		if (soundMeta == null)
			return null;
		return Lambda.find(soundMeta.metas, m -> m.name == id.Path);
	}
	// #endregion

	// #region 音频片段
	public function GetSoundClip(id:NamespaceID):AudioClip
	{
		return FindInMods(id, mod -> mod.Sounds);
	}
	// #endregion

	// #region 私有方法
	private function LoadInitModSoundClips(nsp:String):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResourcesMulti(AudioClip, nsp, MergeMode.Intersection, null, ["Init", "Sound"]);
		for (pair in resources)
		{
			modResource.Sounds.set(pair.key.Path, pair.resource);
		}
		return Task.CompletedTask;
	}
	private function LoadMainModSoundClips(nsp:String, progress:TaskProgress):Task
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResourcesMulti(AudioClip, nsp, MergeMode.Intersection, progress, ["Main", "Sound"]);
		for (i in 0...resources.length)
		{
			var pair = resources[i];
			modResource.Sounds.set(pair.key.Path, pair.resource);
			if (progress != null)
				progress.SetCurrentTaskName('Added ${pair.key.Path}');
		}
		return Task.CompletedTask;
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Spawns.cs
	// #region 生成
	public function GetModSpawnMetas(spaceName:String):Array<SpawnMeta>
	{
		var resources = GetModResource(spaceName);
		if (resources == null || resources.SpawnMetaList == null)
			return [];
		return resources.SpawnMetaList.Metas.copy();
	}
	public function GetSpawnMeta(id:NamespaceID):SpawnMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var resources = GetModResource(id.SpaceName);
		if (resources == null || resources.SpawnMetaList == null)
			return null;
		return Lambda.find(resources.SpawnMetaList.Metas, e -> e.ID == id.Path);
	}
	// #endregion
	// #endregion

	// #region ResourceManager_Sprites.cs
	public function GetSpriteByPath(nsp:String, path:String):Sprite
	{
		return GetSprite(new NamespaceID(nsp, path));
	}
	// TODO-PORT: C# 重载 GetSprite(NamespaceID id)，重命名以区分。
	public function GetSprite(id:NamespaceID):Sprite
	{
		return FindInMods(id, mod -> mod.Sprites);
	}
	// TODO-PORT: C# 重载 GetSprite(SpriteReference spriteRef)，重命名以区分。
	public function GetSpriteFromReference(spriteRef:SpriteReference):Sprite
	{
		if (!SpriteReference.IsValid(spriteRef))
			return null;
		if (spriteRef.IsSheet)
		{
			var sheet = GetSpriteSheet(spriteRef.ID);
			if (sheet == null)
				return null;
			if (spriteRef.Index >= sheet.length)
				return null;
			return sheet[spriteRef.Index];
		}
		else
		{
			return GetSprite(spriteRef.ID);
		}
	}
	public function GetSpriteSheet(id:NamespaceID):Array<Sprite>
	{
		return FindInMods(id, mod -> mod.SpriteSheets);
	}
	public function GetSpriteReference(sprite:Sprite):SpriteReference
	{
		if (sprite == null)
			return null;
		if (spriteReferenceCacheDict.exists(sprite))
		{
			return spriteReferenceCacheDict.get(sprite);
		}
		return null;
	}
	public function GetDefaultSprite():Sprite
	{
		return defaultSprite;
	}
	public function GetDefaultSpriteClone():Sprite
	{
		// PORT-NOTE: Unity 的 Object.Instantiate 返回资源副本，Haxe 侧 Sprite 为引用类型，直接返回同一实例。
		return defaultSprite;
	}
	public function CreateSprite(texture:Texture2D, rect:Rect, pivot:Vector2, name:String, category:String = "default"):Sprite
	{
		var sprite = Sprite.Create(texture, rect, pivot);
		sprite.name = name;
		if (generatedSpriteManifest != null && Application.isEditor)
		{
			var background = Sprite.Create(backgroundTex, rect, pivot);
			background.name = name;
			generatedSpriteManifest.AddSprite(category, sprite, background);
		}
		return sprite;
	}
	public function RemoveCreatedSprite(sprite:Sprite, name:String, category:String):Void
	{
		if (generatedSpriteManifest != null && Application.isEditor)
		{
			generatedSpriteManifest.RemoveSprite(category, sprite.name);
		}
		UnityObject.destroy(sprite);
	}
	private function Init_Sprites():Void
	{
		if (Application.isEditor)
		{
			backgroundTex = GenerateSpriteBackgroundTexture(MAX_BACKGROUND_TEX_WIDTH, MAX_BACKGROUND_TEX_HEIGHT);
		}
	}
	private function LoadInitSpriteManifests(modNamespace:String):Task
	{
		var modResource = GetModResource(modNamespace);
		if (modResource == null)
			return Task.CompletedTask;
		// PORT-NOTE: 原工程这一步按 "Init"+"SpriteManifest" 标签加载 SpriteManifest 资产；
		// 移植层没有 Addressables 资产，改为从 tools_build/convert_sprites.py 预生成的
		// assets/sprites_manifest.json 重建等价的 SpriteManifest，再交给同一个
		// LoadSpriteManifest 处理，保证后续模型/视图代码拿到的 Sprites 表与 Unity 一致。
		LoadGeneratedSpriteManifests(modNamespace, modResource, ["Init", "SpriteManifest"]);
		var resources = LoadLabeledResourcesMulti(SpriteManifest, modNamespace, MergeMode.Intersection, null, ["Init", "SpriteManifest"]);
		for (pair in resources)
		{
			// PORT-NOTE: 定位符 mvz2:init/init_manifest、mvz2:manifest 指向 spritemanifests/*.asset，
			// 是 Unity 专有格式、移植层无法还原成 SpriteManifest（加载分派会给出原始 Bytes），
			// 于是下面这行把非 SpriteManifest 的对象强转成 null 再传进去，LoadSpriteManifest 里
			// `manifest.spriteEntries` 直接空引用（debug 构建 Null Object Reference / 默认构建访问违例）。
			// C# 侧 Addressables 按 T=SpriteManifest 反序列化，永远不会给错类型，所以原代码没有这层判断。
			if (!Std.isOfType(pair.resource, SpriteManifest))
				continue;
			LoadSpriteManifest(modNamespace, modResource, pair.resource);
		}
		return Task.CompletedTask;
	}
	private function LoadMainSpriteManifests(modNamespace:String, progress:TaskProgress):Task
	{
		var modResource = GetModResource(modNamespace);
		if (modResource == null)
			return Task.CompletedTask;
		// PORT-NOTE: 同 LoadInitSpriteManifests，只是标签为 "Main"+"SpriteManifest"。
		LoadGeneratedSpriteManifests(modNamespace, modResource, ["Main", "SpriteManifest"]);
		var resources = LoadLabeledResourcesMulti(SpriteManifest, modNamespace, MergeMode.Intersection, progress, ["Main", "SpriteManifest"]);
		for (pair in resources)
		{
			// PORT-NOTE: 同 LoadInitSpriteManifests——非 SpriteManifest（spritemanifests/*.asset 在移植层
			// 无法还原）一律按缺失跳过，避免强转成 null 后在 LoadSpriteManifest 里空引用。
			if (!Std.isOfType(pair.resource, SpriteManifest))
				continue;
			LoadSpriteManifest(modNamespace, modResource, pair.resource);
		}
		return Task.CompletedTask;
	}
	// PORT-NOTE: 移植层新增。把预生成的精灵清单（assets/sprites_manifest.json）按标签
	// 还原成本工程 SpriteManifest 资产的内容，等价于原工程 Addressables 按标签加载
	// spritemanifests/*.asset 的结果（见 tools_build/convert_sprites.py 的 manifestLabels）。
	private function LoadGeneratedSpriteManifests(modNamespace:String, modResource:ModResource, labels:Array<String>):Void
	{
		for (manifest in SpriteManifestLoader.createSpriteManifests(labels))
		{
			LoadSpriteManifest(modNamespace, modResource, manifest);
		}
	}
	private function LoadSpriteManifest(modNamespace:String, modResource:ModResource, manifest:SpriteManifest):Void
	{
		if (manifest.spriteEntries != null)
		{
			for (entry in manifest.spriteEntries)
			{
				if (entry.name == null || entry.name == "")
					continue;
				var sprite = entry.sprite;
				if (!unity.UnityObject.exists(sprite))
					continue;
				var id = new NamespaceID(modNamespace, entry.name);
				modResource.Sprites.set(entry.name, sprite);
				AddSpriteReferenceCache(new SpriteReference(id), sprite);
			}
		}
		if (manifest.spritesheetEntries != null)
		{
			for (entry in manifest.spritesheetEntries)
			{
				if (entry.name == null || entry.name == "")
					continue;
				var sheet = entry.spritesheet;
				if (sheet == null)
					continue;
				var id = new NamespaceID(modNamespace, entry.name);
				modResource.SpriteSheets.set(entry.name, sheet);
				for (i in 0...sheet.length)
				{
					AddSpriteReferenceCache(SpriteReference.FromSheet(id, i), sheet[i]);
				}
			}
		}
	}
	private function LoadSpriteSheets(modNamespace:String):Task
	{
		var modResource = GetModResource(modNamespace);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResources(Array, modNamespace, "Spritesheet");
		for (pair in resources)
		{
			var res:Array<Sprite> = pair.resource;
			modResource.SpriteSheets.set(pair.key.Path, res);
			for (i in 0...res.length)
			{
				// PORT-NOTE: C# 的重载构造函数 SpriteReference(id, index) 在 Haxe 中为静态工厂 FromSheet。
			var sprRef = SpriteReference.FromSheet(pair.key, i);
				AddSpriteReferenceCache(sprRef, res[i]);
			}
		}
		return Task.CompletedTask;
	}
	private function LoadSprites(modNamespace:String):Task
	{
		var modResource = GetModResource(modNamespace);
		if (modResource == null)
			return Task.CompletedTask;
		var resources = LoadLabeledResources(Sprite, modNamespace, "Sprite");
		for (pair in resources)
		{
			modResource.Sprites.set(pair.key.Path, pair.resource);
			var sprRef = new SpriteReference(pair.key);
			AddSpriteReferenceCache(sprRef, pair.resource);
		}
		return Task.CompletedTask;
	}
	private function AddSpriteReferenceCache(sprRef:SpriteReference, sprite:Sprite):Void
	{
		spriteReferenceCacheDict.set(sprite, sprRef);
	}
	private function GenerateSpriteBackgroundTexture(width:Int, height:Int):Texture2D
	{
		var tex = new Texture2D(width, height);
		tex.name = "sprite_background_texture";
		var gray = new Color32(127, 127, 127, 255);
		var darkGray = new Color32(63, 63, 63, 255);
		var colorBuffer = spriteColorBuffer;
		for (x in 0...width)
		{
			if (x % COLOR_BUFFER_WIDTH != 0) continue;
			// PORT-NOTE: C# 的 Mathf.Min(int,int) 返回 int；unity shim 的 Mathf.Min 只接受 Float，
			// 整数版本为 Mathf.MinInt（与 MaxInt 成对）。
			var w = Mathf.MinInt(COLOR_BUFFER_WIDTH, width - x);
			for (y in 0...height)
			{
				if (y % COLOR_BUFFER_HEIGHT != 0) continue;
				var h = Mathf.MinInt(COLOR_BUFFER_HEIGHT, height - y);
				for (ix in 0...w)
				{
					for (iy in 0...h)
					{
						var dstX = x + ix;
						var dstY = x + iy;
						var dstIndex = iy * w + ix;
						colorBuffer[dstIndex] = ((Std.int(dstX / 16) + Std.int(dstY / 16)) % 2 == 0) ? gray : darkGray;
					}
				}
				// TODO-PORT: C# 是 `tex.SetPixels32(x, y, w, h, colorBuffer)`（带子矩形的重载）；
				// unity shim 的 Texture2D.SetPixels32 只有 `SetPixels32(colors:Array<Color32>)`，
				// 子矩形重载缺失，这里退化为整块写入（背景棋盘纹在 shim 中不按块定位）。
				tex.SetPixels32(colorBuffer);
			}
		}
		tex.Apply();
		return tex;
	}
	private var spriteReferenceCacheDict:Map<Sprite, SpriteReference> = new Map();
	private var generatedSpriteTextureDict:Map<Texture2D, Texture2D> = new Map();
	private static inline var COLOR_BUFFER_WIDTH:Int = 128;
	private static inline var COLOR_BUFFER_HEIGHT:Int = 128;
	private static inline var MAX_BACKGROUND_TEX_WIDTH:Int = 2560;
	private static inline var MAX_BACKGROUND_TEX_HEIGHT:Int = 2560;

	@:header("Sprites")
	@:serializeField
	private var defaultSprite:Sprite = null;
	@:serializeField
	private var generatedSpriteManifest:GeneratedSpriteManifest = null;
	private var backgroundTex:Texture2D = null;
	private var spriteColorBuffer:Array<Color32> = [for (i in 0...(COLOR_BUFFER_WIDTH * COLOR_BUFFER_HEIGHT)) new Color32(0, 0, 0, 0)];
	// #endregion

	// #region ResourceManager_Stages.cs
	public function GetModStageMetas(spaceName:String):Array<StageMeta>
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null || modResource.StageMetaList == null)
			return [];
		return modResource.StageMetaList.metas.copy();
	}
	private function LoadUnlocks_Stages(resource:ModResource):Void
	{
		if (resource.StageMetaList == null)
			return;
		for (meta in resource.StageMetaList.metas)
		{
			AddConditionListUnlocks(meta.UnlockConditions);
		}
	}
	// #endregion

	// #region ResourceManager_Stats.cs
	public function GetStatMetaList(spaceName:String):StatMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.StatMetaList;
	}
	public function GetStatCategoryMeta(categoryID:NamespaceID):StatCategoryMeta
	{
		if (categoryID == null)
			return null;
		var stageMetalist = GetStatMetaList(categoryID.SpaceName);
		if (stageMetalist == null)
			return null;
		return Lambda.find(stageMetalist.categories, m -> m.ID == categoryID.Path);
	}
	public function GetStatEntryName(entryID:NamespaceID, type:StatCategoryType):String
	{
		switch (type)
		{
			case StatCategoryType.Entity:
				return GetEntityName(entryID);
			case StatCategoryType.Stage:
				return Main.LevelManager.GetStageName(entryID);
		}
		return entryID.toString();
	}
	public function GetStatDirectEntryMeta(entryID:NamespaceID):StatEntryMeta
	{
		if (!NamespaceID.IsValid(entryID))
			return null;
		var stageMetalist = GetStatMetaList(entryID.SpaceName);
		if (stageMetalist == null)
			return null;
		return Lambda.find(stageMetalist.entries, m -> m.ID == entryID.Path);
	}
	public function ShouldStatEntryDisplay(entryID:NamespaceID, type:StatCategoryType):Bool
	{
		switch (type)
		{
			case StatCategoryType.Entity:
				{
					var entityDef = Main.Game.GetEntityDefinition(entryID);
					if (entityDef == null)
						return false;
					if (entityDef.HideInStats())
						return false;
					return true;
				}
			case StatCategoryType.Stage:
				{
					var stageDef = Main.Game.GetStageDefinition(entryID);
					if (stageDef == null)
						return false;
					if (stageDef.HideInStats())
						return false;
					return true;
				}
		}
		return false;
	}
	// #endregion

	// #region ResourceManager_Store.cs
	// #region 商品
	public function GetProductMeta(groupID:NamespaceID):ProductMeta
	{
		if (!NamespaceID.IsValid(groupID))
			return null;
		return productCacheDict.exists(groupID) ? productCacheDict.get(groupID) : null;
	}
	public function HasProductMeta(groupID:NamespaceID):Bool
	{
		return GetProductMeta(groupID) != null;
	}
	public function GetAllProductsID():Array<NamespaceID>
	{
		return [for (k in productCacheDict.keys()) k];
	}
	// #endregion

	// #region 闲聊
	public function GetCharacterStoreChats(characterID:NamespaceID):Array<StoreChatMeta>
	{
		if (!NamespaceID.IsValid(characterID))
			return null;
		if (!storeChats.exists(characterID))
		{
			return null;
		}
		return storeChats.get(characterID).copy();
	}
	// #endregion

	// #region 剧情对话
	public function GetCurrentStoreLoreTalks():Array<NamespaceID>
	{
		var talks:Array<NamespaceID> = [];
		for (modResource in modResources)
		{
			if (modResource == null)
				continue;
			var loreTalks = modResource.StoreMetaList != null ? modResource.StoreMetaList.LoreTalks : null;
			if (loreTalks == null)
				continue;
			talks = talks.concat(loreTalks.GetLoreTalks(Main.SaveManager));
		}
		return talks;
	}
	// #endregion

	// #region 预设
	public function GetStorePresetMeta(presetID:NamespaceID):StorePresetMeta
	{
		var modResource = GetModResource(presetID.SpaceName);
		if (modResource == null || modResource.StoreMetaList == null)
			return null;
		return Lambda.find(modResource.StoreMetaList.Presets, p -> p.ID == presetID.Path);
	}
	public function GetAllStorePresets():Array<StorePresetMeta>
	{
		var list:Array<StorePresetMeta> = [];
		for (modResource in modResources)
		{
			if (modResource.StoreMetaList == null)
				continue;
			list = list.concat(modResource.StoreMetaList.Presets);
		}
		return list;
	}
	// #endregion

	private function PostLoadMod_Store(modNamespace:String, modResource:ModResource):Void
	{
		if (modResource.StoreMetaList == null)
		{
			return;
		}
		for (meta in modResource.StoreMetaList.Chats)
		{
			if (!storeChats.exists(meta.Character))
			{
				storeChats.set(meta.Character, []);
			}
			storeChats.get(meta.Character).concat(meta.Chats);
		}
		for (meta in modResource.StoreMetaList.Products)
		{
			if (meta.IsEmpty())
				continue;
			productCacheDict.set(new NamespaceID(modNamespace, meta.ID), meta);
		}
	}
	private function LoadUnlocks_Store(resource:ModResource):Void
	{
		if (resource.StoreMetaList == null)
			return;
		for (product in resource.StoreMetaList.Products)
		{
			for (entry in product.Stages)
			{
				AddUnlock(entry.Unlocks);
			}
			AddConditionListUnlocks(product.UnlockConditions);
		}
		for (preset in resource.StoreMetaList.Presets)
		{
			AddConditionListUnlocks(preset.Conditions);
		}
		if (resource.StoreMetaList.LoreTalks != null)
		{
			for (talk in resource.StoreMetaList.LoreTalks.Talks)
			{
				AddConditionListUnlocks(talk.Conditions);
			}
		}
	}
	private function ClearResources_Store():Void
	{
		productCacheDict.clear();
		storeChats.clear();
	}

	private var productCacheDict:Map<NamespaceID, ProductMeta> = new Map();
	private var storeChats:Map<NamespaceID, Array<StoreChatMeta>> = new Map();
	// #endregion

	// #region ResourceManager_Talks.cs
	// #region 对话组
	public function GetTalkGroup(groupID:NamespaceID):TalkGroup
	{
		if (!NamespaceID.IsValid(groupID))
			return null;
		return talksCacheDict.exists(groupID) ? talksCacheDict.get(groupID) : null;
	}
	public function HasTalkGroup(groupID:NamespaceID):Bool
	{
		return GetTalkGroup(groupID) != null;
	}
	public function GetAllTalkGroupsID():Array<NamespaceID>
	{
		return [for (k in talksCacheDict.keys()) k];
	}
	public function CanStartTalk(groupId:NamespaceID, sectionIndex:Int):Bool
	{
		var section = GetTalkSection(groupId, sectionIndex);
		if (section == null)
			return false;
		return true;
	}
	public function WillSkipTalk(groupId:NamespaceID, sectionIndex:Int):Bool
	{
		if (!Main.OptionsManager.SkipAllTalks())
			return false;
		var section = GetTalkSection(groupId, sectionIndex);
		if (section == null)
			return false;
		if (!section.canAutoSkip)
			return false;
		return true;
	}
	// #endregion

	// #region 对话段落
	public function GetTalkSection(groupID:NamespaceID, sectionIndex:Int):TalkSection
	{
		var group = GetTalkGroup(groupID);
		if (group == null || group.sections == null)
			return null;
		if (sectionIndex < 0 || sectionIndex >= group.sections.length)
			return null;
		return group.sections[sectionIndex];
	}
	// #endregion

	// #region 对话语句
	public function GetTalkSentence(groupID:NamespaceID, sectionIndex:Int, sentenceIndex:Int):TalkSentence
	{
		var section = GetTalkSection(groupID, sectionIndex);
		if (section == null || section.sentences == null)
			return null;
		if (sentenceIndex < 0 || sentenceIndex >= section.sentences.length)
			return null;
		return section.sentences[sentenceIndex];
	}
	// #endregion

	// #region 档案标签
	public function GetArchiveMetaList(nsp:String):ArchiveMetaList
	{
		var modResource = GetModResource(nsp);
		if (modResource == null)
			return null;
		return modResource.ArchiveMetaList;
	}
	public function GetArchiveTagMeta(tagID:NamespaceID):ArchiveTagMeta
	{
		var metaList = GetArchiveMetaList(tagID.SpaceName);
		if (metaList == null)
			return null;
		return Lambda.find(metaList.Tags, t -> t.ID == tagID.Path);
	}
	public function GetArchiveTagName(tagID:NamespaceID):String
	{
		var meta = GetArchiveTagMeta(tagID);
		if (meta == null)
			return "";
		return main.LanguageManager._p(LogicStrings.CONTEXT_ARCHIVE_TAG_NAME, meta.Name);
	}
	// #endregion

	private function LoadUnlocks_Talks(resource:ModResource):Void
	{
		if (resource.TalkMetas == null)
			return;
		for (pair in resource.TalkMetas.keyValueIterator())
		{
			if (pair.value == null)
				continue;
			for (group in pair.value.groups)
			{
				AddConditionListUnlocks(group.archive != null ? group.archive.unlockConditions : null);
			}
		}
	}
	private var talksCacheDict:Map<NamespaceID, TalkGroup> = new Map();
	// #endregion

	// #region ResourceManager_Unlocks.cs
	// #region 解锁组
	public function GetUnlockGroupMeta(groupID:NamespaceID):UnlockGroupMeta
	{
		if (!NamespaceID.IsValid(groupID))
			return null;
		var resources = GetModResource(groupID.SpaceName);
		var metaList = resources.UnlockMetaList;
		if (metaList == null)
			return null;
		return Lambda.find(metaList.groups, m -> m.ID == groupID.Path);
	}
	private function LoadUnlocks_Unlocks(resource:ModResource):Void
	{
		if (resource.UnlockMetaList == null)
			return;
		for (group in resource.UnlockMetaList.groups)
		{
			AddConditionListUnlocks(group != null ? group.Conditions : null);
		}
	}
	// #endregion

	// #region 所有解锁条件
	public function GetAllUnlockConditions():Array<NamespaceID>
	{
		return [for (k in unlockConditionList.keys()) k];
	}
	private function LoadModResourceUnlocks(resource:ModResource):Void
	{
		LoadUnlocks_Achievements(resource);
		LoadUnlocks_Almanac(resource);
		LoadUnlocks_Arcade(resource);
		LoadUnlocks_Artifacts(resource);
		LoadUnlocks_Characters(resource);
		LoadUnlocks_Entities(resource);
		LoadUnlocks_MainmenuView(resource);
		LoadUnlocks_Music(resource);
		LoadUnlocks_Stages(resource);
		LoadUnlocks_Store(resource);
		LoadUnlocks_Talks(resource);
		LoadUnlocks_Unlocks(resource);
	}
	private function AddConditionListUnlocks(conditions:XMLConditionList):Void
	{
		if (conditions == null)
			return;
		for (condition in conditions.Conditions)
		{
			AddConditionUnlocks(condition);
		}
	}
	private function AddConditionUnlocks(condition:XMLCondition):Void
	{
		AddUnlocks(condition.Required);
		AddUnlocks(condition.RequiredNot);
	}
	private function AddUnlocks(unlocks:Array<NamespaceID>):Void
	{
		if (unlocks == null)
			return;
		for (unlock in unlocks)
		{
			AddUnlock(unlock);
		}
	}
	private function AddUnlock(unlock:NamespaceID):Void
	{
		if (unlock == null)
			return;
		unlockConditionList.set(unlock, true);
	}
	private var unlockConditionList:Map<NamespaceID, Bool> = new Map();
	// #endregion
	// #endregion

	// #region ResourceManager_Blueprints.cs
	public function GetBlueprintMetaList(spaceName:String):BlueprintMetaList
	{
		var modResource = GetModResource(spaceName);
		if (modResource == null)
			return null;
		return modResource.BlueprintMetaList;
	}
	// #region 选项
	public function GetModBlueprintOptionMetas(spaceName:String):Array<BlueprintOptionMeta>
	{
		var metalist = GetBlueprintMetaList(spaceName);
		if (metalist == null)
			return [];
		return metalist.Options.copy();
	}
	public function GetModEntityBlueprintMetas(spaceName:String):Array<BlueprintEntityMeta>
	{
		var metalist = GetBlueprintMetaList(spaceName);
		if (metalist == null)
			return [];
		return metalist.Entities.copy();
	}
	public function GetModBlueprintErrorMetas(nsp:String):Array<BlueprintErrorMeta>
	{
		var modResource = main.ResourceManager.GetModResource(nsp);
		if (modResource == null || modResource.BlueprintMetaList == null)
			return [];
		return modResource.BlueprintMetaList.Errors;
	}
	// #endregion

	// #region 样式
	public function GetBlueprintStyleMeta(id:NamespaceID):BlueprintStyleMeta
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var metalist = GetBlueprintMetaList(id.SpaceName);
		if (metalist == null)
			return null;
		return Lambda.find(metalist.Styles, s -> s.ID == id.Path);
	}
	// #endregion

	public function GetBlueprintViewData(seed:SeedPack):BlueprintViewData
	{
		if (seed == null)
			return BlueprintViewData.Empty;
		var viewData = GetBlueprintViewDataFromDefinition(seed.Definition, seed.Level.IsEndless(), seed.IsCommandBlockOfPack());
		viewData.cost = Std.string(seed.GetCost());
		return viewData;
	}
	// TODO-PORT: C# 重载 GetBlueprintViewData(SeedDefinition, bool, bool)，重命名以区分。
	public function GetBlueprintViewDataFromDefinition(seedDef:SeedDefinition, isEndless:Bool, isCommandBlock:Bool = false):BlueprintViewData
	{
		var sprite = GetBlueprintIcon(seedDef);
		var costStr = "";

		var seedID = seedDef.GetID();
		var commandBlock = seedID == VanillaContraptionID.commandBlock;
		if (!commandBlock)
		{
			var costSB = new StringBuf();
			costSB.add(seedDef.GetCost());
			if (seedDef.IsUpgradeBlueprint() && isEndless)
			{
				costSB.add("+");
			}
			costStr = costSB.toString();
		}

		var viewData = new BlueprintViewData();
		viewData.icon = sprite;
		viewData.cost = costStr;
		viewData.triggerActive = seedDef.IsTriggerActive();
		viewData.iconGrayscale = isCommandBlock;
		var styleID = GetBlueprintStyleID(seedDef, isCommandBlock);
		var styleMeta = GetBlueprintStyleMeta(styleID);
		SetBlueprintViewDataStyle(viewData, styleMeta);
		return viewData;
	}
	// TODO-PORT: C# 重载 GetBlueprintViewData(NamespaceID?, bool, bool)，重命名以区分。
	public function GetBlueprintViewDataFromID(seedID:NamespaceID, isEndless:Bool, isCommandBlock:Bool = false):BlueprintViewData
	{
		if (NamespaceID.IsValid(seedID))
		{
			var definition = main.Game.GetSeedDefinition(seedID);
			if (definition != null)
			{
				return GetBlueprintViewDataFromDefinition(definition, isEndless, isCommandBlock);
			}
		}
		return GetDefaultBlueprintViewData(isCommandBlock);
	}
	public function GetDefaultBlueprintViewData(isCommandBlock:Bool = false):BlueprintViewData
	{
		var viewData = new BlueprintViewData();
		viewData.triggerActive = false;
		viewData.cost = "0";
		viewData.icon = GetDefaultSprite();
		viewData.iconGrayscale = isCommandBlock;
		var styleID = isCommandBlock ? LogicBlueprintStyles.normal : LogicBlueprintStyles.commandBlock;
		var styleMeta = GetBlueprintStyleMeta(styleID);
		SetBlueprintViewDataStyle(viewData, styleMeta);
		return viewData;
	}
	public function GetBlueprintName(blueprintID:NamespaceID, commandBlock:Bool):String
	{
		var name = main.Game.GetBlueprintName(blueprintID);
		if (commandBlock)
		{
			name = Global.Localization.GetTextParticular(name, LogicStrings.COMMAND_BLOCK_BLUEPRINT_NAME_TEMPLATE);
		}
		return name;
	}
	public function GetBlueprintTooltip(blueprintID:NamespaceID):String
	{
		return main.Game.GetBlueprintTooltip(blueprintID);
	}
	public function GetBlueprintIconMobile(seedDef:SeedDefinition):Sprite
	{
		if (seedDef != null)
		{
			var sprRef = seedDef.GetMobileIcon();
			if (sprRef == null)
				return null;
			return Main.GetFinalSpriteFromRef(sprRef);
		}
		return GetDefaultSprite();
	}
	public function GetBlueprintIconStandalone(seedDef:SeedDefinition):Sprite
	{
		if (seedDef != null)
		{
			var sprite:Sprite = null;

			var iconRef = seedDef.GetIcon();
			if (iconRef != null)
				sprite = Main.GetFinalSpriteFromRef(iconRef);

			if (sprite != null)
				return sprite;

			var seedModelIcon = seedDef.GetModelID();
			if (seedModelIcon != null)
				sprite = GetModelIcon(seedModelIcon);

			return sprite;
		}
		return GetDefaultSprite();
	}
	public function GetBlueprintIcon(seedDef:SeedDefinition):Sprite
	{
		return Main.UseMobileLayout() ? GetBlueprintIconMobile(seedDef) : GetBlueprintIconStandalone(seedDef);
	}
	private function GetBlueprintStyleID(seedDef:SeedDefinition, isCommandBlock:Bool):NamespaceID
	{
		var defaultValue = LogicBlueprintStyles.normal;
		var result = new CallbackResult();
		result.SetValue(defaultValue);
		var args = new GetBlueprintStyleParams(seedDef, isCommandBlock);
		Global.Game.RunCallbackWithResultFiltered(LogicCallbacks.GET_BLUEPRINT_STYLE, args, result, seedDef);

		var value:NamespaceID = result.GetValue();
		return value != null ? value : defaultValue;
	}
	private function SetBlueprintViewDataStyle(viewData:BlueprintViewData, styleMeta:BlueprintStyleMeta):Void
	{
		var main = Main;
		viewData.standaloneBackground = main.GetFinalSpriteFromRef(styleMeta != null ? styleMeta.StandaloneBackground : null);
		viewData.mobileBackground = main.GetFinalSpriteFromRef(styleMeta != null ? styleMeta.MobileBackground : null);
		viewData.mobileFrameTop = main.GetFinalSpriteFromRef(styleMeta != null ? styleMeta.MobileFrameTop : null);
		viewData.mobileFrameBottom = main.GetFinalSpriteFromRef(styleMeta != null ? styleMeta.MobileFrameBottom : null);
	}
	// #endregion

	public var Main(get, never):MainManager;
	function get_Main():MainManager return main;
	@:serializeField
	private var main:MainManager = null;
	private var modResources:Array<ModResource> = [];
}

class ResourceLocationEqualityComparer
{
	// needed for IEqualityComparer<IResourceLocation> interface
	public function Equals(x:Dynamic, y:Dynamic):Bool
	{
		return x.PrimaryKey == y.PrimaryKey && x.ResourceType == y.ResourceType && x.InternalId == y.InternalId;
	}

	// needed for IEqualityComparer<IResourceLocation> interface
	public function GetHashCode(loc:Dynamic):Int
	{
		// PORT-NOTE: Haxe 的 String 没有 hash()（C# 为 string.GetHashCode()），
		// 采用与 mvz2.models.ModelAnchor.hashCodeOf 相同的简易字符串哈希。
		return stringHash(loc.PrimaryKey + "") * 31 + stringHash(loc.ResourceType + "");
	}
	private static function stringHash(s:String):Int
	{
		var h = 0;
		if (s != null)
		{
			for (i in 0...s.length)
				h = 31 * h + s.charCodeAt(i);
		}
		return h & 0x7FFFFFFF;
	}
	public function new() {}
}


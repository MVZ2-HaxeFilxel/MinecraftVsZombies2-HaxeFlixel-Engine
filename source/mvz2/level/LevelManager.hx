// Ported from: Assets/Scripts/MVZ2/Level/LevelManager.cs
package mvz2.level;

// PORT-NOTE: 原 import 写作 mvz2.IO.FileHelper，但 Haxe 无法解析含大写字母的包路径（首个大写段会被当作类型名），
// 且 source/mvz2/IO/ 内的文件本身声明的是 `package mvz2.io;`（目录名待改为小写），故改用小写包路径。
import mvz2.io.FileHelper;
import mvz2.managers.MainManager;
import mvz2.scenes.SceneLoadingManager;
import mvz2.scenes.ScenePrefabLoader;
import mvz2.ui.UiRenderer;
import mvz2logic.games.IGlobalLevel;
import mvz2logic.level.LevelExitTarget;
import mvz2logic.localization.LogicStrings;
import pvzengine.NamespaceID;
import pvzengine.level.LevelEngine;
import system.threading.tasks.Task;
import unity.*;
import unity.Debug;
import mvz2.debugs.DebugManager;
import mvz2.io.FileManager;
import mvz2.io.PathHelper;
import mvz2.localization.LanguageManager;
import mvz2.modding.ModManager;
import mvz2.saves.SaveManager;
import mvz2logic.serialization.SerializeHelper;
import unity.scenemanagement.LoadSceneMode;
import unity.scenemanagement.SceneManager;
import unity.scenemanagement.SceneInstance.Scene;
import Main;
import unity.scenemanagement.SceneInstance;
// PORT-NOTE: C# 的扩展方法在 Haxe 中需要显式 using 才能以 `obj.Method()` 形式调用。
using mvz2logic.level.LogicStageProps;             // IsEndlessOfStage / GetDayNumberOfStage / GetLevelNameOfStage
using mvz2logic.saves.LogicSaveExt;                // IsHPBarUnlocked(this IGlobalSaveData)
using mvz2logic.serialization.SerializeHelper;     // ToBson(this object)

class LevelManager extends MonoBehaviour implements IGlobalLevel
{
	@:allow(mvz2.level)
	function SetLevelController(controller:LevelController):Void
	{
		this.controller = controller;
	}
	public function GetLevelController():LevelController
	{
		return controller;
	}
	public function GetLevel():LevelEngine
	{
		if (controller == null)
			return null;
		return controller.GetEngine();
	}
	public function IsInLevel():Bool
	{
		return GetLevel() != null;
	}
	public function InitLevel(areaID:NamespaceID, stageID:NamespaceID, beginningDelay:Float = 0, exitTarget:LevelExitTarget = LevelExitTarget.MapOrMainmenu):Void
	{
		if (controller == null)
			return;
		Main.SaveManager.SaveToFile(); // 关卡开始时保存游戏
		controller.SetStartStage(areaID, stageID);
		if (HasLevelState(stageID))
		{
			LoadLevel(areaID, stageID);
		}
		else
		{
			controller.InitLevel(Main.Game, areaID, stageID);
			controller.StartLevelIntro(beginningDelay);
		}
		controller.SetExitTarget(exitTarget);
	}
	// #region 关卡存读
	public function SaveLevel():Void
	{
		if (controller == null)
			return;
		var stageID = controller.GetStartStageID();
		var path = GetLevelStatePath(stageID);
		FileHelper.ValidateDirectory(path);


		// PORT-NOTE: C# 依次写入 header 行与 content 行；移植层 FileManager.WriteStringFile
		// 已负责压缩与整文件写入，这里拼成一整段文本一次写入。
		var header = controller.SaveGameHeader();
		var headerJson = header.ToBson();
		var content = controller.SaveGame();
		var contentJson = content.ToBson();
		Main.FileManager.WriteStringFile(path, headerJson + "\n" + contentJson + "\n");

		UpdateCurrentEndlessFlags(stageID, controller.GetCurrentFlag());
	}
	public function LoadLevel(areaID:NamespaceID, stageID:NamespaceID):Void
	{
		if (controller == null)
			return;
		if (!HasLevelState(stageID))
			return;
		try
		{
			controller.SetActive(true);
			var path = GetLevelStatePath(stageID);

			// 读取文件内容
			// PORT-NOTE: C# 使用 StreamReader + MongoDB.Bson.IO.JsonReader 逐行反序列化；
			// 移植层 FileManager.ReadStringFile 已负责解压与整文件读取，这里按行切分后交给
			// SerializeMacro.ReadBson(text, type)。
			var text = Main.FileManager.ReadStringFile(path);
			if (text == null)
				return;
			var lines = text.split("\n");

			// 读取首行数据
			var header = mvz2logic.serialization.SerializeMacro.ReadBson(lines[0], SerializableLevelControllerHeader);

			// 验证首行数据
			var validate = controller.ValidateGameStateHeader(header);
			if (!validate)
				return;

			// 读取内容
			var content = mvz2logic.serialization.SerializeMacro.ReadBson(lines[1], SerializableLevelController);

			var success = controller.LoadGame(content, Main.Game, areaID, stageID);
			if (!success)
				return;
			UpdateCurrentEndlessFlags(stageID, controller.GetCurrentFlag());
		}
		catch (e:Dynamic)
		{
			controller.ShowLevelErrorLoadingDialog(e);
		}
	}
	public function HasLevelState(stageID:NamespaceID):Bool
	{
		var path = GetLevelStatePath(stageID);
		return sys.FileSystem.exists(path);
	}
	public function RemoveLevelState(stageID:NamespaceID):Void
	{
		var path = GetLevelStatePath(stageID);
		if (sys.FileSystem.exists(path))
		{
			sys.FileSystem.deleteFile(path);
		}
		UpdateCurrentEndlessFlags(stageID, 0);
	}
	public function GetLevelStatePath(stageID:NamespaceID):String
	{
		var userIndex = Main.SaveManager.GetCurrentUserIndex();
		var dir = Main.SaveManager.GetUserModSaveDataDirectory(userIndex, stageID.SpaceName);
		return mvz2.io.PathHelper.combine(dir, "level", '${stageID.Path}.lvl');
	}
	public function GetLevelStateIdentifierList():LevelDataIdentifierList
	{
		var mods = Main.ModManager.GetAllModInfos();
		return new LevelDataIdentifierList([for (m in mods) new LevelDataIdentifier(m.Namespace, m.LevelDataVersion)]);
	}
	public function GetStageName(stageID:NamespaceID):String
	{
		var meta = Main.Game.GetStageDefinition(stageID);
		if (meta == null)
			return Main.LanguageManager._p(LogicStrings.CONTEXT_LEVEL_NAME, LogicStrings.LEVEL_NAME_UNKNOWN);
		var levelName = Main.LanguageManager._p(LogicStrings.CONTEXT_LEVEL_NAME, meta.GetLevelNameOfStage());
		var dayNumber = meta.GetDayNumberOfStage();
		if (dayNumber > 0)
		{
			levelName = Main.LanguageManager._pn(LogicStrings.CONTEXT_LEVEL_NAME, LogicStrings.LEVEL_NAME_DAY_TEMPLATE, dayNumber, [levelName, dayNumber]);
		}
		return levelName;
	}
	// TODO-PORT: C# 重载 GetStageName(LevelEngine level)，重命名以区分。
	public function GetStageNameFromLevel(level:LevelEngine):String
	{
		var name = level.GetLevelName();
		if (name == null || name == "")
			name = LogicStrings.LEVEL_NAME_UNKNOWN;
		var levelName = Main.LanguageManager._p(LogicStrings.CONTEXT_LEVEL_NAME, name);
		var dayNumber = level.GetDayNumber();
		if (dayNumber > 0)
		{
			levelName = Main.LanguageManager._pn(LogicStrings.CONTEXT_LEVEL_NAME, LogicStrings.LEVEL_NAME_DAY_TEMPLATE, dayNumber, [levelName, dayNumber]);
		}
		if (level.IsEndless() && level.CurrentFlag > 0)
		{
			levelName = Main.LanguageManager._pn(LogicStrings.CONTEXT_LEVEL_NAME, LogicStrings.LEVEL_NAME_ENDLESS_FLAGS_TEMPLATE, level.CurrentFlag, [levelName, level.CurrentFlag]);
		}
		return levelName;
	}
	// #endregion
	public function LawnToTrans(pos:Vector3):Vector3
	{
		if (controller != null)
		{
			return controller.LawnToTrans(pos);
		}
		pos = pos * LawnToTransScale;
		return new Vector3(pos.x, pos.z + pos.y, pos.z);
	}
	public function TransToLawn(pos:Vector3):Vector3
	{
		if (controller != null)
		{
			return controller.TransToLawn(pos);
		}
		var vector = new Vector3(pos.x, pos.y - pos.z, pos.z);
		vector = vector * TransToLawnScale;
		return vector;
	}
	public function GotoLevelSceneAsync():Task
	{
		var sceneName = "Level";
		var oldScene = Scene.GetSceneInstance(sceneName);
		var oldController = controller;
		var oldRoot = levelSceneRoot;

		// PORT-NOTE: C# 的 `await Scene.LoadSceneAsync(...)` 在 Haxe 侧 Task shim 中同步执行，
		// 且 Task<T> 无法表达泛型结果，SceneInstance 存放在 Task.result 中。
		// 这里保留该调用：它的职责是「把 SceneInstance 登记进 SceneLoadingManager.sceneCaches」，
		// `IsSceneLoaded` / `GetSceneInstance` / `UnloadSceneAsyncByName`（ExitLevelSceneAsync）都依赖它。
		var newScene = (cast Scene.LoadSceneAsync(sceneName, LoadSceneMode.Additive).result : SceneInstance);

		// PORT-NOTE: **移植层真正建场景树的地方**。Unity 由 Addressables 反序列化
		// `Assets/GameContent/Scenes/Level.unity`（该场景就是一个 Level.prefab 实例）并让根对象进入场景；
		// 移植层没有 Unity 资产系统，改由 `ScenePrefabLoader` 按 `tools_build/build_scene.py` 导出的节点表
		// 重建同一棵对象图（972 节点 / 2100 组件），语义等价于 Unity 的场景反序列化。
		// 这同时是 `newScene.Scene.GetRootGameObjects()` 拿不到东西的原因（见下）。
		//
		// `callAwakeInInstantiate` 用默认值 true，对应 Unity「场景加载完成后对场景内组件调用 Awake」。
		// 关卡**必须**真的分发 Awake：`LevelController.Awake` 负责建立 `parts` 表并跑完全部 Awake_*
		// 子系统（UI/相机/网格/实体/蓝图/工具…），缺了它 `InitLevel` 里的 `for (controller in parts)`
		// 会直接空引用（`LevelController.InitLevel` 只做 `SetActive(true)`，移植层的 SetActive 不会
		// 像 Unity 那样触发延迟的 Awake）。
		var newRoot = ScenePrefabLoader.InstantiateScene(sceneName);
		if (newRoot == null)
		{
			// 数据缺失（未运行 build_scene.py / 清单里没有 Level）时降级：不建立场景树、不改 controller，
			// 让后续 InitLevel 走「controller == null」的既有分支（原实现同样拿不到 LevelController）。
			Debug.LogWarning('[LevelManager] Level 场景数据不可用，无法重建关卡场景树：'
				+ ScenePrefabLoader.loadWarnings.join(" / "));
			return Task.CompletedTask;
		}
		levelSceneRoot = newRoot;

		// PORT-NOTE: 对应 Unity「加载出来的场景对象加入渲染」。`UiRenderer.registerRoot` 的注释里
		// 就点名了关卡场景（可多次调用追加遍历根）；不登记的话关卡 UI 不会进显示列表。
		// 世界空间的 SpriteRenderer 由 `unity.RenderBridge` 每帧按 transform 同步 ——
		// `ScenePrefabLoader` 走 `GameObject.AddComponent`，登记点已覆盖。
		if (UiRenderer.instance != null)
			UiRenderer.instance.registerRoot(newRoot);

		// PORT-NOTE: C# 遍历 `newScene.Scene.GetRootGameObjects()` 找 LevelController。
		// 移植层 `SceneInstance.Scene.GetRootGameObjects()` 是空实现（没有场景容器，见
		// unity/scenemanagement/SceneInstance.hx），因此把刚重建出来的场景根一并纳入遍历：
		// 两种来源都覆盖，控制流与 C# 完全一致（找到即 SetLevelController 并 break）。
		var sceneRoots:Array<GameObject> = newScene != null && newScene.Scene != null
			? newScene.Scene.GetRootGameObjects() : [];
		if (sceneRoots.indexOf(newRoot) < 0)
			sceneRoots.push(newRoot);
		for (go in sceneRoots)
		{
			if (go == null)
				continue;
			var ctrl = go.GetComponent(LevelController);
			if (ctrl != null)
			{
				SetLevelController(ctrl);
				break;
			}
		}
		if (controller != null)
		{
			controller.SetActive(false);
		}

		// PORT-NOTE: **首次进入关卡时 `oldScene` 为 null**（sceneCaches 里还没有 "Level" 实例）。
		// C# 直接写 `oldScene.Scene.IsValid()` —— Unity 的 SceneInstance 是 struct、Scene 恒有值，
		// 移植层是 class，第一次进入时 oldScene 就是 null，必须显式判空，否则空引用。
		if (oldScene != null && oldScene.Scene != null && oldScene.Scene.IsValid())
		{
			Scene.UnloadSceneAsync(oldScene);
		}
		// PORT-NOTE: `SceneLoadingManager.UnloadSceneAsync` 只做「从 sceneCaches 移除」的登记动作，
		// 移植层没有场景容器替我们把对象图收走，因此旧的场景树要在这里显式销毁
		//（对应 Unity 卸载场景时销毁其全部对象）。重复进关 / 重开关卡（`LevelController.ReloadLevel`）
		// 都会走这条路径：不做这一步会每关泄漏一整棵 972 节点的树，且旧的关卡 UI 会继续参与渲染。
		if (oldRoot != null && oldRoot != newRoot)
			UnityObject.destroy(oldRoot);
		return Task.CompletedTask;
	}
	public function ExitLevelSceneAsync():Task
	{
		var sceneName = "Level";
		if (!Scene.IsSceneLoaded(sceneName))
			return Task.CompletedTask;
		// PORT-NOTE: C# 重载 `Scene.UnloadSceneAsync(string)` 在 Haxe 中改名为 UnloadSceneAsyncByName。
		Scene.UnloadSceneAsyncByName(sceneName);
		// PORT-NOTE: 与 GotoLevelSceneAsync 的建树配对 —— 场景管理侧只登记 SceneInstance，
		// 对象图必须在这里销毁（否则退出关卡后关卡 UI 仍留在显示列表里）。
		DestroyLevelSceneRoot();
		SetLevelController(null);
		return Task.CompletedTask;
	}
	/** 销毁当前关卡场景树并清空登记（对应 Unity 卸载场景时销毁其全部对象）。 */
	private function DestroyLevelSceneRoot():Void
	{
		var root = levelSceneRoot;
		levelSceneRoot = null;
		if (root != null && UnityObject.exists(root))
			UnityObject.destroy(root);
	}
	private function UpdateCurrentEndlessFlags(stageID:NamespaceID, flags:Int):Void
	{
		var stageDef = Main.Game.GetStageDefinition(stageID);
		if (stageDef != null && stageDef.IsEndlessOfStage())
		{
			Main.SaveManager.SetCurrentEndlessFlag(stageID, flags);
		}
	}


	public function GetHPBarUnlocked():Bool
	{
		return Main.SaveManager.IsHPBarUnlocked() || Main.DebugManager.CanUseDebugFeatures();
	}


	public static inline var CURRENT_DATA_VERSION:Int = 4;
	public var LawnToTransScale(get, never):Float;
	function get_LawnToTransScale():Float return 1 / transToLawnScale;
	public var TransToLawnScale(get, never):Float;
	function get_TransToLawnScale():Float return transToLawnScale;
	public var Main(get, never):MainManager;
	function get_Main():MainManager return main;
	public var Scene(get, never):SceneLoadingManager;
	function get_Scene():SceneLoadingManager return main.SceneManager;
	@:serializeField
	private var main:MainManager = null;
	@:serializeField
	private var transToLawnScale:Float = 100;
	private var controller:LevelController;
	/**
	 * `GotoLevelSceneAsync` 重建出来的关卡场景根（对应 Unity 里 "Level" 场景的对象图）。
	 *
	 * PORT-NOTE: Unity 由 `SceneManager`/Addressables 持有已加载的场景，移植层的
	 * `SceneInstance` 只是名字句柄（见 `unity/scenemanagement/SceneInstance.hx`），
	 * 对象图必须由本管理器自己持有，`ExitLevelSceneAsync` 才能把它销毁掉。
	 */
	private var levelSceneRoot:GameObject = null;
}

class LevelDataIdentifierCompareResult
{
	public var versionMismatches:Array<LevelDataIdentifierPair>;
	public var missingMismatches:Array<LevelDataIdentifier>;
	public var additionalMismatches:Array<LevelDataIdentifier>;
	public var valid:Bool;
	public function new() {}
}

@:rtti
class LevelDataIdentifierPair
{
	public var lhs:LevelDataIdentifier;
	public var rhs:LevelDataIdentifier;
	public function new() {}
}

@:rtti
class LevelDataIdentifierList
{
	public function new(identifiers:Array<LevelDataIdentifier>)
	{
		this.identifiers = this.identifiers.concat(identifiers);
	}
	public function Compare(other:LevelDataIdentifierList):LevelDataIdentifierCompareResult
	{
		if (other == null)
		{
			var result = new LevelDataIdentifierCompareResult();
			result.valid = false;
			result.versionMismatches = [];
			result.missingMismatches = [];
			result.additionalMismatches = identifiers.copy();
			return result;
		}

		var versionMismatches:Array<LevelDataIdentifierPair> = [];
		var missingMismatches:Array<LevelDataIdentifier> = [];
		var additionalMismatches:Array<LevelDataIdentifier> = [];
		for (i1 in identifiers)
		{
			var nameMatches = false;
			for (i2 in other.identifiers)
			{
				if (i1.spaceName == i2.spaceName)
				{
					nameMatches = true;
					if (i1.dataVersion != i2.dataVersion)
					{
						var pair = new LevelDataIdentifierPair();
						pair.lhs = i1;
						pair.rhs = i2;
						versionMismatches.push(pair);
					}
				}
			}
			if (!nameMatches)
			{
				additionalMismatches.push(i1);
			}
		}
		for (i1 in other.identifiers)
		{
			var nameMatches = false;
			for (i2 in identifiers)
			{
				if (i1.spaceName == i2.spaceName)
				{
					nameMatches = true;
					break;
				}
			}
			if (!nameMatches)
			{
				missingMismatches.push(i1);
			}
		}
		var valid = versionMismatches.length + missingMismatches.length + additionalMismatches.length == 0;
		var result = new LevelDataIdentifierCompareResult();
		result.valid = valid;
		result.versionMismatches = versionMismatches;
		result.missingMismatches = missingMismatches;
		result.additionalMismatches = additionalMismatches;
		return result;
	}
	public function GetHashCode():Int
	{
		var hash = 0;
		for (id in identifiers)
		{
			hash = hash * 31 + id.GetHashCode();
		}
		return hash;
	}
	public var identifiers:Array<LevelDataIdentifier> = [];
}

@:rtti
class LevelDataIdentifier
{
	public function new(name:String, version:Int)
	{
		spaceName = name;
		dataVersion = version;
	}
	public var spaceName:String;
	public var dataVersion:Int;

	public function Equals(obj:Dynamic):Bool
	{
		return Std.isOfType(obj, LevelDataIdentifier) && equals(cast obj);
	}
	public function equals(identifier:LevelDataIdentifier):Bool
	{
		return spaceName == identifier.spaceName && dataVersion == identifier.dataVersion;
	}

	public function GetHashCode():Int
	{
		// PORT-NOTE: Haxe 的 String 没有 hashCode（C# 为 spaceName.GetHashCode()），
		// 采用与 mvz2.models.ModelAnchor.hashCodeOf 相同的简易字符串哈希。
		var hash = 0;
		if (spaceName != null)
		{
			for (i in 0...spaceName.length)
				hash = 31 * hash + spaceName.charCodeAt(i);
		}
		hash = hash * 31 + dataVersion;
		return hash & 0x7FFFFFFF;
	}
}

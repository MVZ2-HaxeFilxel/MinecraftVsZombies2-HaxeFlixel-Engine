// Ported from: (新增文件) 场景/UI prefab 的运行期实例化
package mvz2.scenes;

import haxe.Json;
import mvz2.models.ModelPrefabContext;
// PORT-NOTE: ModelPrefabTransform 是 mvz2.models.ModelPrefabData 模块内的 typedef，
// 跨模块引用必须显式 import 该类型（与 ScenePrefabData 的处理相同）。
import mvz2.models.ModelPrefabData.ModelPrefabTransform;
import mvz2.scenes.ScenePrefabData;
import sys.io.File;
import unity.Component;
import unity.Debug;
import unity.GameObject;
import unity.MonoBehaviour;
import unity.Quaternion;
import unity.RectTransform;
import unity.Transform;
import unity.UnityObject;
import unity.Vector2;
import unity.Vector3;

// PORT-NOTE: 本文件是移植层新增的「场景/prefab 资产加载器」，没有 C# 对应源码。
//
// C# 侧关卡与 UI 由 Unity 的 SceneManager 加载 `Assets/GameContent/Scenes/{Main,Level}.unity`，
// 场景里的 prefab 实例被反序列化成 GameObject 层级，组件的 `[SerializeField]` 字段由 prefab 注入。
// 移植层没有 Unity 资产系统，改由 `tools_build/build_scene.py` 把场景与 `Assets/Prefabs/**` 的
// prefab 合并导出成节点表（`assets/scene_manifest.json` + `assets/scene_prefabs/**`），
// 这里按节点表重建 GameObject 层级 —— 语义等价于 Unity 的场景反序列化。
//
// 与 `mvz2.models.ModelPrefabLoader`（模型 prefab）的关系：
//   * 数据格式与解码器（`ModelPrefabContext`）完全复用；
//   * 组件类表、字段写回各自独立（模型组件 vs UI/关卡组件）。
//
// 用法（给启动链路 / 关卡构建使用）：
//   var scene = ScenePrefabLoader.InstantiateScene("Level");   // 场景根 GameObject
//   var prefab = ScenePrefabLoader.InstantiatePrefab("Prefabs/Level/Grid");
class ScenePrefabLoader {
	// #region 清单与数据文件
	/** 清单相对路径（由 unity.Application.dataPath 给出 assets 根）。 */
	public static function GetManifestPath():String {
		return unity.Application.dataPath + "/scene_manifest.json";
	}
	public static function GetDataDir():String {
		return unity.Application.dataPath + "/scene_prefabs";
	}
	/** 首次访问时同步加载清单；C# 侧这些数据来自 Unity 资产的导入结果。 */
	public static function GetManifest(?reload:Bool = false):Null<SceneManifest> {
		if (manifest == null || reload) {
			manifest = loadManifest();
			sceneIndex = null;
			prefabIndex = null;
			if (manifest != null) {
				sceneIndex = new Map();
				if (manifest.scenes != null) {
					for (entry in manifest.scenes) {
						if (entry != null && entry.key != null)
							sceneIndex.set(entry.key, entry);
					}
				}
				prefabIndex = new Map();
				if (manifest.prefabs != null) {
					for (entry in manifest.prefabs) {
						if (entry != null && entry.key != null)
							prefabIndex.set(entry.key, entry);
					}
				}
			}
		}
		return manifest;
	}
	public static function GetSceneEntry(sceneName:String):Null<SceneManifestScene> {
		GetManifest();
		if (sceneIndex == null)
			return null;
		return sceneIndex.exists(sceneName) ? sceneIndex.get(sceneName) : null;
	}
	public static function GetPrefabEntry(key:String):Null<SceneManifestPrefab> {
		GetManifest();
		if (prefabIndex == null)
			return null;
		return prefabIndex.exists(key) ? prefabIndex.get(key) : null;
	}
	private static function loadManifest():Null<SceneManifest> {
		var path = GetManifestPath();
		if (!sys.FileSystem.exists(path)) {
			loadWarnings.push('场景清单不存在：$path（需先运行 tools_build/build_scene.py）');
			return null;
		}
		try {
			return cast Json.parse(File.getContent(path));
		} catch (e:Dynamic) {
			loadWarnings.push('场景清单解析失败：$path：$e');
			return null;
		}
	}
	/** 按 key 读取单个场景/prefab 的数据文件（不存在或未转换时为 null）。 */
	public static function LoadData(key:String):Null<ScenePrefabFile> {
		if (key == null)
			return null;
		if (dataCache.exists(key))
			return dataCache.get(key);
		var result:Null<ScenePrefabFile> = null;
		var dataPath:Null<String> = null;
		var sceneEntry = GetSceneEntry(key);
		if (sceneEntry != null) {
			dataPath = sceneEntry.data;
		} else {
			var prefabEntry = GetPrefabEntry(key);
			if (prefabEntry != null)
				dataPath = prefabEntry.data;
		}
		if (dataPath != null) {
			// 清单里的 data 是**相对 assets 根**的路径（与 build_scene.py 的字段说明一致）。
			var path = unity.Application.dataPath + "/" + dataPath;
			if (sys.FileSystem.exists(path)) {
				try {
					result = cast Json.parse(File.getContent(path));
				} catch (e:Dynamic) {
					loadWarnings.push('场景数据解析失败：$path：$e');
				}
			} else {
				loadWarnings.push('场景数据文件不存在：$path');
			}
		}
		dataCache.set(key, result);
		return result;
	}
	// #endregion

	// #region 实例化
	/**
	 * 按场景名重建场景根 GameObject 层级（等价于 Unity 加载 .unity 场景）。
	 *
	 * PORT-NOTE: Unity 的场景根会进入当前活动场景；移植层没有场景容器，返回的根 GameObject
	 * 由调用方决定挂到哪里（`parent` 为 null 时是游离根，`LevelManager.GotoLevelSceneAsync`
	 * 需要把它交给 `unity.scenemanagement.Scene` 的实例记录 —— 见报告「需要启动链路配合」）。
	 */
	public static function InstantiateScene(sceneName:String, ?parent:Transform,
			?callAwakeInInstantiate:Bool = true):Null<GameObject> {
		var entry = GetSceneEntry(sceneName);
		if (entry == null) {
			instantiateFailures++;
			loadWarnings.push('场景未转换：$sceneName');
			return null;
		}
		return InstantiateKey(sceneName, parent, callAwakeInInstantiate);
	}
	/** 按 prefab key（相对 Assets 的路径去扩展名）重建 GameObject 层级。 */
	public static function InstantiatePrefab(key:String, ?parent:Transform,
			?callAwakeInInstantiate:Bool = true):Null<GameObject> {
		if (GetPrefabEntry(key) == null) {
			instantiateFailures++;
			loadWarnings.push('prefab 未转换：$key');
			return null;
		}
		return InstantiateKey(key, parent, callAwakeInInstantiate);
	}
	public static function InstantiateKey(key:String, ?parent:Transform,
			?callAwakeInInstantiate:Bool = true):Null<GameObject> {
		var data = LoadData(key);
		if (data == null) {
			instantiateFailures++;
			return null;
		}
		return InstantiateData(data, parent, callAwakeInInstantiate);
	}

	/**
	 * 按 prefab 数据重建层级，并把**根节点**「接管」到调用方已建好的 `rootOverride` 上。
	 *
	 * PORT-NOTE: 这是给「手工构造了根对象（含它的控制器组件），但缺 prefab 子树与字段」的
	 * 调用方用的（`MainGameScene` 的各页面就是这样：它 `new MapController()` 挂在同名 GameObject
	 * 上，但 `mapCamera` 等 `[SerializeField]` 停在初值）。等价于 Unity 里 prefab 实例**覆盖**
	 * 场景中已存在对象：根对象的组件不重建（保留手工 new 的实例，按类型映射到数据记录上），
	 * 其 `[SerializeField]` 字段照常写入；子节点整棵新建。
	 *
	 * @param key          导出数据的 key（如 "Prefabs/Map/Map"）。
	 * @param rootOverride 已存在的根 GameObject（其名字应与数据根节点名一致）。
	 * @param parent       新建子树的父级；null 表示保持根对象原有的父级。
	 * @return 写入的字段数；数据不存在时返回 -1。
	 */
	public static function InstantiateInto(key:String, rootOverride:GameObject,
			?parent:Transform, ?callAwakeInInstantiate:Bool = false):Int {
		var data = LoadData(key);
		if (data == null || rootOverride == null) {
			instantiateFailures++;
			loadWarnings.push('场景数据不存在：$key');
			return -1;
		}
		if (data.nodes == null || data.nodes.length == 0 || data.roots == null || data.roots.length == 0)
			return -1;
		// 先把「新建节点」的总数记下来，用于统计注入字段数。
		var before = injectedFields;
		InstantiateData(data, parent, callAwakeInInstantiate, rootOverride);
		return injectedFields - before;
	}

	/** 每次实例化累计写入的字段数（诊断用）。 */
	public static var injectedFields:Int = 0;

	/**
	 * 按已解析的数据重建 GameObject 层级（等价于 Instantiate(prefab, parent)）。
	 *
	 * PORT-NOTE: `callAwakeInInstantiate=false` 时**不**分发 Awake —— 给「先建树、再统一分发」的
	 * 调用方使用（Unity 的 `Instantiate` 本来也不调用 Awake，只有场景加载/AddComponent 才调用；
	 * 移植层为了单点可用默认按 AddComponent 语义分发）。手工构造的 UI 图（`MainGameScene`）
	 * 就是这种调用方：它自己按顺序调 Awake（`MainManager` 必须最先）。
	 */
	public static function InstantiateData(data:ScenePrefabFile, ?parent:Transform,
			?callAwakeInInstantiate:Bool = true, ?rootOverride:GameObject = null):Null<GameObject> {
		if (data == null || data.nodes == null || data.nodes.length == 0) {
			instantiateFailures++;
			return null;
		}
		var ctx = new ModelPrefabContext(cast data);
		// 根节点用调用方已建好的对象时（`InstantiateInto` 的「接管」模式），该下标的节点不新建。
		var overrideIndex = -1;
		if (rootOverride != null && data.roots != null && data.roots.length > 0)
			overrideIndex = data.roots[0];

		// 1) 先建 GameObject + Transform（此时还没有组件，引用解析放到第 3 步）。
		for (i in 0...data.nodes.length) {
			var node = data.nodes[i];
			if (i == overrideIndex) {
				// PORT-NOTE: 接管已有对象 —— 组件不重建（手工构造的页面控制器就在这上面），
				// 只把它的组件按类型映射进 ctx，好让第 3 步把 prefab 字段写上去。
				// Transform 本身也保留（父级/位置/激活态不动），但 rect 等字段由
				// applyRootTransform 按数据写（对齐 Unity prefab 覆盖语义）。
				ctx.gameObjects.push(rootOverride);
				var existing:Array<Component> = [rootOverride.transform];
				var used:Array<Component> = [];
				for (rec in node.components) {
					var cls = ScenePrefabComponentTypes.GetClass(rec);
					var found:Component = null;
					if (cls != null) {
						for (comp in rootOverride.GetAllComponents()) {
							if (used.indexOf(comp) >= 0)
								continue;
							if (Std.isOfType(comp, cls)) {
								found = comp;
								break;
							}
						}
					}
					if (found != null)
						used.push(found);
					existing.push(found);
				}
				ctx.components.push(existing);
				// PORT-NOTE: 接管模式下也要把 JSON 根节点的 transform 写到已存在的根对象上
				//（见 applyRootTransform）。原先整段跳过，对话框/页面根的 rect 停在默认值。
				applyRootTransform(rootOverride, node.transform, existing);
				continue;
			}
			var go = new GameObject(node.name);
			go.name = node.name;
			go.layer = node.layer;
			ctx.gameObjects.push(go);
			ctx.components.push([]);

			var tr = go.transform;
			var td = node.transform;
			if (td != null) {
				tr.localPosition = _v3(td.pos, 0, 0, 0);
				tr.localRotation = _quat(td.rot);
				tr.localScale = _v3(td.scale, 1, 1, 1);
				if (td.rect != null) {
					var rt = new RectTransform();
					rt.name = tr.name;
					rt.gameObject = go;
					rt.localPosition = tr.localPosition;
					rt.localRotation = tr.localRotation;
					rt.localScale = tr.localScale;
					rt.anchoredPosition = _v2(td.rect.anchoredPosition, 0, 0);
					rt.sizeDelta = _v2(td.rect.sizeDelta, 0, 0);
					rt.anchorMin = _v2(td.rect.anchorMin, 0.5, 0.5);
					rt.anchorMax = _v2(td.rect.anchorMax, 0.5, 0.5);
					rt.pivot = _v2(td.rect.pivot, 0.5, 0.5);
					go.transform = rt;
					tr = rt;
				}
			}
			// 组件下标 0 = Transform（见 ScenePrefabData 的编码约定）。
			ctx.components[i].push(tr);
			go.SetActive(node.active);
		}

		// 2) 建组件实例（顺序 = prefab 的 m_Component 顺序，GetComponents 顺序与此一致）。
		//    PORT-NOTE: 接管模式下根节点已有手工 new 的组件（按类型映射到数据记录上），
		//    但数据里**多出来**的组件类型仍要补建（例如 MapController 节点的 MapUI：
		//    它不在手工对象图上，而 MapController.ui 正指向它）。
		for (i in 0...data.nodes.length) {
			var node = data.nodes[i];
			for (ci in 0...node.components.length) {
				if (i == overrideIndex && ctx.components[i][ci + 1] != null)
					continue;
				var rec = node.components[ci];
				var cls = ScenePrefabComponentTypes.GetClass(rec);
				if (cls == null) {
					var key = rec.type == "MonoBehaviour" ? (rec.script == null ? "(unknown script)" : rec.script) : rec.type;
					unknownComponents.set(key, (unknownComponents.exists(key) ? unknownComponents.get(key) : 0) + 1);
					if (i == overrideIndex)
						ctx.components[i][ci + 1] = null;
					else
						ctx.components[i].push(null);
					continue;
				}
				var comp:Component = ctx.gameObjects[i].AddComponent(cls);
				// Unity 里组件的 name 就是类型名；移植层 AddComponent 不会设置，这里补上，
				// 便于日志/调试定位。
				comp.name = Type.getClassName(cls);
				if (i == overrideIndex)
					ctx.components[i][ci + 1] = comp;
				else
					ctx.components[i].push(comp);
			}
		}

		// 2.5) Unity 里 ParticleSystem 的 renderer 就是同 GameObject 上的 ParticleSystemRenderer
		// 组件（与 ModelPrefabLoader 的同一处理）。
		for (i in 0...data.nodes.length) {
			var ps = ctx.gameObjects[i].GetComponent(unity.ParticleSystem);
			if (ps == null)
				continue;
			var psr = ctx.gameObjects[i].GetComponent(unity.ParticleSystemRenderer);
			if (psr != null)
				ps.renderer = psr;
		}

		// 3) 写序列化字段（要等所有组件都建好，引用才能互相解析）。
		for (i in 0...data.nodes.length) {
			var node = data.nodes[i];
			for (ci in 0...node.components.length) {
				var comp = ctx.components[i][ci + 1];
				if (comp == null)
					continue;
				var rec = node.components[ci];
				var missing = ScenePrefabFieldApplier.Apply(comp, rec, ctx);
				var written = rec.fields == null ? 0 : Reflect.fields(rec.fields).length;
				if (missing != null) {
					var label = rec.script != null ? rec.script : rec.type;
					written -= missing.length;
					for (field in missing) {
						var key = label + "." + field;
						if (!missingFields.exists(key))
							missingFields.set(key, 1);
					}
				}
				if (written > 0)
					injectedFields += written;
			}
		}

		// 4) 恢复父子关系（按 m_Children 顺序）。
		for (i in 0...data.nodes.length) {
			if (i == overrideIndex)
				continue;
			var node = data.nodes[i];
			if (node.parent != null && node.parent >= 0 && node.parent < ctx.gameObjects.length) {
				ctx.gameObjects[i].transform.SetParent(ctx.gameObjects[node.parent].transform, false);
			}
		}

		// 5) 挂到目标父级（对应 Instantiate 的 parent 参数）。
		var root:GameObject = null;
		for (idx in data.roots) {
			if (idx < 0 || idx >= ctx.gameObjects.length)
				continue;
			var tr = ctx.gameObjects[idx].transform;
			// 接管模式：根对象已经挂在目标父级上，不要重复 SetParent。
			if (parent != null && idx != overrideIndex)
				tr.SetParent(parent, false);
			root = ctx.gameObjects[idx];
		}

		// 6) Unity 的 AddComponent 语义：组件加入后立即 Awake（可由调用方关闭）。
		if (callAwakeInInstantiate) {
			for (i in 0...data.nodes.length) {
				for (ci in 0...data.nodes[i].components.length) {
					var comp = ctx.components[i][ci + 1];
					if (comp != null)
						callAwake(comp);
				}
			}
		}
		instantiated++;
		return root;
	}

	/**
	 * 只对**根节点**的组件分发 Awake。
	 *
	 * PORT-NOTE: Unity 在加载场景时会对所有组件调用 Awake。移植层若要一次性分发整棵树，
	 * 会与启动链路（`MainGameScene.awakeAll`）对同一批组件的显式分发重复。
	 * 因此 `InstantiateData` 已经按 Unity 语义全树分发过一次；本方法留给调用方在
	 * 「先建树、后统一分发」的场景里使用（此时应传 `callAwakeInInstantiate=false`）。
	 */
	public static function AwakeTree(root:GameObject):Void {
		if (root == null)
			return;
		awakeRecursive(root);
	}
	private static function awakeRecursive(go:GameObject):Void {
		for (comp in go.GetAllComponents())
			callAwake(comp);
		for (child in go.transform.children)
			awakeRecursive(child.gameObject);
	}

	/** Unity 的 AddComponent 会同步调用 Awake；移植层手动触发（找不到 Awake 时什么都不做）。 */
	public static function callAwake(comp:Component):Void {
		var fn = Reflect.field(comp, "Awake");
		if (fn == null || !Reflect.isFunction(fn))
			return;
		try {
			Reflect.callMethod(comp, fn, []);
		} catch (e:Dynamic) {
			// PORT-NOTE: Unity 的 AddComponent 里 Awake 抛异常也会被 Unity 记录并继续；
			// 这里保持同样的容错，并把组件类型带进日志便于定位。
			Debug.LogWarning('[ScenePrefabLoader] ${Type.getClassName(Type.getClass(comp))} 的 Awake 抛出异常：$e');
		}
	}
	// #endregion

	// #region 诊断
	public static var instantiated:Int = 0;
	public static var instantiateFailures:Int = 0;
	/** 无法解析的组件类型 -> 出现次数。 */
	public static var unknownComponents:Map<String, Int> = new Map();
	/** 导出数据里有、但 Haxe 组件上不存在的字段 -> 出现次数。 */
	public static var missingFields:Map<String, Int> = new Map();
	/** 加载过程中的告警（清单/数据文件缺失等）。 */
	public static var loadWarnings:Array<String> = [];
	public static function ResetStats():Void {
		instantiated = 0;
		instantiateFailures = 0;
		unknownComponents.clear();
		missingFields.clear();
		loadWarnings = [];
	}
	// #endregion

	// #region 内部
	private static var manifest:Null<SceneManifest> = null;
	private static var sceneIndex:Map<String, SceneManifestScene> = null;
	private static var prefabIndex:Map<String, SceneManifestPrefab> = null;
	private static var dataCache:Map<String, Null<ScenePrefabFile>> = new Map();

	static function _v2(a:Array<Float>, dx:Float, dy:Float):Vector2 {
		return a != null && a.length >= 2 ? new Vector2(a[0], a[1]) : new Vector2(dx, dy);
	}
	static function _v3(a:Array<Float>, dx:Float, dy:Float, dz:Float):Vector3 {
		return a != null && a.length >= 3 ? new Vector3(a[0], a[1], a[2]) : new Vector3(dx, dy, dz);
	}
	static function _quat(a:Array<Float>):Quaternion {
		return a != null && a.length >= 4 ? new Quaternion(a[0], a[1], a[2], a[3]) : new Quaternion(0, 0, 0, 1);
	}

	/**
	 * 根接管模式下，把 JSON 根节点的 transform 应用到调用方已建好的根对象上。
	 *
	 * PORT-NOTE: 非接管路径为每个新建节点写 pos/rot/scale，`td.rect != null` 时再换成一个
	 * 填好 anchor/pivot/sizeDelta 的 RectTransform。接管路径原先**整段跳过** transform 写入
	 * （原意是保留手工构造的 Transform），于是 `childRect()` / `page()` 建出来的根停在
	 * `RectTransform` 的默认值（anchorMin/Max=(0.5,0.5)、sizeDelta=(0,0)）—— 对话框根 rect
	 * 塌成 1×1，`UiRenderer.childFrame` 的 anchor 数学与命中测试全错。
	 *
	 * 对齐 Unity 的 Instantiate 语义：prefab 实例会用 prefab 根节点的 rect 字段
	 * （anchoredPosition / sizeDelta / anchorMin / anchorMax / pivot）覆盖已存在的对象，
	 * 旋转/缩放同样取自 prefab；位置、父级、名字、激活态等接管方已有的关键设置保持不动
	 * （页面根由 `page()` 刻意设为未激活，等 `MainSceneController.DisplayPage` 切换，
	 * 因此这里**不**写 `active`）。
	 *
	 * 数据根是 RectTransform 而接管对象上是普通 Transform 时（DebugConsole / Credits /
	 * AchievementHint 三个页面走 `page()`，拿到的是普通 Transform），现场换成 RectTransform：
	 * 换掉父级 children 表里的槽位、搬走旧 Transform 的子节点、并把根对象上各组件的
	 * `transform` 引用改到新实例 —— 与非接管路径 `go.transform = rt` 的效果一致，
	 * 只是发生在挂载之后。
	 */
	static function applyRootTransform(go:GameObject, td:Null<ModelPrefabTransform>,
			existing:Array<Component>):Void {
		if (go == null || td == null)
			return;
		var tr = go.transform;
		if (tr == null)
			return;
		if (td.rect != null) {
			var rt:RectTransform = Std.isOfType(tr, RectTransform) ? cast(tr, RectTransform) : null;
			if (rt == null) {
				rt = new RectTransform();
				rt.name = tr.name;
				rt.gameObject = go;
				// 接管方已摆好的位置/旋转/缩放先照搬过去（下面只覆盖 rect 字段与旋转/缩放）。
				rt.localPosition = tr.localPosition;
				rt.localRotation = tr.localRotation;
				rt.localScale = tr.localScale;
				// 根对象已被调用方挂到目标父级上：换掉父级 children 表里的槽位，保持挂载关系。
				var oldParent = tr.parent;
				if (oldParent != null) {
					var slot = oldParent.children.indexOf(tr);
					if (slot >= 0)
						oldParent.children[slot] = rt;
					else
						oldParent.children.push(rt);
				}
				rt.parent = oldParent;
				// 旧 Transform 上的子节点（若有）转移到新 RectTransform 下。
				var oldChildren = tr.children.copy();
				tr.children = [];
				for (c in oldChildren) {
					c.parent = rt;
					rt.children.push(c);
				}
				go.transform = rt;
				// 手工挂上的组件持有旧 Transform 引用，逐个改到新 RectTransform 上。
				for (comp in go.GetAllComponents()) {
					if (comp != null && comp.transform == tr)
						comp.transform = rt;
				}
				existing[0] = rt;
				tr = rt;
			}
			rt.anchoredPosition = _v2(td.rect.anchoredPosition, 0, 0);
			rt.sizeDelta = _v2(td.rect.sizeDelta, 0, 0);
			rt.anchorMin = _v2(td.rect.anchorMin, 0.5, 0.5);
			rt.anchorMax = _v2(td.rect.anchorMax, 0.5, 0.5);
			rt.pivot = _v2(td.rect.pivot, 0.5, 0.5);
		}
		// 位置保留接管方已有的值（原 Unity 行为：prefab 实例化覆盖 rect 字段，不动调用方摆好的
		// 位置；实测这些根的数据 pos 也都是 (0,0,0)，与接管方默认值一致）。
		tr.localRotation = _quat(td.rot);
		tr.localScale = _v3(td.scale, 1, 1, 1);
	}
	// #endregion
}

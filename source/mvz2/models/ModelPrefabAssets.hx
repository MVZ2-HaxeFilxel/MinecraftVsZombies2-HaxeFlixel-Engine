// Ported from: (新增文件) 对应 Unity 的资产引用解析（Resources/Addressables 加载贴图、材质等）
package mvz2.models;

import flixel.FlxSprite;
import mvz2.models.ModelPrefabData;
import unity.Sprite;
import unity.SpriteRenderer;

// PORT-NOTE: 本文件是移植层新增的「prefab 里的资产引用 -> 运行期对象」解析点，没有 C# 对应源码。
//
// C# 侧 prefab 里的贴图/动画控制器/材质引用由 Unity 资产系统直接给出实例；移植层没有这套系统，
// 因此这里提供：
//   1. 一个可插拔的解析器（Resolver），由资源/精灵工作包在启动时注入；
//   2. 一个默认实现：按 Addressables 地址（或镜像路径、guid:fileID）查
//      unity.addressableassets.Addressables 的进程内注册表，再按 Unity 资产引用
//      （guid + fileID）查精灵清单（mvz2.sprites.SpriteManifestLoader.getSpriteDefinitionByAssetRef），
//      拿到单帧 unity.Sprite（含图集切片）；
//   3. SpriteRenderer.sprite 的旁表：`renderer.sprite` 直接写解析结果——unity.Sprite 由
//      SpriteFrameFactory 经 SpriteRenderer 的 setter 钩子转成 FlxSprite（见 unity/SpriteRenderer.hx），
//      flixel.FlxSprite 则本身就是渲染对象。
class ModelPrefabAssets {
	/** 可插拔解析器：给定 prefab 里的资产引用，返回运行期对象（FlxSprite/unity.Sprite/Material…）或 null。 */
	public static var Resolver:ModelPrefabAssetRef->Dynamic = null;

	/** 资产引用 -> 解析结果（成功过的不再重复解析）。 */
	private static var cache:Map<String, Dynamic> = new Map();
	/** SpriteRenderer -> 该渲染器在 prefab 里引用的精灵（未写入 sprite 字段时记录在此）。 */
	private static var rendererSprites:Map<SpriteRenderer, Dynamic> = new Map();

	/** 统计：解析成功/失败次数与失败样例（诊断用）。 */
	public static var resolvedCount:Int = 0;
	public static var unresolvedCount:Int = 0;
	public static var unresolvedKeys:Array<String> = [];

	/** 资产引用的稳定键："guid:fileID"，与 tools_build 输出一致。 */
	public static function KeyOf(ref:ModelPrefabAssetRef):String {
		if (ref == null)
			return "null";
		return (ref.guid == null ? "?" : ref.guid) + ":" + (ref.fileID == null ? "0" : ref.fileID);
	}

	/** 解析一个资产引用。 */
	public static function Resolve(ref:ModelPrefabAssetRef):Dynamic {
		if (ref == null)
			return null;
		var key = KeyOf(ref);
		if (cache.exists(key))
			return cache.get(key);
		var result:Dynamic = null;
		if (Resolver != null) {
			result = Resolver(ref);
		}
		if (result == null)
			result = resolveFromRegistry(ref);
		cache.set(key, result);
		if (result != null) {
			resolvedCount++;
		} else {
			unresolvedCount++;
			if (unresolvedKeys.length < 100)
				unresolvedKeys.push(key + " (" + (ref.source == null ? ref.path : ref.source) + ")");
		}
		return result;
	}

	/**
	 * 默认解析：查移植层的资源注册表，再按 Unity 资产引用（guid[:fileID]）查精灵清单。
	 *
	 * 顺序：Addressables 地址 -> 镜像路径 -> "guid:fileID" 注册表 -> 精灵清单（guid[:fileID]）。
	 * PORT-NOTE: 最后一档是本工作包接上的：prefab 里 `m_Sprite: {fileID, guid}` 引用的是
	 * Unity 的 Sprite 子资源（图集里的某一帧），清单里有完整的 guid + internalID 对应关系
	 * （见 SpriteManifestLoader.getSpriteDefinitionByAssetRef），因此这里能还原出真正的单帧
	 * unity.Sprite，而不是像以前那样只能命中整图或直接失败。
	 */
	private static function resolveFromRegistry(ref:ModelPrefabAssetRef):Dynamic {
		var registry = unity.addressableassets.Addressables.assets;
		if (ref.address != null && registry.exists(ref.address))
			return registry.get(ref.address);
		if (ref.path != null && registry.exists(ref.path))
			return registry.get(ref.path);
		var key = KeyOf(ref);
		if (registry.exists(key))
			return registry.get(key);
		// PORT-NOTE: 按 Unity 资产引用查精灵清单（kind 为 Image/Sprite 的引用才有意义）。
		if (ref.guid != null && (ref.kind == null || ref.kind == "Image" || ref.kind == "Sprite"
			|| ref.kind == "Texture2D")) {
			var definition = mvz2.sprites.SpriteManifestLoader.getSpriteDefinitionByAssetRef(ref.guid, ref.fileID);
			if (definition != null)
				return mvz2.sprites.SpriteManifestLoader.createSprite(definition);
		}
		// PORT-NOTE: Prefab 资产引用（kind=="Prefab"）：Unity 里这种字段持有 prefab 资产
		// （如 LevelController.entityTemplate = Prefabs/Entity/Entity.prefab），Instantiate 它
		// 才得到实例。移植层没有资产实例句柄，改为按 key 实例化一次并缓存（Resolve 自带 cache），
		// 返回实例根 GameObject；ModelPrefabContext.decode 再按目标字段类型取组件。
		// InstantiatePrefab 的 callAwakeInInstantiate=false：模板只作克隆源，不跑生命周期。
		if (ref.path != null && ref.path.indexOf(".prefab") > 0
				&& (ref.kind == "Prefab" || ref.path.indexOf("Prefabs/") == 0)) {
			var key = ref.path.substr(0, ref.path.indexOf(".prefab"));
			var go = mvz2.scenes.ScenePrefabLoader.InstantiatePrefab(key, null, false);
			if (go != null)
				return go;
		}
		// PORT-NOTE: AnimatorController / AnimationClip 引用返回**数据 key 字符串**
		// （相对 assets 的路径，含扩展名）。`unity.Animator.runtimeAnimatorController` 的 setter
		// 接受字符串并按 key 加载 controller 数据（见 unity/Animator.hx 与
		// mvz2/animations/AnimatorRuntime.hx）—— 这是 Splash → Titlescreen 等页面推进的关键路径。
		if (ref.path != null && (ref.kind == "AnimatorController" || ref.kind == "AnimationClip"))
			return ref.path;
		return null;
	}

	/** 把 prefab 里的精灵引用交给 SpriteRenderer（unity.Sprite 会经 SpriteFrameFactory 落到渲染对象）。 */
	public static function ApplyRendererSprite(renderer:SpriteRenderer, ref:ModelPrefabAssetRef):Void {
		var value = Resolve(ref);
		if (value == null)
			return;
		rendererSprites.set(renderer, value);
		renderer.sprite = value;
	}

	/** 取某个 SpriteRenderer 在 prefab 里引用的精灵（sprite 字段未写入时用）。 */
	public static function GetRendererSprite(renderer:SpriteRenderer):Dynamic {
		return rendererSprites.exists(renderer) ? rendererSprites.get(renderer) : null;
	}

	public static function ResetStats():Void {
		cache.clear();
		rendererSprites.clear();
		resolvedCount = 0;
		unresolvedCount = 0;
		unresolvedKeys = [];
	}
}

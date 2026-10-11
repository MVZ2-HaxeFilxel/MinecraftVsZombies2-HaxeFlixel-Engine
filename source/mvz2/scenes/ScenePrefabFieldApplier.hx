// Ported from: (新增文件) 把场景/prefab 数据里的组件字段写回移植层组件
package mvz2.scenes;

import mvz2.models.ModelPrefabAssets;
import mvz2.models.ModelPrefabContext;
import mvz2.scenes.ScenePrefabData.ScenePrefabComponent;
import pvzengine.base.NamespaceIDReference;
import unity.AnimationCurve;
import unity.Animator;
import unity.Component;
import unity.SpriteRenderer;
import unity.tmpro.TMP_Dropdown.TMP_OptionData;
import unity.ui.Selectable.ColorBlock;
import unity.ui.Graphic;
import unity.ui.Selectable.Navigation;
import unity.ui.LayoutElement.RectOffset;
import unity.ui.Selectable.SpriteState;

// PORT-NOTE: 本文件是移植层新增的「场景数据字段写回」实现，没有 C# 对应源码。
//
// C# 侧场景/prefab 里的 `[SerializeField]` 字段由 Unity 的序列化系统自动填充；移植层只能逐字段写。
// 与 `mvz2.models.ModelPrefabFieldApplier`（模型 prefab 用）的差别：
//   * 模型 prefab 的组件类型集合固定（ModelGroup/EntityModel/元素类），那份实现为它们做了
//     类型化赋值；
//   * 场景/prefab 的组件类型有 30+ 种（UI/TMP/Canvas/相机/碰撞体…），逐类类型化不现实，
//     这里统一走**按名字反射**写入，只在个别组件上做类型化处理（SpriteRenderer 的精灵、
//     Graphic 的 color）。
//
// PORT-NOTE: 字段是否存在用 `Type.getInstanceFields` 判断，**不用 Reflect.hasField**：
// 实测（hxcpp 原生构建）Reflect.hasField 对类实例一律返回 false，会让所有字段都写不进去
// （与 ModelPrefabFieldApplier.applyGeneric 的同一处理）。
class ScenePrefabFieldApplier {
	/**
	 * 把一条组件记录的字段写到组件实例上。
	 *
	 * 返回值：写不进去的字段名列表（null = 全部写入）。调用方把结果记进
	 * `ScenePrefabLoader.missingFields`，便于定位「导出数据有、Haxe 组件没有」的字段。
	 */
	public static function Apply(comp:Component, rec:ScenePrefabComponent, ctx:ModelPrefabContext):Array<String> {
		var fields:Dynamic = rec.fields;
		if (fields == null)
			return null;
		var missing:Array<String> = null;
		for (name in Reflect.fields(fields)) {
			if (!hasField(comp, name)) {
				if (missing == null)
					missing = [];
				missing.push(name);
				continue;
			}
			var raw:Dynamic = Reflect.field(fields, name);
			var current:Dynamic = getField(comp, name);
			// 子字典（如 LayoutGroup 的 padding / CanvasScaler 的 referenceResolution）在 normalize
			// 识别不出具体形态时，才递归写入现有子对象，而不是替换它。
			//
			// PORT-NOTE: normalize 必须**先于** applyNested 执行。normalize 里的 ColorBlock
			// （`m_NormalColor`->`normalColor`）、RectOffset（`m_Left`->`left`）、SpriteState / Navigation
			// 是**专用名字映射**：它们按 Unity 序列化名取数据，而 applyNested 是按 Haxe 字段名做
			// `hasField(target, name)` 匹配的 —— 先走通用递归时这些 Unity 名一个都匹配不上，
			// 于是字段被**静默丢弃**（实测后果：所有 Selectable.colors 恒为声明初值，
			// normalColor 是不透明白，下拉框条目的背景因此盖住白色文字；所有 LayoutGroup.padding 恒为 0）。
			// 所以先给 normalize 一次机会：只有它**原样返回 raw**（`==` 对匿名对象是引用比较，
			// 即没识别出具体形态）时才回退到递归。
			var canRecurse:Bool = isPlainDict(raw) && isNestedObject(current);
			var normalized = normalize(raw, current);
			if (normalized == SKIP)
				continue;
			if (canRecurse && normalized == raw) {
				applyNested(current, raw, ctx);
				continue;
			}
			var value:Dynamic = ctx.decode(normalized, current);
			if (value == null && current != null && isStructField(current)) {
				// PORT-NOTE: 数据里是 null 而字段当前是非 null 的结构体时，保持原值不动 ——
				// C# 里 Vector2/Color 等是 struct，序列化数据缺项时字段保留声明初值，
				// 写成 null 会让后续读取直接空引用（见 PORTING.md「C# struct 默认值 vs Haxe null」）。
				continue;
			}
			if (!isAssignable(value, current)) {
				// PORT-NOTE: 导出数据的字段类型与 Haxe 字段类型不符（例如 Unity YAML 的
				// `m_SortingLayer` 是 int 而 shim 只有 `sortingLayerName:String`）。
				// hxcpp 上把 Int 写进 String 字段不会报错，但下次读取会当字符串解引用 → 段错误。
				// 这里直接跳过并记入 missingFields，宁可缺值也不要崩。
				if (missing == null)
					missing = [];
				missing.push(name + "(类型不符:" + typeNameOf(value) + "->" + typeNameOf(current) + ")");
				continue;
			}
			setField(comp, name, value);
		}
		// 精灵/颜色这类需要走 shim 访问器的字段单独处理。
		if (Std.isOfType(comp, SpriteRenderer)) {
			var sprite = Reflect.field(fields, "sprite");
			if (sprite != null)
				ModelPrefabAssetsBridge.ApplyRendererSprite(cast comp, cast sprite);
		}
		// PORT-NOTE: uGUI 的 Graphic（Image/RawImage）的 `sprite` 字段与 SpriteRenderer 走同一套
		// 资产引用解析：导出数据里是 `{asset:{guid,fileID,path,address}}`，运行期需要落成
		// `unity.Sprite` 才能被 `mvz2.ui.UiRenderer` 取帧。原先这里只处理 SpriteRenderer，
		// Graphic.sprite 一直是 null（= 所有 UI 图片都退化成纯色块，画面因此几乎全黑）。
		if (Std.isOfType(comp, unity.ui.Image)) {
			var imageSprite = Reflect.field(fields, "sprite");
			if (imageSprite != null)
				ModelPrefabAssetsBridge.ApplyImageSprite(cast comp, cast imageSprite);
		}
		if (Std.isOfType(comp, unity.ui.RawImage)) {
			var rawTexture = Reflect.field(fields, "texture");
			if (rawTexture != null)
				ModelPrefabAssetsBridge.ApplyRawImageTexture(cast comp, cast rawTexture);
		}
		return missing;
	}

	/**
	 * 字段写入前的**形态归一化**：Unity 序列化的子对象字典 -> 移植层 shim 的类实例。
	 *
	 * PORT-NOTE: Unity 把这些子结构序列化成无标记 dict，shim 里是普通类：
	 *
	 *   | Unity YAML | shim 字段类型 | 归一化目标 |
	 *   |---|---|---|
	 *   | `m_Colors`（ColorBlock） | `ColorBlock` | `unity.ui.ColorBlock` |
	 *   | `m_SpriteState` | `SpriteState` | `unity.ui.SpriteState` |
	 *   | `m_Navigation` | `Navigation` | `unity.ui.Navigation` |
	 *   | `m_Padding` / `padding`（RectOffset） | `RectOffset` | `unity.ui.RectOffset` |
	 *   | `m_Options`（OptionDataList） | `Array<TMP_OptionData>` | 数组 |
	 *   | `id`（SortingLayerPicker） | `mvz2.SortingLayerPicker` | `new SortingLayerPicker(id)` |
	 *   | `{m_PersistentCalls:{m_Calls:[]}}`（UnityEvent） | 事件类 | `null`（事件不由 prefab 驱动） |
	 *   | `{spacename,path}`（NamespaceIDReference） | 类 | 逐字段写 |
	 *   | `{m_Curve:[{time,value}]}`（AnimationCurve） | `AnimationCurve` | 关键帧数组 |
	 *
	 * 不做归一化时的实际后果（release 无空指针检查 = 直接访问违例）：
	 * `TMP_Dropdown.options` 的 setter 收到匿名对象 → `SetupOptions` 里 `options.copy()` 空引用，
	 * 这是 `ScenePrefabLoader.InstantiateScene("Level")` 段错误的第一处（见
	 * `tools_build/scene_pipeline_work.md` §2）。
	 *
	 * 返回 `SKIP` 表示「该字段不该写」（保持声明初值）；返回 `raw` **本身**（同一引用）表示
	 * 「没识别出具体形态」，调用方据此决定是否回退到通用递归 —— 见 Apply / applyNested 里的
	 * PORT-NOTE（normalize 必须先于 applyNested）。
	 */
	static function normalize(raw:Dynamic, current:Dynamic):Dynamic {
		if (raw == null)
			return null;
		// ---- LayerMask：Unity 把 `LayerMask` 字段序列化成 int（或 {m_Bits}），
		// shim 是类。直接写 int 会让后续 `mask.value` 解引用崩溃。----
		if (Std.isOfType(current, unity.LayerMask) && Type.typeof(raw) != TObject) {
			return new unity.LayerMask(cast raw);
		}
		// ---- Rect：Unity 把 Rect 序列化成 {x,y,width,height}（无 `t` 标记），
		// shim 是 unity.Rect（abstract over class）。----
		if (Std.isOfType(current, unity.Rect) && Type.typeof(raw) == TObject
			&& Reflect.hasField(raw, "width") && Reflect.hasField(raw, "height")
			&& !Reflect.hasField(raw, "t")) {
			return new unity.Rect(cast Reflect.field(raw, "x"), cast Reflect.field(raw, "y"),
				cast Reflect.field(raw, "width"), cast Reflect.field(raw, "height"));
		}
		if (Type.typeof(raw) != TObject)
			return raw;
		if (Reflect.hasField(raw, "n") || Reflect.hasField(raw, "asset") || Reflect.hasField(raw, "t"))
			return raw;

		// ---- UnityEvent 家族：序列化数据里只有 {m_PersistentCalls:{m_Calls:[...]}}，
		// 移植层的事件对象由代码在 Awake 里创建并订阅；用数据覆盖会清空监听（Unity 本身也不序列化
		// 运行期监听）。因此保持声明初值不动。----
		if (Reflect.hasField(raw, "m_PersistentCalls") && Reflect.fields(raw).length == 1)
			return SKIP;

		// ---- TMP_Dropdown.m_Options: {m_Options:[{m_Text,m_Image}]} -> Array<TMP_OptionData> ----
		if (Reflect.hasField(raw, "m_Options") && Reflect.fields(raw).length == 1) {
			var list:Array<Dynamic> = Reflect.field(raw, "m_Options");
			var out:Array<TMP_OptionData> = [];
			if (list != null) {
				for (entry in list) {
					if (entry == null)
						continue;
					var text:Null<String> = Reflect.hasField(entry, "m_Text") ? Reflect.field(entry, "m_Text") : null;
					var image:Null<unity.Sprite> = null;
					var rawImage:Dynamic = Reflect.hasField(entry, "m_Image") ? Reflect.field(entry, "m_Image") : null;
					if (rawImage != null)
						image = cast ModelPrefabAssets.Resolve(cast (Reflect.hasField(rawImage, "asset")
							? Reflect.field(rawImage, "asset") : rawImage));
					out.push(new TMP_OptionData(text, image));
				}
			}
			return out;
		}

		// ---- RectOffset: {m_Left,m_Right,m_Top,m_Bottom} ----
		if (Reflect.hasField(raw, "m_Left") || Reflect.hasField(raw, "m_Right")
			|| Reflect.hasField(raw, "m_Top") || Reflect.hasField(raw, "m_Bottom")) {
			var offset = Std.isOfType(current, RectOffset) ? cast current : new RectOffset();
			if (Reflect.hasField(raw, "m_Left")) offset.left = Reflect.field(raw, "m_Left");
			if (Reflect.hasField(raw, "m_Right")) offset.right = Reflect.field(raw, "m_Right");
			if (Reflect.hasField(raw, "m_Top")) offset.top = Reflect.field(raw, "m_Top");
			if (Reflect.hasField(raw, "m_Bottom")) offset.bottom = Reflect.field(raw, "m_Bottom");
			return offset;
		}

		// ---- PolygonCollider2D.points: {m_Paths:[[{t:"Vector2",v:[x,y]}...]]} -> Array<Vector2> ----
		// PORT-NOTE: Unity 把 `m_Paths` 序列化成「路径数组的数组」，而 shim 的字段是
		// `Array<Vector2>`（单条路径）。不归一化时 `ctx.decode` 会把整个匿名对象原样返回，
		// 于是 `PolygonCollider2D.points` 变成一个**不是数组的对象** —— 后续
		// `UiRenderer.colliderHalfExtents` 读 `points.length` 再 `for (p in points)` 直接失败，
		// 表现为「带 PolygonCollider2D 的按钮（主菜单按钮、地图按钮）命中区解析不出来」。
		// Unity 的 `PolygonCollider2D.points` 正是**第一条路径**的点，故取 m_Paths[0]。
		if (Reflect.hasField(raw, "m_Paths")) {
			var paths:Array<Dynamic> = cast Reflect.field(raw, "m_Paths");
			var out:Array<unity.Vector2> = [];
			if (paths != null && paths.length > 0) {
				var first:Array<Dynamic> = cast paths[0];
				if (first != null) {
					for (point in first) {
						if (point == null)
							continue;
						var v:Array<Float> = cast Reflect.field(point, "v");
						if (v != null && v.length >= 2)
							out.push(new unity.Vector2(v[0], v[1]));
					}
				}
			}
			return out;
		}

		// ---- ColorBlock: {m_NormalColor, m_HighlightedColor, ...} ----
		if (Reflect.hasField(raw, "m_NormalColor")) {
			var block = Std.isOfType(current, ColorBlock) ? cast current : new ColorBlock();
			applyNamed(raw, block, [
				{src: "m_NormalColor", dst: "normalColor"},
				{src: "m_HighlightedColor", dst: "highlightedColor"},
				{src: "m_PressedColor", dst: "pressedColor"},
				{src: "m_SelectedColor", dst: "selectedColor"},
				{src: "m_DisabledColor", dst: "disabledColor"},
				{src: "m_ColorMultiplier", dst: "colorMultiplier"},
				{src: "m_FadeDuration", dst: "fadeDuration"},
			]);
			return block;
		}

		// ---- SpriteState: {m_HighlightedSprite, ...} ----
		if (Reflect.hasField(raw, "m_HighlightedSprite") || Reflect.hasField(raw, "m_PressedSprite")
			|| Reflect.hasField(raw, "m_DisabledSprite")) {
			var state = Std.isOfType(current, SpriteState) ? cast current : new SpriteState();
			applyNamed(raw, state, [
				{src: "m_HighlightedSprite", dst: "highlightedSprite"},
				{src: "m_PressedSprite", dst: "pressedSprite"},
				{src: "m_SelectedSprite", dst: "selectedSprite"},
				{src: "m_DisabledSprite", dst: "disabledSprite"},
			]);
			return state;
		}

		// ---- Navigation: {m_Mode, m_WrapAround, m_SelectOnUp, ...} ----
		if (Reflect.hasField(raw, "m_Mode") && Reflect.hasField(raw, "m_WrapAround")) {
			var nav = Std.isOfType(current, Navigation) ? cast current : new Navigation();
			nav.mode = cast Reflect.field(raw, "m_Mode");
			// PORT-NOTE: shim 的 Navigation 没有 wrapAround 字段（Selectable 的自动导航在本移植层
			// 由 mvz2.ui.Deselector / 自定义输入接管），显式与 SelectOn* 一起忽略。
			return nav;
		}

		// ---- SortingLayerPicker: {id:int} ----
		if (Reflect.hasField(raw, "id") && Reflect.fields(raw).length == 1
			&& (Std.isOfType(current, mvz2.SortingLayerPicker) || current == null)) {
			return new mvz2.SortingLayerPicker(cast Reflect.field(raw, "id"));
		}

		// ---- AnimationCurve: {m_Curve:[{time,value,...}], ...} ----
		if (Reflect.hasField(raw, "m_Curve")) {
			var keys:Array<Dynamic> = Reflect.field(raw, "m_Curve");
			var curve = Std.isOfType(current, AnimationCurve) ? cast current : new AnimationCurve();
			curve.keys.resize(0);
			if (keys != null) {
				for (key in keys) {
					if (key == null)
						continue;
					curve.AddKey(cast Reflect.field(key, "time"), cast Reflect.field(key, "value"));
				}
			}
			return curve;
		}

		// ---- NamespaceIDReference: {spacename, path} ----
		if (Reflect.hasField(raw, "spacename") && Reflect.hasField(raw, "path")) {
			var ref = Std.isOfType(current, NamespaceIDReference)
				? cast current : new NamespaceIDReference();
			// PORT-NOTE: 两个字段在 C#/Haxe 侧都是 private（Unity 由序列化系统写入），
			// 这里与其它 [SerializeField] 字段同样走 Reflect 写入（该文件整体就是反射写字段）。
			Reflect.setField(ref, "spacename", Reflect.field(raw, "spacename"));
			Reflect.setField(ref, "path", Reflect.field(raw, "path"));
			return ref;
		}

		return raw;
	}

	/** 按 (源字段名 -> 目标字段名) 把标量/引用写进已有的类实例。 */
	static function applyNamed(raw:Dynamic, target:Dynamic, mapping:Array<{src:String, dst:String}>):Void {
		for (pair in mapping) {
			if (!Reflect.hasField(raw, pair.src))
				continue;
			var value:Dynamic = Reflect.field(raw, pair.src);
			if (value == null)
				continue;
			// 引用/结构体交给 decode（复用同一套解析），标量直接写。
			var decoded:Dynamic = value;
			if (Type.typeof(value) == TObject)
				decoded = decoder.decode(value, Reflect.field(target, pair.dst));
			if (decoded == null)
				continue;
			Reflect.setField(target, pair.dst, decoded);
		}
	}

	/** 只做「结构体/引用解码」用的解码器（不需要节点图，图内引用一律解析为 null）。 */
	private static var decoder:ModelPrefabContext = new ModelPrefabContext(null);

	/** normalize 的「不写」哨兵值。 */
	private static var SKIP:Dynamic = {};

	/** 递归写入子对象（保持子对象实例，逐字段写）。 */
	static function applyNested(target:Dynamic, fields:Dynamic, ctx:ModelPrefabContext):Void {
		for (name in Reflect.fields(fields)) {
			if (!hasField(target, name))
				continue;
			var raw:Dynamic = Reflect.field(fields, name);
			var current:Dynamic = getField(target, name);
			// PORT-NOTE: 与 Apply 保持完全一致的顺序语义 —— normalize 先跑，只有它**原样返回 raw**
			// （`==` 是引用比较，即没识别出 ColorBlock/RectOffset/SpriteState/Navigation 这类专用映射）
			// 时才回退到「通用递归写子对象」。反过来先递归的话，专用名字映射（Unity 序列化名 -> Haxe
			// 字段名）会被通用递归按 Haxe 名匹配、全部落空而静默丢弃。
			var canRecurse:Bool = isPlainDict(raw) && isNestedObject(current);
			var normalized = normalize(raw, current);
			if (normalized == SKIP)
				continue;
			if (canRecurse && normalized == raw) {
				applyNested(current, raw, ctx);
				continue;
			}
			var value:Dynamic = ctx.decode(normalized, current);
			if (value == null && current != null && isStructField(current))
				continue;
			if (!isAssignable(value, current))
				continue;
			setField(target, name, value);
		}
	}

	/**
	 * 类实例的字段集合（缓存）；匿名对象走 Reflect。
	 *
	 * PORT-NOTE: hxcpp 上 `Type.getInstanceFields` **不包含 Haxe 属性**（`public var x(get,set)`），
	 * 属性只以 `get_x` / `set_x` 方法的形式出现，而且 `Reflect.hasField(obj, "x")` 恒为 false、
	 * `Reflect.setField(obj, "x", v)` 直接抛 `Invalid field:x`（实测，见
	 * tools_build/scene_pipeline_findings.md §5.4）。unity shim 里大量字段是属性
	 * （SpriteRenderer.color/flipX、AudioSource.volume/loop、Toggle.isOn、Slider.value…），
	 * 因此这里把属性也纳入字段集合，并在写入时改走 `set_x`。
	 */
	static function hasField(target:Dynamic, name:String):Bool {
		var cls = Type.getClass(target);
		if (cls == null)
			return Reflect.hasField(target, name);
		var key = Type.getClassName(cls);
		if (key == null)
			return Reflect.hasField(target, name);
		var set = fieldSetCache.get(key);
		if (set == null) {
			set = new Map();
			for (field in Type.getInstanceFields(cls))
				set.set(field, true);
			fieldSetCache.set(key, set);
		}
		if (set.exists(name))
			return true;
		// 属性：写成 set_x 方法即可（读用 get_x）。
		if (set.exists("set_" + name))
			return true;
		return Reflect.hasField(target, name);
	}
	private static var fieldSetCache:Map<String, Map<String, Bool>> = new Map();

	/** 读字段当前值（属性走 get_x，字段走 Reflect.field）。 */
	static function getField(target:Dynamic, name:String):Dynamic {
		var cls = Type.getClass(target);
		if (cls != null) {
			var set = fieldSetCache.get(Type.getClassName(cls));
			if (set != null) {
				if (!set.exists(name) && set.exists("get_" + name)) {
					var getter = Reflect.field(target, "get_" + name);
					if (getter != null && Reflect.isFunction(getter))
						return Reflect.callMethod(target, getter, []);
				}
			}
		}
		return Reflect.field(target, name);
	}

	/** 写字段（属性走 set_x）。 */
	static function setField(target:Dynamic, name:String, value:Dynamic):Void {
		var cls = Type.getClass(target);
		if (cls != null) {
			var set = fieldSetCache.get(Type.getClassName(cls));
			if (set != null && !set.exists(name) && set.exists("set_" + name)) {
				var setter = Reflect.field(target, "set_" + name);
				if (setter != null && Reflect.isFunction(setter)) {
					Reflect.callMethod(target, setter, [value]);
					return;
				}
			}
		}
		Reflect.setField(target, name, value);
	}

	/** 现有字段值是「可递归写入的对象」（shim 的模块对象或结构体），字符串/数组不算。 */
	static function isNestedObject(value:Dynamic):Bool {
		if (value == null)
			return false;
		return switch (Type.typeof(value)) {
			case TObject: true;
			case TClass(c): c != String && c != Array;
			default: false;
		}
	}

	/** 普通字典（不是引用/结构体）时返回 true。 */
	static function isPlainDict(value:Dynamic):Bool {
		// PORT-NOTE: 必须用 Type.typeof 判断匿名对象——hxcpp 上 Reflect.isObject("字符串") 也为 true。
		if (value == null || Type.typeof(value) != TObject)
			return false;
		return !Reflect.hasField(value, "n") && !Reflect.hasField(value, "asset") && !Reflect.hasField(value, "t");
	}

	/** 值是不是 unity 结构体（Vector2/Vector3/Color/…，C# 里是 struct）。 */
	static function isStructField(value:Dynamic):Bool {
		var cls = Type.getClass(value);
		if (cls == null)
			return false;
		var name = Type.getClassName(cls);
		return name != null && StringTools.startsWith(name, "unity.")
			&& StringTools.endsWith(name, "Data");
	}

	/**
	 * 值能否安全写进当前值所在的字段。
	 *
	 * PORT-NOTE: hxcpp 的 Reflect.setField 不做类型检查：把 Int 写进 `String` 字段不会立刻报错，
	 * 但之后读该字段会被当成字符串对象解引用 → 直接访问违例（release 段错误）。
	 * Unity 的 YAML 字段名与类型并不总是与 C# API 一致（`m_SortingLayer` 是 int 哈希、
	 * 而 shim 只有 `sortingLayerName:String`），所以这里按「当前值的运行期类型」做一次守门：
	 *   * 当前是 String → 只接受 String / null
	 *   * 当前是 Bool   → 只接受 Bool / 数字（Unity 里 bool 序列化成 0/1）
	 *   * 当前是数字   → 只接受数字 / Bool
	 *   * 当前是类实例 / 匿名对象 / 数组 / 函数 → 放行（由 decode 负责正确构造）
	 */
	static function isAssignable(value:Dynamic, current:Dynamic):Bool {
		if (value == null)
			return true;
		var valueType = Type.typeof(value);
		switch (Type.typeof(current)) {
			case TClass(c):
				if (c == String)
					return switch (valueType) {
						case TClass(vc): vc == String;
						default: false;
					}
				return true;
			case TInt, TFloat:
				return switch (valueType) {
					case TInt, TFloat, TBool: true;
					default: false;
				}
			case TBool:
				return switch (valueType) {
					case TInt, TFloat, TBool: true;
					default: false;
				}
			default:
				return true;
		}
	}

	/** 运行期类型名（诊断用，写进 missingFields）。 */
	static function typeNameOf(value:Dynamic):String {
		if (value == null)
			return "null";
		return switch (Type.typeof(value)) {
			case TClass(c): Type.getClassName(c);
			case TEnum(e): Type.getEnumName(e);
			case TInt: "Int";
			case TFloat: "Float";
			case TBool: "Bool";
			case TObject: "Object";
			case TFunction: "Function";
			default: "Unknown";
		}
	}
}

// PORT-NOTE: `ModelPrefabAssets.ApplyRendererSprite` 的参数类型是
// `mvz2.models.ModelPrefabAssetRef`（typedef，运行期就是匿名对象），与导出数据的
// `{asset:{...}}` 包装不同：这里先解包再调用，保持「精灵引用走同一套解析/旁表」的语义。
private class ModelPrefabAssetsBridge {
	public static function ApplyRendererSprite(renderer:SpriteRenderer, raw:Dynamic):Void {
		var ref:Dynamic = raw;
		if (Reflect.hasField(raw, "asset"))
			ref = Reflect.field(raw, "asset");
		ModelPrefabAssets.ApplyRendererSprite(renderer, cast ref);
	}

	// PORT-NOTE: uGUI 的 Image.sprite 与 SpriteRenderer.sprite 共用同一份资产引用解析，
	// 但结果必须落成 `unity.Sprite`（而不是 FlxSprite）——`mvz2.ui.UiRenderer` 用
	// `SpriteFrameFactory.getFrame(sprite)` 取帧，需要 rect/pivot 才能算出正确子矩形。
	// 图集里的单帧（`{guid, fileID}` 指向子精灵）按 fileID 在 sprites_manifest 的
	// `internalIDString` 里反查（见 SpriteManifestLoader.findSpriteByFileID）。
	public static function ApplyImageSprite(image:unity.ui.Image, raw:Dynamic):Void {
		var sprite = ResolveSprite(raw);
		if (sprite != null)
			image.sprite = sprite;
	}

	public static function ApplyRawImageTexture(rawImage:unity.ui.RawImage, raw:Dynamic):Void {
		var texture = ModelPrefabAssets.Resolve(cast Unwrap(raw));
		if (Std.isOfType(texture, unity.Texture2D))
			rawImage.texture = cast texture;
	}

	/** 解析精灵引用：优先按 (guid, fileID) 反查清单，再回退到 ModelPrefabAssets 的注册表。 */
	public static function ResolveSprite(raw:Dynamic):unity.Sprite {
		var ref:Dynamic = Unwrap(raw);
		if (ref == null)
			return null;
		var guid:String = Reflect.hasField(ref, "guid") ? Std.string(Reflect.field(ref, "guid")) : null;
		var fileID:String = Reflect.hasField(ref, "fileID") ? Std.string(Reflect.field(ref, "fileID")) : null;
		if (guid != null) {
			var sprite = mvz2.sprites.SpriteManifestLoader.findSpriteByFileID(guid, fileID);
			if (sprite != null)
				return sprite;
		}
		var resolved = ModelPrefabAssets.Resolve(cast ref);
		return Std.isOfType(resolved, unity.Sprite) ? cast resolved : null;
	}

	static function Unwrap(raw:Dynamic):Dynamic {
		if (raw == null)
			return null;
		return Reflect.hasField(raw, "asset") ? Reflect.field(raw, "asset") : raw;
	}
}

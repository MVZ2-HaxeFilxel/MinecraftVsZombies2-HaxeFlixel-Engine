// Ported from: (新增文件) prefab 实例化过程中的节点/组件表与 JSON 值解码
package mvz2.models;

import mvz2.models.ModelPrefabData;
import unity.Component;
import unity.GameObject;
import unity.Quaternion;
import unity.Vector2;
import unity.Vector3;
import unity.Vector4;

/**
 * 一次实例化过程中的节点/组件表，用于把 {n, c} 引用解析成真实对象。
 */
class ModelPrefabContext {
	public var data:ModelPrefabFile;
	public var gameObjects:Array<GameObject> = [];
	/** components[节点][0] = Transform，components[节点][k+1] = 节点第 k 个组件（与编码约定一致）。 */
	public var components:Array<Array<Component>> = [];

	public function new(data:ModelPrefabFile) {
		this.data = data;
	}

	/** 解析 {n, c} 引用（c==null → GameObject；c==0 → Transform；c==k+1 → components[k]）。 */
	public function resolveRef(n:Null<Int>, c:Null<Int>):Dynamic {
		if (n == null || n < 0 || n >= gameObjects.length)
			return null;
		var go = gameObjects[n];
		if (c == null)
			return go;
		// components[n][0] 就是 Transform，components[n][k+1] 是节点第 k 个组件，
		// 所以导出数据里的 c 可以直接当数组下标用（c==0 即 Transform）。
		var list = components[n];
		if (c < 0 || c >= list.length)
			return null;
		return list[c];
	}

	/**
	 * 把 JSON 值解码成运行期对象。
	 *
	 * 编码约定（见 ModelPrefabData）：
	 *   {n[,c]}                  -> 图内对象引用（GameObject / Transform / Component）
	 *   {asset:{...}}            -> 图外资产（贴图/材质/动画控制器…），交给 ModelPrefabAssets
	 *   {t, v}                   -> Unity 结构体（Vector2/3/4、Color、Rect、Quaternion）
	 *   数组/字典/标量           -> 递归解码
	 *
	 * PORT-NOTE: 标量必须先于「对象」分支处理——hxcpp 上 Reflect.isObject("字符串") 返回 true
	 * （字符串也是 hx::Object），只靠 Reflect.isObject 会把所有字符串字段解码成空匿名对象。
	 * 因此这里用 Type.typeof 区分标量 / 数组 / 匿名对象 / 类实例。
	 *
	 * current 是该字段当前的默认值，用来判断字段的实际类型：字段类型为 Quaternion 但 JSON 只标了
	 * Vector4（同 4 分量）时以字段类型为准。
	 */
	public function decode(raw:Dynamic, ?current:Dynamic):Dynamic {
		if (raw == null)
			return null;
		switch (Type.typeof(raw)) {
			case TNull, TBool, TInt, TFloat, TFunction:
				return raw;
			case TClass(c):
				if (c == String)
					return raw;
				if (c == Array) {
					var arr:Array<Dynamic> = cast raw;
					var curArr:Array<Dynamic> = (current != null && Std.isOfType(current, Array)) ? cast current : null;
					var out:Array<Dynamic> = [];
					for (i in 0...arr.length) {
						out.push(decode(arr[i], curArr != null && i < curArr.length ? curArr[i] : null));
					}
					return out;
				}
				// PORT-NOTE: 走到这里 raw 一定是**类实例**（匿名对象走 TObject 分支）。
				// `ScenePrefabFieldApplier.normalize` 会把 Unity 序列化出来的 dict 归归一成 shim
				// 类实例（TMP_OptionData / ColorBlock / Navigation / RectOffset / AnimationCurve /
				// NamespaceIDReference 等）再交给这里解码；此前本分支没有 return，落到下面的
				// `Reflect.isObject` 分支被逐字段复制成**匿名对象**（拍平），调用方再按类实例
				// 读字段（option.text / offset.left / curve.keys…）就是未定义行为（疑似启动期
				// 非确定性段错误的来源）。类实例一律原样返回。
				if (Type.getClass(raw) != null)
					return raw;
			case TObject:
				// 匿名对象（JSON 解析结果）继续往下走。
			default:
				return raw;
		}
		if (Reflect.isObject(raw)) {
			if (Reflect.hasField(raw, "n")) {
				var n:Null<Int> = Reflect.field(raw, "n");
				var c:Null<Int> = Reflect.hasField(raw, "c") ? Reflect.field(raw, "c") : null;
				return resolveRef(n, c);
			}
			if (Reflect.hasField(raw, "asset")) {
				var resolved = ModelPrefabAssets.Resolve(cast Reflect.field(raw, "asset"));
				// PORT-NOTE: Prefab 资产引用解析出的是**实例根 GameObject**（Unity 里该字段持有
				// prefab 资产，Instantiate 才得实例；见 ModelPrefabAssets 的 Prefab 分支）。
				// 而这类字段的目标类型几乎都是「prefab 根上的主控制器组件」
				//（LevelController.entityTemplate 要 EntityController，即 Entity.prefab 根上
				// 第一个 MonoBehaviour）。导出数据不带 Unity fileID，无法精确映射到组件，
				// 因此按两条规则取组件：字段有默认实例（current）时按类型匹配；
				// 否则取根上第一个 MonoBehaviour（跳过 Transform）。
				if (resolved != null && Std.isOfType(resolved, GameObject)) {
					var go = cast(resolved, GameObject);
					var wanted = current != null ? Type.getClass(current) : null;
					if (wanted != null) {
						var comp = go.GetComponent(wanted);
						if (comp != null)
							return comp;
					} else {
						for (c in go.GetAllComponents()) {
							if (c != null && Std.isOfType(c, unity.MonoBehaviour) && !Std.isOfType(c, unity.Transform))
								return c;
						}
					}
				}
				return resolved;
			}
			if (Reflect.hasField(raw, "t")) {
				return structFromTag(raw, current);
			}
			var out:Dynamic = {};
			for (name in Reflect.fields(raw)) {
				Reflect.setField(out, name, decode(Reflect.field(raw, name), null));
			}
			return out;
		}
		return raw;
	}

	/** {t:"Vector3", v:[...]} -> unity 结构体实例。 */
	function structFromTag(raw:Dynamic, ?current:Dynamic):Dynamic {
		var values:Array<Float> = cast Reflect.field(raw, "v");
		var tag:String = Reflect.field(raw, "t");
		var fieldType = structTypeOf(current);
		if (fieldType != null)
			tag = fieldType;
		var a:Float = values != null && values.length > 0 ? values[0] : 0;
		var b:Float = values != null && values.length > 1 ? values[1] : 0;
		var c:Float = values != null && values.length > 2 ? values[2] : 0;
		var d:Float = values != null && values.length > 3 ? values[3] : 0;
		switch (tag) {
			case "Vector2":
				return new Vector2(a, b);
			case "Vector3":
				return new Vector3(a, b, c);
			case "Vector4":
				return new Vector4(a, b, c, d);
			case "Quaternion":
				return new Quaternion(a, b, c, d);
			case "Color":
				return new unity.Color(a, b, c, d);
			case "Rect":
				return new unity.Rect(a, b, c, d);
			default:
				return null;
		}
	}

	/** 字段当前值的 unity 结构体类型名（Vector3Data -> Vector3）。 */
	static function structTypeOf(current:Dynamic):Null<String> {
		if (current == null)
			return null;
		var cls = Type.getClass(current);
		if (cls == null)
			return null;
		var name = Type.getClassName(cls);
		if (name == null || name.indexOf("unity.") != 0)
			return null;
		var short = name.substr("unity.".length);
		if (StringTools.endsWith(short, "Data"))
			short = short.substr(0, short.length - 4);
		return switch (short) {
			case "Vector2" | "Vector3" | "Vector4" | "Quaternion" | "Color" | "Rect" | "Color32": short;
			default: null;
		}
	}
}

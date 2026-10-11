// PORT-NOTE: 运行期 JSON hydration。
// 背景：haxe.Json.parse 产出的是匿名结构（hxcpp 的 hx::Anon），其内存布局与真实 Haxe 类不同；
// 旧反序列化 shim 把匿名对象直接当类实例返回，生成的 C++ 按固定偏移访问"字段"，读到错位数据
// 后形成野指针，造成随机段错误。本工具按 RTTI 把 JSON 树重建为真实类实例与真正的 typed Array
// （Array<Int>/Array<Float> 在 hxcpp 上是独立存储的特化类型，不能用 Array<Dynamic> 顶替）。
// RTTI 来源：存档字段图里的数据类（Serializable*、BuffReference 系列、Timer/FrameTimer、
// unity 的 Vector*Data/ColorData 等）逐个标注了 @:rtti——不能用 addGlobalMetadata 按包全局
// 附加，因为大类的 RTTI XML 会超过 MSVC 的字符串字面量上限（C2026）。
// 用于 json2object 无法表达的类型图（含 Dynamic / 接口 / Int64 / 多态数组的存档结构）：
//   - 接口 / 多态（JSON 字段超出声明字段）/ 无 RTTI 的类：保持匿名结构，维持移植层既有的鸭子类型语义；
//   - 具体类：Type.createEmptyInstance + 逐字段递归重建（含父类字段）。
package mvz2logic.serialization;

import haxe.Int64;
import haxe.rtti.CType;
import haxe.rtti.Rtti;

class TypedJson
{
	// abstract-over-class 的 shim 类型（unity.Vector2/Vector3/Color 等）：abstract 无运行期实体，
	// RTTI 拿不到底层类型，这里显式登记 abstract 路径 -> 底层数据类的运行期名称
	// （模块次类型的运行期名为 "pack._Module.Type"）。
	static var abstractImpls:Map<String, String> = [
		"unity.Vector2" => "unity._Vector2.Vector2Data",
		"unity.Vector3" => "unity._Vector3.Vector3Data",
		"unity.Color" => "unity._Color.ColorData",
	];

	static var rttiCache:Map<String, Null<Classdef>> = new Map();
	static var fieldsCache:Map<String, Map<String, FieldInfo>> = new Map();

	/// 把 haxe.Json.parse 的产物按 className 声明的类型重建为真实实例。无法重建时原样返回。
	public static function hydrate(value:Dynamic, className:String):Dynamic
	{
		if (value == null)
			return null;
		var cls = resolveClass(className);
		if (cls == null)
			return value;
		return hydrateClass(value, cls);
	}

	static function resolveClass(name:String):Class<Dynamic>
	{
		if (name == null)
			return null;
		return Type.resolveClass(name);
	}

	static function getClassDef(cls:Class<Dynamic>):Null<Classdef>
	{
		var name = Type.getClassName(cls);
		if (name == null)
			return null;
		if (rttiCache.exists(name))
			return rttiCache.get(name);
		var def = try Rtti.getRtti(cls) catch (e:Dynamic) null;
		rttiCache.set(name, def);
		return def;
	}

	// 收集本类及全部父类的字段名 -> 字段信息。
	static function collectFields(cls:Class<Dynamic>):Map<String, FieldInfo>
	{
		var className = Type.getClassName(cls);
		var cached = fieldsCache.get(className);
		if (cached != null)
			return cached;
		var result = new Map<String, FieldInfo>();
		var current:Null<Class<Dynamic>> = cls;
		while (current != null)
		{
			var def = getClassDef(current);
			if (def == null)
				break;
			for (f in def.fields)
			{
				if (result.exists(f.name))
					continue;
				var writable = true;
				switch (f.type)
				{
					case CFunction(_, _):
						writable = false;
					default:
				}
				if (writable)
				{
					switch (f.get)
					{
						// 纯计算属性（如 Timer.Expired），无存储，跳过。
						case RCall(_):
							writable = false;
						default:
					}
				}
				result.set(f.name, {type: f.type, writable: writable});
			}
			current = def.superClass != null ? resolveClass(def.superClass.path) : null;
		}
		fieldsCache.set(className, result);
		return result;
	}

	static function hydrateClass(value:Dynamic, cls:Class<Dynamic>):Dynamic
	{
		if (value == null)
			return null;
		if (!Reflect.isObject(value) || Std.isOfType(value, Array) || Std.isOfType(value, String))
			return value;
		var def = getClassDef(cls);
		// 无 RTTI 或接口：保持匿名（鸭子类型），与移植层既有行为一致。
		if (def == null || def.isInterface)
			return value;
		var fields = collectFields(cls);
		// 多态保护：JSON 含声明之外的字段（子类实例，如 BuffReferenceEntity）时保持匿名，
		// 避免丢失子类字段——C# BSON 靠类型鉴别符还原子类，纯 JSON 没有这个信息。
		for (name in Reflect.fields(value))
		{
			if (!fields.exists(name))
				return value;
		}
		var instance = Type.createEmptyInstance(cls);
		for (name in Reflect.fields(value))
		{
			var info = fields.get(name);
			if (info == null || !info.writable)
				continue;
			var v = hydrateValue(Reflect.field(value, name), info.type);
			try
				Reflect.setField(instance, name, v)
			catch (e:Dynamic) {}
		}
		return instance;
	}

	static function hydrateValue(value:Dynamic, type:CType):Dynamic
	{
		if (value == null)
			return null;
		switch (type)
		{
			case CClass(name, params):
				if (shortName(name) == "String")
					return value;
				if (shortName(name) == "Array" && params != null && params.length == 1)
					return hydrateArray(value, params[0]);
				var cls = resolveClass(name);
				if (cls == null)
					return value;
				return hydrateClass(value, cls);
			case CAbstract(name, params):
				switch (shortName(name))
				{
					case "Null":
						return (params != null && params.length == 1) ? hydrateValue(value, params[0]) : value;
					case "Int":
						return toInt(value);
					case "Float" | "Single":
						return toFloat(value);
					case "Bool":
						return value == true;
					case "Int64":
						return toInt64(value);
					case "Map":
						if (params != null && params.length == 2)
							return hydrateMap(value, params[1]);
						return value;
					default:
						// NamespaceID 等 abstract-over-String：运行期值本身就是字符串，原样返回。
						if (Std.isOfType(value, String))
							return value;
						var impl = abstractImpls.get(name);
						if (impl != null)
						{
							var cls = resolveClass(impl);
							if (cls != null)
								return hydrateClass(value, cls);
						}
						return value;
				}
			// 枚举 / typedef / 匿名结构 / Dynamic：匿名产物即正确运行期形态，原样返回。
			case CEnum(_, _) | CTypedef(_, _) | CAnonymous(_) | CDynamic(_) | CUnknown | CFunction(_, _):
				return value;
		}
	}

	static function shortName(path:String):String
	{
		var dot = path.lastIndexOf(".");
		return dot >= 0 ? path.substr(dot + 1) : path;
	}

	static function arrayElemKind(type:CType):ArrayElemKind
	{
		switch (type)
		{
			case CAbstract(name, params):
				switch (shortName(name))
				{
					case "Null":
						return (params != null && params.length == 1) ? arrayElemKind(params[0]) : KOther;
					case "Int":
						return KInt;
					case "Float" | "Single":
						return KFloat;
					case "Bool":
						return KBool;
					case "Int64":
						return KInt64;
					default:
						return KOther;
				}
			case CClass(name, _):
				return shortName(name) == "String" ? KString : KOther;
			default:
				return KOther;
		}
	}

	// hxcpp 上数值/布尔数组是独立存储的特化类型，必须按声明元素类型显式重建；
	// 对象元素数组共享同一运行期表示，重建为 Array<Dynamic> 并递归 hydrate 元素即可。
	static function hydrateArray(value:Dynamic, elemType:CType):Dynamic
	{
		if (!Std.isOfType(value, Array))
			return value;
		var source:Array<Dynamic> = cast value;
		switch (arrayElemKind(elemType))
		{
			case KInt:
				var r:Array<Int> = [];
				for (x in source)
					r.push(x == null ? 0 : toInt(x));
				return r;
			case KFloat:
				var r:Array<Float> = [];
				for (x in source)
					r.push(x == null ? 0 : toFloat(x));
				return r;
			case KBool:
				var r:Array<Bool> = [];
				for (x in source)
					r.push(x == true);
				return r;
			case KInt64:
				var r:Array<Int64> = [];
				for (x in source)
					r.push(toInt64(x));
				return r;
			case KString:
				var r:Array<String> = [];
				for (x in source)
					r.push(x == null ? null : Std.string(x));
				return r;
			case KOther:
				var r:Array<Dynamic> = [];
				for (x in source)
					r.push(hydrateValue(x, elemType));
				return r;
		}
	}

	static function hydrateMap(value:Dynamic, valueType:CType):Dynamic
	{
		if (!Reflect.isObject(value) || Std.isOfType(value, Array) || Std.isOfType(value, String))
			return value;
		// Map<String, V> 的运行期类是 haxe.ds.StringMap（值存 Dynamic），与 V 无关。
		var result = new Map<String, Dynamic>();
		for (name in Reflect.fields(value))
			result.set(name, hydrateValue(Reflect.field(value, name), valueType));
		return result;
	}

	static function toInt(value:Dynamic):Int
	{
		if (Std.isOfType(value, Int))
			return cast value;
		if (Std.isOfType(value, Float))
			return Std.int(cast(value, Float));
		if (Std.isOfType(value, String))
			return Std.parseInt(cast value) ?? 0;
		if (value == true)
			return 1;
		return 0;
	}

	static function toFloat(value:Dynamic):Float
	{
		if (Std.isOfType(value, Float) || Std.isOfType(value, Int))
			return cast value;
		if (Std.isOfType(value, String))
			return Std.parseFloat(cast value);
		return 0;
	}

	// Int64 在 JSON 中的形态取决于写入端：数字（BSON 语义）或 hxcpp 的 {high, low} 对象。
	static function toInt64(value:Dynamic):Null<Int64>
	{
		if (value == null)
			return null;
		if (Std.isOfType(value, Int))
			return Int64.ofInt(cast value);
		if (Std.isOfType(value, Float))
			return Int64.ofInt(Std.int(cast(value, Float)));
		if (Std.isOfType(value, String))
		{
			return try Int64.parseString(cast value) catch (e:Dynamic) Int64.ofInt(0);
		}
		if (Reflect.isObject(value))
		{
			var low = Reflect.field(value, "low");
			var high = Reflect.field(value, "high");
			if (low != null || high != null)
				return Int64.make(high == null ? 0 : toInt(high), low == null ? 0 : toInt(low));
		}
		return Int64.ofInt(0);
	}
}

private typedef FieldInfo = {
	type:CType,
	writable:Bool,
}

private enum ArrayElemKind
{
	KInt;
	KFloat;
	KBool;
	KInt64;
	KString;
	KOther;
}

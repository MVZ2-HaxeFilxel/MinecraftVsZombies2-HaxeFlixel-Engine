// PORT-NOTE: 反序列化 shim（SerializeHelper.FromBson/ReadBson、JsonConvert.DeserializeObject）
// 的编译期分发逻辑。haxe.Json.parse 的匿名产物（hxcpp 的 hx::Anon）内存布局与真实类不同，
// 直接当类实例返回会造成固定偏移字段访问错位 → 随机段错误。因此按目标类型在编译期选路：
//   1. 静态类型无法确定（typedef 目标 / 无显式类型实参）：退回裸 haxe.Json.parse——
//      typedef（匿名结构）的运行期形态本来就是 Anon，天然安全；
//   2. HYDRATE_PATHS 中的类型（字段图含 Dynamic / 接口 / Int64 / 多态数组，
//      json2object 宏无法生成 parser）：用 TypedJson 的 RTTI hydration 重建真实实例；
//   3. 其余具体类 / typedef：生成 json2object.JsonParser<T>（编译期 typed parser，
//      产出真实类实例与真正的 typed Array）。错误处理对齐 Newtonsoft 的宽容语义：
//      未知字段、缺失字段、类型不符只收集不抛异常；仅语法错误（ParserError）抛出，
//      与旧 haxe.Json.parse 对非法 JSON 抛异常的行为一致。
package mvz2logic.serialization;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

class DeserializeBuilder
{
#if macro
	// 字段图无法静态表达、必须走运行期 hydration 的类型（全限定路径）。
	static var HYDRATE_PATHS:Array<String> = [
		"mvz2logic.saves.SerializableLogicSaveData",
		"mvz2.level.SerializableLevelController",
	];

	// jsonExpr: JSON 字符串表达式；typeExpr: 可选的类字面量（Class<T>）。
	public static function build(jsonExpr:Expr, typeExpr:Null<Expr>):Expr
	{
		var target = resolveTarget(typeExpr);
		if (target == null)
		{
			// 无静态类型信息：保持旧的裸 parse 行为（typedef 目标在此分支）。
			return macro haxe.Json.parse($jsonExpr);
		}
		var ct = TypeTools.toComplexType(target);
		var path = TypeTools.toString(target);
		if (HYDRATE_PATHS.indexOf(path) >= 0)
		{
			return macro @:pos(jsonExpr.pos)
				(cast mvz2logic.serialization.TypedJson.hydrate(haxe.Json.parse($jsonExpr), $v{path}) : $ct);
		}
		switch (Context.follow(target))
		{
			case TAnonymous(_):
				// 匿名结构（typedef）：parse 产物即正确形态。
				return macro @:pos(jsonExpr.pos) (cast haxe.Json.parse($jsonExpr) : $ct);
			default:
		}
		return macro @:pos(jsonExpr.pos) {
			var parser = new json2object.JsonParser<$ct>();
			var result = parser.fromJson($jsonExpr, $v{path});
			for (error in parser.errors)
			{
				if (Type.enumConstructor(error) == "ParserError")
					throw "Invalid JSON: " + Std.string(error);
			}
			result;
		};
	}

	static function resolveTarget(typeExpr:Null<Expr>):Null<Type>
	{
		if (typeExpr != null)
		{
			var isNullLiteral = switch (typeExpr.expr)
			{
				case EConst(CIdent("null")): true;
				default: false;
			};
			if (!isNullLiteral)
			{
				var typeType = try Context.typeof(typeExpr) catch (e:Dynamic) null;
				if (typeType != null)
				{
					var extracted = extractClassParam(typeType);
					if (extracted != null)
						return concreteOrNull(extracted);
				}
			}
		}
		var expected = Context.getExpectedType();
		if (expected == null)
			return null;
		return concreteOrNull(expected);
	}

	// 从 Class<T> 中提取 T。
	static function extractClassParam(t:Type):Null<Type>
	{
		switch (Context.follow(t))
		{
			case TAbstract(_.get() => a, params) if (a.name == "Class" && params.length == 1):
				return params[0];
			case TType(_.get() => td, params) if (td.name == "Class" && params.length == 1):
				return params[0];
			default:
				return null;
		}
	}

	// 解包 Null<T>，并排除无法具体化的类型（单态 / 类型参数 / Dynamic）。
	static function concreteOrNull(t:Type):Null<Type>
	{
		t = Context.follow(t, true);
		switch (t)
		{
			case TAbstract(_.get() => a, params) if (a.name == "Null" && params.length == 1):
				t = Context.follow(params[0], true);
			default:
		}
		switch (t)
		{
			case TMono(_) | TDynamic(_):
				return null;
			case TInst(_.get() => c, _):
				switch (c.kind)
				{
					case KTypeParameter(_):
						return null;
					default:
				}
				return t;
			case TAnonymous(_) | TEnum(_, _) | TType(_, _) | TAbstract(_, _):
				return t;
			default:
				return null;
		}
	}
#end
}

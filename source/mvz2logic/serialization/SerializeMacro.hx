// PORT-NOTE: SerializeHelper.FromBson/ReadBson 的宏入口（独立模块）。
// 这两个 API 必须是编译期宏——按调用点的目标类型生成分发型反序列化代码
// （json2object typed parser / TypedJson RTTI hydration / 裸 parse，见 DeserializeBuilder），
// 因为 haxe.Json.parse 的匿名产物（hxcpp 的 hx::Anon）内存布局与真实类不同，
// 直接当类实例返回会让生成 C++ 的固定偏移字段访问读到错位数据 → 随机段错误。
// 宏不能放在 SerializeHelper.hx：macro context 编译宏时会牵引宿主模块的整个 import 图
// （SerializeHelper → unity.Debug → unity.GameObject → flixel.group.FlxGroup），
// 而 flixel.util.FlxSignal 的全部内容在 `#if macro #else` 分支里（macro context 中
// FlxTypedSignal 不存在），类型化必炸。本模块保持零非宏依赖。
package mvz2logic.serialization;

class SerializeMacro
{
	// C#: T FromBson<T>(string bson)。type 可省略（省略时靠调用点返回类型推断；
	// 推断不出则说明目标是 typedef/匿名结构，退回裸 parse 即正确形态）。
	public static macro function FromBson(bson:haxe.macro.Expr.ExprOf<String>, ?type:haxe.macro.Expr):haxe.macro.Expr
	{
		return mvz2logic.serialization.DeserializeBuilder.build(bson, type);
	}
	// TODO-PORT: C# 参数为 IBsonReader，Haxe 无对应类型，改为读取整段字符串。
	public static macro function ReadBson(text:haxe.macro.Expr.ExprOf<String>, ?type:haxe.macro.Expr):haxe.macro.Expr
	{
		return mvz2logic.serialization.DeserializeBuilder.build(text, type);
	}
}

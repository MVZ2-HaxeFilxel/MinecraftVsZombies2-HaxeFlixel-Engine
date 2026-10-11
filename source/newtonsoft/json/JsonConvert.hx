// Ported from: Newtonsoft.Json.JsonConvert (minimal shim)
package newtonsoft.json;

// PORT-NOTE: Haxe 没有运行期字段类型信息，反序列化需要显式传入目标 Class（C# 通过泛型获得）。
// 调用方式：JsonConvert.DeserializeObject(json, MyType)。
// 旧的手写递归 convert 有两个布局级 bug：数组分支对每个元素用顶层类转换；对象分支把
// Json 的 Array<Dynamic> 直接塞进声明为 Array<具体类> 的字段——hxcpp 上 typed Array 是
// 独立存储的特化类型，Anon/Array<Dynamic> 与真实类/typed Array 混用会造成固定偏移访问错位
// → 随机段错误。现改为编译期宏：目标类型静态已知时生成 json2object typed parser
// （宽容语义对齐 Newtonsoft：未知/缺失字段不抛错），详见 mvz2logic.serialization.DeserializeBuilder。
class JsonConvert {
    public static function SerializeObject(value:Dynamic, ?formatting:Dynamic):String {
        return haxe.Json.stringify(value);
    }

    public static macro function DeserializeObject(value:haxe.macro.Expr.ExprOf<String>, ?type:haxe.macro.Expr):haxe.macro.Expr {
        // 保留旧的 null/空串守卫语义（返回 null 而非抛异常）。
        return macro @:pos(value.pos) {
            var json = $value;
            json == null || json == "" ? null : ${mvz2logic.serialization.DeserializeBuilder.build(macro json, type)};
        };
    }

    public static function DeserializeObjectUntyped(value:String):Dynamic {
        if (value == null || value == "") return null;
        return haxe.Json.parse(value);
    }
}

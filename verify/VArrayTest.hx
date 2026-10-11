class Comp {
	public var name:String;
	public function new(n:String) name = n;
}

class VArrayTest {
	static function storeType(a:Dynamic):String {
		var st:Dynamic = Reflect.field(a, "_hx_storeType");
		return Std.string(st);
	}

	// 全部操作都在泛型函数内（数组是 cpp::VirtualArray）
	static function scenario<T>(label:String, own:Array<T>, children:Array<Array<T>>) {
		var result:Array<T> = own;
		Sys.println(label + ' own store=' + storeType(result));
		for (child in children) {
			var cr:Array<T> = child;
			result = result.concat(cr);
			Sys.println(label + ' concat child(len=' + cr.length + ',store=' + storeType(cr) + ') -> store=' + storeType(result) + ' len=' + result.length);
		}
		for (i in 0...result.length) {
			var e:Dynamic = result[i];
			Sys.println(label + '   #' + i + ' typeof=' + Type.typeof(e) + ' str=' + Std.string(e));
		}
	}

	static function mk<T>(items:Array<Comp>):Array<T> {
		var r:Array<T> = [];
		for (c in items) r.push(cast c);
		return r;
	}

	static function main() {
		// A: 空 concat 空
		scenario("A", mk([]), [mk([])]);
		// B: 空 concat 空 concat 2元素（游戏里的 S1 模式）
		scenario("B", mk([]), [mk([]), mk([new Comp("a"), new Comp("b")])]);
		// C: 空 concat 2元素
		scenario("C", mk([]), [mk([new Comp("a"), new Comp("b")])]);
		// D: 2元素 concat 空
		scenario("D", mk([new Comp("a"), new Comp("b")]), [mk([])]);
	}
}

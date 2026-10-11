// Ported from: Assets/Scripts/Logic/Modding/Mod.cs
package mvz2logic.modding;

import mvz2logic.games.IGlobalGame;
import mvz2logic.saves.ModSaveData;
import mvz2logic.serialization.SerializeHelper;
import pvzengine.IGameContent;
import pvzengine.NamespaceID;
import pvzengine.base.Definition;
import pvzengine.base.DefinitionGroup;
import pvzengine.base.ICachedDefinition;
import pvzengine.callbacks.CallbackResult;
import pvzengine.callbacks.CallbackType;
import pvzengine.callbacks.ITrigger;
import pvzengine.callbacks.Trigger;

// abstract
// PORT-NOTE: C# 为 `Mod : IGameContent, IModLogic`。IGameContent 要求 `GetDefinitions<T>(cl, type)`
// 而 IModLogic 要求 `GetDefinitions()`，Haxe 不允许同类中出现两个同名字段（无重载），
// 故此处只保留 IModLogic（GlobalGame.AddMod 依赖 `mod.GetDefinitions()`）；Mod 的定义查询方法保持 C# 原名。
class Mod implements IModLogic
{
	public function new(nsp:String)
	{
		_Namespace = nsp;
	}

	// #region 初始化
	public function Init(game:IGlobalGame):Void
	{
	}
	public function LateInit(game:IGlobalGame):Void
	{

	}
	public function PostGameInit():Void {}
	public function PostReloadMods(game:IGlobalGame):Void
	{
		for (definition in definitionGroup.GetDefinitions())
		{
			if (Std.isOfType(definition, ICachedDefinition))
			{
				var cached:ICachedDefinition = cast definition;
				cached.ClearCaches();
				cached.CacheContents(game);
			}
		}
	}
	// #endregion

	// #region 保存&读取数据
	// abstract
	public function CreateSaveData():ModSaveData
	{
		throw "abstract";
	}
	// abstract
	public function LoadSaveData(json:String):ModSaveData
	{
		throw "abstract";
	}
	public function PostAllSaveDataLoaded():Void {}
	// #endregion

	// #region 定义
	public function AddDefinition(def:Definition):Void
	{
		definitionGroup.Add(def);
		for (trigger in def.GetTriggers())
		{
			triggers.push(trigger);
		}
	}
	public function GetDefinition<T:Definition>(type:String, defRef:Null<NamespaceID>):Null<T>
	{
		// PORT-NOTE: C# 为 definitionGroup.GetDefinition<T>(type, defRef)；Haxe 不支持显式类型参数调用，靠返回类型推断。
		return definitionGroup.GetDefinition(type, defRef);
	}
	public function GetDefinitionsByType<T:Definition>(type:String):Array<T>
	{
		// PORT-NOTE: C# 为 definitionGroup.GetDefinitions<T>(type)（运行期泛型过滤），Haxe 无运行期泛型，
		// 改为按类型对象过滤（PVZEngine.DefinitionGroup.GetDefinitionsOfType）。
		var all:Array<Definition> = definitionGroup.GetDefinitionsOfType(Definition, type);
		return cast all;
	}
	public function GetDefinitions():Array<Definition>
	{
		return definitionGroup.GetDefinitions();
	}
	// #endregion

	// #region 全局回调
	// PORT-NOTE: C# 形参名为 implements，是 Haxe 保留字，改名为 implementer。
	public function ApplyGlobalCallbacks(implementer:IGlobalCallbacks):Void
	{
		implementer.Apply(this);
	}
	// #endregion

	// #region 触发器
	public function AddTrigger<TArgs>(callbackID:CallbackType<TArgs>, action:TArgs->CallbackResult->Void, priority:Int = 0, filter:Dynamic = null):Void
	{
		triggers.push(new Trigger<TArgs>(callbackID, action, priority, filter));
	}
	public function GetTriggers():Array<ITrigger>
	{
		return triggers.copy();
	}
	// #endregion

	// #region 序列化
	// PORT-NOTE: C# protected -> Haxe 无 protected，改为 public。
	// PORT-NOTE: C# 为 SerializeHelper.RegisterClass<T>()；Haxe 不支持显式类型参数调用，改为把类对象作为参数传入。
	public function RegisterSerializableType<T>(type:Class<T>):Void
	{
		SerializeHelper.RegisterClass(type);
	}
	public function Serialize(obj:Dynamic):String
	{
		return SerializeHelper.ToBson(obj);
	}
	public function Deserialize<T>(json:String, type:Class<T>):T
	{
		// PORT-NOTE: C# 为 SerializeHelper.FromBson<T>(json)。泛型函数内无法做编译期分派，
		// 这里走与存档类型一致的运行期 RTTI hydration（TypedJson）——haxe.Json.parse 的匿名
		// 产物（hx::Anon）不能直接当类实例返回，否则 hxcpp 固定偏移字段访问会读到错位数据。
		return cast mvz2logic.serialization.TypedJson.hydrate(haxe.Json.parse(json), Type.getClassName(type));
	}
	// #endregion

	public var Namespace(get, never):String;
	private var _Namespace:String;
	private function get_Namespace():String return _Namespace;
	private var definitionGroup:DefinitionGroup = new DefinitionGroup();
	// PORT-NOTE: C# protected List<ITrigger> triggers -> Haxe private（无 protected）。
	private var triggers:Array<ITrigger> = [];
}

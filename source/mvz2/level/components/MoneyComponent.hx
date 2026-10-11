// Ported from: Assets/Scripts/MVZ2/Level/Components/MoneyComponent.cs
package mvz2.level.components;

import unity.UnityObject;
import mvz2.level.LevelController;
import mvz2logic.Global;
import mvz2logic.level.components.ComponentInterfaces.IMoneyComponent;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
// PORT-NOTE: C# 的扩展方法（this 参数形式）在 Haxe 中需显式 using 才能以 `obj.Method()` 调用。
using mvz2logic.saves.LogicSaveExt;                // GetMoney / SetMoney(this IGlobalSaveData)

class MoneyComponent extends MVZ2Component implements IMoneyComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, componentID, controller);
	}
	public function SetMoney(value:Int):Void
	{
		Global.Saves.SetMoney(value);
	}
	public function AddMoney(value:Int):Void
	{
		SetMoney(GetMoney() + value);
	}
	public function GetMoney():Int
	{
		return Global.Saves.GetMoney();
	}
	public function GetDelayedMoney():Int
	{
		var sum = 0;
		for (v in delayedMoneyEntities)
			sum += v;
		return sum;
	}
	public function AddDelayedMoney(entity:Entity, value:Int):Void
	{
		if (value == 0)
			return;
		var before = GetMoney();
		AddMoney(value);
		var added = GetMoney() - before;
		delayedMoneyEntities.set(entity, added);
	}
	public function RemoveDelayedMoney(entity:Entity):Bool
	{
		return delayedMoneyEntities.remove(entity);
	}
	public function ClearDelayedMoney():Void
	{
		delayedMoneyEntities.clear();
	}
	override public function Update():Void
	{
		super.Update();
		UpdateDelayedEnergyEntities();
	}
	private function UpdateDelayedEnergyEntities():Void
	{
		var entities:Array<Entity> = [];
		for (e in delayedMoneyEntities.keys())
		{
			if (!unity.UnityObject.exists(e))
			{
				entities.push(e);
			}
		}
		for (entity in entities)
		{
			delayedMoneyEntities.remove(entity);
		}
	}
	// 延迟获得的能量
	private var delayedMoneyEntities:Map<Entity, Int> = new Map();
	// PORT-NOTE: C# 的 static readonly 字段是首次使用时才初始化；hxcpp 会在 main() 之前执行全部静态初始化
	// （__boot_all()），那时 Global.Game / MainManager.Instance 仍为 null，直接求值会段错误。
	// 此处改为惰性 getter（结果缓存一次，等价于 C# 的 readonly static），还原 C# 语义。
	public static var componentID(get, never):NamespaceID;
	private static var _componentID:NamespaceID;
	static function get_componentID():NamespaceID
	{
		if (_componentID == null) _componentID = new NamespaceID(Global.BuiltinNamespace, "money");
		return _componentID;
	}
}

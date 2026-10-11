// Ported from: Assets/Scripts/Logic/Saves/BlueprintChooseSaveItem.cs
package mvz2logic.saves;

import mvz2logic.blueprints.BlueprintChooseItem;
import pvzengine.NamespaceID;

// [Serializable]
@:rtti
class BlueprintChooseSaveItem
{
	public var id:NamespaceID;
	public var isCommandBlock:Bool;

	public function new(id:NamespaceID, isCommandBlock:Bool = false)
	{
		this.id = id;
		this.isCommandBlock = isCommandBlock;
	}

	public function Compare(item:BlueprintChooseItem):Bool
	{
		return id == item.id && isCommandBlock == item.isCommandBlock;
	}
	public function Equals(obj:Dynamic):Bool
	{
		if (!Std.isOfType(obj, BlueprintChooseSaveItem))
			return false;
		var item:BlueprintChooseSaveItem = cast obj;
		return this.EqualTo(item);
	}
	public function GetHashCode():Int
	{
		// PORT-NOTE: C# bool.GetHashCode() 在 Haxe 中无对应，用 1/0 等价实现。
		var hashCode = id == null ? 0 : id.GetHashCode();
		hashCode = hashCode * 31 + (isCommandBlock ? 1 : 0);
		return hashCode;
	}
	// PORT-NOTE: C# 的 operator == / != 无法在 Haxe 中重载，改为实例方法 EqualTo。
	public function EqualTo(rhs:Null<BlueprintChooseSaveItem>):Bool
	{
		if (this == null)
		{
			return rhs == null;
		}
		if (rhs == null)
		{
			return false;
		}
		return id == rhs.id && isCommandBlock == rhs.isCommandBlock;
	}
}

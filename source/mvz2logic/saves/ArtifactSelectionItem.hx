// Ported from: Assets/Scripts/Logic/Saves/ArtifactSelectionItem.cs
package mvz2logic.saves;

import pvzengine.NamespaceID;

// [Serializable]
@:rtti
class ArtifactSelectionItem
{
	public var id:NamespaceID;

	public function new(id:NamespaceID)
	{
		this.id = id;
	}

	public function Equals(obj:Dynamic):Bool
	{
		if (!Std.isOfType(obj, ArtifactSelectionItem))
			return false;
		var item:ArtifactSelectionItem = cast obj;
		return this.EqualTo(item);
	}
	public function GetHashCode():Int
	{
		// PORT-NOTE: C# NamespaceID.GetHashCode() 在 Haxe 中无对应，直接沿用其 GetHashCode。
		return id == null ? 0 : id.GetHashCode();
	}
	// PORT-NOTE: C# 的 operator == / != 无法在 Haxe 中重载，改为实例方法 EqualTo。
	public function EqualTo(rhs:Null<ArtifactSelectionItem>):Bool
	{
		if (this == null)
		{
			return rhs == null;
		}
		if (rhs == null)
		{
			return false;
		}
		return id == rhs.id;
	}
}

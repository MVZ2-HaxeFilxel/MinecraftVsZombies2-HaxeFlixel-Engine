// Ported from: Assets/Scripts/Logic/Saves/UserStatEntry.cs
package mvz2logic.saves;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.base.MissingSerializeDataException;

class UserStatEntry
{
	public function new(id:NamespaceID)
	{
		ID = id;
	}
	public function ToSerializable():SerializableUserStatEntry
	{
		var entry = new SerializableUserStatEntry();
		entry.id = ID;
		entry.value = Value;
		return entry;
	}
	public static function FromSerializable(serializable:SerializableUserStatEntry):Null<UserStatEntry>
	{
		if (!NamespaceID.IsValid(serializable.id))
		{
			Log.LogException(MissingSerializeDataException.Property("id"));
			return null;
		}
		var entry = new UserStatEntry(serializable.id);
		entry.Value = serializable.value;
		return entry;
	}
	public var ID(default, null):NamespaceID;
	public var Value:Int64;
}

// [Serializable]
@:rtti
class SerializableUserStatEntry
{
	public function new() {}
	public var id:Null<NamespaceID>;
	public var value:Int64;
}

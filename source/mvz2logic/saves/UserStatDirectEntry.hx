// Ported from: Assets/Scripts/Logic/Saves/UserStatDirectEntry.cs
package mvz2logic.saves;

import haxe.Int64;
import pvzengine.base.MissingSerializeDataException;

class UserStatDirectEntry
{
	public function new(id:String)
	{
		ID = id;
	}
	public function ToSerializable():SerializableUserStatDirectEntry
	{
		var entry = new SerializableUserStatDirectEntry();
		entry.id = ID;
		entry.value = Value;
		return entry;
	}
	public static function FromSerializable(serializable:SerializableUserStatDirectEntry):Null<UserStatDirectEntry>
	{
		if (serializable.id == null || serializable.id.length == 0)
		{
			Log.LogException(MissingSerializeDataException.Property("id"));
			return null;
		}
		var entry = new UserStatDirectEntry(serializable.id);
		entry.Value = serializable.value;
		return entry;
	}
	public var ID(default, null):String;
	public var Value:Int64;
}

// [Serializable]
@:rtti
class SerializableUserStatDirectEntry
{
	public function new() {}
	public var id:Null<String>;
	public var value:Int64;
}

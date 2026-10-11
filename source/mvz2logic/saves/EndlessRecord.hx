// Ported from: Assets/Scripts/Logic/Saves/EndlessRecord.cs
package mvz2logic.saves;

import pvzengine.base.MissingSerializeDataException;

class EndlessRecord
{
	public function new(id:String)
	{
		ID = id;
	}
	public function GetMaxFlags():Int
	{
		return currentFlag;
	}
	public function SetMaxFlags(flags:Int):Void
	{
		currentFlag = flags;
	}
	public function ToSerializable():SerializableEndlessRecord
	{
		var record = new SerializableEndlessRecord();
		record.id = ID;
		record.currentFlag = currentFlag;
		return record;
	}
	public static function FromSerializable(serializable:SerializableEndlessRecord):Null<EndlessRecord>
	{
		if (serializable.id == null || serializable.id.length == 0)
		{
			Log.LogException(MissingSerializeDataException.Property("id"));
			return null;
		}
		var record = new EndlessRecord(serializable.id);
		record.currentFlag = serializable.currentFlag;
		return record;
	}
	public var ID(default, null):String;
	private var currentFlag:Int;
}

// [Serializable]
@:rtti
class SerializableEndlessRecord
{
	public function new() {}
	public var id:Null<String>;
	public var currentFlag:Int;
}

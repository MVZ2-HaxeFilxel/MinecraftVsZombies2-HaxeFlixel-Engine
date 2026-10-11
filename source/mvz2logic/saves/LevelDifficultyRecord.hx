// Ported from: Assets/Scripts/Logic/Saves/LevelDifficultyRecord.cs
package mvz2logic.saves;

import pvzengine.NamespaceID;
import pvzengine.base.MissingSerializeDataException;

class LevelDifficultyRecord
{
	public function new(id:String)
	{
		ID = id;
	}
	public function AddRecord(difficulty:NamespaceID):Void
	{
		difficulties.push(difficulty);
	}
	public function RemoveRecord(difficulty:NamespaceID):Bool
	{
		return difficulties.remove(difficulty);
	}
	public function HasRecord(difficulty:NamespaceID):Bool
	{
		return difficulties.indexOf(difficulty) >= 0;
	}
	public function GetAllRecords():Array<NamespaceID>
	{
		return difficulties.copy();
	}
	public function ToSerializable():SerializableLevelDifficultyRecord
	{
		var record = new SerializableLevelDifficultyRecord();
		record.id = ID;
		record.difficulties = difficulties.copy();
		return record;
	}
	public static function FromSerializable(serializable:SerializableLevelDifficultyRecord):Null<LevelDifficultyRecord>
	{
		if (serializable.id == null || serializable.id.length == 0)
		{
			Log.LogException(MissingSerializeDataException.Property("ID"));
			return null;
		}
		// PORT-NOTE: C# HashSet<NamespaceID> -> Haxe Array<NamespaceID>（保持插入序、去重由 AddRecord 的调用方语义决定）。
		var difficulties:Array<NamespaceID> = [];
		if (serializable.difficulties != null)
		{
			for (diff in serializable.difficulties)
			{
				if (diff == null)
					continue;
				difficulties.push(diff);
			}
		}
		var record = new LevelDifficultyRecord(serializable.id);
		record.difficulties = difficulties;
		return record;
	}
	public var ID(default, null):String;
	private var difficulties:Array<NamespaceID> = [];
}

// [Serializable]
@:rtti
class SerializableLevelDifficultyRecord
{
	public function new() {}
	public var id:Null<String>;
	public var difficulties:Null<Array<Null<NamespaceID>>>;
}

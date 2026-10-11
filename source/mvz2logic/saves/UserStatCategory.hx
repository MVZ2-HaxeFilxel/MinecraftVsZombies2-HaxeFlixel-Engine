// Ported from: Assets/Scripts/Logic/Saves/UserStatCategory.cs
package mvz2logic.saves;

import haxe.Int64;
import mvz2logic.saves.UserStatEntry.SerializableUserStatEntry;
import pvzengine.NamespaceID;
import pvzengine.base.MissingSerializeDataException;

class UserStatCategory
{
	public function new(name:String)
	{
		Name = name;
	}
	public function GetStatValue(id:NamespaceID):Int64
	{
		var entry = GetEntry(id);
		if (entry == null)
			return 0;
		return entry.Value;
	}
	public function SetStatValue(id:NamespaceID, value:Int64):Void
	{
		var entry = GetEntry(id);
		if (entry == null)
			entry = CreateEntry(id);
		entry.Value = value;
	}
	public function HasStat(id:NamespaceID):Bool
	{
		for (e in entries)
		{
			if (e.ID == id)
				return true;
		}
		return false;
	}
	public function GetAllEntries():Array<UserStatEntry>
	{
		return entries.copy();
	}
	public function ToSerializable():SerializableUserStatCategory
	{
		var serializableEntries = [for (e in entries) e.ToSerializable()];
		var category = new SerializableUserStatCategory();
		category.name = Name;
		category.entries = serializableEntries;
		return category;
	}
	public static function FromSerializable(serializable:SerializableUserStatCategory):Null<UserStatCategory>
	{
		if (serializable.name == null || serializable.name.length == 0)
		{
			Log.LogException(MissingSerializeDataException.Property("Name"));
			return null;
		}
		var stats = new UserStatCategory(serializable.name);
		if (serializable.entries != null)
		{
			for (seriEntry in serializable.entries)
			{
				if (seriEntry == null)
					continue;
				var entry = UserStatEntry.FromSerializable(seriEntry);
				if (entry != null)
				{
					stats.entries.push(entry);
				}
			}
		}
		return stats;
	}
	private function GetAllEntriesID():Array<NamespaceID>
	{
		return [for (e in entries) e.ID];
	}
	private function GetEntry(id:NamespaceID):Null<UserStatEntry>
	{
		for (e in entries)
		{
			if (e.ID == id)
				return e;
		}
		return null;
	}
	private function CreateEntry(id:NamespaceID):UserStatEntry
	{
		var entry = new UserStatEntry(id);
		entries.push(entry);
		return entry;
	}
	public var Name(default, null):String;
	private var entries:Array<UserStatEntry> = [];
}

// [Serializable]
@:rtti
class SerializableUserStatCategory
{
	public function new() {}
	public var name:Null<String>;
	public var entries:Null<Array<Null<SerializableUserStatEntry>>>;
}

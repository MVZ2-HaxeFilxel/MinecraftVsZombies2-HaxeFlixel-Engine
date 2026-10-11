// Ported from: Assets/Scripts/Logic/Saves/UserStats.cs
package mvz2logic.saves;

import haxe.Int64;
import mvz2logic.saves.UserStatCategory.SerializableUserStatCategory;
import mvz2logic.saves.UserStatDirectEntry.SerializableUserStatDirectEntry;
import mvz2logic.saves.UserStatEntry.SerializableUserStatEntry;
import pvzengine.NamespaceID;
import mongodb.bson.serialization.attributes.BsonIgnoreExtraElementsAttribute;

class UserStats
{
	public function new() {}
	public function GetStatValue(category:String, entry:NamespaceID):Int64
	{
		var cate = GetCategory(category);
		if (cate == null)
			return 0;
		return cate.GetStatValue(entry);
	}
	public function SetStatValue(category:String, entry:NamespaceID, value:Int64):Void
	{
		var cate = GetCategory(category);
		if (cate == null)
			cate = CreateCategory(category);
		cate.SetStatValue(entry, value);
	}
	public function GetDirectEntryValue(entryID:String):Int64
	{
		var entry = GetDirectEntry(entryID);
		if (entry == null)
			return 0;
		return entry.Value;
	}
	public function SetDirectEntryValue(entryID:String, value:Int64):Void
	{
		var entry = GetDirectEntry(entryID);
		if (entry == null)
			entry = CreateDirectEntry(entryID);
		entry.Value = value;
	}

	// #region Category
	public function HasCategory(name:String):Bool
	{
		for (e in categories)
		{
			if (e.Name == name)
				return true;
		}
		return false;
	}
	public function GetAllCategories():Array<UserStatCategory>
	{
		return categories.copy();
	}
	private function GetAllCategoryNames():Array<String>
	{
		return [for (e in categories) e.Name];
	}
	private function GetCategory(name:String):Null<UserStatCategory>
	{
		for (e in categories)
		{
			if (e.Name == name)
				return e;
		}
		return null;
	}
	private function CreateCategory(name:String):UserStatCategory
	{
		var entry = new UserStatCategory(name);
		categories.push(entry);
		return entry;
	}
	// #endregion

	// #region Direct Entry
	public function HasDirectEntry(id:String):Bool
	{
		for (e in entries)
		{
			if (e.ID == id)
				return true;
		}
		return false;
	}
	public function GetAllDirectEntries():Array<UserStatDirectEntry>
	{
		return entries.copy();
	}
	private function GetAllDirectEntriesID():Array<String>
	{
		return [for (e in entries) e.ID];
	}
	private function GetDirectEntry(id:String):Null<UserStatDirectEntry>
	{
		for (e in entries)
		{
			if (e.ID == id)
				return e;
		}
		return null;
	}
	private function CreateDirectEntry(name:String):UserStatDirectEntry
	{
		var entry = new UserStatDirectEntry(name);
		entries.push(entry);
		return entry;
	}
	// #endregion

	// #region Serialization
	public function ToSerializable():SerializableUserStats
	{
		var stats = new SerializableUserStats();
		stats.categories = [for (e in categories) e.ToSerializable()];
		stats.directEntries = [for (e in entries) e.ToSerializable()];
		stats.playTimeMilliseconds = PlayTimeMilliseconds;
		return stats;
	}
	public static function FromSerializable(serializable:SerializableUserStats):UserStats
	{
		var stats = new UserStats();

		// Categories.
		if (serializable.categories != null)
		{
			for (seriCategory in serializable.categories)
			{
				if (seriCategory == null)
					continue;
				var category = UserStatCategory.FromSerializable(seriCategory);
				if (category == null)
					continue;
				stats.categories.push(category);
			}
		}

		// Direct Entries.
		if (serializable.directEntries != null)
		{
			for (seriEntry in serializable.directEntries)
			{
				if (seriEntry == null)
					continue;
				var entry = UserStatDirectEntry.FromSerializable(seriEntry);
				if (entry == null)
					continue;
				stats.entries.push(entry);
			}
		}

		// Play Time.
		stats.PlayTimeMilliseconds = serializable.playTimeMilliseconds;

		return stats;
	}
	// #endregion

	private var categories:Array<UserStatCategory> = [];
	private var entries:Array<UserStatDirectEntry> = [];
	public var PlayTimeMilliseconds:Int64;
}

// [Serializable]
// [BsonIgnoreExtraElements]
@:rtti
class SerializableUserStats
{
	public function new() {}
	public var categories:Null<Array<Null<SerializableUserStatCategory>>>;
	public var directEntries:Null<Array<Null<SerializableUserStatDirectEntry>>>;
	public var playTimeMilliseconds:Int64;
	// [Obsolete]
	// [BsonIgnoreIfNull]
	public var entries:Null<Array<Null<SerializableUserStatEntry>>>;
}

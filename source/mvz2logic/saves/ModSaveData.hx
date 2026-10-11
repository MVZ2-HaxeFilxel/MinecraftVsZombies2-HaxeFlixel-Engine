// Ported from: Assets/Scripts/Logic/Saves/ModSaveData.cs
package mvz2logic.saves;

import haxe.Int64;
import mvz2logic.saves.EndlessRecord.SerializableEndlessRecord;
import mvz2logic.saves.LevelDifficultyRecord.SerializableLevelDifficultyRecord;
import mvz2logic.saves.UserStats.SerializableUserStats;
import pvzengine.NamespaceID;

// abstract
class ModSaveData
{
	public function new(spaceName:String)
	{
		_Namespace = spaceName;
	}
	// #region 解锁
	public function Unlock(unlockID:String):Void
	{
		unlocks.push(unlockID);
	}
	public function Relock(unlockID:String):Void
	{
		unlocks.remove(unlockID);
	}
	public function IsUnlocked(unlockID:String):Bool
	{
		return unlocks.indexOf(unlockID) >= 0;
	}
	public function GetUnlocks():Array<String>
	{
		return unlocks.copy();
	}
	// #endregion

	// #region 关卡难度记录
	public function AddLevelDifficultyRecord(levelID:String, difficulty:NamespaceID):Void
	{
		var record = GetLevelDifficultyRecord(levelID);
		if (record == null)
		{
			record = CreateLevelDifficultyRecord(levelID);
		}
		record.AddRecord(difficulty);
	}
	public function RemoveLevelDifficultyRecord(levelID:String, difficulty:NamespaceID):Bool
	{
		var record = GetLevelDifficultyRecord(levelID);
		if (record == null)
		{
			return false;
		}
		return record.RemoveRecord(difficulty);
	}
	public function HasLevelDifficultyRecord(levelID:String, difficulty:NamespaceID):Bool
	{
		var record = GetLevelDifficultyRecord(levelID);
		if (record == null)
			return false;
		return record.HasRecord(difficulty);
	}
	public function GetLevelDifficultyRecords(levelID:String):Array<NamespaceID>
	{
		var record = GetLevelDifficultyRecord(levelID);
		if (record == null)
			return [];
		return record.GetAllRecords();
	}
	private function CreateLevelDifficultyRecord(levelID:String):LevelDifficultyRecord
	{
		var record = new LevelDifficultyRecord(levelID);
		levelDifficultyRecords.push(record);
		return record;
	}
	private function GetLevelDifficultyRecord(levelID:String):Null<LevelDifficultyRecord>
	{
		for (r in levelDifficultyRecords)
		{
			if (r.ID == levelID)
				return r;
		}
		return null;
	}
	// #endregion

	// #region 无尽
	public function SetCurrentEndlessFlag(stageID:String, value:Int):Void
	{
		var record:Null<EndlessRecord> = null;
		for (e in endlessRecords)
		{
			if (e.ID == stageID)
			{
				record = e;
				break;
			}
		}
		if (record == null)
		{
			record = new EndlessRecord(stageID);
			endlessRecords.push(record);
		}
		record.SetMaxFlags(value);
	}
	public function GetCurrentEndlessFlag(stageID:String):Int
	{
		var record:Null<EndlessRecord> = null;
		for (e in endlessRecords)
		{
			if (e.ID == stageID)
			{
				record = e;
				break;
			}
		}
		if (record == null)
		{
			return 0;
		}
		return record.GetMaxFlags();
	}
	// #endregion

	// #region 统计
	public function SetStat(category:String, entry:NamespaceID, value:Int64):Void
	{
		stats.SetStatValue(category, entry, value);
	}
	public function GetStat(category:String, entry:NamespaceID):Int64
	{
		return stats.GetStatValue(category, entry);
	}
	public function SetDirectEntryStat(entry:String, value:Int64):Void
	{
		stats.SetDirectEntryValue(entry, value);
	}
	public function GetDirectEntryStat(entry:String):Int64
	{
		return stats.GetDirectEntryValue(entry);
	}
	public function AddPlayTimeMilliseconds(time:Int64):Void
	{
		stats.PlayTimeMilliseconds += time;
	}
	public function GetPlayTimeMilliseconds():Int64
	{
		return stats.PlayTimeMilliseconds;
	}
	public function GetAllStats():UserStats return stats;
	// #endregion

	public function ToSerializable():SerializableModSaveData
	{
		var serializable = CreateSerializable();
		serializable.spaceName = Namespace;
		serializable.stats = stats.ToSerializable();
		serializable.endlessRecords = [for (r in endlessRecords) r.ToSerializable()];
		serializable.levelDifficultyRecords = [for (r in levelDifficultyRecords) r.ToSerializable()];
		serializable.unlocks = unlocks.copy();
		return serializable;
	}
	// PORT-NOTE: C# protected abstract -> Haxe 无 protected，改为 public 并在基类抛错（abstract 语义见注释）。
	public function CreateSerializable():SerializableModSaveData
	{
		throw "abstract";
	}
	// PORT-NOTE: C# protected -> Haxe 无 protected，改为 public。
	public function LoadFromSerializable(serializable:SerializableModSaveData):Void
	{
		stats = serializable.stats != null ? UserStats.FromSerializable(serializable.stats) : stats;
		endlessRecords = [];
		if (serializable.endlessRecords != null)
		{
			for (seriRecord in serializable.endlessRecords)
			{
				var record = EndlessRecord.FromSerializable(seriRecord);
				if (record != null)
					endlessRecords.push(record);
			}
		}
		levelDifficultyRecords = [];
		if (serializable.levelDifficultyRecords != null)
		{
			for (seriRecord in serializable.levelDifficultyRecords)
			{
				var record = LevelDifficultyRecord.FromSerializable(seriRecord);
				if (record != null)
					levelDifficultyRecords.push(record);
			}
		}
		// PORT-NOTE: C# HashSet<string>.ToHashSet() -> Haxe Array<String> 去重。
		unlocks = [];
		for (u in serializable.unlocks)
		{
			if (unlocks.indexOf(u) < 0)
				unlocks.push(u);
		}
	}
	public var Namespace(get, never):String;
	private function get_Namespace():String return _Namespace;
	private var _Namespace:String;
	// PORT-NOTE: C# protected 字段 -> Haxe public。
	public var stats:UserStats = new UserStats();
	public var levelDifficultyRecords:Array<LevelDifficultyRecord> = [];
	public var endlessRecords:Array<EndlessRecord> = [];
	public var unlocks:Array<String> = [];
}

// abstract
@:rtti
class SerializableModSaveData
{
	public function new() {}
	public var version:Int;
	public var spaceName:Null<String>;
	public var stats:Null<SerializableUserStats>;
	public var endlessRecords:Null<Array<SerializableEndlessRecord>>;
	public var levelDifficultyRecords:Null<Array<SerializableLevelDifficultyRecord>>;
	public var unlocks:Null<Array<String>>;
	// [Obsolete]
	public var mapPresetConfigs:Null<Array<Dynamic>>;
}

// Ported from: Assets/Scripts/Logic/Saves/LogicSaveData.cs
package mvz2logic.saves;

import mvz2logic.saves.ModSaveData.SerializableModSaveData;
import pvzengine.NamespaceID;
import mvz2logic.saves.BlueprintSelection;

// [Serializable]
@:rtti
class SerializableLogicSaveData extends SerializableModSaveData
{
	public function new() { super(); }
	public var lastMapID:Null<NamespaceID>;
	public var mapTalkID:Null<NamespaceID>;
	public var money:Int;
	public var lastSelection:Null<BlueprintSelection>;
	// [Obsolete]
	public var artifactSlots:Int;
	// [Obsolete]
	public var blueprintSlots:Int;
	// [Obsolete]
	public var starshardSlots:Int;
}

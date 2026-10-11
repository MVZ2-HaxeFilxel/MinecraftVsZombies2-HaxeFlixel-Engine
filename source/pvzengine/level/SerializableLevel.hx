// Ported from: Assets/Scripts/Engine/Level/Level/SerializableLevel.cs
package pvzengine.level;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.buffs.SerializableBuffList;
import pvzengine.collisions.level.ISerializableCollisionSystem;
import pvzengine.entities.SerializableEntity;
import pvzengine.grids.SerializableGrid;
// PORT-NOTE: SerializablePropertyBlock 与 PropertyBlock 同处模块 pvzengine.level.PropertyBlock，
// 跨模块引用须按 `模块.子类型` 形式 import。
import pvzengine.level.PropertyBlock.SerializablePropertyBlock;
// PORT-NOTE: SerializableClassicSeedPack / SerializableConveyorSeedPack 是模块
// pvzengine.seedpacks.SerializableSeedPack 的子类型，跨模块引用须按 `模块.子类型` 形式 import。
import pvzengine.seedpacks.SerializableSeedPack.SerializableClassicSeedPack;
import pvzengine.seedpacks.SerializableSeedPack.SerializableConveyorSeedPack;
import tools.SerializableRNG;

@:rtti
class SerializableLevel
{
	private var isRerun:Bool;

	private var gridSize:Float;
	private var gridLeftX:Float;
	private var gridBottomZ:Float;
	private var maxLaneCount:Int;
	private var maxColumnCount:Int;


	public var seed:Int;
	public var levelTime:Int64;
	public var isCleared:Bool;
	public var stageDefinitionID:Null<NamespaceID>;
	public var areaDefinitionID:Null<NamespaceID>;
	public var difficulty:Null<NamespaceID>;
	public var Option:Null<SerializableLevelOption>;
	public var levelRandom:Null<SerializableRNG>;
	public var entityRandom:Null<SerializableRNG>;
	public var effectRandom:Null<SerializableRNG>;
	public var roundRandom:Null<SerializableRNG>;
	public var spawnRandom:Null<SerializableRNG>;
	public var conveyorRandom:Null<SerializableRNG>;
	public var debugRandom:Null<SerializableRNG>;
	public var miscRandom:Null<SerializableRNG>;

	public var properties:Null<SerializablePropertyBlock>;

	public var grids:Array<SerializableGrid>;
	public var seedPacks:Array<Null<SerializableClassicSeedPack>>;
	public var conveyorSeedPacks:Array<SerializableConveyorSeedPack>;
	public var requireCards:Bool;
	public var currentEntityID:Int64 = 1;
	// C#: [Obsolete] public long currentBuffID;
	// PORT-NOTE: [Obsolete] 特性无运行期语义，仅保留注释。
	public var currentBuffID:Int64;
	public var currentSeedPackID:Int64;
	public var conveyorSlotCount:Int;
	public var conveyorSeedSpendRecord:Null<SerializableConveyorSeedSpendRecords>;
	public var entities:Array<SerializableEntity>;
	public var entityTrash:Array<SerializableEntity>;
	public var energy:Float;
	public var delayedEnergyEntities:Array<SerializableDelayedEnergy>;
	public var currentWave:Int;
	public var currentFlag:Int;
	public var waveState:Int;
	public var levelProgressVisible:Bool;
	public var spawnedLanes:Array<Int>;
	public var spawnedID:Array<NamespaceID>;
	public var collisionSystem:Null<ISerializableCollisionSystem>;

	public var buffs:Null<SerializableBuffList>;

	public var components:Map<String, ISerializableLevelComponent>;

	public function new() {}
}

@:rtti
class SerializableDelayedEnergy
{
	public var entityId:Int64;
	public var energy:Float;

	public function new() {}
}

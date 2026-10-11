// Ported from: Assets/Scripts/MVZ2/Level/LevelController/SerializableLevelController.cs
package mvz2.level;

import mvz2.entities.EntityController.SerializableEntityController;
import mvz2.grids.GridController.SerializableGridController;
import mvz2.models.AreaModel.SerializableAreaModelData;
import mvz2.models.Model.SerializableModelData;
import mvz2.ui.level.LevelUIPreset.SerializableLevelUIPreset;
import pvzengine.NamespaceID;
import pvzengine.level.SerializableLevel;
import tools.FrameTimer;
import tools.SerializableRNG;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.LevelControllerPart.SerializableLevelControllerPart;
import mvz2.entities.EntityController;
import mvz2.grids.GridController;
import mvz2.models.AreaModel;
import mvz2.models.Model;
import mvz2.ui.level.LevelUIPreset;

// PORT-NOTE: C# 的 [BsonIgnoreExtraElements] 特性在 Haxe 中无对应语义，保留为元数据。
@:bsonIgnoreExtraElements
@:rtti
class SerializableLevelController
{
	public var rng:SerializableRNG;

	public var levelProgress:Float;
	public var bannerProgresses:Array<Float>;
	public var bossHealth:Float;
	public var bossMaxHealth:Float;
	public var bossProgressBarStyle:NamespaceID;
	public var progressBarMode:Bool;

	public var musicID:NamespaceID;
	public var musicTime:Float;
	public var musicVolume:Float;
	public var musicTrackWeight:Float;

	public var energyActive:Bool;
	public var blueprintsActive:Bool;
	public var pickaxeActive:Bool;
	public var starshardActive:Bool;
	public var triggerActive:Bool;

	public var parts:Array<SerializableLevelControllerPart>;

	public var maxCryTime:Int;
	public var cryTimer:FrameTimer;
	public var twinkleTime:Float;

	public var entities:Array<SerializableEntityController>;
	public var model:SerializableModelData;
	// PORT-NOTE: 原字段标记了 [Obsolete]。
	public var areaModel:SerializableAreaModelData;

	public var level:SerializableLevel;

	public var uiPreset:SerializableLevelUIPreset;

	public var grids:Array<SerializableGridController>;
	public function new() {}
}

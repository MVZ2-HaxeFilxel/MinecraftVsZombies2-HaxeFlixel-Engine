// Ported from: Assets/Scripts/MVZ2/Level/ControllerPart/LevelBlueprintController.cs
package mvz2.level;

import mvz2.ui.Blueprint;
import pvzengine.NamespaceID;
import pvzengine.level.LevelEngine;
import unity.*;
import unity.Debug;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.BlueprintController.SerializableBlueprintController;
import mvz2.level.LevelControllerPart.SerializableLevelControllerPart;

class LevelBlueprintController extends LevelControllerPart
{
	// #region 热键
	public function ForceUpdateBlueprintHotkeyTexts():Void
	{
		for (blueprint in classicBlueprints)
		{
			if (blueprint == null)
				continue;
			blueprint.ForceUpdateBlueprintHotkeyText();
		}
		for (blueprint in conveyorBlueprints)
		{
			if (blueprint == null)
				continue;
			blueprint.ForceUpdateBlueprintHotkeyText();
		}
	}
	// #endregion

	// #region 引擎层
	override public function AddEngineCallbacks(level:LevelEngine):Void
	{
		super.AddEngineCallbacks(level);

		level.OnSeedAdded.add(Engine_OnSeedAddedCallback);
		level.OnSeedRemoved.add(Engine_OnSeedRemovedCallback);
		level.OnSeedSlotCountChanged.add(Engine_OnSeedPackCountChangedCallback);

		level.OnConveyorSeedAdded.add(Engine_OnConveyorSeedPackAddedCallback);
		level.OnConveyorSeedRemoved.add(Engine_OnConveyorSeedPackRemovedCallback);
		level.OnConveyorSeedSlotCountChanged.add(Engine_OnConveyorSeedPackCountChangedCallback);
	}
	override public function RemoveEngineCallbacks(level:LevelEngine):Void
	{
		super.RemoveEngineCallbacks(level);

		level.OnSeedAdded.remove(Engine_OnSeedAddedCallback);
		level.OnSeedRemoved.remove(Engine_OnSeedRemovedCallback);
		level.OnSeedSlotCountChanged.remove(Engine_OnSeedPackCountChangedCallback);

		level.OnConveyorSeedAdded.remove(Engine_OnConveyorSeedPackAddedCallback);
		level.OnConveyorSeedRemoved.remove(Engine_OnConveyorSeedPackRemovedCallback);
		level.OnConveyorSeedSlotCountChanged.remove(Engine_OnConveyorSeedPackCountChangedCallback);
	}

	// #region 事件回调
	private function Engine_OnSeedAddedCallback(index:Int):Void
	{
		CreateClassicSeedController(index);
	}
	private function Engine_OnSeedRemovedCallback(index:Int):Void
	{
		DestroyClassicSeedController(index);
	}
	private function Engine_OnSeedPackCountChangedCallback(count:Int):Void
	{
		UpdateUIClassicBlueprintCount();
	}
	private function Engine_OnConveyorSeedPackAddedCallback(index:Int):Void
	{
		CreateConveyorSeedController(index);
	}
	private function Engine_OnConveyorSeedPackRemovedCallback(index:Int):Void
	{
		DestroyConveyorSeedController(index);
	}
	private function Engine_OnConveyorSeedPackCountChangedCallback(count:Int):Void
	{
		UpdateUIConveyorBlueprintCount();
	}
	// #endregion

	// #endregion

	// #region 经典模式控制器
	public function GetClassicBlueprintController(index:Int):ClassicBlueprintController
	{
		if (index < 0 || index >= classicBlueprints.length)
			return null;
		return classicBlueprints[index];
	}
	private function CreateClassicSeedController(index:Int):ClassicBlueprintController
	{
		var seed = Level.GetSeedPackAt(index);
		if (seed == null)
			return null;

		var classicBlueprint = UI.Blueprints.CreateClassicBlueprint();
		UI.Blueprints.InsertClassicBlueprint(index, classicBlueprint);
		UI.Blueprints.ForceAlignBlueprint(index);

		var controller = classicBlueprint.GetComponent(ClassicBlueprintController);
		controller.Init(Controller, classicBlueprint, index, seed);
		classicBlueprints[index] = controller;
		return controller;
	}
	private function DestroyClassicSeedController(index:Int):Void
	{
		var controller = GetClassicBlueprintController(index);
		if (controller == null)
			return;
		controller.Unload();
		UI.Blueprints.DestroyClassicBlueprintAt(index);
		classicBlueprints[index] = null;
	}
	// #endregion

	// #region 传送带模式控制器
	public function GetConveyorBlueprintController(index:Int):ConveyorBlueprintController
	{
		if (index < 0 || index >= conveyorBlueprints.length)
			return null;
		return conveyorBlueprints[index];
	}
	private function CreateConveyorSeedController(index:Int):ConveyorBlueprintController
	{
		var seed = Level.GetConveyorSeedPackAt(index);
		if (seed == null)
			return null;

		var conveyorBlueprint = UI.Blueprints.ConveyBlueprint();
		UI.Blueprints.InsertConveyorBlueprint(index, conveyorBlueprint);

		var i = index;
		while (i < conveyorBlueprints.length)
		{
			conveyorBlueprints[i].Index++;
			i++;
		}
		var controller = conveyorBlueprint.GetComponent(ConveyorBlueprintController);
		controller.Init(Controller, conveyorBlueprint, index, seed);
		conveyorBlueprints.insert(index, controller);
		return controller;
	}
	private function DestroyConveyorSeedController(index:Int):Void
	{
		var controller = GetConveyorBlueprintController(index);
		if (controller == null)
			return;
		controller.Unload();
		UI.Blueprints.DestroyConveyorBlueprintAt(index);
		conveyorBlueprints.splice(index, 1);
		var i = index;
		while (i < conveyorBlueprints.length)
		{
			conveyorBlueprints[i].Index--;
			i++;
		}
	}
	// #endregion
	public function GetCurrentBlueprintControllerByIndex(index:Int):BlueprintController
	{
		if (Level.IsConveyorMode())
		{
			return GetConveyorBlueprintController(index);
		}
		else
		{
			return GetClassicBlueprintController(index);
		}
	}

	// #region 更新
	override public function UpdateLogic():Void
	{
		super.UpdateLogic();
		for (blueprint in classicBlueprints)
		{
			if (blueprint == null)
				continue;
			blueprint.UpdateFixed();
		}
		for (blueprint in conveyorBlueprints)
		{
			if (blueprint == null)
				continue;
			blueprint.UpdateFixed();
		}
	}
	override public function UpdateFrame(deltaTime:Float, simulationSpeed:Float):Void
	{
		super.UpdateFrame(deltaTime, simulationSpeed);
		for (blueprint in classicBlueprints)
		{
			if (blueprint == null)
				continue;
			blueprint.UpdateFrame(deltaTime * simulationSpeed);
		}
		for (blueprint in conveyorBlueprints)
		{
			if (blueprint == null)
				continue;
			blueprint.UpdateFrame(deltaTime * simulationSpeed);
		}
	}
	// #endregion

	// #region 序列化
	override public function GetSerializable():SerializableLevelControllerPart
	{
		var classicBlueprints = [for (b in this.classicBlueprints) b == null ? null : b.ToSerializable()];
		var conveyorBlueprints = [for (b in this.conveyorBlueprints) b.ToSerializable()];
		var seri = new SerializableLevelBlueprintController();
		seri.id = ID;
		seri.classicBlueprints = classicBlueprints;
		seri.conveyorBlueprints = conveyorBlueprints;
		return seri;
	}
	override public function LoadFromSerializable(seri:SerializableLevelControllerPart):Void
	{
		if (!Std.isOfType(seri, SerializableLevelBlueprintController))
			return;
		var serializable:SerializableLevelBlueprintController = cast seri;
		UpdateUIClassicBlueprintCount();
		var seedPacks = Level.GetAllSeedPacks();
		classicBlueprints = [];
		classicBlueprints.resize(seedPacks.length);
		if (serializable.classicBlueprints != null)
		{
			for (i in 0...seedPacks.length)
			{
				var controller = CreateClassicSeedController(i);
				if (controller == null)
					continue;
				var seriSeed = serializable.classicBlueprints[i];
				if (seriSeed == null)
					throw 'Could not find classic blueprint data at index $i in the level state data.';
				controller.LoadFromSerializable(seriSeed);
				controller.UpdateFrame(0);
			}
		}
		UpdateUIConveyorBlueprintCount();
		var conveyorSeedPacks = Level.GetAllConveyorSeedPacks();
		if (serializable.conveyorBlueprints != null)
		{
			for (i in 0...conveyorSeedPacks.length)
			{
				var controller = CreateConveyorSeedController(i);
				if (controller == null)
					continue;
				var seriSeed = serializable.conveyorBlueprints[i];
				if (seriSeed == null)
					throw 'Could not find conveyor blueprint data at index $i in the level state data.';
				controller.LoadFromSerializable(seriSeed);
				controller.UpdateFrame(0);
			}
		}
	}
	// #endregion

	// #region 传送带
	public function SetUIConveyorMode(mode:Bool):Void
	{
		UI.Blueprints.SetConveyorMode(mode);
		UpdateUIClassicBlueprintCount();
		UpdateUIConveyorBlueprintCount();
	}
	public function GetConveyorSpeed():Float
	{
		return conveyorSpeed;
	}
	// #endregion

	// #region UI层

	// #region 经典模式
	private function UpdateUIClassicBlueprintCount():Void
	{
		var count = Level.GetSeedSlotCount();
		classicBlueprints.resize(count);
		UI.Blueprints.SetClassicBlueprintSlotCount(count);
	}
	public function DestroyClassicBlueprintAt(index:Int):Void
	{
		UI.Blueprints.DestroyClassicBlueprintAt(index);
	}
	// #endregion

	// #region 传送带模式
	public function DestroyConveyorBlueprintAt(index:Int):Void
	{
		UI.Blueprints.DestroyConveyorBlueprintAt(index);
	}
	public function SetConveyorBlueprintUIPosition(index:Int, position:Float):Void
	{
		UI.Blueprints.SetConveyorBlueprintNormalizedPosition(index, position);
	}
	private function UpdateUIConveyorBlueprintCount():Void
	{
		UI.Blueprints.SetConveyorBlueprintSlotCount(Level.GetConveyorSlotCount());
	}
	// #endregion

	// #endregion

	@:serializeField
	private var conveyorSpeed:Float = 1;
	private var classicBlueprints:Array<ClassicBlueprintController> = [];
	private var conveyorBlueprints:Array<ConveyorBlueprintController> = [];
}

@:rtti
class SerializableLevelBlueprintController extends SerializableLevelControllerPart
{
	public var classicBlueprints:Array<SerializableBlueprintController>;
	public var conveyorBlueprints:Array<SerializableBlueprintController>;
	public function new()
	{
		super();
	}
}

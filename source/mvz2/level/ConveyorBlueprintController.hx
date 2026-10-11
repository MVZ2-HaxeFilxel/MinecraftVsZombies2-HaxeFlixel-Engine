// Ported from: Assets/Scripts/MVZ2/Level/Blueprints/ConveyorBlueprintController.cs
package mvz2.level;

import mvz2.ui.Blueprint;
import mvz2.ui.Blueprint.BlueprintViewData;
// PORT-NOTE: 原 import 写作 mvz2logic.blueprints.LogicBlueprintExt（该类型不存在且未被使用），故删除。
import pvzengine.seedpacks.SeedPack;
import unity.Mathf;
import unity.Debug;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.BlueprintController.SerializableBlueprintController;
import mvz2.managers.ResourceManager;
import Main;

class ConveyorBlueprintController extends RuntimeBlueprintController
{
	// #region 初始化
	override public function Init(controller:ILevelController, ui:Blueprint, index:Int, seedPack:SeedPack):Void
	{
		super.Init(controller, ui, index, seedPack);
		Position = controller.GetEngine().GetConveyorSlotCount();
	}
	// #endregion

	// #region 生命周期
	override public function UpdateFixed():Void
	{
		super.UpdateFixed();
		var index = Index;
		Position -= Controller.BlueprintController.GetConveyorSpeed() / 45.0;
		var minPosition:Float = 0;
		if (index > 0)
		{
			var prevSeed = Controller.BlueprintController.GetConveyorBlueprintController(index - 1);
			if (prevSeed != null)
			{
				minPosition = prevSeed.Position + 1;
			}
		}
		Position = Mathf.Max(Position, minPosition);
	}
	override public function UpdateFrame(deltaTime:Float):Void
	{
		super.UpdateFrame(deltaTime);

		ui.SetRecharge(0);
		ui.SetDisabled(false);
		ui.SetTwinkleAlpha(ShouldBlueprintTwinkle(SeedPack) ? Controller.GetTwinkleAlpha() : 0);
		ui.SetSelected(Level.IsHoldingConveyorBlueprint(Index));

		Controller.BlueprintController.SetConveyorBlueprintUIPosition(Index, Position);
	}
	// #endregion

	// #region UI
	override public function GetBlueprintViewData():BlueprintViewData
	{
		var viewData = Main.ResourceManager.GetBlueprintViewData(SeedPack);
		viewData.cost = "";
		return viewData;
	}
	// #endregion
	override public function IsInConveyor():Bool
	{
		return true;
	}

	// #region 序列化
	override public function CreateSerializable():SerializableBlueprintController
	{
		var seri = new SerializableConveyorBlueprintController();
		seri.position = Position;
		return seri;
	}
	override public function LoadSerializable(serializable:SerializableBlueprintController):Void
	{
		if (!Std.isOfType(serializable, SerializableConveyorBlueprintController))
			return;
		var conveyor:SerializableConveyorBlueprintController = cast serializable;
		Position = conveyor.position;
	}
	// #endregion
	public var Position(default, set):Float;
	function set_Position(v:Float):Float return Position = v;
}

@:rtti
class SerializableConveyorBlueprintController extends SerializableBlueprintController
{
	public var position:Float;
	public function new()
	{
		super();
	}
}

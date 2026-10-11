// Ported from: Assets/Scripts/MVZ2/Level/Blueprints/ClassicBlueprintController.cs
package mvz2.level;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.BlueprintController.SerializableBlueprintController;
import pvzengine.SeedPack;

// PORT-NOTE: 原 import 写作 mvz2logic.blueprints.LogicBlueprintExt，但该类型从未被移植/使用
// （C# 侧对应文件是 LogicSeedExt/LogicBlueprintStyles 等），本文件并不引用它，故删除。

class ClassicBlueprintController extends RuntimeBlueprintController
{
	// #region 生命周期
	override public function UpdateFixed():Void
	{
		super.UpdateFixed();
		var maxRecharge = SeedPack.GetMaxRecharge();
		var recharge = SeedPack.GetRecharge();
		var recharged = recharge >= maxRecharge;
		if (recharged != CurrentRecharged)
		{
			CurrentRecharged = recharged;
			if (recharged)
			{
				ui.RechargeFlash();
			}
		}
	}
	override public function UpdateFrame(deltaTime:Float):Void
	{
		super.UpdateFrame(deltaTime);

		var maxRecharge = SeedPack.GetMaxRecharge();
		var recharge = SeedPack.GetRecharge();
		ui.SetRecharge(maxRecharge == 0 ? 0 : 1 - recharge / maxRecharge);
		ui.SetDisabled(!CanPick());
		ui.SetTwinkleAlpha(ShouldBlueprintTwinkle(SeedPack) ? Controller.GetTwinkleAlpha() : 0);
		ui.SetSelected(Level.IsHoldingClassicBlueprint(Index));
		ui.UpdateAnimation(deltaTime);
	}
	override function OnDeactive():Void
	{
		CurrentRecharged = false;
	}
	// #endregion
	override public function IsInConveyor():Bool
	{
		return false;
	}

	// #region 序列化
	override public function CreateSerializable():SerializableBlueprintController
	{
		var seri = new SerializableClassicBlueprintController();
		seri.recharged = CurrentRecharged;
		return seri;
	}
	override public function LoadSerializable(serializable:SerializableBlueprintController):Void
	{
		if (!Std.isOfType(serializable, SerializableClassicBlueprintController))
			return;
		var seri:SerializableClassicBlueprintController = cast serializable;
		CurrentRecharged = seri.recharged;
	}
	// #endregion

	public var CurrentRecharged(default, null):Bool;
}

@:rtti
class SerializableClassicBlueprintController extends SerializableBlueprintController
{
	public var recharged:Bool;
	public function new()
	{
		super();
	}
}

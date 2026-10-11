// Ported from: Assets/Scripts/MVZ2/Level/Components/UIComponent.cs
package mvz2.level.components;

import haxe.Int64;
import mvz2.level.LevelController;
import mvz2logic.Global;
import mvz2logic.level.components.ComponentInterfaces.IUIComponent;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.level.ISerializableLevelComponent;
import pvzengine.level.LevelEngine;
import unity.Vector2;
import unity.Vector3;
import unity.Debug;
import mvz2.cameras.ShakeManager;
import unity.scenemanagement.SceneInstance.Scene;
import pvzengine.callbacks.Trigger;
import unity.scenemanagement.SceneInstance;
import Main;

class UIComponent extends MVZ2Component implements IUIComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, componentID, controller);
	}
	public function ScreenToLawnPositionByZ(screenPosition:Vector2, z:Float):Vector3
	{
		return Controller.ScreenToLawnPositionByZ(screenPosition, z);
	}
	public function ScreenToLawnPositionByY(screenPosition:Vector2, y:Float):Vector3
	{
		return Controller.ScreenToLawnPositionByY(screenPosition, y);
	}
	public function ScreenToLawnPositionByRelativeY(screenPosition:Vector2, relativeY:Float):Vector3
	{
		return Controller.ScreenToLawnPositionByRelativeY(screenPosition, relativeY);
	}
	public function ShakeScreen(startAmplitude:Float, endAmplitude:Float, time:Int):Void
	{
		Main.ShakeManager.AddShake(startAmplitude * Controller.LawnToTransScale, endAmplitude * Controller.LawnToTransScale, time / Level.TPS);
	}
	public function ShowMoney():Void
	{
		Controller.ShowMoney();
	}
	public function SetMoneyFade(fade:Bool):Void
	{
		Controller.SetMoneyFade(fade);
	}
	public function SetEnergyActive(visible:Bool):Void Controller.EnergyActive = visible;
	public function IsEnergyActive():Bool return Controller.EnergyActive;
	public function SetBlueprintsActive(visible:Bool):Void Controller.BlueprintsActive = visible;
	public function AreBlueprintsActive():Bool return Controller.BlueprintsActive;
	public function SetPickaxeActive(visible:Bool):Void Controller.PickaxeActive = visible;
	public function IsPickaxeActive():Bool return Controller.PickaxeActive;
	public function SetStarshardActive(visible:Bool):Void Controller.StarshardActive = visible;
	public function IsStarshardActive():Bool return Controller.StarshardActive;
	public function SetTriggerActive(visible:Bool):Void Controller.TriggerActive = visible;
	public function IsTriggerActive():Bool return Controller.TriggerActive;

	public function SetHintArrowPointToBlueprint(index:Int):Void
	{
		var levelUI = Controller.GetUIPreset();
		levelUI.SetHintArrowPointToBlueprint(index);
		TargetType = HintArrowTargetType.Blueprint;
		TargetID = index;
	}
	public function SetHintArrowPointToPickaxe():Void
	{
		var levelUI = Controller.GetUIPreset();
		levelUI.SetHintArrowPointToPickaxe();
		TargetType = HintArrowTargetType.Pickaxe;
		TargetID = 0;
	}
	public function SetHintArrowPointToTrigger():Void
	{
		var levelUI = Controller.GetUIPreset();
		levelUI.SetHintArrowPointToTrigger();
		TargetType = HintArrowTargetType.Trigger;
		TargetID = 0;
	}
	public function SetHintArrowPointToStarshard():Void
	{
		var levelUI = Controller.GetUIPreset();
		levelUI.SetHintArrowPointToStarshard();
		TargetType = HintArrowTargetType.Starshard;
		TargetID = 0;
	}
	public function SetHintArrowPointToEntity(entity:Entity):Void
	{
		var levelUI = Controller.GetUIPreset();
		var entityCtrl = Controller.GetEntityController(entity);
		if (entityCtrl != null)
			levelUI.SetHintArrowPointToEntity(entityCtrl.transform, entity.GetScaledSize().y);
		TargetType = HintArrowTargetType.Entity;
		TargetID = entity.ID;
	}
	public function HideHintArrow():Void
	{
		var levelUI = Controller.GetUIPreset();
		levelUI.HideHintArrow();
		TargetType = HintArrowTargetType.None;
		TargetID = 0;
	}
	public function PauseGame(level:Int = 0):Void
	{
		Controller.PauseGame(level);
	}
	public function ResumeGame(level:Int = 0):Void
	{
		Controller.ResumeGame(level);
	}
	public function ResumeGameDelayed(level:Int = 0):Void
	{
		Controller.ResumeGameDelayed(level);
	}
	public function SetUIAndInputDisabled(disabled:Bool):Void
	{
		Controller.SetUIAndInputDisabled(disabled);
	}
	public function ShowDialog(title:String, desc:String, options:Array<String>, onSelect:Int->Void = null):Void
	{
		Main.Scene.ShowDialog(title, desc, options, onSelect);
	}
	override public function ToSerializable():ISerializableLevelComponent
	{
		var comp = new SerializableUIComponent();
		comp.targetType = cast TargetType;
		comp.targetID = TargetID;
		return comp;
	}
	override public function InitFromSerializable(seri:ISerializableLevelComponent):Void
	{
		if (!Std.isOfType(seri, SerializableUIComponent))
			return;
		var comp:SerializableUIComponent = cast seri;
		TargetType = cast comp.targetType;
		TargetID = comp.targetID;
	}
	override public function PostLevelLoad():Void
	{
		super.PostLevelLoad();
		switch (TargetType)
		{
			case HintArrowTargetType.Entity:
				{
					if (TargetID <= 0)
						return;
					var entity = Level.FindEntityByID(TargetID);
					if (entity == null)
						return;
					SetHintArrowPointToEntity(entity);
				}
			case HintArrowTargetType.Blueprint:
				{
					// PORT-NOTE: TargetID 是 haxe.Int64，Std.int() 不接受 Int64，需用 Int64.toInt。
					var index = Int64.toInt(TargetID);
					if (index < 0 || index >= Level.GetSeedSlotCount())
						return;
					SetHintArrowPointToBlueprint(index);
				}
			case HintArrowTargetType.Pickaxe:
				{
					SetHintArrowPointToPickaxe();
				}
			case HintArrowTargetType.Starshard:
				{
					SetHintArrowPointToStarshard();
				}
			default:
		}
	}
	public function SetProgressBarToBoss(barStyle:NamespaceID):Void
	{
		Controller.SetProgressToBoss(barStyle);
	}
	public function SetProgressBarToStage():Void
	{
		Controller.SetProgressToStage();
	}
	public function SetAreaModelPreset(preset:String):Void
	{
		Controller.SetModelPreset(preset);
	}
	public function TriggerModelAnimator(name:String):Void
	{
		Controller.TriggerModelAnimator(name);
	}
	public function SetModelAnimatorBool(name:String, value:Bool):Void
	{
		Controller.SetModelAnimatorBool(name, value);
	}
	public function SetModelAnimatorInt(name:String, value:Int):Void
	{
		Controller.SetModelAnimatorInt(name, value);
	}
	public function SetModelAnimatorFloat(name:String, value:Float):Void
	{
		Controller.SetModelAnimatorFloat(name, value);
	}
	public function UpdateLevelName():Void
	{
		Controller.UpdateLevelName();
	}
	public function FlickerEnergy():Void
	{
		Controller.FlickerEnergy();
	}
	public var TargetType(default, null):HintArrowTargetType;
	public var TargetID(default, null):Int64;
	// PORT-NOTE: C# 的 static readonly 字段是首次使用时才初始化；hxcpp 会在 main() 之前执行全部静态初始化
	// （__boot_all()），那时 Global.Game / MainManager.Instance 仍为 null，直接求值会段错误。
	// 此处改为惰性 getter（结果缓存一次，等价于 C# 的 readonly static），还原 C# 语义。
	public static var componentID(get, never):NamespaceID;
	private static var _componentID:NamespaceID;
	static function get_componentID():NamespaceID
	{
		if (_componentID == null) _componentID = new NamespaceID(Global.BuiltinNamespace, "ui");
		return _componentID;
	}
}

@:rtti
class SerializableUIComponent implements ISerializableLevelComponent
{
	public var targetType:Int;
	public var targetID:Int64;
	public function new() {}
}

enum abstract HintArrowTargetType(Int) from Int to Int
{
	var None = 0;
	var Blueprint = 1;
	var Pickaxe = 2;
	var Trigger = 3;
	var Entity = 4;
	var Starshard = 5;
}

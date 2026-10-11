// Ported from: Assets/Scripts/MVZ2/Level/Blueprints/BlueprintController.cs
package mvz2.level;

import mvz2.managers.MainManager;
// PORT-NOTE: C# 为 MVZ2.SeedPacks.BlueprintModelInterface；移植后类实际在 mvz2.blueprints。
import mvz2.blueprints.BlueprintModelInterface;
import mvz2.models.Model.SerializableModelData;
import mvz2.ui.Blueprint;
import mvz2.ui.Blueprint.BlueprintViewData;
import mvz2.ui.Tooltip.TooltipContent;
import mvz2.ui.ITooltipSource;
import mvz2.ui.ITooltipTarget;
import mvz2logic.inputs.PointerInteraction;
import pvzengine.level.LevelEngine;
import pvzengine.models.IModelInterface;
import pvzengine.seedpacks.SeedDefinition;
import unity.*;
import unity.Debug;
import unity.eventsystems.PointerEventData;
import mvz2.managers.ResourceManager;
import mvz2.models.Model;
import mvz2.ui.Tooltip;
import Main;

// PORT-NOTE: C# 的 abstract class 在 Haxe 中语义不同（abstract 是编译期的抽象类型）。
// 这里仍写作普通 class，抽象方法以空实现 + 注释标注。
class BlueprintController extends MonoBehaviour
{
	// #region 生命周期
	function InitBlueprint(controller:ILevelController, blueprint:Blueprint, index:Int):Void
	{
		if (inited)
			return;
		Controller = controller;
		ui = blueprint;
		Index = index;

		modelInterface = new BlueprintModelInterface(this);
		tooltipSource = new BlueprintTooltipSource(this);

		UpdateView();
		InitModel();

		inited = true;
		UpdateActive();
	}
	public function Unload():Void
	{
		inited = false;
		UpdateActive();
	}
	private function OnEnable():Void
	{
		UpdateActive();
	}
	private function OnDisable():Void
	{
		UpdateActive();
	}
	private function UpdateActive():Void
	{
		var active = inited && enabled;
		if (active != lastActive)
		{
			lastActive = active;
			if (active)
			{
				OnActive();
			}
			else
			{
				OnDeactive();
			}
		}
	}
	function OnActive():Void
	{
		ui.OnPointerInteraction.add(OnPointerInteractionCallback);
	}
	function OnDeactive():Void
	{
		ui.OnPointerInteraction.remove(OnPointerInteractionCallback);
	}
	// #endregion

	// #region 模型
	public function GetModel():Model
	{
		return ui.Model;
	}
	private function InitModel():Void
	{
		var model = GetModel();
		if (model != null)
		{
			// TODO 把这个蓝图的内嵌蓝图ID给它改一下
			model.Init(null, Controller.GetCamera());
		}
	}
	// #endregion

	// #region UI
	public function UpdateView():Void
	{
		var viewData = GetBlueprintViewData();
		ui.UpdateView(viewData);
	}
	public function GetBlueprintViewData():BlueprintViewData
	{
		return Main.ResourceManager.GetBlueprintViewDataFromDefinition(GetSeedDefinition(), Level.IsEndless(), IsCommandBlock());
	}
	public function GetTooltipViewData():TooltipContent
	{
		var content = new TooltipContent();
		content.name = GetName();
		content.error = "";
		content.description = "";
		return content;
	}
	// #endregion


	// #region 事件回调
	private function OnPointerInteractionCallback(blueprint:Blueprint, eventData:PointerEventData, interaction:PointerInteraction):Void
	{
		switch (interaction)
		{
			case PointerInteraction.Enter:
				Controller.ShowTooltip(tooltipSource);
			case PointerInteraction.Exit:
				Controller.HideTooltip();
			default:
		}
	}
	// #endregion

	public function GetBlueprintUI():Blueprint
	{
		return ui;
	}
	// abstract
	public function GetSeedDefinition():SeedDefinition
	{
		throw "abstract";
	}
	// abstract
	public function IsCommandBlock():Bool
	{
		throw "abstract";
	}
	private function GetName():String
	{
		return Main.ResourceManager.GetBlueprintName(GetSeedDefinition().GetID(), IsCommandBlock());
	}

	// #region 属性字段
	public var Main(get, never):MainManager;
	function get_Main():MainManager return MainManager.Instance;
	public var Level(get, never):LevelEngine;
	function get_Level():LevelEngine return Controller.GetEngine();
	public var Index(default, set):Int;
	function set_Index(v:Int):Int return Index = v;
	public var Controller(default, null):ILevelController = null;
	// PORT-NOTE: C# 中为 protected 字段；Haxe 无 protected，改用 @:allow 开放给同包子类。
	@:allow(mvz2.level)
	var ui:Blueprint = null;
	@:allow(mvz2.level)
	var modelInterface:IModelInterface = null;
	@:allow(mvz2.level)
	var tooltipSource:ITooltipSource = null;
	private var inited:Bool = false;
	private var lastActive:Bool = false;
	// #endregion
}

class BlueprintTooltipSource implements ITooltipSource
{
	public function new(blueprintController:BlueprintController)
	{
		this.blueprintController = blueprintController;
	}
	public function GetCamera():Camera
	{
		return blueprintController.Controller.GetCamera();
	}
	public function GetTarget():ITooltipTarget
	{
		return blueprintController.GetBlueprintUI();
	}
	public function GetContent():TooltipContent
	{
		return blueprintController.GetTooltipViewData();
	}
	private var blueprintController:BlueprintController;
}

@:rtti
class SerializableBlueprintController
{
	public var model:SerializableModelData;
	public function new() {}
}

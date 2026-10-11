// Ported from: Assets/Scripts/View/Level/LevelUIPreset.cs
package mvz2.ui.level;

import mvz2.ui.level.PickaxeSlot;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2.models.Model;
import mvz2.ui.ElementList;
import mvz2.ui.MoneyPanel;
import mvz2.ui.level.ProgressBar;
import mvz2logic.inputs.PointerInteraction;
import mvz2logic.level.LawnArea;
import unity.Animator;
import unity.CanvasGroup;
import unity.GameObject;
import unity.Mathf;
import unity.Sprite;
import unity.Transform;
import unity.UnityObject;
import unity.Vector2;
import unity.eventsystems.PointerEventData;
import unity.tmpro.TextMeshProUGUI;
import unity.ui.Button;
import unity.ui.CanvasScaler;
import unity.ui.LayoutElement;
import unity.LayerMask;
import unity.MonoBehaviour;
import mvz2.models.Model.SerializableAnimator;
import mvz2.ui.level.PickaxeSlot.PickaxeNumberText;
import mvz2.ui.level.ProgressBar.ProgressBarTemplateViewData;
import unity.ui.CanvasScaler.GraphicRaycaster;
import flixel.util.FlxSignal;

class LevelUIPreset extends unity.MonoBehaviour
{
	// #region 公有方法

	// #region 基本
	public function SetActive(active:Bool):Void
	{
		gameObject.SetActive(active);
	}
	public function SetRaycasterMask(mask:unity.LayerMask):Void
	{
		for (raycaster in raycasters)
		{
			raycaster.blockingMask = mask;
		}
	}
	public function UpdateFrame(deltaTime:Float):Void
	{
		if (animator.gameObject.activeInHierarchy)
			animator.Update(deltaTime);
		for (i in 0...artifactList.Count)
		{
			var artifact = artifactList.getElementAs(i, ArtifactItemUI);
			if (!UnityObject.exists(artifact))
				continue;
			artifact.UpdateAnimator(deltaTime);
		}
		BlueprintChoose.UpdateFrame(deltaTime);
	}
	public function SetReceiveRaycasts(value:Bool):Void
	{
		for (group in canvasGroups)
		{
			group.blocksRaycasts = value;
		}
	}
	// #endregion

	// #region 能量
	public function SetEnergyActive(value:Bool):Void
	{
		energyPanel.gameObject.SetActive(value);
	}
	public function SetEnergy(value:String):Void
	{
		energyPanel.SetEnergy(value);
	}
	public function FlickerEnergy():Void
	{
		energyPanel.FlickerEnergy();
	}
	// #endregion

	// #region 铁镐
	public function SetPickaxeActive(visible:Bool):Void
	{
		pickaxeSlotObj.SetActive(visible);
	}
	public function SetPickaxeSelected(selected:Bool):Void
	{
		pickaxeSlot.SetSelected(selected);
	}
	public function SetPickaxeDisabled(selected:Bool):Void
	{
		pickaxeSlot.SetDisabled(selected);
	}
	public function SetPickaxeHotkeyText(hotkey:String):Void
	{
		pickaxeSlot.SetHotkeyText(hotkey);
	}
	public function SetPickaxeNumberText(info:PickaxeNumberText):Void
	{
		pickaxeSlot.SetNumberText(info);
	}
	public function GetPickaxeSlot():PickaxeSlot
	{
		return pickaxeSlot;
	}
	// #endregion

	// #region 触发
	public function SetTriggerActive(visible:Bool):Void
	{
		triggerSlotObj.SetActive(visible);
		triggerSlotConveyorObj.SetActive(visible);
	}
	public function SetTriggerSelected(selected:Bool):Void
	{
		triggerSlot.SetSelected(selected);
		triggerSlotConveyor.SetSelected(selected);
	}
	public function SetTriggerHotkeyText(hotkey:String):Void
	{
		triggerSlot.SetHotkeyText(hotkey);
		triggerSlotConveyor.SetHotkeyText(hotkey);
	}
	public function GetCurrentTriggerUI():TriggerSlot
	{
		return Blueprints.IsConveyorMode() ? triggerSlotConveyor : triggerSlot;
	}
	// #endregion

	// #region 钱
	public function SetMoney(money:String):Void
	{
		moneyPanel.SetMoney(money);
	}
	public function HideMoney():Void
	{
		moneyPanel.Hide();
	}
	public function SetMoneyFade(fade:Bool):Void
	{
		moneyPanel.SetFade(fade);
	}
	public function ResetMoneyFadeTime():Void
	{
		moneyPanel.ResetTimeout();
	}
	// #endregion

	// #region 星之碎片
	public function SetStarshardActive(visible:Bool):Void
	{
		starshardPanelObj.SetActive(visible);
	}
	public function SetStarshardIcon(icon:Null<Sprite>):Void
	{
		starshardPanel.SetIconSprite(icon);
	}
	public function SetStarshardCount(count:Int, maxCount:Int):Void
	{
		starshardPanel.SetPoints(count, maxCount);
	}
	public function SetStarshardSelected(selected:Bool):Void
	{
		starshardPanel.SetSelected(selected);
	}
	public function SetStarshardDisabled(selected:Bool):Void
	{
		starshardPanel.SetDisabled(selected);
	}
	public function SetStarshardHotkeyText(hotkey:String):Void
	{
		starshardPanel.SetHotkeyText(hotkey);
	}
	// #endregion

	// #region 右上角

	// #region 游戏难度
	public function SetDifficulty(difficulty:String):Void
	{
		difficultyText.text = difficulty;
	}
	// #endregion

	// #region 加速
	public function SetSpeedUp(speedUp:Bool):Void
	{
		speedUpEnabledObject.SetActive(speedUp);
		speedUpDisabledObject.SetActive(!speedUp);
	}
	public function SetSpeedUpHotkeyText(hotkey:String):Void
	{
		if (speedUpHotkeyText != null)
			speedUpHotkeyText.text = hotkey;
	}
	// #endregion

	// #endregion

	// #region 关卡进度

	// #region 关卡名
	public function SetLevelName(name:String):Void
	{
		levelNameText.text = name;
	}
	// #endregion

	// #region 关卡进度
	public function SetProgressBarVisible(visible:Bool):Void
	{
		progressBarRoot.SetActive(visible);
	}
	public function SetProgressBarMode(boss:Bool):Void
	{
		progressBar.gameObject.SetActive(!boss);
		bossProgressBar.gameObject.SetActive(boss);
	}
	public function SetLevelProgress(progress:Float):Void
	{
		progressBar.SetProgress(progress);
	}
	public function SetBannerProgresses(progresses:Array<Float>):Void
	{
		progressBar.SetBannerProgresses(progresses);
	}
	public function SetBossProgressTemplate(template:ProgressBarTemplateViewData):Void
	{
		bossProgressBar.UpdateTemplate(template);
	}
	public function SetBossProgress(progress:Float):Void
	{
		bossProgressBar.SetProgress(progress);
	}
	public function SetBossProgressText(text:String):Void
	{
		bossProgressBar.SetProgressText(text);
	}
	// #endregion

	// #endregion

	// #region 提示文本
	public function ShowHugeWaveText():Void
	{
		animator.SetTrigger("HugeWave");
	}
	public function ShowFinalWaveText():Void
	{
		animator.SetTrigger("FinalWave");
	}
	public function ShowReadySetBuild():Void
	{
		animator.SetTrigger("ReadySetBuild");
	}
	public function ShowAdvice(advice:String):Void
	{
		adviceObject.SetActive(true);
		adviceText.text = advice;
	}
	public function HideAdvice():Void
	{
		adviceObject.SetActive(false);
	}
	// #endregion

	// #region 提示箭头
	public function SetHintArrowPointToBlueprint(index:Int):Void
	{
		var blueprint = Blueprints.GetCurrentModeBlueprint(index);
		if (!UnityObject.exists(blueprint))
		{
			HideHintArrow();
			return;
		}
		hintArrow.SetVisible(true);
		hintArrow.SetTarget(blueprint.transform, hintArrowOffsetBlueprint * 0.01, hintArrowAngleBlueprint);
	}
	public function SetHintArrowPointToPickaxe():Void
	{
		hintArrow.SetVisible(true);
		var pickaxe = pickaxeSlot;
		hintArrow.SetTarget(pickaxe.transform, hintArrowOffsetPickaxe * 0.01, hintArrowAnglePickaxe);
	}
	public function SetHintArrowPointToTrigger():Void
	{
		hintArrow.SetVisible(true);
		var trigger = GetCurrentTriggerUI();
		hintArrow.SetTarget(trigger.transform, hintArrowOffsetTrigger * 0.01, hintArrowAngleTrigger);
	}
	public function SetHintArrowPointToStarshard():Void
	{
		hintArrow.SetVisible(true);
		var starshard = starshardPanel.Icon;
		hintArrow.SetTarget(starshard.transform, hintArrowOffsetStarshard * 0.01, hintArrowAngleStarshard);
	}
	public function SetHintArrowPointToEntity(transform:Transform, height:Float):Void
	{
		hintArrow.SetVisible(true);
		hintArrow.SetTarget(transform, new Vector2(0, height + 16) * 0.01, 180);
	}
	public function HideHintArrow():Void
	{
		hintArrow.SetVisible(false);
	}
	// #endregion

	// #region 制品
	public function SetArtifactCount(count:Int):Void
	{
		artifactList.updateList(count, null,
			function(obj:unity.GameObject)
			{
				var artifact = obj.GetComponent(ArtifactItemUI);
				artifact.OnPointerEnterSignal.add(OnArtifactPointerEnterCallback);
				artifact.OnPointerExitSignal.add(OnArtifactPointerExitCallback);
			},
			function(obj:unity.GameObject)
			{
				var artifact = obj.GetComponent(ArtifactItemUI);
				artifact.OnPointerEnterSignal.remove(OnArtifactPointerEnterCallback);
				artifact.OnPointerExitSignal.remove(OnArtifactPointerExitCallback);
			});
	}
	public function SetArtifactIcon(index:Int, value:Null<Sprite>):Void
	{
		var ui = GetArtifactAt(index);
		if (!UnityObject.exists(ui)) return;
		ui.SetIcon(value);
	}
	public function SetArtifactNumber(index:Int, number:String):Void
	{
		var ui = GetArtifactAt(index);
		if (!UnityObject.exists(ui)) return;
		ui.SetNumber(number);
	}
	public function HighlightArtifact(index:Int):Void
	{
		var ui = GetArtifactAt(index);
		if (!UnityObject.exists(ui)) return;
		ui.Shine();
	}
	public function SetArtifactGrayscale(index:Int, value:Bool):Void
	{
		var ui = GetArtifactAt(index);
		if (!UnityObject.exists(ui)) return;
		ui.SetGrayscale(value);
	}
	public function SetArtifactGlowing(index:Int, value:Bool):Void
	{
		var ui = GetArtifactAt(index);
		if (!UnityObject.exists(ui)) return;
		ui.SetGlowing(value);
	}
	public function GetArtifactAt(index:Int):Null<ArtifactItemUI>
	{
		return artifactList.getElementAs(index, ArtifactItemUI);
	}
	// #endregion

	public function SetCameraLimitWidth(t:Float):Void
	{
		t = Mathf.Clamp01(t);
		limitRegionLayoutElement.minWidth = cameraLimitWidth * t;
	}
	public function SetUIVisibleState(state:VisibleState):Void
	{
		animator.SetInteger("UIState", (cast state : Int));
	}
	public function SetUIDisabled(disabled:Bool):Void
	{
		animator.SetBool("DisableUI", disabled);
	}
	public function SetBlueprintsSortingToChoosing(choosing:Bool):Void
	{
		blueprints.SetSortingToChoosing(choosing);
	}

	public function ToSerializable():SerializableLevelUIPreset
	{
		var artifactAnimators:Array<Null<SerializableAnimator>> = [];
		artifactAnimators.resize(artifactList.Count);
		for (i in 0...artifactAnimators.length)
		{
			var artifact = artifactList.getElementAs(i, ArtifactItemUI);
			if (!UnityObject.exists(artifact))
				continue;
			artifactAnimators[i] = artifact.GetSerializableAnimator();
		}
		var result = new SerializableLevelUIPreset();
		result.animator = new SerializableAnimator(animator);
		result.artifactAnimators = artifactAnimators;
		return result;
	}
	public function LoadFromSerializable(serializable:SerializableLevelUIPreset):Void
	{
		if (serializable.animator != null) serializable.animator.Deserialize(animator);
		if (serializable.artifactAnimators != null)
		{
			for (i in 0...serializable.artifactAnimators.length)
			{
				var artifact = artifactList.getElementAs(i, ArtifactItemUI);
				if (artifact == null)
					continue;
				var seriAnimator = serializable.artifactAnimators[i];
				if (seriAnimator == null)
					continue;
				artifact.LoadFromSerializableAnimator(seriAnimator);
			}
		}
	}

	public function CallStartGame():Void
	{
		OnStartGameCalled.dispatch();
	}
	// #endregion

	// #region 私有方法
	private function Awake():Void
	{
		animator.enabled = false;
		for (receiver in receivers)
		{
			receiver.OnPointerInteraction.add((r, data, interaction) -> OnRaycastReceiverPointerInteraction.dispatch(r.GetArea(), data, interaction));
		}

		starshardPanel.OnPointerDownSignal.add(data -> OnStarshardPointerDown.dispatch(data));

		pickaxeSlot.OnPointerEnterSignal.add(data -> OnPickaxePointerEnter.dispatch(data));
		pickaxeSlot.OnPointerExitSignal.add(data -> OnPickaxePointerExit.dispatch(data));
		pickaxeSlot.OnPointerDownSignal.add(data -> OnPickaxePointerDown.dispatch(data));

		triggerSlot.OnPointerEnterSignal.add(data -> OnTriggerPointerEnter.dispatch(data));
		triggerSlot.OnPointerExitSignal.add(data -> OnTriggerPointerExit.dispatch(data));
		triggerSlot.OnPointerDownSignal.add(data -> OnTriggerPointerDown.dispatch(data));

		if (triggerSlotConveyor != triggerSlot)
		{
			triggerSlotConveyor.OnPointerEnterSignal.add(data -> OnTriggerPointerEnter.dispatch(data));
			triggerSlotConveyor.OnPointerExitSignal.add(data -> OnTriggerPointerExit.dispatch(data));
			triggerSlotConveyor.OnPointerDownSignal.add(data -> OnTriggerPointerDown.dispatch(data));
		}

		menuButton.onClick.AddListener(() -> OnMenuButtonClick.dispatch());
		speedUpButton.onClick.AddListener(() -> OnSpeedUpButtonClick.dispatch());

		blueprints.OnBlueprintPointerInteraction.add((index, e, i, c) -> OnBlueprintPointerInteraction.dispatch(index, e, i, c));
	}

	private function OnArtifactPointerEnterCallback(item:ArtifactItemUI):Void
	{
		OnArtifactPointerEnter.dispatch(artifactList.indexOfComponent(item));
	}
	private function OnArtifactPointerExitCallback(item:ArtifactItemUI):Void
	{
		OnArtifactPointerExit.dispatch(artifactList.indexOfComponent(item));
	}
	// #endregion

	// #region 事件
	public var OnRaycastReceiverPointerInteraction:FlxTypedSignal<LawnArea->PointerEventData->PointerInteraction->Void> = new FlxTypedSignal();

	public var OnPickaxePointerEnter:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();
	public var OnPickaxePointerExit:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();
	public var OnPickaxePointerDown:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();

	public var OnArtifactPointerEnter:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnArtifactPointerExit:FlxTypedSignal<Int->Void> = new FlxTypedSignal();

	public var OnStarshardPointerDown:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();

	public var OnTriggerPointerEnter:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();
	public var OnTriggerPointerExit:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();
	public var OnTriggerPointerDown:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();

	public var OnBlueprintPointerInteraction:FlxTypedSignal<Int->PointerEventData->PointerInteraction->Bool->Void> = new FlxTypedSignal();

	public var OnStartGameCalled:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnMenuButtonClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnSpeedUpButtonClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	// #endregion

	// #region 属性字段

	public var Blueprints(get, never):LevelUIBlueprints;
	function get_Blueprints():LevelUIBlueprints return blueprints;
	public var BlueprintChoose(get, never):LevelUIBlueprintChoose;
	function get_BlueprintChoose():LevelUIBlueprintChoose return blueprintChoose;

	@:serializeField
	private var animator:Animator;
	@:serializeField
	private var raycasters:Array<GraphicRaycaster>;
	@:serializeField
	private var canvasGroups:Array<CanvasGroup>;

	// [Header("Enabling")]
	@:serializeField
	private var pickaxeSlotObj:GameObject;
	@:serializeField
	private var starshardPanelObj:GameObject;
	@:serializeField
	private var triggerSlotObj:GameObject;
	@:serializeField
	private var triggerSlotConveyorObj:GameObject;

	// [Header("Blueprints")]
	@:serializeField
	private var blueprints:LevelUIBlueprints;
	@:serializeField
	private var blueprintChoose:LevelUIBlueprintChoose;


	// [Header("Tools")]
	@:serializeField
	private var energyPanel:EnergyPanel;
	@:serializeField
	private var triggerSlot:TriggerSlot;
	@:serializeField
	private var triggerSlotConveyor:TriggerSlot;
	@:serializeField
	private var pickaxeSlot:PickaxeSlot;

	// [Header("Raycast Receivers")]
	@:serializeField
	private var receivers:Array<LawnRaycastReceiver>;

	// [Header("CameraLimit")]
	@:serializeField
	private var limitRegionLayoutElement:LayoutElement;
	@:serializeField
	private var cameraLimitWidth:Float = 220;

	// [Header("Artifacts")]
	@:serializeField
	private var artifactList:ElementList;

	// [Header("Bottom")]
	@:serializeField
	private var moneyPanel:MoneyPanel;
	@:serializeField
	private var starshardPanel:StarshardPanel;
	@:serializeField
	private var levelNameText:TextMeshProUGUI;
	@:serializeField
	private var progressBarRoot:GameObject;
	@:serializeField
	private var progressBar:ProgressBar;
	@:serializeField
	private var bossProgressBar:ProgressBar;

	// [Header("Right Top")]
	@:serializeField
	private var speedUpButton:Button;
	@:serializeField
	private var speedUpEnabledObject:GameObject;
	@:serializeField
	private var speedUpDisabledObject:GameObject;
	@:serializeField
	private var speedUpHotkeyText:TextMeshProUGUI;
	@:serializeField
	private var menuButton:Button;
	@:serializeField
	private var difficultyText:TextMeshProUGUI;

	// [Header("Advice")]
	@:serializeField
	private var adviceObject:GameObject;
	@:serializeField
	private var adviceText:TextMeshProUGUI;

	// [Header("Hint Arrow")]
	@:serializeField
	private var hintArrow:HintArrow;
	@:serializeField
	private var hintArrowOffsetBlueprint:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 null 解引用（该字段在 Unity 由 prefab 序列化赋值，移植层由 prefab 数据覆盖）
	@:serializeField
	private var hintArrowOffsetPickaxe:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 null 解引用（该字段在 Unity 由 prefab 序列化赋值，移植层由 prefab 数据覆盖）
	@:serializeField
	private var hintArrowOffsetStarshard:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 null 解引用（该字段在 Unity 由 prefab 序列化赋值，移植层由 prefab 数据覆盖）
	@:serializeField
	private var hintArrowOffsetTrigger:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 null 解引用（该字段在 Unity 由 prefab 序列化赋值，移植层由 prefab 数据覆盖）
	@:serializeField
	private var hintArrowAngleBlueprint:Float;
	@:serializeField
	private var hintArrowAnglePickaxe:Float;
	@:serializeField
	private var hintArrowAngleStarshard:Float;
	@:serializeField
	private var hintArrowAngleTrigger:Float;
	// #endregion
}

// C# 中为 MVZ2.UI.Level.LevelUIPreset 的内嵌枚举 Receiver；Haxe 不支持类内嵌类型，移到模块顶层（仍可用 LevelUIPreset.Receiver 访问）。
enum Receiver
{
	Side;
	Lawn;
	Bottom;
}

enum abstract VisibleState(Int)
{
	var Nothing = 0;
	var ChoosingBlueprints = 1;
	var InLevel = 2;
}

// C# 中为 MVZ2.UI.Level 的 SerializableLevelUIPreset 类（[Serializable]）。
@:serialize
@:rtti
class SerializableLevelUIPreset
{
	public var animator:Null<SerializableAnimator>;
	public var artifactAnimators:Null<Array<Null<SerializableAnimator>>>;

	// PORT-NOTE: C# 结构体初始化器 `new SerializableLevelUIPreset { field = value }` 在 Haxe 中写作 `new SerializableLevelUIPreset({field: value})`，
	// 因此构造函数接受可选的匿名结构参数，同时兼容 `new SerializableLevelUIPreset()`。
	public function new(?data:{?animator:Null<SerializableAnimator>, ?artifactAnimators:Null<Array<Null<SerializableAnimator>>>})
	{
		if (data == null)
			return;
		if (data.animator != null) animator = data.animator;
		if (data.artifactAnimators != null) artifactAnimators = data.artifactAnimators;
	}
}

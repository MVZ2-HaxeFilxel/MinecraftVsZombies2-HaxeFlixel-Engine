// Ported from: Assets/Scripts/View/Level/BlueprintChoose/LevelUIBlueprintChoose.cs
package mvz2.ui.level;

import mvz2.ui.level.ArtifactSlot;

import mvz2.ui.level.ArtifactSelectItem;

import mvz2.ui.BlueprintDisplayer;

import mvz2.ui.level.BlueprintChoosePanel;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2.ui.Blueprint;
import mvz2.ui.ElementListUI;
import mvz2logic.inputs.PointerInteraction;
import unity.Animator;
import unity.Debug;
import unity.GameObject;
import unity.Transform;
import unity.RectTransform;
import unity.UnityObject;
import unity.Vector3;
import unity.eventsystems.PointerEventData;
import unity.ui.Button;
import unity.MonoBehaviour;
import mvz2.ui.BlueprintDisplayer.ChoosingBlueprintViewData;
import mvz2.ui.level.ArtifactSelectItem.ArtifactSelectItemViewData;
import mvz2.ui.level.ArtifactSlot.ArtifactViewData;
import mvz2.ui.level.BlueprintChoosePanel.BlueprintChoosePanelViewData;
import flixel.util.FlxSignal;

class LevelUIBlueprintChoose extends unity.MonoBehaviour
{
	// #region 移动蓝图
	public function CreateMovingBlueprint():MovingBlueprint
	{
		return movingBlueprints.CreateMovingBlueprint();
	}
	public function RemoveMovingBlueprint(blueprint:MovingBlueprint):Void
	{
		movingBlueprints.RemoveMovingBlueprint(blueprint);
	}
	// #endregion

	// #region 选择蓝图
	public function SetChosenBlueprintsVisible(visible:Bool):Void
	{
		choosingBlueprintRoot.SetActive(visible);
		runtimeBlueprintRoot.SetActive(!visible);
	}
	public function SetChosenBlueprintsSlotCount(count:Int):Void
	{
		chosenBlueprints.SetSlotCount(count);
	}
	public function SetViewLawnReturnBlockerActive(active:Bool):Void
	{
		viewLawnReturnBlocker.SetActive(active);
	}
	public function SetSideUIDisplaying(displaying:Bool):Void
	{
		sideUIDisplaying = displaying;
	}
	public function SetBlueprintChooseDisplaying(displaying:Bool):Void
	{
		blueprintChooseDisplaying = displaying;
	}
	public function SetSideUIBlend(blend:Float):Void
	{
		sideUIBlend = blend;
		if (animator.gameObject.activeInHierarchy)
			animator.SetFloat("SideUIBlend", sideUIBlend);
	}
	public function SetBlueprintChooseBlend(blend:Float):Void
	{
		blueprintChooseBlend = blend;
		if (animator.gameObject.activeInHierarchy)
			animator.SetFloat("BlueprintChooseBlend", blend);
	}
	public function SetBlueprintChooseViewAlmanacButtonActive(active:Bool):Void
	{
		choosingViewAlmanacButton.gameObject.SetActive(active);
	}
	public function SetBlueprintChooseViewStoreButtonActive(active:Bool):Void
	{
		choosingViewStoreButton.gameObject.SetActive(active);
	}
	public function UpdateBlueprintChooseElements(viewData:BlueprintChoosePanelViewData):Void
	{
		blueprintChoosePanel.UpdateElements(viewData);
	}
	public function UpdateBlueprintChooseItems(viewDatas:Array<ChoosingBlueprintViewData>):Void
	{
		blueprintChoosePanel.UpdateItems(viewDatas);
	}
	public function UpdateCommandBlockItem(viewData:ChoosingBlueprintViewData):Void
	{
		blueprintChoosePanel.UpdateCommandBlockItem(viewData);
	}
	public function ShowCommandBlockPanel():Void
	{
		commandBlockChoosePanel.gameObject.SetActive(true);
	}
	public function HideCommandBlockPanel():Void
	{
		commandBlockChoosePanel.gameObject.SetActive(false);
	}
	public function UpdateCommandBlockChooseItems(viewDatas:Array<ChoosingBlueprintViewData>):Void
	{
		commandBlockChoosePanel.UpdateItems(viewDatas);
	}
	public function GetBlueprintChooseItem(index:Int):Null<Blueprint>
	{
		return blueprintChoosePanel.GetItem(index);
	}
	public function GetCommandBlockChooseItem(index:Int):Null<Blueprint>
	{
		return commandBlockChoosePanel.GetItem(index);
	}
	// #endregion

	// #region 已选蓝图
	public function CreateChosenBlueprint():Blueprint
	{
		return chosenBlueprints.CreateBlueprint();
	}
	public function InsertChosenBlueprint(index:Int, blueprint:Blueprint):Void
	{
		chosenBlueprints.InsertBlueprint(index, blueprint);
	}
	public function RemoveChosenBlueprint(blueprint:Blueprint):Bool
	{
		return chosenBlueprints.RemoveBlueprint(blueprint);
	}
	public function RemoveChosenBlueprintAt(index:Int):Void
	{
		chosenBlueprints.RemoveBlueprintAt(index);
	}
	public function DestroyChosenBlueprint(blueprint:Blueprint):Bool
	{
		return chosenBlueprints.DestroyBlueprint(blueprint);
	}
	public function DestroyChosenBlueprintAt(index:Int):Void
	{
		chosenBlueprints.DestroyBlueprintAt(index);
	}
	public function GetChosenBlueprintAt(index:Int):Null<Blueprint>
	{
		return chosenBlueprints.GetBlueprintAt(index);
	}
	public function GetChosenBlueprintIndex(blueprint:Blueprint):Int
	{
		return chosenBlueprints.GetBlueprintIndex(blueprint);
	}
	public function GetChosenBlueprintPosition(index:Int):Vector3
	{
		return chosenBlueprints.GetBlueprintPosition(index);
	}
	public function GetChosenBlueprintCount():Int
	{
		return chosenBlueprints.GetBlueprintCount();
	}
	// #endregion

	// #region 选择制品
	public function SetArtifactSlotsActive(visible:Bool):Void
	{
		artifactSlotsRoot.SetActive(visible);
	}
	public function SetArtifactRepickButtonActive(visible:Bool):Void
	{
		artifactRepickButton.gameObject.SetActive(visible);
	}
	public function GetArtifactSlotAt(index:Int):Null<ArtifactSlot>
	{
		return artifactSlotList.getElementAs(index, ArtifactSlot);
	}
	public function ShowArtifactChoosePanel(viewDatas:Array<ArtifactSelectItemViewData>):Void
	{
		artifactChoosingDialogObj.SetActive(true);
		artifactChoosingDialog.UpdateArtifacts(viewDatas);
	}
	public function HideArtifactChoosePanel():Void
	{
		artifactChoosingDialogObj.SetActive(false);
	}
	public function GetArtifactSelectItem(index:Int):Null<ArtifactSelectItem>
	{
		return artifactChoosingDialog.GetArtifactSelectItem(index);
	}
	public function ResetArtifactSlotCount(count:Int):Void
	{
		artifactSlotList.updateList(count,
			function(i:Int, rect:RectTransform)
			{
				var artifactIcon = rect.GetComponent(ArtifactSlot);
				artifactIcon.ResetView();
			},
			function(rect:RectTransform)
			{
				var artifactIcon = rect.GetComponent(ArtifactSlot);
				artifactIcon.OnClick.add(OnBlueprintChooseArtifactSlotClickCallback);
				artifactIcon.OnPointerEnterSignal.add(OnBlueprintChooseArtifactSlotPointerEnterCallback);
				artifactIcon.OnPointerExitSignal.add(OnBlueprintChooseArtifactSlotPointerExitCallback);
			},
			function(rect:RectTransform)
			{
				var artifactIcon = rect.GetComponent(ArtifactSlot);
				artifactIcon.OnClick.remove(OnBlueprintChooseArtifactSlotClickCallback);
				artifactIcon.OnPointerEnterSignal.remove(OnBlueprintChooseArtifactSlotPointerEnterCallback);
				artifactIcon.OnPointerExitSignal.remove(OnBlueprintChooseArtifactSlotPointerExitCallback);
			});
	}
	public function UpdateArtifactSlotAt(index:Int, viewData:ArtifactViewData):Void
	{
		var element = artifactSlotList.getElementAs(index, ArtifactSlot);
		if (!UnityObject.exists(element))
			return;
		element.UpdateView(viewData);
	}
	// #endregion

	public function GetCommandBlockSlotBlueprint():Null<Blueprint>
	{
		return blueprintChoosePanel.GetCommandBlockBlueprintItem();
	}

	private function Awake():Void
	{
		// PORT-NOTE: `artifactRepickButton` 在原工程里指向 ArtifactSlots 嵌套 prefab 内的
		// RefreshButton（UIPresetStandalone.prefab:3911 的 objectReference 指向
		// ArtifactSlots.prefab 的 stripped MonoBehaviour）。导出器不展开嵌套 prefab 实例的
		// stripped 引用，字段恒为 null（Level.json 的 danglingRefs=641 之一），直接订阅就空引用。
		// 这里在移植层按 Unity 的等价关系补绑定：从 artifactSlotsRoot 子树找 RefreshButton。
		if (artifactRepickButton == null)
			artifactRepickButton = findButtonInSubtree(artifactSlotsRoot, "RefreshButton");
		if (artifactRepickButton == null)
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] artifactRepickButton 补绑定失败（子树上找不到 RefreshButton）');

		// PORT-NOTE: 其余字段若因导出丢引用而为 null，跳过订阅并告警 —— Unity 里这些字段
		// 都非 null，空引用会让整个关卡场景加载失败（首 run 点冒险即崩的根因）。
		unity.Debug.Log('[Awake诊断] 步骤1 补绑定后 artifactRepickButton=' + (artifactRepickButton == null ? "null" : "ok"));
		if (viewLawnReturnButton != null)
			viewLawnReturnButton.onClick.AddListener(() -> OnViewLawnReturnClick.dispatch());
		else
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] viewLawnReturnButton 为空，跳过订阅');

		unity.Debug.Log('[Awake诊断] 步骤2 viewLawnReturnButton 订阅完');
		if (artifactRepickButton != null)
			artifactRepickButton.onClick.AddListener(() -> OnArtifactRepickButtonClick.dispatch());

		unity.Debug.Log('[Awake诊断] 步骤3 artifactRepickButton 订阅完');
		if (artifactChoosingDialog != null) {
			artifactChoosingDialog.OnItemClicked.add(index -> OnArtifactChoosingItemClicked.dispatch(index));
			artifactChoosingDialog.OnItemPointerEnter.add(index -> OnArtifactChoosingItemEnter.dispatch(index));
			artifactChoosingDialog.OnItemPointerExit.add(index -> OnArtifactChoosingItemExit.dispatch(index));
			artifactChoosingDialog.OnBackButtonClicked.add(() -> OnArtifactChoosingBackClicked.dispatch());
		} else
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] artifactChoosingDialog 为空，跳过订阅');

		unity.Debug.Log('[Awake诊断] 步骤4 artifactChoosingDialog 订阅完');
		if (blueprintChoosePanel != null) {
			blueprintChoosePanel.OnStartButtonClick.add(() -> OnStartClick.dispatch());
			blueprintChoosePanel.OnViewLawnButtonClick.add(() -> OnViewLawnClick.dispatch());
			blueprintChoosePanel.OnRepickButtonClick.add(() -> OnRepickClick.dispatch());
			blueprintChoosePanel.OnCancelButtonClick.add(() -> OnCancelChooseClick.dispatch());
			blueprintChoosePanel.OnCommandBlockBlueprintPointerInteraction.add((e, i) -> OnCommandBlockPointerInteraction.dispatch(e, i));
			blueprintChoosePanel.OnCommandBlockBlueprintSelect.add(e -> OnCommandBlockSlotSelect.dispatch(e));
			blueprintChoosePanel.OnBlueprintPointerInteraction.add((index, data, i) -> OnBlueprintItemPointerInteraction.dispatch(index, data, i, false));
			blueprintChoosePanel.OnBlueprintSelect.add((index, data) -> OnBlueprintItemSelect.dispatch(index, data, false));
		} else
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] blueprintChoosePanel 为空，跳过订阅');

		unity.Debug.Log('[Awake诊断] 步骤5 blueprintChoosePanel 订阅完');
		if (commandBlockChoosePanel != null) {
			commandBlockChoosePanel.OnCancelButtonClick.add(() -> OnCommandBlockPanelCancelClick.dispatch());
			commandBlockChoosePanel.OnBlueprintPointerInteraction.add((index, data, i) -> OnBlueprintItemPointerInteraction.dispatch(index, data, i, true));
			commandBlockChoosePanel.OnBlueprintSelect.add((index, e) -> OnCommandBlockSlotSelect.dispatch(e));
		} else
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] commandBlockChoosePanel 为空，跳过订阅');

		unity.Debug.Log('[Awake诊断] 步骤6 commandBlockChoosePanel 订阅完');
		if (choosingViewAlmanacButton != null)
			choosingViewAlmanacButton.onClick.AddListener(() -> OnViewAlmanacClick.dispatch());
		else
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] choosingViewAlmanacButton 为空，跳过订阅');
		if (choosingViewStoreButton != null)
			choosingViewStoreButton.onClick.AddListener(() -> OnViewStoreClick.dispatch());
		else
			unity.Debug.LogWarning('[LevelUIBlueprintChoose] choosingViewStoreButton 为空，跳过订阅');
	}

	/** 在 root 子树里按名字找 GameObject 上的 Button（找不到返回 null）。 */
	private function findButtonInSubtree(root:Null<GameObject>, name:String):Null<unity.ui.Button> {
		if (root == null || root.transform == null)
			return null;
		var found:Null<unity.ui.Button> = null;
		var stack:Array<Transform> = [root.transform];
		var guard = 0;
		while (stack.length > 0 && guard++ < 512) {
			var tr = stack.pop();
			if (tr == null || tr.gameObject == null)
				continue;
			if (tr.gameObject.name == name) {
				var btn = tr.gameObject.GetComponent(unity.ui.Button);
				if (btn != null) {
					found = btn;
					break;
				}
			}
			for (c in tr.children)
				stack.push(c);
		}
		return found;
	}
	public function UpdateFrame(deltaTime:Float):Void
	{
		var targetSideUIBlend = sideUIDisplaying ? 1 : 0;
		var targetBlueprintChooseBlend = blueprintChooseDisplaying ? 1 : 0;
		var blendSpeed = 10; // const
		var sideUIBlendAddition = (targetSideUIBlend - sideUIBlend) * blendSpeed * deltaTime;
		var blueprintChooseAddition = (targetBlueprintChooseBlend - blueprintChooseBlend) * blendSpeed * deltaTime;
		SetSideUIBlend(sideUIBlend + sideUIBlendAddition);
		SetBlueprintChooseBlend(blueprintChooseBlend + blueprintChooseAddition);
	}

	// #region 事件回调
	private function OnBlueprintChooseArtifactSlotClickCallback(icon:ArtifactSlot):Void
	{
		OnArtifactSlotClick.dispatch(artifactSlotList.indexOfComponent(icon));
	}
	private function OnBlueprintChooseArtifactSlotPointerEnterCallback(icon:ArtifactSlot):Void
	{
		OnArtifactSlotPointerEnter.dispatch(artifactSlotList.indexOfComponent(icon));
	}
	private function OnBlueprintChooseArtifactSlotPointerExitCallback(icon:ArtifactSlot):Void
	{
		OnArtifactSlotPointerExit.dispatch(artifactSlotList.indexOfComponent(icon));
	}
	// #endregion

	// #region 事件
	public var OnStartClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnViewLawnClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnRepickClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnCancelChooseClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnCommandBlockPointerInteraction:FlxTypedSignal<PointerEventData->PointerInteraction->Void> = new FlxTypedSignal();
	public var OnCommandBlockSlotSelect:FlxTypedSignal<PointerEventData->Void> = new FlxTypedSignal();
	public var OnCommandBlockPanelCancelClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnArtifactSlotClick:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnArtifactSlotPointerEnter:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnArtifactSlotPointerExit:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnBlueprintItemPointerInteraction:FlxTypedSignal<Int->PointerEventData->PointerInteraction->Bool->Void> = new FlxTypedSignal();
	public var OnBlueprintItemSelect:FlxTypedSignal<Int->PointerEventData->Bool->Void> = new FlxTypedSignal();

	public var OnViewAlmanacClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnViewStoreClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnViewLawnReturnClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();

	public var OnArtifactChoosingItemClicked:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnArtifactChoosingItemEnter:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnArtifactChoosingItemExit:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnArtifactChoosingBackClicked:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var OnArtifactRepickButtonClick:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	// #endregion

	private var sideUIBlend:Float = 1;
	private var blueprintChooseBlend:Float;
	@:serializeField
	private var animator:Animator;
	// [Header("Blueprint Choose")]
	@:serializeField
	private var choosingBlueprintRoot:GameObject;
	@:serializeField
	private var runtimeBlueprintRoot:GameObject;
	@:serializeField
	private var chosenBlueprints:BlueprintList;
	@:serializeField
	private var viewLawnReturnButton:Button;
	@:serializeField
	private var viewLawnReturnBlocker:GameObject;
	@:serializeField
	private var artifactChoosingDialogObj:GameObject;
	@:serializeField
	private var artifactChoosingDialog:ArtifactChoosingDialog;
	@:serializeField
	private var movingBlueprints:MovingBlueprintList;
	@:serializeField
	private var blueprintChoosePanel:BlueprintChoosePanel;
	@:serializeField
	private var commandBlockChoosePanel:CommandBlockChoosePanel;
	@:serializeField
	private var choosingViewAlmanacButton:Button;
	@:serializeField
	private var choosingViewStoreButton:Button;
	@:serializeField
	private var sideUIDisplaying:Bool = true;
	@:serializeField
	private var blueprintChooseDisplaying:Bool;
	@:serializeField
	private var artifactSlotsRoot:GameObject;
	@:serializeField
	private var artifactSlotList:ElementListUI;
	@:serializeField
	private var artifactRepickButton:Button;
}

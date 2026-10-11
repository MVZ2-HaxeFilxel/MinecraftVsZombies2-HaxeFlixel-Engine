// Ported from: Assets/Scripts/MVZ2/Level/ControllerPart/LevelBlueprintChooseController.cs
package mvz2.level;

import mvz2.gamecontent.contraptions.VanillaContraptionID;
import mvz2.ui.*;
import mvz2.ui.level.*;
import mvz2logic.artifacts.Artifact;
import mvz2logic.artifacts.ArtifactDefinition;
import mvz2logic.audios.LogicSoundID;
import mvz2logic.blueprints.BlueprintChooseItem;
// PORT-NOTE: 原 import 写作 mvz2logic.blueprints.LogicBlueprintExt（该类型不存在且未被使用），故删除。
import mvz2logic.callbacks.LogicLevelCallbacks;
import mvz2logic.games.IGlobalGame;
import mvz2logic.inputs.InputHelper;
import mvz2logic.inputs.MouseButtons;
import mvz2logic.inputs.PointerInteraction;
import mvz2logic.inputs.PointerTypes;
import mvz2logic.level.LogicLevelExt;
import mvz2logic.localization.LogicStrings;
import mvz2logic.options.CommandBlockModes;
import mvz2logic.resources.SpriteReference;
import mvz2logic.saves.ArtifactSelectionItem;
import mvz2logic.saves.BlueprintChooseSaveItem;
import mvz2logic.saves.BlueprintSelection;
import pvzengine.NamespaceID;
import pvzengine.level.LevelEngine;
import unity.*;
import unity.Debug;
import unity.eventsystems.PointerEventData;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.LevelControllerPart.SerializableLevelControllerPart;
import mvz2.almanacs.AlmanacManager;
import mvz2.audios.SoundManager;
import mvz2.localization.LanguageManager;
import mvz2.managers.ResourceManager;
import mvz2.options.OptionsManager;
import mvz2.saves.SaveManager;
import mvz2logic.callbacks.LogicLevelCallbacks.GetBlueprintWarningsParams;
import mvz2logic.callbacks.LogicLevelCallbacks.PostBlueprintSelectionParams;
import pvzengine.base.Definition;
import unity.scenemanagement.SceneInstance.Scene;
import mvz2.gamecontent.contraptions.CommandBlock;
import unity.scenemanagement.SceneInstance;
import Main;
import mvz2.ui.Blueprint.BlueprintViewData;
import mvz2.ui.BlueprintDisplayer.ChoosingBlueprintViewData;
import mvz2.ui.Tooltip.TooltipContent;
import mvz2.ui.level.ArtifactSelectItem.ArtifactSelectItemViewData;
import mvz2.ui.level.ArtifactSlot.ArtifactViewData;
import mvz2.ui.level.BlueprintChoosePanel.BlueprintChoosePanelViewData;
import unity.Coroutine.CoroutineContext;
// PORT-NOTE: C# 的扩展方法（this 参数形式）在 Haxe 中需显式 using 才能以 `obj.Method()` 调用。
using mvz2logic.artifacts.LogicArtifactProps;      // GetSpriteReference / GetTransformSource
using mvz2logic.blueprints.LogicSeedProps;         // IsUpgradeBlueprint(this SeedDefinition)
using mvz2logic.games.LogicGameDefinitionsExt;     // GetArtifactDefinition(this IGameContent)
using mvz2logic.games.LogicGameExt;                // GetInnateBlueprints / GetInnateArtifacts
using mvz2logic.inputs.InputHelper;                // IsMouseButNotLeft(this PointerEventData)
using mvz2logic.options.LogicOptionExt;            // GetCommandBlockMode / AreBlueprintChooseWarningsDisabled
using mvz2logic.saves.LogicSaveExt;                // GetLastSelection / SetLastSelection / IsCommandBlockUnlocked 等

class LevelBlueprintChooseController extends LevelControllerPart
{
	// #region 生命周期
	override public function Init(controller:LevelController):Void
	{
		super.Init(controller);
		chooseUI.OnBlueprintItemPointerInteraction.add(UI_OnBlueprintPointerInteractionCallback);
		chooseUI.OnBlueprintItemSelect.add(UI_OnBlueprintSelectCallback);

		chooseUI.OnArtifactSlotClick.add(UI_OnArtifactSlotClickCallback);
		chooseUI.OnArtifactSlotPointerEnter.add(UI_OnArtifactSlotPointerEnterCallback);
		chooseUI.OnArtifactSlotPointerExit.add(UI_OnArtifactSlotPointerExitCallback);

		chooseUI.OnCommandBlockPointerInteraction.add(UI_OnCommandBlockPointerInteractionCallback);
		chooseUI.OnCommandBlockSlotSelect.add(UI_OnCommandBlockSelectCallback);
		chooseUI.OnCommandBlockPanelCancelClick.add(UI_OnCommandBlockPanelCancelClickCallback);
		chooseUI.OnStartClick.add(UI_OnStartClickCallback);
		chooseUI.OnViewLawnClick.add(UI_OnViewLawnClickCallback);
		chooseUI.OnRepickClick.add(UI_OnRepickClickCallback);
		chooseUI.OnCancelChooseClick.add(UI_OnCancelChooseClickCallback);
		chooseUI.OnViewAlmanacClick.add(UI_OnViewAlmanacClickCallback);
		chooseUI.OnViewStoreClick.add(UI_OnViewStoreClickCallback);

		chooseUI.OnViewLawnReturnClick.add(UI_OnViewLawnReturnClickCallback);

		chooseUI.OnArtifactRepickButtonClick.add(UI_OnArtifactRepickButtonClickCallback);
		chooseUI.OnArtifactChoosingItemClicked.add(UI_OnArtifactChooseItemClickCallback);
		chooseUI.OnArtifactChoosingItemEnter.add(UI_OnArtifactChooseItemPointerEnterCallback);
		chooseUI.OnArtifactChoosingItemExit.add(UI_OnArtifactChooseItemPointerExitCallback);
		chooseUI.OnArtifactChoosingBackClicked.add(UI_OnArtifactChooseReturnClickCallback);
	}
	override public function UpdateFrame(deltaTime:Float, simulationSpeed:Float):Void
	{
		super.UpdateFrame(deltaTime, simulationSpeed);
		if (chosenBlueprintControllers.length > 0 && isChoosingBlueprints && InputHelper.IsPointerDownByButton(PointerTypes.MOUSE, MouseButtons.RIGHT) && !HasPanelFlags() && !Main.Scene.HasDialog() && !Controller.IsOpeningExtraScene())
		{
			UnloadAllBlueprints();
			Level.PlaySound(LogicSoundID.tap);
		}
	}
	// #endregion

	// #region 对外接口
	public function ApplyChoose():Void
	{
		chooseUI.SetChosenBlueprintsVisible(false);
		// 如果根本没有进行选卡，那就不进行替换。
		if (choosingBlueprints == null)
			return;
		choosingBlueprints = null;

		// 替换蓝图。
		Level.SetupBattleBlueprints([for (e in chosenBlueprintControllers) e.ToChooseItem()]);
		ClearChosenBlueprints();

		// 替换制品。
		// PORT-NOTE: C# 重载 ReplaceArtifacts(this LevelEngine, IEnumerable<NamespaceID?>) 在 Haxe 中
		// 改名为 ReplaceArtifactsByIDs（接收 ArtifactDefinition 的版本保留原名）。
		Level.ReplaceArtifactsByIDs([for (i in chosenArtifacts) i != null ? i.id : null]);
		chosenArtifacts = null;
	}
	public function IsInteractable():Bool
	{
		return isChoosingBlueprints && !isViewingLawn;
	}
	public function ShowBlueprintChoosePanel(blueprints:Array<NamespaceID>):Void
	{
		chooseUI.SetSideUIBlend(0);
		chooseUI.SetBlueprintChooseBlend(0);

		isChoosingBlueprints = true;

		chooseUI.HideCommandBlockPanel();
		ClearPanelFlags();
		UI.SetBlueprintsSortingToChoosing(true);
		chooseUI.SetChosenBlueprintsVisible(true);

		// 继承制品。
		InheritArtifacts();

		Refresh(blueprints);

		// 边缘UI。
		chooseUI.SetSideUIDisplaying(true);
		chooseUI.SetBlueprintChooseDisplaying(true);
	}
	// #endregion

	// #region 蓝图UI和控制器
	private function CreateChosenBlueprint(seedPackIndex:Int, item:BlueprintChooseItem):Void
	{
		var seedID = item.id;
		var seedDef = Game.GetSeedDefinition(seedID);
		if (seedDef == null)
			return;

		// 创造已选蓝图UI。
		var blueprint = chooseUI.CreateChosenBlueprint();
		chooseUI.InsertChosenBlueprint(seedPackIndex, blueprint);
		blueprint.transform.position = chooseUI.GetChosenBlueprintPosition(seedPackIndex);

		// 绑定已选蓝图控制器。
		var controller = blueprint.GetComponent(ChosenBlueprintController);
		controller.CommandBlock = item.isCommandBlock;
		controller.Innate = item.innate;
		controller.Init(Controller, blueprint, seedPackIndex, seedDef);
		chosenBlueprintControllers.insert(seedPackIndex, controller);
		UpdateControllerIndexes();

		// 更新可选蓝图UI。
		UpdateBlueprintChooseItem(seedID, item.isCommandBlock);
	}
	private function UnbindChosenBlueprint(index:Int):Void
	{
		chooseUI.RemoveChosenBlueprintAt(index);

		// 解绑已选蓝图控制器。
		var controller = chosenBlueprintControllers[index];
		if (controller != null)
		{
			controller.Unload();
			chosenBlueprintControllers.remove(controller);
			UpdateControllerIndexes();
		}
	}
	private function ClearChosenBlueprints():Void
	{
		// 清除已选蓝图控制器。
		var i = chosenBlueprintControllers.length - 1;
		while (i >= 0)
		{
			var controller = chosenBlueprintControllers[i];
			controller.Unload();
			chooseUI.DestroyChosenBlueprintAt(i);
			i--;
		}
		chosenBlueprintControllers = [];
	}
	private function UpdateControllerIndexes():Void
	{
		for (i in 0...chosenBlueprintControllers.length)
		{
			chosenBlueprintControllers[i].Index = i;
		}
	}
	// #endregion

	// #region 选择蓝图
	public function ChooseBlueprint(index:Int):Void
	{
		var id = choosingBlueprints != null ? choosingBlueprints[index] : null;
		if (!NamespaceID.IsValid(id))
			return;
		ChooseBlueprintByID(id, false);
	}
	public function ChooseCommandBlockBlueprint(id:NamespaceID):Void
	{
		ChooseBlueprintByID(id, true);
	}
	// TODO-PORT: C# 重载 ChooseBlueprint(NamespaceID id, bool commandBlock)，重命名以区分。
	public function ChooseBlueprintByID(id:NamespaceID, commandBlock:Bool):Void
	{
		var seedSlots = Level.GetSeedSlotCount();
		var seedPackIndex = chosenBlueprintControllers.length;
		if (seedPackIndex >= seedSlots)
			return;
		var exists = false;
		for (i in chosenBlueprintControllers)
		{
			if (i.GetDefinitionID() == id && i.IsCommandBlock() == commandBlock)
			{
				exists = true;
				break;
			}
		}
		if (exists)
			return;
		LoadBlueprint(seedPackIndex, id, commandBlock);

		// 播放音效。
		Level.PlaySound(LogicSoundID.tap);
	}
	private function LoadBlueprint(seedPackIndex:Int, seedID:NamespaceID, commandBlock:Bool):Void
	{
		// 创建一个已选蓝图。
		// PORT-NOTE: C#（LevelBlueprintChooseController.cs:200）是
		// `new BlueprintChooseItem(seedID, isCommandBlock: commandBlock)`——命名实参只给了第二个形参，
		// innate 走默认值 false。这里原来写成 `(seedID, null, commandBlock)`：位置错位且把 null 当作
		// Bool 传给 cpp 目标，编译期即报 `null can't be used as basic type Bool`（neko 目标不报）。
		CreateChosenBlueprint(seedPackIndex, new BlueprintChooseItem(seedID, commandBlock));

		// 卸载原先位置的已选蓝图，用来进行移动动画。
		var blueprintUI = chooseUI.GetChosenBlueprintAt(seedPackIndex);
		chooseUI.RemoveChosenBlueprintAt(seedPackIndex);

		// 将蓝图移动到目标位置。
		// 获取源位置。
		var sourcePos = GetChoosingBlueprintSourcePosition(seedPackIndex, seedID, commandBlock);
		if (blueprintUI != null)
		{
			blueprintUI.transform.position = sourcePos;
		}

		// 加一个占位符，先把目标位置占住，移动完毕后再移除
		var targetPlaceHolder = chooseUI.CreateChosenBlueprint();
		targetPlaceHolder.UpdateView(BlueprintViewData.Empty);
		chooseUI.InsertChosenBlueprint(seedPackIndex, targetPlaceHolder);

		// 创建移动中的蓝图。
		var movingBlueprint = CreateMovingBlueprint();
		movingBlueprint.transform.position = sourcePos;
		if (blueprintUI != null)
		{
			movingBlueprint.SetBlueprint(blueprintUI);
		}
		// PORT-NOTE: C# 重载 SetMotion(Vector3, Transform) 在 Haxe 中改名为 SetMotionToTransform
		//（另一重载 (Vector3, Vector3) 改名 SetMotionToPosition）。
		movingBlueprint.SetMotionToTransform(sourcePos, targetPlaceHolder.transform);
		movingBlueprint.OnMotionFinished.add(function(movingBlueprint:MovingBlueprint)
		{
			// 移除占位符并替换为该蓝图
			if (blueprintUI != null)
			{
				var index = chooseUI.GetChosenBlueprintIndex(targetPlaceHolder);
				chooseUI.DestroyChosenBlueprint(targetPlaceHolder);
				chooseUI.InsertChosenBlueprint(index, blueprintUI);
			}
			DestroyMovingBlueprint(movingBlueprint);
		});
	}
	private function GetChoosingBlueprintSourcePosition(index:Int, seedID:NamespaceID, commandBlock:Bool):Vector3
	{
		var choosingBlueprintItem:Blueprint = null;
		if (commandBlock)
		{
			choosingBlueprintItem = chooseUI.GetCommandBlockSlotBlueprint();
		}
		else
		{
			var choosingIndex = choosingBlueprints.indexOf(seedID);
			choosingBlueprintItem = chooseUI.GetBlueprintChooseItem(choosingIndex);
		}

		if (choosingBlueprintItem != null)
		{
			return choosingBlueprintItem.transform.position;
		}
		else
		{
			return chooseUI.GetChosenBlueprintPosition(index);
		}
	}
	// #endregion

	// #region 取消选择
	public function UnchooseBlueprint(index:Int):Void
	{
		var choosingItem = chosenBlueprintControllers[index];
		if (choosingItem.Innate)
		{
			return;
		}
		UnloadBlueprint(index);

		Level.PlaySound(LogicSoundID.tap);
		Controller.HideTooltip();
	}

	private function UnloadBlueprint(index:Int):Void
	{
		// 获取当前已选的蓝图。
		var chosenController = chosenBlueprintControllers[index];
		var blueprintUI = chosenController.GetBlueprintUI();

		// 解绑当前已选的蓝图，用于移动。
		UnbindChosenBlueprint(index);

		// 获取移动的源位置。
		var sourcePos = blueprintUI != null ? blueprintUI.transform.position : Vector3.zero;

		// 获取要卸载的蓝图ID和命令方块状态。
		var id = chosenController.GetDefinitionID();
		var commandBlock = chosenController.IsCommandBlock();

		// 获取目标位置。
		var targetBlueprint:Blueprint = null;
		if (commandBlock)
		{
			targetBlueprint = chooseUI.GetCommandBlockSlotBlueprint();
		}
		else
		{
			var choosingIndex = choosingBlueprints.indexOf(id);
			targetBlueprint = chooseUI.GetBlueprintChooseItem(choosingIndex);
		}

		if (targetBlueprint == null)
		{
			// 如果目标位置不存在，则直接更新目标位置。
			UpdateBlueprintChooseItem(id, commandBlock);
			UnityObject.destroy(chosenController.gameObject);
		}
		else
		{
			// 如果目标位置存在，则创建移动蓝图用于移动动画。
			var movingBlueprint = CreateMovingBlueprint();
			movingBlueprint.transform.position = sourcePos;
			if (blueprintUI != null)
			{
				movingBlueprint.SetBlueprint(blueprintUI);
			}
			movingBlueprint.SetMotionToTransform(sourcePos, targetBlueprint.transform);
			movingBlueprint.OnMotionFinished.add(function(movingBlueprint:MovingBlueprint)
			{
				UpdateBlueprintChooseItem(id, commandBlock);
				DestroyMovingBlueprint(movingBlueprint);
			});
		}
	}
	// #endregion

	// #region 交换蓝图
	private function SwapChosenBlueprints(index1:Int, index2:Int):Void
	{
		// 位置相同则不交换。
		if (index1 == index2)
			return;
		var min = Std.int(Mathf.Min(index1, index2));
		var max = Std.int(Mathf.Max(index1, index2));
		MoveChosenBlueprint(min, max);
		MoveChosenBlueprint(max - 1, min);
	}
	private function MoveChosenBlueprint(fromIndex:Int, toIndex:Int):Void
	{
		// 位置相同则不移动。
		if (fromIndex == toIndex)
			return;

		// 获取源位置的蓝图UI和控制器。
		var controller = chosenBlueprintControllers[fromIndex];
		var blueprint = controller.GetBlueprintUI();

		// 移除源位置的蓝图UI和控制器。
		chosenBlueprintControllers.splice(fromIndex, 1);
		chooseUI.RemoveChosenBlueprintAt(fromIndex);

		// 将目标位置限制在一定范围内。
		toIndex = Std.int(Mathf.Clamp(toIndex, 0, chosenBlueprintControllers.length));

		// 将蓝图控制器和UI插入到目标位置。
		chosenBlueprintControllers.insert(toIndex, controller);
		if (blueprint != null)
		{
			chooseUI.InsertChosenBlueprint(toIndex, blueprint);
		}

		// 更新蓝图控制器的索引。
		UpdateControllerIndexes();
	}
	// #endregion

	// #region 移动蓝图
	private function CreateMovingBlueprint():MovingBlueprint
	{
		var movingBlueprint = chooseUI.CreateMovingBlueprint();
		movingBlueprints.push(movingBlueprint);
		return movingBlueprint;
	}
	private function DestroyMovingBlueprint(blueprint:MovingBlueprint):Void
	{
		movingBlueprints.remove(blueprint);
		chooseUI.RemoveMovingBlueprint(blueprint);
	}
	private function ClearMovingBlueprints():Void
	{
		for (movingBlueprint in movingBlueprints.copy())
		{
			chooseUI.RemoveMovingBlueprint(movingBlueprint);
		}
		movingBlueprints = [];
	}
	// #endregion

	// #region 替换
	public function ReplaceChoosingBlueprints(blueprints:Array<BlueprintChooseSaveItem>):Void
	{
		if (blueprints == null)
			return;
		// PORT-NOTE: C# 的 `async void` + `await ShowDialogMessageAsync` 在 Haxe 中同步执行。
		var errors:Array<String> = [];
		if (ValidateReplaceBlueprints(blueprints, errors))
		{
			var alignedBlueprints = [for (i in blueprints) if (NamespaceID.IsValid(i.id)) i];
			ReplaceBlueprints(alignedBlueprints);
		}
		else
		{
			var title = Main.LanguageManager._(LogicStrings.ERROR);
			var desc = Main.LanguageManager._(errors[0]);
			Main.Scene.ShowDialogMessageAsync(title, desc);
		}
	}
	public function ReplaceChoosingArtifacts(artifacts:Array<ArtifactSelectionItem>):Void
	{
		var errors:Array<String> = [];
		if (ValidateReplaceArtifacts(artifacts, errors))
		{
			var alignedArtifacts = [for (i in artifacts) if (NamespaceID.IsValid(i != null ? i.id : null)) i];
			ReplaceArtifacts(alignedArtifacts);
		}
		else
		{
			var title = Main.LanguageManager._(LogicStrings.ERROR);
			var desc = Main.LanguageManager._(errors[0]);
			Main.Scene.ShowDialogMessageAsync(title, desc);
		}
	}
	// TODO-PORT: C# 的 `out string? errorMessage` 改为可选数组参数。
	private function ValidateReplaceBlueprints(blueprints:Array<BlueprintChooseSaveItem>, outError:Array<String>):Bool
	{
		// 检查重复项（对应 C# 的 GroupBy(x => x).Any(g => g.Count() > 1)）。
		for (i in 0...blueprints.length)
		{
			for (j in (i + 1)...blueprints.length)
			{
				if (blueprints[i].Equals(blueprints[j]))
				{
					outError.push(REPLACE_ERROR_DUPLICATE_BLUEPRINTS);
					return false;
				}
			}
		}
		for (item in blueprints)
		{
			if (!Main.SaveManager.IsContraptionUnlocked(item.id))
			{
				outError.push(REPLACE_ERROR_CONTRAPTION_LOCKED);
				return false;
			}
		}
		var hasCommandBlock = false;
		for (item in blueprints)
		{
			if (item.isCommandBlock)
			{
				hasCommandBlock = true;
				break;
			}
		}
		if (hasCommandBlock && !Main.SaveManager.IsCommandBlockUnlocked())
		{
			outError.push(REPLACE_ERROR_CONTRAPTION_LOCKED);
			return false;
		}
		outError.push(null);
		return true;
	}
	// TODO-PORT: C# 的 `out string? errorMessage` 改为可选数组参数。
	private function ValidateReplaceArtifacts(artifacts:Array<ArtifactSelectionItem>, outError:Array<String>):Bool
	{
		for (i in 0...artifacts.length)
		{
			for (j in (i + 1)...artifacts.length)
			{
				if (artifacts[i] != null && artifacts[i].Equals(artifacts[j]))
				{
					outError.push(REPLACE_ERROR_DUPLICATE_ARTIFACTS);
					return false;
				}
			}
		}
		for (item in artifacts)
		{
			if (item != null && !Main.SaveManager.IsArtifactUnlocked(item.id))
			{
				outError.push(REPLACE_ERROR_ARTIFACT_LOCKED);
				return false;
			}
		}
		outError.push(null);
		return true;
	}
	private function ReplaceBlueprints(targetBlueprints:Array<BlueprintChooseSaveItem>):Void
	{
		// 移除所有正在移动的蓝图。
		ClearMovingBlueprints();

		var slotCount = Level.GetSeedSlotCount();

		var innateCount = 0;
		var chosen:Array<ChosenBlueprintController> = [];
		for (i in chosenBlueprintControllers)
		{
			if (i.Innate)
				innateCount++;
			else
				chosen.push(i);
		}
		var targets = targetBlueprints.slice(0, slotCount - innateCount);
		var retainBlueprints = [for (i in targets)
		{
			var found = false;
			for (item in chosen)
			{
				if (item.CompareChooseSaveItem(i))
				{
					found = true;
					break;
				}
			}
			if (found) i else null;
		}];
		retainBlueprints = [for (i in retainBlueprints) if (i != null) i];
		var pickBlueprints = [for (i in targets) if (retainBlueprints.indexOf(i) < 0) i];
		var removeBlueprints = [for (item in chosen)
		{
			var found = false;
			for (i in targets)
			{
				if (item.CompareChooseSaveItem(i))
				{
					found = true;
					break;
				}
			}
			if (!found) item else null;
		}];
		removeBlueprints = [for (i in removeBlueprints) if (i != null) i];

		// 首先卸下要移除的蓝图。
		for (item in removeBlueprints)
		{
			var existingIndex = chosenBlueprintControllers.indexOf(item);
			UnloadBlueprint(existingIndex);
		}
		// 然后装载要添加的蓝图。
		for (item in pickBlueprints)
		{
			var id = item.id;
			var targetIndex = targets.indexOf(item) + innateCount;
			LoadBlueprint(targetIndex, id, item.isCommandBlock);
		}
		// 最后将要保留的蓝图交换位置。
		for (item in retainBlueprints)
		{
			var targetIndex = targets.indexOf(item) + innateCount;
			var existingIndex = findChosenBlueprintIndex(item);
			SwapChosenBlueprints(existingIndex, targetIndex);
		}
	}
	private function findChosenBlueprintIndex(item:BlueprintChooseSaveItem):Int
	{
		for (i in 0...chosenBlueprintControllers.length)
		{
			if (chosenBlueprintControllers[i].CompareChooseSaveItem(item))
				return i;
		}
		return -1;
	}
	// #endregion

	// #region 替换制品
	private function ReplaceArtifacts(artifactsID:Array<ArtifactSelectionItem>):Void
	{
		var slotCount = Level.GetArtifactSlotCount();

		var innateCount = 0;
		for (i in chosenArtifacts)
		{
			if (i != null && i.innate)
				innateCount++;
		}

		var i = innateCount;
		while (i < slotCount)
		{
			if (i < artifactsID.length)
			{
				SetChosenArtifact(i, artifactsID[i] != null ? artifactsID[i].id : null);
			}
			else
			{
				SetChosenArtifact(i, null);
			}
			i++;
		}
	}
	// #endregion

	// #region 取消选择所有蓝图
	private function UnloadAllBlueprints():Void
	{
		// 移除所有正在移动的蓝图。
		ClearMovingBlueprints();

		// 卸下要移除的蓝图。
		var i = chosenBlueprintControllers.length - 1;
		while (i >= 0)
		{
			var controller = chosenBlueprintControllers[i];
			if (controller.Innate)
			{
				i--;
				continue;
			}
			UnloadBlueprint(i);
			i--;
		}
	}
	// #endregion

	// #region 刷新
	public function Refresh(blueprints:Array<NamespaceID>):Void
	{
		chooseUI.SetChosenBlueprintsSlotCount(Level.GetSeedSlotCount());
		RefreshChosenArtifacts();
		RefreshBlueprintChoosePanel(blueprints);
	}
	private function RefreshBlueprintChoosePanel(blueprints:Array<NamespaceID>):Void
	{
		// 保存之前的选卡ID。
		var chosenBlueprintBefore = [for (i in chosenBlueprintControllers) if (!i.Innate) i];

		// 更新可选蓝图。
		RefreshBlueprintsForChoose(blueprints);

		// 刷新所有已选蓝图。
		RefreshChosenBlueprints(chosenBlueprintBefore);

		// 刷新选卡界面的元素。
		RefreshChooseBlueprintPanelElements();

		// 如果有丢失的卡牌，取消他们的选择。
		var i = chosenBlueprintControllers.length - 1;
		while (i >= 0)
		{
			var item = chosenBlueprintControllers[i];
			if (item.Innate)
			{
				i--;
				continue;
			}
			if (choosingBlueprints.indexOf(item.GetDefinitionID()) >= 0)
			{
				i--;
				continue;
			}
			UnchooseBlueprint(i);
			i--;
		}
	}
	// #endregion

	// #region 刷新已选蓝图
	private function RefreshChosenBlueprints(chosenBlueprintBefore:Array<ChosenBlueprintController>):Void
	{
		// 清除所有已选蓝图和移动中的蓝图，然后重新设置已选蓝图。
		var seedSlotCount = Level.GetSeedSlotCount();
		ClearMovingBlueprints();
		ClearChosenBlueprints();
		var innateBlueprints = Main.Game.GetInnateBlueprints();
		for (i in 0...seedSlotCount)
		{
			if (i < innateBlueprints.length)
			{
				// 加入固有蓝图。
				// PORT-NOTE: C# `new BlueprintChooseItem(innateBlueprints[i], innate: true)`；
				// 参数槽为 (id, isCommandBlock, innate)，不可把 true 放进 isCommandBlock。
				CreateChosenBlueprint(i, new BlueprintChooseItem(innateBlueprints[i], false, true));
			}
			else if (i < innateBlueprints.length + chosenBlueprintBefore.length)
			{
				// 重新计算选卡映射。
				CreateChosenBlueprint(i, chosenBlueprintBefore[i - innateBlueprints.length].ToChooseItem());
			}
		}

		for (blueprintController in chosenBlueprintControllers)
		{
			if (blueprintController != null)
			{
				blueprintController.UpdateView();
			}
		}
	}
	// #endregion

	// #region 刷新选卡界面元素
	private function RefreshChooseBlueprintPanelElements():Void
	{
		var canRepick = Main.SaveManager.GetLastSelection() != null;
		var panelViewData = new BlueprintChoosePanelViewData();
		panelViewData.canViewLawn = Level.CurrentFlag > 0;
		panelViewData.hasCommandBlock = Main.SaveManager.IsCommandBlockUnlocked();
		panelViewData.canRepick = canRepick;
		chooseUI.UpdateBlueprintChooseElements(panelViewData);
		chooseUI.SetBlueprintChooseViewAlmanacButtonActive(Main.SaveManager.IsAlmanacUnlocked());
		chooseUI.SetBlueprintChooseViewStoreButtonActive(Main.SaveManager.IsStoreUnlocked());
	}
	// #endregion

	// #region 刷新可选蓝图
	private function RefreshBlueprintsForChoose(blueprints:Array<NamespaceID>):Void
	{
		// 更新可选蓝图ID。
		var orderedBlueprints:Array<NamespaceID> = [];
		Main.AlmanacManager.GetOrderedContraptionsByAlmanac(blueprints, orderedBlueprints);
		choosingBlueprints = orderedBlueprints.copy();

		// 更新可选蓝图UI。
		var isEndless = Level.IsEndless();
		var blueprintViewDatas = [for (id in choosingBlueprints) Main.AlmanacManager.GetChoosingBlueprintViewData(id, isEndless)];
		chooseUI.UpdateBlueprintChooseItems(blueprintViewDatas);
		for (i in 0...choosingBlueprints.length)
		{
			// PORT-NOTE: C# 重载 UpdateBlueprintChooseItem(int index) 在 Haxe 中改名为 UpdateBlueprintChooseItemAt。
			UpdateBlueprintChooseItemAt(i);
		}

		// 更新命令方块项。
		var commandBlockSlotViewData = Main.AlmanacManager.GetChoosingBlueprintViewData(VanillaContraptionID.commandBlock, isEndless);
		chooseUI.UpdateCommandBlockItem(commandBlockSlotViewData);
		UpdateCommandBlockItem();
	}
	private function UpdateBlueprintChooseItem(id:NamespaceID, commandBlock:Bool):Void
	{
		if (commandBlock)
		{
			UpdateCommandBlockItem();
		}
		else
		{
			var index = choosingBlueprints.indexOf(id);
			UpdateBlueprintChooseItemAt(index);
		}
	}
	// TODO-PORT: C# 重载 UpdateBlueprintChooseItem(int index)，重命名以区分。
	private function UpdateBlueprintChooseItemAt(index:Int):Void
	{
		var blueprintChooseItem = chooseUI.GetBlueprintChooseItem(index);
		if (blueprintChooseItem == null || choosingBlueprints == null)
			return;
		var id = choosingBlueprints[index];
		if (!NamespaceID.IsValid(id))
			return;
		var selected = false;
		for (i in chosenBlueprintControllers)
		{
			if (i.GetDefinitionID() == id && !i.IsCommandBlock())
			{
				selected = true;
				break;
			}
		}
		var notRecommended = Level.IsBlueprintNotRecommmended(id);

		blueprintChooseItem.SetDisabled(selected);
		blueprintChooseItem.SetRecharge((selected || notRecommended) ? 1 : 0);
	}
	private function UpdateCommandBlockItem():Void
	{
		var blueprintChooseItem = chooseUI.GetCommandBlockSlotBlueprint();
		if (blueprintChooseItem == null)
			return;
		var selected = false;
		for (i in chosenBlueprintControllers)
		{
			if (i.IsCommandBlock())
			{
				selected = true;
				break;
			}
		}
		blueprintChooseItem.SetDisabled(selected);
		blueprintChooseItem.SetRecharge(selected ? 1 : 0);
	}
	// #endregion

	// #region 能否选择
	private function CanChooseBlueprint(id:NamespaceID):Bool
	{
		if (id == null)
			return false;
		return true;
	}
	private function CanChooseCommandBlock():Bool
	{
		for (i in chosenBlueprintControllers)
		{
			if (i.IsCommandBlock())
				return false;
		}
		if (chosenBlueprintControllers.length >= Level.GetSeedSlotCount())
			return false;
		return true;
	}
	private function CanChooseCommandBlockBlueprint(id:NamespaceID):Bool
	{
		var seedDef = Main.Game.GetSeedDefinition(id);
		if (seedDef != null && seedDef.IsUpgradeBlueprint())
		{
			return false;
		}
		if (choosingBlueprints.indexOf(id) < 0)
		{
			return false;
		}
		return true;
	}
	// #endregion

	// #region 提示文本
	// TODO-PORT: C# 的 `out string? errorMessage` 改为可选数组参数。
	public function TryGetChosenBlueprintTooltipError(index:Int, outError:Array<String>):Bool
	{
		outError.push(null);
		var item = chosenBlueprintControllers[index];
		if (item == null)
			return false;
		if (item.Innate)
		{
			outError[0] = Main.LanguageManager._(LogicStrings.INNATE);
			return true;
		}
		return TryGetBlueprintTooltipError(item.GetDefinitionID(), outError, item.IsCommandBlock());
	}
	public function GetChosenBlueprintTooltipError(index:Int):String
	{
		var errors:Array<String> = [];
		if (TryGetChosenBlueprintTooltipError(index, errors) && errors.length > 0 && !(errors[0] == null || errors[0] == ""))
		{
			return errors[0];
		}
		return "";
	}
	// TODO-PORT: C# 的 `out string? errorMessage` 改为可选数组参数。
	public function TryGetChosenArtifactTooltipError(index:Int, outError:Array<String>):Bool
	{
		outError.push(null);
		var item = chosenArtifacts != null ? chosenArtifacts[index] : null;
		if (item == null)
			return false;
		if (item.innate)
		{
			outError[0] = Main.LanguageManager._(LogicStrings.INNATE);
			return true;
		}
		return false;
	}
	public function GetChosenArtifactTooltipError(index:Int):String
	{
		var errors:Array<String> = [];
		if (TryGetChosenArtifactTooltipError(index, errors) && errors.length > 0 && !(errors[0] == null || errors[0] == ""))
		{
			return errors[0];
		}
		return "";
	}
	// TODO-PORT: C# 的 `out string? errorMessage` 改为可选数组参数。
	public function TryGetBlueprintTooltipError(blueprintID:NamespaceID, outError:Array<String>, commandBlock:Bool):Bool
	{
		outError.push(null);
		var level = Controller.GetEngine();
		if (commandBlock)
		{
			var seedDef = Main.Game.GetSeedDefinition(blueprintID);
			if (seedDef != null && seedDef.IsUpgradeBlueprint())
			{
				outError[0] = Main.LanguageManager._(LogicStrings.TOOLTIP_CANNOT_IMITATE_THIS_CONTRAPTION);
				return true;
			}
		}
		if (level.IsBlueprintNotRecommmended(blueprintID))
		{
			outError[0] = Main.LanguageManager._(LogicStrings.NOT_RECOMMONEDED_IN_LEVEL);
			return true;
		}
		return false;
	}
	public function GetBlueprintTooltipError(blueprintID:NamespaceID, commandBlock:Bool):String
	{
		var errors:Array<String> = [];
		if (TryGetBlueprintTooltipError(blueprintID, errors, commandBlock) && errors.length > 0 && !(errors[0] == null || errors[0] == ""))
		{
			return errors[0];
		}
		return "";
	}
	// #endregion

	// #region 制品
	private function RefreshChosenArtifacts():Void
	{
		var hasArtifacts = Main.SaveManager.GetUnlockedArtifacts().length > 0;
		chooseUI.SetArtifactSlotsActive(hasArtifacts);

		var lastSelection = Main.SaveManager.GetLastSelection();
		chooseUI.SetArtifactRepickButtonActive(lastSelection != null && lastSelection.artifacts != null);

		var artifactCount = Level.GetArtifactSlotCount();
		chooseUI.ResetArtifactSlotCount(artifactCount);

		if (chosenArtifacts == null || artifactCount != chosenArtifacts.length)
		{
			RemapChosenArtifacts(artifactCount);
		}
		if (chosenArtifacts != null)
		{
			for (i in 0...chosenArtifacts.length)
			{
				var item = chosenArtifacts[i];
				if (item == null)
					continue;
				var sprite = GetArtifactIcon(item.id);
				var artifactViewData = new ArtifactViewData();
				artifactViewData.sprite = sprite;
				chooseUI.UpdateArtifactSlotAt(i, artifactViewData);
			}
		}
	}
	private function OpenChooseArtifactDialog(slotIndex:Int):Void
	{
		choosingArtifactSlotIndex = slotIndex;

		var choosing:Array<NamespaceID> = [];
		var unlockedArtifacts = Main.SaveManager.GetUnlockedArtifacts();
		Main.AlmanacManager.GetOrderedArtifactsByAlmanac(unlockedArtifacts, choosing);
		choosingArtifacts = choosing.copy();
		var viewDatas = [for (id in choosingArtifacts)
		{
			if (!NamespaceID.IsValid(id))
			{
				ArtifactSelectItemViewData.Empty;
			}
			else
			{
				var sprite = GetArtifactIcon(id);
				var disabled = !CanChooseArtifact(id);
				var data = new ArtifactSelectItemViewData();
				data.icon = sprite;
				data.selected = hasChosenArtifact(id);
				data.disabled = disabled;
				data;
			}
		}];
		chooseUI.ShowArtifactChoosePanel(viewDatas);
		AddPanelFlag(PanelFlags.Artifact);
		Main.SoundManager.Play2D(LogicSoundID.tap);
	}
	private function hasChosenArtifact(id:NamespaceID):Bool
	{
		for (i in chosenArtifacts)
		{
			if (i != null && i.id == id)
				return true;
		}
		return false;
	}
	private function ChooseArtifact(index:Int):Void
	{
		if (choosingArtifacts == null || chosenArtifacts == null)
			return;
		var id = choosingArtifacts[index];
		if (!CanChooseArtifact(id))
			return;
		var artifactAtSlot = chosenArtifacts[choosingArtifactSlotIndex];
		var isCancel = artifactAtSlot != null && artifactAtSlot.id == id;
		for (i in 0...chosenArtifacts.length)
		{
			var item = chosenArtifacts[i];
			if (item != null && item.id == id)
			{
				chosenArtifacts[i] = null;
				SetChosenArtifact(i, null);
			}
		}
		SetChosenArtifact(choosingArtifactSlotIndex, isCancel ? null : id);
		Controller.HideTooltip();
		CloseArtifactChoosePanel();
		Main.SoundManager.Play2D(LogicSoundID.tap);
	}
	private function InheritArtifacts():Void
	{
		var artifactCount = Level.GetArtifactSlotCount();
		chosenArtifacts = [];
		chosenArtifacts.resize(artifactCount);

		// 获取固有制品。
		var innateArtifacts = Main.Game.GetInnateArtifacts();
		var innateCount = innateArtifacts.length;
		for (i in 0...innateCount)
		{
			if (i >= chosenArtifacts.length)
				continue;
			chosenArtifacts[i] = new ArtifactChooseItem(innateArtifacts[i], true);
		}

		// 继承制品。
		if (Level.CurrentFlag > 0)
		{
			var notInnateArtifacts = [for (a in Level.GetArtifacts()) if (a != null && !containsID(innateArtifacts, a.Definition.GetID())) a];
			InheritChosenArtifacts(innateCount, notInnateArtifacts);
		}
		else
		{
			var lastSelection = Main.SaveManager.GetLastSelection();
			if (lastSelection != null && lastSelection.artifacts != null)
			{
				var notInnateArtifacts = lastSelection.artifacts;
				InheritLastChosenArtifacts(innateCount, notInnateArtifacts);
			}
		}
	}
	private function containsID(ids:Array<NamespaceID>, id:NamespaceID):Bool
	{
		for (i in ids)
		{
			if (i == id)
				return true;
		}
		return false;
	}
	private function InheritChosenArtifacts(startIndex:Int, targets:Array<Artifact>):Void
	{
		if (chosenArtifacts == null)
			return;
		for (i in 0...targets.length)
		{
			var artifact = targets[i];
			if (artifact == null)
				continue;
			var sourceID = artifact.GetTransformSource();
			var index = i + startIndex;
			if (index >= chosenArtifacts.length)
				continue;
			var id = sourceID;
			if (!NamespaceID.IsValid(sourceID))
			{
				id = artifact.Definition != null ? artifact.Definition.GetID() : null;
			}
			if (!NamespaceID.IsValid(id))
				continue;
			chosenArtifacts[index] = new ArtifactChooseItem(id, false);
		}
	}
	private function InheritLastChosenArtifacts(startIndex:Int, targets:Array<ArtifactSelectionItem>):Void
	{
		if (chosenArtifacts == null)
			return;
		for (i in 0...targets.length)
		{
			var artifact = targets[i];
			if (artifact == null)
				continue;
			var index = i + startIndex;
			if (index >= chosenArtifacts.length)
				continue;
			chosenArtifacts[index] = new ArtifactChooseItem(artifact.id, false);
		}
	}
	private function RemapChosenArtifacts(count:Int):Void
	{
		var newArray:Array<ArtifactChooseItem> = [];
		newArray.resize(count);
		if (chosenArtifacts != null)
		{
			var max = Std.int(Mathf.Min(chosenArtifacts.length, count));
			for (i in 0...max)
			{
				newArray[i] = chosenArtifacts[i];
			}
		}
		chosenArtifacts = newArray;
	}
	private function GetArtifactIcon(id:NamespaceID):Sprite
	{
		if (!NamespaceID.IsValid(id))
			return null;
		var def = Game.GetArtifactDefinition(id);
		if (def == null)
			return null;
		return GetArtifactIconFromDefinition(def);
	}
	// TODO-PORT: C# 重载 GetArtifactIcon(ArtifactDefinition def)，重命名以区分。
	private function GetArtifactIconFromDefinition(def:ArtifactDefinition):Sprite
	{
		if (def == null)
			return null;
		var spriteRef = def.GetSpriteReference();
		if (!SpriteReference.IsValid(spriteRef))
			return null;
		return Main.GetFinalSpriteFromRef(spriteRef);
	}
	private function CanChooseArtifact(id:NamespaceID):Bool
	{
		if (!NamespaceID.IsValid(id))
			return false;
		// 如果会取消选择固有制品，则无法选择。
		for (e in chosenArtifacts)
		{
			if (e != null && e.id == id && e.innate)
				return false;
		}
		return true;
	}
	private function CloseArtifactChoosePanel():Void
	{
		chooseUI.HideArtifactChoosePanel();
		RemovePanelFlag(PanelFlags.Artifact);
		choosingArtifactSlotIndex = -1;
		choosingArtifacts = null;
	}
	private function SetChosenArtifact(index:Int, id:NamespaceID):Void
	{
		if (chosenArtifacts == null)
			return;
		if (id == null)
		{
			chosenArtifacts[index] = null;
		}
		else
		{
			chosenArtifacts[index] = new ArtifactChooseItem(id, false);
		}
		var sprite = GetArtifactIcon(id);
		var artifactViewData = new ArtifactViewData();
		artifactViewData.sprite = sprite;
		chooseUI.UpdateArtifactSlotAt(index, artifactViewData);
	}
	// #endregion

	// #region UI层

	// #region 事件回调

	// #region 可选蓝图
	private function UI_OnBlueprintPointerInteractionCallback(index:Int, eventData:PointerEventData, interaction:PointerInteraction, commandBlock:Bool):Void
	{
		switch (interaction)
		{
			case PointerInteraction.Enter:
				var id = choosingBlueprints != null ? choosingBlueprints[index] : null;
				if (NamespaceID.IsValid(id))
				{
					var ui = commandBlock ? chooseUI.GetCommandBlockChooseItem(index) : chooseUI.GetBlueprintChooseItem(index);
					if (ui != null)
					{
						Controller.ShowTooltip(new ChooseBlueprintTooltipSource(this, id, ui, commandBlock));
					}
				}
			case PointerInteraction.Exit:
				Controller.HideTooltip();
			default:
		}
	}
	private function UI_OnBlueprintSelectCallback(index:Int, eventData:PointerEventData, commandBlock:Bool):Void
	{
		if (eventData.IsMouseButNotLeft())
			return;
		var id = choosingBlueprints != null ? choosingBlueprints[index] : null;
		if (commandBlock)
		{
			if (!CanChooseCommandBlockBlueprint(id))
				return;
			ChooseCommandBlockBlueprint(id);
			chooseUI.HideCommandBlockPanel();
			RemovePanelFlag(PanelFlags.CommandBlock);
		}
		else
		{
			if (!CanChooseBlueprint(id))
				return;
			ChooseBlueprint(index);
		}
	}
	// #endregion

	// #region 制品选择对话框
	private function UI_OnArtifactChooseItemPointerEnterCallback(index:Int):Void
	{
		var id = choosingArtifacts != null ? choosingArtifacts[index] : null;
		if (!NamespaceID.IsValid(id))
			return;
		var item = chooseUI.GetArtifactSelectItem(index);
		if (item == null)
		{
			Controller.HideTooltip();
			return;
		}
		Controller.ShowTooltip(new ChooseArtifactTooltipSource(this, id, item));
	}
	private function UI_OnArtifactChooseItemPointerExitCallback(index:Int):Void
	{
		Controller.HideTooltip();
	}
	private function UI_OnArtifactChooseItemClickCallback(index:Int):Void
	{
		ChooseArtifact(index);
	}
	private function UI_OnArtifactChooseReturnClickCallback():Void
	{
		CloseArtifactChoosePanel();
	}
	// #endregion

	// #region 界面元素
	private function UI_OnStartClickCallback():Void
	{
		var chosen = [for (i in chosenBlueprintControllers) i.ToChooseItem()];
		if (!Main.OptionsManager.AreBlueprintChooseWarningsDisabled())
		{
			var warnings:Array<String> = [];

			if (chosenBlueprintControllers.length < Level.GetSeedSlotCount())
			{
				warnings.push(Main.LanguageManager._(WARNING_SELECTED_BLUEPRINTS_NOT_FULL));
			}
			var blueprintsForChoose = [for (i in choosingBlueprints) if (CanChooseBlueprint(i)) i];
			Game.RunCallback(LogicLevelCallbacks.GET_BLUEPRINT_WARNINGS, new GetBlueprintWarningsParams(Level, blueprintsForChoose, chosen, warnings));
			for (warning in warnings)
			{
				var title = Main.LanguageManager._(LogicStrings.WARNING);
				var desc = warning;
				// PORT-NOTE: C# 中为 `await Main.Scene.ShowDialogSelectAsync(title, desc)`；Haxe 侧
				// Task shim 同步返回，用 awaitResult() 取回结果。
				var result = Main.Scene.ShowDialogSelectAsync(title, desc).awaitResult();
				if (!result)
					return;
			}
		}
		isChoosingBlueprints = false;

		// 保存上次选择
		var selectionBlueprints = [for (i in chosen) if (!i.innate) i.ToSaveItem()];
		var selectionArtifacts:Array<ArtifactSelectionItem> = [];
		for (e in chosenArtifacts)
		{
			if (NamespaceID.IsValid(e != null ? e.id : null) && !e.innate)
			{
				selectionArtifacts.push(i_toArtifactSelection(e));
			}
		}
		var selection = new BlueprintSelection(selectionBlueprints, selectionArtifacts);
		Main.SaveManager.SetLastSelection(selection);
		Game.RunCallback(LogicLevelCallbacks.POST_BLUEPRINT_SELECTION, new PostBlueprintSelectionParams(Level, chosen));
		Main.SaveManager.SaveToFile(); // 选卡之后保存游戏。

		StartCoroutine(BlueprintChosenTransition());
	}
	private static function i_toArtifactSelection(i:ArtifactChooseItem):ArtifactSelectionItem
	{
		return i != null ? new ArtifactSelectionItem(i.id) : null;
	}
	private function UI_OnViewLawnClickCallback():Void
	{
		isViewingLawn = true;
		viewLawnFinished = false;
		StartCoroutine(BlueprintChooseViewLawnTransition());
	}
	private function UI_OnViewLawnReturnClickCallback():Void
	{
		viewLawnFinished = true;
	}
	private function UI_OnCommandBlockPointerInteractionCallback(eventData:PointerEventData, interaction:PointerInteraction):Void
	{
		switch (interaction)
		{
			case PointerInteraction.Enter:
				var ui = chooseUI.GetCommandBlockSlotBlueprint();
				if (ui != null)
				{
					Controller.ShowTooltip(new ChooseBlueprintTooltipSource(this, VanillaContraptionID.commandBlock, ui, false));
				}
				else
				{
					Controller.HideTooltip();
				}
			case PointerInteraction.Exit:
				Controller.HideTooltip();
			default:
		}
	}
	private function UI_OnCommandBlockSelectCallback(eventData:PointerEventData):Void
	{
		if (eventData.IsMouseButNotLeft())
			return;
		if (!CanChooseCommandBlock())
			return;
		if (Main.OptionsManager.GetCommandBlockMode() == CommandBlockModes.PREVIOUS)
		{
			var previous:ChosenBlueprintController = chosenBlueprintControllers.length > 0 ? chosenBlueprintControllers[chosenBlueprintControllers.length - 1] : null;
			if (previous != null && !previous.IsCommandBlock())
			{
				var id = previous.GetDefinitionID();
				if (CanChooseCommandBlockBlueprint(id))
				{
					ChooseCommandBlockBlueprint(id);
					return;
				}
			}
		}
		ShowCommandBlockPanel();
	}
	private function ShowCommandBlockPanel():Void
	{
		chooseUI.ShowCommandBlockPanel();
		AddPanelFlag(PanelFlags.CommandBlock);
		var commandBlockViewDatas = [for (id in choosingBlueprints)
		{
			if (!NamespaceID.IsValid(id))
			{
				ChoosingBlueprintViewData.Empty;
			}
			else
			{
				var viewData = Main.AlmanacManager.GetChoosingBlueprintViewData(id, Level.IsEndless(), true);
				viewData.blueprint.iconGrayscale = true;
				var blueprintDef = Main.Game.GetSeedDefinition(id);
				if (blueprintDef != null && blueprintDef.IsUpgradeBlueprint())
				{
					// 命令方块不能模仿升级蓝图。
					viewData.disabled = true;
					viewData.recharge = 1;
				}
				var notRecommended = Level.IsBlueprintNotRecommmended(id);
				if (notRecommended)
				{
					viewData.recharge = 1;
				}
				viewData;
			}
		}];
		chooseUI.UpdateCommandBlockChooseItems(commandBlockViewDatas);
	}
	private function UI_OnCommandBlockPanelCancelClickCallback():Void
	{
		chooseUI.HideCommandBlockPanel();
		RemovePanelFlag(PanelFlags.CommandBlock);
	}
	private function UI_OnViewAlmanacClickCallback():Void
	{
		Controller.OpenAlmanac();
	}
	private function UI_OnViewStoreClickCallback():Void
	{
		Controller.OpenStore();
	}
	private function UI_OnRepickClickCallback():Void
	{
		var lastSelection = Main.SaveManager.GetLastSelection();
		if (lastSelection == null)
			return;
		var blueprints = lastSelection.blueprints;
		ReplaceChoosingBlueprints(blueprints);
	}
	private function UI_OnCancelChooseClickCallback():Void
	{
		UnloadAllBlueprints();
	}
	// #endregion

	// #region 制品槽
	private function UI_OnArtifactRepickButtonClickCallback():Void
	{
		var lastSelection = Main.SaveManager.GetLastSelection();
		if (lastSelection == null)
			return;
		var artifacts = lastSelection.artifacts;
		ReplaceChoosingArtifacts(artifacts);
	}
	private function UI_OnArtifactSlotPointerEnterCallback(index:Int):Void
	{
		var ui = chooseUI.GetArtifactSlotAt(index);
		if (ui == null)
			return;
		Controller.ShowTooltip(new ArtifactSlotTooltipSource(this, index, ui));
	}
	private function UI_OnArtifactSlotPointerExitCallback(index:Int):Void
	{
		Controller.HideTooltip();
	}
	private function UI_OnArtifactSlotClickCallback(index:Int):Void
	{
		var item = chosenArtifacts != null ? chosenArtifacts[index] : null;
		if (item != null && item.innate)
			return;
		OpenChooseArtifactDialog(index);
	}
	// #endregion

	// #endregion

	// #endregion

	// #region 序列化
	override public function GetSerializable():SerializableLevelControllerPart
	{
		var seri = new SerializableLevelBlueprintChooseController();
		seri.id = ID;
		return seri;
	}
	override public function LoadFromSerializable(seri:SerializableLevelControllerPart):Void
	{
	}
	// #endregion

	// #region 面板标识符
	private function AddPanelFlag(flag:Int):Void
	{
		panelFlags |= flag;
	}
	private function RemovePanelFlag(flag:Int):Void
	{
		panelFlags &= ~flag;
	}
	private function ClearPanelFlags():Void
	{
		panelFlags = 0;
	}
	private function HasPanelFlags():Bool
	{
		return panelFlags != 0;
	}
	// #endregion

	// #region 过渡
	private function BlueprintChosenTransition():Coroutine
	{
		return Coroutine.create(function(co:CoroutineContext)
		{
			chooseUI.SetBlueprintChooseDisplaying(false);
			UI.SetReceiveRaycasts(false);

			co.wait(1);
			// PORT-NOTE: C# 的 `yield return Controller.GameStartToLawnTransition();` 用
			//   co.waitCoroutine 表达。**不能**写成工厂轮询（`var inner = ...(); while (!inner.finished)
			//   co.waitFrames(1);`）—— 重放模型下每次恢复都会重新调用工厂，拿到全新的、无人驱动的
			//   子协程，循环永不退出（见 unity/Coroutine.hx 的取舍说明）。
			co.waitCoroutine(Controller.GameStartToLawnTransition());
		});
	}
	private function BlueprintChooseViewLawnTransition():Coroutine
	{
		return Coroutine.create(function(co:CoroutineContext)
		{
			chooseUI.SetBlueprintChooseDisplaying(false);
			UI.SetReceiveRaycasts(false);

			co.wait(1);
			// PORT-NOTE: `yield return Controller.MoveCameraToLawn();` —— 见 BlueprintChosenTransition 的说明。
			co.waitCoroutine(Controller.MoveCameraToLawn());
			UI.SetReceiveRaycasts(true);
			UI.SetBlueprintsSortingToChoosing(false);
			chooseUI.SetViewLawnReturnBlockerActive(true);
			// PORT-NOTE: C# 的 params string[] args 在 Haxe 侧是显式数组参数，需补空数组。
			Level.ShowAdvice(LogicStrings.CONTEXT_ADVICE, LogicStrings.ADVICE_CLICK_TO_CONTINUE, 1000, -1, []);
			while (!viewLawnFinished)
			{
				co.waitFrames(1);
			}
			UI.SetBlueprintsSortingToChoosing(true);
			chooseUI.SetViewLawnReturnBlockerActive(false);
			Level.HideAdvice();
			// PORT-NOTE: `yield return Controller.MoveCameraToChoose();` —— 见 BlueprintChosenTransition 的说明。
			co.waitCoroutine(Controller.MoveCameraToChoose());
			chooseUI.SetBlueprintChooseDisplaying(true);
			isViewingLawn = false;
			viewLawnFinished = false;
		});
	}
	// #endregion

	// #region 属性字段
	@:translateMsg("对话框内容")
	public static inline var WARNING_SELECTED_BLUEPRINTS_NOT_FULL:String = "你没有携带满蓝图，确认要继续吗？";
	@:translateMsg("关卡UI")
	public static inline var CHOOSE_ARTIFACT:String = "选择制品";
	@:translateMsg("重选蓝图的验证错误信息")
	public static inline var REPLACE_ERROR_DUPLICATE_BLUEPRINTS:String = "上一次选择的蓝图中包含多个相同的器械。";
	@:translateMsg("重选蓝图的验证错误信息")
	public static inline var REPLACE_ERROR_CONTRAPTION_LOCKED:String = "上一次选择的蓝图中包含未解锁的器械。";
	@:translateMsg("重选蓝图的验证错误信息")
	public static inline var REPLACE_ERROR_DUPLICATE_ARTIFACTS:String = "上一次选择的制品中包含多个相同的制品。";
	@:translateMsg("重选蓝图的验证错误信息")
	public static inline var REPLACE_ERROR_ARTIFACT_LOCKED:String = "上一次选择的制品中包含未解锁的制品。";
	private var chooseUI(get, never):LevelUIBlueprintChoose;
	function get_chooseUI():LevelUIBlueprintChoose return UI.BlueprintChoose;

	private var isChoosingBlueprints:Bool;
	private var panelFlags:Int = 0;
	private var choosingBlueprints:Array<NamespaceID>;
	private var chosenBlueprintControllers:Array<ChosenBlueprintController> = [];
	private var movingBlueprints:Array<MovingBlueprint> = [];

	private var chosenArtifacts:Array<ArtifactChooseItem>;
	private var choosingArtifactSlotIndex:Int;
	private var choosingArtifacts:Array<NamespaceID>;

	private var isViewingLawn:Bool;
	private var viewLawnFinished:Bool;
	// #endregion

	// 供同模块的 ArtifactSlotTooltipSource 访问（对应 C# 的私有嵌套类访问外部类私有字段）。
	public function getChosenArtifactAt(index:Int):ArtifactChooseItem
	{
		return chosenArtifacts != null ? chosenArtifacts[index] : null;
	}
}

@:rtti
class SerializableLevelBlueprintChooseController extends SerializableLevelControllerPart
{
	public function new()
	{
		super();
	}
}

class ArtifactChooseItem
{
	public var id:NamespaceID;
	public var innate:Bool;
	public function new(id:NamespaceID, innate:Bool)
	{
		this.id = id;
		this.innate = innate;
	}
}

class PanelFlags
{
	public static inline var None:Int = 0;
	public static inline var Artifact:Int = 1;
	public static inline var CommandBlock:Int = 1 << 1;
}

// PORT-NOTE: C# 中该类是 LevelBlueprintChooseController 的私有嵌套类（与 BlueprintController.cs
// 中的同名词级联类同名）。Haxe 无嵌套类，且同包内不允许重名，故改名以区分。
class ChooseBlueprintTooltipSource implements ITooltipSource
{
	public function new(controller:LevelBlueprintChooseController, blueprintID:NamespaceID, target:ITooltipTarget, commandBlock:Bool)
	{
		this.controller = controller;
		this.blueprintID = blueprintID;
		this.target = target;
		this.commandBlock = commandBlock;
	}
	public function GetCamera():Camera
	{
		return controller.Controller.GetCamera();
	}
	public function GetTarget():ITooltipTarget
	{
		return target;
	}
	public function GetContent():TooltipContent
	{
		var name = controller.Main.ResourceManager.GetBlueprintName(blueprintID, commandBlock);
		var tooltip = controller.Main.ResourceManager.GetBlueprintTooltip(blueprintID);
		var error = controller.GetBlueprintTooltipError(blueprintID, commandBlock);
		var content = new TooltipContent();
		content.name = name;
		content.error = error;
		content.description = tooltip;
		return content;
	}
	private var controller:LevelBlueprintChooseController;
	private var blueprintID:NamespaceID;
	private var target:ITooltipTarget;
	private var commandBlock:Bool;
}

// PORT-NOTE: 同 BlueprintTooltipSource，C# 中是 LevelBlueprintChooseController 的私有嵌套类；
// 与 LevelController_Tooltip.cs 中的同名嵌套类冲突，故改名。
class ChooseArtifactTooltipSource implements ITooltipSource
{
	public function new(controller:LevelBlueprintChooseController, artifactID:NamespaceID, target:ITooltipTarget)
	{
		this.controller = controller;
		this.artifactID = artifactID;
		this.target = target;
	}
	public function GetCamera():Camera
	{
		return controller.Controller.GetCamera();
	}
	public function GetTarget():ITooltipTarget
	{
		return target;
	}
	public function GetContent():TooltipContent
	{
		var name = controller.Main.ResourceManager.GetArtifactName(artifactID);
		var tooltip = controller.Main.ResourceManager.GetArtifactTooltip(artifactID);
		var error = "";
		var content = new TooltipContent();
		content.name = name;
		content.error = error;
		content.description = tooltip;
		return content;
	}
	private var controller:LevelBlueprintChooseController;
	private var artifactID:NamespaceID;
	private var target:ITooltipTarget;
}

class ArtifactSlotTooltipSource implements ITooltipSource
{
	public function new(controller:LevelBlueprintChooseController, index:Int, target:ITooltipTarget)
	{
		this.controller = controller;
		this.index = index;
		this.target = target;
	}
	public function GetCamera():Camera
	{
		return controller.Controller.GetCamera();
	}
	public function GetTarget():ITooltipTarget
	{
		return target;
	}
	public function GetContent():TooltipContent
	{
		var artifact = controller.getChosenArtifactAt(index);
		var artifactID = artifact != null ? artifact.id : null;
		if (NamespaceID.IsValid(artifactID))
		{
			var name = controller.Main.ResourceManager.GetArtifactName(artifactID);
			var tooltip = controller.Main.ResourceManager.GetArtifactTooltip(artifactID);
			var error = controller.GetChosenArtifactTooltipError(index);
			var content = new TooltipContent();
			content.name = name;
			content.error = error;
			content.description = tooltip;
			return content;
		}
		else
		{
			var content = new TooltipContent();
			content.name = controller.Main.LanguageManager._(LevelBlueprintChooseController.CHOOSE_ARTIFACT);
			content.error = "";
			content.description = "";
			return content;
		}
	}
	private var controller:LevelBlueprintChooseController;
	private var index:Int;
	private var target:ITooltipTarget;
}

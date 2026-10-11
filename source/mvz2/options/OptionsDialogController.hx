// Ported from: Assets/Scripts/MVZ2/Options/Dialog/OptionsDialogController.cs
package mvz2.options;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2.ui.OptionsDialog.Page;  // SUBIMPORT
import mvz2.ui.OptionsDialogMainPage.SliderType;  // SUBIMPORT
import mvz2.ui.OptionsDialogMainPage.TextButtonType;  // SUBIMPORT
import mvz2.ui.arcade.IndexArcadePage.ButtonType;  // SUBIMPORT
import mvz2.ui.OptionsDialogMainPage.ToggleType;  // SUBIMPORT
import mvz2logic.options.IOptionContext.IOptionContextMap;  // SUBIMPORT
import mvz2logic.options.IOptionContext.IOptionContextLevel;  // SUBIMPORT
import mvz2.cameras.ResolutionManager;
import mvz2.gamecontent.stages.VanillaStageID;
import mvz2.managers.MainManager;
import mvz2.ui.OptionsDialog;
import mvz2.ui.OptionsDialogMainPage;
import mvz2.ui.OptionsDialogMoreOptionsPage;
import mvz2.ui.OptionWidgets;
import mvz2.ui.SimpleTooltipSource;
import mvz2.ui.Tooltip.TooltipContent;
import mvz2.ui.TooltipHandler;
import mvz2logic.Global;
import mvz2logic.LogicMain;
import mvz2logic.audios.LogicSoundID;
import mvz2logic.localization.LogicStrings;
import mvz2logic.options.IOptionContext;
import mvz2logic.options.IOptionContext.IOptionContextLevel;  // IMPORTFIX
import mvz2logic.options.IOptionContext.IOptionContextMap;  // IMPORTFIX
import mvz2logic.options.LogicOptionExt;
import mvz2logic.options.LogicOptionWidgetID;
import mvz2logic.options.OptionButtonDefinition;  // IMPORTFIX
import mvz2logic.options.OptionDropdownDefinition;  // IMPORTFIX
import mvz2logic.options.OptionSliderDefinition;  // IMPORTFIX
import mvz2logic.options.OptionToggleDefinition;  // IMPORTFIX
import mvz2logic.options.OptionWidgetDefinition;  // IMPORTFIX
import mvz2logic.options.OptionWidgetsViewData;
import mvz2logic.options.MoreOptionsCategoryViewData;
import mvz2logic.options.MoreOptionsViewData;
import mvz2logic.options.OptionWidgetType;
import pvzengine.NamespaceID;
import tools.ObjectExtensions;
import unity.Mathf;
import unity.UnityObject;
using mvz2logic.options.LogicOptionExt;  // EXTUSING
using mvz2logic.games.LogicGameExt;  // EXTUSING
using mvz2logic.commands.LogicOptionWidgetProps;  // EXTUSING
using mvz2logic.difficulties.LogicDifficultyProps;  // EXTUSING
using mvz2logic.games.LogicGameDefinitionsExt;  // EXTUSING
using mvz2logic.level.LogicLevelExt;  // EXTUSING
using mvz2logic.saves.LogicSaveExt;  // EXTUSING
using pvzengine.PropertyKeyHelper;  // EXTUSING

// PORT-NOTE: 依赖 mvz2.ui（OptionsDialog / OptionsDialogMainPage / OptionWidgets 等）
// 与 mvz2logic.options 的控件定义类型，均由其他工作包提供。
class OptionsDialogController extends unity.MonoBehaviour {
    public function new() {
        super();
    }

    public function Open(context:IOptionContext):Void {
        this.context = context;

        UpdateMainPageWidgets();
        UpdateMoreOptionsPageWidgets();
    }
    public function IsOpen():Bool {
        return context != null;
    }
    public function Close():Void {
        if (context == null)
            return;
        var needsReload = context.NeedsReload();
        context.FlushCachedOptions(Main.OptionsManager);
        context = null;
        SaveOptions();
        OnClose.dispatch(needsReload);
    }
    private function Awake():Void {
        ui.Main.OnToggleValueChanged.add(OnMainPageToggleValueChangedCallback);
        ui.Main.OnSliderValueChanged.add(OnMainPageSliderValueChangedCallback);
        ui.Main.OnSliderEnd.add(OnMainPageSliderEndCallback);
        ui.Main.OnButtonClick.add(OnMainPageButtonClickCallback);
        ui.Main.OnTooltipShow.add(OnTooltipShowCallback);
        ui.Main.OnTooltipHide.add(OnTooltipHideCallback);

        ui.MoreOptions.OnBackClick.add(OnMoreOptionsBackClickCallback);

        ui.MoreOptions.OnToggleValueChanged.add(OnMoreOptionsToggleValueChangedCallback);
        ui.MoreOptions.OnSliderValueChanged.add(OnMoreOptionsSliderValueChangedCallback);
        ui.MoreOptions.OnSliderEnd.add(OnMoreOptionsSliderEndCallback);
        ui.MoreOptions.OnDropdownValueChanged.add(OnMoreOptionsDropdownValueChangedCallback);
        ui.MoreOptions.OnButtonClick.add(OnMoreOptionsButtonClickCallback);
        ui.MoreOptions.OnTooltipShow.add(OnTooltipShowCallback);
        ui.MoreOptions.OnTooltipHide.add(OnTooltipHideCallback);
    }
    private function OnEnable():Void {
        ResolutionManager.OnResolutionChanged.add(OnResolutionChangedCallback);
    }
    private function OnDisable():Void {
        ResolutionManager.OnResolutionChanged.remove(OnResolutionChangedCallback);
    }

    // #region 事件回调
    private function OnResolutionChangedCallback(width:Int, height:Int):Void {
        RefreshResolutionDropdown();
    }
    private function RefreshResolutionDropdown():Void {
        if (context == null)
            return;
        var id = LogicOptionWidgetID.resolution;
        var definition = Main.Game.GetOptionWidgetDefinition(id);
        if (!Std.isOfType(definition, OptionDropdownDefinition))
            return;
        var dropdown:OptionDropdownDefinition = cast definition;
        var widgets = ui.MoreOptions.GetWidgetsByID(id);
        if (!unity.UnityObject.exists(widgets))
            return;
        var items:Array<String> = [];
        dropdown.FillItems(context, items);
        widgets.SetDropdownOptions(items);

        var value = dropdown.GetValue(context);
        widgets.SetDropdownValue(value);
    }

    private function OnMainPageToggleValueChangedCallback(type:ToggleType, value:Bool):Void {
        switch (type) {
            case ToggleType.SwapTrigger:
                {
                    Main.OptionsManager.SetSwapTrigger(value);
                    UpdateSwapTriggerToggle(value);
                    SaveOptions();
                }
            case ToggleType.PauseOnFocusLost:
                {
                    Main.OptionsManager.SetPauseOnFocusLost(value);
                    UpdatePauseOnFocusLostToggle(value);
                    SaveOptions();
                }
            default:
        }
    }
    private function OnMainPageSliderValueChangedCallback(type:SliderType, value:Float):Void {
        switch (type) {
            case SliderType.Music:
                {
                    Main.OptionsManager.SetMusicVolume(value);
                    UpdateMusicSlider(value);
                }
            case SliderType.Sound:
                {
                    Main.OptionsManager.SetSoundVolume(value);
                    UpdateSoundSlider(value);
                }
            case SliderType.FastForward:
                {
                    var multi = ValueToFastForwardMultiplier(GetFastwoardMultiplierStart(), value);
                    Main.OptionsManager.SetFastForwardMultiplier(multi);
                    UpdateFastforwardSlider(multi);
                }
            default:
        }
    }
    private function OnMainPageSliderEndCallback(type:SliderType, value:Float):Void {
        switch (type) {
            case SliderType.Music, SliderType.FastForward:
                SaveOptions();
            case SliderType.Sound:
                Main.SoundManager.Play2D(LogicSoundID.click);
                SaveOptions();
            default:
        }
    }
    private function OnMainPageButtonClickCallback(type:ButtonType):Void {
        // PORT-NOTE: C# 该回调为 async void 并 await 了对话框/退出关卡操作；
        // Haxe 无 async，改为顺序调用（Scene.ExitLevel 等由对应实现自行等待）。
        switch (type) {
            case ButtonType.Back:
                Close();
            case ButtonType.Difficulty:
                {
                    Main.OptionsManager.CycleDifficulty();
                    UpdateDifficultyButton(Main.OptionsManager.GetDifficulty());
                    SaveOptions();
                    var level = Main.LevelManager.GetLevelController();
                    if (unity.UnityObject.exists(level)) {
                        level.UpdateDifficulty();
                    }
                }
            case ButtonType.MoreOptions:
                ui.SetPage(Page.More);

            case ButtonType.LeaveLevel:
                {
                    var level = Main.LevelManager.GetLevelController();
                    if (!unity.UnityObject.exists(level)) {
                        return;
                    }
                    // PORT-NOTE: C# 的 ShowDialogSelect 返回 bool（同步等待选择）；
                    // 移植层为回调式 API，故把“确认退出后”的逻辑放进回调。
                    var doLeaveLevel = function():Void {
                        if (level.IsGameStarted()) {
                            Main.LevelManager.SaveLevel();
                        }
                        level.ExitLevel();
                    };
                    if (level.IsGameStarted() || level.GetCurrentFlag() > 0) {
                        var title = Main.LanguageManager._(LogicStrings.BACK);
                        var desc = Main.LanguageManager._(DIALOG_DESC_LEAVE_LEVEL);

                        Main.Scene.ShowDialogSelect(title, desc, function(result:Bool):Void {
                            if (result)
                                doLeaveLevel();
                        });
                    }
                    else {
                        doLeaveLevel();
                    }
                }
            case ButtonType.Restart:
                {
                    var level = Main.LevelManager.GetLevelController();
                    if (!unity.UnityObject.exists(level))
                        return;
                    level.ShowRestartConfirmDialog();
                }
            default:
        }
    }
    private function OnMoreOptionsBackClickCallback():Void {
        ui.SetPage(Page.Main);
    }

    private function OnMoreOptionsToggleValueChangedCallback(widgets:OptionWidgets, value:Bool):Void {
        if (context == null)
            return;
        var id = widgets.GetOptionID();
        var definition = Main.Game.GetOptionWidgetDefinition(id);
        if (!Std.isOfType(definition, OptionToggleDefinition))
            return;
        var toggle:OptionToggleDefinition = cast definition;

        toggle.OnValueChanged(context, value);
    }
    private function OnMoreOptionsSliderValueChangedCallback(widgets:OptionWidgets, value:Float):Void {
        if (context == null)
            return;
        var id = widgets.GetOptionID();
        var definition = Main.Game.GetOptionWidgetDefinition(id);
        if (!Std.isOfType(definition, OptionSliderDefinition))
            return;
        var slider:OptionSliderDefinition = cast definition;

        slider.OnValueChanged(context, value);

        var sliderValue = slider.GetLabelValue(context, value);
        var label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_NAME, definition.GetLabel(), [sliderValue]);
        widgets.SetSliderText(label);
    }
    private function OnMoreOptionsSliderEndCallback(widgets:OptionWidgets, value:Float):Void {
        if (context == null)
            return;
        var id = widgets.GetOptionID();
        var definition = Main.Game.GetOptionWidgetDefinition(id);
        if (!Std.isOfType(definition, OptionSliderDefinition))
            return;
        var slider:OptionSliderDefinition = cast definition;

        slider.OnEndEdit(context, value);
    }
    private function OnMoreOptionsDropdownValueChangedCallback(widgets:OptionWidgets, value:Int):Void {
        if (context == null)
            return;
        var id = widgets.GetOptionID();
        var definition = Main.Game.GetOptionWidgetDefinition(id);
        if (!Std.isOfType(definition, OptionDropdownDefinition))
            return;
        var dropdown:OptionDropdownDefinition = cast definition;

        dropdown.OnValueChanged(context, value);
    }
    private function OnMoreOptionsButtonClickCallback(widgets:OptionWidgets):Void {
        if (context == null)
            return;
        var id = widgets.GetOptionID();
        var definition = Main.Game.GetOptionWidgetDefinition(id);
        if (!Std.isOfType(definition, OptionButtonDefinition))
            return;
        var button:OptionButtonDefinition = cast definition;

        button.OnClick();

        var labelValue = button.GetLabelValue(context);
        var label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_NAME, definition.GetLabel(), [labelValue]);
        widgets.SetButtonText(label);
    }
    private function OnTooltipShowCallback(handler:TooltipHandler):Void {
        if (handler.text == null || handler.text.length == 0)
            return;
        var text:String;
        if (handler.context == null || handler.context.length == 0) {
            text = Main.LanguageManager._(handler.text);
        } else {
            text = Main.LanguageManager._p(handler.context, handler.text);
        }
        var camera = ui.GetCamera();
        if (!unity.UnityObject.exists(camera))
            return;
        var content = new TooltipContent();
        content.description = text;
        Main.Scene.ShowTooltip(new SimpleTooltipSource(camera, handler, content));
    }
    private function OnTooltipHideCallback(handler:TooltipHandler):Void {
        Main.Scene.HideTooltip();
    }
    // #endregion
    private function SaveOptions():Void {
        Main.OptionsManager.SaveOptions();
    }
    // #region 主界面
    private function UpdateMainPageWidgets():Void {
        // Main
        UpdateMusicSlider(Main.OptionsManager.GetMusicVolume());
        UpdateSoundSlider(Main.OptionsManager.GetSoundVolume());
        UpdateFastforwardSlider(Main.OptionsManager.GetFastForwardMultiplier());

        UpdateSwapTriggerToggle(Main.OptionsManager.IsTriggerSwapped());
        UpdatePauseOnFocusLostToggle(Main.OptionsManager.GetPauseOnFocusLost());

        UpdateMoreOptionsButton();

        UpdateDifficultyButton(Main.OptionsManager.GetDifficulty());
        UpdateRestartButton();

        UpdateLeaveLevelButton();

        UpdateBackButton();

        if (Std.isOfType(context, IOptionContextMap)) {
            ui.Main.SetButtonActive(ButtonType.Restart, false);
            ui.Main.SetButtonActive(ButtonType.LeaveLevel, false);
        } else if (Std.isOfType(context, IOptionContextLevel)) {
            var level = Main.LevelManager.GetLevelController();
            var isInLevel = unity.UnityObject.exists(level) && (level.IsGameStarted() || level.GetCurrentFlag() > 0);
            ui.Main.SetButtonActive(ButtonType.Difficulty, !isInLevel);
            ui.Main.SetButtonActive(ButtonType.Restart, isInLevel);
            ui.Main.SetButtonActive(ButtonType.LeaveLevel, true);
        } else {
            ui.Main.SetButtonActive(ButtonType.Restart, false);
            ui.Main.SetButtonActive(ButtonType.LeaveLevel, false);
        }


        var mainPage = ui.Main;
        var mobile = Main.IsMobile();
        mainPage.SetToggleActive(ToggleType.SwapTrigger, Main.SaveManager.IsTriggerUnlocked());
    }
    private function UpdateMusicSlider(value:Float):Void {
        UpdateMainPageSliderValue(value, OPTION_MUSIC, SliderType.Music);
    }
    private function UpdateSoundSlider(value:Float):Void {
        UpdateMainPageSliderValue(value, OPTION_SOUND, SliderType.Sound);
    }
    private function UpdateFastforwardSlider(multi:Float):Void {
        var sliderMultiplierEnd = FASTFORWARD_MULTIPLIER_END;
        var sliderMultiplierStart = GetFastwoardMultiplierStart();
        var sliderMultiplierRange = sliderMultiplierEnd - sliderMultiplierStart;

        var value = FastForwardMultiplierToValue(sliderMultiplierStart, multi);

        var valueText = LogicMain.GetFloatPercentageText(multi);
        var text = Main.LanguageManager._(OPTION_FASTFORWARD_MULTIPLIER, [valueText]);

        var sliderStart = 0;
        var sliderEnd = Mathf.RoundToInt(sliderMultiplierRange / FASTFORWARD_STEP);
        ui.Main.SetSliderRange(SliderType.FastForward, sliderStart, sliderEnd, true);
        ui.Main.SetSliderValue(SliderType.FastForward, value);
        ui.Main.SetSliderText(SliderType.FastForward, text);
    }
    private function ValueToFastForwardMultiplier(startMultiplier:Float, value:Float):Float {
        return startMultiplier + FASTFORWARD_STEP * value;
    }
    private function FastForwardMultiplierToValue(startMultiplier:Float, multi:Float):Float {
        return Mathf.RoundToInt((multi - startMultiplier) / FASTFORWARD_STEP);
    }
    private function GetFastwoardMultiplierStart():Float {
        return FASTFORWARD_MULTIPLIER_START;
    }
    private function ValueToAnimationFrequency(value:Float):Float {
        return value;
    }
    private function AnimationFrequencyToValue(frequency:Float):Float {
        return frequency;
    }
    private function UpdateSwapTriggerToggle(value:Bool):Void {
        UpdateMainPageToggle(value, OPTION_SWAP_TRIGGER, ToggleType.SwapTrigger);
    }
    private function UpdatePauseOnFocusLostToggle(value:Bool):Void {
        UpdateMainPageToggle(value, OPTION_PAUSE_ON_FOCUS_LOST, ToggleType.PauseOnFocusLost);
    }
    private function UpdateMoreOptionsButton():Void {
        var text = Main.LanguageManager._(OPTION_MORE_OPTIONS);
        ui.Main.SetButtonText(TextButtonType.MoreOptions, text);
    }
    private function UpdateDifficultyButton(value:NamespaceID):Void {
        var valueText = GetDifficultyText(value);
        var text = Main.LanguageManager._(OPTION_DIFFICULTY, [valueText]);
        ui.Main.SetButtonText(TextButtonType.Difficulty, text);
    }
    private function UpdateRestartButton():Void {
        var text = Main.LanguageManager._(OPTION_RESTART);
        ui.Main.SetButtonText(TextButtonType.Restart, text);
    }
    private function UpdateLeaveLevelButton():Void {
        var textKey = Global.Saves.IsLevelCleared(VanillaStageID.prologue) ? LogicStrings.BACK_TO_MAP : LogicStrings.BACK_TO_MAINMENU;
        var text = Main.LanguageManager._(textKey);
        ui.Main.SetButtonText(TextButtonType.LeaveLevel, text);
    }
    private function UpdateBackButton():Void {
        var text = Main.LanguageManager._(OPTION_BACK);
        ui.Main.SetButtonText(TextButtonType.Back, text);
    }
    // #endregion

    // #region 更多选项
    private function UpdateMoreOptionsPageWidgets():Void {
        if (context == null)
            return;
        var definitions = Main.Game.GetAllOptionWidgetDefinitions();
        definitions.sort((d1, d2) -> Reflect.compare(d1.GetOrder(), d2.GetOrder()));
        var categories:Map<NamespaceID, Array<OptionWidgetsViewData>> = new Map();
        for (definition in definitions) {
            if (!definition.ShouldEnable(context))
                continue;
            var categoryID = definition.GetCategoryID();
            if (!NamespaceID.IsValid(categoryID))
                continue;
            if (!categories.exists(categoryID)) {
                categories.set(categoryID, []);
            }
            var list = categories.get(categoryID);
            var viewData = GetWidgetViewData(definition);
            list.push(viewData);
        }
        var categoryViewDatas:Array<MoreOptionsCategoryViewData> = [];

        for (key in categories.keys()) {
            var categoryMeta = Main.ResourceManager.GetOptionCategoryMeta(key);
            if (categoryMeta == null)
                continue;
            var label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_CATEGORY, categoryMeta.Label);
            var viewData = new MoreOptionsCategoryViewData();
            viewData.label = label;
            viewData.widgets = categories.get(key).copy();
            categoryViewDatas.push(viewData);
        }
        var moreOptionsViewData = new MoreOptionsViewData();
        moreOptionsViewData.categories = categoryViewDatas.copy();
        ui.MoreOptions.UpdateOptions(moreOptionsViewData);
    }
    private function GetWidgetViewData(definition:OptionWidgetDefinition):OptionWidgetsViewData {
        if (context == null)
            return new OptionWidgetsViewData();
        var tooltipText = definition.GetTooltip();
        if (tooltipText == null) tooltipText = "";
        var tooltipContext = LogicStrings.CONTEXT_OPTION_TOOLTIP;
        if (Std.isOfType(definition, OptionToggleDefinition)) {
            var toggle:OptionToggleDefinition = cast definition;
            var data = new OptionWidgetsViewData();
            data.label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_NAME, definition.GetLabel());
            data.namespaceID = definition.GetID();
            data.tooltipText = tooltipText;
            data.tooltipContext = tooltipContext;
            data.type = OptionWidgetType.Toggle;
            data.value = toggle.GetValue(context);
            return data;
        } else if (Std.isOfType(definition, OptionSliderDefinition)) {
            var slider:OptionSliderDefinition = cast definition;
            var value = slider.GetValue(context);
            var sliderValue = slider.GetLabelValue(context, value);
            var data = new OptionWidgetsViewData();
            data.label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_NAME, definition.GetLabel(), [sliderValue]);
            data.namespaceID = definition.GetID();
            data.tooltipText = tooltipText;
            data.tooltipContext = tooltipContext;
            data.sliderWholeNumbers = definition.IsSliderWholeNumbers();
            data.sliderMinValue = definition.GetSliderMinValue();
            data.sliderMaxValue = definition.GetSliderMaxValue();
            data.type = OptionWidgetType.Slider;
            data.value = value;
            return data;
        } else if (Std.isOfType(definition, OptionDropdownDefinition)) {
            var dropdown:OptionDropdownDefinition = cast definition;
            var value = dropdown.GetValue(context);
            var items:Array<String> = [];
            dropdown.FillItems(context, items);
            var data = new OptionWidgetsViewData();
            data.label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_NAME, definition.GetLabel());
            data.namespaceID = definition.GetID();
            data.tooltipText = tooltipText;
            data.tooltipContext = tooltipContext;
            data.type = OptionWidgetType.Dropdown;
            data.value = value;
            data.dropdownOptions = items;
            return data;
        } else if (Std.isOfType(definition, OptionButtonDefinition)) {
            var data = new OptionWidgetsViewData();
            data.label = Main.LanguageManager._p(LogicStrings.CONTEXT_OPTION_NAME, definition.GetLabel());
            data.namespaceID = definition.GetID();
            data.tooltipText = tooltipText;
            data.tooltipContext = tooltipContext;
            data.type = OptionWidgetType.Button;
            return data;
        }
        throw "NotImplementedException";
    }
    // #endregion

    // #region 组件更新
    private function GetValueText(value:Bool):String {
        return Main.LanguageManager._(value ? LogicStrings.YES : LogicStrings.NO);
    }
    private function GetDifficultyText(id:NamespaceID):String {
        return Main.Game.GetDifficultyName(id);
    }
    private function UpdateMainPageSliderValue(value:Float, optionKey:String, sliderType:SliderType):Void {
        var valueText = LogicMain.GetFloatPercentageText(value);
        var text = Main.LanguageManager._(optionKey, [valueText]);
        ui.Main.SetSliderValue(sliderType, value);
        ui.Main.SetSliderText(sliderType, text);
    }
    private function UpdateMainPageButtonText(value:Bool, optionKey:String, buttonType:TextButtonType):Void {
        var valueText = GetValueText(value);
        var text = Main.LanguageManager._(optionKey, [valueText]);
        ui.Main.SetButtonText(buttonType, text);
    }
    private function UpdateMainPageToggle(value:Bool, optionKey:String, toggleType:ToggleType):Void {
        var text = Main.LanguageManager._(optionKey);
        ui.Main.SetToggleText(toggleType, text);
        ui.Main.SetToggleOn(toggleType, value);
    }
    // #endregion

    // #region 常量
    public static inline var FASTFORWARD_STEP:Float = 0.05;
    public static inline var FASTFORWARD_MULTIPLIER_START:Float = 1.1;
    public static inline var FASTFORWARD_MULTIPLIER_END:Float = 3;
    // #endregion

    // #region 翻译文本
    // [TranslateMsg("选项")]
    public static inline var OPTION_SWAP_TRIGGER:String = "交换触发";
    // [TranslateMsg("选项")]
    public static inline var OPTION_FULLSCREEN:String = "全屏";
    // [TranslateMsg("选项")]
    public static inline var OPTION_VIBRATION:String = "设备震动";
    // [TranslateMsg("选项")]
    public static inline var OPTION_PAUSE_ON_FOCUS_LOST:String = "后台暂停";
    // [TranslateMsg("选项")]
    public static inline var OPTION_MORE_OPTIONS:String = "更多选项";
    // [TranslateMsg("选项，{0}为难度")]
    public static inline var OPTION_DIFFICULTY:String = "难度：{0}";
    // [TranslateMsg("选项")]
    public static inline var OPTION_RESTART:String = "重新开始";
    // [TranslateMsg("选项")]
    public static inline var OPTION_BACK:String = "返回";


    // [TranslateMsg("选项，{0}为量")]
    public static inline var OPTION_MUSIC:String = "音乐音量：{0}";
    // [TranslateMsg("选项，{0}为量")]
    public static inline var OPTION_SOUND:String = "音效音量：{0}";
    // [TranslateMsg("选项，{0}为量")]
    public static inline var OPTION_FASTFORWARD_MULTIPLIER:String = "加速倍率：{0}";
    // [TranslateMsg("对话框内容")]
    public static inline var DIALOG_DESC_LEAVE_LEVEL:String = "确认要返回吗？\n你的进度会被保存。";
    // #endregion

    public var OnClose:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>();
    private var Main(get, never):MainManager;
    function get_Main():MainManager return MainManager.Instance;
    private var context:IOptionContext;
    private var ui:OptionsDialog = null;
}

package mvz2.titlescreen;

import mvz2.managers.MainManager;
import mvz2.scenes.ScenePage;
import mvz2.ui.titlescreen.TitlescreenUI;
import mvz2logic.options.LogicOptionExt;
import unity.Application;

// PORT-NOTE: C# 中 OptionsManager.IsLanguageInitialized()/SetLanguage() 是 LogicOptionExt 里的扩展方法，
// Haxe 侧用 `using` 还原为调用点方法形式。
using mvz2logic.options.LogicOptionExt;

// Ported from: Assets/Scripts/MVZ2/Titlescreen/TitlescreenController.cs
class TitlescreenController extends ScenePage {
    override public function Display():Void {
        super.Display();
        ui.SetVersionText(GetVersionText());
    }
    // #region 生命周期
    private function Awake():Void {
        ui.OnButtonClick.add(OnButtonClickCallback);
        ui.OnLanguageDialogConfirmed.add(OnLanguageDialogConfirmedCallback);
    }
    private function Update():Void {
        var pipeline = main.GetLoadPipeline();
        if (pipeline != null) {
            var progress = pipeline.GetProgress();
            var name = pipeline.GetCurrentTaskName();
            var text = main.LanguageManager._(name);
            if (Application.isEditor) {
                // PORT-NOTE: C# `(progress * 100):N3` numeric format → fixed decimals.
                text = text + '\n${pipeline.GetCurrentProgressName()}(${formatPercent(progress * 100)}%)';
            }
            targetProgress = progress;
            ui.SetLoadingText(text);
            ui.SetButtonInteractable(pipeline.IsFinished());
        } else {
            var text = main.LanguageManager._(CLICK_TO_START);
            targetProgress = 1;
            ui.SetLoadingText(text);
            ui.SetButtonInteractable(true);
        }
        progress = progress * 0.5 + targetProgress * 0.5;
        ui.SetLoadingProgress(progress);
    }
    // #endregion

    // #region 事件回调
    private function OnButtonClickCallback():Void {
        if (!main.OptionsManager.IsLanguageInitialized()) {
            var languages = main.LanguageManager.GetAllLanguageCodes();
            mvz2.states.BootTrace.step('语言对话框：codes=${languages}');
            ui.ShowLanguageDialog(Lambda.array(Lambda.map(languages, l -> main.LanguageManager.GetLanguageName(l))));
        } else {
            main.Scene.DisplayMainmenu();
        }
    }
    private function OnLanguageDialogConfirmedCallback(index:Int):Void {
        ui.HideLanguageDialog();
        var languages = main.LanguageManager.GetAllLanguageCodes();
        main.OptionsManager.SetLanguage(languages[index]);
        main.Scene.DisplayMainmenu();
    }
    // #endregion

    private function GetVersionText():String {
        return main.LanguageManager._(VERSION_TEXT, [Application.version]);
    }

    // PORT-NOTE: formats with 3 decimals, matching C#'s "N3" format specifier.
    private static function formatPercent(value:Float):String {
        var rounded = Math.round(value * 1000) / 1000;
        var s = Std.string(rounded);
        var dot = s.indexOf(".");
        var intPart = dot < 0 ? s : s.substr(0, dot);
        var frac = dot < 0 ? "" : s.substr(dot + 1);
        while (frac.length < 3) frac += "0";
        var sign = intPart.indexOf("-") == 0 ? "-" : "";
        if (sign.length > 0) intPart = intPart.substr(1);
        var grouped = "";
        var count = 0;
        var i = intPart.length - 1;
        while (i >= 0) {
            grouped = intPart.charAt(i) + grouped;
            count++;
            if (count % 3 == 0 && i > 0) grouped = "," + grouped;
            i--;
        }
        return '$sign$grouped.$frac';
    }

    // #region 属性字段
    @:translateMsg("标题页面的版本号文本，{0}为版本号")
    public static inline var VERSION_TEXT:String = "版本{0}";
    @:translateMsg("标题界面按钮文本")
    public static inline var CLICK_TO_START:String = "点击以开始！";

    private var main(get, never):MainManager;
    inline function get_main():MainManager return MainManager.Instance;

    private var progress:Float;
    private var targetProgress:Float;
    @:serializeField
    private var ui:TitlescreenUI = null;
    // #endregion
}

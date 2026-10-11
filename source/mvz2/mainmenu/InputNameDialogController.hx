package mvz2.mainmenu;

import mvz2.managers.MainManager;
import mvz2.ui.InputNameDialog;
import mvz2logic.localization.LogicStrings;
import unity.MonoBehaviour;
import unity.Task;
import unity.TaskCompletionSource;
import mvz2.localization.LanguageManager;
import mvz2.saves.SaveManager;

// Ported from: Assets/Scripts/MVZ2/Scene/InputNameDialogController.cs
class InputNameDialogController extends MonoBehaviour {
    public function Show(type:InputNameType):Task {
        ui.ResetPosition();
        ui.ClearContent();
        ui.SetErrorMessage("");
        inputNameType = type;
        gameObject.SetActive(true);
        if (tcs != null)
            return tcs.task;
        tcs = new TaskCompletionSource();
        return tcs.task;
    }
    public function ShowRename(renameIndex:Int):Task {
        var task = Show(InputNameType.Rename);
        renamingUserIndex = renameIndex;
        return task;
    }
    /** 移植层新增：同步 Task shim 直通后由主流程主动收起对话框（见 MainmenuController.Init
     *  的 PORT-NOTE —— 直通意味着确认回调无人等待，对话框会永远挂在屏幕上挡住模态遮罩）。*/
    public function Dismiss():Void Hide();
    private function Hide():Void {
        gameObject.SetActive(false);
        inputNameType = InputNameType.None;
        renamingUserIndex = -1;
        if (tcs == null)
            return;
        tcs.TrySetResult("");
        tcs = null;
    }
    private function Awake():Void {
        ui.OnConfirm.add(OnConfirmCallback);
        ui.OnCancel.add(OnCancelCallback);
    }
    private function OnConfirmCallback(value:String):Void {
        var message:{value:String} = {value: null};
        if (!ValidateUserName(value, message)) {
            var error = main.LanguageManager._(message.value);
            ui.SetErrorMessage(error);
            return;
        }
        if (tcs != null) tcs.TrySetResult(value);
        Hide();
    }
    private function OnCancelCallback():Void {
        if (inputNameType == InputNameType.Initialize) {
            var error = main.LanguageManager._(LogicStrings.ERROR_MESSAGE_CANNOT_CANCEL_NAME_INPUT);
            ui.SetErrorMessage(error);
            return;
        }
        Hide();
    }
    private function ValidateUserName(name:String, message:{value:String}):Bool {
        if (name == null || name.length == 0) {
            message.value = LogicStrings.ERROR_MESSAGE_NAME_EMPTY;
            return false;
        }

        if (main.SaveManager.HasDuplicateUserName(name, renamingUserIndex)) {
            message.value = LogicStrings.ERROR_MESSAGE_NAME_DUPLICATE;
            return false;
        }

        if (inputNameType == InputNameType.Rename && !main.SaveManager.CanRenameUserTo(name)) {
            message.value = LogicStrings.ERROR_MESSAGE_CANNOT_USE_THIS_NAME;
            return false;
        }
        message.value = null;
        return true;
    }
    private var main(get, never):MainManager;
    inline function get_main():MainManager return MainManager.Instance;

    @:serializeField
    private var ui:InputNameDialog = null;
    private var inputNameType:InputNameType;
    private var renamingUserIndex:Int = -1;
    private var tcs:TaskCompletionSource;
}

// Ported from: Assets/Scripts/MVZ2/Scene/InputNameDialogController.cs (enum InputNameType)
enum abstract InputNameType(Int) {
    var None = 0;
    var Initialize = 1;
    var CreateNewUser = 2;
    var Rename = 3;
}

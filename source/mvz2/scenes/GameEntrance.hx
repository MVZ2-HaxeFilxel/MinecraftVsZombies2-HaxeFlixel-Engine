package mvz2.scenes;

import mvz2.mainmenu.InputNameDialogController;
import mvz2.managers.MainManager;
import mvz2logic.audios.LogicMusicID;
import mvz2logic.localization.LogicStrings;
import mvz2logic.scenes.MainScenePageType;
import mvz2.saves.SaveManager;
import system.io.DirectoryNotFoundException;
import system.io.FileNotFoundException;
import unity.Application;
import unity.Debug;
import unity.GameObject;
import unity.MonoBehaviour;
import unity.Task;
import system.io.IOException;
import mvz2.localization.LanguageManager;
import mvz2.audios.MusicManager;
import mvz2.mainmenu.InputNameDialogController.InputNameType;
import mvz2.saves.SaveManager.SaveDataState;
import unity.scenemanagement.SceneInstance.Scene;

// Ported from: Assets/Scripts/MVZ2/Scene/GameEntrance.cs
// PORT-NOTE: C# async/await → Task-returning methods; `await x` becomes `x.awaitResult()`.
class GameEntrance extends MonoBehaviour {
    private function Start():Void {
        if (!Initialize().awaitResult())
            return;

        CheckSaveDataStatus().awaitResult();
        StartGame().awaitResult();
    }
    private function Initialize():Task {
        var loadingTextObject:GameObject = loadingText;
        loadingTextObject.SetActive(true);
        // PORT-NOTE: 对应 C# `private async Task<bool> Initialize()` —— 返回值决定 Start 是否继续
        // （C# 里是 try { await main.Initialize(); return true; } catch { ShowErrorDialog(e); return false; }
        //  finally { loadingText.SetActive(false); }）。原移植把三段拆成 Initialize/InitializeAsync 后
        // 丢掉了这个返回值：返回 Task.completedTask() 的 Result 是 null，hxcpp 生成
        // `(bool)null == false` → `!false == true` → Start() 恒定提前 return，
        // 后面的 CheckSaveDataStatus()/StartGame()（含 main.InitLoad()、DisplayPage(Splash)、主题曲）
        // 从来没跑过。这里把 InitializeAsync 的结果透传出来。
        var result = InitializeAsync().awaitResult();
        loadingTextObject.SetActive(false);
        return Task.fromResult(result);
    }
    // PORT-NOTE: the try/catch/finally of Initialize() is split so that the Haxe try block can
    // return a value while still restoring the loading text.
    private function InitializeAsync():Task {
        try {
            main.Initialize().awaitResult();
            return Task.fromResult(true);
        } catch (e:Dynamic) {
            ShowErrorDialog(e);
            return Task.fromResult(false);
        }
    }
    private function StartGame():Task {
        loadingText.SetActive(true);
        try {
            main.InitLoad();

            if (!main.IsFastMode()) {
                main.Scene.DisplayPage(MainScenePageType.Splash);
            } else {
                var initTask = main.GetInitTask();
                if (initTask != null) {
                    initTask.awaitResult();
                }
                main.Scene.DisplayMainmenu();
            }
            main.MusicManager.Play(LogicMusicID.mainmenu);
        } catch (e:Dynamic) {
            ShowErrorDialog(e);
        }
        loadingText.SetActive(false);
        return Task.completedTask();
    }
    private function GetErrorMessage(e:Dynamic):String {
        // PORT-NOTE: C# pattern matching on exception types → Std.isOfType checks.
        if (Std.isOfType(e, DirectoryNotFoundException))
            return main.LanguageManager._p(LogicStrings.CONTEXT_ERROR, ERROR_DIRECTORY_NOT_FOUND);
        if (Std.isOfType(e, FileNotFoundException))
            return main.LanguageManager._p(LogicStrings.CONTEXT_ERROR, ERROR_FILE_NOT_FOUND);
        if (Std.isOfType(e, system.io.IOException)) {
            var io:system.io.IOException = cast e;
            if (io.message.indexOf("Sharing Violation") >= 0) {
                return main.LanguageManager._p(LogicStrings.CONTEXT_ERROR, ERROR_SHARING_VIOLATION);
            } else {
                return main.LanguageManager._p(LogicStrings.CONTEXT_ERROR, ERROR_FAILED_TO_LOAD_FILE);
            }
        }
        if (Std.isOfType(e, haxe.Exception))
            return main.LanguageManager._p(LogicStrings.CONTEXT_ERROR, ERROR_INCORRECT_FILE_FORMAT);
        return Std.string(e);
    }
    private function ShowErrorDialog(e:Dynamic):Void {
        Debug.LogException(e);
        var innerMessage = GetErrorMessage(e);
        var title = main.LanguageManager._(LogicStrings.ERROR);
        var message = main.LanguageManager._p(LogicStrings.CONTEXT_ERROR, ERROR_FAILED_TO_INITIALIZE, [innerMessage]);
        var options = [
            main.LanguageManager._(LogicStrings.QUIT)
        ];
        main.Scene.ShowDialog(title, message, options, i -> {
            Quit();
        });
    }
    private function CheckSaveDataStatus():Task {
        var status = main.SaveManager.GetSaveDataStatus();
        switch (status.State) {
            case SaveDataState.SomeCorrupted:
                {
                    var corruptedIndexes = status.GetCorruptedUserIndexes();
                    var corruptedUserNames = Lambda.map(corruptedIndexes, i -> main.SaveManager.GetUserName(i));
                    var names = corruptedUserNames.join(", ");
                    var currentName = main.SaveManager.GetCurrentUserName();
                    var title = main.LanguageManager._(LogicStrings.WARNING);
                    var desc = main.LanguageManager._(ERROR_SOME_USERS_CORRUPTED, [currentName, names]);
                    main.Scene.ShowDialogMessageAsync(title, desc).awaitResult();
                }
            case SaveDataState.AllCorrupted:
                {
                    var title = main.LanguageManager._(LogicStrings.WARNING);
                    var desc = main.LanguageManager._(ERROR_ALL_USERS_CORRUPTED);
                    main.Scene.ShowDialogMessageAsync(title, desc).awaitResult();

                    // PORT-NOTE: C# 在这里 await InputNameDialog 等玩家输入名字；移植层的 Task
                    // shim 是同步直通（awaitResult 不等待，见 system/threading/tasks/Task.hx），
                    // 弹出的对话框无人等待、流程又必须立刻给出用户名 —— 原样移植会以 null
                    // 建用户（SetUserName 写回 null，metas 仍为 null → 下次启动重复「全损坏」
                    // 流程，InputNameDialog 反复出没）。同步模型的等价改法：以默认名创建用户。
                    var newIndex = main.SaveManager.CreateNewUser(DEFAULT_NEW_USERNAME);
                    main.SaveManager.SetCurrentUserIndex(newIndex);
                    main.SaveManager.SaveUserList();
                }
            case SaveDataState.FullCorrupted:
                {
                    var title = main.LanguageManager._(LogicStrings.WARNING);
                    var desc = main.LanguageManager._(ERROR_FULL_USERS_CORRUPTED);
                    main.Scene.ShowDialogMessageAsync(title, desc).awaitResult();

                    // PORT-NOTE: 同 AllCorrupted：ShowDeleteUserDialogAsync / ShowInputNameDialogAsync
                    // 的 awaitResult 在同步模型下直通（null），原样移植会拿 null 去删用户/建用户。
                    // 等价改法：删除栏位 0 的损坏数据并以默认名重建用户。
                    main.SaveManager.DeleteUser(0);
                    main.SaveManager.SaveUserList();

                    var newIndex = main.SaveManager.CreateNewUser(DEFAULT_NEW_USERNAME);
                    main.SaveManager.SetCurrentUserIndex(newIndex);
                    main.SaveManager.SaveUserList();
                }
            default:
        }
        return Task.completedTask();
    }
    private function Quit():Void {
        Application.Quit();
        // PORT-NOTE: the `#if UNITY_EDITOR` UnityEditor.EditorApplication.isPlaying = false
        // branch is editor-only and is not ported.
    }

    @:translateMsg("开始游戏时读取出错，对话框的描述，{0}为错误信息")
    public static inline var ERROR_FAILED_TO_INITIALIZE:String = "游戏加载失败：\n{0}";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_DIRECTORY_NOT_FOUND:String = "文件目录丢失";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_FILE_NOT_FOUND:String = "文件丢失";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_SHARING_VIOLATION:String = "文件被占用";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_FAILED_TO_LOAD_FILE:String = "文件读取失败";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_INCORRECT_FILE_FORMAT:String = "文件格式错误";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息，{0}为新使用的存档，{1}为存档列表")
    public static inline var ERROR_SOME_USERS_CORRUPTED:String = "部分存档无法读取，将使用存档{0}开始游戏。\n无法读取的存档：\n{1}";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_ALL_USERS_CORRUPTED:String = "所有存档均无法读取，文件可能已损坏。\n必须新建存档以继续游戏。";
    @:translateMsg("开始游戏时读取出错，对话框的错误信息")
    public static inline var ERROR_FULL_USERS_CORRUPTED:String = "所有存档均无法读取，文件可能已损坏。\n必须删除一个存档，并新建存档以继续游戏。";
    // PORT-NOTE: 移植层新增：同步 Task shim 下「全损坏」流程无法等待玩家输入名字，
    // 以该默认名直接建用户（见 CheckSaveDataStatus 的 PORT-NOTE）。
    // TODO-PORT: Task.awaitResult 协程化后应还原为弹 InputNameDialog 输入。
    public static inline var DEFAULT_NEW_USERNAME:String = "Player";

    @:serializeField
    private var main:MainManager = null;
    @:serializeField
    private var loadingText:GameObject = null;
}

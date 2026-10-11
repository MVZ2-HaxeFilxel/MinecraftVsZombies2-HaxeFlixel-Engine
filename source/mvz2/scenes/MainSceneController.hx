package mvz2.scenes;

import mvz2.addons.AddonsController;
import mvz2.almanacs.AlmanacController;
import mvz2.arcade.ArcadeController;
import mvz2.archives.ArchiveController;
import mvz2.chaptertransition.ChapterTransitionController;
import mvz2.debugconsole.DebugConsoleController;
import mvz2.gamecontent.stages.VanillaStageID;
import mvz2.mainmenu.DeleteUserDialogController;
import mvz2.mainmenu.InputNameDialogController;
import mvz2.mainmenu.MainmenuController;
import mvz2.managers.MainManager;
import mvz2.map.MapController;
import mvz2.musicroom.MusicRoomController;
import mvz2.note.NoteController;
import mvz2.options.HotKeys;
import mvz2.saves.UserDataItem;
import mvz2.store.StoreController;
import mvz2.titlescreen.TitlescreenController;
import mvz2.level.CameraLimiter;
import mvz2.ui.FPSDisplayer;
import mvz2.ui.ITooltipSource;
import mvz2.ui.scene.MainSceneUI;
import mvz2.ui.scene.PortalController;
import mvz2.ui.Tooltip;
import mvz2logic.audios.LogicSoundID;
import mvz2logic.games.IGlobalScene;
import mvz2logic.localization.LogicStrings;
import mvz2logic.scenes.MainScenePageType;
import pvzengine.NamespaceID;
import unity.Camera;
import unity.Color;
import unity.Coroutine;
import unity.Input;
import unity.MonoBehaviour;
import unity.Task;
import unity.TaskCompletionSource;
import unity.Vector2;
import unity.Vector3;
import mvz2.gamecontent.artifacts.Almanac;
import mvz2.managers.CoroutineManager;
import mvz2.debugs.DebugManager;
import mvz2.localization.LanguageManager;
import mvz2.level.LevelManager;
import mvz2.gamecontent.projectiles.Note;
import mvz2.options.OptionsManager;
import mvz2.managers.ResourceManager;
import mvz2.saves.SaveManager;
import mvz2.audios.SoundManager;
import mvz2.mainmenu.InputNameDialogController.InputNameType;
import mvz2.ui.Tooltip.TooltipPosition;
import flixel.addons.ui.Anchor;
import unity.scenemanagement.SceneInstance.Scene;

// PORT-NOTE: C# 中 SaveManager.IsLevelCleared/GetLastMapID 等是扩展方法，Haxe 侧用 `using` 还原为调用点方法形式。
using mvz2logic.saves.LogicSaveExt;

// Ported from: Assets/Scripts/MVZ2/Scene/MainSceneController.cs
class MainSceneController extends MonoBehaviour implements IGlobalScene {
    public function Init():Void {
        achievementHint.gameObject.SetActive(true);
        uiCameraLimiter.UpdateCamera();
    }
    // #region 对话框
    public function ShowDialog(title:String, desc:String, options:Array<String>, onSelect:Int->Void = null):Void {
        ui.ShowDialog(title, desc, options, onSelect);
    }
    public function ShowDialogTask(title:String, desc:String, options:Array<String>, onSelect:Int->Task = null):Void {
        ui.ShowDialogTask(title, desc, options, onSelect);
    }
    public function ShowDialogMessage(title:String, desc:String, onSelect:Void->Void = null):Void {
        ShowDialog(title, desc, [
            main.LanguageManager._(LogicStrings.CONFIRM),
        ], (index) -> {
            if (onSelect != null) onSelect();
        });
    }
    public function ShowDialogMessageAsync(title:String, desc:String):Task {
        var tcs = new TaskCompletionSource();
        ShowDialogMessage(title, desc, () -> tcs.SetResult(null));
        return tcs.task;
    }
    public function ShowDialogSelect(title:String, desc:String, onSelect:Bool->Void = null):Void {
        ShowDialog(title, desc, [
            main.LanguageManager._(LogicStrings.YES),
            main.LanguageManager._(LogicStrings.NO),
        ], (index) -> {
            if (onSelect != null) onSelect(index == 0);
        });
    }
    public function ShowDialogSelectTask(title:String, desc:String, onSelect:Bool->Task = null):Void {
        var options = [
            main.LanguageManager._(LogicStrings.YES),
            main.LanguageManager._(LogicStrings.NO),
        ];
        var intSelect:Int->Task = null;
        if (onSelect != null) {
            intSelect = (index) -> onSelect(index == 0);
        }
        ShowDialogTask(title, desc, options, intSelect);
    }
    public function ShowDialogSelectAsync(title:String, desc:String):Task {
        var tcs = new TaskCompletionSource();
        ShowDialogSelect(title, desc, (result) -> tcs.SetResult(result));
        return tcs.task;
    }
    public function HasDialog():Bool {
        return ui.HasDialog();
    }
    public function ShowInputNameDialogAsync(type:InputNameType):Task {
        return inputNameDialog.Show(type);
    }
    // PORT-NOTE: 移植层新增：同步 Task shim 直通后由主流程收起输入名字对话框（见
    // MainmenuController.Init 的 PORT-NOTE；对应 C# 里玩家点确认后的正常 Hide）。
    public function HideInputNameDialog():Void {
        inputNameDialog.Dismiss();
    }
    public function ShowInputNameDialogRenameAsync(index:Int):Task {
        return inputNameDialog.ShowRename(index);
    }
    public function ShowDeleteUserDialogAsync(users:Array<UserDataItem>):Task {
        return deleteUserDialog.Show(users);
    }
    // #endregion

    // #region 成就
    public function ShowAchievementEarnTips(achievements:Array<NamespaceID>):Void {
        achievementHint.Show(achievements);
        if (achievements.length > 0) {
            main.SoundManager.Play2D(LogicSoundID.achievement);
        }
    }
    // #endregion

    // #region 弹出提示
    public function ShowPopup(text:String):Void {
        popup.ShowPopup(text);
    }
    // #endregion

    // #region 传送门
    public function PortalFadeIn(OnFadeIn:Void->Void):Void {
        StartPortalFade(1, 2);
        // PORT-NOTE: C# local function `OnFinished` used to unsubscribe itself.
        var OnFinished:Float->Void = null;
        OnFinished = function(value:Float) {
            if (OnFadeIn != null) OnFadeIn();
            portal.OnFadeFinished.remove(OnFinished);
        };
        portal.OnFadeFinished.add(OnFinished);
    }
    public function PortalFadeOut():Void {
        StartPortalFade(0, 2);
    }
    public function SetPortalAlpha(alpha:Float):Void {
        // PORT-NOTE: C# 原实现写死 portal.SetAlpha(1)，忽略参数；TalkController 的
        // "portal set <alpha>" / "portal fade" 命令（TalkController.hx:349/353）会传任意
        // alpha 进来，这里按参数名语义透传（参考 Unity Instantiate/属性 setter 行为）。
        portal.SetAlpha(alpha);
    }
    public function StartPortalFade(target:Float, duration:Float):Void {
        portal.StartFade(target, duration);
    }
    // #endregion

    // #region 屏
    public function SetScreenCoverColor(value:Color):Void {
        ui.SetScreenCoverColor(value);
    }
    public function FadeScreenCoverColor(target:Color, duration:Float):Void {
        ui.FadeScreenCoverColor(target, duration);
    }
    // #endregion

    // #region 页面
    public function DisplayPage(type:MainScenePageType):Void {
        for (key in pages.keys()) {
            var page = pages.get(key);
            if (key == type)
                page.Display();
            else
                page.Hide();
        }
        currentPage = type;
    }
    public function HidePages():Void {
        for (key in pages.keys()) {
            pages.get(key).Hide();
        }
        currentPage = MainScenePageType.None;
    }
    public function DisplayTitlescreen():Void {
        DisplayPage(MainScenePageType.Titlescreen);
    }
    public function DisplayMainmenu():Void {
        DisplayPage(MainScenePageType.Mainmenu);
    }
    public function DisplayMainmenuToBasement():Void {
        DisplayPage(MainScenePageType.Mainmenu);
        mainmenu.SetViewToBasement();
    }
    public function DisplayMap(mapId:NamespaceID):Void {
        DisplayPage(MainScenePageType.Map);
        map.SetMap(mapId);
    }
    public function DisplayNote(id:NamespaceID, buttonText:String):Void {
        DisplayPage(MainScenePageType.Note);
        note.SetNote(id);
        note.SetButtonText(buttonText);
    }
    public function DisplayAlmanac(onReturn:Void->Void):Void {
        DisplayPage(MainScenePageType.Almanac);
        var OnReturn:Void->Void = null;
        OnReturn = () -> {
            if (onReturn != null) onReturn();
            almanac.OnReturnClick.remove(OnReturn);
        };
        almanac.OnReturnClick.add(OnReturn);
    }
    public function DisplayStore(onReturn:Void->Void, showTalk:Bool):Void {
        DisplayPage(MainScenePageType.Store);
        if (showTalk) {
            store.CheckStartTalks();
        }
        var OnReturn:Void->Void = null;
        OnReturn = () -> {
            if (onReturn != null) onReturn();
            store.OnReturnClick.remove(OnReturn);
        };
        store.OnReturnClick.add(OnReturn);
    }
    public function DisplayArchive(onReturn:Void->Void):Void {
        DisplayPage(MainScenePageType.Archive);
        var OnReturn:Void->Void = null;
        OnReturn = () -> {
            if (onReturn != null) onReturn();
            archive.OnReturnClick.remove(OnReturn);
        };
        archive.OnReturnClick.add(OnReturn);
    }
    public function DisplayAddons(onReturn:Void->Void):Void {
        DisplayPage(MainScenePageType.Addons);
        var OnReturn:Void->Void = null;
        OnReturn = () -> {
            if (onReturn != null) onReturn();
            addons.OnReturnClick.remove(OnReturn);
        };
        addons.OnReturnClick.add(OnReturn);
    }
    public function DisplayMusicRoom(onReturn:Void->Void):Void {
        DisplayPage(MainScenePageType.MusicRoom);
        var OnReturn:Void->Void = null;
        OnReturn = () -> {
            if (onReturn != null) onReturn();
            musicRoom.OnReturnClick.remove(OnReturn);
        };
        musicRoom.OnReturnClick.add(OnReturn);
    }
    public function DisplayArcade(onReturn:Void->Void):Void {
        DisplayPage(MainScenePageType.Arcade);
        var OnReturn:Void->Void = null;
        OnReturn = () -> {
            if (onReturn != null) onReturn();
            arcade.OnReturnClick.remove(OnReturn);
        };
        arcade.OnReturnClick.add(OnReturn);
    }
    public function DisplayArcadeMinigames():Void {
        arcade.DisplayMinigames();
    }
    public function DisplayArcadePuzzles():Void {
        arcade.DisplayPuzzles();
    }
    public function DisplayEnemyAlmanac(enemyID:NamespaceID):Void {
        almanac.OpenEnemyAlmanac(enemyID);
    }
    public function DisplayChapterTransitionAsync(id:NamespaceID, end:Bool):Task {
        HidePages();
        return chapterTransition.DisplayAsync(id, end);
    }
    public function HideChapterTransition():Void {
        chapterTransition.Hide();
    }
    // #endregion

    // #region 控制台
    public function DisplayConsole():Void {
        debugConsole.Show();
    }
    public function HideConsole():Void {
        debugConsole.Hide();
    }
    public function IsConsoleActive():Bool {
        return debugConsole.IsActive();
    }
    public function GetCommandHistory():Array<String> {
        return debugConsole.GetCommandHistory();
    }
    public function ClearConsole():Void {
        debugConsole.ClearConsole();
    }
    public function Print(text:String):Void {
        debugConsole.Print(text);
    }
    // #endregion

    // #region 工具提示
    public function ShowTooltip(source:ITooltipSource):Void {
        tooltipSource = source;
        if (tooltipSource == null)
            return;
        var target = tooltipSource.GetTarget();
        var anchor = target.Anchor;
        if (anchor == null || anchor.IsDisabled)
            return;
        UpdateTooltip();
        ui.ShowTooltip();
    }
    public function UpdateTooltip():Void {
        if (tooltipSource == null) {
            ui.HideTooltip();
            return;
        }
        var target = tooltipSource.GetTarget();
        if (target == null || target.Anchor == null || target.Anchor.IsDisabled) {
            ui.HideTooltip();
            return;
        }
        var anchor = target.Anchor;
        var content = tooltipSource.GetContent();
        var camera = tooltipSource.GetCamera();
        var tooltipPosition:Vector3 = anchor.Position;
        if (camera != null) {
            var screenPosition = camera.WorldToScreenPoint(anchor.Position);
            tooltipPosition = uiCamera.ScreenToWorldPoint(screenPosition);
        }
        var position = new TooltipPosition();
        // PORT-NOTE: C# 依赖 UnityEngine 的 Vector3→Vector2 隐式转换，Haxe 需显式构造。
        position.position = new Vector2(tooltipPosition.x, tooltipPosition.y);
        position.pivot = anchor.Pivot;
        ui.SetTooltipContent(content);
        ui.SetTooltipPosition(position);
    }
    public function HideTooltip():Void {
        tooltipSource = null;
    }
    // #endregion

    public function ShowKeybinding():Void {
        keybinding.Display();
    }
    public function ShowCredits():Void {
        credits.Display();
    }

    public function SetFPSEnabled(enabled:Bool):Void {
        fpsDisplayer.SetActive(enabled);
    }
    public function SetFPSCorner(corner:Vector2):Void {
        fpsDisplayer.SetCorner(corner);
    }
    public function SetFPS(fps:String):Void {
        fpsDisplayer.SetFPS(fps);
    }
    public function GotoMapOrMainmenu():Void {
        if (main.SaveManager.IsLevelCleared(VanillaStageID.prologue)) {
            var lastMapID = main.SaveManager.GetLastMapID();
            if (lastMapID == null) lastMapID = main.ResourceManager.GetFirstMapID();
            DisplayMap(lastMapID);
        } else {
            DisplayMainmenu();
        }
    }

    // #region 关卡
    private function GotoLevelSceneAsync():Task {
        main.LevelManager.GotoLevelSceneAsync().awaitResult();
        HidePages();
        return Task.completedTask();
    }
    // TODO-PORT: 工程内同时存在两套 Task shim —— unity.Task（本文件对话框部分所用）与
    // system.threading.tasks.Task（mvz2.managers / LevelManager / CoroutineManager / mvz2logic 所用）。
    // 二者是同一个 C# 类型 System.Threading.Tasks.Task 的重复移植，互不兼容（成员名也不同：
    // IsCompleted/Result vs completed/result），无法在不改 shim 的前提下互相转换。
    // 本方法体与 C# 完全一致，仅用 cast 跨过类型边界（与 mvz2.managers.MainManager 处理
    // SponsorManager.PullSponsors 的方式一致）。注意：该 cast 是无检查的，运行期对象的真实
    // 布局仍是 system 版；在 unity/system 两域把 shim 统一为一套之前，这条路径不应被依赖。
    private function ExitLevelSceneAsync():Task {
        return cast main.LevelManager.ExitLevelSceneAsync();
    }
    // #endregion

    // #region IGlobalScene 接口实现
    public function GotoMainmenu():Void {
        DisplayMainmenu();
    }
    public function GotoMap(mapID:NamespaceID):Void {
        DisplayMap(mapID);
    }
    public function GotoStore(backAction:Void->Void, showTalks:Bool):Void {
        DisplayStore(backAction, showTalks);
    }
    public function GotoLevelCoroutine():Coroutine {
        // TODO-PORT: unity.Task → system.threading.tasks.Task 的 shim 重复问题，见 ExitLevelSceneAsync。
        return main.CoroutineManager.ToCoroutine(cast GotoLevelSceneAsync());
    }
    public function GotoChapterTransitionCoroutine(chapterID:NamespaceID, end:Bool):Coroutine {
        // TODO-PORT: unity.Task → system.threading.tasks.Task 的 shim 重复问题，见 ExitLevelSceneAsync。
        return main.CoroutineManager.ToCoroutine(cast DisplayChapterTransitionAsync(chapterID, end));
    }
    public function OpenCreditsPanel():Void {
        ShowCredits();
    }
    public function OpenKeybindingPanel():Void {
        ShowKeybinding();
    }
    // #endregion

    // #region 生命周期
    private function Awake():Void {
        pages.set(MainScenePageType.Splash, splash);
        pages.set(MainScenePageType.Titlescreen, titlescreen);
        pages.set(MainScenePageType.Mainmenu, mainmenu);
        pages.set(MainScenePageType.Note, note);
        pages.set(MainScenePageType.Map, map);
        pages.set(MainScenePageType.Almanac, almanac);
        pages.set(MainScenePageType.Store, store);
        pages.set(MainScenePageType.Archive, archive);
        pages.set(MainScenePageType.Addons, addons);
        pages.set(MainScenePageType.MusicRoom, musicRoom);
        pages.set(MainScenePageType.Arcade, arcade);

        ui.OnDebugIconClick.add((icon) -> main.Scene.DisplayConsole());
    }
    private function Update():Void {
        UpdateTooltip();
        var userName = main.SaveManager.GetCurrentUserName();
        var canUse = CanUseDebugConsole(userName);
        var consoleOpen = !debugConsole.IsActive();
        if (Input.GetKeyDown(main.OptionsManager.GetKeyBinding(HotKeys.console)) && canUse && consoleOpen) {
            DisplayConsole();
        }
        ui.SetDebugIconActive(canUse && consoleOpen);
    }
    // #endregion

    private function CanUseDebugConsole(username:String):Bool {
        if (!CanPageUseDebugConsole())
            return false;
        // PORT-NOTE: C# 重载 CanUseDebugFeatures(string? username) 在 Haxe 移植层改名为 CanUseDebugFeaturesByName。
        return main.DebugManager.CanUseDebugFeaturesByName(username);
    }
    private function CanPageUseDebugConsole():Bool {
        if (main.LevelManager.IsInLevel())
            return true;
        return currentPage != MainScenePageType.None &&
            currentPage != MainScenePageType.Splash &&
            currentPage != MainScenePageType.Titlescreen;
    }

    // #region 属性字段
    private var main(get, never):MainManager;
    inline function get_main():MainManager return MainManager.Instance;

    private var pages:Map<MainScenePageType, ScenePage> = new Map();
    private var currentPage:MainScenePageType = MainScenePageType.None;
    private var tooltipSource:ITooltipSource;

    @:serializeField
    private var uiCamera:Camera = null;
    @:serializeField
    private var uiCameraLimiter:CameraLimiter = null;
    @:serializeField
    private var ui:MainSceneUI = null;
    @:serializeField
    private var splash:SplashController = null;
    @:serializeField
    private var titlescreen:TitlescreenController = null;
    @:serializeField
    private var mainmenu:MainmenuController = null;
    @:serializeField
    private var note:NoteController = null;
    @:serializeField
    private var map:MapController = null;
    @:serializeField
    private var portal:PortalController = null;
    @:serializeField
    private var chapterTransition:ChapterTransitionController = null;
    @:serializeField
    private var almanac:AlmanacController = null;
    @:serializeField
    private var store:StoreController = null;
    @:serializeField
    private var archive:ArchiveController = null;
    @:serializeField
    private var addons:AddonsController = null;
    @:serializeField
    private var musicRoom:MusicRoomController = null;
    @:serializeField
    private var arcade:ArcadeController = null;
    @:serializeField
    private var keybinding:KeybindingController = null;
    @:serializeField
    private var credits:CreditsController = null;
    @:serializeField
    private var achievementHint:AchievementHintController = null;
    @:serializeField
    private var popup:PopupController = null;
    @:serializeField
    private var fpsDisplayer:FPSDisplayer = null;
    @:serializeField
    private var debugConsole:DebugConsoleController = null;
    @:serializeField
    private var inputNameDialog:InputNameDialogController = null;
    @:serializeField
    private var deleteUserDialog:DeleteUserDialogController = null;
    // #endregion
}

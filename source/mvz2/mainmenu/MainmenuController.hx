// Ported from: Assets/Scripts/MVZ2/Mainmenu/MainmenuController.cs
package mvz2.mainmenu;

import mvz2.gamecontent.areas.VanillaAreaID;
import mvz2.gamecontent.notes.VanillaNoteID;
import mvz2.gamecontent.stages.VanillaStageID;
import mvz2.io.FileHelper;
import mvz2.mainmenu.InputNameDialogController;
import mvz2.managers.MainManager;
import mvz2.metas.AchievementMeta;
import mvz2.metas.MainmenuViewMeta;
import mvz2.metas.StatCategoryType;
import mvz2.metas.StatOperation;
// PORT-NOTE: mvz2.ui.UserManageDialog 与 mvz2.ui.OptionsDialogMainPage 都声明了公开子类型 ButtonType。
// Haxe 不允许同一包内出现两个同名类型，故 UserManageDialog 的子类型改名为 UserManageButtonType。
import mvz2.ui.UserManageDialog;
import mvz2.options.OptionContextMainmenu;
import mvz2.saves.SaveManager;
import mvz2.saves.UserDataPackMetadata;
import mvz2.scenes.MainScenePage;
import mvz2.supporters.SponsorPlans;
import mvz2.ui.UserManageList;
import mvz2.ui.mainmenu.AchievementEntryUI;
import mvz2.ui.mainmenu.MainmenuButton;
import mvz2.ui.mainmenu.MainmenuUI;
import mvz2.ui.mainmenu.StatCategoryUI;
import mvz2.ui.mainmenu.StatDirectEntryUI;
import mvz2.ui.mainmenu.StatEntryUI;
import mvz2.ui.mainmenu.StatsUI;
import mvz2logic.audios.LogicMusicID;
import mvz2logic.audios.LogicSoundID;
import mvz2logic.localization.LogicStrings;
import mvz2logic.resources.SpriteReference;
import mvz2logic.saves.UserStatCategory;
import mvz2logic.saves.UserStatDirectEntry;
import mvz2logic.saves.UserStats;
import pvzengine.NamespaceID;
import system.io.File;
import unity.Animator;
import unity.Application;
import unity.Color;
import unity.Coroutine;
import unity.Debug;
import unity.Input;
import unity.KeyCode;
import unity.Sprite;
import unity.Task;
import unity.Time;
import unity.Vector2;
import mvz2.gamecontent.artifacts.Almanac;
import mvz2.gamecontent.commands.Help;
import mvz2.localization.LanguageManager;
import mvz2.level.LevelManager;
import mvz2logic.games.LogicGameExt;
import mvz2logic.saves.LogicSaveExt;
import mvz2.saves.MVZ2SaveExt;
import mvz2.audios.MusicManager;
import mvz2.options.Options;
import mvz2.options.OptionsDialogController;
import mvz2.managers.ResourceManager;
import mvz2.audios.SoundManager;
import mvz2.supporters.SponsorManager;
import mvz2.metas.StatCategoryMeta;
import mvz2.mainmenu.InputNameDialogController.InputNameType;
import mvz2.ui.UserManageDialog.UserManageButtonType;
import mvz2.ui.UserManageList.UserNameItemViewData;
import mvz2.ui.mainmenu.AchievementEntryUI.AchievementEntryViewData;
import mvz2.ui.mainmenu.MainmenuUI.MainmenuButtonType;
import mvz2.ui.mainmenu.StatCategoryUI.StatCategoryViewData;
import mvz2.ui.mainmenu.StatDirectEntryUI.StatDirectEntryViewData;
import mvz2.ui.mainmenu.StatEntryUI.StatEntryViewData;
import mvz2.ui.mainmenu.StatsUI.StatsViewData;
import unity.Coroutine.CoroutineContext;
import flixel.system.debug.stats.Stats;
import unity.scenemanagement.SceneInstance.Scene;

using mvz2.saves.MVZ2SaveExt;
using mvz2logic.games.LogicGameExt;
using mvz2logic.saves.LogicSaveExt;

class MainmenuController extends MainScenePage {
    override public function Display():Void {
        super.Display();
        for (button in GetAllButtons()) {
            button.Interactable = true;
        }
        ui.SetButtonActive(MainmenuButtonType.Almanac, main.SaveManager.IsAlmanacUnlocked());
        ui.SetButtonActive(MainmenuButtonType.Store, main.SaveManager.IsStoreUnlocked());
        ui.SetButtonActive(MainmenuButtonType.MusicRoom, main.SaveManager.IsMusicRoomUnlocked());
        ui.SetButtonActive(MainmenuButtonType.Arcade, main.SaveManager.IsArcadeUnlocked());

        isDark = false;
        ui.SetBackgroundDark(false);
        ui.SetOptionsDialogVisible(false);
        ui.SetUserManageDialogVisible(false);
        ui.SetRayblockerActive(true);

        UpdateWindowView();

        if (!main.MusicManager.IsPlaying(LogicMusicID.mainmenu)) {
            main.MusicManager.Play(LogicMusicID.mainmenu);
        }
        ui.SetVersion(Application.version);
        var name = main.SaveManager.GetCurrentUserName();
        if (name == null)
            name = "";
        SetUserName(name);
        animatorBlendStart = mainmenuBlend;
        animatorBlendEnd = mainmenuBlend;
    }
    public function SetViewToBasement():Void {
        animator.SetTrigger("Instant");
        animatorBlendStart = basementBlend;
        animatorBlendEnd = basementBlend;
        var blend = GetCurrentAnimatorBlend();
        animator.SetFloat("BlendX", blend.x);
        animator.SetFloat("BlendY", blend.y);
        ui.SetRayblockerActive(false);
    }
    public function Reload():Void {
        Hide();
        Display();
    }
    // PORT-NOTE: C# `async void Init()`；Haxe 无 async，await 改为 awaitResult()，方法不阻塞。
    public function Init():Void {
        var userName = main.SaveManager.GetCurrentUserName();
        if (userName == null || userName.length == 0) {
            main.Scene.ShowInputNameDialogAsync(InputNameType.Initialize).awaitResult();
            // PORT-NOTE: awaitResult 是同步直通（见 system/threading/tasks/Task.hx），
            // 拿不到玩家在对话框里的输入；原样移植 result 恒为 null，流程跳过改名，
            // 用户名一直是空 —— 进关卡后的存档读取会把空名当损坏。同步模型的等价改法：
            // 以默认名补上并收起对话框（原版此处弹 InputNameDialog 等玩家输入）。
            // TODO-PORT: Task.awaitResult 协程化后还原为读取玩家输入。
            main.Scene.HideInputNameDialog();
            RenameUser(main.SaveManager.GetCurrentUserIndex(), mvz2.scenes.GameEntrance.DEFAULT_NEW_USERNAME);
        }
        ui.SetRayblockerActive(false);
    }
    // #region 生命周期
    private function Awake():Void {
        mainmenuActionDict.set(MainmenuButtonType.Adventure, OnAdventureButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Options, OnOptionsButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Help, OnHelpButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.UserManage, OnUserManageButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Quit, OnQuitButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Almanac, OnAlmanacButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Store, OnStoreButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.MoreMenu, OnMoreMenuButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.BackToMenu, OnBackToMenuButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Archive, OnArchiveButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Addons, OnAddonsButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Stats, OnStatsButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Achievement, OnAchievementButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.MusicRoom, OnMusicRoomButtonClickCallback);
        mainmenuActionDict.set(MainmenuButtonType.Arcade, OnArcadeButtonClickCallback);
        ui.OnMainmenuButtonUpdateSprite.add(OnMainmenuButtonUpdateSpriteCallback);
        ui.OnMainmenuButtonClick.add(OnMainmenuButtonClickCallback);

        ui.OnUserManageDialogButtonClick.add(OnUserManageDialogButtonClickCallback);
        ui.OnUserManageDialogUserSelect.add(OnUserManageUserSelectCallback);
        ui.OnUserManageDialogCreateNewUserButtonClick.add(OnUserManageCreateNewUserButtonClickCallback);

        ui.OnStatsReturnButtonClick.add(OnStatsReturnClickCallback);
        ui.OnAchievementsReturnButtonClick.add(OnAchievementsReturnClickCallback);

        if (optionsDialogController != null)
            optionsDialogController.OnClose.add(OnOptionsCloseClickCallback);
    }
    private function Update():Void {
        if (Application.isEditor) {
            if (Input.GetKeyDown(KeyCode.F1)) {
                StartCoroutine(GotoDebugStage(VanillaAreaID.halloween));
            } else if (Input.GetKeyDown(KeyCode.F2)) {
                StartCoroutine(GotoDebugStage(VanillaAreaID.dream));
            } else if (Input.GetKeyDown(KeyCode.F3)) {
                StartCoroutine(GotoDebugStage(VanillaAreaID.castle));
            } else if (Input.GetKeyDown(KeyCode.F4)) {
                StartCoroutine(GotoDebugStage(VanillaAreaID.mausoleum));
            } else if (Input.GetKeyDown(KeyCode.F5)) {
                StartCoroutine(GotoDebugStage(VanillaAreaID.ship));
            } else if (Input.GetKeyDown(KeyCode.F6)) {
                StartCoroutine(GotoDebugStage(VanillaAreaID.palace));
            }
        }
        if (animatorBlendTimeout > 0) {
            animatorBlendTimeout -= Time.deltaTime;
            if (animatorBlendTimeout <= 0) {
                animatorBlendTimeout = 0;
                ui.SetRayblockerActive(false);
            }
            var blend = GetCurrentAnimatorBlend();
            animator.SetFloat("BlendX", blend.x);
            animator.SetFloat("BlendY", blend.y);
        }
    }
    // #endregion

    // #region 事件回调
    private function OnMainmenuButtonUpdateSpriteCallback(type:MainmenuButtonType, button:MainmenuButton):Void {
        var sprKey = button.NormalSprite;
        if (!button.Interactable) {
            sprKey = button.DisabledSprite;
        } else if (button.IsHovered) {
            sprKey = button.HoveredSprite;
        }
        var spr = main.GetFinalSpriteFromSprite(sprKey);
        button.SetSprite(spr);
    }
    private function OnMainmenuButtonClickCallback(type:MainmenuButtonType):Void {
        if (mainmenuActionDict.exists(type)) {
            var action = mainmenuActionDict.get(type);
            if (action != null)
                action();
        }
    }
    private function OnAdventureButtonClickCallback():Void {
        StartCoroutine(StartAdventure());
    }
    private function OnOptionsButtonClickCallback():Void {
        ui.SetOptionsDialogVisible(true);
        var context = new OptionContextMainmenu();
        optionsDialogController.Open(context);
    }
    private function OnHelpButtonClickCallback():Void {
        main.SoundManager.Play2D(LogicSoundID.paper);
        main.MusicManager.Stop();
        var buttonText = main.LanguageManager._(LogicStrings.BACK);
        main.Scene.DisplayNote(VanillaNoteID.help, buttonText);
    }
    private function OnUserManageButtonClickCallback():Void {
        ui.SetUserManageDialogVisible(true);
        RefreshUserManageDialog();
    }
    private function OnQuitButtonClickCallback():Void {
        var title = main.LanguageManager._(LogicStrings.QUIT);
        var desc = main.LanguageManager._(QUIT_DESC);
        main.Scene.ShowDialogSelect(title, desc, function(value:Bool) {
            if (value)
                Application.Quit();
        });
    }

    private function OnAlmanacButtonClickCallback():Void {
        main.Scene.DisplayAlmanac(() -> main.Scene.DisplayMainmenu());
    }
    private function OnStoreButtonClickCallback():Void {
        main.Scene.DisplayStore(() -> main.Scene.DisplayMainmenu(), false);
    }
    private function OnMoreMenuButtonClickCallback():Void {
        StartAnimatorTransition(basementBlend);
    }

    private function OnBackToMenuButtonClickCallback():Void {
        StartAnimatorTransition(mainmenuBlend);
    }
    private function OnArchiveButtonClickCallback():Void {
        main.Scene.DisplayArchive(() -> main.Scene.DisplayMainmenuToBasement());
    }
    private function OnAddonsButtonClickCallback():Void {
        main.Scene.DisplayAddons(() -> main.Scene.DisplayMainmenuToBasement());
    }
    private function OnStatsButtonClickCallback():Void {
        ReloadStats();
        StartAnimatorTransition(statsBlend);
    }
    private function OnAchievementButtonClickCallback():Void {
        ReloadAchievements();
        StartAnimatorTransition(achievementsBlend);
    }
    private function OnMusicRoomButtonClickCallback():Void {
        main.Scene.DisplayMusicRoom(() -> main.Scene.DisplayMainmenu());
    }
    private function OnArcadeButtonClickCallback():Void {
        main.Scene.DisplayArcade(() -> main.Scene.DisplayMainmenu());
    }

    private function OnOptionsCloseClickCallback(needsReload:Bool):Void {
        ui.SetOptionsDialogVisible(false);
        if (needsReload) {
            Reload();
        }
    }

    // #region 用户管理
    private function OnUserManageUserSelectCallback(index:Int):Void {
        selectedUserArrayIndex = index;
        UpdateUserManageButtons();
    }
    // PORT-NOTE: C# `async void`；await 改为 awaitResult()，方法不阻塞。
    private function OnUserManageCreateNewUserButtonClickCallback():Void {
        var result:String = main.Scene.ShowInputNameDialogAsync(InputNameType.CreateNewUser).awaitResult();
        if (result != null && result.length > 0) {
            main.SaveManager.CreateNewUser(result);
            main.SaveManager.SaveUserList();
            RefreshUserManageDialog();
        }
    }
    // PORT-NOTE: C# `async void`；await 改为 awaitResult()，方法不阻塞。
    // PORT-NOTE: C# 中该方法与主菜单按钮的 OnUserManageButtonClickCallback() 同名重载；
    // Haxe 不支持重载，对话框按钮的版本改名 OnUserManageDialogButtonClickCallback。
    private function OnUserManageDialogButtonClickCallback(type:UserManageButtonType):Void {
        switch (type) {
            case UserManageButtonType.Rename:
                {
                    var userIndex = GetSelectedUserIndex();
                    var currentName = main.SaveManager.GetUserName(userIndex);
                    if (!main.SaveManager.CanRenameUser(currentName)) {
                        var title = main.LanguageManager._(LogicStrings.HINT);
                        var desc = main.LanguageManager._(LogicStrings.ERROR_MESSAGE_CANNOT_RENAME_THIS_USER);
                        main.Scene.ShowDialogMessage(title, desc);
                    } else {
                        var result:String = main.Scene.ShowInputNameDialogRenameAsync(userIndex).awaitResult();
                        if (result != null && result.length > 0) {
                            RenameUser(userIndex, result);
                        }
                    }
                }
            case UserManageButtonType.Delete:
                {
                    var userIndex = GetSelectedUserIndex();
                    var title = main.LanguageManager._(LogicStrings.WARNING);
                    var desc = main.LanguageManager._(LogicStrings.WARNING_DELETE_USER, [main.SaveManager.GetUserName(userIndex)]);
                    main.Scene.ShowDialogSelect(title, desc, function(value:Bool) {
                        if (value) {
                            DeleteUser(GetSelectedUserIndex());
                        }
                    });
                }
            case UserManageButtonType.Switch:
                {
                    var userIndex = GetSelectedUserIndex();
                    SwitchUser(userIndex);
                }
            case UserManageButtonType.Back:
                {
                    HideUserManageDialog();
                }
            case UserManageButtonType.Import:
                {
                    if (IsUserFull()) {
                        // C# 此处为 break，跳出 switch。
                    } else {
                        FileHelper.OpenExternalFile(["zip"], OnImportPathSelected).awaitResult();
                    }
                }
            case UserManageButtonType.Export:
                {
                    var userIndex = GetSelectedUserIndex();
                    if (userIndex >= 0) {
                        var userName = main.SaveManager.GetUserName(userIndex);
                        var success = false;
                        var fileName = userName != null ? userName : 'user${userIndex}';
                        for (chr in INVALID_FILE_NAME_CHARS) {
                            fileName = StringTools.replace(fileName, chr, "_");
                        }

                        var path:String = FileHelper.SaveExternalFile(fileName, ["zip"], function(dest:String) {
                            if (dest == null || dest.length == 0)
                                return;
                            try {
                                success = main.SaveManager.ExportUserDataPack(userIndex, dest);
                            } catch (e:Dynamic) {
                                success = false;
                            }
                        }).awaitResult();
                        if (path == null || path.length == 0) {
                            // C# 此处为 break，跳出 switch。
                        } else {
                            var title:String;
                            var desc:String;
                            if (!success) {
                                title = main.LanguageManager._(LogicStrings.ERROR);
                                desc = main.LanguageManager._(ERROR_NOT_EXPORTED);
                            } else {
                                title = main.LanguageManager._(LogicStrings.HINT);
                                desc = main.LanguageManager._(HINT_EXPORTED, [path]);
                            }
                            main.Scene.ShowDialogMessageAsync(title, desc).awaitResult();
                        }
                    }
                }
            case _:
        }
    }
    // PORT-NOTE: C# `async void`；await 改为 awaitResult()，方法不阻塞。
    private function OnImportPathSelected(path:String):Void {
        try {
            var userIndex = main.SaveManager.FindFreeUserIndex();
            if (userIndex < 0)
                return;
            if (path == null || path.length == 0)
                return;
            if (!File.Exists(path))
                return;

            var metadata:UserDataPackMetadata;
            try {
                metadata = main.SaveManager.ImportUserDataPackMetadata(path);
                if (metadata == null) {
                    throw 'Cannot import user data pack metadata from path ${path}';
                }
            } catch (e:Dynamic) {
                // 加载失败，用户文件可能损坏。
                var title = main.LanguageManager._(LogicStrings.ERROR);
                var desc = main.LanguageManager._(ERROR_CORRUPT_USER_DATA_PACK);
                main.Scene.ShowDialogMessage(title, desc);
                return;
            }

            // 如果有重复的名称，则提示用户重新命名。
            var userName = metadata.username;
            if (main.SaveManager.HasDuplicateUserName(userName, -1)) {
                // 如果不能重命名，直接提示错误。
                if (!main.SaveManager.CanRenameUser(userName)) {
                    var title = main.LanguageManager._(LogicStrings.ERROR);
                    var desc = main.LanguageManager._(ERROR_DUPLICATE_IMPORTING_USER_NAME_AND_CANNOT_RENAME);
                    main.Scene.ShowDialogMessage(title, desc);
                    return;
                } else {
                    var newName:String = main.Scene.ShowInputNameDialogAsync(InputNameType.Rename).awaitResult();
                    if (newName == null || newName.length == 0)
                        return;
                    userName = newName;
                }
            }

            main.SaveManager.ImportUserDataPack(userName, userIndex, path);
            RefreshUserManageDialog();
        } catch (e:Dynamic) {
            Debug.LogError('导入用户存档时出现错误：${e}');
        }
    }
    // #endregion

    // #region 统计
    private function OnStatsReturnClickCallback():Void {
        StartAnimatorTransition(basementBlend);
    }
    private function OnAchievementsReturnClickCallback():Void {
        StartAnimatorTransition(basementBlend);
    }
    // #endregion

    // #endregion

    // PORT-NOTE: C# IEnumerator 协程 → unity.Coroutine 步骤函数（PORTING.md §协程）。
    private function StartAdventure():Coroutine {
        return Coroutine.create(function(co:CoroutineContext) {
            if (!main.IsFastMode()) {
                isDark = true;
                ui.SetBackgroundDark(true);
                UpdateWindowView();
                main.MusicManager.Stop();
                main.SoundManager.Play2D(LogicSoundID.loseMusic);

                for (button in GetAllButtons()) {
                    button.Interactable = false;
                }

                co.wait(6);
            }
            if (main.SaveManager.IsLevelCleared(VanillaStageID.prologue)) {
                var lastMapID = main.SaveManager.GetLastMapID();
                if (lastMapID == null)
                    lastMapID = main.ResourceManager.GetFirstMapID();
                main.Scene.DisplayMap(lastMapID);
            } else {
                var task = GotoPrologue();
                while (!task.isCompleted) {
                    co.waitFrames(1);
                }
            }
        });
    }
    private function GetAllButtons():Iterable<MainmenuButton> {
        return ui.GetAllButtons();
    }
    private function GotoPrologue():Task {
        main.LevelManager.GotoLevelSceneAsync().awaitResult();
        main.LevelManager.InitLevel(VanillaAreaID.day, VanillaStageID.prologue);
        Hide();
        return Task.completedTask();
    }
    // PORT-NOTE: C# IEnumerator 协程 → unity.Coroutine 步骤函数。
    private function GotoDebugStage(areaID:NamespaceID):Coroutine {
        return Coroutine.create(function(co:CoroutineContext) {
            var task = main.LevelManager.GotoLevelSceneAsync();
            while (!task.IsCompleted)
                co.waitFrames(1);
            main.LevelManager.InitLevel(areaID, VanillaStageID.debug);
            Hide();
        });
    }

    // #region 用户管理
    private function DeleteUser(userIndex:Int):Void {
        try {
            var currentUserIndex = main.SaveManager.GetCurrentUserIndex();
            if (userIndex == currentUserIndex) {
                // 要删除当前存档，需要切换至其他存档。
                SwitchToOtherUserBeforeDelete(userIndex);
                // 切换成功。
                HideUserManageDialog();
                Reload();
                main.SaveManager.DeleteUser(userIndex);
            } else {
                main.SaveManager.DeleteUser(userIndex);
                RefreshUserManageDialog();
            }
            main.SaveManager.SaveUserList();
        } catch (e:Dynamic) {
            var title = main.LanguageManager._(LogicStrings.ERROR);
            var desc = main.LanguageManager._(ERROR_MESSAGE_UNABLE_TO_DELETE_USER, [e.message]);
            main.Scene.ShowDialogMessage(title, desc);
            Debug.LogError('Unable to delete user${userIndex}\'s save data : ${e}');
        }
    }
    private function RenameUser(userIndex:Int, name:String):Void {
        main.SaveManager.SetUserName(userIndex, name);
        main.SaveManager.SaveUserList();
        RefreshUserManageDialog();
        var currentUserIndex = main.SaveManager.GetCurrentUserIndex();
        if (userIndex == currentUserIndex) {
            SetUserName(name);
        }
    }
    private function SwitchUser(userIndex:Int):Void {
        try {
            main.SaveManager.SaveToFile(); // 切换用户时保存游戏
            main.SaveManager.SetCurrentUserIndex(userIndex);
            main.SaveManager.SaveUserList();
            HideUserManageDialog();
            Reload();
        } catch (e:Dynamic) {
            var title = main.LanguageManager._(LogicStrings.ERROR);
            var desc = main.LanguageManager._(ERROR_MESSAGE_UNABLE_TO_SWITCH_TO_USER, [e.message]);
            main.Scene.ShowDialogMessage(title, desc);
            Debug.LogError('Unable to switch to user${userIndex}\'s save data : ${e}');
        }
    }
    private function SwitchToOtherUserBeforeDelete(currentIndex:Int):Void {
        main.SaveManager.SaveToFile(); // 删除用户前先保存当前存档，以防出现错误。
        // 获取所有后备的可选其他存档。
        var backupUserIndexes = Lambda.filter(managingUserIndexes, u -> u != currentIndex);
        var success = false;
        for (nextUserIndex in backupUserIndexes) {
            try {
                // 切换至其他存档。
                main.SaveManager.SetCurrentUserIndex(nextUserIndex);
                // 切换成功。
                success = true;
                break;
            } catch (e:Dynamic) {
                // 切换失败，换下一个。
                Debug.LogError('Unable to switch to user${nextUserIndex}\'s save data while deleting user${currentIndex} : ${e}');
            }
        }
        // 切换成功，或者全部切换失败。
        if (!success) {
            // 全部切换失败，重新读取当前存档，防止出现错误。
            main.SaveManager.LoadUserData(currentIndex);
            // 报错。
            var message = main.LanguageManager._(ERROR_MESSAGE_NO_SPARE_USERS_TO_SWITCH);
            // PORT-NOTE: system.InvalidOperationException 在 Haxe 侧无 shim，直接抛出错误信息字符串。
            throw message;
        }
    }
    private function GetSelectedUserIndex():Int {
        if (managingUserIndexes == null)
            return -1;
        if (selectedUserArrayIndex < 0 || selectedUserArrayIndex >= managingUserIndexes.length)
            return -1;
        return managingUserIndexes[selectedUserArrayIndex];
    }
    private function RefreshUserManageDialog():Void {
        var users = main.SaveManager.GetAllUsers();
        var currentIndex = main.SaveManager.GetCurrentUserIndex();
        var userIndexes:Array<Int> = [];
        for (i in 0...users.length) {
            if (users[i] != null)
                userIndexes.push(i);
        }
        var reorderedUserPairs:Array<Int> = [currentIndex];
        for (i in userIndexes) {
            if (i != currentIndex)
                reorderedUserPairs.push(i);
        }
        managingUserIndexes = reorderedUserPairs;
        selectedUserArrayIndex = managingUserIndexes.indexOf(currentIndex);
        var names:Array<UserNameItemViewData> = [];
        names.resize(managingUserIndexes.length);
        for (i in 0...names.length) {
            var name = main.SaveManager.GetUserName(managingUserIndexes[i]);
            if (name == null)
                name = "";
            var isSpecialName = name.length > 0 && main.Game.IsSpecialUserName(name);
            var itemData = new UserNameItemViewData();
            itemData.name = name;
            itemData.color = isSpecialName ? Color.red : Color.black;
            names[i] = itemData;
        }
        ui.UpdateUserManageDialog(names, selectedUserArrayIndex);
        UpdateUserManageButtons();
    }
    private function HideUserManageDialog():Void {
        selectedUserArrayIndex = -1;
        managingUserIndexes = null;
        ui.SetUserManageDialogVisible(false);
    }
    private function UpdateUserManageButtons():Void {
        var selected = selectedUserArrayIndex >= 0;
        var hasEmptySlot = !IsUserFull();
        ui.SetUserManageCreateNewUserActive(hasEmptySlot);
        ui.SetUserManageButtonInteractable(UserManageButtonType.Rename, selected);
        ui.SetUserManageButtonInteractable(UserManageButtonType.Delete, selected && managingUserIndexes != null && managingUserIndexes.length >= 2);
        ui.SetUserManageButtonInteractable(UserManageButtonType.Switch, selected && GetSelectedUserIndex() != main.SaveManager.GetCurrentUserIndex());
        ui.SetUserManageButtonInteractable(UserManageButtonType.Import, hasEmptySlot);
        ui.SetUserManageButtonInteractable(UserManageButtonType.Export, selected);
    }
    private function IsUserFull():Bool {
        return managingUserIndexes != null && managingUserIndexes.length >= SaveManager.MAX_USER_COUNT;
    }
    // #endregion

    private function StartAnimatorTransition(target:Vector2):Void {
        animatorBlendStart = GetCurrentAnimatorBlend();
        animatorBlendEnd = target;
        animatorBlendTimeout = transitionTime;
        ui.SetRayblockerActive(true);
    }
    private function GetCurrentAnimatorBlend():Vector2 {
        return Vector2.Lerp(animatorBlendStart, animatorBlendEnd, easeInAndOut((transitionTime - animatorBlendTimeout) / transitionTime));
    }
    private function UpdateWindowView():Void {
        var saves = main.SaveManager;
        var resources = main.ResourceManager;
        var viewsID = resources.GetAllMainmenuViews();
        var metas = Lambda.array(Lambda.filter(Lambda.map(viewsID, id -> resources.GetMainmenuViewMeta(id)), m -> Std.isOfType(m, MainmenuViewMeta)));
        metas.sort((a, b) -> b.Priority - a.Priority);
        var sprite:Sprite = null;
        var sheetIndex = isDark ? 1 : 0;
        for (meta in metas) {
            if (meta.Conditions.IsNullOrMeetsConditions(saves) && NamespaceID.IsValid(meta.SpritesheetID)) {
                var spriteRef = SpriteReference.FromSheet(meta.SpritesheetID, sheetIndex);
                if (SpriteReference.IsValid(spriteRef)) {
                    sprite = main.GetFinalSpriteFromRef(spriteRef);
                    break;
                }
            }
        }
        ui.SetWindowViewSprite(sprite);
    }
    private function SetUserName(name:String):Void {
        var isSpecialName = main.Game.IsSpecialUserName(name);
        ui.SetUserName(name);
        ui.SetUserNameColor(isSpecialName ? Color.red : Color.black);
        ui.SetUserNameGold(!isSpecialName && main.SponsorManager.HasSponsorPlan(name, SponsorPlans.FURNACE_TYPE, SponsorPlans.FURNACE_BLAST_FURNACE));
    }

    // #region 统计
    private function ReloadStats():Void {
        main.SaveManager.UpdatePlayTime();

        var nsp = main.BuiltinNamespace;
        var stats:UserStats = main.SaveManager.GetUserStats(nsp);

        var playTime = stats != null ? stats.PlayTimeMilliseconds : haxe.Int64.ofInt(0);
        var playTimeText = GetPlayTimeText(playTime);

        var entries:Array<UserStatDirectEntry> = stats != null ? stats.GetAllDirectEntries() : [];
        var entriesViewData = GetDirectEntriesViewData(nsp, entries);

        var categories:Array<UserStatCategory> = stats != null ? stats.GetAllCategories() : [];
        var categoriesViewData = GetCategoriesViewData(nsp, categories);

        var viewData = new StatsViewData();
        viewData.playTimeText = playTimeText;
        viewData.entries = entriesViewData;
        viewData.categories = categoriesViewData;
        ui.UpdateStats(viewData);
    }
    private function GetPlayTimeText(milliseconds:haxe.Int64):String {
        // PORT-NOTE: system.TimeSpan shim 未提供 TotalHours/Minutes/Seconds，这里按时长直接换算。
        // TODO-PORT: 待 system.TimeSpan 补齐 TotalHours/Minutes/Seconds 后改回 TimeSpan.FromMilliseconds 的写法。
        var totalSeconds = haxe.Int64.toInt(milliseconds / haxe.Int64.ofInt(1000));
        // 计算总小时数（整数部分）
        var totalHours = Std.int(totalSeconds / 3600);
        // 剩下的分钟和秒
        var minutes = Std.int((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        // 格式化为字符串：总小时数:分钟:秒
        return '${formatD2(totalHours)}:${formatD2(minutes)}:${formatD2(seconds)}';
    }
    // PORT-NOTE: C# 数值格式 "D2"（至少两位，不足补零）。
    private static function formatD2(value:Int):String {
        return value < 10 ? '0${value}' : Std.string(value);
    }
    private function GetCategoriesViewData(nsp:String, categories:Array<UserStatCategory>):Array<StatCategoryViewData> {
        var categoriesViewData:Array<StatCategoryViewData> = [];
        categoriesViewData.resize(categories.length);
        for (i in 0...categoriesViewData.length) {
            var category = categories[i];
            var meta = main.ResourceManager.GetStatCategoryMeta(new NamespaceID(nsp, category.Name));
            var metaName = meta != null ? meta.Name : category.Name;
            var metaType = meta != null ? meta.Type : StatCategoryType.Entity;
            var metaOperation = meta != null ? meta.Operation : StatOperation.Sum;

            var title = main.LanguageManager._p(LogicStrings.CONTEXT_STAT_CATEGORY, metaName);

            var categoryNumber = haxe.Int64.ofInt(0);
            // 子项。
            var entries = category.GetAllEntries();
            var entriesViewData:Array<StatEntryViewData> = [];
            for (j in 0...entries.length) {
                var entry = entries[j];
                if (!main.ResourceManager.ShouldStatEntryDisplay(entry.ID, metaType))
                    continue;
                var name = main.ResourceManager.GetStatEntryName(entry.ID, metaType);
                var count = entry.Value;
                var entryData = new StatEntryViewData();
                entryData.name = name;
                entryData.count = count;
                entriesViewData.push(entryData);
                switch (metaOperation) {
                    case StatOperation.Sum:
                        categoryNumber = categoryNumber + count;
                    case StatOperation.Max:
                        if (count > categoryNumber) categoryNumber = count;
                    case _:
                }
            }
            // 大类数字显示。
            var categoryNumberString = Std.string(categoryNumber);

            entriesViewData.sort((a, b) -> (a.count > b.count ? -1 : (a.count < b.count ? 1 : 0)));
            var categoryData = new StatCategoryViewData();
            categoryData.entries = entriesViewData;
            categoryData.sum = categoryNumberString;
            categoryData.title = title;
            categoriesViewData[i] = categoryData;
        }
        return categoriesViewData;
    }
    private function GetDirectEntriesViewData(nsp:String, entries:Array<UserStatDirectEntry>):Array<StatDirectEntryViewData> {
        var entriesViewData:Array<StatDirectEntryViewData> = [];
        for (i in 0...entries.length) {
            var entry = entries[i];
            var meta = main.ResourceManager.GetStatDirectEntryMeta(new NamespaceID(nsp, entry.ID));
            if (meta == null)
                continue;
            // 子项。
            var name = main.LanguageManager._p(LogicStrings.CONTEXT_STAT_ENTRY, meta.Name);
            var count = entry.Value;
            if (count <= 0)
                continue;
            var entryData = new StatDirectEntryViewData();
            entryData.name = name;
            entryData.number = Std.string(count);
            entriesViewData.push(entryData);
        }
        return entriesViewData;
    }
    // #endregion

    // #region 成就
    private function ReloadAchievements():Void {
        var nsp = main.BuiltinNamespace;
        var metas = main.ResourceManager.GetModAchievementMetas(nsp);
        var viewDatas:Array<AchievementEntryViewData>;
        if (metas != null) {
            viewDatas = [];
            viewDatas.resize(metas.length);
            for (i in 0...viewDatas.length) {
                var meta = metas[i];
                if (meta == null)
                    continue;
                var iconRef = meta.Icon;
                var metaName = meta.Name;
                var metaDescription = meta.Description;

                var icon = main.GetFinalSpriteFromRef(iconRef);
                var name = main.LanguageManager._p(LogicStrings.CONTEXT_ACHIEVEMENT, metaName);
                var earned = main.SaveManager.IsAchievementEarned(new NamespaceID(nsp, meta.ID));
                var description = main.LanguageManager._p(LogicStrings.CONTEXT_ACHIEVEMENT, metaDescription);
                var entryData = new AchievementEntryViewData();
                entryData.icon = icon;
                entryData.name = name;
                entryData.earned = earned;
                entryData.description = description;
                viewDatas[i] = entryData;
            }
        } else {
            viewDatas = [];
        }
        ui.UpdateAchievements(viewDatas);
    }
    // #endregion

    // #region 属性字段
    @:translateMsg("删除用户时的错误信息，{0}为错误信息")
    public static inline var ERROR_MESSAGE_UNABLE_TO_DELETE_USER:String = "无法删除用户：{0}";
    @:translateMsg("切换用户时的错误信息，{0}为错误信息")
    public static inline var ERROR_MESSAGE_UNABLE_TO_SWITCH_TO_USER:String = "无法切换至用户：{0}";
    @:translateMsg("删除用户时的错误信息")
    public static inline var ERROR_MESSAGE_NO_SPARE_USERS_TO_SWITCH:String = "没有其他有效的用户可供切换。";
    @:translateMsg("退出对话框的描述")
    public static inline var QUIT_DESC:String = "确认要退出吗？";
    @:translateMsg("存档导出失败的警告")
    public static inline var ERROR_NOT_EXPORTED:String = "导出存档失败。";
    @:translateMsg("存档导入失败的警告")
    public static inline var ERROR_FAILED_TO_IMPORT:String = "导入存档失败。";
    @:translateMsg("存档导入失败的警告")
    public static inline var ERROR_CORRUPT_USER_DATA_PACK:String = "导入存档失败，文件可能已损坏。";
    @:translateMsg("存档导入失败的警告")
    public static inline var ERROR_DUPLICATE_IMPORTING_USER_NAME_AND_CANNOT_RENAME:String = "导入存档失败，游戏中存在同名用户，但正在导入的存档不可重命名。";
    @:translateMsg("存档导出成功的提示，{0}为路径")
    public static inline var HINT_EXPORTED:String = "存档已导出至{0}。";

    // PORT-NOTE: C# `Path.GetInvalidFileNameChars()` 在 system.io.Path shim 中缺失，
    // 这里给出 Windows 平台等价的非法文件名字符集合。
    // TODO-PORT: 字符集为按 Windows 惯例手工列举（未包含 0x00-0x1F 控制字符），待 shim 补齐后替换。
    // PORT-NOTE: inline 变量必须是常量表达式，数组字面量不满足，故去掉 inline
    private static var INVALID_FILE_NAME_CHARS:Array<String> = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"];

    // PORT-NOTE: C# Tools.Mathematics.Transitions.EaseInAndOut 未在 tools.Transitions 中实现，
    // 这里按三次缓入缓出（easeInOutCubic）提供最小等价实现。
    // TODO-PORT: 无法核对外部 Tools 库缓动曲线的原始实现，缓动结果可能与原版有细微差异。
    private static function easeInAndOut(progress:Float):Float {
        progress = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
        if (progress < 0.5)
            return 4 * progress * progress * progress;
        var inv = -2 * progress + 2;
        return 1 - inv * inv * inv / 2;
    }

    private var mainmenuActionDict:Map<MainmenuButtonType, Void->Void> = new Map();

    private var main(get, never):MainManager;
    inline function get_main():MainManager return MainManager.Instance;

    @:serializeField
    private var ui:MainmenuUI = null;
    @:serializeField
    private var animator:Animator = null;
    @:serializeField
    private var transitionTime:Float = 1;
    @:serializeField
    private var mainmenuBlend:Vector2 = new Vector2(0, 0);
    @:serializeField
    private var basementBlend:Vector2 = new Vector2(0, -1);
    @:serializeField
    private var statsBlend:Vector2 = new Vector2(-1, -1);
    @:serializeField
    private var achievementsBlend:Vector2 = new Vector2(1, -1);
    @:serializeField
    private var optionsDialogController:mvz2.options.OptionsDialogController = null;
    private var managingUserIndexes:Array<Int>;
    private var selectedUserArrayIndex:Int = -1;
    private var isDark:Bool;

    private var animatorBlendStart:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    private var animatorBlendEnd:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    private var animatorBlendTimeout:Float;

    // #endregion
}

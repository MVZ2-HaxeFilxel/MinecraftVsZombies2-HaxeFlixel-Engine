// Ported from: Assets/Scripts/MVZ2/Saves/SaveManager.cs
// Ported from: Assets/Scripts/MVZ2/Saves/SaveManager_Users.cs (partial class 合并)
package mvz2.saves;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2logic.callbacks.LogicCallbacks.PostUserLoadParams;  // SUBIMPORT
import haxe.io.Bytes;
import mvz2.io.FileHelper;
import mvz2.io.ZipArchiveHelper;
import mvz2.managers.MainManager;
import mvz2.modding.ModInfo;
import mvz2.saves.UserDataList.SerializableUserDataList;  // IMPORTFIX
import mvz2.oldsave.OldSaveDataConvertor;
import mvz2.oldsave.OldSaveDataMain.OldSaveData;
import mvz2.oldsave.OldGlobalSave;  // IMPORTFIX
import mvz2.oldsave.OldUserList;  // IMPORTFIX
import mvz2logic.Global;
import mvz2logic.callbacks.LogicCallbacks;
import mvz2logic.conditions.IConditionList;
import mvz2logic.games.IGlobalSaveData;
import mvz2logic.saves.LogicSaveData;
import mvz2logic.saves.ModSaveData;
import mvz2logic.saves.UserStats;
import mvz2logic.serialization.SerializeHelper;
import pvzengine.EntityTypes;
import pvzengine.Log;
import pvzengine.NamespaceID;
import system.Guid;
import system.io.Directory;
import system.io.File;
import system.io.FileMode;
import system.io.Path;
import system.io.SearchOption;
import system.io.compression.ZipArchive;
import system.io.compression.ZipArchiveMode;
import system.io.compression.ZipFileExtensions;
import system.text.Encoding;
import unity.Debug;
import unity.Time;
using mvz2logic.games.LogicGameDefinitionsExt;  // EXTUSING
using mvz2logic.entities.LogicEntityProps;  // EXTUSING
using mvz2logic.games.LogicGameExt;  // EXTUSING
using mvz2logic.artifacts.LogicArtifactProps;  // EXTUSING
using mvz2logic.difficulties.LogicDifficultyProps;  // EXTUSING
using mvz2.io.FileHelper;  // EXTUSING
using mvz2.io.ZipArchiveHelper;  // EXTUSING
using mvz2.saves.MVZ2SaveExt;  // EXTUSING
using mvz2logic.serialization.SerializeHelper;  // EXTUSING
using pvzengine.ContentProviderHelper;  // EXTUSING
using pvzengine.PropertyKeyHelper;  // EXTUSING
using system.io.compression.ZipFileExtensions;  // EXTUSING

class SaveManager extends unity.MonoBehaviour implements IGlobalSaveData {
    public function new() {
        super();
    }

    // #region 保存
    public function SaveToFile():Void {
        var playTime = GetPlayTimeDeltaMilliseconds();
        UpdatePlayTimeDelta();
        for (mod in Main.ModManager.GetAllModInfos()) {
            SaveCurrentModData(mod.Namespace, playTime);
        }
    }
    public function SaveCurrentModData(spaceName:String, playTimeDelta:haxe.Int64):Void {
        if (userDataList == null)
            return;
        SaveModData(userDataList.CurrentUserIndex, spaceName, playTimeDelta);
    }
    public function SaveModData(userIndex:Int, spaceName:String, playTimeDelta:haxe.Int64):Void {
        var modSaveData = GetModSaveData(spaceName);
        if (modSaveData == null)
            return;
        UpdatePlayTimeMod(modSaveData, playTimeDelta);

        WriteSaveData(userIndex, spaceName, modSaveData);
    }
    private function WriteSaveData(userIndex:Int, spaceName:String, modSaveData:ModSaveData):Void {
        var modInfo = Main.ModManager.GetModInfo(spaceName);
        if (modInfo == null || modInfo.Logic == null)
            return;

        // PORT-NOTE: C# 的 lock (_saveLock) 在 Haxe 单线程游戏逻辑中无对应语义，直接顺序执行。
        {
            // 1. 将存档写入临时文件。
            var guid = Guid.NewGuid().ToString("N");
            var tempSavePath = Path.Combine(unity.Application.temporaryCachePath, 'save_validate_${guid}.tmp');
            FileHelper.ValidateDirectory(tempSavePath);
            var serializable = modSaveData.ToSerializable();
            var metaJson = SerializeHelper.ToBson(serializable);
            Main.FileManager.WriteStringFile(tempSavePath, metaJson);

            // 2. 检验临时文件能否正确被读取。如果不能则终止保存并发出警告。
            try {
                var validateString = Main.FileManager.ReadStringFile(tempSavePath);
                var validateSerializable = modInfo.Logic.LoadSaveData(validateString);
            } catch (e:Dynamic) {
                Log.LogWarning('保存用户${userIndex}的Mod${spaceName}的存档文件时发生错误，存档文件验证失败：${e}');
                if (File.Exists(tempSavePath))
                    File.Delete(tempSavePath);
                return;
            }

            // 3. 写入临时文件成功后，将备份文件和之前的存档文件写入备份。
            CycleSaveDataBackups(userIndex, spaceName);

            // 4. 用临时文件替换之前的存档文件
            var destPath = GetUserModSaveDataPath(userIndex, spaceName, 0);
            var backupPath = GetUserModSaveDataPath(userIndex, spaceName, 1);
            FileHelper.ValidateDirectory(destPath);

            try {
                // 如果原存档存在，将其安全移至备份路径
                if (File.Exists(destPath)) {
                    File.Copy(destPath, backupPath, true);
                }

                // 因为跨分区/跨目录，放弃使用 File.Move
                // 直接采用 File.Copy (覆盖模式)，在 Android 上这是最安全、权限通过率最高的底层 IO 方式
                File.Copy(tempSavePath, destPath, true);
            } catch (e:Dynamic) {
                Log.LogError('正式存档写入失败（Cache -> Persist）: ${e}');
            }
            // PORT-NOTE: Haxe 的 try 不支持 finally，清理逻辑顺序执行在 try/catch 之后。
            {
                // 无论正式写入成功还是失败，都把 cache 里的临时文件擦干净
                try {
                    if (File.Exists(tempSavePath)) {
                        File.Delete(tempSavePath);
                    }
                } catch (e:Dynamic) { /* 缓存文件删不掉也无所谓，系统后续会自动清理 */ }
            }
        }
    }
    private function CycleSaveDataBackups(userIndex:Int, spaceName:String):Void {
        var i = backupCount;
        while (i >= 1) {
            var savePath = GetUserModSaveDataPath(userIndex, spaceName, i);
            if (!File.Exists(savePath)) {
                i--;
                continue;
            }
            if (i == backupCount) {
                File.Delete(savePath);
            } else {
                var targetSavePath = GetUserModSaveDataPath(userIndex, spaceName, i + 1);
                FileHelper.Move(savePath, targetSavePath, true);
            }
            i--;
        }
    }
    // #endregion

    // #region 加载
    public function Load():Void {
        var rootDirectory = GetSaveDataRoot();
        if (!Directory.Exists(rootDirectory)) {
            try {
                var oldSaveData = mvz2.oldsave.OldSaveDataImporter.Import();
                ImportOldSaveData(oldSaveData);
            } catch (e:Dynamic) {
                Debug.LogError('An error has occured while importing save data from old version: ${e}');
            }
        }
        userDataList = LoadUserList();
        LoadInitialUserData(userDataList);
    }
    public function LoadUserData(index:Int):Void {
        modSaveDatas = [];
        var modInfos = Main.ModManager.GetAllModInfos();
        for (mod in modInfos) {
            LoadModData(index, mod);
        }
        EvaluateUnlocks(true);
        for (mod in modInfos) {
            PostAllModDataLoaded(index, mod);
        }

        var userName = GetUserName(index);
        if (userName == null) userName = "";
        var param = new PostUserLoadParams();
        param.userIndex = index;
        param.userName = userName;
        OnUserLoad.dispatch(index, userName);
        Main.Game.RunCallback(LogicCallbacks.POST_USER_LOAD, param);
    }
    public function GetSaveDataStatus():SaveDataStatus {
        return status;
    }
    private function LoadInitialUserData(userDataList:UserDataList):Void {
        // 预备一个所有存档的列表。
        var userIndexes:Array<Int> = [];
        var allUsers = userDataList.GetAllUsers();
        for (i in 0...allUsers.length) {
            if (allUsers[i] != null) userIndexes.push(i);
        }
        // 将当前存档索引调至第一位。
        userIndexes.remove(userDataList.CurrentUserIndex);
        userIndexes.insert(0, userDataList.CurrentUserIndex);

        // 按照顺序加载所有存档。
        for (index in userIndexes) {
            try {
                // 加载用户存档。
                LoadUserData(index);
                // 加载存档成功，将当前用户索引设置为该存档的索引，然后跳出。
                userDataList.CurrentUserIndex = index;
                SaveUserList();
                return;
            } catch (e:Dynamic) {
                // 加载存档失败，弹出警告。
                status.AddCorruptedUserIndex(index);
                status.State = SaveDataState.SomeCorrupted;
                Debug.LogWarning('存档加载失败：${e}');
            }
        }
        // 没有存档有效。
        if (userIndexes.length < MAX_USER_COUNT) {
            // 尝试创建一个存档。
            status.State = SaveDataState.AllCorrupted;
        } else {
            // 如果存档栏位都满了，强制要求玩家删除一个。
            status.State = SaveDataState.FullCorrupted;
        }
    }
    private function LoadModData(userIndex:Int, modInfo:ModInfo):Void {
        if (modInfo == null || modInfo.Logic == null)
            return;

        // 加载存档。
        var saveData:ModSaveData = null;

        var i = 0;
        // 如果目标存档文件不存在，或者加载失败了，那就尝试寻找备份文件。
        while (i <= backupCount) {
            var path = GetUserModSaveDataPath(userIndex, modInfo.Namespace, i);
            if (File.Exists(path)) {
                try {
                    var saveDataJson = Main.FileManager.ReadStringFile(path);
                    saveData = modInfo.Logic.LoadSaveData(saveDataJson);
                    break;
                } catch (e:Dynamic) {
                    Log.LogWarning('用户${userIndex}的MOD${modInfo.Namespace}的存档的第${i}份备份读取失败：${e}');
                }
            }
            i++;
        }


        // 如果备份文件都加载失败了或不存在，直接创建一个新存档。
        if (saveData == null) {
            saveData = modInfo.Logic.CreateSaveData();
            Log.LogWarning('无法读取用户${userIndex}的MOD${modInfo.Namespace}的存档或任何备份，创建一个新存档。');
        } else {
            if (i > 0) {
                Log.LogWarning('用户${userIndex}的MOD${modInfo.Namespace}的存档将以第${i}份备份开始游戏。');
            }
        }


        modSaveDatas.push(saveData);
    }
    private function PostAllModDataLoaded(userIndex:Int, modInfo:ModInfo):Void {
        if (modInfo == null || modInfo.Logic == null)
            return;
        modInfo.Logic.PostAllSaveDataLoaded();
    }
    // #endregion

    // #region 获取
    public function GetModSaveData(spaceName:String):ModSaveData {
        return Lambda.find(modSaveDatas, s -> s.Namespace == spaceName);
    }
    // PORT-NOTE: C# 泛型方法 GetModSaveData<T>(string spaceName)（与非泛型重载同名）使用 OfType<T>
    // 做运行期类型过滤；Haxe 泛型方法内无法取得 T 的类值（@:generic 下 T 也不是可用值），
    // 故按接口签名 GetModSaveDataOfType<T> 实现为「按命名空间查找 + cast」。
    public function GetModSaveDataOfType<T>(spaceName:String):Null<T> {
        return cast GetModSaveData(spaceName);
    }
    public function IsUnlocked(unlockId:NamespaceID):Bool {
        if (!NamespaceID.IsValid(unlockId))
            return false;
        var modSaveData = GetModSaveData(unlockId.SpaceName);
        if (modSaveData == null)
            return false;
        return modSaveData.IsUnlocked(unlockId.Path);
    }
    public function IsGroupUnlocked(groupID:NamespaceID):Bool {
        if (!NamespaceID.IsValid(groupID))
            return false;
        var meta = Main.ResourceManager.GetUnlockGroupMeta(groupID);
        if (meta == null || meta.Conditions == null)
            return false;
        return meta.Conditions.MeetsConditions(this);
    }
    public function GetLevelDifficultyRecords(stageID:NamespaceID):Array<NamespaceID> {
        if (stageID == null)
            return [];
        var modSaveData = GetModSaveData(stageID.SpaceName);
        if (modSaveData == null)
            return [];
        return modSaveData.GetLevelDifficultyRecords(stageID.Path);
    }
    public function GetLevelDifficulty(stageID:NamespaceID):NamespaceID {
        var records = Main.SaveManager.GetLevelDifficultyRecords(stageID);
        var best:NamespaceID = null;
        var bestValue = -2147483648;
        for (r in records) {
            var meta = Main.Game.GetDifficultyDefinition(r);
            var value = meta == null ? -2147483648 : meta.GetValue();
            if (best == null || value > bestValue) {
                best = r;
                bestValue = value;
            }
        }
        return best;
    }
    public function HasLevelDifficultyRecords(stageID:NamespaceID, difficulty:NamespaceID):Bool {
        if (stageID == null || difficulty == null)
            return false;
        var modSaveData = GetModSaveData(stageID.SpaceName);
        if (modSaveData == null)
            return false;
        return modSaveData.HasLevelDifficultyRecord(stageID.Path, difficulty);
    }
    public function IsContraptionUnlocked(contraptionID:NamespaceID):Bool {
        return unlockedContraptionsCache.contains(contraptionID);
    }
    public function IsArtifactUnlocked(artifactID:NamespaceID):Bool {
        return unlockedArtifactsCache.contains(artifactID);
    }
    public function IsEnemyUnlocked(enemyID:NamespaceID):Bool {
        return unlockedEnemiesCache.contains(enemyID);
    }
    public function GetUnlockedContraptions():Array<NamespaceID> {
        return unlockedContraptionsCache.copy();
    }
    public function GetUnlockedEnemies():Array<NamespaceID> {
        return unlockedEnemiesCache.copy();
    }
    public function GetUnlockedArtifacts():Array<NamespaceID> {
        return unlockedArtifactsCache.copy();
    }
    public function GetUnlockedProducts():Array<NamespaceID> {
        return unlockedProductsCache.copy();
    }
    public function GetAllUnlocks():Array<NamespaceID> {
        var results:Array<NamespaceID> = [];
        for (saveData in modSaveDatas) {
            for (unlock in saveData.GetUnlocks()) {
                results.push(new NamespaceID(saveData.Namespace, unlock));
            }
        }
        return results;
    }

    // #endregion

    // #region 修改
    public function Unlock(unlockId:NamespaceID):Void {
        var modSaveData = GetModSaveData(unlockId.SpaceName);
        if (modSaveData == null)
            return;
        modSaveData.Unlock(unlockId.Path);
        EvaluateUnlocks(false);
    }
    public function Relock(unlockId:NamespaceID):Void {
        if (unlockId == null)
            return;
        var modSaveData = GetModSaveData(unlockId.SpaceName);
        if (modSaveData == null)
            return;
        modSaveData.Relock(unlockId.Path);
        EvaluateUnlocks(false);
    }
    public function AddLevelDifficultyRecord(stageID:NamespaceID, difficulty:NamespaceID):Void {
        if (stageID == null || difficulty == null)
            return;
        var modSaveData = GetModSaveData(stageID.SpaceName);
        if (modSaveData == null)
            return;
        modSaveData.AddLevelDifficultyRecord(stageID.Path, difficulty);
    }
    public function RemoveLevelDifficultyRecord(stageID:NamespaceID, difficulty:NamespaceID):Bool {
        if (stageID == null || difficulty == null)
            return false;
        var modSaveData = GetModSaveData(stageID.SpaceName);
        if (modSaveData == null)
            return false;
        return modSaveData.RemoveLevelDifficultyRecord(stageID.Path, difficulty);
    }
    public function DeleteUserSaveData(index:Int):Bool {
        var path = GetUserSaveDataDirectory(index);
        if (!Directory.Exists(path))
            return false;
        Directory.Delete(path, true);
        return true;
    }
    // #endregion

    // #region 路径
    public function GetSaveDataRoot():String {
        return Path.Combine(unity.Application.persistentDataPath, "userdata");
    }
    public function GetUserSaveDataDirectory(userIndex:Int):String {
        return Path.Combine(GetSaveDataRoot(), 'user${userIndex}');
    }
    public function GetUserModSaveDataDirectory(userIndex:Int, spaceName:String):String {
        return Path.Combine(GetUserSaveDataDirectory(userIndex), spaceName);
    }
    public function GetUserModSaveDataPath(userIndex:Int, spaceName:String, backupIndex:Int = 0):String {
        var filename:String;
        if (backupIndex <= 0) {
            filename = "user.dat";
        } else {
            filename = 'user.dat.bak${backupIndex}';
        }
        return Path.Combine(GetUserModSaveDataDirectory(userIndex, spaceName), filename);
    }
    // #endregion

    // #region 游玩时长
    public function UpdatePlayTime():Void {
        var playTime = GetPlayTimeDeltaMilliseconds();
        UpdatePlayTimeDelta();
        for (mod in Main.ModManager.GetAllModInfos()) {
            UpdatePlayTimeBySpaceName(mod.Namespace, playTime);
        }
    }
    private function UpdatePlayTimeBySpaceName(spaceName:String, time:haxe.Int64):Void {
        var modSaveData = GetModSaveData(spaceName);
        UpdatePlayTimeMod(modSaveData, time);
    }
    // PORT-NOTE: C# 中 UpdatePlayTime(string, long) 与 UpdatePlayTime(ModSaveData, long) 为重载，
    // Haxe 不支持重载，故第二个重载改名 UpdatePlayTimeMod。
    private function UpdatePlayTimeMod(modSaveData:ModSaveData, time:haxe.Int64):Void {
        if (modSaveData == null)
            return;
        modSaveData.AddPlayTimeMilliseconds(time);
    }
    private function GetPlayTimeDeltaMilliseconds():haxe.Int64 {
        return haxe.Int64.fromFloat(GetPlayTimeDelta() * 1000);
    }
    private function GetPlayTimeDelta():Float {
        return Time.realtimeSinceStartup - lastPlayTime;
    }
    private function UpdatePlayTimeDelta():Void {
        lastPlayTime = Time.realtimeSinceStartup;
    }
    // #endregion

    public function GetCurrentEndlessFlag(stageID:NamespaceID):Int {
        if (!NamespaceID.IsValid(stageID))
            return 0;
        var saveData = GetModSaveData(stageID.SpaceName);
        if (saveData == null)
            return 0;
        return saveData.GetCurrentEndlessFlag(stageID.Path);
    }
    public function SetCurrentEndlessFlag(stageID:NamespaceID, value:Int):Void {
        if (!NamespaceID.IsValid(stageID))
            return;
        var saveData = GetModSaveData(stageID.SpaceName);
        if (saveData == null)
            return;
        saveData.SetCurrentEndlessFlag(stageID.Path, value);
    }

    // #region 统计
    public function GetUserStats(nsp:String):UserStats {
        var saveData = GetModSaveData(nsp);
        if (saveData == null)
            return null;
        return saveData.GetAllStats();
    }
    public function GetStat(category:NamespaceID, entry:NamespaceID):haxe.Int64 {
        var saveData = GetModSaveData(category.SpaceName);
        if (saveData == null)
            return haxe.Int64.ofInt(0);
        return saveData.GetStat(category.Path, entry);
    }
    public function SetStat(category:NamespaceID, entry:NamespaceID, value:haxe.Int64):Void {
        var saveData = GetModSaveData(category.SpaceName);
        if (saveData == null)
            return;
        saveData.SetStat(category.Path, entry, value);
    }
    // PORT-NOTE: C# IGlobalSaveData 中的默认实现 AddStat 在此展开为普通方法。
    public function AddStat(category:NamespaceID, entry:NamespaceID, value:haxe.Int64):Void {
        SetStat(category, entry, haxe.Int64.add(GetStat(category, entry), value));
    }
    public function GetDirectEntryStat(entry:NamespaceID):haxe.Int64 {
        var saveData = GetModSaveData(entry.SpaceName);
        if (saveData == null)
            return haxe.Int64.ofInt(0);
        return saveData.GetDirectEntryStat(entry.Path);
    }
    public function SetDirectEntryStat(entry:NamespaceID, value:haxe.Int64):Void {
        var saveData = GetModSaveData(entry.SpaceName);
        if (saveData == null)
            return;
        saveData.SetDirectEntryStat(entry.Path, value);
    }
    // #endregion

    // #region 成就
    public function IsAchievementEarned(achievementID:NamespaceID):Bool {
        var resourceManager = Main.ResourceManager;
        var meta = resourceManager.GetAchievementMeta(achievementID);
        if (meta == null)
            return false;
        return MVZ2SaveExt.IsNullOrMeetsConditions(meta.Unlock, this);
    }
    // #endregion

    // #region 私有方法
    private function EvaluateUnlocks(initial:Bool):Void {
        EvaluateUnlockedEntities();
        EvaluateUnlockedArtifacts();
        EvaluateUnlockedProducts();
        EvaluateUnlockedAchievements(initial);
    }
    private function EvaluateUnlockedArtifacts():Void {
        unlockedArtifactsCache = [];
        var game = Main.Game;
        var artifacts = game.GetAllArtifactDefinitions();
        for (def in artifacts) {
            var unlockConditions = def.GetUnlockConditions();
            if (unlockConditions == null)
                continue;
            if (!MVZ2SaveExt.IsNullOrMeetsConditions(unlockConditions, this))
                continue;
            unlockedArtifactsCache.push(def.GetID());
        }
    }
    private function EvaluateUnlockedProducts():Void {
        unlockedProductsCache = [];
        var resourceManager = Main.ResourceManager;
        var productsID = resourceManager.GetAllProductsID();
        for (id in productsID) {
            var meta = resourceManager.GetProductMeta(id);
            if (meta == null)
                continue;
            if (!MVZ2SaveExt.IsNullOrMeetsConditions(meta.UnlockConditions, this))
                continue;
            unlockedProductsCache.push(id);
        }
    }
    private function EvaluateUnlockedEntities():Void {
        unlockedContraptionsCache = [];
        unlockedEnemiesCache = [];
        var resourceManager = Main.ResourceManager;
        var entities = Main.Game.GetAllEntityDefinitions();
        for (def in entities) {
            if (def == null)
                continue;
            var unlockConditions = def.GetEntityUnlock();
            if (!MVZ2SaveExt.IsNullOrMeetsConditions(unlockConditions, Main.SaveManager))
                continue;
            var id = def.GetID();
            if (def.Type == EntityTypes.PLANT) {
                unlockedContraptionsCache.push(id);
            } else if (def.Type == EntityTypes.ENEMY) {
                unlockedEnemiesCache.push(id);
            }
        }
    }
    private function EvaluateUnlockedAchievements(initial:Bool):Void {
        var resourceManager = Main.ResourceManager;
        var achievementsID = resourceManager.GetAllAchievements();
        var newAchievements = achievementsID.filter(id -> IsAchievementEarned(id));
        if (!initial) {
            Main.Scene.ShowAchievementEarnTips(newAchievements.filter(id -> !unlockedAchievementsCache.contains(id)));
        }
        unlockedAchievementsCache = [];
        unlockedAchievementsCache = unlockedAchievementsCache.concat(newAchievements);
    }
    // #endregion

    public var OnUserLoad:FlxTypedSignal<Int->String->Void> = new FlxTypedSignal<Int->String->Void>();

    // ============================== SaveManager_Users.cs ==============================

    // #region 修改
    public function SetUserName(index:Int, name:String):Void {
        if (userDataList == null)
            return;
        var meta = userDataList.Get(index);
        if (meta == null) {
            meta = userDataList.Create(index);
        }
        if (meta == null)
            return;
        meta.Username = name;
        OnUserNameChanged.dispatch(index, name);
    }
    public function SetCurrentUserIndex(index:Int):Void {
        if (userDataList == null)
            return;
        LoadUserData(index);
        userDataList.CurrentUserIndex = index;
    }
    public function CreateNewUser(name:String):Int {
        var index = FindFreeUserIndex();
        CreateNewUserAt(name, index);
        return index;
    }
    // PORT-NOTE: C# 中 CreateNewUser(string) 与 CreateNewUser(string, int) 为重载，
    // Haxe 不支持重载，带索引的版本改名 CreateNewUserAt。
    public function CreateNewUserAt(name:String, index:Int):Void {
        SetUserName(index, name);
        var directory = GetUserSaveDataDirectory(index);
        if (Directory.Exists(directory)) {
            Directory.Delete(directory, true);
        }
    }
    public function DeleteUser(index:Int):Void {
        if (userDataList == null)
            return;
        userDataList.Delete(index);
        DeleteUserSaveData(index);
    }
    // #endregion

    // #region 获取
    public function GetAllUsers():Array<UserDataItem> {
        if (userDataList == null)
            return [];
        return userDataList.GetAllUsers();
    }
    public function GetCurrentUserIndex():Int {
        if (userDataList == null)
            return -1;
        return userDataList.CurrentUserIndex;
    }
    public function GetCurrentUserName():String {
        if (userDataList == null)
            return null;
        var index = userDataList.CurrentUserIndex;
        return GetUserName(index);
    }
    public function GetUserName(index:Int):String {
        if (userDataList == null)
            return null;
        var meta = userDataList.Get(index);
        if (meta == null)
            return null;
        return meta.Username;
    }
    public function HasDuplicateUserName(name:String, indexToExcept:Int):Bool {
        if (userDataList == null)
            return false;
        for (i in 0...userDataList.GetMaxUserCount()) {
            if (i == indexToExcept)
                continue;
            var meta = userDataList.Get(i);
            if (meta == null)
                continue;
            if (meta.Username == name)
                return true;
        }
        return false;
    }
    public function UserExists(i:Int):Bool {
        if (userDataList == null)
            return false;
        return userDataList.Get(i) != null;
    }
    public function FindFreeUserIndex():Int {
        for (i in 0...MAX_USER_COUNT) {
            if (!UserExists(i))
                return i;
        }
        return -1;
    }
    public function CanRenameUser(userName:String):Bool {
        return userName != null && userName.length > 0 && !Main.Game.IsSpecialUserName(userName);
    }
    public function CanRenameUserTo(userName:String):Bool {
        return !Main.Game.IsSpecialUserName(userName);
    }
    // #endregion

    // #region 保存
    public function SaveUserList():Void {
        if (userDataList == null)
            return;
        var saveDataMetaPath = GetUserListPath();
        FileHelper.ValidateDirectory(saveDataMetaPath);
        var serializable = userDataList.ToSerializable();
        var metaJson = SerializeHelper.ToBson(serializable);
        // 用户列表只保存元数据。使用明文 JSON，避免 hxcpp 启动阶段的 gzip 解压原生崩溃。
        SerializeHelper.Write(saveDataMetaPath, metaJson);
    }
    // #endregion

    // #region 读取
    private function LoadUserList():UserDataList {
        var result:UserDataList;
        var saveDataMetaPath = GetUserListPath();
        if (!File.Exists(saveDataMetaPath)) {
            result = new UserDataList(MAX_USER_COUNT);
        } else {
            try {
                // 旧版列表可能是 gzip，hxcpp 在读取它时会在 Haxe catch 之前触发访问违例。
                // 启动期不读取现有 users.dat：先保留为备份，再创建新的明文列表；用户个人
                // 存档目录完全保留，避免旧列表格式阻断游戏启动。
                var legacyPath = saveDataMetaPath + '.legacy';
                try {
                    if (File.Exists(legacyPath))
                        File.Delete(legacyPath);
                    sys.FileSystem.rename(saveDataMetaPath, legacyPath);
                    Debug.LogWarning('已将旧版用户列表备份为 .legacy，跳过危险格式解析');
                } catch (moveError:Dynamic) {
                    Debug.LogWarning('无法备份旧用户列表，使用空用户列表继续启动');
                }
                result = new UserDataList(MAX_USER_COUNT);
            } catch (e:Dynamic) {
                Debug.LogError('Error loading user list: ${e}');
                // 保留旧文件作为备份并移出启动读取路径，避免每次启动重复触发旧格式解析。
                var legacyPath = saveDataMetaPath + '.legacy';
                try {
                    if (File.Exists(legacyPath))
                        File.Delete(legacyPath);
                    sys.FileSystem.rename(saveDataMetaPath, legacyPath);
                } catch (moveError:Dynamic) {}
                result = new UserDataList(MAX_USER_COUNT);
            }
        }
        return result;
    }
    // #endregion

    // #region 路径
    public function GetUserListPath():String {
        return Path.Combine(GetSaveDataRoot(), "users.dat");
    }
    // #endregion

    // #region 导出
    public function ExportUserDataPack(userIndex:Int, destPath:String):Bool {
        var userDir = GetUserSaveDataDirectory(userIndex);
        if (!Directory.Exists(userDir))
            return false;

        FileHelper.ValidateDirectory(destPath);
        var files = Directory.GetFiles(userDir, "*", SearchOption.AllDirectories);
        var stream = File.Open(destPath, FileMode.Create);
        var archive = new ZipArchive(stream, ZipArchiveMode.Create);

        for (filePath in files) {
            var entryName = Path.Combine("userdata", Path.GetRelativePath(userDir, filePath));
            entryName = entryName.split("\\").join("/");
            ZipFileExtensions.CreateEntryFromFile(archive, filePath, entryName);
        }
        var userName = GetUserName(userIndex);
        if (userName == null) userName = 'user${userIndex}';
        var metadata = new UserDataPackMetadata(userName);
        var seri = metadata.ToSerializable();
        var json = SerializeHelper.ToBson(seri);

        var metadataEntry = archive.CreateEntry(USER_DATA_PACK_METADATA_ENTRY_NAME);
        ZipArchiveHelper.WriteString(metadataEntry, json, Encoding.UTF8);
        archive.Dispose();
        stream.Dispose();
        return true;
    }
    // #endregion

    // #region 导入
    public function ImportUserDataPack(userName:String, userIndex:Int, sourcePath:String):Void {
        if (!File.Exists(sourcePath))
            return;
        if (userIndex < 0)
            return;
        var userDir = GetUserSaveDataDirectory(userIndex);
        if (Directory.Exists(userDir)) {
            Directory.Delete(userDir, true);
        }

        var stream = File.Open(sourcePath, FileMode.Open);
        var archive = new ZipArchive(stream);

        var entries = archive.Entries.copy();
        for (entry in entries) {
            if (entry.Name == null || entry.Name.length == 0)
                continue;

            if (Path.GetExtension(entry.FullName) == null || Path.GetExtension(entry.FullName).length == 0)
                continue;

            var fullPath = entry.FullName.split("\\").join("/");
            var splitedPaths = fullPath.split(Path.DirectorySeparatorChar).join("|").split(Path.AltDirectorySeparatorChar).join("|").split("|");
            if (splitedPaths.length > 1 && splitedPaths[0] == "userdata") {
                var relativePath = Path.Combine(splitedPaths[1], splitedPaths.length > 2 ? splitedPaths.slice(2).join("|").split("|").join(Path.DirectorySeparatorChar) : "");
                var destPath = Path.Combine(userDir, relativePath);
                FileHelper.ValidateDirectory(destPath);

                var bytes = ZipArchiveHelper.ReadBytes(entry);
                var entryStream = File.Open(destPath, FileMode.CreateNew);
                entryStream.Write(bytes, 0, bytes.length);
                entryStream.Dispose();
            }
        }
        archive.Dispose();
        stream.Dispose();
        SetUserName(userIndex, userName);
        SaveUserList();
        userDataList = LoadUserList();
    }
    public function ImportUserDataPackMetadata(sourcePath:String):UserDataPackMetadata {
        if (!File.Exists(sourcePath))
            return null;
        var stream = File.Open(sourcePath, FileMode.Open);
        var archive = new ZipArchive(stream);

        var entry = archive.GetEntry(USER_DATA_PACK_METADATA_ENTRY_NAME);
        if (entry == null)
            return null;
        var json = ZipArchiveHelper.ReadString(entry, Encoding.UTF8);
        var seri = mvz2logic.serialization.SerializeMacro.FromBson(json);
        var result = UserDataPackMetadata.FromSerializable(seri);
        archive.Dispose();
        stream.Dispose();
        return result;
    }
    // #endregion

    // #region 导入旧存档
    private function ImportOldSaveData(saveData:OldGlobalSave):Void {
        if (saveData == null)
            return;

        // 用户列表
        var newUserDataList = ImportOldUserList(saveData.userList);
        if (newUserDataList == null)
            return;

        var saveDataMetaPath = GetUserListPath();
        FileHelper.ValidateDirectory(saveDataMetaPath);
        var seriUserList = newUserDataList.ToSerializable();
        var userListJson = SerializeHelper.ToBson(seriUserList);
        Main.FileManager.WriteStringFile(saveDataMetaPath, userListJson);

        // 存档。
        var saveDatas = ImportOldUserData(newUserDataList, saveData.saveDatas);
        if (saveDatas == null)
            return;

        var spaceName = Main.BuiltinNamespace;
        for (i in 0...saveDatas.length) {
            var modSaveData = saveDatas[i];
            if (modSaveData == null)
                continue;
            WriteSaveData(i, spaceName, modSaveData);
        }
    }
    private function ImportOldUserList(userList:OldUserList):UserDataList {
        if (userList == null || userList.usernames == null)
            return null;

        // 用户列表
        var newUserDataList = new UserDataList(MAX_USER_COUNT);
        newUserDataList.CurrentUserIndex = -1;
        for (i in 0...userList.usernames.length) {
            var name = userList.usernames[i];
            if (name == null || name.length == 0)
                continue;
            var userItem = newUserDataList.Create(i);
            if (userItem != null) {
                userItem.Username = name;
                if (newUserDataList.CurrentUserIndex < 0) {
                    newUserDataList.CurrentUserIndex = i;
                }
            }
        }
        if (newUserDataList.CurrentUserIndex < 0) {
            newUserDataList.CurrentUserIndex = 0;
        }
        return newUserDataList;
    }
    private function ImportOldUserData(userList:UserDataList, userDatas:Array<OldSaveData>):Array<LogicSaveData> {
        if (userDatas == null)
            return null;

        var vanillaMod:ModInfo = null;
        for (mod in Main.ModManager.GetAllModInfos()) {
            if (mod == null || mod.Logic == null)
                continue;
            if (mod.Namespace != Main.BuiltinNamespace)
                continue;
            vanillaMod = mod;
            break;
        }
        if (vanillaMod == null)
            return null;

        var allUsers = userList.GetAllUsers();
        var results = new Array<LogicSaveData>();
        results.resize(allUsers.length);
        for (i in 0...allUsers.length) {
            var user = allUsers[i];
            if (user == null)
                continue;
            var oldData = userDatas[i];
            if (oldData == null)
                continue;
            var data = vanillaMod.Logic != null ? vanillaMod.Logic.CreateSaveData() : null;
            if (!Std.isOfType(data, LogicSaveData))
                continue;
            var vanilla:LogicSaveData = cast data;
            OldSaveDataConvertor.ImportUserDataFromOld(vanilla, oldData);
            results[i] = vanilla;
        }
        return results;
    }
    // #endregion

    public var OnUserNameChanged:FlxTypedSignal<Int->String->Void> = new FlxTypedSignal<Int->String->Void>();

    // #region 属性字段
    public static inline var USER_DATA_PACK_METADATA_ENTRY_NAME:String = "metadata.json";
    public static inline var MAX_USER_COUNT:Int = 8;
    public var Main(get, never):MainManager;
    function get_Main():MainManager return MainManager.Instance;
    public var backupCount:Int = 8;
    private var status:SaveDataStatus = new SaveDataStatus();
    private var modSaveDatas:Array<ModSaveData> = [];
    private var unlockedContraptionsCache:Array<NamespaceID> = [];
    private var unlockedEnemiesCache:Array<NamespaceID> = [];
    private var unlockedArtifactsCache:Array<NamespaceID> = [];
    private var unlockedProductsCache:Array<NamespaceID> = [];
    private var unlockedAchievementsCache:Array<NamespaceID> = [];
    private var lastPlayTime:Float = 0;
    private var _saveLock:Dynamic = {};
    // #endregion
    private var userDataList:UserDataList;
}

class SaveDataStatus {
    public var State:SaveDataState = SaveDataState.Success;
    public function new() {}
    public function AddCorruptedUserIndex(index:Int):Void {
        corruptedIndexes.push(index);
    }
    public function GetCorruptedUserIndexes():Array<Int> {
        return corruptedIndexes.copy();
    }
    private var corruptedIndexes:Array<Int> = [];
}

enum abstract SaveDataState(Int) from Int to Int {
    var Success = 0;
    var SomeCorrupted = 1;
    var AllCorrupted = 2;
    var FullCorrupted = 3;
}

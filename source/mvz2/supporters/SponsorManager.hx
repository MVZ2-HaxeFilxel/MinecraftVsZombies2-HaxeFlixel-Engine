package mvz2.supporters;

import haxe.Int64;
import mvz2.io.FileHelper;
import mvz2.managers.MainManager;
import mvz2.supporters.SponsorQueryResults;
import system.io.File;
import system.io.Path;
import system.text.Encoding;
import unity.Application;
import unity.Debug;
import unity.JsonUtility;
import unity.MonoBehaviour;
import unity.Task;
import unity.TaskCompletionSource;
import unity.networking.UnityWebRequest;
import unity.networking.WWWForm;
import mvz2.io.FileManager;
import Main;
import mvz2.managers.MainManager.TaskProgress;
import mvz2.supporters.SponsorQueryResults.GenericResp;
import mvz2.supporters.SponsorQueryResults.ItemList;
import mvz2.supporters.SponsorQueryResults.SponsorItem;
import unity.networking.UnityWebRequest.Result;

// Ported from: Assets/Scripts/MVZ2/Sponsors/SponsorManager.cs
class SponsorManager extends MonoBehaviour {
    // PORT-NOTE: `async Task PullSponsors` → Task; `await` is translated to `.awaitResult()`.
    public function PullSponsors(progress:TaskProgress):Task {
        var sponserCache:SponsorInfos = null;
        try {
            sponserCache = LoadSponsorsCache();
        } catch (e:Dynamic) {
            Debug.LogError('加载赞助者名单缓存时出现错误：${e}');
        }
        try {
            if (!ShouldRepull(sponserCache)) {
                SetCurrentSponsorInfos(sponserCache);
                progress.SetProgress(1, "No need to pull");
                return Task.completedTask();
            }
            var items:Array<SponsorItem> = GetAllSponsors(progress).awaitResult();
            // PORT-NOTE: C# 在 `RequestSponsors` 返回 null 时由下一行的 `resp.Result` 抛
            // NullReferenceException，被上面的 catch 记成 error 日志。移植层把「本次没拿到
            // 可用响应」（网络失败 / 响应为空 / 反序列化拿不到对象，见 GetAllSponsors 的
            // TODO-PORT）视为**非致命**情形：只记一条 warning 并跳过本次更新——不写缓存、
            // 不更新 currentSponsors，与 C# 的「本次不更新」语义一致，但不再往启动日志里塞
            // error 级噪声（该分支在无网络启动时每次都会命中）。
            if (items == null) {
                Debug.LogWarning("未获取到赞助者名单，本次跳过更新。");
                return Task.completedTask();
            }
            sponserCache = new SponsorInfos(items);
            sponserCache.lastUpdateTime = Std.int(getUnixTimeSeconds());
            SetCurrentSponsorInfos(sponserCache);
            SaveSponsorsCache(sponserCache);
        } catch (e:Dynamic) {
            Debug.LogError('更新赞助者名单时出现错误：${e}');
        }
        return Task.completedTask();
    }
    public function GetSponsorPlanNames(rankType:Int, rank:Int):Array<String> {
        if (currentSponsors == null)
            return [];
        return Lambda.array(Lambda.map(Lambda.filter(currentSponsors.sponsors, s -> Lambda.exists(s.plans, p -> p.rankType == rankType && p.rank >= rank)), s -> s.name));
    }
    public function HasSponsorPlan(name:String, rankType:Int, rank:Int):Bool {
        if (currentSponsors == null)
            return false;
        return Lambda.exists(currentSponsors.sponsors, s -> s.name == name && Lambda.exists(s.plans, p -> p.rankType == rankType && p.rank >= rank));
    }
    private function GetAllSponsors(progress:TaskProgress):Task {
        var sponsorList:Array<SponsorItem> = [];
        var numPerPage = 100;
        progress.SetProgress(0, "Page 1");
        var resp:GenericResp<ItemList<SponsorItem>> = RequestSponsors(1, numPerPage, null).awaitResult();
        // PORT-NOTE: C# 里 `resp` 为 null 时下一行的 `resp.Result` 抛 NullReferenceException，
        // 由 `PullSponsors` 的 `try { … } catch (e) { Debug.LogError(…); }` 捕获后继续启动。
        // hxcpp release 没有空指针检查，直接解引用是访问违例（exit 139）→ 整个进程死，
        // 因此不能照搬 C# 的「让它抛」。这里改为返回 null，把「本次没拿到名单」作为**非致命**
        // 结果交回 `PullSponsors` 处理（记一条 warning 后跳过更新），既保住进程也保住语义。
        // TODO-PORT: `resp` 为 null 的根因已定位——`RequestSponsors` 里
        // `cast haxe.Json.parse(json)` 把 JSON 解析出的匿名对象（hx::Anon）直接 cast 成
        // `GenericResp<ItemList<SponsorItem>>`，hxcpp 上该 cast 必然失败并返回 null
        // （实测：无论响应是否成功，`resp` 恒为 null，见 tools_build 记录），
        // 即赞助者名单在 cpp 上从来没真正加载过。修法是在 `RequestSponsors` 里按字段
        // 手工构造 `GenericResp`/`ItemList`/`SponsorItem`（JSON 解析产物不能直接当类实例用），
        // 属独立工作包，不在本次「消除日志噪声」的范围内。
        if (resp == null)
            return Task.fromResult(null);
        if (resp.Result == null) {
            return Task.fromResult([]);
        }
        if (resp.Result.List != null) {
            for (item in resp.Result.List) sponsorList.push(item);
        }
        var totalPage = resp.Result.TotalPage;

        for (i in 2...(totalPage + 1)) {
            progress.SetProgress((i - 1) / totalPage, 'Page $i');
            var obj:GenericResp<ItemList<SponsorItem>> = RequestSponsors(i, numPerPage, null).awaitResult();
            if (obj == null)
                continue;
            if (obj.Result != null && obj.Result.List != null) {
                for (item in obj.Result.List) sponsorList.push(item);
            }
        }
        progress.SetProgress(1, "Finished");

        return Task.fromResult(Lambda.array(sponsorList));
    }
    private function RequestSponsors(page:Int = 0, numPerPage:Int = 100, targetUserID:Array<Int> = null):Task {
        var sponsorParams = new SponsorQueryParams(page, numPerPage, targetUserID);
        var param = JsonUtility.ToJson(sponsorParams);
        var url = baseUrl + sponsorQueryPath;
        var json:String = RequestText(url, param).awaitResult();

        // PORT-NOTE: MongoDB.Bson deserialization is replaced by json2object/Dynamic parsing.
        var parsed:GenericResp<ItemList<SponsorItem>> = cast haxe.Json.parse(json);
        return Task.fromResult(parsed);
    }
    private function ErrorHandler(request:UnityWebRequest):Void {
        if (request.result == Result.ConnectionError) {
            throw new SponsorNetworkException("无法连接至赞助者服务器。");
        }
        if (request.result == Result.ProtocolError) {
            throw new SponsorNetworkException("赞助者服务器发送了一个错误响应。");
        }
        if (request.result == Result.DataProcessingError) {
            throw new SponsorNetworkException("处理赞助者服务器发送的数据时发生错误。");
        }
        if (request.result != Result.Success) {
            throw new SponsorNetworkException("发生未知错误。");
        }
    }
    private function RequestText(url:String, param:String):Task {
        var request:UnityWebRequest = Request(url, param).awaitResult();
        var result = request.downloadHandler.text;
        request.Dispose();
        return Task.fromResult(result);
    }
    private function Request(url:String, param:String):Task {
        var timestamp = Std.string(Std.int(getUnixTimeSeconds()));

        var token = DecryptToken();
        var strToCalc = token + "params" + param + "ts" + timestamp + "user_id" + userID;
        var hash = haxe.crypto.Md5.encode(strToCalc);
        var hashStr = hash;

        var wwwForm = new WWWForm();
        wwwForm.AddField("user_id", userID);
        wwwForm.AddField("params", param);
        wwwForm.AddField("ts", timestamp);
        wwwForm.AddField("sign", hashStr);
        var request = UnityWebRequest.Post(url, wwwForm);

        request.timeout = responseTimeout;

        var tcs = new TaskCompletionSource();

        var requestOp = request.SendWebRequest();
        requestOp.completed.add(function(op) {
            tcs.SetResult(op);
        });

        tcs.task.awaitResult();

        ErrorHandler(request);

        return Task.fromResult(request);
    }

    private function LoadSponsorsCache():SponsorInfos {
        var path = GetSponsorCacheFilePath();
        if (!File.Exists(path)) {
            return null;
        }
        var json = Main.FileManager.ReadStringFile(path);
        // PORT-NOTE: Bson deserialization replaced with JSON parsing.
        // haxe.Json.parse 的匿名产物（hx::Anon）不能 cast 成真实类（内存布局不同会段错误），
        // 且 SponsorInfos.lastUpdateTime 是 Int64——用 RTTI hydration 重建真实实例。
        // 写入端是 haxe.Json.stringify 真实实例（键名与字段名一致），hydration 兼容。
        return cast mvz2logic.serialization.TypedJson.hydrate(haxe.Json.parse(json), "mvz2.supporters.SponsorInfos");
    }
    private function SaveSponsorsCache(saveInfo:SponsorInfos):Void {
        var path = GetSponsorCacheFilePath();
        FileHelper.ValidateDirectory(path);
        // PORT-NOTE: SponsorInfos.ToJson() (Bson) → JSON serialization.
        var json = haxe.Json.stringify(saveInfo);
        Main.FileManager.WriteStringFile(path, json);
    }
    private function ShouldRepull(infos:SponsorInfos):Bool {
        if (infos == null)
            return true;
        var lastTime = Date.fromTime(Int64.toInt(infos.lastUpdateTime) * 1000);
        var nowTime = Date.now();
        // PORT-NOTE: C# `nowTime.Date != lastTime.Date` → same-day comparison.
        if (nowTime.getFullYear() != lastTime.getFullYear()
            || nowTime.getMonth() != lastTime.getMonth()
            || nowTime.getDate() != lastTime.getDate()) {
            return true;
        }
        return false;
    }
    private function GetSponsorCacheFilePath():String {
        return Path.Combine(Application.persistentDataPath, "sponsors.dat");
    }
    private function SetCurrentSponsorInfos(infos:SponsorInfos):Void {
        currentSponsors = infos;
    }
    // #region 解密
    private function DecryptToken():String {
        try {
            return Decrypt(apiToken, key, iv);
        } catch (ex:Dynamic) {
            Sys.println("解密失败: " + ex);
            return "";
        }
    }
    private static function Decrypt(encryptedText:String, aesKey:haxe.io.Bytes, aesIV:haxe.io.Bytes):String {
        var aesEncryptedData = haxe.crypto.Base64.decode(encryptedText);
        return AesDecrypt(aesEncryptedData, aesKey, aesIV);
    }
    private static function AesDecrypt(encryptedData:haxe.io.Bytes, key:haxe.io.Bytes, iv:haxe.io.Bytes):String {
        // TODO-PORT: AES-CBC/PKCS7 decryption (System.Security.Cryptography.Aes) has no Haxe std
        // equivalent; a crypt library must be wired in during the integration phase.
        throw 'AES decryption is not implemented in the Haxe port.';
    }
    // #endregion

    public var Main(get, never):MainManager;
    inline function get_Main():MainManager return MainManager.Instance;

    // PORT-NOTE: DateTimeOffset.UtcNow.ToUnixTimeSeconds() helper.
    private static function getUnixTimeSeconds():Float {
        return Date.now().getTime() / 1000;
    }

    private var currentSponsors:SponsorInfos;
    @:serializeField
    private var userID:String = "";
    @:serializeField
    private var apiToken:String = "";
    @:serializeField
    private var baseUrl:String = "https://afdian.com/api";
    @:serializeField
    private var sponsorQueryPath:String = "/open/query-sponsor";
    @:serializeField
    private var responseTimeout:Int = 10;
    private var key:haxe.io.Bytes = haxe.io.Bytes.ofHex("58115811531053105811581153105310");
    private var iv:haxe.io.Bytes = haxe.io.Bytes.ofHex("11451419198108101145141919810810");
}

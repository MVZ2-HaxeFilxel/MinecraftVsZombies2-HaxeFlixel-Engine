// PORT-NOTE: 验证用（不参与游戏构建）。内置语言包 .mo 二进制解析的运行时冒烟测试：
// 用与 ZipArchiveHelper.ReadCatalog 完全相同的构造路径（MemoryStream -> new Catalog），
// 真实读取 assets/Localization/pack/assets/mvz2/en-US/{general,almanac,talk}.mo，
// 逐项核对 ngettext.Catalog 的查表行为（单数 / 上下文 / 复数三条路径 + .po 文本回退）。
//
// 背景：Catalog.hx 原来只解析 .po 文本，对二进制 .mo 解析出 0 条翻译，全游戏本地化
// 查表失败（语言名下拉显示 zh-Hans(zh-hans)、切语言无效）。
//
// 运行（纯解释执行，不产出任何构建文件、不碰 obj 目录）：
//   cd HaxePort && haxe -cp source -cp verify --interp -main mocatalog.MoCatalogSmokeTest
// 或：bash HaxePort/tools_build/check_mo_catalog.sh
package mocatalog;

import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import mvz2.io.ZipArchiveHelper;
import ngettext.Catalog;
import system.io.MemoryStream;
import system.io.compression.ZipArchive;

class MoCatalogSmokeTest {
    private static var checks:Int = 0;
    private static var notes:Int = 0;
    private static var failures:Array<String> = [];

    // 与 LanguageManager.GetLanguageName 的查表路径一致（CURRENT_LANGUAGE_NAME "中文"）。
    private static inline var CONTEXT_LANGUAGE_NAME:String = "language_name";
    private static inline var MSGID_LANGUAGE_NAME:String = "中文";
    private static inline var EXPECTED_LANGUAGE_NAME:String = "English (United States)";

    // general.mo 里的普通单数条目（无上下文）。
    private static inline var MSGID_PLAIN:String = "10 槽";
    private static inline var EXPECTED_PLAIN:String = "10 Slots";

    // general.mo 里的上下文复数条目（msgctxt=advice）。
    private static inline var CTX_ADVICE:String = "advice";
    private static inline var MSGID_PLURAL:String = "干得好！还剩{0}轮！";

    public static function main():Void {
        var packDir = findPackDir();
        if (packDir == null) {
            info('找不到内置语言包目录（试过 assets/Localization/pack/assets/mvz2/en-US 与 assets/Localization/source/en-US）');
            Sys.exit(2);
        }
        info('语言包目录: $packDir');

        // ---------------- 二进制 .mo ----------------
        var general = loadCatalog(packDir, "general.mo");
        check(general != null, 'general.mo 已构造 Catalog（二进制 .mo 解析路径）');
        if (general != null) {
            checkGeneral(general);
        }

        var almanac = loadCatalog(packDir, "almanac.mo");
        check(almanac != null, 'almanac.mo 已构造 Catalog');
        if (almanac != null) {
            check(almanac.TranslationCount > 0, 'almanac.mo 条目数 ${almanac.TranslationCount} > 0');
        }

        var talk = loadCatalog(packDir, "talk.mo");
        check(talk != null, 'talk.mo 已构造 Catalog');
        if (talk != null) {
            check(talk.TranslationCount > 0, 'talk.mo 条目数 ${talk.TranslationCount} > 0');
        }

        info('条目数: general=${general != null ? general.TranslationCount : -1}'
            + ' almanac=${almanac != null ? almanac.TranslationCount : -1}'
            + ' talk=${talk != null ? talk.TranslationCount : -1}');

        // ---------------- 文本 .po 回退 ----------------
        checkPoFallback();

        // ---------------- 内置语言包的真实路径（zip 条目 -> ReadCatalog）----------------
        // BuiltinLanguagePackReference -> ReadLanguagePackZip -> ReadLanguagePackZipStream
        // -> ZipArchiveHelper.ReadCatalog，与 LanguageManager.LoadLanguagePacks 同一链路。
        checkZipPackPath(packDir);

        info('检查项 $checks，失败 ${failures.length}，说明 $notes');
        Sys.exit(failures.length == 0 ? 0 : 1);
    }

    private static function checkGeneral(catalog:Catalog):Void {
        // 条目数：修复前的症状就是 0 条；general.mo 现有 1024 条（断言留余量，换包不脆断）。
        check(catalog.TranslationCount > 0, 'general.mo 条目数 ${catalog.TranslationCount} > 0（修复前为 0）');
        check(catalog.TranslationCount >= 1000, 'general.mo 条目数 ${catalog.TranslationCount} >= 1000');
        info('general.mo 总条目数: ${catalog.TranslationCount}');

        // ---- 语言名（msgctxt="language_name"，GetLanguageName 的查表路径）----
        check(catalog.IsTranslationExist(CONTEXT_LANGUAGE_NAME + "\u0004" + MSGID_LANGUAGE_NAME),
            'IsTranslationExist("language_name\\u0004中文") 为真');
        check(!catalog.IsTranslationExist(CONTEXT_LANGUAGE_NAME), 'IsTranslationExist("language_name") 为假（上下文本身不是键）');
        check(!catalog.IsTranslationExist(MSGID_LANGUAGE_NAME), 'IsTranslationExist("中文") 为假（带上下文的条目不能用无上下文键查到）');
        var languageName = catalog.GetParticularString(CONTEXT_LANGUAGE_NAME, MSGID_LANGUAGE_NAME);
        check(languageName == EXPECTED_LANGUAGE_NAME,
            'GetParticularString("language_name", "中文") == "$EXPECTED_LANGUAGE_NAME"（实际 "$languageName"）');

        // ---- 普通单数条目 ----
        check(catalog.IsTranslationExist(MSGID_PLAIN), 'IsTranslationExist("$MSGID_PLAIN") 为真');
        var plain = catalog.GetString(MSGID_PLAIN);
        check(plain == EXPECTED_PLAIN, 'GetString("$MSGID_PLAIN") == "$EXPECTED_PLAIN"（实际 "$plain"）');

        // ---- 上下文复数条目（LanguagePack.TryGetStringParticularPlural 的门槛 + 形式选择）----
        // .mo 里 msgid = "advice\u0004干得好！还剩{0}轮！\u0000干得好！还剩{0}轮！"，
        // msgstr = "Good job! {0} round left!\u0000Good job! {0} rounds left!"。
        check(catalog.IsTranslationExist(CTX_ADVICE + "\u0004" + MSGID_PLURAL),
            'IsTranslationExist("advice\\u0004$MSGID_PLURAL") 为真（复数条目的单数键门槛）');
        var plural1 = catalog.GetParticularPluralString(CTX_ADVICE, MSGID_PLURAL, MSGID_PLURAL, haxe.Int64.ofInt(1), [1]);
        check(plural1 == "Good job! 1 round left!", 'n=1 取第 0 种形式并格式化（实际 "$plural1"）');
        var plural5 = catalog.GetParticularPluralString(CTX_ADVICE, MSGID_PLURAL, MSGID_PLURAL, haxe.Int64.ofInt(5), [5]);
        check(plural5 == "Good job! 5 rounds left!", 'n=5 取第 1 种形式并格式化（实际 "$plural5"）');

        // ---- 查不到时原样返回（与 NGettext/调用方约定一致）----
        check(!catalog.IsTranslationExist("绝对不存在的键_zzz"), 'IsTranslationExist(不存在键) 为假');
        check(catalog.GetString("绝对不存在的键_zzz") == "绝对不存在的键_zzz", 'GetString(不存在键) 原样返回');
    }

    private static function checkZipPackPath(packDir:String):Void {
        // 用真实 general.mo 字节在内存里按内置语言包的目录布局打一个 zip
        // （assets/mvz2/en-US/general.mo），再走 LanguageManager 的同一条读取链路。
        var moPath = packDir + "/general.mo";
        if (!sys.FileSystem.exists(moPath)) {
            info('跳过 zip 路径检查（不存在）: $moPath');
            return;
        }
        var moBytes = sys.io.File.getBytes(moPath);

        var out = new BytesOutput();
        var entries = new haxe.ds.List<haxe.zip.Entry>();
        entries.add({
            fileName: "assets/mvz2/en-US/general.mo",
            fileSize: moBytes.length,
            fileTime: Date.now(),
            compressed: false,
            dataSize: moBytes.length,
            data: moBytes,
            crc32: haxe.crypto.Crc32.make(moBytes)
        });
        new haxe.zip.Writer(out).write(entries);
        var zipBytes = out.getBytes();

        // ReadLanguagePackZipStream 的入口：new ZipArchive(stream)。
        var archive = new ZipArchive(new MemoryStream(zipBytes));
        check(archive.Entries.length > 0, 'new ZipArchive(stream) 读出了 ${archive.Entries.length} 个条目（构造即 load）');
        var moCount = 0;
        for (entry in archive.Entries) {
            if (Path_getExtension(entry.FullName) == ".mo")
                moCount++;
        }
        check(moCount > 0, 'zip 内找到 .mo 条目 ${moCount} 个');

        // 复刻 ReadLanguagePackZipStream 的路径约定与 ReadCatalog 调用。
        for (entry in archive.Entries) {
            var fullPath = entry.FullName.split("\\").join("/");
            var splitedPaths = fullPath.split("/");
            if (splitedPaths.length < 3 || splitedPaths[0] != "assets")
                continue;
            var lang = splitedPaths[2].split("_").join("-");
            if (splitedPaths.length == 4 && Path_getExtension(splitedPaths[3]) == ".mo") {
                var catalog = ZipArchiveHelper.ReadCatalog(entry, lang);
                check(catalog != null, 'ZipArchiveHelper.ReadCatalog 返回 Catalog（lang=$lang）');
                if (catalog != null) {
                    check(catalog.TranslationCount >= 1000, 'zip 路径条目数 ${catalog.TranslationCount} >= 1000');
                    check(catalog.GetParticularString(CONTEXT_LANGUAGE_NAME, MSGID_LANGUAGE_NAME) == EXPECTED_LANGUAGE_NAME,
                        'zip 路径 GetParticularString("language_name", "中文") == "$EXPECTED_LANGUAGE_NAME"');
                }
            }
        }
    }

    // 避免为一条路径判断引入 system.io.Path 的依赖（其闭包在本测试里用不到）。
    private static function Path_getExtension(path:String):String {
        var slashA = path.lastIndexOf("/");
        var slashB = path.lastIndexOf("\\");
        var slash = slashA > slashB ? slashA : slashB;
        var fileName = slash >= 0 ? path.substr(slash + 1) : path;
        var dot = fileName.lastIndexOf(".");
        return dot >= 0 ? fileName.substr(dot) : "";
    }

    private static function checkPoFallback():Void {
        // .po 文本路径仍可用（非 .mo magic 走 load(content)），且上下文键编码与 .mo 一致。
        var po = "msgctxt \"ui\"\n"
            + "msgid \"hello\"\n"
            + "msgstr \"你好\"\n"
            + "\n"
            + "msgid \"plain\"\n"
            + "msgstr \"普通\"\n";
        var catalog = new Catalog(new MemoryStream(Bytes.ofString(po)), "zh-Hans");
        check(catalog.TranslationCount == 2, '.po 文本解析出 ${catalog.TranslationCount} 条（期望 2）');
        check(catalog.GetParticularString("ui", "hello") == "你好", '.po: GetParticularString("ui", "hello") == "你好"');
        check(catalog.GetString("plain") == "普通", '.po: GetString("plain") == "普通"');
        check(!catalog.IsTranslationExist("hello"), '.po: 无上下文键 "hello" 不为真（msgctxt 前缀已生效）');
    }

    // 与 ZipArchiveHelper.ReadCatalog / LanguageManager.LoadPackLanguageDirectroy 同一构造路径。
    private static function loadCatalog(dir:String, fileName:String):Catalog {
        var path = dir + "/" + fileName;
        if (!sys.FileSystem.exists(path)) {
            info('跳过（不存在）: $path');
            return null;
        }
        return new Catalog(new MemoryStream(sys.io.File.getBytes(path)), "en-US");
    }

    private static function findPackDir():String {
        for (candidate in [
            "assets/Localization/pack/assets/mvz2/en-US",
            "assets/Localization/source/en-US"
        ]) {
            if (sys.FileSystem.exists(candidate + "/general.mo"))
                return candidate;
        }
        return null;
    }

    private static function check(condition:Bool, message:String):Void {
        checks++;
        if (condition) {
            Sys.println('[ ok ] ' + message);
        } else {
            Sys.println('[FAIL] ' + message);
            failures.push(message);
        }
    }

    private static function info(message:String):Void {
        Sys.println('[info] ' + message);
    }

    private static function note(message:String):Void {
        notes++;
        Sys.println('[note] ' + message);
    }
}

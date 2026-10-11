package ngettext;

import haxe.Int64;
import haxe.io.Bytes;
import system.io.Stream;

// Ported shim of NGettext.Catalog (external library, not present in the repository).
// PORT-NOTE: only the members used by this project are implemented; translations are loaded
// from the PO/MO content stored in the archive entry.
// PORT-NOTE: 游戏内置语言包（assets/Localization/pack/**/**.mo 及其 zip）是 GNU gettext 的
//   **二进制 .mo**，而这里的 load() 原本只按 .po 文本逐行解析：UTF-8 解码后的二进制内容
//   匹配不到任何 "msgid "/"msgstr " 行，解析出 0 条翻译，全游戏本地化查表因此全部落空
//   （语言名下拉只显示兜底的 "zh-Hans(zh-hans)"、切换语言无效）。现在构造时先取原始字节，
//   按 magic 分派：0x950412de（小端文件字节 DE 12 04 95 / 大端 95 04 12 DE）走二进制解析，
//   其余仍按 .po 文本解析。键编码与 NGettext 的 MoLoader/MoFileParser 对齐：
//     * 单数条目：键 = msgid 原样（带上下文时即 "msgctxt\u0004msgid"）；
//     * 复数条目：完整 msgid（"singular\u0000plural"，可带 "msgctxt\u0004" 前缀）作为
//       pluralForms 的键，msgstr 按 "\u0000" 拆成复数形式数组；同时把「到第一个 \u0000
//       为止的单数键」写入 translations（IsTranslationExist 的门槛 + GetString 的第 0 形式）。
class Catalog {
    private var translations:Map<String, String> = new Map();
    private var pluralForms:Map<String, Array<String>> = new Map();
    public var CultureInfo(get, never):Dynamic;
    public var TranslationCount(get, never):Int;
    private var culture:Dynamic;
    // PORT-NOTE: 诊断用：成功装入的条目数（.mo 的 N / .po 的 msgid 数），供验证脚本打印。
    private var entryCount:Int = 0;

    public function new(?stream:Stream, ?culture:Dynamic) {
        this.culture = culture;
        if (stream != null) {
            // PORT-NOTE: 二进制 .mo 必须走原始字节：MemoryStream.ReadToEnd()/FileStream.ReadToEnd()
            //   会先做 UTF-8 解码，无效序列被替换成 U+FFFD，魔法数都认不出。MemoryStream 与
            //   FileStream 的 ReadAll() 都返回完整内容；若拿到空（基类 Stream 的默认实现），
            //   退回原来的 ReadToEnd() 文本路径，保持对纯文本流的兼容。
            var bytes = stream.ReadAll();
            if (bytes != null && bytes.length > 0) {
                if (isMoMagic(bytes)) {
                    loadMo(bytes);
                } else {
                    load(bytes.toString());
                }
            } else {
                load(stream.ReadToEnd());
            }
        }
    }

    // ------------------------------------------------------------------ .po (text) ---

    private function load(content:String):Void {
        var currentId:String = null;
        var currentContext:String = null;
        for (line in content.split("\n")) {
            var trimmed = StringTools.trim(line);
            if (trimmed.length == 0 || trimmed.charAt(0) == "#")
                continue;
            if (StringTools.startsWith(trimmed, "msgctxt ")) {
                // PORT-NOTE: 与二进制路径保持同一套键编码：上下文条目的键是
                //   "msgctxt\u0004msgid"，否则 GetParticularString 查不到。
                currentContext = parseValue(trimmed.substr(8));
            } else if (StringTools.startsWith(trimmed, "msgid ")) {
                currentId = (currentContext != null ? currentContext + "\u0004" : "") + parseValue(trimmed.substr(6));
                currentContext = null;
            } else if (StringTools.startsWith(trimmed, "msgstr ") && currentId != null) {
                var value = parseValue(trimmed.substr(7));
                translations.set(currentId, value);
                entryCount++;
                currentId = null;
            }
        }
    }
    private static function parseValue(raw:String):String {
        var value = StringTools.trim(raw);
        if (value.length >= 2 && value.charAt(0) == '"' && value.charAt(value.length - 1) == '"') {
            value = value.substr(1, value.length - 2);
        }
        return StringTools.replace(value, "\\n", "\n");
    }

    // ------------------------------------------------------------------ .mo (binary) ---
    // 格式见 GNU gettext 手册「MO Files」章节：文件头 7 个 32 位整数
    //   magic(4) + revision(4) + N(4) + origOffset(4) + transOffset(4) + hashSize(4) + hashOffset(4)，
    //   随后 N 个 (length, offset) 对分别组成原串表与翻译表；字符串 UTF-8 存放于文件内，
    //   msgid 中 \x00 分隔 singular/plural、\x04 前缀 msgctxt，msgstr 中 \x00 分隔复数形式。
    // 32 位整数的字节序由 magic 判定；hash 表不读（查表走内存 Map）。解析行为对齐 NGettext 的
    // MoFileParser（魔法数/大端判定、revision 主版本 ≤ 1、按 (length, offset) 取串）。
    private static inline var MO_HEADER_SIZE:Int = 28;

    private static function isMoMagic(bytes:Bytes):Bool {
        if (bytes.length < 4)
            return false;
        // 小端魔法数 0x950412de 的文件字节序是 DE 12 04 95；大端是 95 04 12 DE。
        return (bytes.get(0) == 0xDE && bytes.get(1) == 0x12 && bytes.get(2) == 0x04 && bytes.get(3) == 0x95)
            || (bytes.get(0) == 0x95 && bytes.get(1) == 0x04 && bytes.get(2) == 0x12 && bytes.get(3) == 0xDE);
    }

    private static function readU32(bytes:Bytes, offset:Int, littleEndian:Bool):Int {
        var b0 = bytes.get(offset);
        var b1 = bytes.get(offset + 1);
        var b2 = bytes.get(offset + 2);
        var b3 = bytes.get(offset + 3);
        return littleEndian
            ? b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
            : b3 | (b2 << 8) | (b1 << 16) | (b0 << 24);
    }

    private function loadMo(bytes:Bytes):Void {
        if (bytes.length < MO_HEADER_SIZE) {
            throw 'MO 内容过短：${bytes.length} 字节（文件头至少 ${MO_HEADER_SIZE} 字节）';
        }
        var littleEndian = bytes.get(0) == 0xDE;
        var revision = readU32(bytes, 4, littleEndian);
        if ((revision >> 16) > 1) {
            throw '不支持的 MO 文件 revision：${revision}';
        }
        var count = readU32(bytes, 8, littleEndian);
        var origTableOffset = readU32(bytes, 12, littleEndian);
        var transTableOffset = readU32(bytes, 16, littleEndian);
        // hash 表大小/偏移（20/24）不读：本 shim 的查表全走内存 Map。
        // count 上界取文件长度的 1/8，既防伪造头部导致的超长循环，也保证 8*count 不溢出 Int
        // （合法 .mo 至少 28 + 16*N 字节，N ≤ 长度/8 恒成立）。
        var tableBytes = 8 * count;
        if (count < 0 || count > (bytes.length >> 3)
            || origTableOffset < 0 || origTableOffset > bytes.length - tableBytes
            || transTableOffset < 0 || transTableOffset > bytes.length - tableBytes) {
            throw 'MO 文件头越界：N=${count}，origTable=${origTableOffset}，transTable=${transTableOffset}，长度=${bytes.length}';
        }
        for (i in 0...count) {
            var origLength = readU32(bytes, origTableOffset + 8 * i, littleEndian);
            var origOffset = readU32(bytes, origTableOffset + 8 * i + 4, littleEndian);
            var transLength = readU32(bytes, transTableOffset + 8 * i, littleEndian);
            var transOffset = readU32(bytes, transTableOffset + 8 * i + 4, littleEndian);
            if (origOffset < 0 || origOffset > bytes.length || origLength < 0 || origLength > bytes.length - origOffset
                || transOffset < 0 || transOffset > bytes.length || transLength < 0 || transLength > bytes.length - transOffset) {
                throw 'MO 第 ${i} 个条目的串偏移/长度越界';
            }
            addMoEntry(bytes.getString(origOffset, origLength), bytes.getString(transOffset, transLength));
        }
    }

    private function addMoEntry(msgid:String, msgstr:String):Void {
        entryCount++;
        var separator = msgid.indexOf("\u0000");
        if (separator >= 0) {
            // 复数条目：msgid = "singular\u0000plural"（可带 "msgctxt\u0004" 前缀），
            // msgstr 的 "\u0000" 分隔各复数形式。对齐 NGettext：
            //   * 完整 msgid 作 pluralForms 的键 —— GetPluralString 拼的正是
            //     "id\u0000plural"（上下文条目的 id 已带 "ctx\u0004" 前缀）；
            //   * 单数键（到第一个 \u0000 为止）也写入 translations ——
            //     IsTranslationExist(singular) 因此为真（LanguagePack.TryGetStringPlural /
            //     TryGetStringParticularPlural 的门槛），GetString(singular) 则像 NGettext 的
            //     GetStringDefault 一样返回第 0 种复数形式。
            var singular = msgid.substr(0, separator);
            var forms = msgstr.split("\u0000");
            pluralForms.set(msgid, forms);
            translations.set(singular, forms.length > 0 ? forms[0] : msgstr);
        } else {
            // 单数条目：键 = msgid 原样。带上下文的条目在 .mo 里存的就是 "msgctxt\u0004msgid"，
            // 与 GetParticularString(context + "\u0004" + id)、LanguagePack.TryGetStringParticular 的
            // IsTranslationExist(context + "\u0004" + text) 查表键完全一致。
            translations.set(msgid, msgstr);
        }
    }
    inline function get_CultureInfo():Dynamic return culture;
    inline function get_TranslationCount():Int return entryCount;

    // PORT-NOTE: NGettext 的 GetString(id) / GetString(id, args) 在 Haxe 中无法重载，
    //   合并为可选参数形式（args 省略时不做格式化）。
    public function GetString(id:String, ?args:Array<Dynamic>):String {
        var format = translations.exists(id) ? translations.get(id) : id;
        if (args == null) return format;
        return formatString(format, args);
    }
    // PORT-NOTE: NGettext 的 GetPluralString(id, plural, n) / (..., args) 合并为可选参数形式。
    public function GetPluralString(id:String, plural:String, n:haxe.Int64, ?args:Array<Dynamic>):String {
        var key = id + "\u0000" + plural;
        var result:String;
        if (pluralForms.exists(key)) {
            var forms = pluralForms.get(key);
            result = forms.length > 0 ? forms[pluralIndex(n, forms.length)] : id;
        } else {
            result = Int64.eq(n, 1) ? GetString(id) : GetString(plural);
        }
        return args == null ? result : formatString(result, args);
    }
    // C#: public string GetParticularString(string context, string id, params object[] args)
    public function GetParticularString(context:String, id:String, ?args:Array<Dynamic>):String {
        var format = GetString(context + "\u0004" + id);
        return args == null ? format : formatString(format, args);
    }
    // C#: public string GetParticularPluralString(string context, string id, string plural, long n, params object[] args)
    public function GetParticularPluralString(context:String, id:String, plural:String, n:haxe.Int64, ?args:Array<Dynamic>):String {
        // PORT-NOTE: 键 = "ctx\u0004id\u0000plural"：context 只拼到 singular 上。旧实现把 context
        //   又拼了一遍 plural（"ctx\u0004id\u0000ctx\u0004plural"），那是 .mo 里不可能存在的键，
        //   上下文复数条目永远查不到。NGettext 的对应实现同样只按 "ctx\u0004singular" 查表。
        return GetPluralString(context + "\u0004" + id, plural, n, args);
    }
    // C#: public bool IsTranslationExist(string id)
    public function IsTranslationExist(id:String):Bool {
        return translations.exists(id);
    }
    private static inline function pluralIndex(n:haxe.Int64, count:Int):Int {
        // PORT-NOTE: 英文等两复数形式语言的简化实现（与 shim 的 PO 解析能力一致）。
        return Int64.eq(n, 1) ? 0 : (count > 1 ? 1 : 0);
    }

    private static function formatString(format:String, args:Array<Dynamic>):String {
        var result = format;
        if (args == null) return result;
        for (i in 0...args.length) {
            result = StringTools.replace(result, "{" + i + "}", Std.string(args[i]));
        }
        return result;
    }
}

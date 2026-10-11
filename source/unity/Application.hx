package unity;

// Minimal UnityEngine.Application shim.
// PORT-NOTE: `version` 的真实值由编译期宏从 HaxePort/Project.xml 的 `<app version="..."/>`
// 注入（见 ApplicationVersionMacro.hx）；下面的 "0.0.0" 只是宏读取失败时的回落初值。
@:build(unity.ApplicationVersionMacro.build())
class Application {
    public static var persistentDataPath(get, never):String;
    public static var dataPath(get, never):String;
    public static var streamingAssetsPath(get, never):String;
    public static var temporaryCachePath(get, never):String;
    public static var version:String = "0.0.0";
    public static var unityVersion:String = "haxe-port";
    public static var isEditor:Bool = false;
    public static var isPlaying:Bool = true;
    // PORT-NOTE: 补全 Application.targetFrameRate（-1 表示平台默认）。
    public static var targetFrameRate:Int = -1;
    // C#: public static bool isFocused { get; }
    // PORT-NOTE: 移植层没有窗口焦点事件源，默认视为持焦；如需真实语义应由 lime 窗口事件驱动。
    public static var isFocused:Bool = true;
    // C#: public static SystemLanguage systemLanguage { get; }
    public static var systemLanguage(get, never):SystemLanguage;
    static function get_systemLanguage():SystemLanguage {
        // PORT-NOTE: 由 Haxe 的 Sys.systemName() 粗略映射到 Unity 的 SystemLanguage。
        #if sys
        return switch (Sys.systemName()) {
            case "Windows": SystemLanguage.English;
            case "Linux": SystemLanguage.English;
            case "Mac": SystemLanguage.English;
            default: SystemLanguage.English;
        };
        #else
        return SystemLanguage.English;
        #end
    }
    public static var platform(get, never):RuntimePlatform;

    // C#: public static void SetStackTraceLogType(LogType logType, StackTraceLogType stackTraceType)
    // PORT-NOTE: 移植层无 Unity 的堆栈跟踪开关，保留调用点但不产生副作用。
    public static function SetStackTraceLogType(logType:LogType, stackTraceType:StackTraceLogType):Void {}
    // C#: public static StackTraceLogType GetStackTraceLogType(LogType logType)
    public static function GetStackTraceLogType(logType:LogType):StackTraceLogType return StackTraceLogType.None;

    static function get_persistentDataPath():String {
        // PORT-NOTE: uses lime storage directory instead of Unity's persistentDataPath
        #if sys
        return lime.system.System.applicationStorageDirectory;
        #else
        return "";
        #end
    }
    static function get_dataPath():String return "assets";
    static function get_streamingAssetsPath():String return "assets";
    static function get_temporaryCachePath():String return get_persistentDataPath() + "/tmp";
    static function get_platform():RuntimePlatform {
        #if android
        return RuntimePlatform.Android;
        #elseif ios
        return RuntimePlatform.IPhonePlayer;
        #elseif windows
        return RuntimePlatform.WindowsPlayer;
        #elseif mac
        return RuntimePlatform.OSXPlayer;
        #elseif linux
        return RuntimePlatform.LinuxPlayer;
        #else
        return RuntimePlatform.WindowsPlayer;
        #end
    }

    public static function Quit():Void {
        #if sys
        Sys.exit(0);
        #end
    }

    // event Action<string, string, LogType> logMessageReceivedThreaded
    public static var logMessageReceivedThreaded:Array<String->String->LogType->Void> = [];
    public static var logMessageReceived:Array<String->String->LogType->Void> = [];

    // PORT-NOTE: invoked by unity.Debug when a message is logged.
    public static function dispatchLog(message:String, stackTrace:String, type:LogType):Void {
        for (listener in logMessageReceivedThreaded.copy()) {
            listener(message, stackTrace, type);
        }
        for (listener in logMessageReceived.copy()) {
            listener(message, stackTrace, type);
        }
    }
}

enum abstract RuntimePlatform(Int) {
    var WindowsPlayer = 1;
    var OSXPlayer = 4;
    var LinuxPlayer = 13;
    var IPhonePlayer = 8;
    var Android = 11;
    var WebGLPlayer = 17;
    var WindowsEditor = 7;
}

enum abstract LogType(Int) {
    var Error = 0;
    var Assert = 1;
    var Warning = 2;
    var Log = 3;
    var Exception = 4;
}

// C#: UnityEngine.StackTraceLogType
enum abstract StackTraceLogType(Int) {
    var None = 0;
    var ScriptOnly = 1;
    var Full = 2;
}

// C#: UnityEngine.SystemLanguage（仅列出本作可能用到的成员，数值与 Unity 一致）。
enum abstract SystemLanguage(Int) {
    var Afrikaans = 0;
    var Arabic = 1;
    var Basque = 2;
    var Belarusian = 3;
    var Bulgarian = 4;
    var Catalan = 5;
    var Chinese = 6;
    var Czech = 7;
    var Danish = 8;
    var Dutch = 9;
    var English = 10;
    var Estonian = 11;
    var Faroese = 12;
    var Finnish = 13;
    var French = 14;
    var German = 15;
    var Greek = 16;
    var Hebrew = 17;
    var Hungarian = 18;
    var Icelandic = 19;
    var Indonesian = 20;
    var Italian = 21;
    var Japanese = 22;
    var Korean = 23;
    var Latvian = 24;
    var Lithuanian = 25;
    var Norwegian = 26;
    var Polish = 27;
    var Portuguese = 28;
    var Romanian = 29;
    var Russian = 30;
    var SerboCroatian = 31;
    var Slovak = 32;
    var Slovenian = 33;
    var Spanish = 34;
    var Swedish = 35;
    var Thai = 36;
    var Turkish = 37;
    var Ukrainian = 38;
    var Vietnamese = 39;
    var ChineseSimplified = 40;
    var ChineseTraditional = 41;
    var Unknown = 42;
}

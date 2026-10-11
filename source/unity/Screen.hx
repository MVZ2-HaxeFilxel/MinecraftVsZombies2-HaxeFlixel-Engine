package unity;

import flixel.FlxG;

// Minimal UnityEngine.Screen shim.
class Screen {
    public static var width(get, never):Int;
    public static var height(get, never):Int;

    static inline function get_width():Int return FlxG.width;
    static inline function get_height():Int return FlxG.height;

    // PORT-NOTE: 移植层没有系统分辨率枚举，返回由当前窗口尺寸构造的单一分辨率列表。
    public static var resolutions(get, never):Array<Resolution>;
    static function get_resolutions():Array<Resolution> {
        return [currentResolution];
    }
    public static var currentResolution(get, never):Resolution;
    static function get_currentResolution():Resolution {
        return new Resolution(FlxG.width, FlxG.height, new RefreshRate(Std.int(FlxG.drawFramerate), 1));
    }
    public static var fullScreenMode(get, never):FullScreenMode;
    static function get_fullScreenMode():FullScreenMode {
        return FullScreenMode.Windowed;
    }
    // PORT-NOTE: 补全 fullScreen 的 setter（ResolutionManager 会写入该项），桥接到 FlxG.fullscreen。
    public static var fullScreen(get, set):Bool;
    static function get_fullScreen():Bool return FlxG.fullscreen;
    static function set_fullScreen(value:Bool):Bool {
        // MVZ2-DEBUG-WINDOWED: 验证用环境变量强制窗口化（全屏时 lime 窗口位置异常，底部 UI 落到
        // 屏幕外无法交互）。收尾时移除。
        if (Sys.getEnv("MVZ2_WINDOWED") == "1")
            value = false;
        FlxG.fullscreen = value;
        return value;
    }
    // PORT-NOTE: 刷新率不参与逻辑，SetResolution 仅改变窗口尺寸。
    public static function SetResolution(width:Int, height:Int, fullscreenMode:FullScreenMode, ?preferredRefreshRate:RefreshRate):Void {
        FlxG.resizeWindow(width, height);
    }

    // C#: public static int sleepTimeout { get; set; }
    // PORT-NOTE: 移动端息屏控制无 Haxe 等价实现（MainManager.InitGameSettings 会写入 SleepTimeout.NeverSleep），
    // 这里只保留取值语义，不影响运行。
    public static var sleepTimeout:Int = SleepTimeout.NeverSleep;
}

// C#: UnityEngine.SleepTimeout
class SleepTimeout {
    public static inline var NeverSleep:Int = -1;
    public static inline var SystemSetting:Int = -2;
}

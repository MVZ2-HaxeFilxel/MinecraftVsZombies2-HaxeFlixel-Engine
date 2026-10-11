package;

import flixel.FlxGame;
import openfl.display.Sprite;
import mvz2.states.InitState;

/**
 * Entry point of the HaxeFlixel port of Minecraft VS Zombies 2.
 * Mirrors the Unity landing scene -> main scene flow:
 * InitState bootstraps managers (the former MainManager) then switches
 * to the title screen state.
 */
class Main extends Sprite
{
	public static var gameWidth:Int = 1280;
	public static var gameHeight:Int = 720;
	public static var initialState:Class<flixel.FlxState> = InitState;
	public static var framerate:Int = 60;

	public static function main():Void
	{
		// PORT-NOTE: 启动追踪要在任何 flixel/openfl 逻辑之前开始——lime 的 Windows 程序是 GUI 子系统，
		// stdout/stderr 全部丢弃，启动阶段出了问题（尤其是 hxcpp 启动期静态初始化里的空指针段错误）
		// 会看不到任何信息。详见 mvz2.states.BootTrace。
		mvz2.states.BootTrace.start();
		mvz2.states.BootTrace.step("Main.main 进入");
		var app = new Main();
		mvz2.states.BootTrace.step("Main 实例已创建（FlxGame 已挂载）");
		openfl.Lib.current.addChild(app);
		mvz2.states.BootTrace.step("Main 已挂载到 stage");
		installFrameHeartbeat();
	}

	// PORT-NOTE: 独立于 flixel 状态机的心跳。FlxGame.update() 在 `!_state.active || !_state.exists`
	// 或存在 subState 时会直接返回、根本不会调用 FlxState.update，那种情况下"进程还活着"和
	// "游戏循环真的在跑"完全不是一回事。这里直接挂在 openfl 的 ENTER_FRAME 上，用来区分二者。
	public static var frameCount(default, null):Int = 0;

	private static function installFrameHeartbeat():Void
	{
		openfl.Lib.current.stage.addEventListener(openfl.events.Event.ENTER_FRAME, function(_) {
			frameCount++;
			if (frameCount == 1) {
				mvz2.states.BootTrace.step("ENTER_FRAME 心跳：第 1 帧（openfl 主循环在跑）");
				var win = lime.app.Application.current != null ? lime.app.Application.current.window : null;
				mvz2.states.BootTrace.step('窗口诊断：FlxG=${flixel.FlxG.width}x${flixel.FlxG.height}'
					+ ' stage=${openfl.Lib.current.stage.stageWidth}x${openfl.Lib.current.stage.stageHeight}'
					+ (win != null ? ' window=${win.width}x${win.height}@(${win.x},${win.y}) scale=${win.scale} fullscreen=${win.fullscreen}' : ' window=null'));
			}
			else if (frameCount % 1800 == 0)
				mvz2.states.BootTrace.step('ENTER_FRAME 心跳：第 $frameCount 帧');
		});
	}

	public function new()
	{
		super();
		addChild(new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, true, false));
	}
}

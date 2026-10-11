// Ported from: Assets/Prefabs/MainGame.prefab（+ 其嵌套的 MainManager.prefab）
//              Assets/GameContent/Scenes/Main.unity
// PORT-NOTE: 原工程 "Main" 场景 = MainGame.prefab 的一个实例；MainGame.prefab 又嵌套
// MainManager.prefab（全部管理器）与 MainScene 子树（全部 UI 控制器）。Unity 由 prefab 反序列化
// 建立对象图并注入 [SerializeField] 引用；移植阶段 prefab 尚未转换为可运行的数据，
// 这里用代码重建同一棵对象图的"骨架"：对象名、层级、组件，以及主流程用得到的序列化引用。
// 完整的 prefab→场景 转换应由资源转换工作包完成（见报告"需配合事项"），届时本文件应改为
// 读取转换后的场景数据，而不是手写对象图。
//
// PORT-NOTE: 本文件里注入的序列化字段 / 调用的生命周期方法在 C# 中是 private（[SerializeField]
// 字段与 Unity 反射调用的 Awake/Start/Update），Haxe 用 @:privateAccess 表达式标注跨类访问。
package mvz2.states;

import mvz2.addons.AddonsController;
import mvz2.almanacs.AlmanacController;
import mvz2.almanacs.AlmanacManager;
import mvz2.animations.AnimatorAutoUpdater;
import mvz2.arcade.ArcadeController;
import mvz2.archives.ArchiveController;
import mvz2.audios.AudioManifest;
import mvz2.audios.MusicManager;
import mvz2.audios.SoundManager;
import mvz2.audios.SoundSource;
import mvz2.cameras.ResolutionManager;
import mvz2.cameras.ShakeManager;
import mvz2.chaptertransition.ChapterTransitionController;
import mvz2.cursors.CursorManager;
import mvz2.debugconsole.DebugConsoleController;
import mvz2.debugs.DebugManager;
import mvz2.io.FileManager;
import mvz2.inputs.InputManager;
import mvz2.level.CameraLimiter;
import mvz2.level.LevelManager;
import mvz2.localization.LanguageManager;
import mvz2.mainmenu.DeleteUserDialogController;
import mvz2.mainmenu.InputNameDialogController;
import mvz2.mainmenu.MainmenuController;
import mvz2.managers.CoroutineManager;
import mvz2.managers.FontManager;
import mvz2.managers.MainManager;
import mvz2.managers.PerformanceManager;
import mvz2.managers.PerformanceManager.PerformanceData;
import mvz2.managers.ResourceManager;
import mvz2.managers.TalkManager;
import mvz2.map.MapController;
import mvz2.modding.ModManager;
import mvz2.models.GraphicsManager;
import mvz2.models.ModelManager;
import mvz2.musicroom.MusicRoomController;
import mvz2.note.NoteController;
import mvz2.options.OptionsManager;
import mvz2.scenes.AchievementHintController;
import mvz2.scenes.CreditsController;
import mvz2.scenes.GameEntrance;
import mvz2.scenes.GameUpdater;
import mvz2.scenes.KeybindingController;
import mvz2.scenes.MainSceneController;
import mvz2.scenes.PopupController;
import mvz2.scenes.SceneLoadingManager;
import mvz2.scenes.ScenePrefabLoader;
import mvz2.scenes.SplashController;
import mvz2.saves.SaveManager;
import mvz2.store.StoreController;
import mvz2.store.StoreManager;
import mvz2.supporters.SponsorManager;
import mvz2.titlescreen.TitlescreenController;
import mvz2.ui.ColorFader;
import mvz2.ui.ButtonRow;
import mvz2.ui.CustomDialog;
import mvz2.ui.DeleteUserDialog;
import mvz2.ui.ElementList;
import mvz2.ui.ElementListUI;
import mvz2.ui.FPSDisplayer;
import mvz2.ui.FloatFader;
import mvz2.ui.InputNameDialog;
import mvz2.ui.TextButton;
import mvz2.ui.Tooltip;
import mvz2.ui.UserManageItem;
import mvz2.ui.UserManageList;
import mvz2.ui.scene.DebugConsoleIcon;
import mvz2.ui.scene.MainSceneUI;
import mvz2.ui.titlescreen.TitlescreenUI;
import mvz2.ui.mainmenu.MainmenuUI;
import mvz2.ui.scene.PortalController;
import unity.AudioMixer;
import unity.AudioSource;
import unity.Camera;
import unity.Component;
import unity.Debug;
import unity.GameObject;
import unity.MonoBehaviour;
import unity.RectTransform;
import unity.Vector2;
import unity.tmpro.TextMeshProUGUI;
import unity.tmpro.TMP_InputField;
import unity.ui.Button;
import unity.ui.Image;
import unity.ui.Toggle;

class MainGameScene {
	public var root(default, null):GameObject;
	public var mainManager(default, null):MainManager;
	public var entrance(default, null):GameEntrance;
	public var updater(default, null):GameUpdater;
	public var sceneController(default, null):MainSceneController;
	/** 场景内全部 MonoBehaviour，用于驱动各自的协程运行器（对应 Unity 引擎行为）。 */
	public var behaviours(default, null):Array<MonoBehaviour> = [];
	/** Awake 分发时抛异常的组件（移植阶段 prefab 引用缺失时会出现在这里）。 */
	public var awakeFailures(default, null):Array<String> = [];
	/** 因 prefab 序列化引用尚未转换而"跳过 Awake"的组件名（见 page()）。 */
	public var skippedAwake(default, null):Array<String> = [];

	/** 因抛异常而停止步进协程的组件（等价 Unity 只记录日志、不中断其它组件的行为）。 */
	public var failedCoroutines(default, null):Array<MonoBehaviour> = [];

	public function new() {
		build();
	}

	// #region 生命周期分发
	// PORT-NOTE: Unity 由引擎调用场景内组件的 Awake/Start/Update。移植层没有引擎反射，
	// 改为在此登记步骤并按序显式调用（顺序：MainManager 最先，因为它负责设置
	// MainManager.Instance，其余组件在 Awake 中会读取该单例）。
	public function awakeAll():Void {
		for (step in awakeSteps) {
			// PORT-NOTE: 先记录再调用——如果某个 Awake 触发的是 C++ 层崩溃（而非 Haxe 异常），
			// try/catch 捕获不到，只能靠这条"最后开始的步骤"定位。
			BootTrace.step('Awake ${step.name}');
			try {
				step.run();
			} catch (e:Dynamic) {
				var message = '${step.name}: ${Std.string(e)}';
				awakeFailures.push(message);
				BootTrace.error('Awake 失败 - $message');
				Debug.LogError('[MVZ2] Awake 失败 - $message');
			}
		}
	}

	/**
	 * 对应 Unity 在 Awake 之后对场景对象调用 Start。
	 * GameEntrance.Start 是本场景真正的启动入口（Landing 场景加载完 Main 场景后由它接管）。
	 * 这里不捕获异常，由 MainSceneState 统一降级到 ErrorState。
	 */
	public function startAll():Void {
		BootTrace.step("GameEntrance.Start（main.Initialize + InitLoad）");
		@:privateAccess entrance.Start();
	}

	public function update(elapsed:Float):Void {
		// PORT-NOTE: Unity 的引擎每帧自动推进所有 `enabled && activeInHierarchy` 的 Animator。
		// 移植层没有引擎，这里补上同样的分发 —— **这是动画事件（Splash 的 EnterTitleScreen、
		// Mainmenu 的 Init 等）被触发的唯一途径**，也是 Splash → Titlescreen 页面推进的前提。
		animatorUpdater.update(elapsed);
		for (behaviour in behaviours) {
			if (behaviour.gameObject == null || !behaviour.gameObject.activeInHierarchy)
				continue;
			// PORT-NOTE: Unity 里某个组件的协程抛异常只影响它自己（引擎记日志后继续跑其它组件）。
			// 移植层没有引擎边界，异常会一路冒到 FlxGame 的 update 循环里，因此这里补上同样的隔离，
			// 并把失败写进 boot-trace（lime 的 Windows GUI 程序没有 stdout，只看 Debug.LogError 看不到）。
			var runner = behaviour.coroutineRunner;
			if (runner == null || failedCoroutines.indexOf(behaviour) >= 0)
				continue;
			try {
				runner.update(elapsed);
			} catch (e:Dynamic) {
				failedCoroutines.push(behaviour);
				var message = '${Type.getClassName(Type.getClass(behaviour))}: ${Std.string(e)}';
				BootTrace.error('协程 Update 失败（该组件已停止步进协程）- $message');
				Debug.LogError('[MVZ2] 协程 Update 失败（该组件已停止步进协程）- $message');
			}
		}
		for (step in updateSteps) {
			if (!step.enabled)
				continue;
			// PORT-NOTE: Unity 不会对未激活对象调用 Update，这里用同样的判断。
			if (step.gameObject != null && !step.gameObject.activeInHierarchy)
				continue;
			try {
				step.run();
			} catch (e:Dynamic) {
				step.enabled = false;
				var message = '${step.name}: ${Std.string(e)}';
				BootTrace.error('Update 失败（该组件已停止 Update）- $message');
				Debug.LogError('[MVZ2] Update 失败（该组件已停止 Update）- $message');
			}
		}
	}
	// #endregion

	// #region 场景构建
	private function build():Void {
		root = new GameObject("MainGame");

		BootTrace.step("build: MainManager 及其管理器");
		buildManagers();
		BootTrace.step("build: MainScene（UI 与页面控制器）");
		buildMainScene();
		BootTrace.step("build: GameEntrance / GameUpdater");
		buildGameEntrance();
		// PORT-NOTE: 全部页面/prefab 注入完成后再登记 Animator（页面 prefab 的子节点是
		// InjectPagePrefab 里新建出来的，构建期登记会漏掉它们）。
		animatorUpdater.addTree(root);
		// PORT-NOTE: 同时打印 `GetComponentsInChildren` 的结果作为对照 —— 实测该方法在
		// 未激活的页面子树上会漏（页面根由 `page()` 设为 `SetActive(false)`），
		// 显式遍历 `transform.children` 才拿得到全部。两者差值是诊断依据。
		var viaGetComponents = root.GetComponentsInChildren(unity.Animator, true).length;
		BootTrace.step('Animator 已登记：${animatorUpdater.count} 个（每帧自动推进，触发动画事件）'
			+ '，其中未绑定 controller 数据 ${animatorUpdater.unboundCount} 个'
			+ '（GetComponentsInChildren 对照值：$viaGetComponents）');
	}

	/** 场景级 Animator 自动推进（对应 Unity 引擎每帧推进 enabled 的 Animator）。 */
	public var animatorUpdater(default, null):AnimatorAutoUpdater = new AnimatorAutoUpdater();

	/** 对应 MainGame.prefab 中嵌套的 MainManager.prefab。 */
	private function buildManagers():Void {
		@:privateAccess {
			var managers = child(root, "MainManager");
			mainManager = attach(managers, new MainManager());
			awakeStep("MainManager", () -> mainManager.Awake());

			var coroutine = attach(child(managers, "CoroutineManager"), new CoroutineManager());
			var resource = attach(child(managers, "ResourceManager"), new ResourceManager());
			var lang = attach(child(managers, "LangManager"), new LanguageManager());
			var mod = attach(child(managers, "ModManager"), new ModManager());
			var save = attach(child(managers, "SaveManager"), new SaveManager());
			var model = attach(child(managers, "ModelManager"), new ModelManager());
			var music = attach(child(managers, "MusicManager"), new MusicManager());
			var sound = attach(child(managers, "SoundManager"), new SoundManager());
			var level = attach(child(managers, "LevelManager"), new LevelManager());
			var cursor = attach(child(managers, "CursorManager"), new CursorManager());
			var shake = attach(child(managers, "ShakeManager"), new ShakeManager());
			var file = attach(child(managers, "FileManager"), new FileManager());
			var font = attach(child(managers, "FontManager"), new FontManager());
			var options = attach(child(managers, "OptionsManager"), new OptionsManager());
			var resolution = attach(child(managers, "ResolutionManager"), new ResolutionManager());
			var sceneManager = attach(child(managers, "SceneManager"), new SceneLoadingManager());
			var almanac = attach(child(managers, "AlmanacManager"), new AlmanacManager());
			var store = attach(child(managers, "StoreManager"), new StoreManager());
			var input = attach(child(managers, "InputManager"), new InputManager());
			var sponsor = attach(child(managers, "SponsorManager"), new SponsorManager());
			var graphics = attach(child(managers, "GraphicsManager"), new GraphicsManager());
			var debug = attach(child(managers, "DebugManager"), new DebugManager());
			var performance = attach(child(managers, "PerformanceManager"), new PerformanceManager());
			var talk = attach(child(managers, "TalkManager"), new TalkManager());

			// MainManager 的字段在 C# 中是 [SerializeField] private，由 prefab 注入。
			mainManager.coroutine = coroutine;
			mainManager.resource = resource;
			mainManager.lang = lang;
			mainManager.mod = mod;
			mainManager.save = save;
			mainManager.model = model;
			mainManager.music = music;
			mainManager.sound = sound;
			mainManager.level = level;
			mainManager.cursor = cursor;
			mainManager.shake = shake;
			mainManager.file = file;
			mainManager.fontManager = font;
			mainManager.options = options;
			mainManager.resolution = resolution;
			mainManager.sceneLoadingManager = sceneManager;
			mainManager.almanacManager = almanac;
			mainManager.storeManager = store;
			mainManager.inputManager = input;
			mainManager.sponsorManager = sponsor;
			mainManager.graphicsManager = graphics;
			mainManager.debugManager = debug;
			mainManager.performanceManager = performance;
			mainManager.talkManager = talk;

			// PORT-NOTE: 以下管理器在 Awake/Update 中直接使用各自持有的 main 引用（其余管理器改用
			// MainManager.Instance），对应 prefab 里注入的 MainManager 引用。
			resource.main = mainManager;
			lang.main = mainManager;
			mod.main = mainManager;
			model.main = mainManager;
			music.main = mainManager;
			sound.main = mainManager;
			level.main = mainManager;
			graphics.main = mainManager;

			// PORT-NOTE: MusicManager 的音频组件（mixer / 主副音轨 / 音量渐变器）在 prefab 中是
			// MusicManager 下的同名子对象，这里保留同样的挂载方式。
			// mixer 在 prefab 里指向工程唯一的 mixer 资源 Assets/Mixers/Main（与 SoundManager 同一个）。
			// 注意**必须**用 AudioManifest.mainMixer 而不是 AudioMixer.main：unity.AudioMixer 在构造
			// 时就 getGraph() 并缓存（AudioMixer.hx:35），而总路线图是 AudioManifest 载入清单时才
			// defineGraph 的；直接 AudioMixer.main 会先造出一个空图实例并一直沿用（表现为
			// 「mixer 总线 MainTrack 不存在」「没有暴露参数 MainWeight」等一串告警，音量/音轨权重失效）。
			// AudioManifest.mainMixer 会先 ensureLoaded() 再取 AudioMixer.main，拿到的是已定义好的图。
			music.mixer = AudioManifest.mainMixer;
			music.mainTrackSource = attach(child(music.gameObject, "Main"), new AudioSource());
			music.mainTrackSource.loop = true;
			music.subTrackSource = attach(child(music.gameObject, "Sub"), new AudioSource());
			music.subTrackSource.loop = true;
			music.volumeFader = attach(child(music.gameObject, "Fader"), new FloatFader());

			// PORT-NOTE: SoundManager 的 prefab 序列化引用（Assets/Prefabs/Init/MainManager.prefab）：
			// soundSourceRoot / loopSoundSourceRoot = "Sources" / "LoopSources" 子对象的 Transform，
			// soundTemplate / loopSoundTemplate = "SoundTemplate" / "LoopSoundTemplate" 子对象上的
			// SoundSource（其 audioSource = 同对象的 AudioSource，volumeFader = 同对象的 FloatFader；
			// 模板的 AudioSource 在 prefab 里 Loop=1 仅 Loop 版）。缺了 mixer 会让
			// SoundManager.SetGlobalVolume 在读取设置音量时（OptionsManager.LoadOptions 的
			// OnOptionChangedFloat 回调）直接空引用。
			sound.mixer = AudioManifest.mainMixer;
			sound.soundSourceRoot = child(sound.gameObject, "Sources").transform;
			sound.loopSoundSourceRoot = child(sound.gameObject, "LoopSources").transform;
			var soundTemplateObject = child(sound.gameObject, "SoundTemplate");
			sound.soundTemplate = attach(soundTemplateObject, new SoundSource());
			sound.soundTemplate.audioSource = attach(soundTemplateObject, new AudioSource());
			sound.soundTemplate.volumeFader = attach(soundTemplateObject, new FloatFader());

			var loopSoundTemplateObject = child(sound.gameObject, "LoopSoundTemplate");
			sound.loopSoundTemplate = attach(loopSoundTemplateObject, new SoundSource());
			sound.loopSoundTemplate.audioSource = attach(loopSoundTemplateObject, new AudioSource());
			sound.loopSoundTemplate.audioSource.loop = true;
			sound.loopSoundTemplate.volumeFader = attach(loopSoundTemplateObject, new FloatFader());

			// PORT-NOTE: PerformanceManager.animatorBatchData 在 prefab 中是内嵌的序列化对象
			// （PerformanceData，不是组件），Haxe 侧直接构造（默认值与 C# 声明一致）。
			performance.animatorBatchData = new PerformanceData();

			// TODO-PORT: TalkManager.prefab 下还有 Portraits 立绘池子层级；立绘资源尚未转换，这里只保留层级名。
			child(talk.gameObject, "Portraits");

			awakeStep("LanguageManager", () -> lang.Awake());
			awakeStep("MusicManager", () -> music.Awake());
			awakeStep("SoundManager", () -> sound.Awake());
			awakeStep("ResolutionManager", () -> resolution.Awake());
			awakeStep("GraphicsManager", () -> graphics.Awake());
			awakeStep("PerformanceManager", () -> performance.Awake());

			updateStep("SoundManager", sound.gameObject, () -> sound.Update());
			updateStep("MusicManager", music.gameObject, () -> music.Update());
			updateStep("CursorManager", cursor.gameObject, () -> cursor.Update());
			updateStep("ShakeManager", shake.gameObject, () -> shake.Update());
			updateStep("InputManager", input.gameObject, () -> input.Update());
			updateStep("ResolutionManager", resolution.gameObject, () -> resolution.Update());
			updateStep("PerformanceManager", performance.gameObject, () -> performance.Update());
		}
	}

	/** 对应 MainGame.prefab 中的 MainScene 子树（MainSceneController + 各页面组件）。 */
	private function buildMainScene():Void {
		@:privateAccess {
			var mainScene = child(root, "MainScene");
			sceneController = attach(mainScene, new MainSceneController());

			// #region UI（MainSceneUI + 摄像机限制器）
			var uiObject = child(mainScene, "UI");
			var ui = attach(uiObject, new MainSceneUI());
			// PORT-NOTE: MainGame.prefab 里 "ScreenCover" 节点（fileID 4077540474257370161）同时挂着
			// Image（3413564443117529296）与 ColorFader（3657868704250761626）：
			// MainSceneUI.screenCoverFader 与 blackscreenImage 指向同一个 GameObject 上的两个组件。
			// 缺 blackscreenImage 时 OnBlackscreenFaderValueChangedCallback（MainSceneUI.hx:85）
			// 会在 `blackscreenImage.color = value` 处空引用——SetScreenCoverColor / FadeScreenCoverColor
			// （章节切换、IZombie 开始等）都会走到。
			// PORT-NOTE: ScreenCover 在 prefab（`assets/scene_prefabs/scenes/Main.json` 节点 11）里是
			// **RectTransform**：anchorMin=(0,0)、anchorMax=(1,1)、sizeDelta=(0,0)、pivot=(0.5,0.5)
			// —— 即铺满整个画布。原先这里用 `child()` 建的是普通 `Transform`，被渲染桥判为
			//「Graphic 挂在非 RectTransform 上」直接跳过（boot-trace 里
			// `Graphic 挂在非 RectTransform 上：.../UI/ScreenCover [unity.ui.Image tr=unity.Transform]`），
			// 于是 `SetScreenCoverColor` / `FadeScreenCoverColor`（章节切换、IZombie 开场黑幕、
			// Splash 淡入淡出）全都画不出来。
			// 注意：初始颜色必须**全透明**（prefab 里是 (0,0,0,0)）——`unity.ui.Image` 的默认色是
			// 不透明白，若照默认值渲染，这个铺满屏幕的 Image 会把整个画面盖成白色。
			var screenCover = childRect(uiObject, "ScreenCover");
			var screenCoverRect:RectTransform = cast screenCover.transform;
			screenCoverRect.anchorMin = new Vector2(0, 0);
			screenCoverRect.anchorMax = new Vector2(1, 1);
			screenCoverRect.anchoredPosition = new Vector2(0, 0);
			screenCoverRect.sizeDelta = new Vector2(0, 0);
			screenCoverRect.pivot = new Vector2(0.5, 0.5);
			ui.screenCoverFader = attach(screenCover, new ColorFader());
			var screenCoverImage = attach(screenCover, new Image());
			screenCoverImage.color = new unity.Color(0, 0, 0, 0);
			screenCoverImage.raycastTarget = false;
			ui.blackscreenImage = screenCoverImage;
			ui.debugConsoleIcon = attach(child(uiObject, "DebugIcon"), new DebugConsoleIcon());
			// PORT-NOTE: Tooltip 的 Show/Hide 只访问 gameObject，挂上即可让
			// MainSceneController.UpdateTooltip 在没有提示源时正常工作。
			ui.tooltip = attach(child(uiObject, "Tooltip"), new Tooltip());
			// PORT-NOTE: MainGame.prefab 里 "Dialogs" 是**一个**节点，下面挂 3 个对话框实例
			// （CustomDialog / InputNameDialog / DeleteUserDialog 各自的 prefab 实例）。
			// 因此三个 build*Dialog() 共用一个 Dialogs 父节点，不要各建一个。
			var dialogsObject = childRect(uiObject, "Dialogs");
			// PORT-NOTE: prefab 里 "Dialogs" 节点（`assets/scene_prefabs/Prefabs/MainGame.json`
			// 节点 21）的 RectTransform 序列化值：anchorMin=(0,0)、anchorMax=(1,1)、
			// sizeDelta=(0,0)、pivot=(0.5,0.5) —— 铺满整个画布。`childRect()` 给的是
			// RectTransform 默认值（anchorMin/Max=(0.5,0.5)、sizeDelta=(0,0)），不补这些字段
			// 的话，三个对话框的根（各自 prefab 数据的根都是 amin=(0,0)/amax=(1,1) 的拉伸 rect，
			// 由 ScenePrefabLoader 的根接管模式写入）会被这个 0×0 父帧塌成 1×1：Blocker
			//（raycastTarget=1 的模态遮罩）挡不住点击，布局也跟着错。与上面 ScreenCover 同一处补法。
			var dialogsRect:RectTransform = cast dialogsObject.transform;
			dialogsRect.anchorMin = new Vector2(0, 0);
			dialogsRect.anchorMax = new Vector2(1, 1);
			dialogsRect.anchoredPosition = new Vector2(0, 0);
			dialogsRect.sizeDelta = new Vector2(0, 0);
			dialogsRect.pivot = new Vector2(0.5, 0.5);
			// PORT-NOTE: CustomDialog 是 MainSceneUI 的 [SerializeField] 引用，由 MainGame.prefab
			// （fileID 4113767335989909255 的 MainSceneUI 组件）注入 CustomDialog.prefab 的实例。
			// 缺了它，GameEntrance.CheckSaveDataStatus → MainSceneController.ShowDialogMessageAsync
			// → MainSceneUI.ShowDialogTask（MainSceneUI.hx:32 的 `dialog.gameObject.SetActive(true)`）
			// 会空引用——这是修掉构建错误后启动链路走到的第一个真实崩点。
			// 对象图按 Assets/Prefabs/UI/Dialogs/CustomDialog.prefab 重建（见 buildDialog）。
			ui.dialog = buildDialog(dialogsObject);
			// PORT-NOTE: `Dialogs` 下的三棵子树与页面树是**独立的对象图**（同一个 prefab 的第二份
			// 实例），因此 `dispatchPageAwakes` 覆盖不到它们，必须单独登记 Awake。
			// 缺了这一步，`InputNameDialog.Awake` / `DeleteUserDialog.Awake` 不执行 ——
			// 它们的 confirm/cancel/delete 按钮监听器永远不会挂上，
			// `ShowInputNameDialogAsync().awaitResult()` 会**永久挂起**（GameEntrance 的
			// CheckSaveDataStatus 与 MainmenuController.Init 都会 await 它）。
			dispatchPageAwakes({gameObject: ui.dialog.gameObject, component: ui.dialog});
			sceneController.ui = ui;

			// PORT-NOTE: MainGame.prefab 的 MainSceneController 有两个相机引用：
			//   uiCamera:        1519143245969430927
			//   uiCameraLimiter: 4198902581164152378
			// 二者都来自 Assets/Prefabs/Camera.prefab 的同一个实例（MainGame.prefab 里
			// PrefabInstance 7907983209692094213，其 Camera 组件 fileID 8695281478793315978、
			// 挂在该 prefab 的 "Camera" 节点 9073410350468147870 上）。CameraLimiter 组件的
			// `_camera` 也指向这同一个 Camera（Camera.prefab 里 `_camera: 8695281478793315978`）。
			// 因此这里只建一个 Camera 实例，同时给 uiCamera 与 uiCameraLimiter._camera。
			// 缺 uiCamera 时 UpdateTooltip 的 `uiCamera.ScreenToWorldPoint(...)`
			//（MainSceneController.hx:317，在有 tooltip 源且有相机时触发）会空引用。
			var uiCameraObject = child(mainScene, "Camera");
			var uiCamera = attach(uiCameraObject, new Camera());
			// PORT-NOTE: 与 Assets/Prefabs/Camera.prefab 一致（orthographicSize=3）。
			// 缺了这一项会取 Camera 默认值 5 → 正交投影 ppu 从 120 变 72，世界空间 UI
			// （主菜单按钮、Stats/Achievements 页）整体缩成 0.6 倍且与背景错位。
			uiCamera.orthographicSize = 3;
			uiCameraObject.tag = "MainCamera";
			sceneController.uiCamera = uiCamera;
			var uiCameraLimiter = attach(child(mainScene, "UICameraLimiter"), new CameraLimiter());
			uiCameraLimiter._camera = uiCamera;
			sceneController.uiCameraLimiter = uiCameraLimiter;
			// #endregion

			// #region 页面（对应 MainScene.prefab 下各页面 prefab 实例）
			var splash = page(mainScene, "Splash", new SplashController());
			var titlescreen = page(mainScene, "Titlescreen", new TitlescreenController());
			var mainmenu = page(mainScene, "Mainmenu", new MainmenuController());
			var note = page(mainScene, "Note", new NoteController());
			var map = page(mainScene, "Map", new MapController());
			var almanac = page(mainScene, "Almanac", new AlmanacController());
			var store = page(mainScene, "Store", new StoreController());
			var archive = page(mainScene, "Archive", new ArchiveController());
			var addons = page(mainScene, "Addons", new AddonsController());
			var musicRoom = page(mainScene, "MusicRoom", new MusicRoomController());
			var arcade = page(mainScene, "Arcade", new ArcadeController());
			sceneController.splash = splash.component;
			sceneController.titlescreen = titlescreen.component;
			sceneController.mainmenu = mainmenu.component;
			sceneController.note = note.component;
			sceneController.map = map.component;
			sceneController.almanac = almanac.component;
			sceneController.store = store.component;
			sceneController.archive = archive.component;
			sceneController.addons = addons.component;
			sceneController.musicRoom = musicRoom.component;
			sceneController.arcade = arcade.component;

			var portal = page(mainScene, "Portal", new PortalController());
			var chapterTransition = page(mainScene, "ChapterTransition", new ChapterTransitionController());
			var keybinding = page(mainScene, "Keybinding", new KeybindingController());
			var credits = page(mainScene, "Credits", new CreditsController());
			var achievementHint = page(mainScene, "AchievementHint", new AchievementHintController());
			var popup = page(mainScene, "Popup", new PopupController());
			var fpsDisplayer = pageRect(mainScene, "FPSDisplayer", new FPSDisplayer());
			var debugConsole = page(mainScene, "DebugConsole", new DebugConsoleController());
			var inputNameDialog = page(mainScene, "InputNameDialog", new InputNameDialogController());
			var deleteUserDialog = page(mainScene, "DeleteUserDialog", new DeleteUserDialogController());
			// PORT-NOTE: 这两个控制器的 ui（InputNameDialog / DeleteUserDialog 组件）是
			// [SerializeField] 引用，由 MainGame.prefab 注入各自 prefab 实例。缺了它，
			// GameEntrance.CheckSaveDataStatus（存档损坏分支）调用 ShowInputNameDialogAsync /
			// ShowDeleteUserDialogAsync 时会在 controller.ui.ResetPosition() 处空引用。
			inputNameDialog.component.ui = buildInputNameDialog(dialogsObject);
			deleteUserDialog.component.ui = buildDeleteUserDialog(dialogsObject);
			// PORT-NOTE: 同 `ui.dialog` —— 这两个对话框子树也要分发 Awake，
			// 否则确认/取消/删除按钮的监听器不会挂上（见上面对 Dialog 子树的说明）。
			dispatchPageAwakes({gameObject: inputNameDialog.component.ui.gameObject, component: inputNameDialog.component.ui});
			dispatchPageAwakes({gameObject: deleteUserDialog.component.ui.gameObject, component: deleteUserDialog.component.ui});
			sceneController.portal = portal.component;
			sceneController.chapterTransition = chapterTransition.component;
			sceneController.keybinding = keybinding.component;
			sceneController.credits = credits.component;
			sceneController.achievementHint = achievementHint.component;
			sceneController.popup = popup.component;
			sceneController.fpsDisplayer = fpsDisplayer.component;
			// PORT-NOTE: 对应 MainGame.prefab 里 FPSDisplayer 节点的序列化引用：
			// rectTransform = 自身 RectTransform（anchor/pivot 都是 (1,0)），
			// fpsText = 子对象 "Text" 上的 TextMeshProUGUI。
			// PerformanceManager.Update 每秒**无条件**调用 Main.Scene.SetFPS →
			// FPSDisplayer.SetFPS → fpsText.text，缺这两个引用在 hxcpp 上就是空指针崩溃。
			fpsDisplayer.component.rectTransform = cast fpsDisplayer.gameObject.transform;
			// MainGame.prefab 中 FPSDisplayer 的 RectTransform 序列化值。
			fpsDisplayer.component.rectTransform.anchorMin = new Vector2(1, 0);
			fpsDisplayer.component.rectTransform.anchorMax = new Vector2(1, 0);
			fpsDisplayer.component.rectTransform.anchoredPosition = new Vector2(0, 0);
			fpsDisplayer.component.rectTransform.sizeDelta = new Vector2(54.41, 14);
			fpsDisplayer.component.rectTransform.pivot = new Vector2(1, 0);
			var fpsTextObject = childRect(fpsDisplayer.gameObject, "Text");
			fpsDisplayer.component.fpsText = attach(fpsTextObject, new TextMeshProUGUI());
			sceneController.debugConsole = debugConsole.component;
			sceneController.inputNameDialog = inputNameDialog.component;
			sceneController.deleteUserDialog = deleteUserDialog.component;
			// PORT-NOTE: MainSceneController.Init() 会对 achievementHint 调用 SetActive(true)，
			// 说明它在 prefab 中默认激活（且不在 pages 表里）。
			achievementHint.gameObject.SetActive(true);
			// #endregion

			// PORT-NOTE: MainManager.scene 在 C# 里是 [SerializeField]，由 MainManager.prefab 注入
			// 同一场景中的 MainSceneController（Assets/Scripts/MVZ2/Managers/MainManager.cs:433）。
			// 移植层无处注入，须在场景子树建好后补上，否则 Main.Scene.* 系列调用（如
			// PerformanceManager.UpdateFPSMode 里的 Main.Scene.SetFPSEnabled）会空引用。
			mainManager.scene = sceneController;

			awakeStep("MainSceneController", () -> sceneController.Awake());
			awakeStep("MainSceneUI", () -> ui.Awake());
				@:privateAccess {
					var titlescreenUI = titlescreen.gameObject.GetComponent(TitlescreenUI);
					if (titlescreenUI != null)
						titlescreen.component.ui = titlescreenUI;
				}
			// PORT-NOTE: **点击链路的真实阻断点就在这里。**
			//
			// Unity 在加载场景时对**每个**组件的 Awake 各调用一次；按钮的点击回调正是在
			// Awake 里订阅的（`TitlescreenUI.Awake` 里 `button.onClick.AddListener(...)`、
			// `MainmenuUI.Awake` 里 `button.OnClick.add(...)`、各页面的 `ui.On*Click.add(...)`）。
			// 原先这里只对 MainmenuUI/MainmenuController/AchievementHintController 三个组件分发
			// Awake，其余页面（Titlescreen/Map/Store/Archive/MusicRoom/Arcade/Note/Addons/
			// Almanac/DebugConsole/三个对话框）的 Awake **从未执行** —— 于是它们的按钮即使被命中、
			// `OnPointerClick` 也被派发，信号上也没有任何监听者，表现为「按钮点了没反应」。
			// 更危险的是 `MainmenuButton.Awake`（`cursorHandler = GetComponent(CursorHandler)`）
			// 也从未执行，而 `MainmenuController.Display` 会对每个按钮写 `Interactable`，
			// 该 setter 直接解引用 `cursorHandler` —— release 构建下就是直接访问违例。
			//
			// 为什么现在可以安全分发（原先跳过是怕 hxcpp 空指针直接访问违例）：
			//   `page()` 已经把每个页面的 prefab 数据经 `ScenePrefabLoader.InstantiateInto`
			//   注入完成，页面树的 `[SerializeField]` 引用（`ui`、各按钮、各对话框、各子控件）
			//   都由数据接好了。用 `tools_build/_page_awake_nullrisk.py` 逐页核对过：
			//   16 个页面的整棵子树里**没有任何一个**存在「字段为 null 且 Awake 正文解引用它」
			//   的真实风险（脚本报出的 8 处均为安全用法：`dict.set(k, null)`、
			//   `linkID != null ? ... : ...` 三元保护、`if (UnityObject.exists(model))` 判空；
			//   `_page_awake_risk.py` 另确认这些 Awake 不访问 Global./管理器单例，
			//   因此不依赖 awakeAll 之后的初始化顺序）。
			//
			// 分发范围 = 页面根 + 整棵子树（`dispatchPageAwakes`）：按钮组件既可能在根上
			//（Titlescreen 的 StartButton 由根上的 TitlescreenUI 订阅），也可能在子节点上
			//（`LanguageDialog.Awake`、`UserManageDialog.Awake`、`ElementList.Awake`、
			// `MainmenuButton.Awake`），Unity 对两者一视同仁。
			//
			// PORT-NOTE: **不要**再对同一棵树单独 `awakeStep` 一次 —— Awake 重复执行会让
			// 信号订阅翻倍（按钮点一次触发两次回调）。下面每个页面只登记一次。
			dispatchPageAwakes(titlescreen);
			dispatchPageAwakes(splash);
			dispatchPageAwakes(mainmenu);
			dispatchPageAwakes(note);
			dispatchPageAwakes(map);
			dispatchPageAwakes(almanac);
			dispatchPageAwakes(store);
			dispatchPageAwakes(archive);
			dispatchPageAwakes(addons);
			dispatchPageAwakes(musicRoom);
			dispatchPageAwakes(arcade);
			dispatchPageAwakes(credits);
			dispatchPageAwakes(debugConsole);
			dispatchPageAwakes(inputNameDialog);
			dispatchPageAwakes(deleteUserDialog);
			dispatchPageAwakes(chapterTransition);
			dispatchPageAwakes(achievementHint);

			updateStep("MainSceneController", mainScene, () -> sceneController.Update());
			updateStep("TitlescreenController", titlescreen.gameObject, () -> titlescreen.component.Update());
			updateStep("MainmenuController", mainmenu.gameObject, () -> mainmenu.component.Update());
			updateStep("MapController", map.gameObject, () -> map.component.Update());
			updateStep("StoreController", store.gameObject, () -> store.component.Update());
			updateStep("ArchiveController", archive.gameObject, () -> archive.component.Update());
			updateStep("MusicRoomController", musicRoom.gameObject, () -> musicRoom.component.Update());
			updateStep("PortalController", portal.gameObject, () -> portal.component.Update());
			updateStep("KeybindingController", keybinding.gameObject, () -> keybinding.component.Update());
			updateStep("AchievementHintController", achievementHint.gameObject, () -> achievementHint.component.Update());
			updateStep("DebugConsoleController", debugConsole.gameObject, () -> debugConsole.component.Update());
		}
	}

	/** 对应 Main.unity 里加在 MainGame 对象上的 GameEntrance / GameUpdater 组件。 */
	private function buildGameEntrance():Void {
		@:privateAccess {
			entrance = attach(root, new GameEntrance());
			entrance.main = mainManager;
			entrance.loadingText = child(root, "Loading");

			updater = attach(root, new GameUpdater());
			updater.main = mainManager;
			// Main.unity 中 GameUpdater 的序列化值：logicTicksPerSeconds = 30, maxUpdateTimePerFrame = 1
			updater.logicTicksPerSeconds = 30;
			updater.maxUpdateTimePerFrame = 1;
			updateStep("GameUpdater", root, () -> updater.Update());
		}
	}
	// #endregion

	// #region 构建辅助
	/**
	 * 对应 Assets/Prefabs/UI/Dialogs/CustomDialog.prefab 的实例（MainGame.prefab 里挂在 UI 下的
	 * "Dialogs/CustomDialog"）。层级与序列化引用逐条对照 prefab：
	 *
	 *   CustomDialog            (CustomDialog, 根 RectTransform)
	 *     Blocker               (Image)
	 *     Root                  (RectTransform; dialogTransform = 自身)
	 *       Background          (Image)
	 *       TitleArea           (RectTransform)
	 *         RaycastBox        (Image)
	 *         Title             (TextMeshProUGUI; CustomDialog.title)
	 *       Desc                (TextMeshProUGUI; CustomDialog.desc)
	 *       Buttons             (ElementListUI; CustomDialog.buttonRowList)
	 *         ButtonRow         (RectTransform + ElementList + ButtonRow; _template)
	 *           TextButton      (TextButton; ElementList._template)
	 *             Text          (TextMeshProUGUI; TextButton.text)
	 *
	 * PORT-NOTE: 只重建启动期（对话框显示/选择）真的会走到的组件与引用：
	 *   * ElementListUI._listRoot / _template、ElementList._listRoot / _template、ButtonRow.buttonList、
	 *     TextButton.text/button —— 缺任何一个，ShowDialog 的 updateList 链路都会空引用；
	 *   * TextButton 的 Text 子对象与 Button 组件在 prefab 里是各自独立的组件，这里同样分开挂。
	 * 纯视觉组件（Image/CanvasRenderer/LayoutGroup/DragMover/CursorHandler）在移植层是逻辑 shim，
	 * 挂上不改变行为，为保持 1:1 结构仍一并挂载。
	 */
	private function buildDialog(dialogs:GameObject):CustomDialog {
		@:privateAccess {
			var dialogObject = childRect(dialogs, "CustomDialog");
			var dialog = attach(dialogObject, new CustomDialog());
			// PORT-NOTE: 子节点与 [SerializeField] 引用改由 prefab 数据重建（见 §对话框 prefab 注入）。
			// 原先是手写对象图：数据里明明有 `sprite`（`mvz2:init/form` 等），手写图却从不写它，
			// 于是所有 `Image` 都退化成 1×1 白块（黑屏报告 §4）。
			if (injectDialogPrefab(dialogObject, "Prefabs/UI/Dialogs/CustomDialog"))
				return dialog;

			// CustomDialog.prefab: Blocker（全屏遮罩，Image）
			var blocker = childRect(dialogObject, "Blocker");
			attach(blocker, new Image());

			// Root 自身就是 dialogTransform（CustomDialog.prefab 的 dialogTransform 指向 Root 的 RectTransform）
			var dialogRoot = childRect(dialogObject, "Root");
			dialog.dialogTransform = cast dialogRoot.transform;

			var background = childRect(dialogRoot, "Background");
			attach(background, new Image());

			var titleArea = childRect(dialogRoot, "TitleArea");
			attach(childRect(titleArea, "RaycastBox"), new Image());
			var titleObject = childRect(titleArea, "Title");
			dialog.title = attach(titleObject, new TextMeshProUGUI());

			var descObject = childRect(dialogRoot, "Desc");
			dialog.desc = attach(descObject, new TextMeshProUGUI());

			// Buttons 节点上同时挂 ElementListUI（CustomDialog.buttonRowList）与布局组。
			var buttons = childRect(dialogRoot, "Buttons");
			var buttonRowList = attach(buttons, new ElementListUI());
			buttonRowList._listRoot = cast buttons.transform;
			dialog.buttonRowList = buttonRowList;

			// ButtonRow 是 ElementListUI 的模板项：节点自身是 RectTransform + ElementList + ButtonRow。
			var buttonRowObject = childRect(buttons, "ButtonRow");
			buttonRowList._template = cast buttonRowObject.transform;
			var elementList = attach(buttonRowObject, new ElementList());
			elementList._listRoot = cast buttonRowObject.transform;
			var buttonRow = attach(buttonRowObject, new ButtonRow());
			buttonRow.buttonList = elementList;

			// TextButton 是 ElementList 的模板项。
			var textButtonObject = childRect(buttonRowObject, "TextButton");
			elementList._template = textButtonObject;
			var textButton = attach(textButtonObject, new TextButton());
			var textButtonTextObject = childRect(textButtonObject, "Text");
			textButton.text = attach(textButtonTextObject, new TextMeshProUGUI());
			textButton.button = attach(textButtonObject, new Button());

			return dialog;
		}
	}

	/**
	 * 对应 Assets/Prefabs/UI/Dialogs/InputNameDialog.prefab。MainGame.prefab 把它的实例挂在
	 * UI 下的 "Dialogs" 里（fileID 9120389176242846396 的 InputNameDialogController.ui 指向它）。
	 *
	 *   InputNameDialog        (InputNameDialog)
	 *     Blocker              (Image)
	 *     Dialog               (RectTransform; dialogTransform = 自身)
	 *       Background         (Image)
	 *       TitleArea          (RectTransform)
	 *         RaycastBox       (Image)
	 *         Title            (TextMeshProUGUI)
	 *       ErrorMessageArea   (RectTransform)
	 *         ErrorMessage     (TextMeshProUGUI; InputNameDialog.errorMessage)
	 *       InputField         (TMP_InputField; InputNameDialog.inputField)
	 *       Buttons            (RectTransform)
	 *         Confirm          (TextButton + Button; InputNameDialog.confirmButton)
	 *         Cancel           (TextButton + Button; InputNameDialog.cancelButton)
	 *
	 * PORT-NOTE: prefab 里 Confirm/Cancel 是 TextButton.prefab 的实例，其 Button 组件挂在
	 * TextButton 节点自身（见 InputNameDialog.prefab 里 m_PrefabInstance 指向 TextButton 的
	 * m_Script: ddcdd2fcc671d3646a8c49fe2ebca01c）。InputNameDialog.confirmButton/cancelButton
	 * 的类型是 UnityEngine.UI.Button，因此这里给的是节点上的 Button 组件。
	 * InputNameDialog.Awake 会给这两个按钮挂监听、并在 OnConfirm 时读 inputField.text。
	 */
	private function buildInputNameDialog(dialogs:GameObject):InputNameDialog {
		@:privateAccess {
			var dialogObject = childRect(dialogs, "InputNameDialog");
			var dialog = attach(dialogObject, new InputNameDialog());
			// PORT-NOTE: 同 buildDialog —— 子节点与序列化引用（含 Image.sprite）改由 prefab 数据重建。
			if (injectDialogPrefab(dialogObject, "Prefabs/UI/Dialogs/InputNameDialog"))
				return dialog;

			attach(childRect(dialogObject, "Blocker"), new Image());

			var dialogRoot = childRect(dialogObject, "Dialog");
			dialog.dialogTransform = cast dialogRoot.transform;
			attach(childRect(dialogRoot, "Background"), new Image());

			var titleArea = childRect(dialogRoot, "TitleArea");
			attach(childRect(titleArea, "RaycastBox"), new Image());
			attach(childRect(titleArea, "Title"), new TextMeshProUGUI());

			var errorArea = childRect(dialogRoot, "ErrorMessageArea");
			var errorObject = childRect(errorArea, "ErrorMessage");
			dialog.errorMessage = attach(errorObject, new TextMeshProUGUI());

			var inputFieldObject = childRect(dialogRoot, "InputField");
			dialog.inputField = attach(inputFieldObject, new TMP_InputField());

			var buttons = childRect(dialogRoot, "Buttons");
			var confirmObject = childRect(buttons, "Confirm");
			attach(confirmObject, new TextButton());
			dialog.confirmButton = attach(confirmObject, new Button());
			var cancelObject = childRect(buttons, "Cancel");
			attach(cancelObject, new TextButton());
			dialog.cancelButton = attach(cancelObject, new Button());

			return dialog;
		}
	}

	/**
	 * 对应 Assets/Prefabs/UI/Dialogs/DeleteUserDialog.prefab（fileID 4682724205504364421 的
	 * DeleteUserDialogController.ui）。
	 *
	 *   DeleteUserDialog       (DeleteUserDialog)
	 *     Blocker              (Image)
	 *     Dialog               (RectTransform; dialogTransform = 自身)
	 *       Background         (Image)
	 *       TitleArea          (RectTransform)
	 *         RaycastBox       (Image)
	 *         Title            (TextMeshProUGUI)
	 *       MainElements       (RectTransform)
	 *         UserManageList   (UserManageList; DeleteUserDialog.userList)
	 *           UserManageItem (UserManageItem; 模板项)
	 *             Name         (TextMeshProUGUI; UserManageItem.nameText)
	 *             Toggle       (Toggle; UserManageItem.toggle)
	 *         Space            (RectTransform)
	 *         Buttons          (RectTransform)
	 *           Delete         (TextButton + Button; DeleteUserDialog.deleteButton)
	 *
	 * PORT-NOTE: UserManageList.userList 是 ElementListUI，_template 指向 UserManageItem 节点；
	 * DeleteUserDialogController.Show 会 ui.UpdateUsers → UserManageList.UpdateUsers →
	 * userList.updateList（ItemListUI 的 CreateItem 走 UnityObject.Instantiate 深拷贝模板，
	 * 由本轮补上的克隆实现保证模板上的 UserManageItem 组件被复制）。
	 */
	private function buildDeleteUserDialog(dialogs:GameObject):DeleteUserDialog {
		@:privateAccess {
			var dialogObject = childRect(dialogs, "DeleteUserDialog");
			var dialog = attach(dialogObject, new DeleteUserDialog());
			// PORT-NOTE: 同 buildDialog —— 子节点与序列化引用（含 Image.sprite）改由 prefab 数据重建。
			if (injectDialogPrefab(dialogObject, "Prefabs/UI/Dialogs/DeleteUserDialog"))
				return dialog;

			attach(childRect(dialogObject, "Blocker"), new Image());

			var dialogRoot = childRect(dialogObject, "Dialog");
			dialog.dialogTransform = cast dialogRoot.transform;
			attach(childRect(dialogRoot, "Background"), new Image());

			var titleArea = childRect(dialogRoot, "TitleArea");
			attach(childRect(titleArea, "RaycastBox"), new Image());
			attach(childRect(titleArea, "Title"), new TextMeshProUGUI());

			var mainElements = childRect(dialogRoot, "MainElements");
			var listObject = childRect(mainElements, "UserManageList");
			var userList = attach(listObject, new UserManageList());
			var list = attach(listObject, new ElementListUI());
			list._listRoot = cast listObject.transform;
			userList.userList = list;

			var itemObject = childRect(listObject, "UserManageItem");
			list._template = cast itemObject.transform;
			var item = attach(itemObject, new UserManageItem());
			var itemNameObject = childRect(itemObject, "Name");
			item.nameText = attach(itemNameObject, new TextMeshProUGUI());
			item.toggle = attach(itemObject, new Toggle());

			childRect(mainElements, "Space");

			var buttons = childRect(mainElements, "Buttons");
			var deleteObject = childRect(buttons, "Delete");
			attach(deleteObject, new TextButton());
			dialog.deleteButton = attach(deleteObject, new Button());

			return dialog;
		}
	}

	/**
	 * 把对话框的 prefab 数据接进手工构造的对话框对象图。
	 *
	 * PORT-NOTE: 与 `InjectPagePrefab` 同一机制（`ScenePrefabLoader.InstantiateInto` 的
	 * 根对象接管模式）：对话框根节点保留这里 `new` 出来的组件（`MainSceneUI.dialog` 等
	 * 已持有该引用），子节点与全部 `[SerializeField]` 字段由数据补齐。
	 *
	 * 为什么必须走数据：手写对象图只挂了组件、**从不写序列化字段**，于是
	 *   * `Image.sprite` 恒为 null → `UiRenderer.updateGraphic` 走 `applySolid()`，
	 *     所有面板退化成 1×1 白块（黑屏报告 §4.2 的实测现象）；
	 *   * `RectTransform` 的 anchor/pivot/sizeDelta 全是零 → 位置与尺寸都不对；
	 *   * `TextButton` 的 `text`/`button`、`ElementListUI._template` 等引用也不对。
	 *
	 * 返回 true 表示数据已接管（调用方应跳过手写回退路径）。
	 * 数据缺失（未运行 `build_scene.py`）时返回 false，退回手写对象图，保持启动可用。
	 */
	private function injectDialogPrefab(dialogObject:GameObject, key:String):Bool {
		var written = ScenePrefabLoader.InstantiateInto(key, dialogObject, null, false);
		if (written < 0) {
			prefabInjectionFailures.push('$key');
			return false;
		}
		prefabInjectionFields += written;
		return true;
	}

	private function child(parent:GameObject, name:String):GameObject {
		var go = new GameObject(name);
		go.transform.SetParent(parent.transform, false);
		return go;
	}

	// PORT-NOTE: prefab 里 UI 节点的 transform 是 RectTransform（带 anchor/pivot/sizeDelta），
	// child()/page() 给的是普通 Transform。这里提供 RectTransform 版本：先换掉 GameObject 上
	// 那个还没挂到任何父级的默认 Transform，再 SetParent，保证父级 children 表里存的是新实例。
	private function childRect(parent:GameObject, name:String):GameObject {
		var go = new GameObject(name);
		var rect = new RectTransform();
		rect.gameObject = go;
		go.transform = rect;
		rect.SetParent(parent.transform, false);
		return go;
	}

	// PORT-NOTE: unity.GameObject.AddComponent 内部用 Type.createInstance 反射构造组件；
	// 移植层改用显式 new + 这里的手工登记（等价于 AddComponent 的 gameObject/transform 赋值
	// 与组件表注册），避免依赖运行期反射与 DCE 行为。
	private function attach<T:Component>(parent:GameObject, component:T):T {
		@:privateAccess {
			component.gameObject = parent;
			component.transform = parent.transform;
			parent.components.push(component);
		}
		if (Std.isOfType(component, MonoBehaviour))
			behaviours.push(cast component);
		// PORT-NOTE: 与 `GameObject.AddComponent` 保持一致 —— 手工 `new` + 登记的路径
		// 也必须把 SpriteRenderer 交给渲染桥，否则这些渲染器的
		// visible/scale/angle 永远不同步（`RenderBridge` 是按登记表逐帧同步的）。
		// 实测缺口：`MainGameScene` 手写的对象图（`buildDialog` 等）里如果有 SpriteRenderer，
		// 就会绕过 AddComponent 的登记点。
		if (Std.isOfType(component, unity.SpriteRenderer))
			unity.RenderBridge.registerRenderer(cast component);
		return component;
	}

	private function page<T:MonoBehaviour>(parent:GameObject, name:String, component:T):PageHandle<T> {
		var go = child(parent, name);
		// PORT-NOTE: prefab 中各页面默认处于未激活状态，由 MainSceneController.DisplayPage 切换。
		go.SetActive(false);
		// PORT-NOTE: 页面根的 `[SerializeField]` 引用由下面的 `InjectPagePrefab` 从 prefab 数据补齐，
		// Awake 由 `dispatchPageAwakes` 统一登记（见 buildMainScene 里对「点击链路阻断点」的说明）。
		// 这里不再把页面记进 `skippedAwake` —— 它们**已经**会被分发 Awake，留在那份列表里会
		// 让启动日志继续声称"跳过"，与事实不符。
		var handle = {gameObject: go, component: attach(go, component)};
		// PORT-NOTE: 页面根的组件（MapController / AlmanacController…）在这里手工 new，
		// 它们的 [SerializeField] 引用（mapCamera 等）必须由 prefab 数据注入，否则运行期空引用
		//（release 无空指针检查 → 直接访问违例）。`InjectPagePrefab` 按数据重建子节点并把字段
		// 写到这些手工组件上 —— 等价于 Unity 用 prefab 覆盖场景里已存在的对象。
		InjectPagePrefab(go, name);
		return handle;
	}

	/** page() 的 RectTransform 版本（prefab 中该页面节点的 transform 是 RectTransform）。 */
	private function pageRect<T:MonoBehaviour>(parent:GameObject, name:String, component:T):PageHandle<T> {
		var go = childRect(parent, name);
		go.SetActive(false);
		var handle = {gameObject: go, component: attach(go, component)};
		InjectPagePrefab(go, name);
		return handle;
	}

	/**
	 * 页面名 -> 导出数据 key（`Assets/Prefabs/**` 里对应 prefab 的路径去扩展名）。
	 *
	 * PORT-NOTE: 名称映射取自 `Assets/Prefabs/MainGame.prefab` 里各页面的 PrefabInstance 源：
	 *   Map/Map、Almanac/Almanac、Store/Store、Archive/Archive、Addons/Addons、
	 *   MusicRoom/MusicRoom、Arcade/Arcade、Init/Splash、Init/Titlescreen、Mainmenu/Mainmenu、
	 *   ChapterTransition、Note、Level/UI/DebugConsole、Mainmenu/Credits、UI/AchievementHint。
	 * 未列出的页面（Portal/Popup/Keybinding 等）在移植层是纯逻辑占位，没有对应数据。
	 */
	private static var PAGE_PREFABS:Map<String, String> = [
		"Map" => "Prefabs/Map/Map",
		"Almanac" => "Prefabs/Almanac/Almanac",
		"Store" => "Prefabs/Store/Store",
		"Archive" => "Prefabs/Archive/Archive",
		"Addons" => "Prefabs/Addons/Addons",
		"MusicRoom" => "Prefabs/MusicRoom/MusicRoom",
		"Arcade" => "Prefabs/Arcade/Arcade",
		"Splash" => "Prefabs/Init/Splash",
		"Titlescreen" => "Prefabs/Init/Titlescreen",
		"Mainmenu" => "Prefabs/Mainmenu/Mainmenu",
		"ChapterTransition" => "Prefabs/ChapterTransition",
		"Note" => "Prefabs/Note",
		"DebugConsole" => "Prefabs/Level/UI/DebugConsole",
		"Credits" => "Prefabs/Mainmenu/Credits",
		"AchievementHint" => "Prefabs/UI/AchievementHint",
		// PORT-NOTE: 三个对话框也必须走同一条 prefab 注入路径。
		// 它们原先由 `buildDialog()` / `buildInputNameDialog()` / `buildDeleteUserDialog()` **手工**
		// 建对象图（只挂组件、不写序列化字段），于是 `Image.sprite` 恒为 null —— 渲染层
		//（`mvz2/ui/UiRenderer.hx`）只能退化成 1×1 白图拉伸，画面上的对话框就是几个白块。
		// 数据是齐的（`assets/scene_prefabs/Prefabs/UI/Dialogs/*.json` 里 Image 带真实 sprite），
		// 因此把根节点交给 `InstantiateInto` 的「接管模式」重建整棵子树并写字段。
		"CustomDialog" => "Prefabs/UI/Dialogs/CustomDialog",
		"InputNameDialog" => "Prefabs/UI/Dialogs/InputNameDialog",
		"DeleteUserDialog" => "Prefabs/UI/Dialogs/DeleteUserDialog",
	];

	/**
	 * 把页面对应的 prefab 数据接进手工构造的页面对象图。
	 *
	 * PORT-NOTE: 用 `ScenePrefabLoader.InstantiateInto`（根对象接管模式）：页面根的控制器组件
	 * 保留这里 `new` 出来的实例（`MainSceneController` 持有它们的引用），子节点与
	 * `[SerializeField]` 字段由数据补齐。`callAwakeInInstantiate=false` —— Awake 仍由
	 * `awakeAll()` 按顺序统一分发（页面 Awake 依赖已初始化的管理器）。
	 */
	private function InjectPagePrefab(go:GameObject, pageName:String):Void {
		var key = PAGE_PREFABS.get(pageName);
		if (key == null)
			return;
		// PORT-NOTE: `ScenePrefabLoader` 是跨包引用，必须显式 import。
		var written = ScenePrefabLoader.InstantiateInto(key, go, null, false);
		if (written < 0) {
			prefabInjectionFailures.push('$pageName（$key）');
			BootTrace.error('页面 prefab 注入失败：$pageName（$key）');
		} else {
			prefabInjectionFields += written;
			// PORT-NOTE: 注入结果必须落盘 —— lime 的 Windows GUI 程序没有 stdout，
			// 注入是否真的把子节点/引用建出来只能靠 boot-trace 观察。
			var animators = go.GetComponentsInChildren(unity.Animator, true).length;
			// PORT-NOTE: **在这里就登记 Animator**（而不是只在 `build()` 末尾统一 addTree）。
			// 实测：末尾从 root 递归只登记到 8 个，而每个页面从自己的根递归能看到 43 个 ——
			// 说明页面子树在构建期之后与 root 的 children 链不再连通（uGUI 渲染桥接管了层级）。
			// 在注入点登记不依赖 root 的可达性，且此时子树刚建好、层级最完整。
			animatorUpdater.addTree(go);
			BootTrace.step('页面 prefab 注入：$pageName（$key）写入 $written 个字段，Animator=$animators'
				+ '（累计登记 ${animatorUpdater.count} 个）');
		}
	}

	/** 数据未转换 / 实例化失败的页面（诊断用）。 */
	public var prefabInjectionFailures(default, null):Array<String> = [];
	/** 页面 prefab 数据累计写入的字段数（诊断用）。 */
	public var prefabInjectionFields(default, null):Int = 0;

	/**
	 * 把一个页面根**及其全部子树组件**的 Awake 登记进启动分发表（对应 Unity 加载场景时的全树 Awake）。
	 *
	 * PORT-NOTE: 为什么不直接把页面根加入 `awakeStep`：页面的按钮回调不只挂在根上 ——
	 * `TitlescreenUI.Awake` 订阅的是根上的 Button，但 `LanguageDialog.Awake`、`UserManageDialog.Awake`、
	 * `ElementList.Awake` 等在**子节点**上，它们同样在 Awake 里订阅/转发信号。
	 * Unity 对这些组件各调一次 Awake，因此这里按同一语义递归整棵子树。
	 *
	 * PORT-NOTE: 单个组件的 Awake 用 try/catch 隔离（与 `awakeAll` 的逐项隔离一致）。
	 * 注意：release 构建下**空引用不是 Haxe 异常**（没有 HXCPP_CHECK_POINTER），
	 * try/catch 抓不到；这也是为什么先做了「无 null 解引用」的静态核对
	 *（见调用点上方说明与 `tools_build/_page_awake_nullrisk.py`），
	 * 而不是指望这层 try/catch 兜住空指针。
	 */
	private function dispatchPageAwakes(handle:PageHandle<Dynamic>):Void {
		if (handle == null || handle.gameObject == null)
			return;
		var pending:Array<GameObject> = [handle.gameObject];
		var guard = 0;
		while (pending.length > 0 && guard++ < 4096) {
			var go = pending.shift();
			if (go == null || go.destroyed)
				continue;
			for (comp in go.GetAllComponents()) {
				if (comp == null || comp.destroyed)
					continue;
				var fn:Dynamic = Reflect.field(comp, "Awake");
				if (fn == null || !Reflect.isFunction(fn))
					continue;
				// PORT-NOTE: 这里原先按类名跳过 `mvz2.ui.OptionsDialogMainPage`——当时它的 Awake
				// 会直接解引用未注入的 musicSlider / fastForwardSlider / pauseOnFocusLostToggle，
				// 在 hxcpp 上触发访问违例。该 Awake 现已改成逐项判空后再登记字典（缺失引用只是
				// 不参与事件分发），不再需要跳过，恢复正常派发。
				// PORT-NOTE: 闭包必须捕获 `comp` 的**当前值**，故先绑定到局部变量再登记。
				var target = comp;
				var label = '${Type.getClassName(Type.getClass(target))}@${go.name}';
				awakeStep(label, () -> Reflect.callMethod(target, Reflect.field(target, "Awake"), []));
			}
			for (child in go.transform.children) {
				if (child == null || child.gameObject == null)
					continue;
				pending.push(child.gameObject);
			}
		}
	}

	private function awakeStep(name:String, run:Void->Void):Void {
		awakeSteps.push({name: name, run: run});
	}

	private function updateStep(name:String, gameObject:GameObject, run:Void->Void):Void {
		updateSteps.push({name: name, gameObject: gameObject, run: run, enabled: true});
	}

	private var awakeSteps:Array<AwakeStep> = [];
	private var updateSteps:Array<UpdateStep> = [];
	// #endregion
}

typedef AwakeStep = {name:String, run:Void->Void};
typedef UpdateStep = {name:String, gameObject:GameObject, run:Void->Void, enabled:Bool};
typedef PageHandle<T> = {gameObject:GameObject, component:T};

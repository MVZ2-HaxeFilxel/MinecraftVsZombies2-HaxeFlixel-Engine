// Ported from: (新增文件) uGUI（UnityEngine.UI / TMPro）→ Flixel 显示列表的渲染桥
package mvz2.ui;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import mvz2.sprites.SpriteFrameFactory;
import mvz2.sprites.SpriteManifestData;
import mvz2.sprites.SpriteManifestLoader;
import unity.Canvas;
import unity.Canvas.RenderMode;
import unity.CanvasGroup;
import unity.Collider2D;
import unity.Component;
import unity.BoxCollider2D;
import unity.CapsuleCollider2D;
import unity.CircleCollider2D;
import unity.GameObject;
import unity.PolygonCollider2D;
import unity.RectTransform;
import unity.SortingLayer;
import unity.SpriteRenderer;
import unity.Transform;
import unity.Vector2;
import unity.Vector3;
import unity.ui.CanvasScaler;
import unity.ui.CanvasScaler.ScaleMode;
import unity.ui.CanvasScaler.ScreenMatchMode;
import unity.ui.HorizontalOrVerticalLayoutGroup.AspectMode;
import unity.ui.HorizontalOrVerticalLayoutGroup.AspectRatioFitter;
import unity.ui.LayoutRebuilder;
import unity.ui.Button;
import unity.ui.Graphic;
import unity.ui.Image;
import unity.ui.Mask;
import unity.ui.RawImage;
import unity.ui.Text;
import unity.ui.Toggle;
import unity.eventsystems.PointerEventData;
import unity.tmpro.TextMeshProUGUI;

// PORT-NOTE: 移植层新增（无 C# 对应源码）。**这是本工作包的核心**：把 uGUI 对象图真正画出来。
//
// 背景：`source/unity/ui/*`（Graphic/Image/RawImage/Text/Button/Toggle/Slider/…）在移植层是
// **纯逻辑 shim**，`Graphic.Rebuild()` 是空实现，整包从不往 Flixel 显示列表里加任何东西。
// 因此启动链路即使全绿，画面也是纯黑。本类补上缺失的渲染职责：
//
//   1. 遍历 uGUI 树（`GameObject` + `RectTransform` + `Graphic` 组件）；
//   2. 按 Unity 的 anchor/pivot/offset 规则把 `RectTransform` 解析成**实际矩形**
//      （见 §RectTransform 解析），Canvas 根由 `CanvasScaler` 换算分辨率（见 §Canvas 换算）；
//   3. 每个可见的 `Graphic` 对应一个 FlxSprite / FlxText，作为本 FlxGroup 的成员进显示列表
//      （成员顺序 = 深度优先的层级顺序，FlxGroup 按成员顺序绘制 ⇒ 与 Unity 的绘制顺序一致）。
//
// 与 `unity.ui.Graphic` 的关系：unity 包不能反向依赖 mvz2（会成环），因此 shim 只暴露
// `Graphic.visualDirty` 钩子与 `Graphic.revision` 版本号；本类在 `install()` 里安装钩子。
// 变化检测用「全局 revision + 每项记录的重建代次」：任何会改变外观的字段被写入都会 bump
// revision，下一帧把全部项标脏重建。矩形则每帧重算（RectTransform 的字段是普通字段，
// 无法挂钩子，例如 `MainSceneUI` 只改 `anchoredPosition`）。
//
// 坐标系（关键，别搞反）：
//   * Unity RectTransform 的 rect 原点在**自身 pivot**，y 轴**向上**；子级的 anchor 相对**父级 rect**；
//   * Flixel 的原点在**左上角**，y 轴**向下**，单位是屏幕像素；
//   * 换算链：canvas 单位 --(父级 localScale 级联)--> 画布单位 --(CanvasScaler.scaleFactor)--> 屏幕像素。
//
// 已知简化（都写在报告里）：
//   * Image 只支持 Simple/Sliced/Tiled 的**拉伸到矩形**语义；Filled（fillAmount）不裁剪，
//     只按 fillAmount 做整体 alpha/尺寸近似 —— TODO-PORT。
//   * LayoutGroup（Vertical/Horizontal/Grid + ContentSizeFitter + LayoutElement）不做真实布局：
//     这些节点的子级矩形取自 prefab 里**已序列化的** anchoredPosition/sizeDelta（Unity 运行时
//     会再算一遍，移植层直接用导出值）。因此动态增删的列表项（ElementListUI.CreateItem）位置
//     可能与 Unity 不同。TODO-PORT。
//   * Mask/RectMask2D 用 FlxSprite.clipRect 做矩形裁剪，不做模板缓冲。`clipRect` 是**帧本地**
//     坐标且会被 flixel 取整（`set_clipRect` 里 `rect.round()`），因此纯色块兜底（1×1 白图拉伸到
//     矩形）上的遮罩边界最粗时会有约一个「帧像素 × 缩放」的误差 —— TODO-PORT。
//   * 世界空间 TMP 的 `enableAutoSizing` 只做「钳到 [fontSizeMin, fontSizeMax] + 不超过节点 rect
//     高度」，没有 TMP 的文本度量与二分 —— TODO-PORT。
//   * Mask 裁剪的换算按 |scale| 做，未处理 `flipX/flipY`（翻转帧上裁剪会跟着镜像）。TODO-PORT。
class UiRenderer extends FlxGroup {
	/** 全进程唯一实例（install() 建立）。 */
	public static var instance(default, null):UiRenderer = null;

	/** 需要遍历的 uGUI 根（`MainGameScene.root` 等）。 */
	private var roots:Array<GameObject> = [];
	/** GameObject -> 渲染项。 */
	private var entries:Map<GameObject, UiEntry> = new Map();
	/**
	 * GameObject -> 本帧解析出的布局帧。
	 *
	 * PORT-NOTE: 命中矩形要在遍历结束后统一解析（见 `resolveHitTargets`），
	 * 因此遍历时必须把每个节点的布局帧留一份。只保留本帧（每帧重建），不做跨帧缓存。
	 */
	private var framesByNode:Map<GameObject, LayoutFrame> = new Map();
	/** 本帧遍历到的项，顺序 = 深度优先层级顺序（即 Unity 的绘制顺序）。 */
	private var live:Array<UiEntry> = [];
	/** 被淘汰（GameObject 已销毁）的渲染项。 */
	private var graveyard:Array<UiEntry> = [];
	/** 本帧解析出的鼠标命中项（顺序 = 层级顺序，最后一个 = 最上层）。 */
	private var hitTargets:Array<HitTarget> = [];
	/**
	 * 本帧遍历时收集到的「可点击节点」候选。
	 *
	 * PORT-NOTE: 矩形在**遍历结束后**统一解析（见 resolveHitTargets）：世界空间节点的矩形
	 * 需要「子树里已渲染精灵的屏幕矩形」或「collider 的本地包围盒」，两者都要求整棵树先走完。
	 */
	private var hitCandidates:Array<HitCandidate> = [];
	/**
	 * GameObject -> 本帧**实际绘制出来**的屏幕矩形（取自渲染项的 FlxSprite 几何）。
	 *
	 * PORT-NOTE: 这是命中判定的**第一优先数据源**，也是本文件里唯一与「玩家看到的东西」
	 * 天然一致的矩形。原先命中矩形只由 `RectTransform` 的 anchor/pivot 数学推导
	 *（见 `childFrame`/`toScreenRect`），那条链在真实 prefab 上会与绘制结果分叉：
	 *   * 主菜单/地图按钮的节点根本没有 RectTransform（是普通 Transform + PolygonCollider2D
	 *     或子树里的 SpriteRenderer），数学链无从下手；
	 *   * 有 RectTransform 的节点（如标题页 StartButton）一旦推导链里任何一环与 Unity 不同，
	 *     算出的矩形就可能落到屏幕外 —— 表现为「按钮画得出来，但点不到」。
	 * 改用绘制结果后，命中区与可见区**构造上相等**，不可能再分叉。
	 */
	private var renderedRectsByNode:Map<GameObject, unity.Rect> = new Map();

	/** 诊断：本帧登记的可点击项数。 */
	public static var hitTargetCount:Int = 0;
	/** 诊断：其中挂在 `unity.ui.Button` 上的个数。 */
	public static var hitTargetButtonCount:Int = 0;
	/** 诊断：其中来自项目自定义组件（非 Button，靠 OnPointerClick 反射识别）的个数。 */
	public static var hitTargetCustomCount:Int = 0;
	/** 诊断：其中矩形取自 collider（Box/Polygon/Circle/CapsuleCollider2D）的个数。 */
	public static var hitTargetColliderCount:Int = 0;
	/** 诊断：前若干条可点击项的描述（节点路径 + 命中来源）。 */
	public static var hitTargetSamples:Array<String> = [];

	/** 诊断统计。 */
	public static var graphicCount:Int = 0;
	public static var textCount:Int = 0;
	public static var solidCount:Int = 0;
	public static var spriteRendererCount:Int = 0;
	public static var skippedCount:Int = 0;
	public static var lastError:String = null;
	/** 诊断：Image 的 sprite 字段非 null 的个数（0 = prefab 注入没把 sprite 写进去）。 */
	public static var imageWithSprite:Int = 0;
	/** 诊断：Image 有 sprite 但取不到帧（贴图没解码 / 矩形为空）的个数。 */
	public static var imageFrameFailed:Int = 0;
	/** 诊断：Image 的 sprite 为 null（走纯色兜底）的个数。 */
	public static var imageWithoutSprite:Int = 0;
	/** 诊断：前若干条「sprite 为 null 的 Image」的节点名（定位是哪个 prefab/节点）。 */
	public static var imageWithoutSpriteSamples:Array<String> = [];
	/** 诊断：前若干条「有 sprite 但取帧失败」的节点名。 */
	public static var imageFrameFailedSamples:Array<String> = [];
	/** 诊断：Graphic 挂在非 RectTransform 上（被跳过）的节点名。 */
	public static var nonRectGraphicSamples:Array<String> = [];
	/** 诊断：遇到的 Graphic 具体类名 -> 次数。 */
	public static var graphicClassCounts:Map<String, Int> = new Map();
	/** 诊断：有 RectTransform 的 Graphic 节点数。 */
	public static var rectGraphicCount:Int = 0;
	/** 诊断：updateGraphic 被调用的次数。 */
	public static var updateGraphicCalls:Int = 0;
	/** 诊断：前若干次 updateGraphic 的分类说明。 */
	public static var updateGraphicSamples:Array<String> = [];
	/** 诊断：sync() 结束时的计数快照（保证同一帧内一致，避免读取时序问题）。 */
	public static var snapshot:String = "";

	/** 复用的 1x1 白色位图（纯色 Image 的底图），避免每个纯色块各建一张。 */
	private static inline var WHITE_KEY:String = "mvz2_ui_white";

	/** 上一次同步时的 Graphic 全局 revision。 */
	private var lastRevision:Int = -1;
	/** 已同步的帧序号（用于淘汰扫描）。 */
	private var frame:Int = 0;

	/** 当前成员里 visible == true 的项数（诊断用：0 = 画面上真的什么都没有）。 */
	public var visibleCount(default, null):Int = 0;

	private function new() {
		super();
		// PORT-NOTE: 本组不是"可交互对象"，只需 update + draw。
		active = true;
		visible = true;
	}

	// #region 安装 / 注册

	/**
	 * 建立渲染桥并把 `root` 登记为遍历起点。幂等。
	 *
	 * PORT-NOTE: 必须挂在 `FlxG.state` 上（而不是 `FlxG.plugins`）：plugins 的绘制顺序由
	 * `FlxG.plugins.drawOnTop` 全局决定，会影响其它插件的绘制层；而 UI 必须永远盖在游戏画面之上
	 * （Unity 的 ScreenSpaceOverlay Canvas 语义）。挂进 FlxState 的成员表并最后添加即可。
	 */
	public static function install(root:GameObject):UiRenderer {
		Graphic.visualDirty = onVisualDirty;
		if (instance == null) {
			instance = new UiRenderer();
			if (FlxG.state != null)
				FlxG.state.add(instance);
		}
		if (root != null)
			instance.registerRoot(root);
		return instance;
	}

	/** 追加一个遍历根（可多次调用，例如关卡场景）。 */
	public function registerRoot(root:GameObject):Void {
		if (root == null || roots.indexOf(root) >= 0)
			return;
		roots.push(root);
		lastRevision = -1;
	}

	private static function onVisualDirty():Void {
		// PORT-NOTE: 这里刻意不做同步工作 —— 写入发生在游戏逻辑（Update/协程）里，
		// 而重建渲染对象必须在绘制前统一做（见 update()）。只把 revision 拉高，
		// 由下一帧的 sync() 统一重建。
	}

	// #endregion

	// #region 每帧同步

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		frame++;
		try {
			sync();
		} catch (e:Dynamic) {
			lastError = Std.string(e);
			unity.Debug.LogError('UiRenderer.sync 失败（本帧跳过 UI 同步）：$e');
		}
	}

	/** 重建/更新全部渲染项。 */
	public function sync():Void {
		if (roots.length == 0)
			return;
		var revisionChanged = lastRevision != Graphic.revision;
		lastRevision = Graphic.revision;
		live = [];
		framesByNode = new Map();
		renderedRectsByNode = new Map();
		hitTargets = [];
		hitCandidates = [];
		hitTargetCount = 0;
		hitTargetButtonCount = 0;
		hitTargetCustomCount = 0;
		hitTargetColliderCount = 0;
		if (hitTargetSamples.length > 0) hitTargetSamples = [];
		graphicCount = 0;
		textCount = 0;
		solidCount = 0;
		spriteRendererCount = 0;
		skippedCount = 0;
		imageWithSprite = 0;
		imageFrameFailed = 0;
		imageWithoutSprite = 0;
		if (imageWithoutSpriteSamples.length > 0) imageWithoutSpriteSamples = [];
		if (imageFrameFailedSamples.length > 0) imageFrameFailedSamples = [];
		if (nonRectGraphicSamples.length > 0) nonRectGraphicSamples = [];
		graphicClassCounts = new Map();
		rectGraphicCount = 0;
		updateGraphicCalls = 0;
		if (updateGraphicSamples.length > 0) updateGraphicSamples = [];

		for (root in roots) {
			if (root == null)
				continue;
			// MVZ2-DEBUG-LAYOUT
			// PORT-NOTE: 布局引擎（unity.ui.LayoutRebuilder）必须在遍历**之前**跑：
			// 受 LayoutGroup/ContentSizeFitter 控制的节点，其 anchoredPosition/sizeDelta 在
			// prefab 里是序列化残留（常为 0），由本调用在运行期算出并写回 RectTransform，
			// 下面的 walk 再按新值解析屏幕矩形（与 Unity「布局先行、渲染在后」同序）。
			LayoutRebuilder.rebuild(root);
			var canvas = findCanvas(root);
			if (canvas != null) {
				walkCanvas(canvas, root);
			} else {
				// PORT-NOTE: 没有 Canvas 时仍按"画布 = 整个屏幕"处理，让手工构造的对象图
				// （`MainGameScene.buildDialog` 等只 `new Image()`、没挂 Canvas 的 UI）也能画出来。
				// 此时 scaleFactor **沿父链向上找最近的 CanvasScaler 继承**（Unity 语义：嵌套 Canvas
				// 不重置缩放），父链确实没有（如手工建在 `MainGame/MainScene/UI` 下的对话框树 ——
				// 该 "UI" 节点是 GlobalUICanvas 的替身但没挂 Canvas/CanvasScaler）才落 1。
				// TODO-PORT: 若后续给该节点补上 Canvas+CanvasScaler（或整棵树改由 prefab 数据重建），
				// 这里会自动取到 GlobalUICanvas 的 1.6，无需再改本文件。
				// PORT-NOTE: overlayRank=1 —— 这些无画布的手工 UI（对话框一类）语义上是
				// ScreenSpaceOverlay，须排在世界空间画布之上（见 UiEntry.overlayRank）。
				walk(root, screenFrame(inheritedCanvasScale(root.transform)), revisionChanged, 1);
			}
		}
		applyOrder();
		// PORT-NOTE: 命中矩形必须在**整棵树走完之后**解析：世界空间节点（SpriteRenderer /
		// collider 一类，如 Mainmenu 的 MainmenuButton、Map 的 MapButton）自身没有 RectTransform，
		// 矩形只能取「子树里已渲染精灵的屏幕矩形」或「collider 的本地包围盒」。
		resolveHitTargets();
		processPointer();
		reap();
		// PORT-NOTE: 在同一帧内拍快照。`MainSceneState.update` 里 logUiStats() 在 super.update()
		// **之前**调用，直接读静态计数会拿到"上一帧 sync 之后、本帧 sync 之前"的值；
		// 若两者时序对不上，读到的就是半成品。快照在 sync() 末尾生成，永远自洽。
		var clsList:Array<String> = [];
		for (k in graphicClassCounts.keys())
			clsList.push('$k=${graphicClassCounts.get(k)}');
		snapshot = '可见项=$visibleCount 成员=$length Graphic=$graphicCount(有Rect=$rectGraphicCount)'
			+ ' 文本=$textCount 纯色=$solidCount 世界精灵=$spriteRendererCount 跳过=$skippedCount'
			+ ' updateGraphic调用=$updateGraphicCalls Image有sprite=$imageWithSprite'
			+ ' Image无sprite=$imageWithoutSprite Image取帧失败=$imageFrameFailed'
			+ ' 可点击=$hitTargetCount(Button=$hitTargetButtonCount 自定义=$hitTargetCustomCount 用collider=$hitTargetColliderCount)'
			+ ' 类=[${clsList.join(",")}]';
	}

	/**
	 * 把本帧遍历到的项按深度优先顺序写回 FlxGroup 的成员表。
	 *
	 * PORT-NOTE: 用 `members.resize(n)` + 逐位赋值而不是 clear()+add()：`clear()` 会把
	 * 全部成员槽位置空、`add()` 又从 0 号槽开始填，当项数多于槽位数时 `add()` 会
	 * splice 到数组头部（flixel 的"复用空槽"策略），顺序被打乱。逐位赋值既稳定又不产生垃圾。
	 */
	private function applyOrder():Void {
		// PORT-NOTE: Unity 对 SpriteRenderer 按 (sortingLayer, sortingOrder) 排序，而 UI 按层级顺序。
		// 移植层在同一棵树上同时有两类：这里把 SpriteRenderer 项**在彼此之间**按
		// (sortingLayerID, sortingOrder) 稳定排序（其余项保持层级顺序）。
		// 实例：Mainmenu.prefab 的 `WindowView` 排序层 -10（最靠后），但它在兄弟表里排第 7，
		// 不排序会盖住背景。
		if (spriteRendererCount > 1)
			stableSortWorldSprites();
		// PORT-NOTE: Canvas 分层（Unity：ScreenSpaceOverlay 永远画在世界空间画布之上，与层级顺序无关）。
		// 本组按 overlayRank 稳定分区：0（世界空间/无画布）在前、1（Overlay）在后，
		// 组内保持上面的层级顺序与排序层结果。不分区时，挂在 Overlay 画布下的对话框
		// （MainGame/MainScene/UI/Dialogs/*）会被后遍历的世界空间 Mainmenu 盖住。
		var overlayCount = 0;
		for (e in live)
			if (e.overlayRank > 0)
				overlayCount++;
		if (overlayCount > 0 && overlayCount < live.length)
			stablePartitionByOverlayRank();
		var n = live.length;
		if (members.length != n)
			members.resize(n);
		length = n;
		visibleCount = 0;
		// PORT-NOTE: `textCount` 必须统计**本帧的文本项数**，而不是「本帧新建的 FlxText 数」。
		// 原先只在 `updateText` 里换类型的那一刻 `textCount++`，而渲染项是跨帧复用的 ——
		// 于是除了首帧之外它恒为 0。实测症状：画面上 14 个 TextMeshProUGUI 明明都渲染出来了
		// （`类=[unity.tmpro.TextMeshProUGUI=14,...]`），boot-trace 却报 `文本=0`，
		// 让人误判「文字没画出来」（黑屏报告的 §4.4 就是被这条误导的）。
		textCount = 0;
		for (i in 0...n) {
			members[i] = live[i].sprite;
			if (live[i].sprite.visible)
				visibleCount++;
			if (live[i].kind == UiEntryKind.Label)
				textCount++;
		}
	}

	/** 对 live 里的 SpriteRenderer 项按 (sortingLayerID, sortingOrder) 排序。 */
	private function stableSortWorldSprites():Void {		var indices:Array<Int> = [];
		for (i in 0...live.length) {
			if (live[i].kind == UiEntryKind.WorldSprite)
				indices.push(i);
		}
		if (indices.length < 2)
			return;
		// PORT-NOTE: Haxe 的 Array.sort 不保证稳定，故用 (层, 序, 原下标) 三元组排序，
		// 保证同键的项保持层级顺序。
		var keys:Array<{layer:Int, order:Int, index:Int, entry:UiEntry}> = [];
		for (i in indices) {
			var r = live[i].worldRenderer;
			keys.push({
				layer: r != null ? r.sortingLayerID : 0,
				order: r != null ? r.sortingOrder : 0,
				index: i,
				entry: live[i]
			});
		}
		keys.sort(function(a, b) {
			// PORT-NOTE: 排序键必须用 `SortingLayer.SortKeyOf`（层序号 → 打包）而不是**裸的
			// sortingLayerID**：Unity 的层 ID 是 uniqueID 的哈希，**无符号序**才有层级意义。
			// 裸比大小会把 `Foreground(-4036897)` 排到 `Default(0)` 之前（应为之后），
			// 也会把 `ScreenCover(1206696159)` 排到 `Talk(1660876549)` 之前（应为之后）。
			// 层序来自 `ProjectSettings/TagManager.asset`（见 unity/SortingLayer.hx）。
			var ka = SortingLayer.SortKeyOf(a.layer, a.order);
			var kb = SortingLayer.SortKeyOf(b.layer, b.order);
			if (ka != kb)
				return ka < kb ? -1 : 1;
			return a.index - b.index;
		});
		for (k in 0...indices.length)
			live[indices[k]] = keys[k].entry;
	}

	/**
	 * 按 overlayRank 稳定分区：rank 0（世界空间）在前、rank 1（ScreenSpaceOverlay）在后。
	 *
	 * PORT-NOTE: Haxe 的 Array.sort 不保证稳定，这里同样用 (rank, 原下标) 键排序，
	 * 同组内保持遍历（层级）顺序 —— 与 stableSortWorldSprites 同一手法。
	 */
	private function stablePartitionByOverlayRank():Void {
		var keys:Array<{rank:Int, index:Int, entry:UiEntry}> = [];
		for (i in 0...live.length)
			keys.push({rank: live[i].overlayRank, index: i, entry: live[i]});
		keys.sort(function(a, b) {
			if (a.rank != b.rank)
				return a.rank < b.rank ? -1 : 1;
			return a.index - b.index;
		});
		for (k in 0...live.length)
			live[k] = keys[k].entry;
	}

	private function reap():Void {
		// PORT-NOTE: 只有当"登记过的项数"与"本帧遍历到的项数"不一致时才做全表扫描 ——
		// 正常情况下每帧都相等，省掉 Map 的遍历。另外每 120 帧兜底扫一次，
		// 覆盖"一增一减、数量恰好相等"的边界。
		if (Lambda.count(entries) != live.length || (frame % 120) == 0) {
			for (go in entries.keys()) {
				var entry = entries.get(go);
				if (entry.lastSeenFrame != frame)
					retire(entry);
			}
		}
		if (graveyard.length == 0)
			return;
		for (entry in graveyard) {
			entry.sprite.destroy();
			entries.remove(entry.gameObject);
		}
		graveyard = [];
	}

	/** 一个 GameObject 从遍历中消失（未激活或已销毁）时调用。 */
	private function retire(entry:UiEntry):Void {
		if (entry.retired)
			return;
		entry.retired = true;
		// PORT-NOTE: 不能在这里 destroy() —— 遍历过程中 `destroy()` 会改到 FlxGroup 的成员表；
		// 且 `applyOrder()` 之后本项已不在成员表里，销毁是安全的，故推迟到 reap()。
		graveyard.push(entry);
	}

	// #region 鼠标命中 → OnPointerClick 派发

	/**
	 * 把一个节点登记为「可点击候选」。
	 *
	 * PORT-NOTE: 原先这里只认 `unity.ui.Button`，于是**项目自定义的可点击组件**
	 * （`mvz2.ui.mainmenu.MainmenuButton`、`mvz2.ui.map.MapButton`、`mvz2.ui.map.MapElementButton`、
	 * `mvz2.ui.scene.DebugConsoleIcon`、`mvz2.ui.almanac.AlmanacDescriptionLinkHandler`、
	 * `mvz2.ui.debugconsole.DebugConsoleInputField` …）全部收不到点击，主菜单/地图/图鉴的按钮
	 * 在移植层是死的。
	 *
	 * 判据：**组件上存在可调用的 `OnPointerClick` 方法**（uGUI 的 `IPointerClickHandler`
	 * 与项目自定义组件都按这个约定实现，见 `unity/eventsystems/IEventSystemHandler.hx`）。
	 * 刻意不写具体类名/页面名，新增可点击组件时无需改本文件。
	 *
	 * PORT-NOTE: 不用 `Std.isOfType(c, IPointerClickHandler)` 判定接口：hxcpp 会把
	 * `Std.isOfType(x, ClassOf<T>())` 优化成数字类索引常量，`IEventSystemHandler.hx`
	 * 一个模块里声明了 20 个接口，索引必然取错（同一缺陷见 `updateGraphic` 的 Image 分支说明）。
	 * 反射走的是类对象自身的字段表，与模块布局无关；本工程既有的
	 * `ScenePrefabLoader.callAwake`（找 `Awake`）、`AnimatorRuntime.invokeEvent`（找动画事件方法）
	 * 都是同一条路，实测在 release 构建下有效。
	 */
	private function registerHitCandidate(go:GameObject):Void {
		var handlers = findClickHandlers(go);
		if (handlers.length == 0)
			return;
		var rt = isInstanceOf(go.transform, RectTransform) ? cast(go.transform, RectTransform) : null;
		hitCandidates.push({
			gameObject: go,
			handlers: handlers,
			hasRectTransform: rt != null,
			rect: null,
			order: hitCandidates.length
		});
	}

	/** 该节点上全部「有 OnPointerClick 方法」的组件（顺序 = 组件顺序）。 */
	private static function findClickHandlers(go:GameObject):Array<Dynamic> {
		var result:Array<Dynamic> = [];
		for (c in go.GetAllComponents()) {
			if (c == null || c.destroyed)
				continue;
			var fn:Dynamic = Reflect.field(c, "OnPointerClick");
			if (fn != null && Reflect.isFunction(fn))
				result.push(c);
		}
		return result;
	}

	/**
	 * 遍历结束后统一解析每个候选的屏幕矩形。
	 *
	 * PORT-NOTE: 矩形来源按优先级四级回落（都不需要知道具体页面）：
	 *   1. **节点自身本帧实际绘制出来的矩形**（`renderedRectsByNode`，见其说明）。
	 *      这是与玩家所见**构造上一致**的来源，也是唯一能同时覆盖「uGUI 控件」与
	 *      「世界空间精灵按钮」的来源，因此排在最前。
	 *   2. 节点自身是 `RectTransform`（uGUI 控件）→ 用 `walk` 已经算好的布局帧。
	 *      仅当该节点本帧没画出任何东西时才会走到这里（例如透明 Image 做的命中区）。
	 *   3. 节点自身或**子树**里有 2D 碰撞体（`BoxCollider2D` / `PolygonCollider2D` /
	 *      `CircleCollider2D` / `CapsuleCollider2D`）→ 用碰撞体的本地包围盒按正交相机换算。
	 *   4. 子树里有 `RectTransform` / 已绘制精灵 → 取这些子节点的屏幕矩形并集。
	 * 第 3/4 级必须放在遍历之后：两者都要先走完整棵子树才知道有哪些子节点。
	 */
	private function resolveHitTargets():Void {
		for (candidate in hitCandidates) {
			var go = candidate.gameObject;
			if (go == null || go.destroyed || !go.activeInHierarchy)
				continue;
			var rect = renderedRectsByNode.get(go);
			var source = "绘制结果";
			if (rect == null || rect.width <= 0 || rect.height <= 0) {
				rect = candidate.hasRectTransform ? rectOfNode(go) : null;
				source = "RectTransform";
			}
			if (rect == null || rect.width <= 0 || rect.height <= 0) {
				rect = rectOfCollider(go);
				if (rect != null)
					source = "Collider2D";
			}
			if (rect == null || rect.width <= 0 || rect.height <= 0) {
				rect = rectOfDescendantRects(go);
				if (rect != null)
					source = "子级 RectTransform 并集";
			}
			if (rect == null || rect.width <= 0 || rect.height <= 0)
				continue;
			var isButton = go.GetComponent(Button) != null;
			hitTargets.push({
				gameObject: go,
				handlers: candidate.handlers,
				rect: rect,
				order: candidate.order,
				isButton: isButton
			});
			hitTargetCount++;
			if (isButton)
				hitTargetButtonCount++;
			else
				hitTargetCustomCount++;
			if (source == "Collider2D")
				hitTargetColliderCount++;
			if (hitTargetSamples.length < 16)
				hitTargetSamples.push('${nodePath(go)} [${source} ${Std.int(rect.x)},${Std.int(rect.y)} '
					+ '${Std.int(rect.width)}x${Std.int(rect.height)}]');
		}
	}

	/** 节点自身 RectTransform 的屏幕矩形（遍历时已算好并缓存）。 */
	private function rectOfNode(go:GameObject):unity.Rect {
		var frame = framesByNode.get(go);
		return frame != null ? toScreenRect(frame) : null;
	}

	/**
	 * 节点自身或子树里的 2D 碰撞体 → 屏幕矩形。
	 *
	 * PORT-NOTE: 碰撞体的 `size` / `points` / `radius` 都是**世界单位**（Unity 的物理单位），
	 * 因此先按 `transform.lossyScale` 换算到世界尺寸，再用正交相机的「每世界单位多少屏幕像素」
	 * （`Camera.pixelsPerUnit`）换算到屏幕像素。这与 `updateSpriteRenderer` 用的是同一套换算。
	 */
	private function rectOfCollider(go:GameObject):unity.Rect {
		var collider = findCollider(go);
		if (collider == null || collider.transform == null)
			return null;
		var half = colliderHalfExtents(collider);
		if (half == null || half.x <= 0 || half.y <= 0)
			return null;
		var ppu = orthographicPixelsPerUnit();
		if (ppu <= 0)
			return null;
		var scale = collider.transform.lossyScale;
		var origin = cameraOrigin();
		var world = worldPositionOf(collider.transform);
		var centerX = world.x + collider.offset.x * scale.x;
		var centerY = world.y + collider.offset.y * scale.y;
		var halfWidth = half.x * Math.abs(scale.x) * ppu;
		var halfHeight = half.y * Math.abs(scale.y) * ppu;
		var screenX = FlxG.width * 0.5 + (centerX - origin.x) * ppu;
		var screenY = FlxG.height * 0.5 - (centerY - origin.y) * ppu;
		return new unity.Rect(screenX - halfWidth, screenY - halfHeight, halfWidth * 2, halfHeight * 2);
	}

	/** 节点自身优先，其次子树（对应 Unity 的 `GetComponent` / `GetComponentInChildren` 顺序）。 */
	private function findCollider(go:GameObject):Collider2D {
		var own = go.GetComponent(Collider2D);
		if (own != null)
			return own;
		return go.GetComponentInChildren(Collider2D, true);
	}

	/** 碰撞体在**本地单位**下的半宽/半高（`null` = 该碰撞体类型没有可用几何）。 */
	private function colliderHalfExtents(collider:Collider2D):Vector2 {
		if (isInstanceOf(collider, BoxCollider2D)) {
			var box:BoxCollider2D = cast collider;
			return new Vector2(box.size.x * 0.5, box.size.y * 0.5);
		}
		if (isInstanceOf(collider, CircleCollider2D)) {
			var circle:CircleCollider2D = cast collider;
			return new Vector2(circle.radius, circle.radius);
		}
		if (isInstanceOf(collider, CapsuleCollider2D)) {
			var capsule:CapsuleCollider2D = cast collider;
			return new Vector2(capsule.size.x * 0.5, capsule.size.y * 0.5);
		}
		if (isInstanceOf(collider, PolygonCollider2D)) {
			var polygon:PolygonCollider2D = cast collider;
			var points = polygon.points;
			if (points == null || points.length == 0)
				return null;
			var minX = Math.POSITIVE_INFINITY;
			var minY = Math.POSITIVE_INFINITY;
			var maxX = Math.NEGATIVE_INFINITY;
			var maxY = Math.NEGATIVE_INFINITY;
			for (p in points) {
				if (p == null)
					continue;
				minX = Math.min(minX, p.x);
				maxX = Math.max(maxX, p.x);
				minY = Math.min(minY, p.y);
				maxY = Math.max(maxY, p.y);
			}
			if (minX > maxX || minY > maxY)
				return null;
			return new Vector2((maxX - minX) * 0.5, (maxY - minY) * 0.5);
		}
		return null;
	}

	/**
	 * 节点在世界空间里的位置。
	 *
	 * PORT-NOTE: 移植层没有做「localPosition → position」的层级级联（`ScenePrefabLoader` 只写
	 * `localPosition`，`Transform.position` 保持默认值），因此这里按 Unity 的语义**就地累加**：
	 * 从根往下逐级 `world = parentWorld + parentScale * local`。父级缩放取 `localScale` 级联值。
	 *
	 * PORT-NOTE: 但 `position` **不是恒为 0** —— 游戏逻辑里有 70+ 处直接写它的**世界坐标**
	 *（`MapController` 平移地图相机、`EntityController`/`ModelGroup` 摆实体与模型子节点、
	 * `LevelBlueprintChooseController`/`HintArrow`/`HPBarCanvasController` 摆 UI、…），
	 * 而 prefab 加载只写 `localPosition`。两类节点都要照顾，因此本函数的规则是：
	 * **每个节点自身若 `position` 非零就以它为准（代码写过的世界坐标，不再叠加父级），
	 * 否则取「父级解析值 + parentScale * localPosition」**。
	 * 纯 prefab 节点（`position` 恒为 0）与逐级累加完全一致；被代码摆过的节点保持原样，
	 * 且它的子节点（有 localPosition）从它继续级联（例如实体 → 模型子节点）。
	 *
	 * PORT-NOTE: RectTransform 节点的特例：导出器把 RectTransform 的 `m_LocalPosition` 导成了
	 * (0,0,0)，真实位置存在 `anchoredPosition` 里（Mainmenu 的 Stats/Achievements 世界画布
	 * 与 Elements/Labels 下的世界文本就是这一类 —— 不用 anchoredPosition 它们会全部叠到
	 * 屏幕中心）。因此对「position 与 localPosition 都是 0、但 anchoredPosition 非 0」的
	 * RectTransform 节点，用 anchoredPosition 当局部偏移。
	 * TODO-PORT: 级联应由 Transform 层统一提供（属另一工作包）。
	 */
	private function worldPositionOf(tr:Transform):Vector3 {
		var chain:Array<Transform> = [];
		var t:Transform = tr;
		var guard = 0;
		while (t != null && guard++ < 64) {
			chain.push(t);
			t = t.parent;
		}
		var position = new Vector3(0, 0, 0);
		var scale = new Vector3(1, 1, 1);
		var i = chain.length - 1;
		while (i >= 0) {
			var node = chain[i];
			var direct = node.position;
			if (direct != null && (direct.x != 0 || direct.y != 0 || direct.z != 0)) {
				position.x = direct.x;
				position.y = direct.y;
				position.z = direct.z;
			} else {
				var local = node.localPosition;
				// RectTransform 特例：导出数据里 localPosition 恒为 0、真实位置在 anchoredPosition。
				if ((local == null || (local.x == 0 && local.y == 0 && local.z == 0))
					&& isInstanceOf(node, RectTransform)) {
					var anchored = (cast node : RectTransform).anchoredPosition;
					if (anchored != null && (anchored.x != 0 || anchored.y != 0))
						local = new Vector3(anchored.x, anchored.y, 0);
				}
				if (local != null) {
					position.x += local.x * scale.x;
					position.y += local.y * scale.y;
					position.z += local.z * scale.z;
				}
			}
			var localScale = node.localScale;
			if (localScale != null) {
				scale.x *= localScale.x;
				scale.y *= localScale.y;
				scale.z *= localScale.z;
			}
			i--;
		}
		return position;
	}

	/** 子树里全部 RectTransform 节点的屏幕矩形并集（第 3 级回落）。 */
	private function rectOfDescendantRects(go:GameObject):unity.Rect {
		var minX = Math.POSITIVE_INFINITY;
		var minY = Math.POSITIVE_INFINITY;
		var maxX = Math.NEGATIVE_INFINITY;
		var maxY = Math.NEGATIVE_INFINITY;
		var found = false;
		for (child in go.transform.children) {
			if (child == null || child.gameObject == null)
				continue;
			if (!child.gameObject.activeInHierarchy)
				continue;
			var rect = unionSubtree(child.gameObject, function(r) {
				minX = Math.min(minX, r.x);
				minY = Math.min(minY, r.y);
				maxX = Math.max(maxX, r.x + r.width);
				maxY = Math.max(maxY, r.y + r.height);
			});
			if (rect)
				found = true;
		}
		if (!found || minX > maxX || minY > maxY)
			return null;
		return new unity.Rect(minX, minY, maxX - minX, maxY - minY);
	}

	/** 深度优先收集子树里所有**已绘制**（或已算出布局帧）的节点矩形；返回是否至少命中一个。 */
	private function unionSubtree(go:GameObject, visit:unity.Rect->Void):Bool {
		var found = false;
		// PORT-NOTE: 优先取「实际绘制结果」——主菜单/地图按钮的可见内容在**子节点**的
		// SpriteRenderer 上，而子节点没有 RectTransform（framesByNode 里没有它），
		// 只读布局帧会让这类按钮的命中区并集恒为空。
		var drawn = renderedRectsByNode.get(go);
		if (drawn != null && drawn.width > 0 && drawn.height > 0) {
			visit(drawn);
			found = true;
		} else {
			var frame = framesByNode.get(go);
			if (frame != null) {
				var rect = toScreenRect(frame);
				if (rect.width > 0 && rect.height > 0) {
					visit(rect);
					found = true;
				}
			}
		}
		for (child in go.transform.children) {
			if (child == null || child.gameObject == null)
				continue;
			if (!child.gameObject.activeInHierarchy)
				continue;
			if (unionSubtree(child.gameObject, visit))
				found = true;
		}
		return found;
	}

	/** 该可点击节点当前是否接受指针（CanvasGroup + Selectable 的 Unity 语义）。 */
	private function isHitTargetEnabled(target:HitTarget):Bool {
		var go = target.gameObject;
		if (go == null || go.destroyed || !go.activeInHierarchy)
			return false;
		// CanvasGroup：`blocksRaycasts = false` 在 Unity 里让整棵子树不接收射线；
		// `interactable = false` 让 Selectable 变成不可交互（LevelUIPreset.SetReceiveRaycasts 用前者）。
		var tr:Transform = go.transform;
		var guard = 0;
		while (tr != null && guard++ < 64) {
			if (tr.gameObject != null) {
				var group = tr.gameObject.GetComponent(CanvasGroup);
				if (group != null && (!group.blocksRaycasts || !group.interactable))
					return false;
			}
			tr = tr.parent;
		}
		// Selectable（Button/Toggle/…）：不可交互时不派发。
		// 自定义组件（MainmenuButton 等）的可用性由各自的 `OnPointerClick` 内部判定
		//（MainmenuButton 自己检查 `Interactable`、MapButton/MapElementButton 检查 `IsInteractable()`），
		// 这里不重复猜它们的字段名。
		for (handler in target.handlers) {
			if (isInstanceOf(handler, unity.ui.Selectable)) {
				var selectable:unity.ui.Selectable = cast handler;
				if (!selectable.IsInteractable())
					return false;
			}
		}
		return true;
	}

	/**
	 * 每帧的指针处理：悬停（enter/exit）+ 左键点击。
	 *
	 * PORT-NOTE: 原先这里**只**处理点击，`OnPointerEnter` / `OnPointerExit` 从来不派发。
	 * 后果不只是"没有悬停高亮"：
	 *   * `MainmenuButton.OnPointerEnter` 是它把 `isHovered` 置位、进而 `UpdateSprite()`
	 *     切到 `hoveredSprite` 的唯一途径（`MainmenuController.OnMainmenuButtonUpdateSpriteCallback`
	 *     依赖它），所以主菜单按钮永远停在常态图；
	 *   * `CursorHandler.OnPointerEnter` 是鼠标指针切换形状（`Global.Cursors.AddCursorSource`）
	 *     的唯一途径，缺了它光标在整个 UI 上都是默认箭头。
	 * uGUI 的语义是"指针每帧移动就重算当前命中项，变化时对旧项 exit、对新项 enter"，
	 * 这里按同一语义实现。
	 */
	private function processPointer():Void {
		#if FLX_MOUSE
		if (FlxG.mouse == null)
			return;
		var x = FlxG.mouse.screenX;
		var y = FlxG.mouse.screenY;
		// PORT-NOTE: 取**最后一个**命中项 —— `hitTargets` 的顺序就是深度优先的层级顺序
		// （即 Unity 的绘制顺序），最后一个即最上层，与 uGUI 的射线拾取一致。
		var best:HitTarget = null;
		for (target in hitTargets) {
			if (!isHitTargetEnabled(target))
				continue;
			if (x >= target.rect.x && x <= target.rect.x + target.rect.width
				&& y >= target.rect.y && y <= target.rect.y + target.rect.height)
				best = target;
		}
		dispatchHover(best, x, y);
		if (FlxG.mouse.justPressed && best != null)
			dispatchPointerClick(best, x, y);
		#end
	}

	/** 当前悬停项发生变化时派发 exit / enter（对应 uGUI 的指针进入/离开）。 */
	private function dispatchHover(best:HitTarget, x:Float, y:Float):Void {
		var bestGo = best != null ? best.gameObject : null;
		if (hoveredTarget != null && hoveredTarget.gameObject != bestGo) {
			var old = hoveredTarget;
			hoveredTarget = null;
			dispatchPointerEvent(old, "OnPointerExit", x, y);
		}
		if (best != null && (hoveredTarget == null || hoveredTarget.gameObject != bestGo)) {
			hoveredTarget = best;
			dispatchPointerEvent(best, "OnPointerEnter", x, y);
		}
	}

	/** 本帧悬停的节点（用于下一帧判断是否需要 exit）。 */
	private var hoveredTarget:HitTarget = null;

	/**
	 * 向命中节点上的全部组件派发一次指定名字的指针事件（`OnPointerExit` / `OnPointerEnter`）。
	 *
	 * PORT-NOTE: 与 `dispatchPointerClick` 同样逐个 try/catch —— 单个处理器抛异常
	 * 不应中断其它处理器与整帧同步。
	 */
	private function dispatchPointerEvent(target:HitTarget, method:String, x:Float, y:Float):Void {
		if (target == null)
			return;
		var eventData = new PointerEventData();
		eventData.position = new Vector2(x, y);
		eventData.pressPosition = new Vector2(x, y);
		eventData.pointerId = -1;
		eventData.button = unity.eventsystems.PointerEventData.InputButton.Left;
		eventData.pointerEnter = target.gameObject;
		for (handler in target.handlers) {
			var fn:Dynamic = Reflect.field(handler, method);
			if (fn == null || !Reflect.isFunction(fn))
				continue;
			try {
				Reflect.callMethod(handler, fn, [eventData]);
			} catch (e:Dynamic) {
				lastError = '${nodePath(target.gameObject)} 的 $method 抛出：$e';
				unity.Debug.LogError('UiRenderer：${nodePath(target.gameObject)} 的 $method 抛出异常：$e');
			}
		}
	}

	/**
	 * 向命中节点上的全部 `OnPointerClick` 组件派发一次点击。
	 *
	 * PORT-NOTE: 事件数据按 Unity 的 `PointerEventData` 语义填齐（指针 id 为鼠标左键、位置、
	 * 以及 `pointerCurrentRaycast`）。`pointerId = -1` 是移植层对「鼠标左键」的约定
	 * （见 `InputHelper.GetPointerIdByButtonAndType`：`-button - 1`），
	 * `MapButton` / `MapElementButton` 会据此过滤掉非左键。
	 */
	private function dispatchPointerClick(target:HitTarget, x:Float, y:Float):Void {
		var eventData = new PointerEventData();
		eventData.position = new Vector2(x, y);
		eventData.pressPosition = new Vector2(x, y);
		eventData.pointerId = -1;
		eventData.button = unity.eventsystems.PointerEventData.InputButton.Left;
		eventData.pointerEnter = target.gameObject;
		eventData.pointerPress = target.gameObject;
		eventData.pointerClick = target.gameObject;
		// 部分处理器会读 `pointerCurrentRaycast`（如 `LevelController.UI_OnGridPointerInteractionCallback`
		// 取 worldPosition / screenPosition），这里按相机换算填好，避免下游拿到零值。
		var raycast = eventData.pointerCurrentRaycast;
		if (raycast != null) {
			raycast.gameObject = target.gameObject;
			raycast.screenPosition = new Vector2(x, y);
			raycast.worldPosition = screenToWorld(x, y);
			raycast.isValid = true;
		}
		for (handler in target.handlers) {
			var fn:Dynamic = Reflect.field(handler, "OnPointerClick");
			if (fn == null || !Reflect.isFunction(fn))
				continue;
			try {
				Reflect.callMethod(handler, fn, [eventData]);
			} catch (e:Dynamic) {
				// PORT-NOTE: 单个处理器抛异常不应中断其它处理器与整帧同步（Unity 的事件系统
				// 也是逐个 try/catch 记录）。记录到 lastError 便于诊断。
				lastError = '${nodePath(target.gameObject)} 的 OnPointerClick 抛出：$e';
				unity.Debug.LogError('UiRenderer：${nodePath(target.gameObject)} 的 OnPointerClick 抛出异常：$e');
			}
		}
	}

	/** 屏幕像素（Flixel 左上原点）→ 世界坐标（按当前正交相机）。 */
	private function screenToWorld(x:Float, y:Float):Vector3 {
		var ppu = orthographicPixelsPerUnit();
		if (ppu <= 0)
			return new Vector3(0, 0, 0);
		var origin = cameraOrigin();
		return new Vector3(
			origin.x + (x - FlxG.width * 0.5) / ppu,
			origin.y + (FlxG.height * 0.5 - y) / ppu,
			0);
	}

	// #endregion

	// #endregion

	// #region 树遍历 + RectTransform 解析

	/**
	 * 一个节点的布局帧（把"canvas 单位 → 屏幕像素"的全部信息打包）。
	 *
	 * `local`   —— 该节点在**自身局部坐标系**里的矩形（原点在自身 pivot，与 Unity 的
	 *              `RectTransform.rect` 语义一致）。
	 * `origin`  —— 该节点 pivot 在**屏幕像素**里的位置。
	 * `scale`   —— 该节点的局部单位 → 屏幕像素的比例。
	 * `clip`    —— 祖先 Mask/RectMask2D 产生的裁剪矩形（屏幕像素），null 表示不裁剪。
	 */
	private function frameFor(canvasScale:Float, ownScale:Float, ?origin:Vector2, ?local:unity.Rect, ?clip:unity.Rect,
			?scale:Float):LayoutFrame {
		return {
			canvasScale: canvasScale,
			ownScale: ownScale,
			scale: scale != null ? scale : canvasScale * ownScale,
			origin: origin != null ? origin : new Vector2(0, 0),
			local: local != null ? local : new unity.Rect(0, 0, 0, 0),
			clip: clip
		};
	}

	/** 从任意节点向上找最近的 Canvas 组件。 */
	private function findCanvas(go:GameObject):Canvas {
		var tr:Transform = go != null ? go.transform : null;
		while (tr != null) {
			if (tr.gameObject != null) {
				var c = tr.gameObject.GetComponent(Canvas);
				if (c != null)
					return c;
			}
			tr = tr.parent;
		}
		return null;
	}

	/** 从任意节点向上找最近的 CanvasScaler 组件。 */
	private function findCanvasScaler(go:GameObject):CanvasScaler {
		var tr:Transform = go != null ? go.transform : null;
		while (tr != null) {
			if (tr.gameObject != null) {
				var c = tr.gameObject.GetComponent(CanvasScaler);
				if (c != null)
					return c;
			}
			tr = tr.parent;
		}
		return null;
	}

	/**
	 * 沿父链向上找最近的、带 `CanvasScaler` 的祖先 Canvas 的 scaleFactor（找不到 → 1）。
	 *
	 * PORT-NOTE: Unity 里嵌套 Canvas 若没有自己的 CanvasScaler，**继承**父画布的 scaleFactor
	 * （不是重置为 1）。旧代码 `walkCanvas` 对这类画布直接 `computeScaleFactor(null)` = 1，
	 * 挂在不带 CanvasScaler 的 Canvas 下的 UI 会整体缩小到 1/父缩放。这里统一沿父链查。
	 */
	private function inheritedCanvasScale(from:Transform):Float {
		var scaler = findCanvasScaler(from != null ? from.gameObject : null);
		return scaler != null ? computeScaleFactor(scaler) : 1;
	}

	/** 画布根：矩形 = 屏幕 / scaleFactor（Unity 的 ScreenSpaceOverlay 画布 rect），原点在画布中心。 */
	private function screenFrame(scale:Float):LayoutFrame {
		var w = FlxG.width / scale;
		var h = FlxG.height / scale;
		// PORT-NOTE: 画布根自身的 pivot 是 (0.5, 0.5)（Unity 对根 Canvas 强制如此），
		// 所以它的 local rect 以原点为中心。origin（pivot 的屏幕位置）= 屏幕中心。
		var local = new unity.Rect(-w * 0.5, -h * 0.5, w, h);
		var origin = new Vector2(FlxG.width * 0.5, FlxG.height * 0.5);
		return frameFor(scale, 1, origin, local);
	}

	private function walkCanvas(canvas:Canvas, searchRoot:GameObject):Void {
		var scaler = canvas.gameObject != null ? canvas.gameObject.GetComponent(CanvasScaler) : null;
		// PORT-NOTE: 嵌套 Canvas 自己没挂 CanvasScaler 时继承**父画布**的 scaleFactor（Unity 语义），
		// 而不是重置为 1 —— 旧代码 `computeScaleFactor(null)` 会把这些子树整体缩成 1/父缩放。
		var scale = scaler != null ? computeScaleFactor(scaler) : inheritedCanvasScale(canvas.transform);
		canvas.scaleFactor = scale;
		var frame = screenFrame(scale);
		// PORT-NOTE: Canvas 自身也可能挂 Graphic（罕见），按同一规则生成渲染项。
		// overlayRank=1：ScreenSpaceOverlay 画布整体排在世界空间画布之上（Unity 的 Canvas 分层语义，
		// 见 UiEntry.overlayRank）——否则挂在 Overlay 画布下的对话框会被后遍历的世界空间画布盖住。
		renderNode(canvas.gameObject, frame, true, 1);
		walk(canvas.gameObject, frame, true, 1);
	}

	/**
	 * 世界空间 Canvas（主菜单 Stats/Achievements 子页面就是这一类）：画布根按世界坐标
	 * 摆放，Unity 靠 Animator 平移相机在页面间切换。这里按正交相机把画布根投影到屏幕，
	 * 子级仍走 RectTransform 布局（画布单位 → 屏幕 经 frame.scale = ppu × lossyScale 换算）。
	 * 若按 screenFrame 重挂根，两个本在屏幕外的页面会变成全屏黑场盖住主菜单。
	 */
	private function walkWorldCanvas(canvas:Canvas, go:GameObject, forceDirty:Bool):Void {
		var tr = go.transform;
		// PORT-NOTE: 必须用 `worldPositionOf` —— prefab 加载只写 `localPosition`（`position` 对这类
		// 节点恒为 (0,0,0)，且不做级联），用它会让所有 WorldSpace 画布（主菜单 Stats/Achievements
		// 等子页面）叠在屏幕中心。被代码写过 `position` 的画布由 worldPositionOf 原样采用。
		var pos = tr != null ? worldPositionOf(tr) : new Vector3(0, 0, 0);
		var ppu = orthographicPixelsPerUnit();
		if (ppu <= 0)
			ppu = 1;
		var cam = cameraOrigin();
		var originX = FlxG.width * 0.5 + (pos.x - cam.x) * ppu;
		var originY = FlxG.height * 0.5 - (pos.y - cam.y) * ppu;
		var rt = tr != null && isInstanceOf(tr, RectTransform) ? cast(tr, RectTransform) : null;
		var w = rt != null ? rt.sizeDelta.x : FlxG.width;
		var h = rt != null ? rt.sizeDelta.y : FlxG.height;
		var ls = tr != null ? tr.lossyScale : new Vector3(1, 1, 1);
		// 画布根 pivot (0.5, 0.5)：local rect 以原点为中心（与 screenFrame 同一约定）。
		var frame = frameFor(ppu, ls.x, new Vector2(originX, originY), new unity.Rect(-w * 0.5, -h * 0.5, w, h));
		// overlayRank=0：世界空间画布排在 ScreenSpaceOverlay 之下（见 UiEntry.overlayRank）。
		renderNode(go, frame, forceDirty, 0);
		walk(go, frame, forceDirty, 0);
	}

	/**
	 * 深度优先遍历，按 Unity 规则解析每个 RectTransform 的屏幕矩形并生成渲染项。
	 *
	 * @param parent   父节点的布局帧
	 * @param forceDirty 全局 revision 变化时，全部项都重建（无法逐项定位是哪个字段变了）
	 * @param overlayRank 画布分层权重（0=世界空间，1=ScreenSpaceOverlay），见 UiEntry.overlayRank
	 */
	private function walk(parent:GameObject, parentFrame:LayoutFrame, forceDirty:Bool, overlayRank:Int = 0):Void {
		if (parent == null)
			return;
		var parentTr = parent.transform;
		if (parentTr == null)
			return;
		for (child in parentTr.children) {
			if (child == null || child.gameObject == null)
				continue;
			var go = child.gameObject;
			// PORT-NOTE: Unity 不绘制未激活节点及其子树（activeInHierarchy）。
			if (!go.activeInHierarchy)
				continue;
			var rt = isInstanceOf(child, RectTransform) ? cast(child, RectTransform) : null;
			var frame = rt != null ? childFrame(rt, parentFrame) : parentFrame;
			if (rt != null) {
				var aspect = go.GetComponent(AspectRatioFitter);
				if (aspect != null) {
					if (frame.local.width <= 0 || frame.local.height <= 0)
						frame = parentFrame;
					frame = applyAspectRatio(frame, aspect);
				}
			}

			renderNode(go, frame, forceDirty, overlayRank);
			// 子级：若自身带 Canvas，则它开启一个新的画布（自己的 CanvasScaler）。
			var nested = go.GetComponent(Canvas);
			if (nested != null) {
				if (nested.renderMode == RenderMode.WorldSpace)
					walkWorldCanvas(nested, go, forceDirty);
				else
					walkCanvas(nested, go);
				continue;
			}
			// PORT-NOTE: Mask / RectMask2D 只影响**子树**，不影响本节点自身；因此这里派生出
			// 一份带裁剪的帧给子级用，不改动 frame 本身（否则会泄漏给兄弟节点）。
			var childFrameForSubtree = frame;
			if (go.GetComponent(Mask) != null)
				childFrameForSubtree = withClip(frame, intersectClip(frame.clip, toScreenRect(frame)));
			walk(go, childFrameForSubtree, forceDirty, overlayRank);
		}
	}

	/** 复制一份布局帧并替换裁剪矩形。 */
	private function withClip(frame:LayoutFrame, clip:unity.Rect):LayoutFrame {
		return {
			canvasScale: frame.canvasScale,
			ownScale: frame.ownScale,
			scale: frame.scale,
			origin: frame.origin,
			local: frame.local,
			clip: clip
		};
	}

	/** 按 Unity 的 anchor/pivot/offset 规则把子 RectTransform 解析成屏幕帧。 */
	private function applyAspectRatio(frame:LayoutFrame, fitter:AspectRatioFitter):LayoutFrame {
		if (fitter == null || fitter.aspectRatio <= 0 || fitter.aspectMode == AspectMode.None)
			return frame;
		var width = frame.local.width;
		var height = frame.local.height;
		if (width <= 0 || height <= 0)
			return frame;
		var targetWidth = width;
		var targetHeight = height;
		switch (fitter.aspectMode) {
			case AspectMode.WidthControlsHeight:
				targetHeight = width / fitter.aspectRatio;
			case AspectMode.HeightControlsWidth:
				targetWidth = height * fitter.aspectRatio;
			case AspectMode.FitInParent, AspectMode.EnvelopeParent:
				var fittedHeight = width / fitter.aspectRatio;
				if ((fitter.aspectMode == AspectMode.FitInParent && fittedHeight <= height)
					|| (fitter.aspectMode == AspectMode.EnvelopeParent && fittedHeight >= height))
					targetHeight = fittedHeight;
				else
					targetWidth = height * fitter.aspectRatio;
			case AspectMode.None:
				return frame;
		}
		var centerX = frame.local.x + width * 0.5;
		var centerY = frame.local.y + height * 0.5;
		var local = new unity.Rect(centerX - targetWidth * 0.5, centerY - targetHeight * 0.5, targetWidth, targetHeight);
		return frameFor(frame.canvasScale, frame.ownScale, frame.origin, local, frame.clip, frame.scale);
	}

	private function childFrame(rt:RectTransform, parentFrame:LayoutFrame):LayoutFrame {
		// 1) 在父级局部单位下解析子级矩形（原点在父级 pivot，与 Unity 一致）。
		var p = parentFrame.local;
		var aminX = p.x + rt.anchorMin.x * p.width;
		var amaxX = p.x + rt.anchorMax.x * p.width;
		var aminY = p.y + rt.anchorMin.y * p.height;
		var amaxY = p.y + rt.anchorMax.y * p.height;
		var sizeX = (amaxX - aminX) + rt.sizeDelta.x;
		var sizeY = (amaxY - aminY) + rt.sizeDelta.y;
		var refX = aminX + (amaxX - aminX) * rt.pivot.x;
		var refY = aminY + (amaxY - aminY) * rt.pivot.y;
		var pivotLocalX = refX + rt.anchoredPosition.x;
		var pivotLocalY = refY + rt.anchoredPosition.y;

		// 2) 父级局部单位 → 屏幕像素：先乘父级的 ownScale（父级的 localScale），再乘父级的 scale。
		var toScreen = parentFrame.canvasScale * parentFrame.ownScale;
		// 父级 pivot 在屏幕上的位置 + (子 pivot 相对父 pivot 的偏移) * toScreen
		var originX = parentFrame.origin.x + pivotLocalX * toScreen;
		var originY = parentFrame.origin.y - pivotLocalY * toScreen;

		// 3) 子级自身局部单位 → 屏幕像素
		var scale = toScreen * rt.localScale.x;
		// PORT-NOTE: 缩放取 x 分量（工程里的 RectTransform 缩放都是等比；PanZoomController 例外，
		// 它在缩放时同时改 x/y，这里取 x 已足够）。
		var local = new unity.Rect(-rt.pivot.x * sizeX, -rt.pivot.y * sizeY, sizeX, sizeY);
		// PORT-NOTE: `frameFor` 的 canvasScale 参数必须是**父级已累积**的缩放（= toScreen），
		// ownScale 才是本节点自己的 localScale：下一级 `childFrame` 会再算一次
		// `parent.canvasScale * parent.ownScale`，旧代码在这里传 `scale`（= toScreen * localScale）
		// 使 localScale 被乘了两次（缩放平方）。
		return frameFor(toScreen, rt.localScale.x, new Vector2(originX, originY), local, parentFrame.clip, scale);
	}

	/** 把节点局部矩形（原点在 pivot）换算成屏幕左上角矩形。 */
	private function toScreenRect(frame:LayoutFrame):unity.Rect {
		var w = frame.local.width * frame.scale;
		var h = frame.local.height * frame.scale;
		var x = frame.origin.x + frame.local.x * frame.scale;
		var y = frame.origin.y - frame.local.y * frame.scale - h;
		return new unity.Rect(x, y, w, h);
	}

	// #endregion

	// #region 渲染项

	/** 为一个 GameObject 生成/更新渲染项。 */
	private function renderNode(go:GameObject, frame:LayoutFrame, forceDirty:Bool, overlayRank:Int = 0):Void {
		if (go == null || go.destroyed || !go.activeInHierarchy)
			return;
		if (isInstanceOf(go.transform, RectTransform))
			framesByNode.set(go, frame);
		// PORT-NOTE: 先清掉上一帧留下的「绘制矩形」，由下面真正生成渲染项的分支重新写。
		// 不清会残留旧值，节点改小/移走后命中区仍是旧的。
		renderedRectsByNode.remove(go);
		registerHitCandidate(go);
		var graphic:Graphic = null;
		var text:TextMeshProUGUI = null;
		var worldText:TextMeshProUGUI = null;
		var uiText:unity.ui.Text = null;
		var renderer:SpriteRenderer = null;
		for (c in go.GetAllComponents()) {
			// PORT-NOTE: **「白色占位块」的根因就在这个名字遮蔽上**。
			//
			// 本模块底部声明过 `enum abstract UiEntryKind`，其成员曾叫 `Image` / `Text` /
			// `Solid` / `SpriteRenderer`。Haxe 的模块作用域会把这些成员提升成**模块级名字**，
			// 于是它们遮蔽了同名的类 `unity.ui.Image` / `unity.ui.Text` / `unity.SpriteRenderer`：
			// `Std.isOfType(c, Text)` 实际是拿**整数 3** 去比较，判定恒为 false ——
			// 18 个 `unity.ui.Image` 一个都进不了取帧分支，全部退化成 1×1 白图拉伸。
			//
			// 修法：枚举成员改名（`ImageGraphic` / `Label` / `SolidRect` / `WorldSprite`），
			// 从根上消除遮蔽；这里保留全限定名作为二次保险（对**值位置**的遮蔽同样有效）。
			if (graphic == null && isInstanceOf(c, Graphic))
				graphic = cast c;
			// PORT-NOTE: unity.tmpro.TextMeshPro（世界空间）继承 TextMeshProUGUI，
			// isInstanceOf 会把二者混为一谈。世界空间 TMP 没有 uGUI 布局帧，
			// 必须走 updateWorldText 按正交相机投影，否则全部堆在屏幕左上角。
			if (text == null && worldText == null && isInstanceOf(c, TextMeshProUGUI)) {
				if (Type.getClass(c) == unity.tmpro.TextMeshPro)
					worldText = cast c;
				else
					text = cast c;
			}
			if (uiText == null && isInstanceOf(c, unity.ui.Text))
				uiText = cast c;
			if (renderer == null && isInstanceOf(c, SpriteRenderer))
				renderer = cast c;
		}

		// 裁剪：Mask / RectMask2D 会影响它**下面**的子树，本节点自身不受影响。
		var clip = frame.clip;
		// PORT-NOTE: `Mask.showMaskGraphic = false` 表示该遮罩「只负责裁剪、不绘制自身 Graphic」
		//（Unity 语义；语言下拉框的 `Viewport` 就是这一种）。旧代码照画，遮罩自身的图元会盖住
		// 被它裁剪的内容（下拉框条目被半透明底图挡住）。
		var maskComp = go.GetComponent(Mask);
		var maskSuppressGraphic = maskComp != null && !maskComp.showMaskGraphic;

		if (graphic != null && !maskSuppressGraphic) {
			graphicCount++;
			var cls = Type.getClassName(Type.getClass(graphic));
			graphicClassCounts.set(cls, (graphicClassCounts.exists(cls) ? graphicClassCounts.get(cls) : 0) + 1);
			var rt = isInstanceOf(go.transform, RectTransform) ? cast(go.transform, RectTransform) : null;
			if (rt != null) rectGraphicCount++;
			if (worldText != null) {
				var entry = obtain(go, overlayRank);
				updateWorldText(entry, go, worldText, alphaOf(go));
			} else if (rt == null) {
				// PORT-NOTE: uGUI 的 Graphic 必须挂在 RectTransform 上；挂在普通 Transform 上
				// 说明是手工对象图没换 Transform（见 MainGameScene.childRect 的说明），跳过并计数。
				skippedCount++;
				if (nonRectGraphicSamples.length < 12)
					nonRectGraphicSamples.push('${nodePath(go)} [${Type.getClassName(Type.getClass(graphic))} tr=${Type.getClassName(Type.getClass(go.transform))}]');
			} else {
				var rect = toScreenRect(frame);
				var entry = obtain(go, overlayRank);
				updateGraphic(entry, go, graphic, text, uiText, rect, frame, alphaOf(go), frame.clip);
			}
			// PORT-NOTE: Mask 的裁剪由 walk() 派生子级帧时处理（只影响子树，不影响本节点）。
		} else if (renderer != null && renderer.renderSprite != null) {
			// PORT-NOTE: 世界空间的 SpriteRenderer（Mainmenu/Titlescreen 的背景就是这一类）。
			// 它本来由精灵工作包的 `SpriteFrameFactory` 接线到 `renderSprite`，但**没有**任何
			// 显示列表的所有者；这里按正交相机（orthographicSize / 世界坐标）把它换算到屏幕，
			// 否则主菜单背景永远不可见。属跨包协作点，已在报告里标注。
			spriteRendererCount++;
			var entry = obtain(go, overlayRank);
			updateSpriteRenderer(entry, renderer, alphaOf(go));
		} else {
			skippedCount++;
		}
	}

	private function alphaOf(go:GameObject):Float {
		// PORT-NOTE: CanvasGroup.alpha 在 Unity 里按层级相乘；这里向上收集并相乘。
		var alpha = 1.0;
		var tr:Transform = go.transform;
		while (tr != null) {
			if (tr.gameObject != null) {
				var group = tr.gameObject.GetComponent(CanvasGroup);
				if (group != null)
					alpha *= group.alpha;
			}
			tr = tr.parent;
		}
		return alpha;
	}

	private function obtain(go:GameObject, overlayRank:Int = 0):UiEntry {
		var entry = entries.get(go);
		if (entry == null) {
			entry = {
				gameObject: go,
				sprite: new FlxSprite(),
				kind: UiEntryKind.Empty,
				lastRevision: -1,
				lastText: null,
				lastRect: new unity.Rect(-1, -1, -1, -1),
				worldSprite: null,
				lastFontSize: -1,
				lastFont: null,
				retired: false,
				lastSeenFrame: frame,
				worldRenderer: null,
				overlayRank: overlayRank
			};
			entry.sprite.visible = false;
			entries.set(go, entry);
		}
		// PORT-NOTE: 本帧重新出现（重新激活 / 复用）时从"墓碑"状态恢复。
		if (entry.retired) {
			entry.retired = false;
			entry.lastRevision = -1;
			entry.lastText = null;
			entry.lastFontSize = -1;
			entry.lastFont = null;
		}
		entry.lastSeenFrame = frame;
		if (live.indexOf(entry) < 0)
			live.push(entry);
		return entry;
	}

	// #endregion

	// #region Graphic → FlxSprite / FlxText

	private function updateGraphic(entry:UiEntry, go:GameObject, graphic:Graphic, text:TextMeshProUGUI, uiText:Text,
			rect:unity.Rect, frame:LayoutFrame, groupAlpha:Float, clip:unity.Rect):Void {
		updateGraphicCalls++;
		if (updateGraphicSamples.length < 8) {
			updateGraphicSamples.push('${nodePath(go)} g=${Type.getClassName(Type.getClass(graphic))}'
				+ ' text=${text != null} uiText=${uiText != null}');
		}
		entry.worldRenderer = null;
		var color = graphic.color;
		if (color == null)
			color = new unity.Color(1, 1, 1, 1);
		var alpha = color.a * groupAlpha;
		var tint = FlxColor.fromRGBFloat(color.r, color.g, color.b, 1);

		if (text != null) {
			// PORT-NOTE: 不能直接把 `text.alignment` 交给 flixelAlignment —— 导出数据里 TMP 的
			// alignment 恒为 65535 哨兵，真正对齐在 horizontalAlignment/verticalAlignment
			// （见 tmpAlignmentValue 的说明）。
			updateText(entry, text.text, text.fontSize, tint, alpha, tmpAlignmentValue(text), text.enableWordWrapping,
				text.richText, rect, text.enabled, clip);
			return;
		}
		if (uiText != null) {
			var wrap = uiText.horizontalOverflow == unity.HorizontalWrapMode.Wrap;
			updateText(entry, uiText.text, uiText.fontSize, tint, alpha, uiText.alignment, wrap,
				uiText.supportRichText, rect, uiText.enabled, clip);
			return;
		}

		// ---- Image / RawImage ----
		var sprite:unity.Sprite = null;
		// PORT-NOTE: 这里刻意**不用** `Std.isOfType(graphic, Image)`：hxcpp 把带类型参数的
		// `Std.isOfType(x, ClassOf<T>)` 优化成 `isOfType(x, <类索引常量>)`（本例生成
		// `::Std_obj::isOfType(graphic,1)`），该常量在**同一模块有多个类**时可能取错索引，
		// 实测恒为 false —— 于是 18 个 `unity.ui.Image` 一个都进不了这个分支，
		// `imageWithSprite` / `imageWithoutSprite` 双双为 0，所有 Image 都退化成 1×1 白图拉伸
		//（即「白色占位块」）。改用 `Type.getClass` 沿继承链判定的 `isInstanceOf`，语义明确。
		var image = isInstanceOf(graphic, unity.ui.Image) ? cast(graphic, unity.ui.Image) : null;
		var rawImage = isInstanceOf(graphic, unity.ui.RawImage) ? cast(graphic, unity.ui.RawImage) : null;
		if (image != null)
			sprite = image.activeSprite;
		else if (rawImage != null && isInstanceOf(rawImage.texture, unity.Texture2D))
			sprite = SpriteManifestLoader.createSpriteForTexture(cast rawImage.texture);

		// PORT-NOTE: 诊断计数 —— 「白块」现象（Image 退化成 1x1 白图拉伸）只有区分
		// 「sprite 没注入」和「sprite 有但取不到帧」才能定位。两者都记样例节点名。
		if (image != null) {
			if (sprite == null) {
				imageWithoutSprite++;
				if (imageWithoutSpriteSamples.length < 12)
					imageWithoutSpriteSamples.push(nodePath(go));
			} else {
				imageWithSprite++;
			}
		}

		var needsRebuild = entry.lastRevision != Graphic.revision || entry.kind != UiEntryKind.ImageGraphic;
		if (sprite != null) {
			var frame2 = SpriteFrameFactory.getFrame(sprite);
			if (frame2 != null) {
				if (needsRebuild || entry.worldSprite != sprite) {
					entry.sprite.frames = SpriteFrameFactory.makeImageFrame(frame2);
					entry.sprite.frame = frame2;
					entry.kind = UiEntryKind.ImageGraphic;
					entry.lastRevision = Graphic.revision;
					entry.worldSprite = sprite;
					entry.sprite.origin.set(0, 0);
				}
				solidCount++;
			} else {
				imageFrameFailed++;
				if (imageFrameFailedSamples.length < 12)
					imageFrameFailedSamples.push('${nodePath(go)} sprite=${spriteName(sprite)}');
				applySolid(entry, tint, needsRebuild);
			}
		} else {
			applySolid(entry, tint, needsRebuild);
		}

		var s = entry.sprite;
		s.visible = graphic.enabled && alpha > 0.001;
		s.alpha = alpha;
		s.color = tint;
		if (entry.kind == UiEntryKind.SolidRect) {
			// 纯色块：1x1 白图拉伸到矩形（与 Unity 的 Image 无 sprite 时画纯色矩形一致）。
			s.origin.set(0, 0);
			s.setPosition(rect.x, rect.y);
			s.setGraphicSize(Std.int(Math.max(1, rect.width)), Std.int(Math.max(1, rect.height)));
		} else {
			s.origin.set(0, 0);
			s.setPosition(rect.x, rect.y);
			if (s.frameWidth > 0 && s.frameHeight > 0)
				s.setGraphicSize(Std.int(Math.max(1, rect.width)), Std.int(Math.max(1, rect.height)));
		}
		// PORT-NOTE: `clipRect` 必须在**位置/缩放都定下来之后**再设 —— 它要按图元当前的
		// 绘制左上角与缩放换算到帧本地坐标（见 clipToFrameLocal），且 flixel 的 `clipRect`
		// 不是屏幕矩形（旧代码直接赋屏幕矩形，Mask 子树里的图元会整片不画）。
		s.clipRect = clipToFrameLocal(clip, s);
		// PORT-NOTE: 记下**真正画出来**的矩形（见 renderedRectsByNode 的说明）。
		// 用 `frameWidth/Height * scale` 而不是传入的 `rect`：纯色兜底分支与「有 sprite」
		// 分支的尺寸来源不同，只有读 FlxSprite 自身几何才与画面严格一致。
		renderedRectsByNode.set(go, flxSpriteRect(s));
	}

	/** FlxSprite 当前的屏幕矩形（左上角 + 帧尺寸 × 缩放）。 */
	private static function flxSpriteRect(s:FlxSprite):unity.Rect {
		if (s == null)
			return null;
		var w = (s.frameWidth > 0 ? s.frameWidth : s.width) * Math.abs(s.scale.x);
		var h = (s.frameHeight > 0 ? s.frameHeight : s.height) * Math.abs(s.scale.y);
		// PORT-NOTE: 位置取**绘制左上角**（统一约定：本文件的各分支都用 `setPosition` 摆左上角，
		// 唯一例外是世界精灵分支要按 origin/scale 换算，见 flxSpriteTopLeft）。
		// 旧代码按「flixel 的 (x,y) 是 origin 的位置」又减了一次 origin —— 而 `updateSpriteRenderer`
		// 已经把 pivot 减掉并 `setPosition(left, top)`，于是记录的绘制矩形整体偏移 -origin，
		// 表现为「主菜单按钮画得出来但点不到」（命中框与可见框错位）。
		var topLeft = flxSpriteTopLeft(s);
		return new unity.Rect(topLeft.x, topLeft.y, w, h);
	}

	/**
	 * FlxSprite 在屏幕上的**绘制左上角**（帧本地 (0,0) 落在的屏幕位置）。
	 *
	 * PORT-NOTE: flixel 的 `(x, y)` 是「origin 锚点」位置，不是严格意义上的左上角：`drawComplex`
	 * 里帧内点 p 落到 `(p - origin) * scale + (x, y) - offset + origin`，故左上角为
	 * `(x, y) - offset + origin * (1 - scale)`。本文件的 Image/纯色/文本分支都把 origin 置 0
	 * 且从不动 offset（flixel 5.8 的 `setGraphicSize` 不再顺手调 `updateHitbox`），此时它就是
	 * `(x, y)`；世界精灵分支带 pivot origin 且 scale 可能 ≠ 1，只有按上式换算才与画面一致。
	 */
	private static function flxSpriteTopLeft(s:FlxSprite):Vector2 {
		return new Vector2(s.x - s.offset.x + s.origin.x * (1 - s.scale.x),
			s.y - s.offset.y + s.origin.y * (1 - s.scale.y));
	}

	/**
	 * 屏幕裁剪矩形 → `s` 的**帧本地**裁剪矩形（flixel `clipRect` 的语义）。
	 *
	 * PORT-NOTE: `FlxSprite.set_frame` 里是 `frame.clipTo(clipRect, _frame)`，而
	 * `FlxFrame.clipTo` 先把参数与帧自身的 `(0, 0, frame.width, frame.height)` 求交，
	 * **不相交就把帧置成 EMPTY（整帧不画）**。因此 `clipRect` 的坐标系是「帧本地像素」，
	 * 直接把屏幕矩形赋给它，Mask 子树里的图元会全部消失（语言下拉框 `Viewport(Mask)` 下的
	 * 条目不可见的根因）。这里按 `frameLocal = (screen - 绘制左上角) / |scale|` 换算。
	 * TODO-PORT: 只按 `|scale|` 换算，未处理翻转（本文件图元的翻转走 `flipX/flipY`，
	 * 会让裁剪随帧一起镜像，属已知简化）。
	 */
	private static function clipToFrameLocal(clipScreen:unity.Rect, s:FlxSprite):flixel.math.FlxRect {
		if (clipScreen == null || s == null || clipScreen.width <= 0 || clipScreen.height <= 0)
			return null;
		var scaleX = Math.abs(s.scale.x);
		var scaleY = Math.abs(s.scale.y);
		if (scaleX < 0.0001 || scaleY < 0.0001)
			return null;
		var topLeft = flxSpriteTopLeft(s);
		return clipToFlx(new unity.Rect((clipScreen.x - topLeft.x) / scaleX, (clipScreen.y - topLeft.y) / scaleY,
			clipScreen.width / scaleX, clipScreen.height / scaleY));
	}

	/** 无贴图的 Graphic（Unity 里用 s_WhiteTexture 画纯色矩形）→ 拉伸的 1x1 白图。 */
	private function applySolid(entry:UiEntry, tint:FlxColor, needsRebuild:Bool):Void {
		if (needsRebuild || entry.kind != UiEntryKind.SolidRect) {
			// PORT-NOTE: 共享同一张 1x1 白图（Key 固定 + unique=false），染色靠 FlxSprite.color，
			// 因此几十个纯色块只占一张位图。
			entry.sprite.makeGraphic(1, 1, FlxColor.WHITE, false, WHITE_KEY);
			entry.kind = UiEntryKind.SolidRect;
			entry.lastRevision = Graphic.revision;
			entry.worldSprite = null;
		}
		entry.sprite.color = tint;
	}

	/** 文本（uGUI Text / TMPro TextMeshProUGUI）→ FlxText。 */
	private function updateText(entry:UiEntry, value:String, size:Float, tint:FlxColor, alpha:Float,
			alignment:Dynamic, wrap:Bool, richText:Bool, rect:unity.Rect, enabled:Bool, clipScreen:unity.Rect):Void {
		var label:FlxText = null;
		if (entry.kind == UiEntryKind.Label && isInstanceOf(entry.sprite, FlxText))
			label = cast entry.sprite;
		if (label == null) {
			// PORT-NOTE: 换类型时把旧的 FlxSprite 换成 FlxText。`entry.sprite` 的位置由
			// `applyOrder()` 统一重排，所以这里直接替换引用即可，不必动 FlxGroup 的成员表。
			var old = entry.sprite;
			label = new FlxText(0, 0, 0, "");
			label.origin.set(0, 0);
			entry.sprite = label;
			entry.kind = UiEntryKind.Label;
			entry.lastText = null;
			entry.lastFontSize = -1;
			entry.lastFont = null;
			textCount++;
			// PORT-NOTE: 旧的 FlxSprite 若已被 FlxGroup 持有，它现在已不在 members 里
			//（applyOrder 会用新引用覆写），销毁它。
			old.destroy();
		}
		var text = value != null ? value : "";
		if (entry.lastText != text) {
			label.text = text;
			entry.lastText = text;
		}
		var fontSize = Std.int(Math.max(1, Math.round(size)));
		var font = resolveFont(text);
		// PORT-NOTE: setFormat() 每次都会重建 TextField 的 defaultTextFormat 并重排版，
		// 只在字体或字号真的变了时才调用（每帧调会明显掉帧）。
		if (entry.lastFontSize != fontSize || entry.lastFont != font) {
			label.setFormat(font, fontSize, tint, flixelAlignment(alignment), FlxTextBorderStyle.NONE);
			entry.lastFontSize = fontSize;
			entry.lastFont = font;
		}
		label.color = tint;
		label.alpha = alpha;
		// PORT-NOTE: 赋值顺序必须是「先 fieldWidth、后 wordWrap」，依据 flixel 5.8.0 的
		// `FlxText.set_fieldWidth`（haxelib `flixel/text/FlxText.hx:559`）：对**任何正宽度**
		// 都会强制 `autoSize = false` 且 `wordWrap = true`。旧代码先 `wordWrap = false`
		// 再设 `fieldWidth`，不换行文本被静默翻回换行；同时 `regenGraphic`（同文件 :864）在
		// `textField.textHeight == 0` 时把图形高度回落到旧高度（构造后首帧只有
		// `VERTICAL_GUTTER = 4`px），36px 文字被裁成顶部一条薄片（对话框标题「语言」只剩
		// 碎片、下拉 caption 看似空框的故障即出于此）。现在正宽度只用来固定文本框宽度
		// （居中/右对齐要求 `autoSize=false`，见 `alignment` 字段的说明），换行与否由之后的
		// `wordWrap = wrap` 收口：wrap=false 时 `textField.wordWrap=false`、`_autoHeight`
		// 仍为 true ⇒ 图形高 = textHeight + 4（单行高）；wrap=true 时与旧行为一致。
		label.fieldWidth = Math.max(1, rect.width);
		label.wordWrap = wrap;
		label.alignment = flixelAlignment(alignment);
		label.origin.set(0, 0);
		label.setPosition(rect.x, rect.y);
		// PORT-NOTE: 文本节点同样要套 Mask 裁剪 —— 旧代码完全不裁剪，Mask 子树里的文字
		//（语言下拉框的条目文本、ScrollRect 的 `Viewport` 内容）会溢出遮罩区照常显示。
		// 与图元分支同理：裁剪矩形要按本 FlxText 的绘制左上角/缩放换算到帧本地坐标。
		label.clipRect = clipToFrameLocal(clipScreen, label);
		label.visible = enabled && alpha > 0.001 && text.length > 0;
		// PORT-NOTE: 文本节点也要登记命中矩形（uGUI 的 Text 带 raycastTarget 时可被射线命中）。
		// 这里用**布局矩形**而不是 FlxText 自身几何：文本的可见宽度随字数变化，
		// 而 Unity 的点击区是 RectTransform 的矩形（与文字长度无关）。
		if (entry.gameObject != null)
			renderedRectsByNode.set(entry.gameObject, rect);
	}

	/** 世界空间 TextMeshPro → 屏幕（正交相机换算，与 updateSpriteRenderer 同一套）。 */
	private function updateWorldText(entry:UiEntry, go:GameObject, tmp:TextMeshProUGUI, groupAlpha:Float):Void {
		var tr = go.transform;
		// PORT-NOTE: 同 walkWorldCanvas —— 世界坐标必须走 `worldPositionOf`（prefab 节点只写
		// `localPosition`、`position` 恒为 0 且不级联；代码写过 `position` 的节点按原值采用）。
		var pos = tr != null ? worldPositionOf(tr) : new Vector3(0, 0, 0);
		var ppu = orthographicPixelsPerUnit();
		if (ppu <= 0)
			ppu = 1;
		var cam = cameraOrigin();
		var sx = FlxG.width * 0.5 + (pos.x - cam.x) * ppu;
		var sy = FlxG.height * 0.5 - (pos.y - cam.y) * ppu;
		var ls = tr != null ? tr.lossyScale : new Vector3(1, 1, 1);
		var scaleX = ls.x == 0 ? 1 : Math.abs(ls.x);
		var scaleY = ls.y == 0 ? 1 : Math.abs(ls.y);
		// PORT-NOTE: 世界 TMP 的字号是**世界单位**，乘 ppu 得到像素字号。旧代码只做这一步，
		// 于是 `fontSize = 1.8`（Mainmenu/MainGame 的 Label/Adventure/Version 一类）
		// 变成 1.8 × 120 = 216px 的巨字。Unity 的 TMP 世界文本会被
		// enableAutoSizing / fontSizeMin / fontSizeMax 与 rect 约束，这里按同样语义收敛两级：
		//   1) `enableAutoSizing` 时先把 fontSize 钳到 [fontSizeMin, fontSizeMax]
		//     （真实 auto-size 是在 min..max 之间二分找「能塞进 rect」的字号；移植层没有 TMP
		//     的文本度量，只做区间钳制 —— TODO-PORT）；
		//   2) 再按节点 rect 高度收敛：像素字号不超过 rect 高度 × ppu × |lossyScale.y|
		//     （即字号不超过文本框高度；Unity auto-size 的结果也是这个量级）。
		var sizeUnits = tmp.fontSize;
		if (tmp.enableAutoSizing) {
			var minSize = tmp.fontSizeMin > 0 ? tmp.fontSizeMin : sizeUnits;
			var maxSize = tmp.fontSizeMax > 0 ? tmp.fontSizeMax : sizeUnits;
			sizeUnits = Math.min(Math.max(sizeUnits, minSize), maxSize);
		}
		var size = sizeUnits * ppu * scaleY;
		// 文本框按节点 RectTransform 的 rect（世界单位 → 像素）取，而不是旧代码猜的
		// `max(200, size * 12)`：rect 宽度直接决定 FlxText 的 fieldWidth（见 updateText）。
		var rt = tr != null && isInstanceOf(tr, RectTransform) ? cast(tr, RectTransform) : null;
		var w = rt != null ? Math.abs(rt.sizeDelta.x) * ppu * scaleX : 0;
		var h = rt != null ? Math.abs(rt.sizeDelta.y) * ppu * scaleY : 0;
		if (h > 0)
			size = Math.min(size, h);
		if (size < 1)
			size = 1;
		if (w < 1)
			w = Math.max(200, size * 12);
		// 没有 RectTransform 时沿用旧行为：以投影点为中心给一个足够高的文本框。
		var rect = h > 0 ? new unity.Rect(sx - w * 0.5, sy - h * 0.5, w, h)
			: new unity.Rect(sx - w * 0.5, sy - size, w, size * 2);
		var color = tmp.color;
		if (color == null)
			color = new unity.Color(1, 1, 1, 1);
		var alpha = color.a * groupAlpha;
		var tint = FlxColor.fromRGBFloat(color.r, color.g, color.b, 1);
		updateText(entry, tmp.text, size, tint, alpha, tmpAlignmentValue(tmp), tmp.enableWordWrapping, tmp.richText, rect,
			tmp.enabled, null);
	}

	/** 世界空间 SpriteRenderer → 屏幕（正交相机换算）。 */
	private function updateSpriteRenderer(entry:UiEntry, renderer:SpriteRenderer, groupAlpha:Float):Void {
		var target = renderer.renderSprite;
		if (target == null)
			return;
		// PORT-NOTE: 精灵工作包的 `renderSprite` 是**独立**的 FlxSprite；这里不能把它当本组
		// 成员重复添加（同一个 FlxSprite 属于两个组时 flixel 的绘制/相机解析会互相干扰），
		// 因此复制它的帧到本组的 sprite 上。
		var tr:Transform = renderer.transform;
		// PORT-NOTE: 世界坐标走 `worldPositionOf`（prefab 节点只写 `localPosition`、`position`
		// 恒为 0 且不级联 —— 用它会让所有 prefab 精灵（主菜单背景/按钮）叠在屏幕中心；
		// 被代码摆过的节点（实体/模型子节点等）由 worldPositionOf 原样采用其 `position`）。
		var pos = tr != null ? worldPositionOf(tr) : new Vector3(0, 0, 0);
		var scale = orthographicPixelsPerUnit();
		var origin = cameraOrigin();
		var x = FlxG.width * 0.5 + (pos.x - origin.x) * scale;
		var y = FlxG.height * 0.5 - (pos.y - origin.y) * scale;
		// 精灵原点（Unity 的 sprite.pivot）→ 屏幕左上角
		var w = target.frameWidth * (target.scale.x == 0 ? 1 : target.scale.x);
		var h = target.frameHeight * (target.scale.y == 0 ? 1 : target.scale.y);
		if (w <= 0) w = target.width;
		if (h <= 0) h = target.height;
		var left = x - target.origin.x * (target.scale.x == 0 ? 1 : target.scale.x);
		var top = y - (h - target.origin.y * (target.scale.y == 0 ? 1 : target.scale.y));

		entry.worldRenderer = renderer;
		if (entry.kind != UiEntryKind.WorldSprite || entry.worldSprite != target.frames) {
			entry.sprite.frames = target.frames;
			if (target.frame != null)
				entry.sprite.frame = target.frame;
			entry.kind = UiEntryKind.WorldSprite;
			entry.worldSprite = target.frames;
		}
		entry.sprite.origin.set(target.origin.x, target.origin.y);
		entry.sprite.scale.set(target.scale.x, target.scale.y);
		// PORT-NOTE: 旋转来自 `RenderBridge.syncOne`（每帧按 `transform.eulerAngles.z` 写）。
		// `renderSprite` 是这条链路的数据源，这里只跟随，避免两个写入者互相覆盖。
		entry.sprite.angle = target.angle;
		entry.sprite.flipX = target.flipX;
		entry.sprite.flipY = target.flipY;
		entry.sprite.color = target.color;
		entry.sprite.alpha = target.alpha * groupAlpha * renderer.alpha;
		entry.sprite.visible = renderer.enabled && target.visible;
		entry.sprite.setPosition(left, top);
		// PORT-NOTE: 世界精灵也要登记绘制矩形 —— 主菜单按钮、地图按钮的**可见内容**就是这一层，
		// 而它们的可点击节点自身没有 RectTransform（见 renderedRectsByNode 的说明）。
		if (renderer.gameObject != null)
			renderedRectsByNode.set(renderer.gameObject, flxSpriteRect(entry.sprite));
	}

	/** 正交相机的"每世界单位多少屏幕像素"。 */
	private function orthographicPixelsPerUnit():Float {
		var cam = resolveCamera();
		if (cam == null || cam.orthographicSize <= 0)
			return 1;
		return FlxG.height / (cam.orthographicSize * 2);
	}

	private function cameraOrigin():Vector3 {
		var cam = resolveCamera();
		if (cam == null || cam.transform == null)
			return new Vector3(0, 0, 0);
		// PORT-NOTE: 相机的世界坐标同样要走 `worldPositionOf`：prefab 里的相机只有 localPosition
		//（`position` 恒为 0）—— 此时旧写法让相机原点恒为世界原点，观感/换算全错；
		// 而由代码平移的相机（`MapController` 直接写 `mapCamera.transform.position`）
		// 会被 worldPositionOf 原样采用，行为不变。
		return worldPositionOf(cam.transform);
	}

	/**
	 * 场景里的主相机。
	 *
	 * PORT-NOTE: `unity.Camera.main` 在 shim 里是**惰性自建**的（不看 tag，也不看场景），
	 * 直接用它拿不到 prefab 里那个 `orthographicSize = 3` 的相机（`Main.json` 节点 267）。
	 * 这里优先在已登记的 uGUI 根里找第一个启用的 Camera 组件，找不到才回退到 `Camera.main`。
	 */
	private function resolveCamera():unity.Camera {
		if (cachedCamera != null && !cachedCamera.destroyed && cachedCamera.enabled)
			return cachedCamera;
		for (root in roots) {
			var cam = findCamera(root);
			if (cam != null) {
				cachedCamera = cam;
				return cam;
			}
		}
		cachedCamera = unity.Camera.main;
		return cachedCamera;
	}
	private var cachedCamera:unity.Camera = null;

	private function findCamera(go:GameObject):unity.Camera {
		if (go == null)
			return null;
		var cam = go.GetComponent(unity.Camera);
		if (cam != null && cam.enabled)
			return cam;
		for (child in go.transform.children) {
			if (child == null || child.gameObject == null)
				continue;
			if (!child.gameObject.active)
				continue;
			cam = findCamera(child.gameObject);
			if (cam != null)
				return cam;
		}
		return null;
	}

	// #endregion

	// #region CanvasScaler 换算

	/**
	 * `CanvasScaler` → 缩放系数（Unity `CanvasScaler.HandleScaleWithScreenSize` 的等价实现）。
	 *
	 * PORT-NOTE: 本工程的既有约定是「`Main` 场景逻辑分辨率 1280x720」（`source/Main.hx:15~16`），
	 * 而各 prefab 的 CanvasScaler 用 `referenceResolution = (800, 600)` +
	 * `ScaleWithScreenSize`；Unity 用屏幕分辨率算 scaleFactor，因此这里以 `FlxG.width/height`
	 * （即窗口的 1280x720 逻辑分辨率）为屏幕尺寸，得到 GlobalUICanvas 的 1.6（matchWidthOrHeight=0）
	 * 与 MainGame Canvas 的 1.2（matchWidthOrHeight=1）。
	 * `ScreenMatchMode`：MatchWidthOrHeight 用几何插值；Expand 取较小比例；Shrink 取较大比例。
	 */
	public static function computeScaleFactor(scaler:CanvasScaler):Float {
		if (scaler == null)
			return 1;
		if (scaler.uiScaleMode == ScaleMode.ConstantPixelSize)
			return scaler.scaleFactor != 0 ? scaler.scaleFactor : 1;
		if (scaler.uiScaleMode == ScaleMode.ConstantPhysicalSize)
			// TODO-PORT: 物理尺寸模式（DPI 换算）在移植层没有 DPI 来源，退化为 1。
			return 1;
		var ref = scaler.referenceResolution;
		if (ref == null || ref.x <= 0 || ref.y <= 0)
			return 1;
		var logWidth = Math.log(FlxG.width / ref.x) / Math.log(2);
		var logHeight = Math.log(FlxG.height / ref.y) / Math.log(2);
		return switch (scaler.screenMatchMode) {
			case Expand:
				Math.min(FlxG.width / ref.x, FlxG.height / ref.y);
			case Shrink:
				Math.max(FlxG.width / ref.x, FlxG.height / ref.y);
			default:
				// Unity: scaleFactor = Mathf.Pow(2, Mathf.Lerp(logWidth, logHeight, matchWidthOrHeight))
				Math.pow(2, logWidth + (logHeight - logWidth) * scaler.matchWidthOrHeight);
		}
	}

	// #endregion

	// #region 小工具

	/** TMP 导出数据里的 alignment 哨兵值 = `TextAlignmentOptions.Converted`（0xFFFF）。 */
	private static inline var TMP_ALIGNMENT_SENTINEL:Int = 65535;

	/**
	 * TMP 组件**真正生效**的对齐值（供 flixelAlignment 换算）。
	 *
	 * PORT-NOTE: 导出数据里 TMP 的 `alignment` 字段恒为 65535（`TextAlignmentOptions.Converted`
	 * 哨兵，全部 1185 个 TMP 文本组件实测如此），真正的对齐在
	 * `horizontalAlignment`（1=Left / 2=Center / 4=Right / 8=Justified / 16=Flush，
	 * 见 `unity/tmpro/TextMeshProUGUI.hx:134`）与 `verticalAlignment`
	 * （256=Top / 512=Middle / 1024=Bottom）里。旧代码直接拿 `alignment`：
	 * `65535 & 0xFF = 255`，落进 flixelAlignment 的默认分支（LEFT），于是标题等
	 * 居中文本全部贴左。这里在哨兵情况下按 TMP 源码的位域约定把两个字段合成
	 * （水平在低 8 位、垂直自 0x100 起），flixelAlignment 既有的低 8 位映射即可复用。
	 */
	private static function tmpAlignmentValue(tmp:TextMeshProUGUI):Dynamic {
		if (tmp == null)
			return null;
		var a:Dynamic = tmp.alignment;
		if (a != null && (cast a:Int) == TMP_ALIGNMENT_SENTINEL) {
			// PORT-NOTE: `| 0x100`（Top 位）只是把合成值顶到 >8 的域里，避免
			// verticalAlignment==0 时（合成值可能 ≤8）被 flixelAlignment 的
			// `v <= 8` 分支误判成 unity.TextAnchor；OR 不动低 8 位，水平判定不受影响。
			return tmp.horizontalAlignment | tmp.verticalAlignment | 0x100;
		}
		return a;
	}

	private function flixelAlignment(alignment:Dynamic):flixel.text.FlxText.FlxTextAlign {
		// PORT-NOTE: TextAnchor 与 TMPro.TextAlignmentOptions 的取值不同（前者 0..8，
		// 后者是 256/512/… 的位标志），因此按各自规则换算到 Flixel 的 left/center/right。
		if (alignment == null)
			return flixel.text.FlxText.FlxTextAlign.LEFT;
		var v:Int = cast alignment;
		if (v <= 8) {
			// unity.TextAnchor
			return switch (v) {
				case 1, 4, 7: flixel.text.FlxText.FlxTextAlign.CENTER;
				case 2, 5, 8: flixel.text.FlxText.FlxTextAlign.RIGHT;
				default: flixel.text.FlxText.FlxTextAlign.LEFT;
			}
		}
		// TMPro.TextAlignmentOptions：低 8 位是水平对齐（Left=1/Center=2/Right=4/…）
		var h = v & 0xFF;
		if (h == 2 || h == 8 || h == 32)
			return flixel.text.FlxText.FlxTextAlign.CENTER;
		if (h == 4 || h == 16)
			return flixel.text.FlxText.FlxTextAlign.RIGHT;
		return flixel.text.FlxText.FlxTextAlign.LEFT;
	}

	/**
	 * 文本用的字体资源 id。
	 *
	 * PORT-NOTE: TMP 的 `font`（TMP_FontAsset）在移植层没有解析来源（prefab 里是
	 * `Fonts/mojangles/minecraft_font.asset`，`ResourceManifest` 按 ScriptableObject 返回原始字节），
	 * 因此这里按**文本内容**挑字体：含非 ASCII（中文/日文等）用 unifont（覆盖 BMP），
	 * 否则用 minecraft_font（像素字体，与原版观感一致）。两个 .otf 都已由 Project.xml 的
	 * `<assets path="assets"/>` 打进可执行文件（lime 资源库，id 见下方候选表）。
	 * TODO-PORT: 等 TMP 字体资产转换落地后，改为按 `TextMeshProUGUI.font` 的 guid 解析。
	 */
	private function resolveFont(text:String):String {
		var cjk = false;
		if (text != null) {
			for (i in 0...text.length) {
				if (text.charCodeAt(i) > 0x7F) {
					cjk = true;
					break;
				}
			}
		}
		var candidates = cjk
			? ["assets/Fonts/unifont.otf", "Fonts/unifont.otf"]
			: ["assets/Fonts/mojangles/minecraft_font.otf", "Fonts/mojangles/minecraft_font.otf"];
		for (id in candidates) {
			try {
				if (openfl.utils.Assets.exists(id, openfl.utils.AssetType.FONT))
					return id;
			} catch (e:Dynamic) {}
		}
		return null;
	}

	private static function clipToFlx(clip:unity.Rect):flixel.math.FlxRect {
		if (clip == null || clip.width <= 0 || clip.height <= 0)
			return null;
		return flixel.math.FlxRect.get(clip.x, clip.y, clip.width, clip.height);
	}

	/**
	 * 沿继承链判断 `obj` 是否是 `cls`（或其子类）的实例。
	 *
	 * PORT-NOTE: 不用 `Std.isOfType(obj, cls)` 的原因见 `updateGraphic` 里 Image 分支的说明：
	 * hxcpp 会把 `Std.isOfType(x, ClassOf<T>())` 优化成 `isOfType(x, <类索引常量>)`，
	 * 该常量在**同一模块声明多个类**时会取错（实测 `unity.ui.Image` 判定恒为 false）。
	 * `Type.getClass` + `Type.getSuperClass` 走的是类对象本身，与模块布局无关，语义明确。
	 */
	private static function isInstanceOf(obj:Dynamic, cls:Class<Dynamic>):Bool {
		if (obj == null || cls == null)
			return false;
		var c = Type.getClass(obj);
		var guard = 0;
		while (c != null && guard++ < 32) {
			if (c == cls)
				return true;
			c = Type.getSuperClass(c);
		}
		return false;
	}

	/** 节点的层级路径（诊断用，如 `MainGame/MainScene/UI/Dialogs/CustomDialog/Root/Background`）。 */
	private function nodePath(go:GameObject):String {
		if (go == null)
			return "(null)";
		var parts:Array<String> = [];
		var tr:Transform = go.transform;
		var guard = 0;
		while (tr != null && guard++ < 32) {
			parts.unshift(tr.gameObject != null ? tr.gameObject.name : "?");
			tr = tr.parent;
		}
		return parts.join("/");
	}

	/** 精灵的可读描述（诊断用）。 */
	private function spriteName(sprite:unity.Sprite):String {
		if (sprite == null)
			return "null";
		var rect = sprite.rect;
		return '${sprite.name}(rect=${rect.x},${rect.y},${rect.width},${rect.height}'
			+ ' tex=${sprite.texture != null ? (sprite.texture.name != null ? sprite.texture.name : "?") : "null"})';
	}

	private function intersectClip(current:unity.Rect, next:unity.Rect):unity.Rect {
		if (current == null)
			return next;
		var x = Math.max(current.x, next.x);
		var y = Math.max(current.y, next.y);
		var x2 = Math.min(current.x + current.width, next.x + next.width);
		var y2 = Math.min(current.y + current.height, next.y + next.height);
		return new unity.Rect(x, y, Math.max(0, x2 - x), Math.max(0, y2 - y));
	}

	// #endregion
}

typedef HitCandidate = {
	gameObject:GameObject,
	handlers:Array<Dynamic>,
	hasRectTransform:Bool,
	rect:unity.Rect,
	order:Int
};

typedef HitTarget = {
	gameObject:GameObject,
	handlers:Array<Dynamic>,
	rect:unity.Rect,
	order:Int,
	isButton:Bool
};

typedef UiEntry = {
	gameObject:GameObject,
	sprite:FlxSprite,
	kind:UiEntryKind,
	lastRevision:Int,
	lastText:String,
	lastRect:unity.Rect,
	/** 上次绑定过的资源对象（精灵/帧集合），用于判断是否需要重设 frames。 */
	worldSprite:Dynamic,
	/** 上次应用到 FlxText 的字号 / 字体资源 id（避免每帧重排版）。 */
	lastFontSize:Int,
	lastFont:String,
	/** 本帧未出现在遍历结果里（未激活或已销毁）；重新出现时恢复。 */
	retired:Bool,
	/** 上次被遍历到的帧序号。 */
	lastSeenFrame:Int,
	/** 该项对应的 SpriteRenderer（非 null 时参与排序层排序）。 */
	worldRenderer:SpriteRenderer,
	/**
	 * 画布分层权重（Unity 的 Canvas 渲染顺序）：0 = 世界空间画布/无画布，1 = ScreenSpaceOverlay。
	 *
	 * PORT-NOTE: Unity 里 ScreenSpaceOverlay 画布**永远画在世界空间画布之上**（与层级顺序无关）。
	 * 移植层把所有 Graphic 放进同一个 FlxGroup、按深度优先层级顺序绘制，于是挂在
	 * `MainGame/MainScene/UI`（Overlay 画布）下的对话框会被后遍历的 `Mainmenu`（世界空间画布）
	 * 盖住 —— InputNameDialog 在首 run 完全不显示就是这个原因。applyOrder 按本字段稳定分区：
	 * 0 在前、1 在后（同组内保持层级顺序与排序层排序结果）。
	 */
	overlayRank:Int
};

// PORT-NOTE: 枚举成员刻意**不叫** `Image` / `Text` / `Solid` / `SpriteRenderer`。
// Haxe 的模块作用域会把它们提升为模块级名字，从而**遮蔽**同名的类
//（`unity.ui.Image`、`unity.ui.Text`、`unity.SpriteRenderer`）——
// `Std.isOfType(c, Text)` 于是变成拿整数比较，判定恒为 false。
// 这正是「18 个 Image 全部退化成 1×1 白块」的根因（详见 renderNode 的 PORT-NOTE）。
enum abstract UiEntryKind(Int) {
	var Empty = 0;
	var ImageGraphic = 1;
	var SolidRect = 2;
	var Label = 3;
	var WorldSprite = 4;
}

/** 布局帧（见 UiRenderer.frameFor 的说明）。 */
typedef LayoutFrame = {
	canvasScale:Float,
	ownScale:Float,
	/** 该节点局部单位 → 屏幕像素的比例（canvasScale * 各级 ownScale）。 */
	scale:Float,
	origin:Vector2,
	local:unity.Rect,
	clip:unity.Rect
};

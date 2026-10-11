package mvz2.grids;

// PORT-NOTE: FlxTypedSignal 是 flixel.util.FlxSignal 模块内的次类型，需从所属模块导入。
import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.io.Bytes;
import mvz2.managers.MainManager;
import mvz2.models.Model;
import mvz2.models.ModelBuilder;
import mvz2.ui.level.HPBar.HPBarViewData;
import mvz2.ui.level.HPBarList;
import mvz2.ui.level.IHPBarSource;
import mvz2.ui.level.ILevelRaycastReceiver;
// PORT-NOTE: GridView 就在同包 mvz2.grids 下（C# 原命名空间为 MVZ2.UI.Level），无需 import。
import mvz2.vanilla.grids.VanillaGridLayers;
import mvz2logic.entities.HPBarVisibility;
import mvz2logic.helditems.HeldItemTargetGrid;
import mvz2logic.helditems.HeldItemDefinition;
import mvz2logic.helditems.IHeldItemData;
import mvz2logic.inputs.InputHelper;
import mvz2logic.options.HPBarAmountMode;
import pvzengine.entities.Entity;
import pvzengine.grids.LawnGrid;
import pvzengine.level.LevelEngine;
import pvzengine.models.ModelInsertion;
import unity.Color;
import unity.eventsystems.PointerEventData;
import unity.Sprite;
import unity.Vector2;
import unity.Vector3;
import unity.MonoBehaviour;
import mvz2.level.LevelController;
import mvz2.options.OptionsManager;
import mvz2.scenes.ScenePrefabInjector;
import mvz2.ui.level.HPBar;
import mvz2logic.inputs.PointerInteraction;
import Main;
// PORT-NOTE: C# 的扩展方法（this 参数形式）在 Haxe 中需显式 using 才能以 `obj.Method()` 调用。
using mvz2logic.entities.LogicEntityProps;         // GetHPBarVisibility(this Entity)
using mvz2logic.games.LogicGameDefinitionsExt;     // GetGridLayerDefinition(this IGameContent)
using mvz2logic.options.LogicOptionExt;            // GetHPBarAmountMode(this IGlobalOptions)

// Ported from: Assets/Scripts/MVZ2/Grids/GridController.cs
class GridController extends MonoBehaviour implements ILevelRaycastReceiver {
    // #region 生命周期
    private function Awake():Void {
        // PORT-NOTE: `view` 是 [SerializeField]（prefab 注入）。数据缺失时 `view.OnPointerInteraction`
    // 会空引用；Awake 里不做防御会直接段错误（release 无空指针检查）。这里保持 C# 的调用结构，
    // 但先做一次兜底解析（同 GameObject 上的 GridView）。
        if (view == null && gameObject != null)
            view = gameObject.GetComponent(GridView);
        if (view != null)
            view.OnPointerInteraction.add((view, pointer, interaction) -> OnPointerInteraction.dispatch(this, pointer, interaction));
        hpBarSource = new GridHPBarSource(this);
    }
    public function Init(data:GridInitData):Void {
        Level = data.levelController;
        grid = data.grid;
        view.BuildModel(data.modelBuilder);

        grid.OnModelInsertionAdded.add(OnModelInsertionAddedCallback);
        grid.OnModelInsertionRemoved.add(OnModelInsertionRemovedCallback);
        UpdateModelInsertions();

        Level.AddHPBarSource(hpBarSource);
    }
    public function GetLawnGrid():LawnGrid {
        return grid;
    }
    public function UpdateFixed():Void {
        view.UpdateFixed();
    }
    public function UpdateFrame(deltaTime:Float):Void {
        view.UpdateFrame(deltaTime);

        if (grid != null) {
            var sortingLayer = grid.GetSortingLayer();
            view.SetModelSortingLayerAndOrder(sortingLayer != null ? sortingLayer : "", grid.GetSortingOrder());
        }
    }
    // #endregion

    // #region 显示
    public function UpdateGridController(data:GridControllerData):Void {
        view.SetPosition(data.position);
        view.SetSprite(data.sprite);
        // PORT-NOTE: 这里第一次用到 `size`（SetDisplaySection/SetColliderBevel/后续拾取换算），
        // 数据缺失时先兜底，避免零尺寸传播成 Inf/NaN。
        ensureSize(this);
        SetBevel(data.slope);
        SetDisplaySection(0, 1);
    }
    // #endregion

    // #region 设置属性
    public function SetColor(color:Color):Void {
        view.SetColor(color);
    }
    public function SetDisplaySection(start:Float, end:Float):Void {
        view.SetDisplaySection(start, end, size, BevelHeight);
    }
    public function SetBevel(height:Float):Void {
        view.SetColliderBevel(size, height);
        BevelHeight = height;
    }
    // #endregion

    // #region 坐标转换
    public function TransformWorld2ColliderPosition(worldPosition:Vector3):Vector2 {
        // PORT-NOTE: 拾取换算对 `size` 是硬依赖（下面三处除法），数据缺失时先兜底再算，
        // 否则 `slope`/`colliderX`/`colliderY` 会是 Inf/NaN（见 ensureSize 的说明）。
        ensureSize(this);
        var pos2D = new Vector2(transform.position.x, transform.position.y);
        var lossyScale = new Vector2(transform.lossyScale.x, transform.lossyScale.y);
        var lossySize = Vector2.Scale(size, lossyScale);
        var slope = BevelHeight / size.x;

        var origin = pos2D - lossySize * 0.5;
        var relativeWorldPos = new Vector2(worldPosition.x, worldPosition.y) - origin;
        var colliderX = relativeWorldPos.x / lossySize.x;

        var yOffset = slope * relativeWorldPos.x;
        var colliderY = (relativeWorldPos.y + yOffset) / lossySize.y;

        return new Vector2(colliderX, colliderY);
    }
    // #endregion

    // #region 模型
    public function GetModel():Model {
        return view.GetModel();
    }
    private function UpdateModelInsertions():Void {
        if (grid != null)
            view.UpdateModelInsertions(grid.GetModelInsertions());
    }
    private function OnModelInsertionAddedCallback(insertion:ModelInsertion):Void {
        var model = GetModel();
        if (model != null)
            model.AddModelInsertion(insertion);
    }
    private function OnModelInsertionRemovedCallback(insertion:ModelInsertion):Void {
        var model = GetModel();
        if (model != null)
            model.RemoveModelInsertion(insertion.key);
    }
    // #endregion

    // #region ILevelRaycasterReceiver接口实现
    public function IsValidReceiver(level:LevelEngine, definition:HeldItemDefinition, data:IHeldItemData, eventData:PointerEventData):Bool {
        if (definition == null)
            return false;
        var grid = level.GetGrid(Column, Lane);
        if (grid == null)
            return false;
        var worldPosition = eventData.pointerCurrentRaycast.worldPosition;
        var screenPosition = eventData.pointerCurrentRaycast.screenPosition;
        var localPointerPosition = TransformWorld2ColliderPosition(worldPosition);
        var target = new HeldItemTargetGrid(grid, localPointerPosition, screenPosition);
        var pointer = InputHelper.GetPointerDataFromEventData(eventData);
        return definition.IsValidFor(target, data, pointer);
    }
    public function GetSortingLayer():Int {
        return view.GetSortingLayerID();
    }
    public function GetSortingOrder():Int {
        return view.GetSortingOrder();
    }
    // #endregion

    // #region 序列化
    public function ToSerializable():SerializableGridController {
        var model = GetModel();
        return new SerializableGridController({
            model: model != null ? model.ToSerializable() : null
        });
    }
    public function LoadFromSerializable(seri:SerializableGridController):Void {
        var model = GetModel();
        if (seri.model != null && model != null) {
            model.LoadFromSerializable(seri.model);
            model.UpdateFrame(0);
            UpdateModelInsertions();
        }
    }
    // #endregion


    public var OnPointerInteraction:FlxTypedSignal<GridController->PointerEventData->PointerInteraction->Void> = new FlxTypedSignal();

    public var Main(get, never):MainManager;
    inline function get_Main():MainManager return MainManager.Instance;

    public var Level(default, null):mvz2.level.LevelController;
    public var Lane:Int;
    public var Column:Int;
    public var BevelHeight(default, null):Float;
    private var grid:LawnGrid;
    private var hpBarSource:IHPBarSource = null;
    @:serializeField
    private var view:GridView = null;
    @:serializeField
    private var size:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 null 解引用（该字段在 Unity 由 prefab 序列化赋值，移植层由 prefab 数据覆盖）

    /**
     * `size` 的兜底真值（prefab 数据缺失时用）。
     *
     * PORT-NOTE: C# 里 `size` 由 `Assets/Prefabs/Level/Grid.prefab` 序列化注入
     * （`size: {x: 0.8, y: 0.8}`；`Lane.prefab` 的 ElementList 以它为模板，所以每个格子都是 0.8）。
     * 移植层若在数据注入之前读它（手工构造对象图，或 prefab 数据缺失），会拿到 (0,0)：
     *   * `TransformWorld2ColliderPosition` 的 `slope = BevelHeight / size.x` 除零 → Inf/NaN；
     *   * `lossySize.x/y` 为 0 → `colliderX/colliderY` 为 Inf/NaN → 格子拾取判定全错。
     * `ensureSize` 在首次使用时惰性补上真值：优先取 prefab 数据（`ScenePrefabInjector`），
     * 取不到才退回与 prefab 一致的常量。
     *
     * TODO-PORT: 这是「prefab 数据未接入时的安全兜底」；`ScenePrefabLoader` 正式接管关卡构建后，
     * 该兜底只会在数据缺失时生效（等价于 Unity 缺资产时的行为，但不会除零）。
     */
    public static inline var DEFAULT_SIZE:Float = 0.8;

    public static function ensureSize(grid:GridController):Void {
        if (grid == null || grid.size == null)
            return;
        if (grid.size.x != 0 && grid.size.y != 0)
            return;
        if (ScenePrefabInjector.ApplyGridSize(grid))
            return;
        grid.size = new Vector2(DEFAULT_SIZE, DEFAULT_SIZE);
    }
}

class GridInitData {
    public var levelController:mvz2.level.LevelController;
    public var grid:LawnGrid;
    public var modelBuilder:ModelBuilder;

    public function new() {}
}

class GridControllerData {
    public var position:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    public var sprite:Sprite;
    public var slope:Float;

    public function new() {}
}

@:rtti
class SerializableGridController {
    public var model:Dynamic;

    public function new(?fields:{model:Dynamic}) {
        if (fields != null) model = fields.model;
    }
}

class GridHPBarSource implements IHPBarSource {
    public function new(controller:GridController) {
        Controller = controller;
    }

    public function IsActive():Bool {
        if (Controller == null)
            return false;
        if (Controller.Level == null)
            return false;
        if (Controller.GetLawnGrid() == null)
            return false;
        return true;
    }
    public function GetPosition():Vector3 {
        return Controller.transform.position;
    }
    public function UpdateHPBarList(list:HPBarList):Void {
        list.gameObject.name = Controller.gameObject.name;

        gridHPBarEntityBuffer = [];
        gridHPBarBuffer = [];
        GetHPBarViewDatas();

        list.SetBarCount(gridHPBarBuffer.length);
        for (i in 0...gridHPBarBuffer.length) {
            list.UpdateBar(i, gridHPBarBuffer[i]);
        }
    }
    private function GetHPBarViewDatas():Void {
        var level = Controller.Level;
        var grid = Controller.GetLawnGrid();
        if (grid == null)
            return;

        var amountMode = Main.OptionsManager.GetHPBarAmountMode();

        var shouldShow = level != null ? level.ShouldShowHPBars() : false;
        var layers = Lambda.array(grid.GetLayers());
        layers.sort(function(a, b) {
            return VanillaGridLayers.normalLayerOrders.indexOf(a) - VanillaGridLayers.normalLayerOrders.indexOf(b);
        });
        for (layer in layers) {
            var layerDefinition = Main.Game.GetGridLayerDefinition(layer);
            var entities = grid.GetLayerEntities(layer);
            for (entity in entities) {
                if (entity == null)
                    continue;
                var visibility = entity.GetHPBarVisibility();
                if (visibility == HPBarVisibility.HIDDEN)
                    continue;
                if (!shouldShow && visibility != HPBarVisibility.FORCE)
                    continue;
                if (entity.GetGrid() != grid)
                    continue;
                if (gridHPBarEntityBuffer.contains(entity))
                    continue;
                var entityCtrl = level != null ? level.GetEntityController(entity) : null;
                if (entityCtrl == null || !entityCtrl.ShouldShowMainHPBar() || entityCtrl.ShouldShowHPBarOnEntity())
                    continue;
                var barColor = layerDefinition != null ? layerDefinition.HPBarColor : Color.red;
                var amount = entityCtrl.GetMainHPBarAmount();
                var text = entityCtrl.GetMainHPBarText(amountMode);
                // PORT-NOTE: C# 的重载 Main.GetFinalSprite(SpriteReference) 在 Haxe 中改名为 GetFinalSpriteFromRef。
                var icon = Main.GetFinalSpriteFromRef(layerDefinition != null ? layerDefinition.HPBarIcon : null);
                gridHPBarBuffer.push(new HPBarViewDataData(barColor, amount, text, icon));
                gridHPBarEntityBuffer.push(entity);
            }
        }
    }
    public var Main(get, never):MainManager;
    inline function get_Main():MainManager return MainManager.Instance;

    public var Controller(default, null):GridController;
    // PORT-NOTE: C# `HashSet<Entity>` → Array used as a set (order is irrelevant here).
    private var gridHPBarEntityBuffer:Array<Entity> = [];
    private var gridHPBarBuffer:Array<HPBarViewData> = [];
}

// PORT-NOTE: helper so the HPBarViewData fields can be filled positionally; the C# code uses an
// object initializer.
private class HPBarViewDataData extends HPBarViewData {
    public function new(barColor:Color, barAmount:Float, text:String, icon:Sprite) {
        super();
        this.barColor = barColor;
        this.barAmount = barAmount;
        this.text = text;
        this.icon = icon;
    }
}

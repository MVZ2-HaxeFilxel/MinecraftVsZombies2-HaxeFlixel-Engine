// Ported from: Assets/Scripts/MVZ2/Entities/EntityController.cs
package mvz2.entities;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2.level.LevelController;
import mvz2.level.LevelController.AnimatorUpdateData;
import mvz2.managers.MainManager;
import mvz2.metas.ModelArmorConfigMeta;
import mvz2.models.EntityModel;
import mvz2.models.ModelBuilder;
import mvz2.models.Model.SerializableModelData;
import mvz2.ui.ITooltipAnchor;
import mvz2.ui.ITooltipTarget;
import mvz2.ui.TooltipAnchor;
import mvz2.ui.level.IHPBarSource;
import mvz2.ui.level.ILevelRaycastReceiver;
import mvz2.view.level.HeightIndicatorController;
import mvz2.view.level.LevelPointerInteractionHandler;
import mvz2.view.level.ShadowController;
import mvz2logic.Global;
import mvz2logic.armors.LogicArmorSlots;
import mvz2logic.cursor.CursorSource;
import mvz2logic.cursor.CursorType;
import mvz2logic.entities.LogicEnemyStates;
import mvz2logic.entities.LogicEntityProps;
import mvz2logic.helditems.HeldItemDefinition;
import mvz2logic.helditems.HeldItemTargetEntity;
import mvz2logic.helditems.HeldTargetFlag;
import mvz2logic.helditems.HeldTargetFlagHelper;
import mvz2logic.helditems.IHeldItemData;
import mvz2logic.inputs.InputHelper;
import mvz2logic.inputs.PointerInteraction;
import mvz2logic.models.SortingLayers.ShaderProperties;
import mvz2logic.options.HPBarAmountMode;
import pvzengine.EntityTypes;
import pvzengine.IPropertyKey;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.armors.Armor;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
import pvzengine.models.IModelInterface;
import pvzengine.models.ModelInsertion;
import pvzengine.modifiers.BlendOperator;
// PORT-NOTE: 原 import 写作 tools.ColorCalculator；类实际声明在 pvzengine/modifiers/ColorCalculator.hx。
import pvzengine.modifiers.ColorCalculator;
import tools.RandomGenerator;
// PORT-NOTE: 原 import 写作 tools.Ticks，但 C# 的 Ticks.GetTPS() 来自 PVZEngine（Assets/Scripts/Engine/Level/Ticks.cs），
// 对应 Haxe 的 pvzengine.Ticks（tools.Ticks 是外部 Tools 程序集的移植，只有 TICKS_PER_SECOND/SmoothDamp）。
import pvzengine.Ticks;
import unity.Animator;
import unity.BoxCollider2D;
import unity.Color;
import unity.Mathf;
import unity.SortingLayer;
import unity.UnityObject;
import unity.Vector2;
import unity.Vector3;
import unity.Vector4;
import unity.eventsystems.PointerEventData;
import mvz2.cursors.CursorManager;
import mvz2.inputs.InputManager;
import mvz2.localization.LanguageManager;
import mvz2.managers.ResourceManager;
import mvz2.models.MVZ2ModelExt;
import mvz2.options.OptionsManager;
import mvz2logic.models.SortingLayers;
import mvz2logic.options.LogicOptionExt;
import pvzengine.base.Definition;
import unity.Collider;
import unity.MonoBehaviour;
import mvz2.models.Model;
import unity.ui.Shadow;
import Main;

using mvz2.models.MVZ2ModelExt;
using mvz2logic.entities.LogicEnemyProps;
using mvz2logic.entities.LogicEntityExt;
using mvz2logic.entities.LogicEntityProps;
using mvz2logic.games.LogicGameDefinitionsExt;
using mvz2logic.inputs.InputHelper;
using mvz2logic.options.LogicOptionExt;

// PORT-NOTE: C# 的 EntityController 属性名（Model/Entity/Level）与同名类型重名；
// Haxe 的类型与值处于不同命名空间，故照原样保留属性名。
class EntityController extends unity.MonoBehaviour implements ILevelRaycastReceiver implements ITooltipTarget {
    // #region 公有方法
    public function Init(level:LevelController, entity:Entity):Void {
        Level = level;
        Entity = entity;
        rng = new RandomGenerator(entity.InitSeed);
        isHighlight = false;
        gameObject.name = Std.string(entity);
        transform.position = Level.LawnToTrans(Entity.Position);
        lastPosition = transform.position;

        entity.PostInit.add(PostInitCallback);
        entity.PostPropertyChanged.add(PostPropertyChangedCallback);
        entity.OnChangeModel.add(OnChangeModelCallback);
        entity.OnModelInsertionAdded.add(OnModelInsertionAddedCallback);
        entity.OnModelInsertionRemoved.add(OnModelInsertionRemovedCallback);

        entity.OnEquipArmor.add(OnArmorEquipCallback);
        entity.OnRemoveArmor.add(OnArmorRemoveCallback);

        // PORT-NOTE: hpBarSource 原在 Awake 创建，但移植层的 UnityObject.Instantiate 不派发
        // Awake（CreateControllerForEntity → Instantiate 模板后直接 Init），Unity 里 Instantiate
        // 是会调 Awake 的。这里按需补建：null 时 AddHPBarSource 会把 null 当 Map 键，
        // 之后 UpdateHPBars 遍历 buffer 调 IsActive() 直接空引用。
        if (hpBarSource == null)
            hpBarSource = new EntityHPBarSource(this);
        Level.AddHPBarSource(hpBarSource);
        holdStreakHandler.ResetData();
        RemoveCursorSource();

        entity.SetModelInterface(bodyModelInterface);
        SetModel(Entity.ModelID);
        if (UnityObject.exists(Model)) {
            ClearAllArmorModels();
            var lvl = Entity.Level;
            var heldItemDef = lvl.GetHeldItemDefinition();
            UpdateModelColliderActive(heldItemDef != null ? heldItemDef.GetHeldTargetMask(lvl) : HeldTargetFlag.None);
        }
    }
    public function RemoveEntity():Void {
        Entity.PostInit.remove(PostInitCallback);
        Entity.PostPropertyChanged.remove(PostPropertyChangedCallback);
        Entity.OnChangeModel.remove(OnChangeModelCallback);
        Entity.OnModelInsertionAdded.remove(OnModelInsertionAddedCallback);
        Entity.OnModelInsertionRemoved.remove(OnModelInsertionRemovedCallback);

        Entity.OnEquipArmor.remove(OnArmorEquipCallback);
        Entity.OnRemoveArmor.remove(OnArmorRemoveCallback);
        Entity.SetModelInterface(null);
        Level.RemoveHPBarSource(hpBarSource);
    }

    // #region 模型
    public function SetModel(modelId:NamespaceID):Void {
        if (UnityObject.exists(Model)) {
            UnityObject.destroy(Model.gameObject);
            Model.OnUpdateFrame.remove(OnModelUpdateFrameCallback);
            Model = null;
        }
        var builder = new ModelBuilder(modelId, Level.GetCamera(), Entity.InitSeed);
        var model = builder.Build(transform);
        Model = cast model;
        if (!UnityObject.exists(Model))
            return;
        Model.OnUpdateFrame.add(OnModelUpdateFrameCallback);
        modelPropertyCache.UpdateAll(this);
        Model.UpdateFrame(0);
        Model.UpdateAnimators(0);
        UpdateModelInsertions();

        // 重新创建护甲模型
        for (slot in Entity.GetActiveArmorSlots()) {
            var armor = Entity.GetArmorAtSlot(slot);
            if (armor != null) {
                CreateArmorModel(slot, armor);
            }
        }
    }
    public function SetSimulationSpeed(simulationSpeed:Float):Void {
        if (UnityObject.exists(Model)) {
            Model.SetSimulationSpeed(simulationSpeed);
        }
    }
    // #endregion

    // #region 更新
    public function UpdateFixed():Void {
        renderAccumulator = 0;
        if (UnityObject.exists(Model)) {
            Model.UpdateFixed();
        }
        holdStreakHandler.UpdateHoldAndStreak();
    }
    public function UpdateFrame(deltaTime:Float):Void {
        // 1. 累加渲染时间（deltaTime 来源于系统的每帧耗时）
        renderAccumulator += deltaTime;

        // 避免极端情况下累加器溢出（比如切出游戏后返回）
        renderAccumulator = Mathf.Min(renderAccumulator, maxRenderAccumulator);

        transform.position = GetInterpolatedTransformPosition();
        UpdateShadow();
        UpdateHeightIndicator();
        lastPosition = transform.position;

        var shouldTwinkle = ShouldTwinkle();
        if (twinkling != shouldTwinkle) {
            twinkling = shouldTwinkle;
            modelPropertyCache.SetDirtyProperty(PropertyName.Tint);
        } else if (twinkling) {
            modelPropertyCache.SetDirtyProperty(PropertyName.Tint);
        }
        if (UnityObject.exists(Model)) {
            Model.UpdateFrame(deltaTime);
        }
    }
    public function UpdateAnimators(deltaTime:Float):Void {
        if (UnityObject.exists(Model)) {
            Model.UpdateAnimators(deltaTime);
        }
    }
    public function GetAnimatorsToUpdate(results:Array<AnimatorUpdateData>):Void {
        if (UnityObject.exists(Model)) {
            animatorBuffer = [];
            Model.GetAnimatorsToUpdate(animatorBuffer);
            for (animator in animatorBuffer) {
                results.push(new AnimatorUpdateData(animator, Entity.GetAnimationSpeed()));
            }
        }
    }
    // #endregion

    public function UpdateModelColliderActive(flag:HeldTargetFlag):Void {
        if (Std.isOfType(Model, EntityModel)) {
            var sprModel:EntityModel = cast Model;
            var heldTargetFlag = HeldTargetFlagHelper.GetHeldTargetFlagByType(Entity.Type);
            sprModel.SetColliderActive((flag & heldTargetFlag) != HeldTargetFlag.None);
        }
    }
    public function SetHighlight(highlight:Bool):Void {
        isHighlight = highlight;
        modelPropertyCache.SetDirtyProperty(PropertyName.ColorOffset);
    }
    public function IsHovered():Bool return holdStreakHandler.IsHovered();
    public function IsPressed():Bool return holdStreakHandler.IsPressed();
    public function GetHoveredPointerCount():Int return holdStreakHandler.GetHoveredPointerCount();
    public function GetHoveredPointerEventData(index:Int):PointerEventData return holdStreakHandler.GetHoveredPointerEventData(index);
    public function TransformWorld2ColliderPosition(worldPosition:Vector3):Vector2 {
        var spriteModel:EntityModel = Model;
        if (spriteModel == null)
            return Vector2.zero;
        var collider = spriteModel.Collider;
        if (!Std.isOfType(collider, BoxCollider2D))
            return Vector2.zero;
        var boxCollider:BoxCollider2D = cast collider;
        // PORT-NOTE: unity.Transform shim 未提供 TransformDirection；
        // 这里按 Unity 语义（只应用旋转，不含位移与缩放）用 localRotation 变换方向。
        var colliderTransform = collider.transform;
        var localOffset = new Vector3(collider.offset.x, collider.offset.y, 0);
        var direction = colliderTransform.localRotation * localOffset;
        var colliderPosition = colliderTransform.position + direction;
        var pos2D = new Vector2(colliderPosition.x, colliderPosition.y);
        var scale3 = colliderTransform.lossyScale;
        var lossyScale = new Vector2(scale3.x, scale3.y);
        var size = boxCollider.size;
        var lossySize = Vector2.Scale(size, lossyScale);
        var origin = pos2D - lossySize * 0.5;

        var relativeWorldPos = new Vector2(worldPosition.x, worldPosition.y) - origin;
        var colliderX = relativeWorldPos.x / lossySize.x;
        var colliderY = relativeWorldPos.y / lossySize.y;

        return new Vector2(colliderX, colliderY);
    }
    public function GetInterpolatedTransformPosition():Vector3 {
        // 2. 计算插值系数 alpha
        // 它代表当前渲染时间，在“上一逻辑帧”到“当前逻辑帧”之间走了百分之多少
        // PORT-NOTE: C# 的 Ticks.GetTPS() 位于 PVZEngine（Assets/Scripts/Engine/Level/Ticks.cs），
        // 对应 Haxe 的 pvzengine.Ticks.GetTPS()，故此处 import 的是 pvzengine.Ticks 而非 tools.Ticks。
        var alpha = renderAccumulator * Ticks.GetTPS() * Level.GetGameSpeed();
        alpha = Mathf.Clamp01(alpha); // 确保在 0~1 之间

        // 3. 执行线性插值（Lerp）
        var pos = Entity.Position;
        var currentTransPos = Level.LawnToTrans(pos);
        var posOffset = GetTransformOffset();
        var currPosition = currentTransPos + posOffset;
        var smoothPosition = Vector3.Lerp(lastPosition, currPosition, alpha);

        // 4. 将最终平滑后的位置赋值给渲染组件（如 Mesh / SpriteRenderer）
        return smoothPosition;
    }
    public function GetInterpolatedTransformPositionOffset():Vector3 {
        var pos = Entity.Position;
        var currentTransPos = Level.LawnToTrans(pos);
        return GetInterpolatedTransformPosition() - currentTransPos;
    }

    // #region 手持物品
    // PORT-NOTE: C# `GetHeldItemTarget(Vector3, Vector3)` 与 `GetHeldItemTarget(PointerEventData)` 为重载，
    // Haxe 不支持重载：按世界坐标的版本改名，PointerEventData 版本保留原名（LevelController 依赖该名称）。
    public function GetHeldItemTargetFromWorldPosition(worldPosition:Vector3, screenPosition:Vector3):HeldItemTargetEntity {
        var pos = TransformWorld2ColliderPosition(worldPosition);
        return new HeldItemTargetEntity(Entity, pos, screenPosition);
    }
    public function GetHeldItemTarget(data:PointerEventData):HeldItemTargetEntity {
        var worldPosition = data.pointerCurrentRaycast.worldPosition;
        var screenPosition = data.pointerCurrentRaycast.screenPosition;
        var pos = TransformWorld2ColliderPosition(worldPosition);
        return new HeldItemTargetEntity(Entity, pos, screenPosition);
    }
    // #endregion

    // #region 序列化
    public function ToSerializable():SerializableEntityController {
        var serializable = new SerializableEntityController();
        serializable.id = Entity.ID;
        serializable.model = UnityObject.exists(Model) ? Model.ToSerializable() : null;
        return serializable;
    }
    public function LoadFromSerializable(serializable:SerializableEntityController):Void {
        if (UnityObject.exists(Model) && serializable.model != null) {
            Model.LoadFromSerializable(serializable.model);
            UpdateModelInsertions();
        }
    }
    // #endregion

    // #region 私有方法

    // #region 生命周期
    private function Awake():Void {
        holdStreakHandler.OnPointerInteraction.add((_, d, i) -> OnPointerInteraction.dispatch(this, d, i));
        bodyModelInterface = new BodyModelInterface(this);
        hpBarSource = new EntityHPBarSource(this);
    }
    private function Update():Void {
        var engine = Entity.Level;
        var cursorValid = IsHovered() && Level.IsGameRunning() && !engine.IsHoldingItem();
        if (cursorValid) {
            AddCursorSource();
        } else {
            RemoveCursorSource();
        }
    }
    // #endregion

    // #region 事件回调
    private function PostInitCallback():Void {
        UpdateAnimators(0);
        UpdateFrame(0);
    }
    private function PostPropertyChangedCallback(key:IPropertyKey, beforeValue:Dynamic, afterValue:Dynamic):Void {
        modelPropertyCache.SetDirtyPropertyByKey(key);
    }
    private function OnChangeModelCallback(modelID:NamespaceID):Void {
        SetModel(modelID);
    }
    private function OnModelInsertionAddedCallback(insertion:ModelInsertion):Void {
        if (UnityObject.exists(Model))
            Model.AddModelInsertion(insertion);
    }
    private function OnModelInsertionRemovedCallback(insertion:ModelInsertion):Void {
        if (UnityObject.exists(Model))
            Model.RemoveModelInsertion(insertion.key);
    }
    private function OnArmorEquipCallback(slot:NamespaceID, armor:Armor):Void {
        CreateArmorModel(slot, armor);
    }
    private function OnArmorRemoveCallback(slot:NamespaceID, armor:Armor):Void {
        RemoveArmorModel(slot);
    }
    private function OnModelUpdateFrameCallback(deltaTime:Float):Void {
        UpdateArmorModels();
        UpdateEntityModel();
    }
    // #endregion

    // #region 接口实现
    // PORT-NOTE: C# 为显式接口实现（ILevelRaycastReceiver.X），Haxe 无显式实现语法，改为普通公有方法。
    public function IsValidReceiver(level:LevelEngine, definition:HeldItemDefinition, data:IHeldItemData, d:PointerEventData):Bool {
        if (Entity.IsPreviewEnemy()) {
            return true;
        }
        if (definition == null)
            return false;
        var target = GetHeldItemTarget(d);
        var pointer = InputHelper.GetPointerDataFromEventData(d);
        return definition.IsValidFor(target, data, pointer);
    }
    public function GetSortingLayer():Int {
        if (!UnityObject.exists(Model))
            return 0;
        return Model.SortingLayerID;
    }
    public function GetSortingOrder():Int {
        if (!UnityObject.exists(Model))
            return 0;
        return Model.SortingOrder;
    }
    // #endregion

    // #region 位置
    public function GetGroundWorldPosition():Vector3 {
        var pos = Entity.Position;
        var groundY = Entity.GetGroundY();
        // PORT-NOTE: C# 的 Vector3 为值语义结构体；unity.Vector3 shim 包着可变对象，这里显式复制。
        var shadowPos = new Vector3(pos.x, pos.y, pos.z);
        shadowPos.y = groundY;

        var shadowOffset = modelPropertyCache.ShadowOffset;
        shadowOffset.x *= Entity.GetFinalDisplayScale().x;
        var worldPosition = Level.LawnToTrans(shadowPos);
        worldPosition.x = transform.position.x;
        worldPosition.z = transform.position.z;
        worldPosition += Level.LawnToTransDistance(shadowOffset);
        return worldPosition;
    }
    public function GetGroundLocalPosition():Vector3 {
        return transform.InverseTransformPoint(GetGroundWorldPosition());
    }
    // PORT-NOTE: C# 为 protected；内部类 EntityPropertyCache 需要调用（Haxe 无嵌套类访问权限），改为 public。
    public function UpdateShadow():Void {
        var relativeY = Entity.GetRelativeY();
        var scale = Mathf.Max(0, 1 + relativeY / 300) * modelPropertyCache.ShadowScale;

        var alpha = Mathf.Clamp01(1 - relativeY / 300) * modelPropertyCache.ShadowAlpha;

        var hidden = modelPropertyCache.ShadowHidden;

        var shadowTransform = Shadow.transform;
        shadowTransform.localPosition = GetGroundLocalPosition();
        shadowTransform.localScale = scale;
        Shadow.gameObject.SetActive(!hidden);
        Shadow.SetAlpha(alpha);
    }
    private function UpdateHeightIndicator():Void {
        var relativeY = Entity.GetRelativeY();
        var active = Main.OptionsManager.IsHeightIndicatorEnabled() && Entity.ShowHeightIndicator() && relativeY >= HEIGHT_INDICATOR_MIN_HEIGHT;
        if (heightIndicator.gameObject.activeSelf != active) {
            heightIndicator.gameObject.SetActive(active);
        }
        if (active) {
            heightIndicator.transform.localPosition = GetGroundLocalPosition();
            heightIndicator.SetHeight(relativeY * Level.LawnToTransScale);
            var t = (relativeY - HEIGHT_INDICATOR_FADE_MIN_HEIGHT) / (HEIGHT_INDICATOR_FADE_MAX_HEIGHT - HEIGHT_INDICATOR_FADE_MIN_HEIGHT);
            var indicatorColor = Color.Lerp(HEIGHT_INDICATOR_COLOR_MIN, HEIGHT_INDICATOR_COLOR_MAX, t);
            heightIndicator.SetColor(indicatorColor);
        }
    }
    // PORT-NOTE: C# 为 protected，内部类需要调用，改为 public。
    public function GetZOffset():Float {
        var zOffset = 0.0;
        if (zOffsetDict.exists(Entity.Type)) {
            zOffset = zOffsetDict.get(Entity.Type) * Level.LawnToTransScale;
        }
        return zOffset;
    }
    // PORT-NOTE: C# 为 protected，改为 public 以供内部类/同模块调用。
    public function GetTransformOffset():Vector3 {
        var zOffset = GetZOffset();
        return Vector3.back * zOffset;
    }
    // #endregion

    // #region 护甲
    private function CreateArmorModel(slot:NamespaceID, armor:Armor):Void {
        if (!UnityObject.exists(Model))
            return;
        if (armor == null || armor.Definition == null)
            return;
        var modelID = armor.Definition.GetModelID();
        if (!NamespaceID.IsValid(modelID))
            return;
        var armorID = armor.Definition.GetID();
        var anchor = GetArmorModelAnchor(slot, armorID);
        if (anchor == null || anchor.length == 0)
            return;
        var model = Model.CreateArmor(anchor, slot, modelID);
        if (UnityObject.exists(model)) {
            var modelPosition = GetArmorModelOffset(slot, armorID);
            model.transform.localPosition = modelPosition;
        }
    }
    public function GetArmorModelOffset(slotID:NamespaceID, armorID:NamespaceID):Vector3 {
        if (Model != null) {
            var modelMeta = Main.ResourceManager.GetModelMeta(Model.GetID());
            if (modelMeta != null) {
                var armorConfigID = modelMeta.ArmorConfigID != null ? modelMeta.ArmorConfigID : ModelArmorConfigMeta.DEFAULT_ID;
                var armorConfig = Main.ResourceManager.GetModelArmorConfigMeta(armorConfigID);
                if (armorConfig != null) {
                    var offset = armorConfig.GetArmorOffset(slotID, armorID);
                    offset *= Level.LawnToTransScale;
                    return offset;
                }
            }
        }
        return Vector3.zero;
    }
    public function GetArmorModelAnchor(slotID:NamespaceID, armorID:NamespaceID):String {
        if (Model != null) {
            var modelMeta = Main.ResourceManager.GetModelMeta(Model.GetID());
            if (modelMeta != null) {
                var armorConfigID = modelMeta.ArmorConfigID != null ? modelMeta.ArmorConfigID : ModelArmorConfigMeta.DEFAULT_ID;
                var armorConfig = Main.ResourceManager.GetModelArmorConfigMeta(armorConfigID);
                if (armorConfig != null) {
                    return armorConfig.GetArmorAnchor(slotID, armorID);
                }
            }
        }

        var game = Main.Game;
        var slotMeta = game.GetArmorSlotDefinition(slotID);
        if (slotMeta != null)
            return slotMeta.Anchor;
        return null;
    }
    private function RemoveArmorModel(slot:NamespaceID):Void {
        if (!UnityObject.exists(Model))
            return;
        Model.RemoveArmor(slot);
    }
    private function UpdateArmorModel(slot:NamespaceID):Void {
        if (!UnityObject.exists(Model))
            return;
        var armor = Entity.GetArmorAtSlot(slot);
        if (armor == null)
            return;
        var armorModel = Model.GetArmorModel(slot);
        if (!UnityObject.exists(armorModel))
            return;
        var tint = armor.GetTint();
        var colorOffset = armor.GetColorOffset();
        if (slot == LogicArmorSlots.main) {
            tint = tint * Entity.GetHelmetTint();
            colorOffset = colorOffset + Entity.GetHelmetColorOffset();
        }
        armorModel.SetShaderColor(ShaderProperties.TINT, tint);
        armorModel.SetShaderColor(ShaderProperties.COLOR_OFFSET, colorOffset);
        armorModel.ApplyShaderProperties();
    }
    private function UpdateArmorModels():Void {
        if (!UnityObject.exists(Model))
            return;
        for (slotSlot in Entity.GetActiveArmorSlots()) {
            UpdateArmorModel(slotSlot);
        }
    }
    public function ClearAllArmorModels():Void {
        if (!UnityObject.exists(Model))
            return;
        var game = Main.Game;
        var slots = game.GetAllArmorSlotDefinitions();
        for (def in slots) {
            if (def == null)
                continue;
            Model.ClearModelAnchor(def.Anchor);
        }
        var modelMeta = Main.ResourceManager.GetModelMeta(Model.GetID());
        if (modelMeta != null) {
            var armorConfigID = modelMeta.ArmorConfigID != null ? modelMeta.ArmorConfigID : ModelArmorConfigMeta.DEFAULT_ID;
            var armorConfig = Main.ResourceManager.GetModelArmorConfigMeta(armorConfigID);
            if (armorConfig != null) {
                var anchors = armorConfig.GetAllArmorModelAnchors();
                if (anchors != null) {
                    for (anchor in anchors) {
                        Model.ClearModelAnchor(anchor);
                    }
                }
            }
        }
    }
    // #endregion

    // #region 模型
    private function UpdateEntityModel():Void {
        if (!UnityObject.exists(Model))
            return;

        if (Level.IsGameOver() && Entity == Entity.Level.KillerEnemy) {
            Entity.UpdateAnimationParameters(LogicEnemyStates.WALK);
        }
        // PORT-NOTE: unity.Vector3 shim 包着可变对象，需显式复制以保持 C# 值语义。
        var groundPos = Entity.Position;
        groundPos = new Vector3(groundPos.x, groundPos.y, groundPos.z);
        groundPos.y = Entity.GetGroundY();
        var transGroundPos = Level.LawnToTrans(groundPos);
        Model.SetGroundY(transGroundPos.y);
        Model.transform.localPosition = Level.LawnToTransScale * Entity.GetModelPositionOffset();

        var centerTransform = Model.GetCenterTransform();
        if (UnityObject.exists(centerTransform))
            centerTransform.localEulerAngles = Entity.RenderRotation;

        if (modelPropertyCache.IsDirty) {
            modelPropertyCache.Update(this);
        }
    }
    private function UpdateModelInsertions():Void {
        if (UnityObject.exists(Model))
            Model.UpdateModelInsertions(Entity.GetModelInsertions());
    }
    // #endregion

    private function AddCursorSource():Void {
        if (_cursorSource == null) {
            _cursorSource = new EntityCursorSource(this, CursorType.Point);
            Main.CursorManager.AddCursorSource(_cursorSource);
        }
    }
    private function RemoveCursorSource():Void {
        if (_cursorSource != null) {
            Main.CursorManager.RemoveCursorSource(_cursorSource);
            _cursorSource = null;
        }
    }

    private function ShouldTwinkle():Bool {
        var engine = Entity.Level;
        return engine.ShouldHeldItemMakeEntityTwinkle(Entity);
    }
    // PORT-NOTE: C# 为 private，内部类 EntityPropertyCache 需要调用，改为 public。
    public function GetTint():Color {
        var tint = Entity.GetTint();
        if (twinkling) {
            tint = tint * Level.GetTwinkleColor();
        }
        return tint;
    }
    // PORT-NOTE: C# 为 private，内部类 EntityPropertyCache 需要调用，改为 public。
    public function GetColorOffset():Color {
        var color = Entity.GetColorOffset();
        if (isHighlight) {
            // PORT-NOTE: C# 的 Tools.ColorCalculator 对应 Haxe 的 pvzengine.modifiers.ColorCalculator，
            // Blend 为静态方法，签名与 C# 一致。
            color = ColorCalculator.Blend(new Color(1, 1, 1, 0.5), color, BlendOperator.SrcAlpha, BlendOperator.OneMinusSrcAlpha);
        }
        return color;
    }
    // #endregion

    // #region 血条
    public function IsHPBarHovered():Bool {
        var hoverDisplayRange = Main.OptionsManager.GetHPBarHoverDisplayRange();
        if (hoverDisplayRange > 0) {
            var entity = Entity;
            var level = Level;
            var pointerScreenPos = Main.InputManager.GetPointerScreenPosition();
            var pointerPos = level.ScreenToLawnPositionByY(pointerScreenPos, entity.Position.y);
            if ((pointerPos - entity.Position).sqrMagnitude <= hoverDisplayRange * hoverDisplayRange) {
                return true;
            }
        }
        return false;
    }
    public function ShouldShowHPBarOnEntity():Bool {
        var entity = Entity;
        if (entity.Type == EntityTypes.ENEMY)
            return true;
        if (entity.Type == EntityTypes.PLANT || entity.Type == EntityTypes.OBSTACLE) {
            if (!entity.HasTakenGrid())
                return true;
        }
        return false;
    }
    public function ShouldShowMainHPBar():Bool {
        if (IsHPBarHovered()) {
            return true;
        }
        if (Main.OptionsManager.IsHPBarAutoHide()) {
            var entity = Entity;
            if (Mathf.Abs(entity.GetMaxHealth() - entity.Health) <= 0.01) {
                // 满血
                return false;
            }
            return true;
        } else {
            return true;
        }
    }
    public function ShouldShowArmorHPBar(armor:Armor):Bool {
        if (IsHPBarHovered()) {
            return true;
        }
        if (Main.OptionsManager.IsHPBarAutoHide()) {
            if (Mathf.Abs(armor.GetMaxHealth() - armor.Health) <= 0.01) {
                // 满血
                return false;
            }
            return true;
        } else {
            return true;
        }
    }
    public function GetMainHPBarAmount():Float {
        var entity = Entity;
        var health = entity.Health;
        var maxHealth = entity.GetMaxHealth();
        return health / maxHealth;
    }
    public function GetArmorHPBarAmount(armor:Armor):Float {
        var health = armor.Health;
        var maxHealth = armor.GetMaxHealth();
        return health / maxHealth;
    }
    public function GetMainHPBarText(amountMode:Int):String {
        var entity = Entity;
        if (entity.IsDead) {
            return Main.LanguageManager._(HP_BAR_TEXT_DEATH);
        }
        return GetHPBarText(entity.Health, entity.GetMaxHealth(), amountMode);
    }
    public function GetArmorHPBarText(armor:Armor, amountMode:Int):String {
        // PORT-NOTE: C# `unity.UnityObject.exists(armor)` 是 UnityEngine.Object 的扩展方法；Haxe 侧为 UnityObject.exists(obj)。
        if (!UnityObject.exists(armor)) {
            return Main.LanguageManager._(HP_BAR_TEXT_DESTROYED);
        }
        return GetHPBarText(armor.Health, armor.GetMaxHealth(), amountMode);
    }
    public static function GetHPBarText(health:Float, maxHealth:Float, amountMode:Int):String {
        var text = "";
        switch (amountMode) {
            case HPBarAmountMode.CURRENT_ONLY:
                text = Global.Localization.GetText(HP_BAR_TEXT_TEMPLATE, [Mathf.CeilToInt(Mathf.Max(0, health))]);
            case HPBarAmountMode.CURRENT_AND_MAX:
                text = Global.Localization.GetText(HP_BAR_TEXT_TEMPLATE_WITH_MAX, [Mathf.CeilToInt(Mathf.Max(0, health)), Mathf.CeilToInt(maxHealth)]);
            case _:
        }
        return text;
    }
    // #endregion

    // #region View
    public function TriggerView(name:String):Void {
        if (UnityObject.exists(Model))
            Model.TriggerAnimator(name);
    }
    public function SetViewBool(name:String, value:Bool):Void {
        if (UnityObject.exists(Model))
            Model.SetAnimatorBool(name, value);
    }
    public function SetViewInt(name:String, value:Int):Void {
        if (UnityObject.exists(Model))
            Model.SetAnimatorInt(name, value);
    }
    public function SetViewFloat(name:String, value:Float):Void {
        if (UnityObject.exists(Model))
            Model.SetAnimatorFloat(name, value);
    }
    // #endregion

    // #region 事件
    public var OnPointerInteraction:FlxTypedSignal<EntityController->PointerEventData->PointerInteraction->Void> = new FlxTypedSignal();
    // #endregion

    // #region 属性字段
    public static inline var HEIGHT_INDICATOR_MIN_HEIGHT:Float = 40;
    public static inline var HEIGHT_INDICATOR_FADE_MIN_HEIGHT:Float = 300;
    public static inline var HEIGHT_INDICATOR_FADE_MAX_HEIGHT:Float = 500;
    public static var HEIGHT_INDICATOR_COLOR_MIN:Color = Color.white;
    public static var HEIGHT_INDICATOR_COLOR_MAX:Color = new Color(1, 1, 1, 0);

    public static var zOffsetDict:Map<Int, Float> = [
        EntityTypes.PLANT => 0,
        EntityTypes.OBSTACLE => 0,
        EntityTypes.BOSS => 2,
        EntityTypes.ENEMY => 3,
        EntityTypes.PROJECTILE => 4,
        EntityTypes.CART => 5,
        EntityTypes.EFFECT => 6,
        EntityTypes.PICKUP => 7
    ];
    @:translateMsg("血条的文字")
    public static inline var HP_BAR_TEXT_DEATH:String = "死亡";
    @:translateMsg("血条的文字")
    public static inline var HP_BAR_TEXT_DESTROYED:String = "摧毁";
    @:translateMsg("血条的文字模板")
    public static inline var HP_BAR_TEXT_TEMPLATE:String = "{0}";
    @:translateMsg("血条的文字模板")
    public static inline var HP_BAR_TEXT_TEMPLATE_WITH_MAX:String = "{0}/{1}";
    public var Main(get, never):MainManager;
    inline function get_Main():MainManager return MainManager.Instance;
    public var Model(default, null):EntityModel;
    public var Shadow(get, never):ShadowController;
    inline function get_Shadow():ShadowController return shadow;
    public var Entity(default, null):Entity;
    public var Level(default, null):LevelController;
    private var rng:RandomGenerator;
    private var isHighlight:Bool;
    private var twinkling:Bool;
    private var _cursorSource:EntityCursorSource;
    private var renderAccumulator:Float;
    private var lastPosition:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    private var bodyModelInterface:IModelInterface;
    private var hpBarSource:IHPBarSource;
    private var modelPropertyCache:EntityPropertyCache = new EntityPropertyCache();
    private var animatorBuffer:Array<Animator> = [];
    @:serializeField
    private var maxRenderAccumulator:Float = 1;
    @:serializeField
    private var shadow:ShadowController = null;
    @:serializeField
    private var heightIndicator:HeightIndicatorController = null;
    @:serializeField
    private var tooltipAnchor:TooltipAnchor = null;
    @:serializeField
    private var holdStreakHandler:LevelPointerInteractionHandler = null;

    public var Anchor(get, never):ITooltipAnchor;
    inline function get_Anchor():ITooltipAnchor return tooltipAnchor;
    // #endregion
}

// Ported from: Assets/Scripts/MVZ2/Entities/EntityController.cs (enum EntityPropertyCache.PropertyName)
// PORT-NOTE: C# 为 EntityPropertyCache 的嵌套枚举，Haxe 无嵌套类型，提升为同模块的私有枚举。
private enum abstract PropertyName(Int) {
    var Tint = 0;
    var ColorOffset = 1;
    var HSV = 2;
    var Grayscale = 3;
    var DepthTest = 4;
    var FlipX = 5;
    var DisplayScale = 6;
    var SortingLayer = 7;
    var SortingOrder = 8;

    var ShadowHidden = 9;
    var ShadowOffset = 10;
    var ShadowScale = 11;
    var ShadowAlpha = 12;

    var LightSource = 13;
    var LightColor = 14;
    var LightRange = 15;
}

// Ported from: Assets/Scripts/MVZ2/Entities/EntityController.cs (内嵌类 EntityPropertyCache)
// PORT-NOTE: C# 为 EntityController 的私有内嵌类，Haxe 无嵌套类，提升为同模块的私有类。
// PORT-NOTE: C# 的 HashSet<PropertyName> 用 Array 代替，并在 SetDirtyProperty 中显式去重。
private class EntityPropertyCache {
    // PORT-NOTE: 原 C# 是 EntityController 的嵌套类（隐式无参构造）；Haxe 的模块级类需要显式
    // 构造，`new EntityPropertyCache()` 才能通过。
    public function new() {}
    public function UpdateAll(entityCtrl:EntityController):Void {
        var entity = entityCtrl.Entity;
        var model = entityCtrl.Model;
        if (model != null) {
            model.SetShaderColor(ShaderProperties.TINT, entityCtrl.GetTint());
            var hsvOffset = entity.GetHSVOffset();
            model.SetShaderVector(ShaderProperties.HSV_OFFSET, new Vector4(hsvOffset.x, hsvOffset.y, hsvOffset.z, 0));
            model.SetShaderColor(ShaderProperties.COLOR_OFFSET, entityCtrl.GetColorOffset());
            model.SetShaderInt(ShaderProperties.GRAYSCALE, entity.IsGrayscale() ? 1 : 0);
            model.SetShaderInt(ShaderProperties.DEPTH_TEST, entity.IsDepthTest() ? 1 : 0);
            model.ApplyShaderProperties();

            model.transform.localScale = entity.GetFinalDisplayScale();
            model.SortingLayerID = unity.SortingLayer.NameToID(entity.GetSortingLayer());
            model.SortingOrder = entity.GetSortingOrder();
            model.SetLightVisible(entity.IsLightSource());
            model.SetLightColor(entity.GetLightColor());
            var lightScaleLawn = entity.GetLightRange();
            var lightScale = new Vector2(lightScaleLawn.x, Mathf.Max(lightScaleLawn.y, lightScaleLawn.z)) * entityCtrl.Level.LawnToTransScale;
            model.SetLightRange(lightScale);
        }

        ShadowHidden = entity.IsShadowHidden();
        ShadowAlpha = entity.GetShadowAlpha();
        ShadowOffset = entity.GetShadowOffset();
        ShadowScale = entity.GetShadowScale();
        entityCtrl.UpdateShadow();

        dirtyProperties = [];
    }
    public function Update(entityCtrl:EntityController):Void {
        var entity = entityCtrl.Entity;
        var model = entityCtrl.Model;
        for (dirtyProperty in dirtyProperties) {
            switch (dirtyProperty) {
                case PropertyName.Tint:
                    if (UnityObject.exists(model)) {
                        model.SetShaderColor(ShaderProperties.TINT, entityCtrl.GetTint());
                        model.ApplyShaderProperties();
                    }
                case PropertyName.ColorOffset:
                    if (UnityObject.exists(model)) {
                        model.SetShaderColor(ShaderProperties.COLOR_OFFSET, entityCtrl.GetColorOffset());
                        model.ApplyShaderProperties();
                    }
                case PropertyName.HSV:
                    if (UnityObject.exists(model)) {
                        var hsvOffset = entity.GetHSVOffset();
                        model.SetShaderVector(ShaderProperties.HSV_OFFSET, new Vector4(hsvOffset.x, hsvOffset.y, hsvOffset.z, 0));
                        model.ApplyShaderProperties();
                    }
                case PropertyName.Grayscale:
                    if (UnityObject.exists(model)) {
                        model.SetShaderInt(ShaderProperties.GRAYSCALE, entity.IsGrayscale() ? 1 : 0);
                        model.ApplyShaderProperties();
                    }
                case PropertyName.DepthTest:
                    if (UnityObject.exists(model)) {
                        model.SetShaderIntRecursive(ShaderProperties.DEPTH_TEST, entity.IsDepthTest() ? 1 : 0);
                        model.ApplyShaderPropertiesRecursive();
                    }
                case PropertyName.FlipX | PropertyName.DisplayScale:
                    if (UnityObject.exists(model)) {
                        model.transform.localScale = entity.GetFinalDisplayScale();
                    }
                case PropertyName.SortingLayer:
                    if (UnityObject.exists(model)) {
                        // PORT-NOTE: 显式限定 unity.SortingLayer，避免与同处 case 分支内的
                        // `PropertyName.SortingLayer` 枚举项在名字解析上混淆。
                        model.SortingLayerID = unity.SortingLayer.NameToID(entity.GetSortingLayer());
                    }
                case PropertyName.SortingOrder:
                    if (UnityObject.exists(model)) {
                        model.SortingOrder = entity.GetSortingOrder();
                    }

                case PropertyName.ShadowHidden:
                    {
                        ShadowHidden = entity.IsShadowHidden();
                        entityCtrl.UpdateShadow();
                    }
                case PropertyName.ShadowAlpha:
                    {
                        ShadowAlpha = entity.GetShadowAlpha();
                        entityCtrl.UpdateShadow();
                    }
                case PropertyName.ShadowOffset:
                    {
                        ShadowOffset = entity.GetShadowOffset();
                        entityCtrl.UpdateShadow();
                    }
                case PropertyName.ShadowScale:
                    {
                        ShadowScale = entity.GetShadowScale();
                        entityCtrl.UpdateShadow();
                    }

                case PropertyName.LightSource:
                    {
                        if (Std.isOfType(model, EntityModel)) {
                            var sprModel:EntityModel = cast model;
                            sprModel.SetLightVisible(entity.IsLightSource());
                        }
                    }
                case PropertyName.LightColor:
                    {
                        if (Std.isOfType(model, EntityModel)) {
                            var sprModel:EntityModel = cast model;
                            sprModel.SetLightColor(entity.GetLightColor());
                        }
                    }
                case PropertyName.LightRange:
                    {
                        if (Std.isOfType(model, EntityModel)) {
                            var sprModel:EntityModel = cast model;
                            var lightScaleLawn = entity.GetLightRange();
                            var lightScale = new Vector2(lightScaleLawn.x, Mathf.Max(lightScaleLawn.y, lightScaleLawn.z)) * entityCtrl.Level.LawnToTransScale;
                            sprModel.SetLightRange(lightScale);
                        }
                    }
                // PORT-NOTE: Haxe 的 enum abstract switch 需要穷尽，补上 C# 中不存在的空分支。
                case _:
            }
        }
        dirtyProperties = [];
    }
    public function SetDirtyProperty(property:PropertyName):Void {
        if (!dirtyProperties.contains(property))
            dirtyProperties.push(property);
    }
    // PORT-NOTE: C# `SetDirtyProperty(IPropertyKey)` 与 `SetDirtyProperty(PropertyName)` 为重载，
    // Haxe 不支持重载，按键的版本改名 SetDirtyPropertyByKey。
    public function SetDirtyPropertyByKey(key:IPropertyKey):Void {
        for (pair in propertyMap) {
            if (pair.key == key) {
                SetDirtyProperty(pair.value);
                break;
            }
        }
    }
    public var IsDirty(get, never):Bool;
    inline function get_IsDirty():Bool return dirtyProperties.length > 0;
    public var ShadowHidden(default, null):Bool;
    public var ShadowOffset(default, null):Vector3 = new Vector3();
    public var ShadowScale(default, null):Vector3 = new Vector3();
    public var ShadowAlpha(default, null):Float;
    private var dirtyProperties:Array<PropertyName> = [];
    // PORT-NOTE: C# 为 `Dictionary<PropertyMeta, PropertyName>`（PropertyMeta 为非泛型基类）；
    // Haxe 的 PropertyMeta 是泛型类且无共同基类，故改用键值对数组并按引用比较
    // （属性元数据均为静态单例，引用比较与 C# 的 Equals 等价）。
    private static var propertyMap:Array<{key:IPropertyKey, value:PropertyName}> = buildPropertyMap();
    private static function buildPropertyMap():Array<{key:IPropertyKey, value:PropertyName}> {
        var map:Array<{key:IPropertyKey, value:PropertyName}> = [];
        map.push({key: cast EngineEntityProps.TINT, value: PropertyName.Tint});
        map.push({key: cast EngineEntityProps.COLOR_OFFSET, value: PropertyName.ColorOffset});
        map.push({key: cast LogicEntityProps.HSV_OFFSET, value: PropertyName.HSV});
        map.push({key: cast LogicEntityProps.GRAYSCALE, value: PropertyName.Grayscale});
        map.push({key: cast LogicEntityProps.DEPTH_TEST, value: PropertyName.DepthTest});
        map.push({key: cast EngineEntityProps.FLIP_X, value: PropertyName.FlipX});
        map.push({key: cast EngineEntityProps.DISPLAY_SCALE, value: PropertyName.DisplayScale});
        map.push({key: cast LogicEntityProps.SORTING_LAYER, value: PropertyName.SortingLayer});
        map.push({key: cast LogicEntityProps.SORTING_ORDER, value: PropertyName.SortingOrder});

        map.push({key: cast LogicEntityProps.SHADOW_HIDDEN, value: PropertyName.ShadowHidden});
        map.push({key: cast LogicEntityProps.SHADOW_OFFSET, value: PropertyName.ShadowOffset});
        map.push({key: cast LogicEntityProps.SHADOW_SCALE, value: PropertyName.ShadowScale});
        map.push({key: cast LogicEntityProps.SHADOW_ALPHA, value: PropertyName.ShadowAlpha});

        map.push({key: cast LogicEntityProps.IS_LIGHT_SOURCE, value: PropertyName.LightSource});
        map.push({key: cast LogicEntityProps.LIGHT_COLOR, value: PropertyName.LightColor});
        map.push({key: cast LogicEntityProps.LIGHT_RANGE, value: PropertyName.LightRange});
        return map;
    }
}

// Ported from: Assets/Scripts/MVZ2/Entities/EntityController.cs (class EntityCursorSource)
class EntityCursorSource extends CursorSource {
    public function new(target:EntityController, type:CursorType, priority:Int = 0) {
        // PORT-NOTE: mvz2logic.cursor.CursorSource 目前没有声明构造函数（C# 是隐式默认构造），
        // Haxe 下不能调用不存在的 super()，故此处省略（若 CursorSource 之后补上 new()，需加回 super();）。
        this.target = target;
        this.type = type;
        this.priority = priority;
    }

    override public function IsValid():Bool {
        // PORT-NOTE: C# `target && target.isActiveAndEnabled`；
        // unity.MonoBehaviour shim 未定义 isActiveAndEnabled，这里按 Unity 语义展开判断。
        return target != null && target.enabled && target.gameObject != null && target.gameObject.activeInHierarchy;
    }

    public var target:EntityController;
    private var priority:Int;
    override public function get_Priority():Int return priority;
    private var type:CursorType;
    override public function get_CursorType():CursorType return type;
}

// Ported from: Assets/Scripts/MVZ2/Entities/EntityController.cs (class SerializableEntityController)
@:rtti
class SerializableEntityController {
    public var id:haxe.Int64;
    public var model:SerializableModelData;

    public function new() {}
}

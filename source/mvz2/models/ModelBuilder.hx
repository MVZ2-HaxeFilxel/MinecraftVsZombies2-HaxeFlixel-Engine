// Ported from: Assets/Scripts/MVZ2/Models/Utilities/ModelBuilder.cs
package mvz2.models;

import mvz2.managers.MainManager;
import mvz2.models.Model;
import pvzengine.NamespaceID;
import tools.ObjectExtensions;
import unity.Camera;
import unity.GameObject;
import unity.Transform;
import unity.UnityObject;
using pvzengine.PropertyKeyHelper;  // EXTUSING

class ModelBuilder implements IModelBuilder {
    public function new(id:NamespaceID, camera:Camera, seed:Int = 0) {
        this.id = id;
        this.camera = camera;
        this.seed = 0;
        mainManager = MainManager.Instance;
    }
    public function Build(parent:Transform):Model {
        var res = mainManager.ResourceManager;
        if (!NamespaceID.IsValid(id))
            return null;
        var modelMeta = res.GetModelMeta(id);
        if (modelMeta == null || modelMeta.Path == null)
            return null;
        var model:Model = null;
        var prefab = res.GetModel(modelMeta.Path);
        // PORT-NOTE: C# 的 `unity.UnityObject.exists(prefab)` 是 Unity 的伪空判断（overload ==），Haxe 侧改为
        // unity.UnityObject.exists（null 安全）。
        if (unity.UnityObject.exists(prefab)) {
            model = cast unity.UnityObject.Instantiate(prefab, null, null, parent);
        } else {
            // PORT-NOTE: C# 的 prefab 来自 Unity 资产（Addressables 标签 Model）。移植层没有
            // prefab 资产，ResourceManager.Models 通常为空，此时改用 build_models.py 导出的
            // 节点表重建层级——语义等价于 GameObject.Instantiate(prefab, parent) + GetComponent<Model>()。
            // 详见 ModelPrefabLoader 的 PORT-NOTE。
            var root = ModelPrefabLoader.Instantiate(modelMeta.Path.toString(), parent);
            if (root != null) {
                model = root.GetComponent(Model);
            }
            if (model == null) {
                unity.Debug.LogWarning('模型 ${id} 的 prefab 与导出数据都不可用。');
            }
        }
        if (model != null) {
            for (parameter in modelMeta.AnimatorParameters) {
                parameter.Apply(model);
            }
            for (parameter in modelMeta.ModelProperties) {
                model.SetProperty(parameter.Key, parameter.Value);
            }
            model.Init(id, camera, seed);
        }
        return model;
    }
    public var id:NamespaceID;
    public var camera:Camera;
    public var seed:Int;
    private var mainManager:MainManager;
}

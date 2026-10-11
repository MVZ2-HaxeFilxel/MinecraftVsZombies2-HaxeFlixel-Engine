// Ported from: Assets/Scripts/View/Models/Model.cs
package mvz2.models;
import mvz2.models.ModelGroup.SerializableModelGroup;  // IMPORTAUTO
import mvz2.states.BootTrace;
import system.Guid;  // UNKNOWNIMPORT

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2logic.models.LogicModelHelper;
import pvzengine.NamespaceID;
import pvzengine.PropertyDictionaryString;
import pvzengine.PropertyKeyString;
import pvzengine.SerializablePropertyDictionaryString;
import pvzengine.models.IModelInterface;
import pvzengine.models.ModelInsertion;
import tools.RandomGenerator;
import tools.SerializableRNG;
import unity.Animator;
import unity.AnimatorControllerParameterType;
import unity.Camera;
import unity.Color;
import unity.RectTransform;
import unity.Transform;
import unity.UnityObject;
import unity.Vector3;
import unity.Vector4;
import unity.events.UnityEvent;
using pvzengine.PropertyKeyHelper;  // EXTUSING
using pvzengine.models.HasModelExt;  // EXTUSING

class Model extends unity.MonoBehaviour
{
	public function new() { super(); } // CTORFIX
	// #region 公有方法
	public function GetCamera():Camera
	{
		return eventCamera;
	}
	public function AddElement(element:GraphicElement):Void
	{
		GraphicGroup.AddElement(element);
	}
	public function UpdateElements():Void
	{
	}
	public function GetID():NamespaceID
	{
		return id;
	}

	// #region 生命周期
	public function Init(id:NamespaceID, camera:Camera, ?seed:Int = 0):Void
	{
		this.id = id;
		if (seed == 0)
		{
			// PORT-NOTE: C# 用 Guid.NewGuid().GetHashCode() 生成随机种子，Haxe 无对应 API。
			seed = Std.random(0x7FFFFFFF);
		}
		rng = new RandomGenerator(seed);
		eventCamera = camera;
		InitModel();
	}
	public function InitModel():Void
	{
		modelComponents.resize(0);
		var discovered:Array<ModelComponent> = GetComponentsInChildren(ModelComponent, true);
		for (comp in discovered)
		{
			modelComponents.push(comp);
		}
		for (comp in modelComponents)
		{
			if (comp == null)
				continue;
			var modelComp:ModelComponent = cast comp;
			modelComp.SetModel(this);
			modelComp.Init();
		}
		modelInterface = new ModelParentInterface(this);
	}
	public function UpdateFixed():Void
	{
		modelComponents = Lambda.array(Lambda.filter(modelComponents, e -> e != null));
		for (comp in modelComponents)
		{
			if (comp == null || !comp.IsEnabled())
				continue;
			comp.UpdateLogic();
		}
		childModels = Lambda.array(Lambda.filter(childModels, m -> UnityObject.exists(m)));
		for (child in childModels)
		{
			child.UpdateFixed();
		}
		if (destroyTimeout > 0)
		{
			destroyTimeout--;
			if (destroyTimeout <= 0)
			{
				DestroyModel();
			}
		}
	}
	public function UpdateFrame(deltaTime:Float):Void
	{
		if (!gameObject.activeInHierarchy)
			return;
		GraphicGroup.UpdateFrame(deltaTime);
		modelComponents = Lambda.array(Lambda.filter(modelComponents, e -> e != null));
		for (comp in modelComponents)
		{
			if (comp == null || !comp.IsEnabled())
				continue;
			comp.UpdateFrame(deltaTime);
		}
		childModels = Lambda.array(Lambda.filter(childModels, m -> UnityObject.exists(m)));
		for (child in childModels)
		{
			child.UpdateFrame(deltaTime);
		}
		OnUpdateFrame.dispatch(deltaTime);
	}
	public function DestroyModel():Void
	{
		UnityObject.destroy(gameObject);
	}

	public function GetAnimatorsToUpdate(results:Array<Animator>):Void
	{
		GraphicGroup.GetAnimatorsToUpdate(results);
		for (child in childModels)
		{
			child.GetAnimatorsToUpdate(results);
		}
	}
	public function UpdateAnimators(deltaTime:Float):Void
	{
		GraphicGroup.UpdateAnimators(deltaTime);
		for (child in childModels)
		{
			child.UpdateAnimators(deltaTime);
		}
	}
	public function SetSimulationSpeed(simulationSpeed:Float):Void
	{
		GraphicGroup.SetSimulationSpeed(simulationSpeed);
		childModels = Lambda.array(Lambda.filter(childModels, m -> UnityObject.exists(m)));
		for (child in childModels)
		{
			child.SetSimulationSpeed(simulationSpeed);
		}
	}
	public function SetGroundY(y:Float):Void
	{
		GraphicGroup.SetGroundY(y);
		childModels = Lambda.array(Lambda.filter(childModels, m -> UnityObject.exists(m)));
		for (child in childModels)
		{
			child.SetGroundY(y);
		}
	}
	// #endregion

	// #region 动画
	public function TriggerAnimator(name:String):Void
	{
		GraphicGroup.TriggerAnimator(name);
	}
	public function SetAnimatorBool(name:String, value:Bool):Void
	{
		GraphicGroup.SetAnimatorBool(name, value);
	}
	public function SetAnimatorInt(name:String, value:Int):Void
	{
		GraphicGroup.SetAnimatorInt(name, value);
	}
	public function SetAnimatorFloat(name:String, value:Float):Void
	{
		GraphicGroup.SetAnimatorFloat(name, value);
	}
	public function GetAnimatorInterface(name:String):Null<pvzengine.models.IAnimatorInterface>
	{
		return cast GraphicGroup.GetAnimatorElement(name);
	}
	// #endregion

	// #region 序列化
	public function ToSerializable():SerializableModelData
	{
		var serializable = CreateSerializable();
		serializable.id = id;
		serializable.key = parentKey;
		serializable.anchor = parentAnchor;
		serializable.position = transform.localPosition;
		serializable.rng = rng.ToSerializable();
		serializable.propertyDict = propertyDict.ToSerializable();
		serializable.childModels = [for (c in childModels) c.ToSerializable()];
		serializable.destroyTimeout = destroyTimeout;
		serializable.graphicGroup = GraphicGroup.ToSerializable();
		serializable.insertions = insertions.copy();
		for (comp in modelComponents)
		{
			if (comp == null)
				continue;
			comp.SaveToSerializable(serializable);
		}
		return serializable;
	}
	public function LoadFromSerializable(serializable:SerializableModelData):Void
	{
		rng = serializable.rng != null ? RandomGenerator.FromSerializable(serializable.rng) : new RandomGenerator(Std.random(0x7FFFFFFF));
		destroyTimeout = serializable.destroyTimeout;
		if (serializable.propertyDict != null)
		{
			var dict = PropertyDictionaryString.FromSerializable(serializable.propertyDict);
			for (name in dict.GetPropertyNames())
			{
				SetProperty(name, dict.GetProperty(name));
			}
		}
		if (serializable.childModels != null)
		{
			for (seriChild in serializable.childModels)
			{
				if (seriChild == null || seriChild.anchor == null || seriChild.key == null || seriChild.id == null)
					continue;
				var child = CreateChildModel(seriChild.anchor, seriChild.key, seriChild.id);
				if (UnityObject.exists(child))
				{
					child.transform.localPosition = seriChild.position;
					child.LoadFromSerializable(seriChild);
				}
			}
		}
		LoadSerializable(serializable);
		// 最后再加载GraphicGroup，防止Animator在加载数据前尚未启用。
		if (serializable.graphicGroup != null)
			GraphicGroup.FromSerializable(serializable.graphicGroup);

		insertions.resize(0);
		if (serializable.insertions != null)
		{
			for (key in serializable.insertions)
			{
				if (!NamespaceID.IsValid(key))
					continue;
				insertions.push(key);
			}
		}
		for (comp in modelComponents)
		{
			if (comp == null)
				continue;
			comp.LoadFromSerializable(serializable);
		}
	}
	// abstract
	function CreateSerializable():SerializableModelData
	{
		throw "abstract";
	}
	function LoadSerializable(serializable:SerializableModelData):Void
	{
	}
	// #endregion

	// #region 子模型
	public function CreateChildModel(anchorName:String, key:NamespaceID, id:NamespaceID):Null<Model>
	{
		var existing = GetChildModel(key);
		if (UnityObject.exists(existing))
			RemoveChildModel(key);
		var anchor = GetAnchor(anchorName);
		if (!UnityObject.exists(anchor))
			return null;
		var child = ModelFactories.Create(id, eventCamera, anchor.transform);
		if (!UnityObject.exists(child))
			return null;
		child.transform.localPosition = Vector3.zero;
		child.parentAnchor = anchorName;
		child.parentKey = key;
		child.parent = this;
		childModels.push(child);
		return child;
	}
	public function RemoveChildModel(key:NamespaceID):Bool
	{
		var model = GetChildModel(key);
		if (!UnityObject.exists(model))
			return false;
		if (model.destroyDelay <= 0)
		{
			model.DestroyModel();
			return childModels.remove(model);
		}
		else
		{
			model.DestroyDelayed(model.destroyDelay);
			return true;
		}
	}
	public function GetChildModel(key:NamespaceID):Null<Model>
	{
		for (child in childModels)
		{
			if (!child.IsDestroying() && child.parentKey == key)
			{
				return child;
			}
		}
		return null;
	}
	public function ChangeChildModel(anchorName:String, key:NamespaceID, modelID:NamespaceID):Void
	{
		RemoveChildModel(key);
		CreateChildModel(anchorName, key, modelID);
	}
	public function ClearModelAnchor(anchorName:String):Void
	{
		var anchor = GetAnchor(anchorName);
		if (!UnityObject.exists(anchor))
			return;
		var childCount = anchor.transform.childCount;
		var i = childCount - 1;
		while (i >= 0)
		{
			var child = anchor.transform.GetChild(i);
			var childModel = child.GetComponent(Model);
			if (childModel != null)
			{
				childModel.DestroyModel();
			}
			i--;
		}
	}
	public function GetParentModelInterface():IModelInterface
	{
		return modelInterface;
	}
	// #endregion

	// #region 摧毁
	public function DestroyDelayed(frames:Int):Void
	{
		destroyTimeout = frames;
		onDelayedDestroy.Invoke();
	}
	public function IsDestroying():Bool
	{
		return destroyTimeout > 0;
	}
	// #endregion

	// #region 属性
	public function GetProperty<T>(name:PropertyKeyString):Null<T>
	{
		return propertyDict.GetProperty(name);
	}
	public function SetProperty(name:PropertyKeyString, value:Dynamic):Void
	{
		propertyDict.SetProperty(name, value);
		for (comp in modelComponents)
		{
			if (comp == null)
				continue;
			comp.OnPropertySet(name, value);
		}
	}
	public function TriggerModel(name:PropertyKeyString):Void
	{
		for (comp in modelComponents)
		{
			if (comp == null)
				continue;
			comp.OnTrigger(name);
		}
	}
	// #endregion

	// #region 着色器属性
	public function SetShaderInt(name:String, value:Int):Void
	{
		GraphicGroup.SetShaderInt(name, value);
	}
	public function SetShaderFloat(name:String, value:Float):Void
	{
		GraphicGroup.SetShaderFloat(name, value);
	}
	public function SetShaderColor(name:String, value:Color):Void
	{
		GraphicGroup.SetShaderColor(name, value);
	}
	public function SetShaderVector(name:String, value:Vector4):Void
	{
		GraphicGroup.SetShaderVector(name, value);
	}
	public function ApplyShaderProperties():Void
	{
		GraphicGroup.ApplyShaderProperties();
	}
	public function SetShaderIntRecursive(name:String, value:Int):Void
	{
		SetShaderInt(name, value);
		for (child in childModels)
		{
			child.SetShaderIntRecursive(name, value);
		}
	}

	public function SetShaderFloatRecursive(name:String, value:Float):Void
	{
		SetShaderFloat(name, value);
		for (child in childModels)
		{
			child.SetShaderFloatRecursive(name, value);
		}
	}
	public function SetShaderColorRecursive(name:String, value:Color):Void
	{
		SetShaderColor(name, value);
		for (child in childModels)
		{
			child.SetShaderColorRecursive(name, value);
		}
	}
	public function SetShaderVectorRecursive(name:String, value:Vector4):Void
	{
		SetShaderVector(name, value);
		for (child in childModels)
		{
			child.SetShaderVectorRecursive(name, value);
		}
	}
	public function ApplyShaderPropertiesRecursive():Void
	{
		ApplyShaderProperties();
		for (child in childModels)
		{
			child.ApplyShaderProperties();
		}
	}
	// #endregion

	// #region 模型单元
	// #endregion

	// #region 锚点
	public function GetAnchor(name:String):Null<ModelAnchor>
	{
		return GraphicGroup.GetAnchor(name);
	}
	public function GetAllAnchors():Array<ModelAnchor>
	{
		return GraphicGroup.GetAllAnchors();
	}
	public function GetCenterTransform():Null<Transform>
	{
		var anchor = GetAnchor(LogicModelHelper.ANCHOR_CENTER);
		if (!UnityObject.exists(anchor))
			return null;
		return anchor.transform;
	}
	// #endregion
	public function GetRNG():RandomGenerator
	{
		return rng;
	}
	// #endregion

	// #region 插入模型
	public function AddModelInsertion(insertion:ModelInsertion):Void
	{
		if (!insertions.contains(insertion.key))
		{
			CreateChildModel(insertion.anchorName, insertion.key, insertion.modelID);
			insertions.push(insertion.key);
		}
	}
	public function RemoveModelInsertion(key:NamespaceID):Void
	{
		if (insertions.contains(key))
		{
			RemoveChildModel(key);
			insertions.remove(key);
		}
	}
	public function UpdateModelInsertions(target:Array<ModelInsertion>):Void
	{
		var removeModels:Array<NamespaceID> = insertions.copy();
		for (insertion in target)
		{
			removeModels.remove(insertion.key);
			if (!insertions.contains(insertion.key))
			{
				AddModelInsertion(insertion);
			}
		}
		for (key in removeModels)
		{
			RemoveModelInsertion(key);
		}
	}
	// #endregion

	public var OnUpdateFrame:FlxTypedSignal<Float->Void> = new FlxTypedSignal();

	// #region 属性字段
	public var GraphicGroup(get, never):ModelGroup;
	function get_GraphicGroup():ModelGroup
	{
		throw "abstract"; // abstract
	}

	private var id:NamespaceID;
	private var parentKey:Null<NamespaceID>;
	private var parentAnchor:Null<String>;
	private var eventCamera:Camera;

	private var destroyTimeout:Int;
	private var modelInterface:ModelParentInterface;
	private var rng:RandomGenerator;
	private var propertyDict:PropertyDictionaryString = new PropertyDictionaryString();
	private var modelComponents:Array<ModelComponent> = [];
	private var insertions:Array<NamespaceID> = [];

	// 嵌套
	private var parent:Null<Model>;
	private var childModels:Array<Model> = [];

	// 延迟摧毁
	@:serializeField
	private var destroyDelay:Int;
	@:serializeField
	private var onDelayedDestroy:UnityEvent = new UnityEvent();
	// #endregion
}

@:rtti
class SerializableModelData
{
	public var anchor:Null<String>;
	public var position:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var key:Null<NamespaceID>;
	public var id:Null<NamespaceID>;
	public var rng:Null<SerializableRNG>;
	public var graphicGroup:Null<SerializableModelGroup>;
	public var propertyDict:Null<SerializablePropertyDictionaryString>;
	public var childModels:Array<SerializableModelData>;
	public var insertions:Array<NamespaceID>;
	public var destroyTimeout:Int;

	public function new() {}
}

@:rtti
class SerializableAnimator
{
	public var playingDatas:Array<SerializableAnimatorPlayingData>;
	public var triggerParameters:Array<String> = [];
	public var boolParameters:Map<String, Bool> = [];
	public var intParameters:Map<String, Int> = [];
	public var floatParameters:Map<String, Float> = [];
	public var layerWeights:Array<Float> = [];

	public function new(animator:Animator)
	{
		var layerCount = animator.layerCount;

		playingDatas = [];
		for (i in 0...layerCount)
		{
			var current = animator.GetCurrentAnimatorStateInfo(i);
			var next = animator.GetNextAnimatorStateInfo(i);
			var transition = animator.GetAnimatorTransitionInfo(i);

			var playingData = new SerializableAnimatorPlayingData();
			playingData.currentHash = current.shortNameHash;
			playingData.currentTime = GetNormalizedTime(current.normalizedTime);

			playingData.nextHash = next.shortNameHash;
			playingData.nextNormalizedTime = GetNormalizedTime(next.normalizedTime);
			playingData.nextLength = next.length == Math.POSITIVE_INFINITY ? 0 : next.length;

			playingData.transitionDuration = transition.duration;
			playingData.transitionDurationUnit = (cast transition.durationUnit:Int);
			playingData.transitionTime = GetNormalizedTime(transition.normalizedTime);

			playingDatas.push(playingData);
			layerWeights.push(animator.GetLayerWeight(i));
		}

		for (para in animator.parameters)
		{
			var name = para.name;
			switch (para.type)
			{
				case AnimatorControllerParameterType.Bool:
					boolParameters.set(name, animator.GetBool(name));
				case AnimatorControllerParameterType.Float:
					floatParameters.set(name, animator.GetFloat(name));
				case AnimatorControllerParameterType.Int:
					intParameters.set(name, animator.GetInteger(name));
				case AnimatorControllerParameterType.Trigger:
					if (animator.GetBool(name))
					{
						triggerParameters.push(name);
					}
			}
		}
	}
	private function GetNormalizedTime(time:Float):Float
	{
		if (time > 1)
		{
			return (time - 1) % 1 + 1;
		}
		if (time < 0)
		{
			return time % 1;
		}
		return time;
	}
	public function Deserialize(animator:Animator):Void
	{
		if (triggerParameters != null)
		{
			for (trigger in triggerParameters)
			{
				if (trigger == null || trigger == "")
					continue;
				animator.SetTrigger(trigger);
			}
		}
		if (boolParameters != null)
		{
			for (pair in boolParameters.keys())
			{
				animator.SetBool(pair, boolParameters.get(pair));
			}
		}
		if (intParameters != null)
		{
			for (pair in intParameters.keys())
			{
				animator.SetInteger(pair, intParameters.get(pair));
			}
		}
		if (floatParameters != null)
		{
			for (pair in floatParameters.keys())
			{
				animator.SetFloat(pair, floatParameters.get(pair));
			}
		}
		if (layerWeights != null)
		{
			for (i in 0...animator.layerCount)
			{
				if (i >= layerWeights.length)
					continue;
				var weight = layerWeights[i];
				animator.SetLayerWeight(i, weight);
			}
		}

		if (playingDatas != null)
		{
			var layerCount = playingDatas.length;
			for (i in 0...layerCount)
			{
				var playingData = playingDatas[i];
				if (playingData == null)
					continue;
				var currentNameHash = playingData.currentHash;
				var currentNormalizedTime = GetNormalizedTime(playingData.currentTime);

				animator.PlayHash(currentNameHash, i, currentNormalizedTime);
			}

			for (i in 0...layerCount)
			{
				var playingData = playingDatas[i];
				if (playingData == null)
					continue;
				var nextFullPathHash = playingData.nextHash;
				if (nextFullPathHash != 0)
				{
					var nextNormalizedTime = GetNormalizedTime(playingData.nextNormalizedTime);
					var nextLength = playingData.nextLength;

					var transitionDurationUnit = (cast playingData.transitionDurationUnit:unity.DurationUnit);
					var transitionDuration = playingData.transitionDuration;
					var transitionNormalizedTime = GetNormalizedTime(playingData.transitionTime);
					if (transitionDurationUnit == unity.DurationUnit.Fixed)
					{
						animator.CrossFadeInFixedTime(nextFullPathHash, transitionDuration, i, nextLength, transitionNormalizedTime);
					}
					else
					{
						animator.CrossFadeHash(nextFullPathHash, transitionDuration, i, nextNormalizedTime, transitionNormalizedTime);
					}
				}
			}
		}
		animator.Update(0);
	}
}

@:rtti
class SerializableAnimatorPlayingData
{
	public var currentHash:Int;
	public var currentTime:Float;
	public var nextHash:Int;
	public var nextNormalizedTime:Float;
	public var nextLength:Float;
	public var transitionDurationUnit:Int;
	public var transitionDuration:Float;
	public var transitionTime:Float;

	public function new() {}
}

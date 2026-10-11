// Ported from: Assets/Scripts/View/Models/ModelGroup.cs
package mvz2.models;
import mvz2.models.Model.SerializableAnimator;  // IMPORTAUTO

import unity.Animator;
import unity.Application;
import unity.Color;
import unity.Debug;
import unity.UnityObject;
import unity.Vector4;

class ModelGroup extends unity.MonoBehaviour
{
	public function new() { super(); } // CTORFIX
	// #region 动画器
	public function UpdateFrame(deltaTime:Float):Void
	{
		for (element in animators)
		{
			if (testMode && Application.isEditor)
			{
				element.Animator.enabled = true;
			}
		}
	}
	public function UpdateAnimators(deltaTime:Float):Void
	{
		for (element in animators)
		{
			if (element == null || !element.gameObject.activeInHierarchy)
				continue;
			if (!testMode || !Application.isEditor)
			{
				var animator = element.Animator;
				animator.enabled = false;
				animator.Update(deltaTime);
			}
		}
	}
	public function GetAnimatorsToUpdate(results:Array<Animator>):Void
	{
		for (element in animators)
		{
			if (testMode && Application.isEditor)
				continue;
			if (element == null || !element.gameObject.activeInHierarchy)
				continue;
			var animator = element.Animator;
			if (animator.runtimeAnimatorController == null)
				continue;
			results.push(animator);
		}
	}
	public function TriggerAnimator(name:String):Void
	{
		for (element in animators)
		{
			var animator = element.Animator;
			animator.SetTrigger(name);
		}
	}
	public function SetAnimatorBool(name:String, value:Bool):Void
	{
		for (element in animators)
		{
			var animator = element.Animator;
			animator.SetBool(name, value);
		}
	}
	public function SetAnimatorInt(name:String, value:Int):Void
	{
		for (element in animators)
		{
			var animator = element.Animator;
			animator.SetInteger(name, value);
		}
	}
	public function SetAnimatorFloat(name:String, value:Float):Void
	{
		for (element in animators)
		{
			var animator = element.Animator;
			animator.SetFloat(name, value);
		}
	}
	public function GetAnimatorElement(name:String):Null<AnimatorElement>
	{
		for (element in animators)
		{
			if (element.elementName == name)
			{
				return element;
			}
		}
		return null;
	}

	// #endregion

	// #region 着色器
	// abstract
	public function SetShaderInt(name:String, value:Int):Void
	{
		throw "abstract";
	}
	// abstract
	public function SetShaderFloat(name:String, alpha:Float):Void
	{
		throw "abstract";
	}
	// abstract
	public function SetShaderColor(name:String, color:Color):Void
	{
		throw "abstract";
	}
	// abstract
	public function SetShaderVector(name:String, vector:Vector4):Void
	{
		throw "abstract";
	}
	// abstract
	public function ApplyShaderProperties():Void
	{
		throw "abstract";
	}
	// #endregion

	// #region 锚点
	public function GetAnchor(name:String):Null<ModelAnchor>
	{
		if (name == null || name == "")
			return null;
		// PORT-NOTE: Haxe 的 String 没有 hashCode（StringTools 也无），用简易字符串哈希替代 C# string.GetHashCode。
		var hash = StringHash.of(name);
		for (anchor in modelAnchors)
		{
			if (anchor == null)
				continue;
			if (anchor.KeyHash == hash)
				return anchor;
		}
		return null;
	}
	public function GetAllAnchors():Array<ModelAnchor>
	{
		return modelAnchors.copy();
	}
	// #endregion

	// #region 设置
	public function SetSimulationSpeed(speed:Float):Void
	{
	}
	public function SetGroundY(y:Float):Void
	{
		for (trans in transforms)
		{
			if (trans == null || !trans.LockToGround)
				continue;
			var pos = trans.transform.position;
			pos.y = y;
			trans.transform.position = pos;
		}
	}
	// #endregion

	// #region 元素管理
	// abstract
	public function AddElement(element:GraphicElement):Void
	{
		throw "abstract";
	}
	public function UpdateElements():Void
	{
		var newAnchors = Lambda.filter(GetComponentsInChildren(ModelAnchor, true), g -> ModelHelper.IsDirectChild(g, this));
		ModelHelper.ReplaceList(modelAnchors, newAnchors);

		var trans = Lambda.filter(GetComponentsInChildren(TransformElement, true), g -> ModelHelper.IsDirectChild(g, this));
		ModelHelper.ReplaceList(transforms, trans);

		var anims:Array<AnimatorElement> = [];
		var index = 0;
		for (r in Lambda.filter(GetComponentsInChildren(Animator, true), g -> ModelHelper.IsDirectChild(g, this)))
		{
			var element = r.GetComponent(AnimatorElement);
			if (element == null)
			{
				element = r.gameObject.AddComponent(AnimatorElement);
				element.elementName = index == 0 ? "main" : 'element_${index}';
			}
			anims.push(element);
			index++;
		}
		ModelHelper.ReplaceList(animators, anims);
	}
	// #endregion

	// #region 序列化
	// abstract
	public function ToSerializable():SerializableModelGroup
	{
		throw "abstract";
	}
	public function FromSerializable(serializable:SerializableModelGroup):Void
	{
		if (animators != null && serializable.animators != null)
		{
			for (i in 0...animators.length)
			{
				if (i >= serializable.animators.length)
					break;
				var element = animators[i];
				var data = serializable.animators[i];
				if (!UnityObject.exists(element) || data == null)
					continue;
				data.Deserialize(element.Animator);
			}
		}
		LoadFromSerializable(serializable);
	}
	function SaveToSerializableGroup(serializable:SerializableModelGroup):Void
	{
		serializable.animators = [for (a in animators) a.ToSerializable()];
	}
	function LoadFromSerializable(serializable:SerializableModelGroup):Void
	{
	}
	// #endregion

	// #region 生命周期
	function Awake():Void
	{
		for (element in animators)
		{
			if (element == null)
			{
				Debug.LogWarning('Model ${gameObject.name} has a missing animator!');
				return;
			}
			var animator = element.Animator;
			animator.logWarnings = false;
		}
	}
	// #endregion

	// #region 属性与字段
	@:serializeField
	private var testMode:Bool = false;
	@:serializeField
	private var modelAnchors:Array<ModelAnchor> = [];
	@:serializeField
	private var animators:Array<AnimatorElement> = [];
	@:serializeField
	private var transforms:Array<TransformElement> = [];
	// #endregion
}

@:rtti
class SerializableModelGroup
{
	public var animators:Array<SerializableAnimator>;

	public function new() {}
}

// PORT-NOTE: 简易字符串哈希（C# string.GetHashCode 的对应物）。
class StringHash {
	public static function of(s:String):Int {
		var h = 0;
		if (s != null) {
			for (i in 0...s.length)
				h = 31 * h + s.charCodeAt(i);
		}
		return h & 0x7FFFFFFF;
	}
}

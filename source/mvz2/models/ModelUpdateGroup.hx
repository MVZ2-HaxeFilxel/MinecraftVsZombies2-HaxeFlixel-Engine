// Ported from: Assets/Scripts/View/Models/Area/ModelUpdateGroup.cs
package mvz2.models;
import mvz2.models.Model.SerializableAnimator;  // IMPORTAUTO

import unity.Animator;
import unity.ParticleSystem;
import unity.Transform;
import unity.UnityObject;

class ModelUpdateGroup extends unity.MonoBehaviour
{
	// #region 公有方法
	public function UpdateFrame(deltaTime:Float):Void
	{
		for (animator in animators)
		{
			animator.enabled = false;
			animator.Update(deltaTime);
		}
	}
	public function SetSimulationSpeed(speed:Float):Void
	{
		for (particle in particles)
		{
			particle.SetSimulationSpeed(speed);
		}
	}
	public function UpdateElements():Void
	{
		particles.resize(0);
		for (ps in GetComponentsInChildren(ParticleSystem, true))
		{
			if (!IsParticleChildOfGroup(ps.transform, this))
				continue;
			var player = ps.GetComponent(ParticlePlayer);
			if (player == null)
			{
				player = ps.gameObject.AddComponent(ParticlePlayer);
			}
			particles.push(player);
		}

		animators.resize(0);
		for (animator in GetComponentsInChildren(Animator, true))
		{
			if (!IsChildOfGroup(animator.transform, this))
				continue;
			animators.push(animator);
		}
	}
	public function TriggerAnimator(name:String):Void
	{
		for (animator in animators)
		{
			animator.SetTrigger(name);
		}
	}
	public function SetAnimatorBool(name:String, value:Bool):Void
	{
		for (animator in animators)
		{
			animator.SetBool(name, value);
		}
	}
	public function SetAnimatorInt(name:String, value:Int):Void
	{
		for (animator in animators)
		{
			animator.SetInteger(name, value);
		}
	}
	public function SetAnimatorFloat(name:String, value:Float):Void
	{
		for (animator in animators)
		{
			animator.SetFloat(name, value);
		}
	}

	public function ToSerializable():SerializableModelUpdateGroup
	{
		var serializable = new SerializableModelUpdateGroup();
		serializable.animators = [for (a in animators) new SerializableAnimator(a)];
		serializable.particles = [for (e in particles) e.ToSerializable()];
		return serializable;
	}
	public function LoadFromSerializable(serializable:SerializableModelUpdateGroup):Void
	{
		if (serializable.animators != null)
		{
			for (i in 0...animators.length)
			{
				if (i >= serializable.animators.length)
					break;
				var data = serializable.animators[i];
				if (data == null)
					continue;
				var animator = animators[i];
				data.Deserialize(animator);
			}
		}
		if (serializable.particles != null)
		{
			for (i in 0...particles.length)
			{
				if (i >= serializable.particles.length)
					break;
				var data = serializable.particles[i];
				if (data == null)
					continue;
				var particle = particles[i];
				particle.LoadFromSerializable(data);
			}
		}
	}
	// #endregion

	// #region 私有方法
	function Awake():Void
	{
		for (animator in animators)
		{
			animator.logWarnings = false;
		}
	}
	private static function IsChildOfGroup(child:Transform, group:ModelUpdateGroup):Bool
	{
		return child.GetComponentInParent(ModelUpdateGroup) == group;
	}
	private static function IsParticleChildOfGroup(child:Transform, group:ModelUpdateGroup):Bool
	{
		return child.parent.GetComponentInParent(ParticleSystem) == null && IsChildOfGroup(child, group);
	}
	// #endregion

	@:serializeField
	private var animators:Array<Animator> = [];
	@:serializeField
	private var particles:Array<ParticlePlayer> = [];
}

@:rtti
class SerializableModelUpdateGroup
{
	public var animators:Array<SerializableAnimator>;
	public var particles:Array<SerializableParticleSystem>;

	public function new() {}
}

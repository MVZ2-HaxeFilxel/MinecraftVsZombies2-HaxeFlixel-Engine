// Ported from: Assets/Scripts/View/Models/Particles/SerializableParticle.cs
package mvz2.models;

import unity.Color;
import unity.ParticleSystem.Particle;
import unity.Vector3;

@:rtti
class SerializableParticle
{
	public var position:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var rotation3D:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var startSize3D:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var velocity:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var angularVelocity3D:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var axisOfRotation:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用

	public var randomSeed:Int;
	public var startColor:Color = new Color(0, 0, 0, 0); // PORT-NOTE: C# Color 为 struct，default 为 (0,0,0,0) 透明黑；显式初始化避免 abstract-over-class 的 null 解引用
	public var startLifetime:Float;
	public var remainingLifetime:Float;

	public function new(particle:Particle)
	{
		position = particle.position;
		rotation3D = particle.rotation3D;
		startSize3D = particle.startSize3D;
		velocity = particle.velocity;
		angularVelocity3D = particle.angularVelocity3D;
		axisOfRotation = particle.axisOfRotation;

		// PORT-NOTE: Unity 的 Particle.randomSeed 是 uint，移植层用 Int 表示。
		randomSeed = particle.randomSeed;
		startColor = particle.startColor;
		startLifetime = particle.startLifetime;
		remainingLifetime = particle.remainingLifetime;
	}
	public function Deserialize():Particle
	{
		var particle = new Particle();
		particle.position = position;
		particle.rotation3D = rotation3D;
		particle.startSize3D = startSize3D;
		particle.velocity = velocity;
		particle.angularVelocity3D = angularVelocity3D;
		particle.axisOfRotation = axisOfRotation;

		particle.randomSeed = randomSeed;
		particle.startColor = startColor;
		particle.startLifetime = startLifetime;
		particle.remainingLifetime = remainingLifetime;
		return particle;
	}
}

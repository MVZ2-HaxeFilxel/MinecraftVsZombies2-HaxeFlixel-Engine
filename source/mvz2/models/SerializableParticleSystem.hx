// Ported from: Assets/Scripts/View/Models/Particles/SerializableParticleSystem.cs
package mvz2.models;

import unity.ParticleSystem;
import unity.ParticleSystem.Particle;  // SUBIMPORT
import unity.ParticleSystemStopBehavior;

@:rtti
class SerializableParticleSystem
{
	public var stateBeforePaused:Int;
	public var state:Int;
	public var seed:Int;
	public var time:Float;
	public var particles:Array<SerializableParticle>;

	public function new(particleSystem:ParticleSystem)
	{
		// PORT-NOTE: Unity 的 ParticleSystem.randomSeed 是 uint，移植层用 Int 表示。
		seed = particleSystem.randomSeed;
		time = particleSystem.time;
		state = (cast GetState(particleSystem):Int);
		var parts:Array<Particle> = [];
		parts.resize(particleSystem.particleCount);
		for (i in 0...parts.length)
		{
			parts[i] = new Particle();
		}
		particleSystem.GetParticles(parts);
		particles = [for (p in parts) new SerializableParticle(p)];
	}
	public function Load(particleSystem:ParticleSystem):Void
	{
		particleSystem.Stop(false, ParticleSystemStopBehavior.StopEmittingAndClear);
		particleSystem.randomSeed = seed;
		particleSystem.time = time;

		if (particles != null)
		{
			var count = particles.length;
			var parts:Array<Particle> = [];
			parts.resize(count);
			for (i in 0...count)
			{
				var particleData = particles[i];
				if (particleData == null)
					continue;
				parts[i] = particleData.Deserialize();
			}
			particleSystem.SetParticles(parts);
		}
		SetState((cast state:ParticleState), particleSystem);
	}
	private function GetState(particleSystem:ParticleSystem):ParticleState
	{
		if (particleSystem.isEmitting)
		{
			if (particleSystem.isPlaying)
			{
				return ParticleState.EmittingAndPlaying;
			}
			return ParticleState.Emitting;
		}
		else if (particleSystem.isPlaying)
		{
			return ParticleState.Playing;
		}
		else if (particleSystem.isPaused)
		{
			return ParticleState.Pausing;
		}
		return ParticleState.Stopped;
	}
	private function SetState(state:ParticleState, particle:ParticleSystem):Void
	{
		switch (state)
		{
			case ParticleState.Playing:
				particle.Play();
				if (particle.isEmitting)
				{
					particle.Stop(false, ParticleSystemStopBehavior.StopEmitting);
				}
			case ParticleState.Pausing:
				particle.Play(false);
				particle.Pause(false);
			case ParticleState.EmittingAndPlaying:
				particle.Play(false);
			case ParticleState.Emitting:
				// PORT-NOTE: C# switch 不强制穷举，此分支在 C# 中为空（无操作）；Haxe 需要显式列出。
			case ParticleState.Stopped:
				if (particle.isPaused)
				{
					particle.Play();
				}
				particle.Stop(false, ParticleSystemStopBehavior.StopEmitting);
		}
	}
}

// C# 中为 SerializableParticleSystem 的私有嵌套枚举 ParticleState。
enum abstract ParticleState(Int)
{
	var Stopped = 0;
	var Pausing = 1;
	var Playing = 2;
	var Emitting = 3;
	var EmittingAndPlaying = 4;
}

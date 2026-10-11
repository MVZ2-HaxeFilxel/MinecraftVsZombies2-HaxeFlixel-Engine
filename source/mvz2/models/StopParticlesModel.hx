// Ported from: Assets/Scripts/MVZ2/Models/Components/Effects/StopParticlesModel.cs
package mvz2.models;

import tools.ObjectExtensions;
import unity.ParticleSystemStopBehavior;  // UNKNOWNIMPORT
import unity.ParticleSystem;
import unity.UnityObject;

class StopParticlesModel extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        super.UpdateFrame(deltaTime);
        var stopped:Bool = Model.GetProperty("ParticleStopped");
        if (stopped && particles != null) {
            for (particle in particles) {
                if (particle == null || !unity.UnityObject.exists(particle) || !particle.Particles.isPlaying)
                    continue;
                particle.Particles.Stop(false, ParticleSystemStopBehavior.StopEmitting);
            }
        }
    }
    private var particles:Array<ParticlePlayer>;
}

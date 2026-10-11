package unity;

// Minimal UnityEngine.ParticleSystem shim.
// PORT-NOTE: 粒子模拟由移植层的 Flixel 实现负责，这里保留 Unity API 形状并缓存序列化所需数据。
class ParticleSystem extends Component {
	// PORT-NOTE: 补全 textureSheetAnimation占位（移植层不实现子粒子 sprite sheet 动画）。
	public var textureSheetAnimation:TextureSheetAnimationModule = new TextureSheetAnimationModule();
	public var main:MainModule = new MainModule();
    public var emission:EmissionModule = new EmissionModule();
    public var shape:ShapeModule = new ShapeModule();
    public var renderer:ParticleSystemRenderer;

    public var randomSeed:Int = 0;
    public var useAutoRandomSeed:Bool = true;
    public var time:Float = 0;
    public var particleCount(get, never):Int;
    function get_particleCount():Int return particles.length;
    public var isPlaying(get, never):Bool;
    function get_isPlaying():Bool return playing;
    public var isPaused(get, never):Bool;
    function get_isPaused():Bool return paused;
    public var isEmitting(get, never):Bool;
    function get_isEmitting():Bool return emitting;
    public var isStopped(get, never):Bool;
    function get_isStopped():Bool return !playing && !paused;
    public var loop:Bool = true;
    public var playOnAwake:Bool = true;
    public var duration:Float = 5;

    private var playing:Bool = false;
    private var paused:Bool = false;
    private var emitting:Bool = false;
    private var particles:Array<Particle> = [];

    public function new() {
        super();
        renderer = new ParticleSystemRenderer();
    }

    public function Play(?withChildren:Bool = true):Void {
        playing = true;
        paused = false;
        emitting = true;
    }
    public function Pause(?withChildren:Bool = true):Void {
        paused = true;
    }
    public function Stop(?withChildren:Bool = true, ?stopBehavior:ParticleSystemStopBehavior = ParticleSystemStopBehavior.StopEmittingAndClear):Void {
        playing = false;
        paused = false;
        emitting = false;
        if (stopBehavior == ParticleSystemStopBehavior.StopEmittingAndClear) particles = [];
    }
    public function Clear(?withChildren:Bool = true):Void particles = [];
    public function Simulate(time:Float, ?withChildren:Bool = true, ?restart:Bool = true, ?fixedTimeStep:Bool = true):Void {}
    public function Emit(count:Int):Void {
        for (i in 0...count) particles.push(new Particle());
    }
    public function GetParticles(particles:Array<Particle>):Int {
        var count = Std.int(Math.min(particles.length, this.particles.length));
        for (i in 0...count) particles[i] = this.particles[i];
        return this.particles.length;
    }
    public function SetParticles(particles:Array<Particle>, ?size:Int = -1):Int {
        this.particles = particles.copy();
        return particles.length;
    }
    public function GetParticleCurrentSize(index:Int):Float return 0;

    // ---- 子模块 ----
    public var mainModule(get, never):MainModule;
    function get_mainModule():MainModule return main;
}

// Minimal UnityEngine.ParticleSystem.MainModule shim.
class MainModule {
	// PORT-NOTE: 补全 startSpeedMultiplier（粒子模拟由 Flixel 实现，此处仅保留数值）。
	public var startSpeedMultiplier:Float = 1;
    public var duration:Float = 5;
    public var loop:Bool = true;
    public var prewarm:Bool = false;
    public var startDelay:Float = 0;
    public var startLifetime:MinMaxCurve = new MinMaxCurve(5);
    public var startSpeed:MinMaxCurve = new MinMaxCurve(5);
    public var startSize:MinMaxCurve = new MinMaxCurve(1);
    public var startRotation:MinMaxCurve = new MinMaxCurve(0);
    public var startColor:MinMaxGradient = new MinMaxGradient();
    public var gravityModifier:MinMaxCurve = new MinMaxCurve(0);
    public var simulationSpace:ParticleSystemSimulationSpace = ParticleSystemSimulationSpace.Local;
    public var simulationSpeed:Float = 1;
    public var scalingMode:ParticleSystemScalingMode = ParticleSystemScalingMode.Local;
    public var playOnAwake:Bool = true;
    public var maxParticles:Int = 1000;
    public var cullingMode:ParticleSystemCullingMode = ParticleSystemCullingMode.Automatic;

    public function new() {}
}

// Minimal UnityEngine.ParticleSystem.EmissionModule shim.
class EmissionModule {
    public var enabled:Bool = true;
    public var rateOverTime:MinMaxCurve = new MinMaxCurve(10);
    public var rateOverDistance:MinMaxCurve = new MinMaxCurve(0);
    public var rateOverTimeMultiplier:Float = 10;
    public var rateOverDistanceMultiplier:Float = 0;
    public var burstCount(get, never):Int;
    function get_burstCount():Int return bursts.length;
    private var bursts:Array<Burst> = [];

    public function new() {}

    public function SetBursts(bursts:Array<Burst>, ?size:Int = -1):Void this.bursts = bursts.copy();
    public function GetBursts(bursts:Array<Burst>):Int {
        var count = Std.int(Math.min(bursts.length, this.bursts.length));
        for (i in 0...count) bursts[i] = this.bursts[i];
        return this.bursts.length;
    }
    public function GetBurst(index:Int):Burst {
        if (index < 0 || index >= bursts.length) return null;
        var b = bursts[index];
        if (b == null) { b = new Burst(); bursts[index] = b; }
        return b;
    }
    public function SetBurst(index:Int, burst:Burst):Void {
        if (index < 0 || index >= bursts.length) return;
        bursts[index] = burst;
    }
    public function SetBurstsArray(bursts:Array<Burst>):Void this.bursts = bursts;
}

// Minimal UnityEngine.ParticleSystem.ShapeModule shim.
class ShapeModule {
    public var enabled:Bool = true;
    public var shapeType:ParticleSystemShapeType = ParticleSystemShapeType.Cone;
    public var radius:Float = 1;
    public var angle:Float = 25;
    public var arc:Float = 360;
    public function new() {}
	// PORT-NOTE: 补全 ShapeModule 的 position/scale/rotation（Unity 的发射形状参数，Flixel 端不参与模拟）。
	public var position:Vector3 = new Vector3();
	public var scale:Vector3 = new Vector3(1, 1, 1);
	public var rotation:Vector3 = new Vector3();
}

// Minimal UnityEngine.ParticleSystem.Particle shim.
class Particle {
    public var position:Vector3 = new Vector3();
    public var rotation3D:Vector3 = new Vector3();
    public var startSize3D:Vector3 = new Vector3(1, 1, 1);
    public var velocity:Vector3 = new Vector3();
    public var angularVelocity3D:Vector3 = new Vector3();
    public var axisOfRotation:Vector3 = new Vector3();

    public var randomSeed:Int = 0;
    public var startColor:Color = new Color(1, 1, 1, 1);
    public var startLifetime:Float = 5;
    public var remainingLifetime:Float = 5;
    public var startSize:Float = 1;
    public var rotation:Float = 0;
    public var angularVelocity:Float = 0;

    public function new() {}
}

// Minimal UnityEngine.ParticleSystem.MinMaxCurve shim.
class MinMaxCurve {
    public var mode:ParticleSystemCurveMode = ParticleSystemCurveMode.Constant;
    public var curveMultiplier:Float = 1;
    public var constant:Float = 0;
    public var constantMax:Float = 0;
    public var constantMin:Float = 0;
    public var curve:AnimationCurve;
    public var curveMin:AnimationCurve;
    public var curveMax:AnimationCurve;

    public function new(?constant:Float = 0, ?curve:AnimationCurve = null) {
        this.constant = constant;
        this.curve = curve;
    }
    public function Evaluate(time:Float):Float return constant;
}

// Minimal UnityEngine.ParticleSystem.MinMaxGradient shim.
class MinMaxGradient {
    public var mode:ParticleSystemGradientMode = ParticleSystemGradientMode.Color;
    public var color:Color = new Color(1, 1, 1, 1);
    public var colorMax:Color = new Color(1, 1, 1, 1);
    public var colorMin:Color = new Color(1, 1, 1, 1);
    public var gradient:Gradient;
    public var gradientMax:Gradient;
    public var gradientMin:Gradient;

    public function new(?color:Color = null) {
        if (color != null) this.color = color;
    }
}

// Minimal UnityEngine.ParticleSystem.Burst shim.
class Burst {
    public var count:MinMaxCurve = new MinMaxCurve(0);
    public var time:Float = 0;
    public var cycleCount:Int = 1;
    public var repeatInterval:Float = 1;
    public var probability:Float = 1;

    public function new(?time:Float = 0, ?count:Float = 0) {
        this.time = time;
        this.count = new MinMaxCurve(count);
    }
}

// PORT-NOTE: UnityEngine.ParticleSystem.TextureSheetAnimationModule 的最小占位实现。
class TextureSheetAnimationModule {
	public var enabled:Bool = false;
	// PORT-NOTE: 补全 spriteCount/GetSprite/SetSprite（sprites 列表由调用方维护）。
	public var spriteCount(get, never):Int;
	private var sprites:Array<Dynamic> = [];
	function get_spriteCount():Int return sprites.length;
	public function GetSprite(index:Int):Dynamic return (index >= 0 && index < sprites.length) ? sprites[index] : null;
	public function SetSprite(index:Int, sprite:Dynamic):Void {
		while (sprites.length <= index) sprites.push(null);
		sprites[index] = sprite;
	}
	public var mode:Dynamic = null;
	public var numTilesX:Int = 1;
	public var numTilesY:Int = 1;
	public var animation:Dynamic = null;
	public function new() {}
}

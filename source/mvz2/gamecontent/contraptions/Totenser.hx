// Ported from: Assets/Scripts/Vanilla/GameContent/Contraptions/Chapter2/Totenser.cs
package mvz2.gamecontent.contraptions;

import mvz2.gamecontent.detections.FireBreathDetector;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.projectiles.VanillaProjectileID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.contraptions.VanillaContraptionStates;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.EntityID;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import unity.Vector3;
import unity.UnityObject;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2.vanilla.projectiles.VanillaProjectileExt;
using mvz2logic.entities.LogicContraptionProps;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaContraptionNames.totenser)
class Totenser extends DispenserFamily
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        fireBreathDetector = new FireBreathDetector(VanillaEffectID.fireBreath);
    }

    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        InitShootTimer(entity);
    }
    override function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);
        if (!entity.IsEvoked())
        {
            ShootTick(entity);
        }
        else
        {
            EvokedUpdate(entity);
        }
    }
    override function UpdateLogic(entity:Entity):Void
    {
        super.UpdateLogic(entity);
        UpdateFireBreath(entity);
        entity.SetAnimationFloat("SpearSpeed", entity.IsAIFrozen() ? 0 : 1);
    }
    override function OnEvoke(entity:Entity):Void
    {
        super.OnEvoke(entity);
        entity.SetEvoked(true);
        entity.TriggerAnimation("Throw");
        SetEvocationTime(entity, 0);
    }
    function UpdateFireBreath(entity:Entity):Void
    {
        if (entity.IsTimeInterval(FIRE_DETECT_INTERVAL))
        {
            var target = fireBreathDetector.Detect(DetectionParams.fromEntity(entity));
            if (target != null && !entity.IsAIFrozen())
            {
                entity.State = STATE_FIRE_BREATH;
            }
            else
            {
                entity.State = STATE_IDLE;
            }
        }
        if (entity.State == STATE_FIRE_BREATH)
        {
            var fireBreath = GetFireBreath(entity);
            var position = entity.Position + Vector3.up * 5;
            if (fireBreath == null || !unity.UnityObject.exists(fireBreath))
            {
                // C#: entity.Level.Spawn(...)?.Let(e => { e.SetParent(entity); SetFireBreath(entity, e); })
                fireBreath = entity.Level.Spawn(VanillaEffectID.fireBreath, position, entity);
                if (fireBreath != null)
                {
                    fireBreath.SetParent(entity);
                    SetFireBreath(entity, fireBreath);
                }
            }
            // C#: fireBreath?.Let(e => { ... })
            if (fireBreath != null)
            {
                fireBreath.SetDamage(entity.GetDamage() * 2 / 3);
                fireBreath.SetFlipX(entity.IsFlipX());
                fireBreath.Position = position;
                fireBreath.SetFaction(entity.GetFaction());
            }
        }
        else
        {
            var fireBreath = GetFireBreath(entity);
            if (fireBreath != null)
            {
                fireBreath.SetParent(null);
                SetFireBreath(entity, null);
            }
        }
    }
    function EvokedUpdate(entity:Entity):Void
    {
        var evocationTime = GetEvocationTime(entity);
        evocationTime++;
        if (evocationTime == HATCH_OPEN_TIME || evocationTime == HATCH_CLOSE_TIME)
        {
            entity.PlaySound(VanillaSoundID.stoneHatch);
        }
        if (evocationTime == THROW_JAVELIN_TIME)
        {
            var shootParams = entity.GetShootParams();
            shootParams.position = entity.Position + new Vector3(80 * entity.GetFacingX(), 80);
            shootParams.velocity = entity.GetFacingDirection() * 33;
            shootParams.projectileID = VanillaProjectileID.poisonJavelin;
            shootParams.damage = 1800;
            shootParams.soundID = VanillaSoundID.fling;
            var javelin = entity.ShootProjectile(shootParams);
            entity.PlaySound(VanillaSoundID.poisonCast);
        }
        if (evocationTime >= MAX_EVOCATION_TIME)
        {
            evocationTime = 0;
            entity.SetEvoked(false);
        }
        SetEvocationTime(entity, evocationTime);
    }
    public static function GetEvocationTime(entity:Entity):Int return entity.GetBehaviourFieldNS(ID, PROP_EVOCATION_TIME);
    public static function SetEvocationTime(entity:Entity, value:Int):Void entity.SetBehaviourFieldNS(ID, PROP_EVOCATION_TIME, value);
    public static function GetFireBreath(entity:Entity):Null<Entity>
    {
        var entityID = entity.GetBehaviourFieldNS(ID, PROP_FIRE_BREATH);
        if (entityID == null)
            return null;
        return entityID.GetEntity(entity.Level);
    }
    public static function SetFireBreath(entity:Entity, value:Null<Entity>):Void
    {
        entity.SetBehaviourFieldNS(ID, PROP_FIRE_BREATH, value != null ? new EntityID(value) : null);
    }
    static var ID:NamespaceID = VanillaContraptionID.totenser;
    public static var PROP_EVOCATION_TIME:VanillaEntityPropertyMeta<Int> = new VanillaEntityPropertyMeta<Int>("EvocationTime");
    public static var PROP_FIRE_BREATH:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("FireBreath");
    var fireBreathDetector:Detector;
    public static inline var STATE_IDLE:Int = VanillaContraptionStates.IDLE;
    public static inline var STATE_FIRE_BREATH:Int = VanillaContraptionStates.TOTENSER_FIRE_BREATH;
    public static inline var FIRE_DETECT_INTERVAL:Int = 7;
    public static inline var THROW_JAVELIN_TIME:Int = 30;
    public static inline var MAX_EVOCATION_TIME:Int = 48;
    public static inline var HATCH_OPEN_TIME:Int = 1;
    public static inline var HATCH_CLOSE_TIME:Int = 45;
}

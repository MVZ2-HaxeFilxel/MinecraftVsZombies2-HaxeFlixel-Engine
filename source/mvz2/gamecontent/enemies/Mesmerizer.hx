// Ported from: Assets/Scripts/Vanilla/GameContent/Enemies/Chapter3/Mesmerizer.cs
package mvz2.gamecontent.enemies;

import mvz2.gamecontent.detections.DispenserDetector;
import mvz2.gamecontent.entities.AIEntityBehaviour;
import mvz2.gamecontent.projectiles.CompellingOrb;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEnemyStates;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.EntityID;
import pvzengine.NamespaceID;
import pvzengine.collisions.IEntityCollider;
import pvzengine.damages.DeathInfo;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollisionHelper;
import tools.FrameTimer;
import unity.Mathf;
import unity.UnityObject;
using mvz2.vanilla.contraptions.VanillaContraptionProps;
using mvz2.vanilla.enemies.VanillaEnemyProps;
using mvz2.vanilla.entities.VanillaColliderExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2.vanilla.projectiles.VanillaProjectileExt;

@:autoEntityBehaviourDefinition(VanillaEnemyNames.mesmerizer)
class Mesmerizer extends AIEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        detector = new DispenserDetector();
        cast(detector, DispenserDetector).mask = EntityCollisionHelper.MASK_PLANT | EntityCollisionHelper.MASK_ENEMY | EntityCollisionHelper.MASK_OBSTACLE;
        cast(detector, DispenserDetector).ignoreHighEnemy = false;
        cast(detector, DispenserDetector).ignoreLowEnemy = false;
        cast(detector, DispenserDetector).colliderFilter = (p, c) -> ColliderFilter(p.entity, c);
    }

    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        SetStateTimer(entity, new FrameTimer(CAST_COOLDOWN));
    }
    override function UpdateAI(entity:Entity):Void
    {
        super.UpdateAI(entity);

        if (entity.State == STATE_WALK)
        {
            var stateTimer = GetStateTimer(entity);
            if (stateTimer.RunToExpiredAndNotNull(entity.GetAttackSpeed()))
            {
                var target = detector.DetectEntityWithTheLeast(DetectionParams.fromEntity(entity), t -> Mathf.Abs(entity.Position.x - t.Position.x));
                if (target == null)
                {
                    stateTimer.Frame = CONTROL_DETECT_TIME;
                }
                else
                {
                    var param = entity.GetShootParams();
                    param.damage = 0;
                    var orb = entity.ShootProjectile(param);
                    if (orb != null)
                    {
                        orb.Target = target;
                        orb.SetParent(entity);
                        SetOrb(entity, new EntityID(orb));
                        entity.SetCasting(true);
                    }
                }
            }
        }
        else if (entity.State == STATE_CAST)
        {
            var orbID = GetOrb(entity);
            var orb = orbID != null ? orbID.GetEntity(entity.Level) : null;
            if (orb == null || !unity.UnityObject.exists(orb) || orb.IsDead)
            {
                EndCasting(entity);
            }
        }
    }
    public override function PostDeath(entity:Entity, info:DeathInfo):Void
    {
        super.PostDeath(entity, info);
        if (entity.State == STATE_CAST)
        {
            EndCasting(entity);
        }
    }
    function EndCasting(entity:Entity):Void
    {
        var stateTimer = GetStateTimer(entity);
        if (stateTimer != null)
            stateTimer.Reset();
        entity.SetCasting(false);
    }
    function ColliderFilter(self:Entity, collider:IEntityCollider):Bool
    {
        if (!collider.IsForMain())
            return false;
        var target = collider.Entity;
        if (!CompellingOrb.CanControl(self, target))
            return false;
        if (target.IsFloor())
            return false;
        return true;
    }

    public static function SetOrb(entity:Entity, value:EntityID):Void entity.SetBehaviourFieldNS(ID, PROP_ORB, value);
    public static function GetOrb(entity:Entity):Null<EntityID> return entity.GetBehaviourFieldNS(ID, PROP_ORB);
    public static function SetStateTimer(entity:Entity, timer:FrameTimer):Void entity.SetBehaviourFieldNS(ID, PROP_STATE_TIMER, timer);
    public static function GetStateTimer(entity:Entity):Null<FrameTimer> return entity.GetBehaviourFieldNS(ID, PROP_STATE_TIMER);

    //region 常量
    static inline var CAST_COOLDOWN:Int = 300;
    static inline var CONTROL_DETECT_TIME:Int = 30;

    public static inline var STATE_WALK:Int = LogicEnemyStates.WALK;
    public static inline var STATE_MELEE_ATTACK:Int = LogicEnemyStates.MELEE_ATTACK;
    public static inline var STATE_CAST:Int = LogicEnemyStates.CAST;
    var detector:Detector;
    public static var ID:NamespaceID = VanillaEnemyID.mesmerizer;
    public static var PROP_ORB:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("Orb");
    public static var PROP_STATE_TIMER:VanillaEntityPropertyMeta<FrameTimer> = new VanillaEntityPropertyMeta<FrameTimer>("StateTimer");
    //endregion 常量
}

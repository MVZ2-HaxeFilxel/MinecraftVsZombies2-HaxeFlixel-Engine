// Ported from: Assets/Scripts/Vanilla/GameContent/Projectiles/Chapter3/CompellingOrb.cs
package mvz2.gamecontent.projectiles;

import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostProjectileHitParams;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.projectiles.VanillaProjectileStates;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.EngineEntityProps;
import pvzengine.NamespaceID;
import pvzengine.callbacks.CallbackResult;
import pvzengine.damages.DeathInfo;
import pvzengine.definitions.EntityBehaviourDefinition;
import pvzengine.entities.Entity;
import pvzengine.entities.EntitySourceReference;
import pvzengine.entities.EntityTypes;
import tools.FrameTimer;
import unity.Color;
import unity.Vector3;
import unity.UnityObject;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaProjectileNames.compellingOrb)
class CompellingOrb extends EntityBehaviourDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddTrigger(VanillaLevelCallbacks.POST_PROJECTILE_HIT, PostHitEntityCallback);
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        SetStateTimer(entity, new FrameTimer(30));
    }
    public override function Update(projectile:Entity):Void
    {
        super.Update(projectile);
        if (projectile.Target == null || !unity.UnityObject.exists(projectile.Target) || projectile.Target.IsDead ||
            projectile.Parent == null || !unity.UnityObject.exists(projectile.Parent) || projectile.Parent.IsDead)
        {
            projectile.Die();
            return;
        }

        if (projectile.State == STATE_IDLE)
        {
            var timer = GetStateTimer(projectile);
            if (timer.RunToExpiredAndNotNull())
            {
                projectile.State = STATE_FLY;
                projectile.Velocity = (projectile.Target.GetCenter() - projectile.GetCenter()).normalized * 20;
            }
        }
        projectile.RenderRotation += Vector3.forward * 10;
    }
    function PostHitEntityCallback(param:PostProjectileHitParams, result:CallbackResult):Void
    {
        var hitResult = param.hit;
        var projectile = hitResult.Projectile;
        if (!projectile.Definition.HasBehaviour(this))
            return;
        if (hitResult.Shield != null)
            return;
        var target = hitResult.Other;
        var mesmerizer = projectile.Parent;
        if (!mesmerizer.ExistsAndAlive() || !CanControl(mesmerizer, target))
        {
            target.PlaySound(VanillaSoundID.mindClear);
            return;
        }
        target.CharmWithController(mesmerizer, new EntitySourceReference(projectile));
        target.PlaySound(VanillaSoundID.mindControl);
    }
    public override function PostDeath(entity:Entity, damageInfo:DeathInfo):Void
    {
        super.PostDeath(entity, damageInfo);
        var param = entity.GetSpawnParams();
        param.SetProperty(EngineEntityProps.TINT, Color.magenta);
        param.SetProperty(EngineEntityProps.SIZE, entity.GetScaledSize());
        entity.Spawn(VanillaEffectID.smoke, entity.Position, param);
    }
    public static function CanControl(mesmerizer:Entity, target:Entity):Bool
    {
        return !target.IsLoyal() && target != mesmerizer && !target.IsCharmed() && (target.Type == EntityTypes.PLANT || target.Type == EntityTypes.ENEMY || target.Type == EntityTypes.OBSTACLE);
    }
    public static function SetStateTimer(entity:Entity, timer:FrameTimer):Void entity.SetBehaviourFieldNS(ID, PROP_STATE_TIMER, timer);
    public static function GetStateTimer(entity:Entity):Null<FrameTimer> return entity.GetBehaviourFieldNS(ID, PROP_STATE_TIMER);
    public static inline var STATE_IDLE:Int = VanillaProjectileStates.IDLE;
    public static inline var STATE_FLY:Int = VanillaProjectileStates.COMPELLING_ORB_FLY;

    static var ID:NamespaceID = VanillaProjectileID.compellingOrb;
    static var PROP_STATE_TIMER:VanillaEntityPropertyMeta<FrameTimer> = new VanillaEntityPropertyMeta<FrameTimer>("StateTimer");
}

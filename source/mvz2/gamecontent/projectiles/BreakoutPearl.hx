// Ported from: Assets/Scripts/Vanilla/GameContent/Projectiles/Chapter2/BreakoutPearl.cs
package mvz2.gamecontent.projectiles;

import unity.UnityObject;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.callbacks.VanillaCallbackPriorities;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PostProjectileHitParams;
import mvz2.vanilla.callbacks.VanillaLevelCallbacks.PreProjectileHitParams;
import mvz2logic.level.LevelPositions;
import pvzengine.callbacks.CallbackResult;
import pvzengine.definitions.EntityBehaviourDefinition;
import pvzengine.entities.Entity;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaProjectileNames.breakoutPearl)
class BreakoutPearl extends EntityBehaviourDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddTrigger(VanillaLevelCallbacks.PRE_PROJECTILE_HIT, PreHitEntityCallback, VanillaCallbackPriorities.EARLY);
        AddTrigger(VanillaLevelCallbacks.POST_PROJECTILE_HIT, PostHitEntityCallback);
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        entity.Timeout = 30;
    }

    function PreHitEntityCallback(param:PreProjectileHitParams, result:CallbackResult):Void
    {
        var hit = param.hit;
        var projectile = hit.Projectile;
        if (!projectile.Definition.HasBehaviour(this))
            return;
        if (projectile.Parent != null && unity.UnityObject.exists(projectile.Parent))
        {
            result.SetFinalValue(false);
            return;
        }
    }
    function PostHitEntityCallback(param:PostProjectileHitParams, result:CallbackResult):Void
    {
        var hitResult = param.hit;

        var projectile = hitResult.Projectile;
        if (!projectile.Definition.HasBehaviour(this))
            return;
        var target = hitResult.Other;
        var bullet2Target = projectile.Position - target.Position;
        var newDirection = bullet2Target;
        newDirection.y = 0;
        var velocity = projectile.Velocity;
        var newVelocity = newDirection.normalized * velocity.magnitude;
        velocity.x = newVelocity.x;
        velocity.y = 0;
        velocity.z = newVelocity.z;
        projectile.Velocity = velocity;
    }
    public override function Update(projectile:Entity):Void
    {
        var bounds = projectile.GetBounds();
        if (bounds.max.x < LevelPositions.PROJECTILE_LEFT_BORDER)
        {
            projectile.Remove();
            return;
        }

        projectile.Timeout = 30;
        var level = projectile.Level;
        var position = projectile.Position;
        var velocity = projectile.Velocity;
        if (position.x > MAX_X)
        {
            position.x = MAX_X;
            velocity.x *= -1;
            projectile.PlaySound(VanillaSoundID.pearlTouch);
        }
        if (position.z > level.GetGridTopZ())
        {
            position.z = level.GetGridTopZ();
            velocity.z *= -1;
            projectile.PlaySound(VanillaSoundID.pearlTouch);
        }
        else if (position.z < level.GetGridBottomZ())
        {
            position.z = level.GetGridBottomZ();
            velocity.z *= -1;
            projectile.PlaySound(VanillaSoundID.pearlTouch);
        }
        projectile.Position = position;
        projectile.Velocity = velocity;
        super.Update(projectile);
    }

    public static inline var MAX_X:Float = LevelPositions.RIGHT_BORDER - 40;
}

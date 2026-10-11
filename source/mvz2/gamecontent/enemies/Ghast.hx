// Ported from: Assets/Scripts/Vanilla/GameContent/Enemies/Chapter2/Ghast.cs
package mvz2.gamecontent.enemies;

import unity.UnityObject;
import mvz2.gamecontent.buffs.enemies.FlyBuff;
import mvz2.gamecontent.buffs.projectiles.GhastFireChargeBuff;
import mvz2.gamecontent.detections.DispenserDetector;
import mvz2.gamecontent.entities.AIEntityBehaviour;
import mvz2.gamecontent.projectiles.VanillaProjectileID;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.detection.Detector;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.projectiles.VanillaProjectileExt;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2.vanilla.unlocks.VanillaUnlockID;
import mvz2logic.Global;
import mvz2logic.entities.LogicEnemyStates;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.level.LogicLevelExt;
import pvzengine.buffs.BuffExt;
import pvzengine.damages.DeathInfo;
import pvzengine.entities.Entity;
import tools.FrameTimer;
using mvz2.gamecontent.difficulties.VanillaDifficultyLevelProps;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2.vanilla.projectiles.VanillaProjectileExt;
using mvz2logic.entities.LogicEnemyProps;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaEnemyNames.ghast)
class Ghast extends AIEntityBehaviour
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        detector = new DispenserDetector();
        cast(detector, DispenserDetector).ignoreHighEnemy = true;
    }
    public override function Init(entity:Entity):Void
    {
        super.Init(entity);
        SetStateTimer(entity, new FrameTimer(SHOOT_COOLDOWN));
        var buff = entity.AddBuff(FlyBuff);
        buff.SetProperty(FlyBuff.PROP_TARGET_HEIGHT, 80);

        if (!entity.IsPreviewEnemy())
            entity.PlaySound(VanillaSoundID.ghastCry);
    }
    override function UpdateAI(enemy:Entity):Void
    {
        super.UpdateAI(enemy);
        if (CanShoot(enemy))
        {
            var shootTimer = GetStateTimer(enemy);
            if (shootTimer != null)
            {
                shootTimer.Run(enemy.GetAttackSpeed());
                switch (enemy.State)
                {
                    case STATE_WALK:
                        if (shootTimer.Expired)
                        {
                            var target = FindTarget(enemy);
                            if (target != null && unity.UnityObject.exists(target))
                            {
                                enemy.Target = target;
                                shootTimer.ResetTime(SHOOT_DURATION);
                                enemy.PlayCrySound(VanillaSoundID.ghastFire);
                            }
                            else
                            {
                                shootTimer.Reset();
                            }
                        }
                    case STATE_RANGED_ATTACK:
                        if (shootTimer.Expired)
                        {
                            var target = FindTarget(enemy);
                            if (target != null && unity.UnityObject.exists(target))
                            {
                                Fire(enemy, target);
                            }
                            enemy.Target = null;
                            shootTimer.ResetTime(SHOOT_COOLDOWN);
                        }
                }
            }
        }
    }
    public override function PostDeath(entity:Entity, info:DeathInfo):Void
    {
        super.PostDeath(entity, info);
        if (info.Source != null && info.Source.DefinitionID == VanillaProjectileID.fireCharge && !entity.Level.IsIZombie())
        {
            Global.Saves.Unlock(VanillaUnlockID.returnToSender);
            Global.Saves.SaveToFile(); // 完成成就后保存游戏。
        }
    }
    public static function GetStateTimer(enemy:Entity):Null<FrameTimer>
    {
        return enemy.GetBehaviourField(PROP_STATE_TIMER);
    }
    public static function SetStateTimer(enemy:Entity, value:FrameTimer):Void
    {
        enemy.SetBehaviourField(PROP_STATE_TIMER, value);
    }
    function CanShoot(enemy:Entity):Bool
    {
        return enemy.Position.x <= enemy.Level.GetEntityColumnX(enemy.Level.GetMaxColumnCount() - 1);
    }
    function FindTarget(entity:Entity):Null<Entity>
    {
        return detector.DetectEntityWithTheLeast(DetectionParams.fromEntity(entity), e -> (e.GetCenter() - entity.Position).sqrMagnitude);
    }
    function ValidateTarget(entity:Entity, target:Entity):Bool
    {
        return detector.ValidateTarget(DetectionParams.fromEntity(entity), target);
    }
    function Fire(self:Entity, target:Entity):Void
    {
        var scale = self.GetScale();

        var param = self.GetShootParams();
        var shootPoint = self.GetShootPoint();
        var velocity = self.GetShotVelocity();
        var speed = velocity.magnitude;
        var direciton = (target.GetCenter() - shootPoint).normalized;
        param.velocity = speed * direciton;
        var damageMultiplier = self.Level.GetGhastDamageMultiplier();
        param.damage = self.GetDamage() * damageMultiplier;

        // C#: self.ShootProjectile(param)?.Let(e => { ... })
        var bullet = self.ShootProjectile(param);
        if (bullet != null)
        {
            var buff = bullet.AddBuff(GhastFireChargeBuff);
            GhastFireChargeBuff.SetScaleMultiplier(buff, scale);
            GhastFireChargeBuff.SetRangeMultiplier(buff, scale.x);
            GhastFireChargeBuff.SetDamageMultiplier(buff, scale.x);
        }
        self.PlaySound(VanillaSoundID.fireCharge, scale.x);
    }
    var detector:Detector;
    public static var PROP_STATE_TIMER:VanillaEntityPropertyMeta<FrameTimer> = new VanillaEntityPropertyMeta<FrameTimer>("StateTimer");
    public static inline var SHOOT_COOLDOWN:Int = 135;
    public static inline var SHOOT_DURATION:Int = 15;
    public static inline var STATE_WALK:Int = LogicEnemyStates.WALK;
    public static inline var STATE_RANGED_ATTACK:Int = LogicEnemyStates.RANGED_ATTACK;
}

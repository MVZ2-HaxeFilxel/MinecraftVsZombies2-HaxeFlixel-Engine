// Ported from: Assets/Scripts/Vanilla/GameContent/Stages/Behaviours/FinalClear/FrankensteinStageBehaviour.cs
package mvz2.gamecontent.stages;

import mvz2.gamecontent.bosses.Frankenstein;
import mvz2.gamecontent.bosses.VanillaBossID;
import mvz2.gamecontent.buffs.enemies.FrankensteinTransformerBuff;
import mvz2.gamecontent.buffs.level.FrankensteinStageBuff;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.gamecontent.enemies.VanillaEnemyID;
import mvz2.gamecontent.progressbars.VanillaProgressBarID;
import mvz2.vanilla.audios.VanillaMusicID;
import mvz2.vanilla.bosses.VanillaBossExt;
import mvz2.vanilla.level.VanillaLevelExt;
import mvz2.vanilla.level.VanillaLevelStates;
import mvz2.vanilla.properties.VanillaLevelPropertyMeta;
import pvzengine.entities.EntityTypes;
import mvz2logic.entities.LogicEntityExt;
import mvz2logic.level.LevelPositions;
import mvz2logic.level.LogicLevelExt;
import mvz2logic.level.LogicLevelProps;
import mvz2logic.level.LogicStageProps;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
import pvzengine.level.StageDefinition;
import tools.FrameTimer;
import unity.Mathf;
import unity.Vector3;
import unity.UnityObject;

class FrankensteinStageBehaviour extends BossStageBehaviour
{
    public function new(stageDef:StageDefinition)
    {
        super(stageDef);
    }
    override public function PostWave(level:LevelEngine, wave:Int):Void
    {
        super.PostWave(level, wave);
        if (wave <= 10)
            return;
        if (!level.HasBuff(FrankensteinStageBuff))
        {
            level.AddBuff(FrankensteinStageBuff);
        }
        if (!level.EntityExists(VanillaEffectID.rain))
        {
            VanillaLevelExt.StartRain(level);
        }
    }
    override public function AfterFinalWaveUpdate(level:LevelEngine):Void
    {
        super.AfterFinalWaveUpdate(level);
        var frankensteinTimer = GetOrCreateFrankensteinTimer(level);

        // 如果没有科学怪人的目标，再生成一个。
        var targetEnemy = level.FindFirstEntity(function(e) return !e.IsDead && e.HasBuff(FrankensteinTransformerBuff));
        if (targetEnemy == null || !unity.UnityObject.exists(targetEnemy))
        {
            var position = new Vector3(LevelPositions.ENEMY_RIGHT_BORDER, 0, level.GetEntityLaneZ(Mathf.FloorToInt(level.GetMaxLaneCount() * 0.5)));
            targetEnemy = level.Spawn(VanillaEnemyID.zombie, position, null);
            if (targetEnemy != null)
            {
                targetEnemy.AddBuff(FrankensteinTransformerBuff);
            }
            frankensteinTimer.ResetTime(300);
        }


        // 音乐放缓。
        LogicLevelExt.SetMusicVolume(level, Mathf.Clamp01(LogicLevelExt.GetMusicVolume(level) - (1 / 30.0)));

        frankensteinTimer.Run();
        if (frankensteinTimer.Expired)
        {
            level.WaveState = VanillaLevelStates.STATE_BOSS_FIGHT;
            if (targetEnemy != null)
            {
                var boss = level.Spawn(VanillaBossID.frankenstein, targetEnemy.Position, targetEnemy);
                if (boss != null)
                {
                    Frankenstein.DoTransformationEffects(boss);
                    VanillaBossExt.ApplyBuffForBossRevenge(boss);
                }
            }
            for (ent in level.FindEntities(function(e) return !e.IsDead && e.HasBuff(FrankensteinTransformerBuff)))
            {
                ent.Remove();
            }
            // 音乐。
            LogicLevelExt.PlayMusic(level, VanillaMusicID.halloweenBoss);
            LogicLevelExt.SetMusicVolume(level, 1);
            // 血条。
            LogicLevelExt.SetProgressBarToBoss(level, VanillaProgressBarID.frankenstein);
            // 重置下一波计时器。
            var behaviour:Null<WaveStageBehaviour> = VanillaLevelExt.GetStageBehaviour(level, WaveStageBehaviour);
            if (behaviour != null)
            {
                var timer = WaveStageBehaviour.GetWaveTimer(level);
                if (timer != null)
                    timer.ResetTime(200);
            }
            frankensteinTimer.ResetTime(300);
        }
    }
    override public function BossFightWaveUpdate(level:LevelEngine):Void
    {
        super.BossFightWaveUpdate(level);
        // 如果不存在Boss，继续播放传送带关音乐，进入到Boss后阶段
        // 如果所有Boss死亡，音乐放缓
        // 如果有Boss存活，不停生成怪物。
        var targetBosses = level.FindEntities(function(e) return e.Type == EntityTypes.BOSS && LogicEntityExt.IsHostileEntity(e));
        if (targetBosses.length <= 0)
        {
            level.WaveState = VanillaLevelStates.STATE_AFTER_BOSS;
            var musicID = LogicStageProps.GetMusicID(level);
            if (musicID != null)
            {
                LogicLevelExt.PlayMusic(level, musicID);
            }
            LogicLevelExt.SetMusicVolume(level, 1);
            LogicLevelExt.SetProgressBarToStage(level);
        }
        else
        {
            // C#: targetBosses.All(b => b.IsDead)
            var allDead = true;
            for (b in targetBosses)
            {
                if (!b.IsDead)
                    allDead = false;
            }
            if (allDead)
            {
                LogicLevelExt.SetMusicVolume(level, Mathf.Clamp01(LogicLevelExt.GetMusicVolume(level) - (1 / 30.0)));
                LogicLevelProps.SetLastEnemyPosition(level, targetBosses[0].Position);
            }
            else
            {
                RunBossWave(level);
            }
        }
    }
    override public function AfterBossWaveUpdate(level:LevelEngine):Void
    {
        super.AfterBossWaveUpdate(level);
        VanillaLevelExt.CheckClearUpdate(level);
    }
    public function GetFrankentsteinTimer(level:LevelEngine):Null<FrameTimer> return level.GetProperty(PROP_FRANKENSTEIN_TIMER);
    public function SetFrankensteinTimer(level:LevelEngine, value:FrameTimer):Void level.SetProperty(PROP_FRANKENSTEIN_TIMER, value);
    public function GetOrCreateFrankensteinTimer(level:LevelEngine):FrameTimer
    {
        var roundTimer = GetFrankentsteinTimer(level);
        if (roundTimer == null)
        {
            roundTimer = new FrameTimer(300);
            SetFrankensteinTimer(level, roundTimer);
        }
        return roundTimer;
    }
    private static inline var PROP_REGION:String = "frankenstein_stage";
    @:levelPropertyRegistry(PROP_REGION)
    public static var PROP_FRANKENSTEIN_TIMER:VanillaLevelPropertyMeta<FrameTimer> = new VanillaLevelPropertyMeta<FrameTimer>("FrankensteinTimer");
}

// Ported from: Assets/Scripts/Vanilla/Frameworks/VanillaMod.cs
package mvz2.vanilla;

import mvz2.vanilla.stats.VanillaStats;
import mvz2.vanilla.unlocks.VanillaUnlockID;
import mvz2logic.Global;
import mvz2logic.games.IGlobalGame;
import mvz2logic.modding.Mod;
import mvz2logic.modding.IVanillaInterface;
import mvz2logic.saves.ModSaveData;
import mvz2logic.games.IGlobalSaveData;
import mvz2logic.saves.LogicSaveData;
import mvz2logic.saves.SerializableLogicSaveData;
import pvzengine.NamespaceID;

class VanillaMod extends Mod implements IVanillaInterface
{
    public function new()
    {
        super(spaceName);
    }
    override public function Init(game:IGlobalGame):Void
    {
        super.Init(game);
        Global.SetVanillaInterface(this);
        RegisterSerializableType(SerializableLogicSaveData);
    }

    // #region 存档
    override public function CreateSaveData():ModSaveData
    {
        return new LogicSaveData(spaceName);
    }
    override public function LoadSaveData(json:String):ModSaveData
    {
        var serializable:SerializableLogicSaveData = Deserialize(json, SerializableLogicSaveData);
        return LogicSaveData.DeserializeFrom(serializable);
    }
    override public function PostAllSaveDataLoaded():Void
    {
        // 通过梦境世界第7关，并且没有通过第11关。
        var saves = Global.Saves;
        if (saves.IsUnlocked(VanillaUnlockID.dream7) && !saves.IsUnlocked(VanillaUnlockID.dream11))
        {
            saves.Unlock(VanillaUnlockID.dreamIsNightmare);
        }
    }
    // #endregion

    // #region IVanillaInterface实现
    public function IsEnemyEncountered(saves:IGlobalSaveData, enemyID:NamespaceID):Bool
    {
        return saves.GetStat(VanillaStats.CATEGORY_ENEMY_NEUTRALIZE, enemyID) > 0;
    }
    public function DreamIsNightmare(save:IGlobalSaveData):Bool
    {
        return save.IsUnlocked(VanillaUnlockID.dreamIsNightmare);
    }
    public function SetDreamIsNightmare(save:IGlobalSaveData, value:Bool):Void
    {
        if (value)
        {
            save.Unlock(VanillaUnlockID.dreamIsNightmare);
        }
        else
        {
            save.Relock(VanillaUnlockID.dreamIsNightmare);
        }
    }
    // #endregion

    public static inline var INSTA_DAMAGE_AMOUNT:Float = 58115310;
    public static inline var spaceName:String = "mvz2";
}

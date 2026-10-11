// Ported from: Assets/Scripts/MVZ2/Saves/UserDataList.cs
package mvz2.saves;

import mvz2.saves.UserDataItem.SerializableSaveDataMeta;

// PORT-NOTE: C# 使用可空数组 UserDataItem?[]；Haxe 的 Array<UserDataItem> 用 null 元素表示空位。
class UserDataList {
    public function new(metaCount:Int) {
        metas = [];
        metas.resize(metaCount);
    }
    public function Create(index:Int):UserDataItem {
        if (index < 0 || index >= metas.length)
            return null;
        var meta = new UserDataItem();
        metas[index] = meta;
        return meta;
    }
    public function Get(index:Int):UserDataItem {
        if (index < 0 || index >= metas.length)
            return null;
        return metas[index];
    }
    public function Delete(index:Int):Bool {
        if (index < 0 || index >= metas.length)
            return false;
        metas[index] = null;
        return true;
    }
    public function GetAllUsers():Array<UserDataItem> {
        return metas.copy();
    }
    public function GetMaxUserCount():Int {
        return metas.length;
    }
    public function ToSerializable():SerializableUserDataList {
        var seriMetas:Array<SerializableSaveDataMeta> = [];
        for (m in metas) {
            seriMetas.push(m != null ? m.ToSerializable() : null);
        }
        var serializable = new SerializableUserDataList();
        serializable.currentUserIndex = CurrentUserIndex;
        serializable.metas = seriMetas;
        return serializable;
    }
    public static function FromSerializable(serializable:SerializableUserDataList):UserDataList {
        if (serializable.metas == null) {
            throw pvzengine.base.MissingSerializeDataException.Property("metas");
        }
        var metaList = new UserDataList(serializable.metas.length);
        metaList.CurrentUserIndex = Std.int(Math.min(Math.max(serializable.currentUserIndex, 0), serializable.metas.length - 1));
        for (i in 0...metaList.metas.length) {
            var seriMeta = serializable.metas[i];
            if (seriMeta == null)
                continue;
            metaList.metas[i] = UserDataItem.FromSerializable(seriMeta);
        }
        return metaList;
    }
    public var CurrentUserIndex:Int;
    private var metas:Array<UserDataItem>;
}

// [Serializable]
// PORT-NOTE: C# 为 public class SerializableUserDataList（UserDataList.cs 末尾），此处保持 class
// 而非 typedef：SerializeHelper.RegisterClass<T>(type:Class<T>) 需要真实 Class，且与本工程其余
// [Serializable] DTO（SerializableLogicSaveData / SerializableLevel / SerializableUserStats 等）一致。
@:rtti
class SerializableUserDataList {
    public function new() {}
    public var currentUserIndex:Int;
    public var metas:Array<SerializableSaveDataMeta>;
}

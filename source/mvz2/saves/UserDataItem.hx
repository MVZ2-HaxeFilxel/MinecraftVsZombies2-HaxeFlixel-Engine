// Ported from: Assets/Scripts/MVZ2/Saves/UserDataItem.cs
package mvz2.saves;

class UserDataItem {
    public function new() {}

    public function ToSerializable():SerializableSaveDataMeta {
        var serializable = new SerializableSaveDataMeta();
        serializable.username = Username;
        return serializable;
    }
    public static function FromSerializable(serializable:SerializableSaveDataMeta):UserDataItem {
        if (serializable == null)
            return null;
        var item = new UserDataItem();
        item.Username = serializable.username;
        return item;
    }
    public var Username:String;
}

// [Serializable]
// PORT-NOTE: C# 为 public class SerializableSaveDataMeta（UserDataItem.cs 末尾），此处保持 class
// 而非 typedef：SerializeHelper.RegisterClass<T>(type:Class<T>) 需要真实 Class，且与本工程其余
// [Serializable] DTO（SerializableLogicSaveData / SerializableLevel / SerializableUserStats 等）一致。
@:rtti
class SerializableSaveDataMeta {
    public function new() {}
    public var username:String;
}

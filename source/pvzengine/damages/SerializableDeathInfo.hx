// Ported from: Assets/Scripts/Engine/Level/Damage/DeathInfo.cs
// PORT-NOTE: 该类型在 C# 中与 DeathInfo 同处一个文件。既有同级引擎代码以短包路径引用它
// （pvzengine/entities/Entity.hx、pvzengine/entities/SerializableEntity.hx 的
// `import pvzengine.damages.SerializableDeathInfo;`），而 Haxe 的 import 必须精确对应模块文件
// （同包内另一模块的次级类型无法用短包路径导入），故将 SerializableDeathInfo 拆为独立模块。
package pvzengine.damages;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.level.ILevelSourceReference;
// PORT-NOTE: C# 中 ISerializableSourceReference 与 ILevelSourceReference 同处一个文件；
// 本工程已按既有调用点把它拆成独立模块 pvzengine/level/ISerializableSourceReference.hx。
import pvzengine.level.ISerializableSourceReference;

// [Serializable]
@:rtti
class SerializableDeathInfo
{
    public function new(deathInfo:DeathInfo)
    {
        effects = deathInfo.Effects.GetEffects();
        damage = deathInfo.Damage;
        source = deathInfo.Source != null ? deathInfo.Source.ToSerializable() : null;
        entityID = deathInfo.Entity.ID;
    }
    public var effects:Array<NamespaceID>;
    public var entityID:Int64;
    public var source:Null<ISerializableSourceReference>;
    public var damage:Null<DamageResultValues>;
}

// Ported from: Assets/Scripts/Engine/Level/Grids/SerializableGrid.cs
package pvzengine.grids;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.auras.SerializableAuraEffect;
import pvzengine.buffs.SerializableBuffList;
import pvzengine.level.PropertyBlock.SerializablePropertyBlock;

@:rtti
class SerializableGrid
{
    // PORT-NOTE: Haxe 4.3 不再为无构造函数的类自动生成默认构造函数，C# 的隐式默认构造需显式写出。
    public function new() {}
    public var lane:Int;
    public var column:Int;
    public var definitionID:Null<NamespaceID>;
    // C#: [Obsolete] public Dictionary<string, long>? layerEntities;
    // PORT-NOTE: [Obsolete] 特性无运行期语义，仅保留注释。
    public var layerEntities:Map<String, Int64>;
    public var layerEntityLists:Map<String, Array<Int64>>;
    public var properties:SerializablePropertyBlock;
    public var buffs:SerializableBuffList;
    public var auras:Array<SerializableAuraEffect>;
}

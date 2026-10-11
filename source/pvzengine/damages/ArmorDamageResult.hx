// Ported from: Assets/Scripts/Engine/Level/Damage/ArmorDamageResult.cs
package pvzengine.damages;

import pvzengine.NamespaceID;
import pvzengine.armors.Armor;
import pvzengine.damages.DamageResult.SerializableDamageResult;
import pvzengine.level.LevelEngine;
import pvzengine.shells.ShellDefinition;
import unity.Vector3;

class ArmorDamageResult extends DamageResult
{
    public function new(input:DamageInput, armor:Armor, shell:ShellDefinition = null)
    {
        super(input, shell);
        Armor = armor;
    }
    public override function GetPosition():Vector3
    {
        return Entity.Position;
    }
    public override function ToSerializable():SerializableDamageResult
    {
        return new SerializableArmorDamageResult(this);
    }
    public var Armor:Armor;
}

// [Serializable]
@:rtti
class SerializableArmorDamageResult extends SerializableDamageResult
{
    public function new(result:ArmorDamageResult)
    {
        super(result);
        this.armorSlot = result.Armor.Slot;
    }
    public override function ToDeserialized(level:LevelEngine):DamageResult
    {
        // PORT-NOTE: C# 的 `new ArmorDamageResult(level, seri)` 构造函数重载在 Haxe 中改为
        // 无伤害输入构造 + LoadFromSerializable；原构造函数中 base(level, seri) 之后的
        // 装甲查找逻辑平移到此。
        var result = new ArmorDamageResult(null, null, null);
        result.LoadFromSerializable(level, this);
        var armor = result.Entity.GetArmorAtSlot(armorSlot);
        if (armor == null)
        {
            throw 'Cannot find the armor on slot ${armorSlot} on entity ${result.Entity} while loading SerializableArmorDamageResult.';
        }
        result.Armor = armor;
        return result;
    }
    public var armorSlot:NamespaceID;
}

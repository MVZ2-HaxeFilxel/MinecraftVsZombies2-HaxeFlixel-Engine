// Ported from: Assets/Scripts/Engine/Level/Damage/BodyDamageResult.cs
package pvzengine.damages;

import pvzengine.damages.DamageResult.SerializableDamageResult;
import pvzengine.level.LevelEngine;
import pvzengine.shells.ShellDefinition;
import unity.Vector3;

class BodyDamageResult extends DamageResult
{
    public function new(input:DamageInput, shell:ShellDefinition = null)
    {
        super(input, shell);
    }
    public override function ToSerializable():SerializableDamageResult
    {
        return new SerializableBodyDamageResult(this);
    }
    public override function GetPosition():Vector3
    {
        return Entity.Position;
    }
}

// [Serializable]
@:rtti
class SerializableBodyDamageResult extends SerializableDamageResult
{
    public function new(result:BodyDamageResult)
    {
        super(result);
    }
    public override function ToDeserialized(level:LevelEngine):DamageResult
    {
        // PORT-NOTE: C# 的 `new BodyDamageResult(level, seri)` 构造函数重载在 Haxe 中改为
        // 无伤害输入构造 + LoadFromSerializable。
        var result = new BodyDamageResult(null, null);
        result.LoadFromSerializable(level, this);
        return result;
    }
}

// Ported from: Assets/Scripts/Engine/Level/Damage/DamageResult.cs
package pvzengine.damages;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.level.ILevelSourceReference;
// PORT-NOTE: C# 中 ISerializableSourceReference 与 ILevelSourceReference 同处一个文件；
// 本工程已按既有调用点（mvz2logic/artifacts/ArtifactSourceReference.hx 等）把它拆成独立模块
// pvzengine/level/ISerializableSourceReference.hx，故此处使用短包路径导入。
import pvzengine.level.ISerializableSourceReference;
import pvzengine.level.LevelEngine;
import pvzengine.shells.ShellDefinition;
import unity.Vector3;
// PORT-NOTE: C# 中 `level.Content.GetShellDefinition(...)` 是 PVZEngine.ContentProviderHelper 对
// IGameContent 的扩展方法（C# 靠 using 引入），Haxe 用 using 声明等价（与 mvz2logic/options/LogicOptionExt.hx 一致）。
using pvzengine.ContentProviderHelper;

// C# 为 abstract class
class DamageResult
{
    // PORT-NOTE: C# 有两个构造函数 `DamageResult(DamageInput, ShellDefinition?)` 与
    // `DamageResult(LevelEngine, SerializableDamageResult)`。Haxe 不支持构造函数重载：
    // 反序列化路径改由 LoadFromSerializable(level, seri) 完成（由各 Serializable*DamageResult.ToDeserialized 调用），
    // 传入 input == null 时不初始化伤害数值（仅用于反序列化构造）。
    public function new(input:DamageInput = null, shell:ShellDefinition = null)
    {
        if (input != null)
        {
            values = new DamageResultValues(input.OriginalAmount, input.Amount, 0);
            Entity = input.Entity;
            Effects = input.Effects;
            Source = input.Source;
        }
        ShellDefinition = shell;
    }
    // C#: public DamageResult(LevelEngine level, SerializableDamageResult seri)
    public function LoadFromSerializable(level:LevelEngine, seri:SerializableDamageResult):Void
    {
        var ent = level.FindEntityByID(seri.entityID);
        if (ent == null)
        {
            throw 'Cannot find the entity with id ${seri.entityID} while loading SerializableDamageResult.';
        }
        Entity = ent;
        Source = seri.source != null ? seri.source.ToDeserialized(level) : null;
        Effects = new DamageEffectList(seri.effects);
        values = seri.values;
        Fatal = seri.fatal;
        ShellDefinition = level.Content.GetShellDefinition(seri.shellID);
    }
    // C#: public abstract Vector3 GetPosition();
    // PORT-NOTE: Haxe 无 abstract 方法，基类抛出（PORTING.md 约定），由子类 override。
    public function GetPosition():Vector3
    {
        throw 'abstract';
    }
    public function HasEffect(effect:NamespaceID):Bool
    {
        return Effects != null && Effects.HasEffect(effect);
    }
    public function HasDamageAmount():Bool
    {
        return Amount > 0;
    }
    // C#: public abstract SerializableDamageResult ToSerializable();
    public function ToSerializable():SerializableDamageResult
    {
        throw 'abstract';
    }
    public function GetValues():DamageResultValues
    {
        return values;
    }

    private var values:DamageResultValues;
    public var Source:Null<ILevelSourceReference>;
    public var Effects:DamageEffectList;
    public var ShellDefinition:Null<ShellDefinition>;
    public var Fatal:Bool;
    public var Entity:Entity;
    public var OriginalAmount(get, set):Float;
    inline function get_OriginalAmount():Float return values.originalAmount;
    inline function set_OriginalAmount(value:Float):Float
    {
        values.originalAmount = value;
        return value;
    }
    public var Amount(get, set):Float;
    inline function get_Amount():Float return values.amount;
    inline function set_Amount(value:Float):Float
    {
        values.amount = value;
        return value;
    }
    public var SpendAmount(get, set):Float;
    inline function get_SpendAmount():Float return values.spendAmount;
    inline function set_SpendAmount(value:Float):Float
    {
        values.spendAmount = value;
        return value;
    }
}

// [Serializable]
// C# 为 abstract class
@:rtti
class SerializableDamageResult
{
    public function new(result:DamageResult)
    {
        source = result.Source != null ? result.Source.ToSerializable() : null;
        effects = result.Effects.GetEffects();
        fatal = result.Fatal;
        shellID = result.ShellDefinition != null ? result.ShellDefinition.GetID() : null;
        entityID = result.Entity.ID;
        values = result.GetValues();
    }
    // C#: public abstract DamageResult ToDeserialized(LevelEngine level);
    public function ToDeserialized(level:LevelEngine):DamageResult
    {
        throw 'abstract';
    }
    public var source:Null<ISerializableSourceReference>;
    public var effects:Array<NamespaceID>;
    public var shellID:Null<NamespaceID>;
    public var entityID:Int64;
    public var fatal:Bool;
    public var values:DamageResultValues;
}

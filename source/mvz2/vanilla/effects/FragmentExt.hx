// Ported from: Assets/Scripts/Vanilla/GameContent/Effects/FragmentExt.cs
package mvz2.vanilla.effects;

import mvz2.gamecontent.effects.Fragment;
import mvz2.gamecontent.effects.HealParticles;
import mvz2.gamecontent.effects.VanillaEffectID;
import mvz2.vanilla.contraptions.VanillaContraptionProps;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityID;
import unity.Vector3;
import unity.UnityObject;

// PORT-NOTE: 原文件为 C# 的静态扩展类（MVZ2.Vanilla.Effects.FragmentExt），
// Haxe 侧保留为普通静态类，调用处按 PORTING.md 改为静态调用（FragmentExt.X(entity, ...)）。
class FragmentExt
{
    private static inline var PROP_REGION:String = "fragments";

    // #region 碎片
    public static function CreateFragment(entity:Entity):Null<Entity>
    {
        var fragment = entity.Level.Spawn(VanillaEffectID.fragment, entity.Position, entity);
        // PORT-NOTE: C# `?.Let(e => {...})` → 显式判空块。
        if (fragment != null)
        {
            fragment.SetParent(entity);
            Fragment.UpdateFragmentID(fragment);
        }
        return fragment;
    }
    public static function CreateFragmentAndPlay(entity:Entity, ?id:Null<NamespaceID> = null, emitSpeed:Float = 500):Null<Entity>
    {
        return CreateFragmentAndPlayAt(entity, entity.Position, id, emitSpeed);
    }
    // PORT-NOTE: C# 重载 CreateFragmentAndPlay(this Entity entity, Vector3 position, NamespaceID? id = null, float emitSpeed = 500)
    // 与上面的无位置重载同名，Haxe 不支持重载，此处重命名为 CreateFragmentAndPlayAt。
    public static function CreateFragmentAndPlayAt(entity:Entity, position:Vector3, ?id:Null<NamespaceID> = null, emitSpeed:Float = 500):Null<Entity>
    {
        var fragment = entity.Level.Spawn(VanillaEffectID.fragment, position, entity);
        if (fragment != null)
        {
            // C#: id ?? entity?.GetFragmentID() ?? entity?.GetDefinitionID()
            var fragmentID:Null<NamespaceID> = id;
            if (fragmentID == null && entity != null)
            {
                fragmentID = VanillaContraptionProps.GetFragmentID(entity);
            }
            if (fragmentID == null && entity != null)
            {
                fragmentID = entity.GetDefinitionID();
            }
            Fragment.SetFragmentID(fragment, fragmentID);
            Fragment.AddEmitSpeed(fragment, emitSpeed);
        }
        return fragment;
    }
    public static function GetOrCreateFragment(entity:Entity):Null<Entity>
    {
        var fragmentRef = GetFragment(entity);
        var fragment = fragmentRef != null ? fragmentRef.GetEntity(entity.Level) : null;
        if (fragment == null || !unity.UnityObject.exists(fragment))
        {
            var created = CreateFragment(entity);
            // PORT-NOTE: 原 C# 在 `?.Let` 闭包中引用尚未赋值的局部变量 fragment，
            // 这里改为在赋值后写入引用（修复原闭包捕获时机带来的空引用）。
            if (created != null)
            {
                fragmentRef = new EntityID(created);
                SetFragment(entity, fragmentRef);
            }
            fragment = created;
        }
        return fragment;
    }
    public static function GetFragment(entity:Entity):Null<EntityID>
    {
        return entity.GetProperty(PROP_FRAGMENT);
    }
    public static function SetFragment(entity:Entity, value:EntityID):Void
    {
        entity.SetProperty(PROP_FRAGMENT, value);
    }
    public static function GetFragmentTickDamage(entity:Entity):Float
    {
        return entity.GetProperty(PROP_TICK_DAMAGE);
    }
    public static function SetFragmentTickDamage(entity:Entity, value:Float):Void
    {
        entity.SetProperty(PROP_TICK_DAMAGE, value);
    }
    public static function AddFragmentTickDamage(entity:Entity, value:Float):Void
    {
        SetFragmentTickDamage(entity, GetFragmentTickDamage(entity) + value);
    }
    public static function NoDamageFragments(entity:Entity):Bool
    {
        return entity.GetProperty(PROP_NO_DAMAGE_FRAGMENTS);
    }
    // PORT-NOTE: C# 原文这三个字段带 `[EntityPropertyRegistry(PROP_REGION)]`
    // （Assets/Scripts/Vanilla/GameContent/Effects/FragmentExt.cs:74/76/78），移植时被注释掉了；
    // 补回 `@:entityPropertyRegistry` 元数据（等价于 C# 的 EntityPropertyRegistryAttribute）。
    @:entityPropertyRegistry(PROP_REGION)
    public static var PROP_FRAGMENT:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("Fragment");
    @:entityPropertyRegistry(PROP_REGION)
    public static var PROP_TICK_DAMAGE:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("TickDamage");
    @:entityPropertyRegistry(PROP_REGION)
    public static var PROP_NO_DAMAGE_FRAGMENTS:VanillaEntityPropertyMeta<Bool> = new VanillaEntityPropertyMeta<Bool>("noDamageFragments");
    // #endregion

    // #region 治疗粒子
    public static function CreateHealParticles(entity:Entity):Null<Entity>
    {
        var particles = entity.Level.Spawn(VanillaEffectID.healParticles, entity.Position, entity);
        if (particles != null)
        {
            particles.SetParent(entity);
        }
        var fragmentRef:EntityID = particles != null ? new EntityID(particles) : null;
        SetHealParticles(entity, fragmentRef);
        return particles;
    }
    public static function UpdateHealParticles(entity:Entity):Void
    {
        var healing = GetTickHealing(entity);
        if (healing > 0)
        {
            var particles = GetOrCreateHealParticles(entity);
            if (particles != null)
            {
                HealParticles.AddEmitSpeed(particles, GetTickHealing(entity) * 0.4);
            }
            SetTickHealing(entity, 0);
        }
    }
    public static function GetOrCreateHealParticles(entity:Entity):Null<Entity>
    {
        var reference = GetHealParticles(entity);
        var particles = reference != null ? reference.GetEntity(entity.Level) : null;
        if (particles == null || !unity.UnityObject.exists(particles))
        {
            particles = CreateHealParticles(entity);
        }
        return particles;
    }
    public static function GetTickHealing(entity:Entity):Float
    {
        return entity.GetProperty(PROP_TICK_HEALING);
    }
    public static function SetTickHealing(entity:Entity, value:Float):Void
    {
        entity.SetProperty(PROP_TICK_HEALING, value);
    }
    public static function AddTickHealing(entity:Entity, value:Float):Void
    {
        SetTickHealing(entity, GetTickHealing(entity) + value);
    }
    public static function GetHealParticles(entity:Entity):Null<EntityID>
    {
        return entity.GetProperty(PROP_HEALING_PARTICLES);
    }
    public static function SetHealParticles(entity:Entity, value:EntityID):Void
    {
        entity.SetProperty(PROP_HEALING_PARTICLES, value);
    }
    // [EntityPropertyRegistry(PROP_REGION)]
    public static var PROP_HEALING_PARTICLES:VanillaEntityPropertyMeta<EntityID> = new VanillaEntityPropertyMeta<EntityID>("HealingParticles");
    // [EntityPropertyRegistry(PROP_REGION)]
    public static var PROP_TICK_HEALING:VanillaEntityPropertyMeta<Float> = new VanillaEntityPropertyMeta<Float>("TickHealing");
    // #endregion
}

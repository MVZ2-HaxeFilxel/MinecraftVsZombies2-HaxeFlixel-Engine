// Ported from: Assets/Scripts/Engine/Level/Collisions/BuiltinCollisionEntity.cs
package pvzengine.collisions;

import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Int64;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.SerializableEntityCollider;
import pvzengine.level.LevelEngine;

class BuiltinCollisionEntity
{
    public function new()
    {
        // PORT-NOTE: C# 直接使用方法组注册事件（`collider.OnEnabled += OnColliderEnabledCallback`）。
        // Haxe 的闭包相等性依赖目标平台（cpp 上同一 receiver+method 的闭包相等，eval/interp 上不相等），
        // 为保证 add/remove 在所有目标上都配对，这里缓存闭包实例。
        onColliderEnabledCallback = OnColliderEnabledCallback;
        onColliderDisabledCallback = OnColliderDisabledCallback;
    }
    public function Init(entity:Entity):Void
    {
        this.entity = entity;
        var mainCollider = new BuiltinCollisionCollider(entity, EntityCollisionHelper.NAME_MAIN, new EntityHitbox(entity));
        AddCollider(mainCollider);
    }
    public function Update():Void
    {
    }
    public function UpdateEntityDetection():Void
    {
        for (collider in colliders)
        {
            UpdateColliderDetection(collider);
        }
    }
    private function UpdateColliderDetection(collider:BuiltinCollisionCollider):Void
    {
        //collider.SetIgnored(entity.IsCollisionDisabled());
    }
    public function UpdateEntityPosition():Void
    {
    }
    public function UpdateEntitySize():Void
    {
        for (collider in colliders)
        {
            UpdateColliderSize(collider);
        }
    }
    private function UpdateColliderSize(collider:BuiltinCollisionCollider):Void
    {
        collider.ReevaluateBounds();
    }
    public function GetCurrentCollisions(collisions:Array<EntityCollision>):Void
    {
        for (collider in colliders)
        {
            collider.GetCollisions(collisions);
        }
    }
    public function ClearColliders():Void
    {
        for (collider in colliders)
        {
            OnEntityColliderRemove.dispatch(this, collider);
            collider.OnEnabled.remove(onColliderEnabledCallback);
            collider.OnDisabled.remove(onColliderDisabledCallback);
        }
        colliders = [];
    }

    // #region 碰撞体
    public function CreateCustomCollider(cons:ColliderConstructor):BuiltinCollisionCollider
    {
        var hitbox = new CustomHitbox(entity);
        hitbox.SetSize(cons.size);
        hitbox.SetPivot(cons.pivot);
        hitbox.SetOffset(cons.offset);
        var collider = new BuiltinCollisionCollider(entity, cons.name, hitbox);
        collider.ArmorSlot = cons.armorSlot;
        collider.ReevaluateBounds();
        AddCollider(collider);
        return collider;
    }
    public function AddCollider(collider:BuiltinCollisionCollider):Void
    {
        colliders.push(collider);
        collider.OnEnabled.add(onColliderEnabledCallback);
        collider.OnDisabled.add(onColliderDisabledCallback);
        OnEntityColliderAdd.dispatch(this, collider);

        UpdateColliderDetection(collider);
        UpdateColliderSize(collider);
    }
    public function RemoveCollider(name:String):Bool
    {
        for (collider in colliders)
        {
            if (collider.Name == name)
            {
                colliders.remove(collider);
                collider.OnEnabled.remove(onColliderEnabledCallback);
                collider.OnDisabled.remove(onColliderDisabledCallback);
                OnEntityColliderRemove.dispatch(this, collider);
                return true;
            }
        }
        return false;
    }
    public function GetCollider(name:String):Null<BuiltinCollisionCollider>
    {
        for (collider in colliders)
        {
            if (collider.Name == name)
                return collider;
        }
        return null;
    }
    private function OnColliderEnabledCallback(collider:BuiltinCollisionCollider):Void
    {
        OnEntityColliderEnabled.dispatch(this, collider);
    }
    private function OnColliderDisabledCallback(collider:BuiltinCollisionCollider):Void
    {
        OnEntityColliderDisabled.dispatch(this, collider);
    }
    // #endregion


    public function ToSerializable():SerializableBuiltinCollisionSystemEntity
    {
        // PORT-NOTE: C# 用对象初始化器 `new SerializableBuiltinCollisionSystemEntity() { ... }`，改为逐字段赋值。
        var seri = new SerializableBuiltinCollisionSystemEntity();
        seri.id = entity.ID;
        seri.colliders = [for (c in colliders) c.ToSerializable()];
        return seri;
    }
    public function LoadFromSerializable(level:LevelEngine, seri:ISerializableCollisionEntity):Void
    {
        var ent = level.FindEntityByID(seri.ID);
        if (ent == null)
            return;
        entity = ent;
        if (seri.Colliders != null)
        {
            for (seriCollider in seri.Colliders)
            {
                if (seriCollider == null)
                    continue;
                var collider = BuiltinCollisionCollider.FromSerializable(seriCollider, ent);
                AddCollider(collider);
            }
        }
    }
    public function LoadCollisions(level:LevelEngine, seri:ISerializableCollisionEntity):Void
    {
        if (seri == null || seri.Colliders == null)
            return;
        for (i in 0...colliders.length)
        {
            var seriCollider = seri.Colliders[i];
            if (seriCollider == null)
                continue;
            var collider = colliders[i];
            collider.LoadCollisions(level, seriCollider);
        }
    }
    // PORT-NOTE: C# 的 `event Action<BuiltinCollisionEntity, BuiltinCollisionCollider>` → FlxTypedSignal
    // （工程的 PORTING.md 约定）。事件处理器以字段保存闭包，保证 add/remove 使用同一实例。
    public var OnEntityColliderEnabled:FlxTypedSignal<BuiltinCollisionEntity->BuiltinCollisionCollider->Void> = new FlxTypedSignal();
    public var OnEntityColliderDisabled:FlxTypedSignal<BuiltinCollisionEntity->BuiltinCollisionCollider->Void> = new FlxTypedSignal();
    public var OnEntityColliderAdd:FlxTypedSignal<BuiltinCollisionEntity->BuiltinCollisionCollider->Void> = new FlxTypedSignal();
    public var OnEntityColliderRemove:FlxTypedSignal<BuiltinCollisionEntity->BuiltinCollisionCollider->Void> = new FlxTypedSignal();
    // PORT-NOTE: C# `collider.OnEnabled += OnColliderEnabledCallback` 直接使用方法组；
    // Haxe 中每次取方法引用都会新建闭包（FlxSignal.remove 按实例比较），故缓存闭包字段。
    private var onColliderEnabledCallback:BuiltinCollisionCollider->Void = null;
    private var onColliderDisabledCallback:BuiltinCollisionCollider->Void = null;
    public var ID(get, never):Int64;
    inline function get_ID():Int64 return Entity.ID;
    public var Entity(get, never):Entity;
    inline function get_Entity():Entity return entity;
    private var entity:Entity = null;
    private var colliders:Array<BuiltinCollisionCollider> = [];
}

// [Serializable]
@:rtti
class SerializableBuiltinCollisionSystemEntity implements ISerializableCollisionEntity
{
    public function new()
    {
    }
    public var id:Int64;
    public var colliders:Null<Array<SerializableEntityCollider>>;

    public var ID(get, never):Int64;
    inline function get_ID():Int64 return id;
    public var Colliders(get, never):Null<Array<ISerializableCollisionCollider>>;
    function get_Colliders():Null<Array<ISerializableCollisionCollider>>
    {
        if (colliders == null)
            return null;
        return cast colliders;
    }
}

package mvz2.collisions;

import pvzengine.ColliderConstructor;
import pvzengine.collisions.EntityCollision;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
import pvzengine.collisions.ISerializableCollisionEntity;
import pvzengine.collisions.ISerializableCollisionCollider;
import haxe.Int64;
import unity.GameObject;
import unity.MonoBehaviour;
import unity.Rigidbody;
import unity.Transform;
import unity.UnityObject;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.collisions.UnityEntityCollider.SerializableUnityEntityCollider;

// Ported from: Assets/Scripts/MVZ2/Collision/UnityCollisionEntity.cs
// PORT-NOTE: C# `Queue<T>` (Dequeue/Enqueue/Count) is emulated with a Haxe Array
// (shift/push/length); C# `ColliderConstructor` name field is read as `name`.
class UnityCollisionEntity extends MonoBehaviour {
    public function Init(entity:Entity):Void {
        Entity = entity;
        gameObject.name = Std.string(Entity);
        gameObject.layer = UnityCollisionHelper.ToObjectLayer(Entity.Type);
        UpdateEntity();
    }
    public function ResetEntity():Void {
        for (collider in colliders) {
            if (collider != null) {
                collider.gameObject.SetActive(false);
                RecycleCollider(collider);
            }
        }
        colliders = [];
    }
    public function RecycleColliders():Void {
        for (collider in recyclingColliders) {
            RecycleCollider(collider);
        }
        recyclingColliders = [];
    }
    public function Simulate():Void {
        for (collider in colliders) {
            collider.Simulate();
        }
    }
    public function UpdateEntity():Void {
        UpdateEntityDetection();
        UpdateEntityPosition();
        UpdateEntitySize();
    }
    public function UpdateEntityDetection():Void {
        //bool active = Entity.IsCollisionDisabled();
        //if (gameObject.activeSelf != active)
        //{
        //    gameObject.SetActive(active);
        //}
    }
    public function UpdateEntityPosition():Void {
        var pos = Entity.Position;
        rigid.position = pos;
        transform.position = pos;
    }
    public function UpdateEntitySize():Void {
        for (collider in colliders) {
            collider.UpdateEntitySize();
        }
    }
    private function CreateCollider(name:String):UnityEntityCollider {
        var collider:UnityEntityCollider;
        if (disabledColliders.length > 0) {
            collider = disabledColliders.shift();
        } else {
            var instance:GameObject = UnityObject.Instantiate(colliderTemplate, null, null, colliderRoot);
            collider = instance.GetComponent(UnityEntityCollider);
        }
        collider.gameObject.SetActive(true);
        collider.gameObject.layer = gameObject.layer;
        collider.Init(Entity, name);
        collider.UpdateEntitySize();
        colliders.push(collider);
        return collider;
    }
    public function CreateMainCollider(name:String):UnityEntityCollider {
        var collider = CreateCollider(name);
        collider.SetMain();
        return collider;
    }
    public function CreateCustomCollider(cons:ColliderConstructor):UnityEntityCollider {
        var collider = CreateCollider(cons.name);
        collider.SetCustom(cons);
        return collider;
    }
    public function DestroyCollider(name:String):Bool {
        var collider = Lambda.find(colliders, c -> c.Name == name);
        if (collider != null && colliders.remove(collider)) {
            collider.gameObject.SetActive(false);
            recyclingColliders.push(collider);
            return true;
        }
        return false;
    }
    public function GetCollisions(collisions:Array<EntityCollision>):Void {
        for (collider in colliders) {
            collider.GetCollisions(collisions);
        }
    }
    public function GetCollider(name:String):UnityEntityCollider {
        return Lambda.find(colliders, c -> c.Name == name);
    }
    private function RecycleCollider(collider:UnityEntityCollider):Void {
        disabledColliders.push(collider);
        collider.ResetCollider();
    }

    // #region 序列化
    public function ToSerializable():SerializableUnityCollisionEntity {
        var colliders = Lambda.array(Lambda.map(this.colliders, c -> c.ToSerializable()));
        return new SerializableUnityCollisionEntity({
            id: Entity.ID,
            colliders: colliders
        });
    }
    public function LoadFromSerializable(seri:ISerializableCollisionEntity, entity:Entity):Void {
        Entity = entity;
        if (seri.Colliders != null) {
            for (extraCollider in seri.Colliders) {
                if (extraCollider == null || extraCollider.Name == null || extraCollider.Name.length == 0)
                    continue;
                var collider = CreateCollider(extraCollider.Name);
                collider.LoadFromSerializable(extraCollider, entity);
            }
        }
        UpdateEntity();
    }
    public function LoadCollisions(level:LevelEngine, seri:ISerializableCollisionEntity):Void {
        if (seri.Colliders == null)
            return;
        for (i in 0...colliders.length) {
            var colliderSeri = seri.Colliders[i];
            if (colliderSeri == null)
                continue;
            var collider = colliders[i];
            collider.LoadCollisions(level, colliderSeri);
        }
    }
    // #endregion

    public var Entity(default, null):Entity = null;
    @:serializeField
    private var rigid:Rigidbody = null;
    @:serializeField
    private var colliders:Array<UnityEntityCollider> = [];
    @:serializeField
    private var recyclingColliders:Array<UnityEntityCollider> = [];
    @:serializeField
    private var disabledColliders:Array<UnityEntityCollider> = [];
    @:serializeField
    private var colliderTemplate:GameObject = null;
    @:serializeField
    private var colliderRoot:Transform = null;
}

@:rtti
class SerializableUnityCollisionEntity implements ISerializableCollisionEntity {
    public var id:Int64;
    public var colliders:Array<SerializableUnityEntityCollider>;

    public function new(?fields:{id:Int64, colliders:Array<SerializableUnityEntityCollider>}) {
        if (fields != null) {
            id = fields.id;
            colliders = fields.colliders;
        }
    }

    public var ID(get, never):Int64;
    inline function get_ID():Int64 return id;
    public var Colliders(get, never):Array<ISerializableCollisionCollider>;
    function get_Colliders():Array<ISerializableCollisionCollider> {
        if (colliders == null) return null;
        return cast colliders;
    }
}

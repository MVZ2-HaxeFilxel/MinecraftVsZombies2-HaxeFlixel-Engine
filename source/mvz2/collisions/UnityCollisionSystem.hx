package mvz2.collisions;

import haxe.Int64;
// PORT-NOTE: SerializableUnityCollisionEntity 是 UnityCollisionEntity 模块内的次类型，
// Haxe 需从所属模块显式导入。
import mvz2.collisions.UnityCollisionEntity.SerializableUnityCollisionEntity;
import pvzengine.collisions.EntityCollision;
import pvzengine.collisions.EntityCollisionHelper;
import pvzengine.collisions.ICollisionSystem;
import pvzengine.collisions.IEntityCollider;
import pvzengine.collisions.ISerializableCollisionEntity;
import pvzengine.collisions.ISerializableCollisionSystem;
import pvzengine.collisions.level.OverlapParams;
import pvzengine.ColliderConstructor;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
import unity.Collider;
import unity.GameObject;
import unity.MonoBehaviour;
import unity.Physics;
import unity.QueryTriggerInteraction;
import unity.Quaternion;
import unity.Transform;
import unity.UnityObject;
import unity.Vector3;

// Ported from: Assets/Scripts/MVZ2/Collision/UnityCollisionSystem.cs
// PORT-NOTE: `ArrayBuffer<T>` (PVZEngine.Base) is replaced by a plain Haxe Array, and
// `Dictionary<long, T>` keyed lookups with an int index are ported as
// `map.get(Int64.ofInt(i))` to preserve the original behaviour.
class UnityCollisionSystem extends MonoBehaviour implements ICollisionSystem {
    public function Update():Void {
        ClearEntityTrash();
        Physics.Simulate(1);
        simulateBuffer = [for (e in entities) e];
        for (i in 0...simulateBuffer.length) {
            var entity = simulateBuffer[i];
            entity.Simulate();
            entity.RecycleColliders();
        }
    }
    public function InitEntity(entity:Entity):Void {
        var col = CreateCollisionEntity(entity);
        col.CreateMainCollider(EntityCollisionHelper.NAME_MAIN);
        entities.set(entity.ID, col);
    }
    public function UpdateEntityDetection(entity:Entity):Void {
        var ent = GetCollisionEntity(entity);
        if (ent != null) ent.UpdateEntityDetection();
    }
    public function UpdateEntityPosition(entity:Entity):Void {
        var ent = GetCollisionEntity(entity);
        if (ent != null) ent.UpdateEntityPosition();
    }
    public function UpdateEntitySize(entity:Entity):Void {
        var ent = GetCollisionEntity(entity);
        if (ent != null) ent.UpdateEntitySize();
    }
    public function DestroyEntity(entity:Entity):Void {
        DestroyCollisionEntity(entity);
    }
    public function GetCurrentCollisions(entity:Entity, collisions:Array<EntityCollision>):Void {
        var collisionEnt = GetCollisionEntity(entity);
        if (collisionEnt == null)
            return;
        collisionEnt.GetCollisions(collisions);
    }
    private function CreateCollisionEntity(entity:Entity):UnityCollisionEntity {
        var ent:UnityCollisionEntity;
        if (disabledEntities.length > 0) {
            ent = disabledEntities.shift();
        } else {
            var instance:GameObject = UnityObject.Instantiate(collisionEntityTemplate, null, null, entityRoot);
            ent = instance.GetComponent(UnityCollisionEntity);
        }
        ent.gameObject.SetActive(true);
        ent.Init(entity);
        return ent;
    }
    private function DestroyCollisionEntity(entity:Entity):Void {
        var collisionEnt = GetCollisionEntity(entity);
        if (collisionEnt != null && entities.remove(entity.ID)) {
            collisionEnt.gameObject.SetActive(false);
            entityTrash.set(entity.ID, collisionEnt);
        }
    }
    private function GetCollisionEntity(entity:Entity):UnityCollisionEntity {
        if (entities.exists(entity.ID))
            return entities.get(entity.ID);
        return GetCollisionEntityInTrash(entity.ID);
    }
    private function GetCollisionEntityInTrash(id:Int64):UnityCollisionEntity {
        if (entityTrash.exists(id))
            return entityTrash.get(id);
        return null;
    }
    private function ClearEntityTrash():Void {
        for (ent in entityTrash) {
            if (ent == null)
                continue;
            disabledEntities.push(ent);
            ent.ResetEntity();
        }
        entityTrash.clear();
    }

    // #region 碰撞体
    public function CreateCustomCollider(entity:Entity, cons:ColliderConstructor):IEntityCollider {
        var collisionEnt = GetCollisionEntity(entity);
        if (collisionEnt == null)
            return null;
        return collisionEnt.CreateCustomCollider(cons);
    }
    public function RemoveCollider(entity:Entity, name:String):Bool {
        var collisionEnt = GetCollisionEntity(entity);
        if (collisionEnt == null)
            return false;
        return collisionEnt.DestroyCollider(name);
    }
    public function GetCollider(entity:Entity, name:String):UnityEntityCollider {
        var collisionEnt = GetCollisionEntity(entity);
        if (collisionEnt == null)
            return null;
        return collisionEnt.GetCollider(name);
    }
    // #endregion

    // #region 检测
    public function OverlapBox(center:Vector3, size:Vector3, param:OverlapParams):Array<IEntityCollider> {
        var results:Array<IEntityCollider> = [];
        OverlapBoxNonAlloc(center, size, param, results);
        return results;
    }
    public function OverlapBoxNonAlloc(center:Vector3, size:Vector3, param:OverlapParams, results:Array<IEntityCollider>):Void {
        var combinedMask = param.hostileMask | param.friendlyMask;
        var layerMask = UnityCollisionHelper.ToObjectLayerMask(combinedMask);

        var colliderCount = Physics.OverlapBoxNonAlloc(center, size * 0.5, overlapBuffer, Quaternion.identity, layerMask, QueryTriggerInteraction.Collide);
        for (i in 0...colliderCount) {
            var col = overlapBuffer[i];
            var collider = col.GetComponent(UnityEntityCollider);
            if (results.contains(collider))
                continue;
            var ent = collider.Entity;
            if (EntityCollisionHelper.CanCollide(param.hostileMask, ent) && ent.IsHostile(param.faction)) {
                results.push(collider);
            } else if (EntityCollisionHelper.CanCollide(param.friendlyMask, ent) && ent.IsFriendly(param.faction)) {
                results.push(collider);
            }
        }
    }
    public function OverlapSphere(center:Vector3, radius:Float, param:OverlapParams):Array<IEntityCollider> {
        var results:Array<IEntityCollider> = [];
        OverlapSphereNonAlloc(center, radius, param, results);
        return results;
    }
    public function OverlapSphereNonAlloc(center:Vector3, radius:Float, param:OverlapParams, results:Array<IEntityCollider>):Void {
        var combinedMask = param.hostileMask | param.friendlyMask;
        var layerMask = UnityCollisionHelper.ToObjectLayerMask(combinedMask);

        var colliderCount = Physics.OverlapSphereNonAlloc(center, radius, overlapBuffer, layerMask, QueryTriggerInteraction.Collide);
        for (i in 0...colliderCount) {
            var col = overlapBuffer[i];
            var collider = col.GetComponent(UnityEntityCollider);
            if (results.contains(collider))
                continue;
            var ent = collider.Entity;
            if (EntityCollisionHelper.CanCollide(param.hostileMask, ent) && ent.IsHostile(param.faction)) {
                results.push(collider);
            } else if (EntityCollisionHelper.CanCollide(param.friendlyMask, ent) && ent.IsFriendly(param.faction)) {
                results.push(collider);
            }
        }
    }
    public function OverlapCapsule(point0:Vector3, point1:Vector3, radius:Float, param:OverlapParams):Array<IEntityCollider> {
        var results:Array<IEntityCollider> = [];
        OverlapCapsuleNonAlloc(point0, point1, radius, param, results);
        return results;
    }
    public function OverlapCapsuleNonAlloc(point0:Vector3, point1:Vector3, radius:Float, param:OverlapParams, results:Array<IEntityCollider>):Void {
        var combinedMask = param.hostileMask | param.friendlyMask;
        var layerMask = UnityCollisionHelper.ToObjectLayerMask(combinedMask);

        var colliderCount = Physics.OverlapCapsuleNonAlloc(point0, point1, radius, overlapBuffer, layerMask, QueryTriggerInteraction.Collide);
        for (i in 0...colliderCount) {
            var col = overlapBuffer[i];
            var collider = col.GetComponent(UnityEntityCollider);
            if (results.contains(collider))
                continue;
            var ent = collider.Entity;
            if (EntityCollisionHelper.CanCollide(param.hostileMask, ent) && ent.IsHostile(param.faction)) {
                results.push(collider);
            } else if (EntityCollisionHelper.CanCollide(param.friendlyMask, ent) && ent.IsFriendly(param.faction)) {
                results.push(collider);
            }
        }
    }
    // #endregion

    public function ToSerializable():SerializableUnityCollisionSystem {
        var ents = Lambda.array(Lambda.map(Lambda.filter([for (e in entities) e], e -> e != null && e.Entity != null), e -> e.ToSerializable()));
        var trash = Lambda.array(Lambda.map(Lambda.filter([for (e in entityTrash) e], e -> e != null && e.Entity != null), e -> e.ToSerializable()));
        return new SerializableUnityCollisionSystem({
            entities: ents,
            entityTrash: trash
        });
    }
    public function LoadFromSerializable(level:LevelEngine, seri:ISerializableCollisionSystem):Void {
        // Load Entities.
        if (seri.Entities != null) {
            for (seriEnt in seri.Entities) {
                if (seriEnt == null)
                    continue;
                var ent = level.FindEntityByID(seriEnt.ID);
                if (ent == null)
                    continue;
                var colEntity = CreateCollisionEntity(ent);
                colEntity.LoadFromSerializable(seriEnt, ent);
                entities.set(ent.ID, colEntity);
            }
        }

        if (seri.EntityTrash != null) {
            for (seriEnt in seri.EntityTrash) {
                if (seriEnt == null)
                    continue;
                var ent = level.FindEntityByID(seriEnt.ID);
                if (ent == null)
                    continue;
                var colEntity = CreateCollisionEntity(ent);
                colEntity.LoadFromSerializable(seriEnt, ent);
                colEntity.gameObject.SetActive(false);
                entityTrash.set(ent.ID, colEntity);
            }
        }

        // Load Collisions.
        if (seri.Entities != null) {
            for (i in 0...seri.Entities.length) {
                var ent = entities.get(Int64.ofInt(i));
                var seriEnt = seri.Entities[i];
                if (seriEnt == null)
                    continue;
                ent.LoadCollisions(level, seriEnt);
            }
        }
        if (seri.EntityTrash != null) {
            for (i in 0...seri.EntityTrash.length) {
                var ent = entityTrash.get(Int64.ofInt(i));
                var seriEnt = seri.EntityTrash[i];
                if (seriEnt == null)
                    continue;
                ent.LoadCollisions(level, seriEnt);
            }
        }
    }

    @:serializeField
    private var collisionEntityTemplate:GameObject = null;
    @:serializeField
    private var entityRoot:Transform = null;
    private var overlapBuffer:Array<Collider> = new Array<Collider>();
    private var simulateBuffer:Array<UnityCollisionEntity> = [];
    private var entities:Map<Int64, UnityCollisionEntity> = new Map();
    private var entityTrash:Map<Int64, UnityCollisionEntity> = new Map();
    private var disabledEntities:Array<UnityCollisionEntity> = [];

    public function new() {
        super();
        overlapBuffer.resize(2048);
    }
}

@:rtti
class SerializableUnityCollisionSystem implements ISerializableCollisionSystem {
    public var entities:Array<SerializableUnityCollisionEntity>;
    public var entityTrash:Array<SerializableUnityCollisionEntity>;

    public function new(?fields:{entities:Array<SerializableUnityCollisionEntity>, entityTrash:Array<SerializableUnityCollisionEntity>}) {
        if (fields != null) {
            entities = fields.entities;
            entityTrash = fields.entityTrash;
        }
    }

    public var Entities(get, never):Array<ISerializableCollisionEntity>;
    function get_Entities():Array<ISerializableCollisionEntity> {
        if (entities == null) return null;
        return cast entities;
    }
    public var EntityTrash(get, never):Array<ISerializableCollisionEntity>;
    function get_EntityTrash():Array<ISerializableCollisionEntity> {
        if (entityTrash == null) return null;
        return cast entityTrash;
    }
}

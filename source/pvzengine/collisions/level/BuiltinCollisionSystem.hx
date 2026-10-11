// Ported from: Assets/Scripts/Engine/Level/Collisions/Level/BuiltinCollisionSystem.cs
package pvzengine.collisions.level;

import haxe.Int64;
import pvzengine.collisions.BuiltinCollisionCollider;
import pvzengine.collisions.BuiltinCollisionEntity;
import pvzengine.collisions.BuiltinCollisionEntity.SerializableBuiltinCollisionSystemEntity;
import pvzengine.collisions.ColliderConstructor;
import pvzengine.collisions.Hitbox;
import pvzengine.collisions.IEntityCollider;
import pvzengine.collisions.ISerializableCollisionEntity;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollision;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.level.LevelEngine;
import tools.Ref;
import tools.geometrical.Capsule;
import tools.geometrical.Geometry;
import unity.Bounds;
import unity.Rect;
import unity.Vector3;
import unity.pool.ObjectPool;
// PORT-NOTE: C# 中 `entity.IsCollisionCheckDisabled()` / `entity.IsCollisionOverlapDisabled()` 是
// EngineEntityProps 的扩展方法（PVZEngine.Entities 命名空间，C# 靠 using 引入扩展），
// Haxe 用 using 声明等价。
using pvzengine.entities.EngineEntityProps;

class BuiltinCollisionSystem implements ICollisionSystem
{
    public function new(treeParams:QuadTreeParams)
    {
        quadTreeParams = treeParams;
        entityPool = new ObjectPool<BuiltinCollisionEntity>(CreateEntityFunc);
        // PORT-NOTE: C# 直接使用方法组注册事件；闭包相等性依赖目标平台，故缓存闭包实例（同 BuiltinCollisionEntity）。
        onEntityColliderEnabledCallback = OnEntityColliderEnabledCallback;
        onEntityColliderDisabledCallback = OnEntityColliderDisabledCallback;
        onEntityColliderAddCallback = OnEntityColliderAddCallback;
        onEntityColliderRemoveCallback = OnEntityColliderRemoveCallback;
    }
    public function Update():Void
    {
        UpdateTrash();
        Simulate();
    }
    private function Simulate():Void
    {
        colliderBuffer = [];
        for (quadTree in quadTrees)
        {
            quadTree.Update();
            quadTree.GetAllTargets(colliderBuffer);
        }

        for (collider1 in colliderBuffer)
        {
            var ent1 = collider1.Entity;
            if (ent1.IsCollisionCheckDisabled())
                continue;
            if (ent1.Cache.CollisionInterval > 1 && !ent1.IsTimeInterval(ent1.Cache.CollisionInterval))
                continue;
            var maskHostile = ent1.CollisionMaskHostile;
            var maskFriendly = ent1.CollisionMaskFriendly;
            var maskTotal = maskHostile | maskFriendly;
            var ent1Faction = ent1.Cache.Faction;

            // PORT-NOTE: C# 的局部函数（local function）改为局部闭包。
            var colliderFilter = function(collider2:BuiltinCollisionCollider):Bool
            {
                if (collider1 == collider2)
                    return false;
                var ent2 = collider2.Entity;
                if (ent1 == ent2)
                    return false;
                if (ent2.IsCollisionCheckDisabled())
                    return false;
                if (!EntityCollisionHelper.CanCollideFaction(maskHostile, maskFriendly, ent1Faction, ent2))
                    return false;
                return true;
            };

            var rect1 = collider1.GetCollisionRect();

            var sorter = colliderComparer;
            sorter.SetCollider(collider1);

            collisionBuffer = [];
            FindCollidersRange(maskTotal, rect1, collisionBuffer, 0, colliderFilter);
            // PORT-NOTE: C# `List<T>.Sort(IComparer<T>)` → Haxe Array.sort(compare 函数)。
            collisionBuffer.sort(sorter.Compare);

            for (collider2 in collisionBuffer)
            {
                collider1.DoCollision(collider2, Vector3.zero);
            }

            collider1.ExitCollision();
        }
    }
    private function UpdateTrash():Void
    {
        for (trash in entityTrash)
        {
            entityPool.Release(trash);
        }
        entityTrash = new Map();
    }


    // #region 实体
    public function InitEntity(entity:Entity):Void
    {
        var collisionEntity = CreateCollisionEntity();
        collisionEntity.Init(entity);
        entities.set(entity.ID, collisionEntity);
    }
    public function UpdateEntityDetection(entity:Entity):Void
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity != null)
            collisionEntity.UpdateEntityDetection();
    }
    public function UpdateEntityPosition(entity:Entity):Void
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity != null)
            collisionEntity.UpdateEntityPosition();
    }
    public function UpdateEntitySize(entity:Entity):Void
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity != null)
            collisionEntity.UpdateEntitySize();
    }
    public function DestroyEntity(entity:Entity):Void
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity == null)
            return;
        RemoveCollisionEntity(collisionEntity);
    }
    public function GetCurrentCollisions(entity:Entity, collisions:Array<EntityCollision>):Void
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity == null)
            return;
        collisionEntity.GetCurrentCollisions(collisions);
    }

    private function CreateEntityFunc():BuiltinCollisionEntity
    {
        return new BuiltinCollisionEntity();
    }
    public function CreateCollisionEntity():BuiltinCollisionEntity
    {
        var collisionEnt = entityPool.Get();
        collisionEnt.OnEntityColliderEnabled.add(onEntityColliderEnabledCallback);
        collisionEnt.OnEntityColliderDisabled.add(onEntityColliderDisabledCallback);
        collisionEnt.OnEntityColliderAdd.add(onEntityColliderAddCallback);
        collisionEnt.OnEntityColliderRemove.add(onEntityColliderRemoveCallback);
        return collisionEnt;
    }
    public function GetCollisionEntity(entity:Entity):Null<BuiltinCollisionEntity>
    {
        return entities.exists(entity.ID) ? entities.get(entity.ID) : null;
    }
    public function RemoveCollisionEntity(entity:BuiltinCollisionEntity):Bool
    {
        var id = entity.ID;
        if (entities.remove(id))
        {
            entity.ClearColliders();
            entity.OnEntityColliderEnabled.remove(onEntityColliderEnabledCallback);
            entity.OnEntityColliderDisabled.remove(onEntityColliderDisabledCallback);
            entity.OnEntityColliderAdd.remove(onEntityColliderAddCallback);
            entity.OnEntityColliderRemove.remove(onEntityColliderRemoveCallback);
            entityTrash.set(id, entity);
            return true;
        }
        return false;
    }
    // #endregion


    // #region 碰撞体
    public function CreateCustomCollider(entity:Entity, cons:ColliderConstructor):Null<IEntityCollider>
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity == null)
            return null;
        return collisionEntity.CreateCustomCollider(cons);
    }
    public function AddCollider(entity:Entity, collider:IEntityCollider):Void
    {
        if (!Std.isOfType(collider, BuiltinCollisionCollider))
            return;
        var entCol:BuiltinCollisionCollider = cast collider;
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity == null)
            return;
        collisionEntity.AddCollider(entCol);
    }
    public function RemoveCollider(entity:Entity, name:String):Bool
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity == null)
            return false;
        return collisionEntity.RemoveCollider(name);
    }
    public function GetCollider(entity:Entity, name:String):Null<BuiltinCollisionCollider>
    {
        var collisionEntity = GetCollisionEntity(entity);
        if (collisionEntity == null)
            return null;
        return collisionEntity.GetCollider(name);
    }

    // #endregion

    // #region 检测
    public function OverlapBox(center:Vector3, size:Vector3, param:OverlapParams):Array<IEntityCollider>
    {
        var min = center - size * 0.5;
        var filterRect = new Rect(min.x, min.z, size.x, size.z);
        var bounds = new Bounds(center, size);
        return Overlap(filterRect, param, h -> bounds.IntersectsOptimized(h.GetBounds()));
    }
    public function OverlapBoxNonAlloc(center:Vector3, size:Vector3, param:OverlapParams, results:Array<IEntityCollider>):Void
    {
        var min = center - size * 0.5;
        var filterRect = new Rect(min.x, min.z, size.x, size.z);
        var bounds = new Bounds(center, size);
        OverlapNonAlloc(filterRect, param, h -> bounds.IntersectsOptimized(h.GetBounds()), results);
    }
    public function OverlapSphere(center:Vector3, radius:Float, param:OverlapParams):Array<IEntityCollider>
    {
        var min = center - Vector3.one * radius;
        var filterRect = new Rect(min.x, min.z, radius * 2, radius * 2);
        return Overlap(filterRect, param, h -> Geometry.CollideBetweenCubeAndSphere(h.GetBounds(), center, radius));
    }
    public function OverlapSphereNonAlloc(center:Vector3, radius:Float, param:OverlapParams, results:Array<IEntityCollider>):Void
    {
        var min = center - Vector3.one * radius;
        var filterRect = new Rect(min.x, min.z, radius * 2, radius * 2);
        OverlapNonAlloc(filterRect, param, h -> Geometry.CollideBetweenCubeAndSphere(h.GetBounds(), center, radius), results);
    }
    public function OverlapCapsule(point0:Vector3, point1:Vector3, radius:Float, param:OverlapParams):Array<IEntityCollider>
    {
        var center = (point1 + point0) * 0.5;
        var min = center - Vector3.one * radius;
        var filterRect = new Rect(min.x, min.z, radius * 2, radius * 2);
        var capsule = new Capsule(point0, point1, radius);
        return Overlap(filterRect, param, h -> Geometry.CollideBetweenCubeAndCapsule(capsule, h.GetBounds()));
    }
    public function OverlapCapsuleNonAlloc(point0:Vector3, point1:Vector3, radius:Float, param:OverlapParams, results:Array<IEntityCollider>):Void
    {
        var center = (point1 + point0) * 0.5;
        var min = center - Vector3.one * radius;
        var filterRect = new Rect(min.x, min.z, radius * 2, radius * 2);
        var capsule = new Capsule(point0, point1, radius);
        OverlapNonAlloc(filterRect, param, h -> Geometry.CollideBetweenCubeAndCapsule(capsule, h.GetBounds()), results);
    }
    public function Overlap(filterRect:Rect, param:OverlapParams, predicate:Hitbox->Bool):Array<IEntityCollider>
    {
        if (predicate == null)
            return [];
        var totalMask = param.hostileMask | param.friendlyMask;
        overlapBuffer = [];
        FindCollidersRange(totalMask, filterRect, overlapBuffer, 0, c -> FilterOverlap(param, predicate, c));
        // PORT-NOTE: C# 返回 `overlapBuffer.ToArray()`（返回副本，且依赖 C# 的数组协变）；
        // Haxe 的 Array 对类类型不变，这里复制一份并逐个上转为 IEntityCollider。
        var result:Array<IEntityCollider> = [];
        for (collider in overlapBuffer)
        {
            result.push(collider);
        }
        return result;
    }
    private function OverlapNonAlloc(filterRect:Rect, param:OverlapParams, predicate:Hitbox->Bool, results:Array<IEntityCollider>):Void
    {
        if (predicate == null)
            return;
        var totalMask = param.hostileMask | param.friendlyMask;
        overlapBuffer = [];
        FindCollidersRange(totalMask, filterRect, overlapBuffer, 0, c -> FilterOverlap(param, predicate, c));
        for (collider in overlapBuffer)
        {
            results.push(collider);
        }
    }
    private function FilterOverlap(param:OverlapParams, hitboxPredicate:Hitbox->Bool, collider:BuiltinCollisionCollider):Bool
    {
        var entity = collider.Entity;
        if (!param.includeIgnored && entity.IsCollisionOverlapDisabled())
            return false;
        if (EntityCollisionHelper.CanCollideFaction(param.hostileMask, param.friendlyMask, param.faction, entity))
        {
            var hitbox = collider.GetHitbox();
            if (hitboxPredicate(hitbox))
            {
                return true;
            }
        }
        return false;
    }
    // #endregion

    // #region 四叉树
    public function GetCollisionQuadTree(flag:Int):Null<QuadTreeCollider>
    {
        if (quadTrees.exists(flag))
            return quadTrees.get(flag);
        return null;
    }
    private function FindCollidersRange(mask:Int, rect:Rect, results:Array<BuiltinCollisionCollider>, rewind:Float = 0, predicate:BuiltinCollisionCollider->Bool = null):Void
    {
        for (flag in quadTrees.keys())
        {
            if ((flag & mask) == 0)
                continue;
            var quadTree = quadTrees.get(flag);
            quadTree.FindTargetsInRect(rect, results, rewind, predicate);
        }
    }
    private function InsertColliderToTree(flag:Int, collider:BuiltinCollisionCollider):Void
    {
        var tree = quadTrees.get(flag);
        if (tree == null)
        {
            tree = CreateQuadTree();
            quadTrees.set(flag, tree);
        }
        tree.Insert(collider);
    }
    private function RemoveColliderFromTree(flag:Int, collider:BuiltinCollisionCollider):Void
    {
        var tree = quadTrees.get(flag);
        if (tree == null)
        {
            return;
        }
        tree.Remove(collider);
    }
    private function CreateQuadTree():QuadTreeCollider
    {
        return new QuadTreeCollider(quadTreeParams.size, quadTreeParams.maxObjects, quadTreeParams.collapseObjects, quadTreeParams.maxDepth);
    }
    // #endregion

    // #region 回调
    private function OnEntityColliderEnabledCallback(entity:BuiltinCollisionEntity, collider:BuiltinCollisionCollider):Void
    {
        InsertColliderToTree(entity.Entity.TypeCollisionFlag, collider);
    }
    private function OnEntityColliderDisabledCallback(entity:BuiltinCollisionEntity, collider:BuiltinCollisionCollider):Void
    {
        RemoveColliderFromTree(collider.Entity.TypeCollisionFlag, collider);
    }
    private function OnEntityColliderAddCallback(entity:BuiltinCollisionEntity, collider:BuiltinCollisionCollider):Void
    {
        if (collider.Enabled)
        {
            InsertColliderToTree(entity.Entity.TypeCollisionFlag, collider);
        }
    }
    private function OnEntityColliderRemoveCallback(entity:BuiltinCollisionEntity, collider:BuiltinCollisionCollider):Void
    {
        if (collider.Enabled)
        {
            RemoveColliderFromTree(collider.Entity.TypeCollisionFlag, collider);
        }
    }
    // #endregion

    public function ToSerializable():SerializableBuiltinCollisionSystem
    {
        // PORT-NOTE: C# 的容器为 SortedDictionary（按 long 键升序枚举）；Haxe 的 Map 无顺序，
        // 这里显式按键排序后再序列化，保持与 C# 相同的输出顺序。
        var seri = new SerializableBuiltinCollisionSystem();
        seri.entities = [for (id in sortedKeys(entities)) entities.get(id).ToSerializable()];
        seri.entityTrash = [for (id in sortedKeys(entityTrash)) entityTrash.get(id).ToSerializable()];
        return seri;
    }
    public function LoadFromSerializable(level:LevelEngine, seri:ISerializableCollisionSystem):Void
    {
        if (seri.Entities != null)
        {
            for (seriEnt in seri.Entities)
            {
                if (seriEnt == null)
                    continue;
                var entity = CreateCollisionEntity();
                entity.LoadFromSerializable(level, seriEnt);
                entities.set(seriEnt.ID, entity);
            }
        }
        if (seri.EntityTrash != null)
        {
            for (seriEnt in seri.EntityTrash)
            {
                if (seriEnt == null)
                    continue;
                var entity = CreateCollisionEntity();
                entity.LoadFromSerializable(level, seriEnt);
                entityTrash.set(seriEnt.ID, entity);
            }
        }
        if (seri.Entities != null)
        {
            for (seriEnt in seri.Entities)
            {
                if (seriEnt == null)
                    continue;
                var entity = entities.get(seriEnt.ID);
                entity.LoadCollisions(level, seriEnt);
            }
        }
        if (seri.EntityTrash != null)
        {
            for (seriEnt in seri.EntityTrash)
            {
                if (seriEnt == null)
                    continue;
                var entity = entityTrash.get(seriEnt.ID);
                entity.LoadCollisions(level, seriEnt);
            }
        }
    }
    // PORT-NOTE: C# 显式实现 `ISerializableCollisionSystem ICollisionSystem.ToSerializable()`；
    // Haxe 无显式接口实现，已由同名的 ToSerializable() 满足接口。

    private static function sortedKeys(map:Map<Int64, BuiltinCollisionEntity>):Array<Int64>
    {
        var keys = [for (k in map.keys()) k];
        keys.sort(Int64.compare);
        return keys;
    }


    private var colliderBuffer:Array<BuiltinCollisionCollider> = [];
    private var collisionBuffer:Array<BuiltinCollisionCollider> = [];
    private var overlapBuffer:Array<BuiltinCollisionCollider> = [];
    private var entityPool:ObjectPool<BuiltinCollisionEntity>;
    private var quadTrees:Map<Int, QuadTreeCollider> = new Map();
    private var quadTreeParams:QuadTreeParams;
    private var colliderComparer:ColliderComparer = new ColliderComparer();

    // PORT-NOTE: C# 为 SortedDictionary<long, T>；Haxe 的 Map 无序（需要顺序处见 sortedKeys）。
    private var entities:Map<Int64, BuiltinCollisionEntity> = new Map();
    private var entityTrash:Map<Int64, BuiltinCollisionEntity> = new Map();
    // PORT-NOTE: C# 直接使用方法组注册事件；闭包相等性依赖目标平台，故缓存闭包实例（同 BuiltinCollisionEntity）。
    private var onEntityColliderEnabledCallback:BuiltinCollisionEntity->BuiltinCollisionCollider->Void = null;
    private var onEntityColliderDisabledCallback:BuiltinCollisionEntity->BuiltinCollisionCollider->Void = null;
    private var onEntityColliderAddCallback:BuiltinCollisionEntity->BuiltinCollisionCollider->Void = null;
    private var onEntityColliderRemoveCallback:BuiltinCollisionEntity->BuiltinCollisionCollider->Void = null;
}

// [Serializable]
@:rtti
class SerializableBuiltinCollisionSystem implements ISerializableCollisionSystem
{
    public function new()
    {
    }
    public var entities:Null<Array<SerializableBuiltinCollisionSystemEntity>>;
    public var entityTrash:Null<Array<SerializableBuiltinCollisionSystemEntity>>;
    public var Entities(get, never):Null<Array<ISerializableCollisionEntity>>;
    function get_Entities():Null<Array<ISerializableCollisionEntity>>
    {
        if (entities == null)
            return null;
        return cast entities;
    }
    public var EntityTrash(get, never):Null<Array<ISerializableCollisionEntity>>;
    function get_EntityTrash():Null<Array<ISerializableCollisionEntity>>
    {
        if (entityTrash == null)
            return null;
        return cast entityTrash;
    }
}

class ColliderComparer
{
    public function new(precision:Float = 1)
    {
        this.precision = precision;
    }
    public function SetCollider(collider:BuiltinCollisionCollider):Void
    {
        this.collider = collider;
        var ent1 = collider.Entity;
        prevPosition = collider.GetPosition() - (ent1.Position - ent1.PreviousPosition);
        collisionTimeCache = new Map();
    }

    public function Compare(c1:BuiltinCollisionCollider, c2:BuiltinCollisionCollider):Int
    {
        var collisionTime1 = GetCollisionTime(c1);
        var collisionTime2 = GetCollisionTime(c2);
        // C#: collisionTime1.CompareTo(collisionTime2)
        var distanceResult = collisionTime1 < collisionTime2 ? -1 : (collisionTime1 > collisionTime2 ? 1 : 0);
        if (distanceResult != 0)
            return distanceResult;
        var id1 = c1.Entity.ID;
        var id2 = c2.Entity.ID;
        // C#: id1.CompareTo(id2)
        var idResult = Int64.compare(id1, id2);
        if (idResult != 0)
            return idResult;
        // C#: c1.Name.CompareTo(c2.Name)
        return Reflect.compare(c1.Name, c2.Name);
    }
    private function GetCollisionTime(c:BuiltinCollisionCollider):Float
    {
        if (collider == null)
            throw 'Collider of a ColliderComparer is not set before comparing.';
        var time = collisionTimeCache.get(c);
        if (time == null)
        {
            // PORT-NOTE: C# 的 `out float t` → tools.Ref<Float>。
            var t = Ref.to(0.0);
            time = collider.GetCollisionTime(prevPosition, c, precision, t) ? t.value : Math.POSITIVE_INFINITY;
            collisionTimeCache.set(c, time);
        }
        return time;
    }
    private var precision:Float = 1;
    private var collider:BuiltinCollisionCollider;
    private var prevPosition:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    private var collisionTimeCache:Map<BuiltinCollisionCollider, Float> = new Map();
}

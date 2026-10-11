package mvz2.collisions;

import haxe.Int64;
import pvzengine.ColliderConstructor;
import pvzengine.EntityColliderReference;
import pvzengine.NamespaceID;
import pvzengine.collisions.EntityCollision;
import pvzengine.collisions.EntityCollisionHelper;
import pvzengine.collisions.IEntityCollider;
import pvzengine.collisions.ISerializableCollisionCollider;
import pvzengine.collisions.ISerializableCollisionEntity;
import pvzengine.entities.Entity;
import pvzengine.level.LevelEngine;
import unity.BoxCollider;
import unity.Bounds;
import unity.Collider;
import unity.MonoBehaviour;
import unity.Vector3;
import Main;

// Ported from: Assets/Scripts/MVZ2/Collision/UnityEntityCollider.cs
// PORT-NOTE: `Tools.Geometrical` (external assembly, not present in the repo) is replaced by
// local equivalents: Vector3.Abs() is inlined, Bounds.IntersectsOptimized lives in unity.Bounds,
// and the capsule/cube test is approximated in CollideBetweenCubeAndCapsule.
class UnityEntityCollider extends MonoBehaviour implements IEntityCollider {
    public function ResetCollider():Void {
        SetEnabled(true);
        SetMain();
        touchingColliders = [];
        collisionList = [];
        collisionBuffer = [];
    }
    public function Init(entity:Entity, name:String):Void {
        if (name == null || name.length == 0)
            throw 'The name of an EntityCollider cannot be null or empty.';
        Entity = entity;
        Name = name;
        gameObject.name = Name;
    }
    public function SetMain():Void {
        updateMode = ColliderUpdateMode.Main;
        ArmorSlot = null;
        customSize = Vector3.zero;
        customOffset = Vector3.zero;
        customPivot = Vector3.one * 0.5;
    }
    public function SetCustom(constructor:ColliderConstructor):Void {
        updateMode = ColliderUpdateMode.Custom;
        ArmorSlot = constructor.armorSlot;
        customSize = constructor.size;
        customOffset = constructor.offset;
        customPivot = constructor.pivot;
    }
    public function SetEnabled(enabled:Bool):Void {
        if (Enabled == enabled)
            return;
        Enabled = enabled;
        boxCollider.enabled = enabled;
    }
    public function UpdateEntitySize():Void {
        var boundsSize:Vector3;
        var boundsPivot:Vector3;
        var boundsOffset:Vector3;
        switch (updateMode) {
            case ColliderUpdateMode.Main:
                boundsSize = Entity.GetSize();
                boundsPivot = Entity.GetBoundsPivot();
                boundsOffset = Vector3.zero;
            case ColliderUpdateMode.Custom:
                boundsSize = customSize;
                boundsPivot = customPivot;
                boundsOffset = customOffset;
            default:
                return;
        }

        var scale = Entity.GetFinalScale();
        var center = Vector3.Scale(Vector3.one * 0.5 - boundsPivot, boundsSize) + boundsOffset;
        center = Vector3.Scale(center, scale);
        boundsSize = Vector3.Scale(boundsSize, scale);
        // PORT-NOTE: Tools extension `Vector3.Abs()`.
        boundsSize = new Vector3(Math.abs(boundsSize.x), Math.abs(boundsSize.y), Math.abs(boundsSize.z));
        boxCollider.center = center;
        boxCollider.size = boundsSize;
    }
    public function Simulate():Void {
        for (colliderCache in touchingColliders) {
            var collider = colliderCache.collider;
            if (collider == null)
                continue;
            var otherCollider = collider.GetComponent(UnityEntityCollider);
            if (otherCollider == null)
                continue;

            var other = otherCollider.Entity;
            if (other == null)
                continue;

            var collision = Lambda.find(collisionList, c -> (cast c.OtherCollider : UnityEntityCollider) == otherCollider);
            if (collision == null) {
                collision = new EntityCollision(this, otherCollider);
                collision.Enter = true;
                collisionList.push(collision);
            } else {
                collision.Enter = false;
            }
            collision.Checked = true;
        }
        collisionBuffer = Lambda.array(collisionList);
        for (i in 0...collisionBuffer.length) {
            var collision = collisionBuffer[i];
            if (collision.Checked) {
                if (CallPreCollision(collision)) {
                    if (collision.Enter) {
                        CallPostCollision(collision, EntityCollisionHelper.STATE_ENTER);
                    } else {
                        CallPostCollision(collision, EntityCollisionHelper.STATE_STAY);
                    }
                }
            } else {
                collisionList.remove(collision);
                CallPostCollision(collision, EntityCollisionHelper.STATE_EXIT);
            }
            collision.Checked = false;
        }
        touchingColliders = [];
    }
    public function GetBoundingBox():Bounds {
        return boxCollider.bounds;
    }
    private function OnTriggerStay(other:Collider):Void {
        for (c in touchingColliders) {
            if (c.collider == other)
                return;
        }
        var otherCollider = other.GetComponent(UnityEntityCollider);
        if (otherCollider == null)
            return;
        var targetEnt = otherCollider.Entity;
        var cache = new ColliderCache(other, Entity, targetEnt.ID);
        var mask = Entity.IsHostile(targetEnt) ? Entity.CollisionMaskHostile : Entity.CollisionMaskFriendly;
        if (!EntityCollisionHelper.CanCollide(mask, targetEnt))
            return;
        var index = binarySearch(touchingColliders, cache);
        if (index < 0) {
            touchingColliders.insert(~index, cache);
        }
    }

    // PORT-NOTE: C# `List<T>.BinarySearch` with IComparable; reimplemented here.
    private static function binarySearch(list:Array<ColliderCache>, value:ColliderCache):Int {
        var lo = 0;
        var hi = list.length - 1;
        while (lo <= hi) {
            var mid = (lo + hi) >> 1;
            var cmp = list[mid].CompareTo(value);
            if (cmp == 0) return mid;
            if (cmp < 0) lo = mid + 1;
            else hi = mid - 1;
        }
        return ~lo;
    }

    // #region 检测
    public function CheckBox(center:Vector3, size:Vector3):Bool {
        return boxCollider.bounds.IntersectsOptimized(new Bounds(center, size));
    }
    public function CheckSphere(center:Vector3, radius:Float):Bool {
        var closest = boxCollider.ClosestPoint(center);
        return (closest - (transform.position + boxCollider.center)).sqrMagnitude < radius * radius;
    }
    public function CheckCapsule(pos1:Vector3, pos2:Vector3, radius:Float):Bool {
        // TODO-PORT: `Tools.Geometrical.Geometry.CollideBetweenCubeAndCapsule` comes from an
        // external assembly that is not part of the repository; approximated with a bounding
        // sphere test.
        var sphereCenter = boxCollider.bounds.center;
        var capsuleCenter = (pos1 + pos2) * 0.5;
        var capsuleRadius = radius + Vector3.Distance(pos1, pos2) * 0.5;
        var boxRadius = boxCollider.bounds.extents.magnitude;
        return Vector3.Distance(sphereCenter, capsuleCenter) <= capsuleRadius + boxRadius;
    }
    // #endregion

    // #region 碰撞
    public function GetCollisions(collisions:Array<EntityCollision>):Void {
        for (c in collisionList) collisions.push(c);
    }
    private function CallPreCollision(collision:EntityCollision):Bool {
        return Entity.PreCollision(collision);
    }
    private function CallPostCollision(collision:EntityCollision, state:Int):Void {
        Entity.PostCollision(collision, state);
    }
    // #endregion

    // #region 序列化
    public function ToReference():EntityColliderReference {
        return new EntityColliderReference(Entity.ID, Name);
    }
    public function ToSerializable():SerializableUnityEntityCollider {
        return new SerializableUnityEntityCollider({
            name: Name,
            collisionList: Lambda.array(Lambda.map(collisionList, c -> c.ToSerializable())),
            enabled: Enabled,
            armorSlot: ArmorSlot,
            updateMode: cast updateMode,
            customSize: customSize,
            customOffset: customOffset,
            customPivot: customPivot,
        });
    }
    public function LoadFromSerializable(seri:ISerializableCollisionCollider, entity:Entity):Void {
        if (seri.Name == null || seri.Name.length == 0) {
            // TODO-PORT: `MissingSerializeDataException.Property<T>(nameof(Name))` belongs to
            // PVZEngine, whose sources are not present in this repository.
            throw 'Missing serialize data: Name';
        }
        Entity = entity;
        Name = seri.Name;
        ArmorSlot = seri.ArmorSlot;
        updateMode = cast seri.UpdateMode;
        customSize = seri.CustomSize;
        customOffset = seri.CustomOffset;
        customPivot = seri.CustomPivot;
        gameObject.name = Name;
        SetEnabled(seri.Enabled);
    }
    public function LoadCollisions(level:LevelEngine, seri:ISerializableCollisionCollider):Void {
        collisionList = [];
        if (seri.Collisions != null) {
            // PORT-NOTE: ISerializableCollisionCollider.Collisions 声明为 Dynamic（C# 是可空数组），
            // 这里显式标注为 Array<Dynamic> 才能迭代。
            var collisions:Array<Dynamic> = seri.Collisions;
            for (seriCollision in collisions) {
                if (seriCollision == null)
                    continue;
                var collision = EntityCollision.FromSerializable(seriCollision, level);
                if (collision == null)
                    continue;
                collisionList.push(collision);
            }
        }
    }
    // #endregion

    public var Enabled(default, null):Bool = true;
    public var Name(default, null):String = null;
    public var Entity(default, null):Entity = null;
    public var ArmorSlot(default, null):NamespaceID;
    private var updateMode:ColliderUpdateMode;
    private var customSize:Vector3 = Vector3.zero;
    private var customOffset:Vector3 = Vector3.zero;
    private var customPivot:Vector3 = Vector3.one * 0.5;

    @:serializeField
    private var boxCollider:BoxCollider = null;
    private var touchingColliders:Array<ColliderCache> = [];
    private var collisionList:Array<EntityCollision> = [];
    // PORT-NOTE: C# `ArrayBuffer<EntityCollision>` (PVZEngine.Base) → plain Array.
    private var collisionBuffer:Array<EntityCollision> = [];
}

// PORT-NOTE: C# nested struct `ColliderCache : IComparable<ColliderCache>` → module class.
private class ColliderCache {
    public function new(collider:Collider, self:Entity, colliderEntityID:Int64) {
        var prevPos = self.PreviousPosition;
        this.collider = collider;
        sqrDistance = (collider.attachedRigidbody.position - prevPos).sqrMagnitude;
        colliderID = colliderEntityID;
    }
    public function CompareTo(other:ColliderCache):Int {
        var value = sqrDistance < other.sqrDistance ? -1 : (sqrDistance > other.sqrDistance ? 1 : 0);
        if (value != 0)
            return value;
        if (colliderID == other.colliderID) return 0;
        return colliderID < other.colliderID ? -1 : 1;
    }
    public function Equals(other:ColliderCache):Bool {
        return collider == other.collider;
    }
    // PORT-NOTE: Haxe objects have no default hash code; equality is by identity.
    public function GetHashCode():Int {
        return 0;
    }
    public var collider:Collider;
    public var sqrDistance:Float;
    public var colliderID:Int64;
}

@:rtti
class SerializableUnityEntityCollider implements ISerializableCollisionCollider {
    public var name:String;
    public var enabled:Bool;
    public var armorSlot:NamespaceID;
    public var collisionList:Array<Dynamic>;
    public var updateMode:Int;
    public var customSize:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    public var customOffset:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    public var customPivot:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用

    public function new(?fields:{
        name:String, enabled:Bool, armorSlot:NamespaceID, collisionList:Array<Dynamic>,
        updateMode:Int, customSize:Vector3, customOffset:Vector3, customPivot:Vector3
    }) {
        if (fields != null) {
            name = fields.name;
            enabled = fields.enabled;
            armorSlot = fields.armorSlot;
            collisionList = fields.collisionList;
            updateMode = fields.updateMode;
            customSize = fields.customSize;
            customOffset = fields.customOffset;
            customPivot = fields.customPivot;
        }
    }

    public var Name(get, never):String;
    inline function get_Name():String return name;
    public var Enabled(get, never):Bool;
    inline function get_Enabled():Bool return enabled;
    public var ArmorSlot(get, never):NamespaceID;
    inline function get_ArmorSlot():NamespaceID return armorSlot;
    public var Collisions(get, never):Array<Dynamic>;
    inline function get_Collisions():Array<Dynamic> return collisionList;
    public var UpdateMode(get, never):Int;
    inline function get_UpdateMode():Int return updateMode;
    public var CustomSize(get, never):Vector3;
    inline function get_CustomSize():Vector3 return customSize;
    public var CustomOffset(get, never):Vector3;
    inline function get_CustomOffset():Vector3 return customOffset;
    public var CustomPivot(get, never):Vector3;
    inline function get_CustomPivot():Vector3 return customPivot;
}

// PORT-NOTE: `ColliderUpdateMode` belongs to PVZEngine; declared as an abstract here so that
// the update mode round-trips through the serializable form as an int.
enum abstract ColliderUpdateMode(Int) {
    var None = 0;
    var Main = 1;
    var Custom = 2;
}

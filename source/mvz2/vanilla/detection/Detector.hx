// Ported from: Assets/Scripts/Vanilla/Frameworks/Detection/Detector.cs
package mvz2.vanilla.detection;

import mvz2logic.Global;
import mvz2logic.level.LevelPositions;
import mvz2.vanilla.entities.VanillaEntityProps;
import pvzengine.NamespaceID;
import pvzengine.base.ArrayBuffer;
import pvzengine.collisions.EntityCollisionHelper;
import pvzengine.collisions.FactionTarget;
import pvzengine.collisions.IEntityCollider;
import pvzengine.collisions.level.OverlapParams;
import pvzengine.entities.Entity;
import pvzengine.entities.EngineEntityExt;
import pvzengine.entities.EntityDefinition;
import unity.Bounds;
import unity.Vector3;
import unity.UnityObject;

class Detector
{
    public function DetectExists(self:DetectionParams):Bool
    {
        var collider = Detect(self);
        if (collider == null || collider.Entity == null || !unity.UnityObject.exists(collider.Entity))
            return false;
        return true;
    }
    public function Detect(self:DetectionParams):Null<IEntityCollider>
    {
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            return collider;
        }
        return null;
    }
    public function DetectWithTheLeast<T>(self:DetectionParams, keySelector:IEntityCollider->T):Null<IEntityCollider>
    {
        var least:IEntityCollider = null;
        var leastKey:Null<T> = null;
        var hasLeastKey = false;
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            var key = keySelector(collider);
            // C#: Comparer<T>.Default.GetLessOne(collider, ref least, key, ref leastKey)
            if (least == null || (!hasLeastKey && key != null) || CompareLess(key, leastKey))
            {
                least = collider;
                leastKey = key;
                hasLeastKey = true;
            }
        }
        return least;
    }
    public function DetectWithTheMost<T>(self:DetectionParams, keySelector:IEntityCollider->T):Null<IEntityCollider>
    {
        var most:IEntityCollider = null;
        var mostKey:Null<T> = null;
        var hasMostKey = false;
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            var key = keySelector(collider);
            // C#: Comparer<T>.Default.GetGreaterOne(collider, ref most, key, ref mostKey)
            if (most == null || (!hasMostKey && key != null) || CompareGreater(key, mostKey))
            {
                most = collider;
                mostKey = key;
                hasMostKey = true;
            }
        }
        return most;
    }
    // C#: DetectMultiple(DetectionParams self, ICollection<IEntityCollider> results)
    public function DetectMultiple(self:DetectionParams, results:Array<IEntityCollider>):Void
    {
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            results.push(collider);
        }
    }
    // C#: DetectMultiple(DetectionParams self, ArrayBuffer<IEntityCollider> results)
    // PORT-NOTE: Haxe has no method overloading; renamed overload to DetectMultipleIntoBuffer.
    public function DetectMultipleIntoBuffer(self:DetectionParams, results:ArrayBuffer<IEntityCollider>):Void
    {
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            results.Add(collider);
        }
    }
    public function DetectEntityWithTheLeast<T>(self:DetectionParams, keySelector:Entity->T):Null<Entity>
    {
        var least:Entity = null;
        var leastKey:Null<T> = null;
        var hasLeastKey = false;
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            var entity = collider.Entity;
            var key = keySelector(entity);
            if (least == null || (!hasLeastKey && key != null) || CompareLess(key, leastKey))
            {
                least = entity;
                leastKey = key;
                hasLeastKey = true;
            }
        }
        return least;
    }
    public function DetectEntityWithTheMost<T>(self:DetectionParams, keySelector:Entity->T):Null<Entity>
    {
        var most:Entity = null;
        var mostKey:Null<T> = null;
        var hasMostKey = false;
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            var entity = collider.Entity;
            var key = keySelector(entity);
            if (most == null || (!hasMostKey && key != null) || CompareGreater(key, mostKey))
            {
                most = entity;
                mostKey = key;
                hasMostKey = true;
            }
        }
        return most;
    }
    public function DetectEntities(self:DetectionParams, results:Array<Entity>):Void
    {
        entityBuffer = [];
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            var entity = collider.Entity;
            if (entityBuffer.indexOf(entity) >= 0)
                continue;
            entityBuffer.push(entity);
            results.push(entity);
        }
    }
    public function DetectEntityCount(self:DetectionParams):Int
    {
        entityBuffer = [];
        var count = 0;
        for (collider in DetectColliders(self))
        {
            if (!ValidateCollider(self, collider))
                continue;
            var entity = collider.Entity;
            if (entityBuffer.indexOf(entity) >= 0)
                continue;
            entityBuffer.push(entity);
            count++;
        }
        return count;
    }
    public function ValidateTarget(self:DetectionParams, target:Entity):Bool
    {
        if (target == null)
            return false;
        if (self.entity == target && !includeSelf)
            return false;
        if (target.IsDead)
            return false;
        // PORT-NOTE: C# 的 target.IsFactionTarget(int, FactionTarget) 扩展重载在移植层更名为 IsFactionTargetFaction。
        if (!EngineEntityExt.IsFactionTargetFaction(target, self.faction, factionTarget))
            return false;
        if (!canDetectInvisible && VanillaEntityProps.IsInvisible(target))
            return false;
        return true;
    }
    // abstract
    function GetDetectionBounds(self:Entity):Bounds
    {
        throw "abstract";
    }
    function ValidateCollider(param:DetectionParams, collider:IEntityCollider):Bool
    {
        if (!ValidateTarget(param, collider.Entity))
            return false;
        return true;
    }
    function TargetInLawn(target:Entity):Bool
    {
        return TargetInLawnX(target.Position.x);
    }
    function TargetInLawnX(x:Float):Bool
    {
        return x > LevelPositions.GetAttackBorderX(false) && x < LevelPositions.GetAttackBorderX(true);
    }
    function GetEntityDefinition(entityID:Null<NamespaceID>):Null<EntityDefinition>
    {
        if (!NamespaceID.IsValid(entityID))
            return null;
        if (!definitionCaches.exists(entityID))
        {
            var cache = Global.Game.GetEntityDefinition(entityID);
            if (cache != null)
            {
                definitionCaches.set(entityID, cache);
            }
        }
        return definitionCaches.get(entityID);
    }
    function GetProjectileSize(entity:Entity, defaultValue:Vector3):Vector3
    {
        return GetEntitySize(VanillaEntityProps.GetProjectileID(entity), defaultValue);
    }
    function GetEntitySize(projectileID:Null<NamespaceID>, defaultValue:Vector3):Vector3
    {
        if (NamespaceID.IsValid(projectileID))
        {
            var projectileDef = GetEntityDefinition(projectileID);
            if (projectileDef != null)
                return projectileDef.GetSize();
        }
        return defaultValue;
    }
    private function DetectColliders(param:DetectionParams):Array<IEntityCollider>
    {
        var bounds = GetDetectionBounds(param.entity);

        var hostileMask = factionTarget == FactionTarget.Friendly ? 0 : mask;
        var friendlyMask = factionTarget == FactionTarget.Hostile ? 0 : mask;
        resultsBuffer = [];

        var overlapParam = new OverlapParams(param.faction, hostileMask, friendlyMask, includeOverlapDisabled);
        param.entity.Level.OverlapBoxNonAlloc(bounds.center, bounds.size, overlapParam, resultsBuffer);
        return resultsBuffer;
    }
    public var mask:Int = EntityCollisionHelper.MASK_VULNERABLE;
    // PORT-NOTE: C# 为 public FactionTarget factionTarget（枚举 abstract 在 Haxe 中不会隐式转换为 Int）。
    public var factionTarget:FactionTarget = FactionTarget.Hostile;
    public var canDetectInvisible:Bool = false;
    public var includeSelf:Bool = false;
    public var includeOverlapDisabled:Bool = false;
    private var resultsBuffer:Array<IEntityCollider> = [];
    private var entityBuffer:Array<Entity> = [];
    private var definitionCaches:Map<NamespaceID, EntityDefinition> = new Map();

    // C#: Comparer<T>.Default.GetLessOne / GetGreaterOne (Tools.Mathematics extension)
    private static function CompareLess<T>(a:Null<T>, b:Null<T>):Bool
    {
        if (a == null)
            return b != null;
        if (b == null)
            return false;
        return Reflect.compare(a, b) < 0;
    }
    private static function CompareGreater<T>(a:Null<T>, b:Null<T>):Bool
    {
        if (a == null)
            return false;
        if (b == null)
            return true;
        return Reflect.compare(a, b) > 0;
    }
}

// C#: public struct DetectionParams
class DetectionParams
{
    public var entity:Entity;
    public var faction:Int;

    public function new(?entity:Entity, ?faction:Int)
    {
        this.entity = entity;
        this.faction = faction;
    }

    @:from
    public static function fromEntity(entity:Entity):DetectionParams
    {
        var param = new DetectionParams();
        param.entity = entity;
        param.faction = entity.GetFaction();
        return param;
    }
}

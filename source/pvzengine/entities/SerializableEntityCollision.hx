// Ported from: Assets/Scripts/Engine/Level/Collisions/EntityCollision.cs
// PORT-NOTE: 该类型在 C# 中与 EntityCollision / EntityColliderReference 同处一个文件。
// 同级引擎代码（pvzengine/entities/SerializableEntityCollider.hx 的
// `public var collisionList:Array<SerializableEntityCollision>;`）以短类型名在同一包内引用它，
// 而 Haxe 中另一模块的次级类型无法这样解析，故将 SerializableEntityCollision 拆为独立模块。
package pvzengine.entities;

import unity.Vector3;

// [Serializable]
@:rtti
class SerializableEntityCollision
{
    // PORT-NOTE: C# 为字段声明 + 对象初始化器；这里与工程内其它 Serializable* 类一致，
    // 用可选的匿名结构参数构造函数（同时支持无参构造）。
    public function new(?fields:{collider:EntityColliderReference, otherCollider:EntityColliderReference, seperation:Vector3})
    {
        if (fields != null)
        {
            collider = fields.collider;
            otherCollider = fields.otherCollider;
            seperation = fields.seperation;
        }
    }
    public var collider:EntityColliderReference;
    public var otherCollider:EntityColliderReference;
    public var seperation:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
}

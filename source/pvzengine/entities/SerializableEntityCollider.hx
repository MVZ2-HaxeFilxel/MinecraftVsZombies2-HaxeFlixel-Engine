// Ported from: Assets/Scripts/Engine/Level/Entities/Hitboxes/SerializableEntityCollider.cs
package pvzengine.entities;

import pvzengine.NamespaceID;
import pvzengine.collisions.ISerializableCollisionCollider;
import unity.Vector3;

// PORT-NOTE: C# 的显式接口实现（`string? ISerializableCollisionCollider.Name => name;` 等）在 Haxe 中
//   改为普通的只读属性 + getter；公开字段名保持与 C# 一致（name / collisionList / ...）。
@:rtti
class SerializableEntityCollider implements ISerializableCollisionCollider
{
	public function new() {}

	public var name:String;
	public var enabled:Bool;
	public var armorSlot:Null<NamespaceID>;
	public var collisionList:Array<SerializableEntityCollision>;
	public var updateMode:Int;
	public var customSize:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var customOffset:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var customPivot:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用

	public var Name(get, never):String;
	function get_Name():String
	{
		return name;
	}
	public var Enabled(get, never):Bool;
	function get_Enabled():Bool
	{
		return enabled;
	}
	public var ArmorSlot(get, never):Null<NamespaceID>;
	function get_ArmorSlot():Null<NamespaceID>
	{
		return armorSlot;
	}
	// PORT-NOTE: 接口中 Collisions 声明为 Dynamic（见 ISerializableCollisionCollider 的 PORT-NOTE）。
	public var Collisions(get, never):Dynamic;
	function get_Collisions():Dynamic
	{
		return collisionList;
	}
	public var UpdateMode(get, never):Int;
	function get_UpdateMode():Int
	{
		return updateMode;
	}
	public var CustomSize(get, never):Vector3;
	function get_CustomSize():Vector3
	{
		return customSize;
	}
	public var CustomOffset(get, never):Vector3;
	function get_CustomOffset():Vector3
	{
		return customOffset;
	}
	public var CustomPivot(get, never):Vector3;
	function get_CustomPivot():Vector3
	{
		return customPivot;
	}
}

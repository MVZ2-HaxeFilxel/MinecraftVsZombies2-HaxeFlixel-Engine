// Ported from: Assets/Scripts/View/Models/Entity/EntityModel.cs
package mvz2.models;
import mvz2.models.Model.SerializableModelData;  // IMPORTAUTO

import unity.Collider2D;
import unity.Color;
import unity.Vector2;
import unity.rendering.SortingGroup;
using mvz2logic.entities.LogicEntityProps;  // EXTUSING

// @:DisallowMultipleComponent
// @:RequireComponent(SortingGroup)
class EntityModel extends Model
{
	public function CancelSortAtRoot():Void
	{
		RendererGroup.CancelSortAtRoot();
	}
	public function SetLightVisible(visible:Bool):Void
	{
		if (bone != null)
			bone.SetLightVisible(visible);
	}
	public function SetLightColor(color:Color):Void
	{
		if (bone != null)
			bone.SetLightColor(color);
	}
	public function SetLightRange(range:Vector2):Void
	{
		if (bone != null)
			bone.SetLightRange(range);
	}
	public function SetColliderActive(active:Bool):Void
	{
		if (modelCollider != null)
		{
			modelCollider.enabled = active;
		}
	}
	override public function UpdateElements():Void
	{
		super.UpdateElements();
		var colliderCandidates = Lambda.filter(GetComponentsInChildren(Collider2D, true), g -> ModelHelper.IsDirectChild(g, this));
		var newCollider = colliderCandidates.length > 0 ? colliderCandidates[0] : null;
		if (newCollider != modelCollider)
		{
			modelCollider = newCollider;
		}
		var newSortingGroup = GetComponent(SortingGroup);
		if (newSortingGroup != sortingGroup)
		{
			sortingGroup = newSortingGroup;
		}
		var newGroup = GetComponent(ModelGroupEntity);
		if (newGroup != group)
		{
			group = newGroup;
		}
		var boneCandidates = Lambda.filter(GetComponentsInChildren(ModelBone, true), g -> ModelHelper.IsDirectChild(g, this) && g.gameObject != gameObject);
		var newBone = boneCandidates.length > 0 ? boneCandidates[0] : null;
		if (newBone != bone)
		{
			bone = newBone;
		}
	}
	override function CreateSerializable():SerializableModelData
	{
		var serializable = new SerializableSpriteModelData();
		return serializable;
	}
	public var SortingLayerID(get, set):Int;
	function get_SortingLayerID():Int
	{
		return sortingGroup.sortingLayerID;
	}
	function set_SortingLayerID(value:Int):Int
	{
		sortingGroup.sortingLayerID = value;
		RendererGroup.SetSortingLayerID(value);
		return value;
	}
	public var SortingLayerName(get, set):String;
	function get_SortingLayerName():String
	{
		return sortingGroup.sortingLayerName;
	}
	function set_SortingLayerName(value:String):String
	{
		sortingGroup.sortingLayerName = value;
		RendererGroup.SetSortingLayerName(value);
		return value;
	}
	public var SortingOrder(get, set):Int;
	function get_SortingOrder():Int
	{
		return sortingGroup.sortingOrder;
	}
	function set_SortingOrder(value:Int):Int
	{
		sortingGroup.sortingOrder = value;
		RendererGroup.SetSortingOrder(value);
		return value;
	}
	override public function get_GraphicGroup():ModelGroup
	{
		return RendererGroup;
	}
	public var Collider(get, never):Collider2D;
	function get_Collider():Collider2D return modelCollider;
	public var RendererGroup(get, never):ModelGroupEntity;
	function get_RendererGroup():ModelGroupEntity return group;
	// [Header("Entity")]
	@:serializeField
	private var sortingGroup:SortingGroup;
	@:serializeField
	private var modelCollider:Collider2D;
	@:serializeField
	private var group:ModelGroupEntity;
	@:serializeField
	private var bone:ModelBone;
}

@:rtti
class SerializableSpriteModelData extends SerializableModelData
{
	public function new()
	{
		super();
	}
}

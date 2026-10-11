// Ported from: Assets/Scripts/View/Models/Entity/ModelGroupEntity.cs
package mvz2.models;
import mvz2.models.ModelGroup.SerializableModelGroup;  // IMPORTAUTO
import mvz2.models.ModelGroupRenderer.SerializableModelGroupRenderer;  // IMPORTAUTO

import unity.UnityObject;
import unity.rendering.SortingGroup;

class ModelGroupEntity extends ModelGroupRenderer
{
	// #region 排序
	public function CancelSortAtRoot():Void
	{
		for (element in subSortingGroups)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			var group = element.Group;
			if (!UnityObject.exists(group))
				continue;
			group.sortAtRoot = false;
		}
	}
	public function SetSortingLayerID(value:Int):Void
	{
		for (element in subSortingGroups)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			var group = element.Group;
			if (!UnityObject.exists(group) || !group.sortAtRoot)
				continue;
			group.sortingLayerID = value;
		}
	}
	public function SetSortingLayerName(value:String):Void
	{
		for (element in subSortingGroups)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			var group = element.Group;
			if (!UnityObject.exists(group) || !group.sortAtRoot)
				continue;
			group.sortingLayerName = value;
		}
	}
	public function SetSortingOrder(value:Int):Void
	{
		for (element in subSortingGroups)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			var group = element.Group;
			if (!UnityObject.exists(group) || !group.sortAtRoot)
				continue;
			group.sortingOrder = value;
		}
	}
	// #endregion

	// #region 元素管理
	override public function UpdateElements():Void
	{
		super.UpdateElements();
		var newGroups = Lambda.filter(GetComponentsInChildren(SortingGroup, true), g -> ModelHelper.IsDirectChild(g, this) && g.gameObject != gameObject);
		var elements:Array<SortingGroupElement> = [];
		for (r in newGroups)
		{
			var element = r.GetComponent(SortingGroupElement);
			if (element == null)
			{
				element = r.gameObject.AddComponent(SortingGroupElement);
			}
			elements.push(element);
		}
		ModelHelper.ReplaceList(subSortingGroups, elements);
	}
	// #endregion

	// #region 序列化
	override public function ToSerializable():SerializableModelGroup
	{
		var serializable = new SerializableModelGroupEntity();
		SaveToSerializableRenderer(serializable);
		return serializable;
	}
	// #endregion

	// #region 属性字段
	@:serializeField
	private var subSortingGroups:Array<SortingGroupElement> = [];
	// #endregion
}

@:rtti
class SerializableModelGroupEntity extends SerializableModelGroupRenderer
{
	public function new()
	{
		super();
	}
}

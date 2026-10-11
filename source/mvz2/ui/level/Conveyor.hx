// Ported from: Assets/Scripts/View/Level/Blueprints/Conveyor.cs
package mvz2.ui.level;

import mvz2.ui.ElementList;
import unity.RectTransform;
import unity.Transform;
import unity.UnityObject;
import unity.Vector3;
import unity.ui.Shadow;
import unity.ui.LayoutRebuilder;

class Conveyor extends BlueprintSet
{
	public function SetSlotCount(count:Int):Void
	{
		slotCount = count;
		structureList.updateList(count);
		LayoutRebuilder.ForceRebuildLayoutImmediate(cast transform);
	}
	override public function CreateBlueprint():Blueprint
	{
		return blueprints.CreateItem().GetComponent(Blueprint);
	}
	override public function InsertBlueprint(index:Int, blueprint:Blueprint):Void
	{
		if (blueprint == null)
			return;
		blueprints.Insert(index, blueprint.gameObject);
		blueprint.OnPointerInteraction.add(OnBlueprintPointerInteractionCallback);
	}
	override public function RemoveBlueprint(blueprint:Blueprint):Bool
	{
		if (blueprint == null)
			return false;
		if (blueprints.Remove(blueprint.gameObject))
		{
			blueprint.OnPointerInteraction.remove(OnBlueprintPointerInteractionCallback);
			return true;
		}
		return false;
	}
	override public function DestroyBlueprint(blueprint:Blueprint):Bool
	{
		if (blueprint == null)
			return false;
		if (blueprints.DestroyItem(blueprint.gameObject))
		{
			blueprint.OnPointerInteraction.remove(OnBlueprintPointerInteractionCallback);
			return true;
		}
		return false;
	}
	override public function GetBlueprintAt(index:Int):Null<Blueprint>
	{
		return blueprints.getElementAs(index, Blueprint);
	}
	override public function GetBlueprintIndex(value:Blueprint):Int
	{
		return blueprints.indexOf(value.gameObject);
	}
	public function SetBlueprintNormalizedPosition(index:Int, position:Float):Void
	{
		var blueprint = GetBlueprintAt(index);
		if (!UnityObject.exists(blueprint))
			return;
		blueprint.transform.position = Vector3.LerpUnclamped(startPositionAnchor.position, endPositionAnchor.position, position / (slotCount - 1));
	}
	private var slotCount:Int;
	@:serializeField
	private var blueprints:ElementList;
	@:serializeField
	private var structureList:ElementList;
	@:serializeField
	private var startPositionAnchor:Transform;
	@:serializeField
	private var endPositionAnchor:Transform;
}

// Ported from: Assets/Scripts/View/Models/Elements/SortingGroupElement.cs
package mvz2.models;
import mvz2.models.GraphicElement.SerializableGraphicElement;  // IMPORTAUTO

import unity.rendering.SortingGroup;

class SortingGroupElement extends GraphicElement
{
	public var Group(get, never):Null<SortingGroup>;
	function get_Group():Null<SortingGroup>
	{
		if (_group == null)
		{
			_group = GetComponent(SortingGroup);
		}
		return _group;
	}
	override public function ToSerializable():SerializableGraphicElement
	{
		return new SerializableSortinGroupElement();
	}
	private var _group:Null<SortingGroup>;
}

@:rtti
class SerializableSortinGroupElement extends SerializableGraphicElement
{
	public function new()
	{
		super();
	}
}

// Ported from: Assets/Scripts/View/Models/Elements/GraphicElement.cs
package mvz2.models;

// abstract
class GraphicElement extends unity.MonoBehaviour
{
	public function new() { super(); } // CTORFIX
	// abstract
	public function ToSerializable():SerializableGraphicElement
	{
		throw "abstract";
	}
	public function LoadFromSerializable(serializable:SerializableGraphicElement):Void {}
	public var ExcludedInGroup(get, never):Bool;
	function get_ExcludedInGroup():Bool return excludedInGroup;
	@:serializeField
	private var excludedInGroup:Bool;
}

@:rtti
class SerializableGraphicElement
{
	public function new() {}
}

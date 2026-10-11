// Ported from: Assets/Scripts/View/Models/Elements/ImageElement.cs
package mvz2.models;
import mvz2.models.GraphicElement.SerializableGraphicElement;  // IMPORTAUTO

class ImageElement extends GraphicElement
{
	override public function ToSerializable():SerializableGraphicElement
	{
		return new SerializableImageElement();
	}
	public function LoadFromSerializableSerializable(serializable:SerializableImageElement):Void
	{
	}
	public var Image(get, never):Null<unity.ui.Image>;
	function get_Image():Null<unity.ui.Image>
	{
		if (_image == null)
		{
			_image = GetComponent(unity.ui.Image);
		}
		return _image;
	}
	private var _image:Null<unity.ui.Image>;
}

@:rtti
class SerializableImageElement extends SerializableGraphicElement
{
	public function new()
	{
		super();
	}
}

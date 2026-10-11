// Ported from: Assets/Scripts/View/Models/Elements/RendererElement.cs
package mvz2.models;
import mvz2.models.GraphicElement.SerializableGraphicElement;  // IMPORTAUTO

import unity.Color;
import unity.MaterialPropertyBlock;
import unity.Renderer;
import unity.UnityObject;
import unity.Vector4;

class RendererElement extends GraphicElement
{
	public function SetInt(name:String, value:Int):Void
	{
		intCache.set(name, value);
	}
	public function SetFloat(name:String, value:Float):Void
	{
		floatCache.set(name, value);
	}
	public function SetColor(name:String, value:Color):Void
	{
		colorCache.set(name, value);
	}
	public function SetVector(name:String, value:Vector4):Void
	{
		vectorCache.set(name, value);
	}
	public function ApplyShaderProperties():Void
	{
		var renderer = Renderer;
		if (!UnityObject.exists(renderer))
			return;
		var block = PropertyBlock;
		renderer.GetPropertyBlock(block);
		for (p in intCache.keys())
		{
			var key = p;
			var value = intCache.get(p);
			intProperties.set(key, value);
			block.SetInt(key, value);
		}
		for (p in floatCache.keys())
		{
			var key = p;
			var value = floatCache.get(p);
			floatProperties.set(key, value);
			block.SetFloat(key, value);
		}
		for (p in colorCache.keys())
		{
			var key = p;
			var value = colorCache.get(p);
			colorProperties.set(key, value);
			block.SetColor(key, value);
		}
		for (p in vectorCache.keys())
		{
			var key = p;
			var value = vectorCache.get(p);
			vectorProperties.set(key, value);
			block.SetVector(key, value);
		}
		intCache.clear();
		floatCache.clear();
		colorCache.clear();
		vectorCache.clear();
		renderer.SetPropertyBlock(block);
	}

	override public function ToSerializable():SerializableGraphicElement
	{
		var element = new SerializableRendererElement();
		element.colorProperties = colorProperties.copy();
		element.intProperties = intProperties.copy();
		element.floatProperties = floatProperties.copy();
		element.vectorProperties = vectorProperties.copy();
		return element;
	}
	override public function LoadFromSerializable(serializable:SerializableGraphicElement):Void
	{
		if (!Std.isOfType(serializable, SerializableRendererElement))
			return;
		var rendererElement:SerializableRendererElement = cast serializable;
		intProperties.clear();
		floatProperties.clear();
		colorProperties.clear();
		vectorProperties.clear();
		if (rendererElement.intProperties != null)
		{
			for (prop in rendererElement.intProperties.keys())
				intProperties.set(prop, rendererElement.intProperties.get(prop));
		}
		if (rendererElement.floatProperties != null)
		{
			for (prop in rendererElement.floatProperties.keys())
				floatProperties.set(prop, rendererElement.floatProperties.get(prop));
		}
		if (rendererElement.colorProperties != null)
		{
			for (prop in rendererElement.colorProperties.keys())
				colorProperties.set(prop, rendererElement.colorProperties.get(prop));
		}
		if (rendererElement.vectorProperties != null)
		{
			for (prop in rendererElement.vectorProperties.keys())
				vectorProperties.set(prop, rendererElement.vectorProperties.get(prop));
		}
		var renderer = Renderer;
		if (UnityObject.exists(renderer))
		{
			var block = PropertyBlock;
			renderer.GetPropertyBlock(block);
			for (p in intProperties.keys())
				block.SetInt(p, intProperties.get(p));
			for (p in floatProperties.keys())
				block.SetFloat(p, floatProperties.get(p));
			for (p in colorProperties.keys())
				block.SetColor(p, colorProperties.get(p));
			for (p in vectorProperties.keys())
				block.SetVector(p, vectorProperties.get(p));
			renderer.SetPropertyBlock(block);
		}
	}
	public var PropertyBlock(get, never):MaterialPropertyBlock;
	function get_PropertyBlock():MaterialPropertyBlock
	{
		if (propertyBlock == null)
		{
			propertyBlock = new MaterialPropertyBlock();
		}
		return propertyBlock;
	}
	public var Renderer(get, never):Null<Renderer>;
	function get_Renderer():Null<Renderer>
	{
		if (_renderer == null)
		{
			_renderer = GetComponent(unity.Renderer);
		}
		return _renderer;
	}
	private var propertyBlock:MaterialPropertyBlock;
	private var intProperties:Map<String, Int> = [];
	private var floatProperties:Map<String, Float> = [];
	private var colorProperties:Map<String, Color> = [];
	private var vectorProperties:Map<String, Vector4> = [];
	private var intCache:Map<String, Int> = [];
	private var floatCache:Map<String, Float> = [];
	private var colorCache:Map<String, Color> = [];
	private var vectorCache:Map<String, Vector4> = [];
	private var _renderer:Null<Renderer>;
}

@:rtti
class SerializableRendererElement extends SerializableGraphicElement
{
	public var floatProperties:Map<String, Float>;
	public var intProperties:Map<String, Int>;
	public var colorProperties:Map<String, Color>;
	public var vectorProperties:Map<String, Vector4>;

	public function new()
	{
		super();
	}
}

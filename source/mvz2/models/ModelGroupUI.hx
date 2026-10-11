// Ported from: Assets/Scripts/View/Models/UI/ModelGroupUI.cs
package mvz2.models;
import mvz2.models.ModelGroup.SerializableModelGroup;  // IMPORTAUTO

import unity.Color;
import unity.Vector4;
import unity.Canvas; // PORT-NOTE: UnityEngine.Canvas（非 UI 包）
import unity.ui.Image;
import unity.ui.Mask;

// @:RequireComponent(Canvas)
class ModelGroupUI extends ModelGroup
{
	// #region 着色器
	override public function SetShaderInt(name:String, value:Int):Void
	{
	}
	override public function SetShaderFloat(name:String, alpha:Float):Void
	{
	}
	override public function SetShaderColor(name:String, color:Color):Void
	{
	}
	override public function SetShaderVector(name:String, color:Vector4):Void
	{
	}
	override public function ApplyShaderProperties():Void
	{
	}
	// #endregion

	// #region 元素管理
	override public function AddElement(element:GraphicElement):Void
	{
		if (!Std.isOfType(element, ImageElement))
			throw 'Wrong model group element type. (element)'; // ArgumentException("Wrong model group element type.", nameof(element))
		images.push(cast element);
	}
	override public function UpdateElements():Void
	{
		super.UpdateElements();
		var newImages = Lambda.filter(GetComponentsInChildren(Image, true), g -> ModelHelper.IsDirectChild(g, this) && g.GetComponent(Mask) == null);
		var elements:Array<ImageElement> = [];
		for (r in newImages)
		{
			var element = r.GetComponent(ImageElement);
			if (element == null)
			{
				element = r.gameObject.AddComponent(ImageElement);
			}
			elements.push(element);
		}
		ModelHelper.ReplaceList(images, elements);
	}
	// #endregion

	// #region 序列化
	override public function ToSerializable():SerializableModelGroup
	{
		var ui = new SerializableModelGroupUI();
		SaveToSerializableGroup(ui);
		return ui;
	}
	// #endregion

	// #region 属性字段
	@:serializeField
	private var images:Array<ImageElement> = [];
	// #endregion
}

@:rtti
class SerializableModelGroupUI extends SerializableModelGroup
{
	public function new()
	{
		super();
	}
}

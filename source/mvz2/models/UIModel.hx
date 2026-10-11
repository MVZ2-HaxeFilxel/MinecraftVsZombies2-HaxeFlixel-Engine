// Ported from: Assets/Scripts/View/Models/UI/UIModel.cs
package mvz2.models;
import mvz2.models.Model.SerializableModelData;  // SUBIMPORT

import mvz2.models.Model;

import pvzengine.NamespaceID;
import unity.Camera;
import unity.Canvas; // PORT-NOTE: UnityEngine.Canvas（非 UI 包）

// @:DisallowMultipleComponent
class UIModel extends Model
{
	override public function Init(id:NamespaceID, camera:Camera, ?seed:Int = 0):Void
	{
		super.Init(id, camera, seed);
		canvas.worldCamera = camera;
	}
	override public function UpdateElements():Void
	{
		super.UpdateElements();
		var newCanvas = GetComponent(Canvas);
		if (newCanvas != canvas)
		{
			canvas = newCanvas;
		}
		var newGroup = GetComponent(ModelGroupUI);
		if (newGroup != group)
		{
			group = newGroup;
		}
	}
	override function CreateSerializable():SerializableModelData
	{
		var serializable = new SerializableUIModelData();
		return serializable;
	}
	override public function get_GraphicGroup():ModelGroup
	{
		return ImageGroup;
	}
	public var ImageGroup(get, never):ModelGroupUI;
	function get_ImageGroup():ModelGroupUI return group;
	// [Header("Image")]
	@:serializeField
	private var canvas:Canvas;
	@:serializeField
	private var group:ModelGroupUI;
}

@:rtti
class SerializableUIModelData extends SerializableModelData
{
	public function new()
	{
		super();
	}
}

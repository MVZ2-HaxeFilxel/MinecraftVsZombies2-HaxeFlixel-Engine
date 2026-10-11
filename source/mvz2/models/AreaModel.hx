// Ported from: Assets/Scripts/View/Models/Area/AreaModel.cs
package mvz2.models;
import mvz2.models.Model.SerializableModelData;  // IMPORTAUTO
import mvz2.models.ModelUpdateGroup.SerializableModelUpdateGroup;  // IMPORTAUTO

import unity.UnityObject;

// @:DisallowMultipleComponent
class AreaModel extends Model
{
	public function SetPreset(name:Null<String>):Void
	{
		var hasActive = false;
		for (preset in presets)
		{
			var active = preset.GetName() == name;
			if (active)
			{
				hasActive = true;
			}
			preset.SetActive(active);
		}
		if (!hasActive)
		{
			var preset = presets.length > 0 ? presets[0] : null;
			if (preset != null)
			{
				preset.SetActive(true);
			}
		}
		currentPreset = name;
	}
	override public function UpdateElements():Void
	{
		super.UpdateElements();
		var newGroup = GetComponent(ModelGroupArea);
		if (newGroup != group)
		{
			group = newGroup;
		}
		var newPresets = Lambda.filter(GetComponentsInChildren(AreaModelPreset, true), g -> ModelHelper.IsDirectChild(g, this) && g.gameObject != gameObject);
		ModelHelper.ReplaceList(presets, newPresets);
	}
	// #region 序列化
	override function CreateSerializable():SerializableModelData
	{
		var serializable = new SerializableAreaModelData();
		serializable.currentPreset = currentPreset;
		return serializable;
	}
	override function LoadSerializable(serializable:SerializableModelData):Void
	{
		super.LoadSerializable(serializable);
		if (!Std.isOfType(serializable, SerializableAreaModelData))
			return;
		var areaModel:SerializableAreaModelData = cast serializable;
		SetPreset(areaModel.currentPreset);
	}
	// #endregion

	override public function get_GraphicGroup():ModelGroup
	{
		return RendererGroup;
	}
	public var RendererGroup(get, never):ModelGroupArea;
	function get_RendererGroup():ModelGroupArea return group;
	private var currentPreset:Null<String>;
	// [Header("Area")]
	@:serializeField
	private var group:ModelGroupArea;
	@:serializeField
	private var presets:Array<AreaModelPreset> = [];
}

// [Serializable]
@:rtti
class SerializableAreaModelData extends SerializableModelData
{
	public var currentPreset:Null<String>;
	// [Obsolete]
	public var updateGroup:Null<SerializableModelUpdateGroup>;

	public function new()
	{
		super();
	}
}

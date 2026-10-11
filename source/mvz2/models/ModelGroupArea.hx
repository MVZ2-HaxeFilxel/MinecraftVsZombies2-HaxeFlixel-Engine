// Ported from: Assets/Scripts/View/Models/Area/ModelGroupArea.cs
package mvz2.models;
import mvz2.models.ModelGroup.SerializableModelGroup;  // IMPORTAUTO
import mvz2.models.ModelGroupRenderer.SerializableModelGroupRenderer;  // IMPORTAUTO

class ModelGroupArea extends ModelGroupRenderer
{
	// #region 序列化
	override public function ToSerializable():SerializableModelGroup
	{
		var serializable = new SerializableModelGroupArea();
		SaveToSerializableRenderer(serializable);
		return serializable;
	}
	// #endregion
}

@:rtti
class SerializableModelGroupArea extends SerializableModelGroupRenderer
{
	public function new()
	{
		super();
	}
}

// Ported from: Assets/Scripts/MVZ2/Level/Components/BlueprintComponent.cs
package mvz2.level.components;

import mvz2.level.LevelController;
import mvz2logic.level.components.ComponentInterfaces.IBlueprintComponent;
import pvzengine.NamespaceID;
import pvzengine.level.ISerializableLevelComponent;
import pvzengine.level.LevelEngine;
import mvz2.level.BlueprintController;

class BlueprintComponent extends MVZ2Component implements IBlueprintComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, ID, controller);
	}
	// #region 传送带
	public function SetConveyorMode(mode:Bool):Void
	{
		isConveyorMode = mode;
		Controller.BlueprintController.SetUIConveyorMode(mode);
	}
	public function IsConveyorMode():Bool
	{
		return isConveyorMode;
	}
	// #endregion

	override public function ToSerializable():ISerializableLevelComponent
	{
		var comp = new SerializableBlueprintComponent();
		comp.isConveyorMode = isConveyorMode;
		return comp;
	}
	override public function InitFromSerializable(seri:ISerializableLevelComponent):Void
	{
		super.InitFromSerializable(seri);
		if (!Std.isOfType(seri, SerializableBlueprintComponent))
			return;
		var comp:SerializableBlueprintComponent = cast seri;
		SetConveyorMode(comp.isConveyorMode);
	}

	private var isConveyorMode:Bool;
	public static var ID:NamespaceID = new NamespaceID("mvz2", "blueprints");
}

@:rtti
class SerializableBlueprintComponent implements ISerializableLevelComponent
{
	public var isConveyorMode:Bool;
	public function new() {}
}

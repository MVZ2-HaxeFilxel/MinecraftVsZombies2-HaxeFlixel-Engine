// Ported from: Assets/Scripts/MVZ2/Level/Components/ArtifactComponent.cs
package mvz2.level.components;

import mvz2.level.LevelController;
import mvz2logic.Global;
import mvz2logic.artifacts.Artifact;
import mvz2logic.artifacts.ArtifactDefinition;
import mvz2logic.artifacts.ArtifactList;
import mvz2logic.artifacts.SerializableArtifactList;
import mvz2logic.level.components.ComponentInterfaces.IArtifactComponent;
import pvzengine.NamespaceID;
import pvzengine.level.ISerializableLevelComponent;
import pvzengine.level.LevelEngine;
import unity.Sprite;
import unity.Debug;
import pvzengine.base.Definition;
import Main;
// PORT-NOTE: C# 的扩展方法（this 参数形式）在 Haxe 中需显式 using 才能以 `obj.Method()` 调用。
using mvz2logic.artifacts.LogicArtifactProps;      // GetSpriteReference / GetDisplayText / GetNumber / IsInactive / GetGlowing

class ArtifactComponent extends MVZ2Component implements IArtifactComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, componentID, controller);
		artifacts = new ArtifactList(level, ARTIFACT_COUNT);
		// PORT-NOTE: C# 的 event Action<int> OnArtifactHighlighted 在 Haxe 侧是 Array<Int->Void>。
		artifacts.OnArtifactHighlighted.push(OnArtifactHighlighted);
	}
	override public function OnStart():Void
	{
		super.OnStart();
		UpdateUIArtifacts();
	}
	public function SetSlotCount(count:Int):Void
	{
		artifacts.SetSlotCount(count);
		var uiPreset = Controller.GetUIPreset();
		uiPreset.SetArtifactCount(count);
	}
	public function GetSlotCount():Int
	{
		return artifacts.GetSlotCount();
	}
	public function ReplaceArtifacts(artifactDef:Array<ArtifactDefinition>):Void
	{
		artifacts.ReplaceArtifacts(artifactDef);
	}
	public function ReplaceArtifact(slot:Int, artifactDef:ArtifactDefinition):Void
	{
		artifacts.ReplaceArtifact(slot, artifactDef);
	}
	public function SetArtifact(slot:Int, artifact:Artifact):Void
	{
		artifacts.SetArtifact(slot, artifact);
	}
	public function GetArtifacts():Array<Artifact>
	{
		return artifacts.GetAllArtifacts();
	}
	// TODO-PORT: C# 重载 HasArtifact(ArtifactDefinition artifactDef)，重命名以区分。
	public function HasArtifactDefinition(artifactDef:ArtifactDefinition):Bool
	{
		return artifacts.HasArtifact(artifactDef);
	}

	// TODO-PORT: C# 重载 GetArtifactIndex(ArtifactDefinition artifactDef)，重命名以区分。
	public function GetArtifactIndexByDefinition(artifactDef:ArtifactDefinition):Int
	{
		// PORT-NOTE: C# 的重载 GetArtifactIndex(ArtifactDefinition) 在 Haxe 中为 GetArtifactIndexByDefinition。
		return artifacts.GetArtifactIndexByDefinition(artifactDef);
	}
	public function HasArtifact(artifactID:NamespaceID):Bool
	{
		return artifacts.HasArtifactByID(artifactID);
	}

	// TODO-PORT: C# 还有一个重载 GetArtifactIndex(NamespaceID artifactID)，
	// 因接口中该重载被命名为 GetArtifactIndexByID，此处与其保持一致。
	public function GetArtifactIndexByID(artifactID:NamespaceID):Int
	{
		return artifacts.GetArtifactIndexByID(artifactID);
	}
	public function GetArtifactIndex(artifact:Artifact):Int
	{
		return artifacts.GetArtifactIndex(artifact);
	}
	public function GetArtifactAt(index:Int):Artifact
	{
		return artifacts.GetArtifactAt(index);
	}



	override public function Update():Void
	{
		super.Update();
		artifacts.Update();
	}
	override public function UpdateFrame(deltaTime:Float, simulationSpeed:Float):Void
	{
		super.UpdateFrame(deltaTime, simulationSpeed);
		UpdateUIArtifacts();
	}
	override public function ToSerializable():ISerializableLevelComponent
	{
		var comp = new SerializableArtifactComponent();
		comp.artifacts = artifacts.ToSerializable();
		return comp;
	}
	override public function InitFromSerializable(seri:ISerializableLevelComponent):Void
	{
		if (!Std.isOfType(seri, SerializableArtifactComponent))
			return;
		var comp:SerializableArtifactComponent = cast seri;
		artifacts = comp.artifacts != null ? ArtifactList.CreateFromSerializable(comp.artifacts, Level) : new ArtifactList(Level, ARTIFACT_COUNT);
		artifacts.OnArtifactHighlighted.push(OnArtifactHighlighted);
		var uiPreset = Controller.GetUIPreset();
		uiPreset.SetArtifactCount(artifacts.GetSlotCount());
		UpdateUIArtifacts();
	}
	override public function LoadFromSerializable(seri:ISerializableLevelComponent):Void
	{
		if (!Std.isOfType(seri, SerializableArtifactComponent))
			return;
		var comp:SerializableArtifactComponent = cast seri;
		if (comp.artifacts == null)
			return;
		artifacts.LoadFromSerializable(comp.artifacts);
	}
	private function UpdateUIArtifacts():Void
	{
		var uiPreset = Controller.GetUIPreset();
		var count = artifacts.GetSlotCount();
		for (i in 0...count)
		{
			var artifact = artifacts.GetArtifactAt(i);
			var icon:Sprite = null;
			var text = "";
			var grayscale = false;
			var glowing = false;
			if (artifact != null)
			{
				icon = Main.GetFinalSpriteFromRef(artifact.Definition.GetSpriteReference());
				var displayText = artifact.GetDisplayText();
				if (displayText != null && displayText != "")
				{
					text = displayText;
				}
				else
				{
					var number = artifact.GetNumber();
					text = number < 0 ? "" : Std.string(number);
				}
				grayscale = artifact.IsInactive();
				glowing = artifact.GetGlowing();
			}
			uiPreset.SetArtifactIcon(i, icon);
			uiPreset.SetArtifactNumber(i, text);
			uiPreset.SetArtifactGrayscale(i, grayscale);
			uiPreset.SetArtifactGlowing(i, glowing);
		}
	}
	private function OnArtifactHighlighted(index:Int):Void
	{
		var uiPreset = Controller.GetUIPreset();
		uiPreset.HighlightArtifact(index);
	}
	private var artifacts:ArtifactList;
	public static inline var ARTIFACT_COUNT:Int = 3;
	// PORT-NOTE: C# 的 static readonly 字段是首次使用时才初始化；hxcpp 会在 main() 之前执行全部静态初始化
	// （__boot_all()），那时 Global.Game / MainManager.Instance 仍为 null，直接求值会段错误。
	// 此处改为惰性 getter（结果缓存一次，等价于 C# 的 readonly static），还原 C# 语义。
	public static var componentID(get, never):NamespaceID;
	private static var _componentID:NamespaceID;
	static function get_componentID():NamespaceID
	{
		if (_componentID == null) _componentID = new NamespaceID(Global.BuiltinNamespace, "artifact");
		return _componentID;
	}
}

@:rtti
class SerializableArtifactComponent implements ISerializableLevelComponent
{
	public var artifacts:SerializableArtifactList;
	public function new() {}
}

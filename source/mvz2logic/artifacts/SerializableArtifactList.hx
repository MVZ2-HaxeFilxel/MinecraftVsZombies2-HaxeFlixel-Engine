// Ported from: Assets/Scripts/Logic/Artifacts/SerializableArtifactList.cs
package mvz2logic.artifacts;

// [Serializable]
@:rtti
class SerializableArtifactList
{
	public function new() {}
	public var artifacts:Null<Array<Null<SerializableArtifact>>>;
}

// Ported from: Assets/Scripts/Logic/Artifacts/SerializableArtifact.cs
package mvz2logic.artifacts;

import pvzengine.NamespaceID;
import pvzengine.SerializablePropertyDictionary;
import pvzengine.auras.SerializableAuraEffect;
import tools.SerializableRNG;

// [Serializable]
@:rtti
class SerializableArtifact
{
	public function new() {}
	public var definitionID:Null<NamespaceID>;
	public var rng:Null<SerializableRNG>;
	public var propertyDict:Null<SerializablePropertyDictionary>;
	public var auras:Null<Array<Null<SerializableAuraEffect>>>;
}

// Ported from: Assets/Scripts/Logic/Saves/BlueprintSelection.cs
package mvz2logic.saves;

// [Serializable]
@:rtti
class BlueprintSelection
{
	public var blueprints:Array<BlueprintChooseSaveItem>;
	public var artifacts:Array<Null<ArtifactSelectionItem>>;

	public function new(blueprints:Array<BlueprintChooseSaveItem>, artifacts:Array<Null<ArtifactSelectionItem>>)
	{
		this.blueprints = blueprints;
		this.artifacts = artifacts;
	}
}

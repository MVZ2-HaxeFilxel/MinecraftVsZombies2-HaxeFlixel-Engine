// Ported from: Assets/Scripts/Logic/Artifacts/LogicArtifactProps.cs
package mvz2logic.artifacts;

import mvz2logic.conditions.IConditionList;
import mvz2logic.resources.SpriteReference;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import tools.FrameTimer;

@:propertyRegistryRegion(PropertyRegions.artifact)
class LogicArtifactProps
{
	public static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var SPRITE_REFERENCE:PropertyMeta<SpriteReference> = Get("spriteReference");
	public static var NUMBER:PropertyMeta<Int> = Get("number", 0);
	public static var DISPLAY_TEXT:PropertyMeta<String> = Get("display_text");
	public static var INACTIVE:PropertyMeta<Bool> = Get("inactive", false);
	public static var GLOWING:PropertyMeta<Bool> = Get("glowing", false);
	// PORT-NOTE: C# 扩展方法 this ArtifactDefinition definition -> 静态方法
	public static function GetSpriteReference(definition:ArtifactDefinition):Null<SpriteReference>
	{
		return definition.GetProperty(SPRITE_REFERENCE);
	}
	public static function SetSpriteReference(definition:ArtifactDefinition, spriteReference:Null<SpriteReference>):Void
	{
		definition.SetProperty(SPRITE_REFERENCE, spriteReference);
	}
	public static function GetNumber(artifact:Artifact):Int
	{
		return artifact.GetProperty(NUMBER);
	}
	public static function SetNumber(artifact:Artifact, number:Int):Void
	{
		artifact.SetProperty(NUMBER, number);
	}
	public static function GetDisplayText(artifact:Artifact):Null<String>
	{
		return artifact.GetProperty(DISPLAY_TEXT);
	}
	public static function SetDisplayText(artifact:Artifact, value:String):Void
	{
		artifact.SetProperty(DISPLAY_TEXT, value);
	}
	public static function SetInactive(artifact:Artifact, value:Bool):Void
	{
		artifact.SetProperty(INACTIVE, value);
	}
	public static function IsInactive(artifact:Artifact):Bool
	{
		return artifact.GetProperty(INACTIVE);
	}
	public static function SetGlowing(artifact:Artifact, value:Bool):Void
	{
		artifact.SetProperty(GLOWING, value);
	}
	public static function GetGlowing(artifact:Artifact):Bool
	{
		return artifact.GetProperty(GLOWING);
	}
	public static var TRANSFORM_SOURCE:PropertyMeta<NamespaceID> = Get("transformSource");
	public static function SetTransformSource(artifact:Artifact, id:NamespaceID):Void
	{
		artifact.SetProperty(TRANSFORM_SOURCE, id);
	}
	public static function GetTransformSource(artifact:Artifact):Null<NamespaceID>
	{
		return artifact.GetProperty(TRANSFORM_SOURCE);
	}

	// #region 制品名称
	public static var NAME:PropertyMeta<String> = Get("name");
	public static function GetArtifactName(definition:ArtifactDefinition):Null<String>
	{
		return definition.GetProperty(NAME);
	}
	public static function SetArtifactName(definition:ArtifactDefinition, value:String):Void
	{
		definition.SetProperty(NAME, value);
	}
	// #endregion

	// #region 制品工具提示
	public static var TOOLTIP:PropertyMeta<String> = Get("tooltip");
	public static function GetArtifactTooltip(definition:ArtifactDefinition):Null<String>
	{
		return definition.GetProperty(TOOLTIP);
	}
	public static function SetArtifactTooltip(definition:ArtifactDefinition, value:String):Void
	{
		definition.SetProperty(TOOLTIP, value);
	}
	// #endregion

	// #region 制品解锁
	public static var UNLOCK:PropertyMeta<IConditionList> = Get("unlock");
	public static function GetUnlockConditions(definition:ArtifactDefinition):Null<IConditionList>
	{
		return definition.GetProperty(UNLOCK);
	}
	public static function SetUnlockConditions(definition:ArtifactDefinition, value:Null<IConditionList>):Void
	{
		definition.SetProperty(UNLOCK, value);
	}
	// #endregion

	public static var SECOND_TIMER:PropertyMeta<FrameTimer> = Get("second_timer");
	public static function GetSecondTimer(artifact:Artifact):Null<FrameTimer>
	{
		return artifact.GetProperty(SECOND_TIMER);
	}
	public static function SetSecondTimer(artifact:Artifact, value:Null<FrameTimer>):Void
	{
		artifact.SetProperty(SECOND_TIMER, value);
	}
}

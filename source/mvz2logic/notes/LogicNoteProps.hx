// Ported from: Assets/Scripts/Logic/Notes/LogicNoteProps.cs
package mvz2logic.notes;

import mvz2logic.LogicPropertyRegions;
import mvz2logic.resources.SpriteReference;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;

@:propertyRegistryRegion(LogicPropertyRegions.note)
class LogicNoteProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	// #region 笔记贴图
	public static var NOTE_SPRITE:PropertyMeta<SpriteReference> = Get("note_sprite");
	// PORT-NOTE: C# 扩展方法 -> 静态方法
	public static function GetNoteSprite(definition:NoteDefinition):Null<SpriteReference>
	{
		return definition.GetProperty(NOTE_SPRITE);
	}
	// #endregion

	// #region 背景贴图
	public static var NOTE_BACKGROUND:PropertyMeta<SpriteReference> = Get("note_background");
	public static function GetNoteBackground(definition:NoteDefinition):Null<SpriteReference>
	{
		return definition.GetProperty(NOTE_BACKGROUND);
	}
	// #endregion

	// #region 反转贴图
	public static var FLIP_NOTE_SPRITE:PropertyMeta<SpriteReference> = Get("flip_note_sprite");
	public static function GetFlipNoteSprite(definition:NoteDefinition):Null<SpriteReference>
	{
		return definition.GetProperty(FLIP_NOTE_SPRITE);
	}
	// #endregion

	// #region 可翻转
	public static var CAN_FLIP:PropertyMeta<Bool> = Get("can_flip", false);
	public static function CanFlip(definition:NoteDefinition):Bool
	{
		return definition.GetProperty(CAN_FLIP);
	}
	// #endregion

	// #region 开场对话
	public static var START_TALK:PropertyMeta<NamespaceID> = Get("start_talk");
	public static function GetStartTalk(definition:NoteDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(START_TALK);
	}
	// #endregion
}

// Ported from: Assets/Scripts/View/Almanac/BookAlmanacPage.cs
package mvz2.ui.almanac;

import mvz2.ui.almanac.AlmanacDescriptionTag;

import mvz2.ui.almanac.AlmanacTagIcon;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2.ui.ElementList;
import unity.GameObject;
import unity.ui.Shadow;
import unity.ui.ScrollRect;
import unity.tmpro.TextMeshProUGUI;
import mvz2.ui.almanac.AlmanacDescriptionTag.AlmanacDescriptionTagViewData;
import mvz2.ui.almanac.AlmanacTagIcon.AlmanacTagIconViewData;
import unity.ui.LayoutRebuilder;
import flixel.util.FlxSignal;

// abstract
class BookAlmanacPage extends AlmanacPage
{
	public function GetTagIcon(index:Int):Null<AlmanacTagIcon>
	{
		return entryTags.getElementAs(index, AlmanacTagIcon);
	}
	public function GetDescriptionIcon(index:Int):Null<AlmanacTagIcon>
	{
		return descriptionIconUpdater.GetIconContainer(index);
	}
	public function UpdateTagIcons(viewDatas:Array<AlmanacTagIconViewData>):Void
	{
		entryTags.updateList(viewDatas.length,
			function(i:Int, obj:GameObject)
			{
				var tag = obj.GetComponent(AlmanacTagIcon);
				tag.UpdateContainer(viewDatas[i]);
			},
			function(obj:GameObject)
			{
				var tag = obj.GetComponent(AlmanacTagIcon);
				tag.OnPointerEnterSignal.add(OnTagPointerEnterCallback);
				tag.OnPointerExitSignal.add(OnTagPointerExitCallback);
				tag.OnPointerDownSignal.add(OnTagPointerDownCallback);
			},
			function(obj:GameObject)
			{
				var tag = obj.GetComponent(AlmanacTagIcon);
				tag.OnPointerEnterSignal.remove(OnTagPointerEnterCallback);
				tag.OnPointerExitSignal.remove(OnTagPointerExitCallback);
				// PORT-NOTE: C# 此处为 `-=`（原始代码笔误写成 `+=`），Haxe 中保持与原逻辑等价的注销。
				tag.OnPointerDownSignal.remove(OnTagPointerDownCallback);
			});
	}
	public function UpdateDescriptionIcons(viewDatas:Array<AlmanacDescriptionTagViewData>):Void
	{
		LayoutRebuilder.ForceRebuildLayoutImmediate(descriptionScrollRect.content);
		descriptionIconUpdater.UpdateIconStacks(viewDatas);
	}
	public function SetDescription(name:String, description:String):Void
	{
		nameText.text = name;
		descriptionText.text = description;
		descriptionScrollRect.verticalNormalizedPosition = 1;
	}
	// protected override
	public override function Awake():Void
	{
		super.Awake();
		descriptionIconUpdater.OnIconEnter.add(id -> OnDescriptionIconEnter.dispatch(id));
		descriptionIconUpdater.OnIconExit.add(id -> OnDescriptionIconExit.dispatch(id));
		descriptionIconUpdater.OnIconDown.add(id -> OnDescriptionIconDown.dispatch(id));

		descriptionLinkHandler.OnLinkClick.add(id -> OnDescriptionLinkClick.dispatch(id));
	}
	private function OnTagPointerEnterCallback(icon:AlmanacTagIcon):Void
	{
		OnTagIconEnter.dispatch(entryTags.indexOfComponent(icon));
	}
	private function OnTagPointerExitCallback(icon:AlmanacTagIcon):Void
	{
		OnTagIconExit.dispatch(entryTags.indexOfComponent(icon));
	}
	private function OnTagPointerDownCallback(icon:AlmanacTagIcon):Void
	{
		OnTagIconDown.dispatch(entryTags.indexOfComponent(icon));
	}
	public var OnDescriptionIconEnter:FlxTypedSignal<String->Void> = new FlxTypedSignal();
	public var OnDescriptionIconExit:FlxTypedSignal<String->Void> = new FlxTypedSignal();
	public var OnDescriptionIconDown:FlxTypedSignal<String->Void> = new FlxTypedSignal();
	public var OnDescriptionLinkClick:FlxTypedSignal<String->Void> = new FlxTypedSignal();
	public var OnTagIconEnter:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnTagIconExit:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	public var OnTagIconDown:FlxTypedSignal<Int->Void> = new FlxTypedSignal();
	@:serializeField
	private var descriptionScrollRect:ScrollRect;
	@:serializeField
	private var nameText:TextMeshProUGUI;
	@:serializeField
	private var descriptionText:TextMeshProUGUI;
	@:serializeField
	private var entryTags:ElementList;
	@:serializeField
	private var descriptionIconUpdater:AlmanacTaggedDescription;
	@:serializeField
	private var descriptionLinkHandler:AlmanacDescriptionLinkHandler;
}

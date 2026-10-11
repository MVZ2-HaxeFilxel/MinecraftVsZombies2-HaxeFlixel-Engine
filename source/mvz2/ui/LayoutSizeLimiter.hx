// Ported from: Assets/Scripts/View/UI/LayoutSizeLimiter.cs
package mvz2.ui;

import unity.RectTransform;
import unity.Vector2;
import unity.ui.Selectable;
import unity.ui.Shadow;
import unity.ui.UIBehaviour;
import mvz2.gamecontent.commands.Clear;
import unity.Mathf;
import unity.ui.Selectable.ILayoutElement;
import unity.ui.LayoutRebuilder;

// @:RequireComponent(RectTransform)
// @:ExecuteAlways
class LayoutSizeLimiter extends UIBehaviour implements ILayoutElement
{
	public function new()
	{
		super();
	}
	override public function OnEnable():Void
	{
		super.OnEnable();
		SetDirty();
	}
	override public function OnDisable():Void
	{
		// PORT-NOTE: C# 的 DrivenRectTransformTracker 由 Unity 布局系统提供，移植层无对应实现。
		LayoutRebuilder.MarkLayoutForRebuild(rectTransform);
		super.OnDisable();
	}
	override public function OnRectTransformDimensionsChange():Void
	{
		SetDirty();
	}
	override public function OnValidate():Void
	{
		SetDirty();
	}
	function SetDirty():Void
	{
		if (!IsActive())
			return;

		LayoutRebuilder.MarkLayoutForRebuild(rectTransform);
	}
	public function CalculateLayoutInputHorizontal():Void
	{
		if (maxWidth < 0)
		{
			_currentWidth = -1;
			return;
		}
		// PORT-NOTE: m_Tracker.Add(...) 对应 Unity 的 DrivenRectTransformTracker，移植层省略。

		_disabled = true;
		var preferredWidth = LayoutUtility.GetPreferredSize(m_Rect, 0);
		var width = unity.Mathf.Min(preferredWidth, maxWidth);
		_currentWidth = width;
		_disabled = false;

		// PORT-NOTE: C# 为 `rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, width)`。
		// unity shim 的 RectTransform 未定义该方法，改用本类的同名私有辅助函数（见文件末尾）。
		// TODO-PORT: 待 unity 域在 RectTransform 上补 SetSizeWithCurrentAnchors 后改回成员调用。
		setSizeWithCurrentAnchors(LayoutAxis.Horizontal, width);
	}
	public function CalculateLayoutInputVertical():Void
	{
		if (maxHeight < 0)
		{
			_currentHeight = -1;
			return;
		}
		// PORT-NOTE: m_Tracker.Add(...) 对应 Unity 的 DrivenRectTransformTracker，移植层省略。

		_disabled = true;
		var preferredHeight = LayoutUtility.GetPreferredSize(m_Rect, 1);
		var height = unity.Mathf.Min(preferredHeight, maxHeight);
		_currentHeight = height;
		_disabled = false;

		// Set size to min or preferred size
		// PORT-NOTE: 同 CalculateLayoutInputHorizontal，改用本类的辅助函数。
		setSizeWithCurrentAnchors(LayoutAxis.Vertical, height);
	}

	// PORT-NOTE: C# 为 `RectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis, float)`。
	// unity shim 的 RectTransform 未定义该方法；此 shim 中锚点不拉伸时 RectTransform.rect 的尺寸即 sizeDelta，
	// 故按轴改写 sizeDelta。TODO-PORT: 待 unity 域补齐后删除本函数并改回成员调用。
	private function setSizeWithCurrentAnchors(axis:LayoutAxis, size:Float):Void
	{
		var delta = rectTransform.sizeDelta;
		if (axis == LayoutAxis.Horizontal)
			rectTransform.sizeDelta = new Vector2(size, delta.y);
		else
			rectTransform.sizeDelta = new Vector2(delta.x, size);
	}

	// [System.NonSerialized]
	private var m_Rect:RectTransform;
	private var rectTransform(get, never):RectTransform;
	function get_rectTransform():RectTransform
	{
		if (m_Rect == null)
			m_Rect = GetComponent(RectTransform);
		return m_Rect;
	}
	@:serializeField
	private var maxWidth:Float = -1;
	@:serializeField
	private var maxHeight:Float = -1;
	private var _disabled:Bool;
	private var _currentWidth:Float;
	private var _currentHeight:Float;
	public var minWidth(get, never):Float;
	function get_minWidth():Float return -1;
	public var minHeight(get, never):Float;
	function get_minHeight():Float return -1;
	public var preferredWidth(get, never):Float;
	function get_preferredWidth():Float return _disabled ? -1 : _currentWidth;
	public var preferredHeight(get, never):Float;
	function get_preferredHeight():Float return _disabled ? -1 : _currentHeight;
	public var flexibleWidth(get, never):Float;
	function get_flexibleWidth():Float return -1;
	public var flexibleHeight(get, never):Float;
	function get_flexibleHeight():Float return -1;
	public var layoutPriority(get, never):Int;
	function get_layoutPriority():Int return 100;
}

// Minimal UnityEngine.UI.LayoutUtility shim.
class LayoutUtility
{
	public static function GetPreferredSize(rect:RectTransform, axis:Int):Float return 0;
	public static function GetMinSize(rect:RectTransform, axis:Int):Float return 0;
	public static function GetFlexibleSize(rect:RectTransform, axis:Int):Float return 0;
	public static function GetMinWidth(rect:RectTransform):Float return 0;
	public static function GetPreferredWidth(rect:RectTransform):Float return 0;
	public static function GetFlexibleWidth(rect:RectTransform):Float return 0;
	public static function GetMinHeight(rect:RectTransform):Float return 0;
	public static function GetPreferredHeight(rect:RectTransform):Float return 0;
	public static function GetFlexibleHeight(rect:RectTransform):Float return 0;
}

// Minimal UnityEngine.UI.DrivenRectTransformTracker shim.
class DrivenRectTransformTracker
{
	public function new() {}
	public function Add(driver:Dynamic, rect:RectTransform, drivenProperties:Int):Void {}
	public function Clear():Void {}
}

// Minimal UnityEngine.RectTransform.Axis shim.
enum abstract LayoutAxis(Int)
{
	var Horizontal = 0;
	var Vertical = 1;
}

// Ported from: Assets/Scripts/View/Dialogs/Options/OptionsDialogMainPage.cs
package mvz2.ui;

import flixel.util.FlxSignal.FlxTypedSignal;
import mvz2.ui.LabeledToggle;
import mvz2.ui.TextButton;
import mvz2.ui.TextSlider;
import mvz2.ui.TooltipHandler;
import unity.GameObject;
import unity.Transform;
import unity.UnityObject;
import unity.ui.Button;
import unity.MonoBehaviour;
import unity.ui.Slider;
import unity.ui.Text;
import unity.ui.Toggle;
import flixel.util.FlxSignal;

class OptionsDialogMainPage extends unity.MonoBehaviour
{
	// #region 滑动条
	public function SetSliderValue(type:SliderType, value:Float):Void
	{
		if (sliderDict.exists(type))
		{
			var slider = sliderDict.get(type);
			slider.Slider.SetValueWithoutNotify(value);
		}
	}
	public function SetSliderRange(type:SliderType, min:Float, max:Float, integer:Bool):Void
	{
		if (sliderDict.exists(type))
		{
			var slider = sliderDict.get(type);
			slider.Slider.minValue = min;
			slider.Slider.maxValue = max;
			slider.Slider.wholeNumbers = integer;
		}
	}
	public function SetSliderText(type:SliderType, text:String):Void
	{
		if (sliderDict.exists(type))
		{
			var slider = sliderDict.get(type);
			slider.Text.text = text;
		}
	}
	public function SetSliderActive(type:SliderType, value:Bool):Void
	{
		if (sliderDict.exists(type))
		{
			var slider = sliderDict.get(type);
			slider.gameObject.SetActive(value);
			UpdateWidgetAreas();
		}
	}
	// #endregion

	// #region 按钮
	public function SetButtonText(type:TextButtonType, text:String):Void
	{
		if (textButtonDict.exists(type))
		{
			var button = textButtonDict.get(type);
			button.Text.text = text;
		}
	}
	public function SetButtonActive(type:ButtonType, value:Bool):Void
	{
		if (buttonDict.exists(type))
		{
			var button = buttonDict.get(type);
			button.gameObject.SetActive(value);
			UpdateWidgetAreas();
		}
	}
	// #endregion

	// #region 切换
	public function SetToggleActive(type:ToggleType, value:Bool):Void
	{
		if (toggleDict.exists(type))
		{
			var toggle = toggleDict.get(type);
			toggle.gameObject.SetActive(value);
			UpdateWidgetAreas();
		}
	}
	public function SetToggleText(type:ToggleType, text:String):Void
	{
		if (toggleDict.exists(type))
		{
			var toggle = toggleDict.get(type);
			toggle.Text.text = text;
		}
	}
	public function SetToggleOn(type:ToggleType, value:Bool):Void
	{
		if (toggleDict.exists(type))
		{
			var toggle = toggleDict.get(type);
			toggle.Toggle.SetIsOnWithoutNotify(value);
		}
	}
	// #endregion

	// #region 生命周期
	// PORT-NOTE: 导出数据里 `musicSlider` / `fastForwardSlider` / `pauseOnFocusLostToggle` 的注入值
	// 本来就是 null（见 assets/scene_prefabs/**/OptionsDialog*.json），其余引用也可能因导出/注入
	// 失败而缺失。hxcpp release 下空引用是访问违例（`try/catch` 抓不到），因此这里**逐项判空**后
	// 才登记：缺引用的控件只是不参与事件分发，而不是让 Awake 在第一处解引用上崩掉。
	private function Awake():Void
	{
		addSlider(SliderType.Music, musicSlider);
		addSlider(SliderType.Sound, soundSlider);
		addSlider(SliderType.FastForward, fastForwardSlider);

		// 1-1
		addToggle(ToggleType.SwapTrigger, swapTriggerToggle);

		// 1-2
		addToggle(ToggleType.PauseOnFocusLost, pauseOnFocusLostToggle);

		// 2-1
		addButton(TextButtonType.MoreOptions, ButtonType.MoreOptions, moreOptionsButton);

		// 2-2
		addButton(TextButtonType.Difficulty, ButtonType.Difficulty, diffcultyButton);
		addButton(TextButtonType.Restart, ButtonType.Restart, restartButton);

		// 3-1
		addButton(TextButtonType.LeaveLevel, ButtonType.LeaveLevel, leaveLevelButton);

		// 3-2
		addButton(TextButtonType.Back, ButtonType.Back, backButton);

		// PORT-NOTE: 三个字典此刻只含「引用完整」的项，下面的订阅循环可以安全解引用。
		for (type in sliderDict.keys())
		{
			var capturedType = type;
			var slider = sliderDict.get(type);
			slider.Slider.onValueChanged.AddListener(value -> OnSliderValueChanged.dispatch(capturedType, value));
			if (UnityObject.exists(slider.EndHandler))
				slider.EndHandler.OnEnd.add(value -> OnSliderEnd.dispatch(capturedType, slider.Slider.value));
		}
		for (type in buttonDict.keys())
		{
			var capturedType = type;
			buttonDict.get(type).onClick.AddListener(() -> OnButtonClick.dispatch(capturedType));
		}
		for (type in toggleDict.keys())
		{
			var capturedType = type;
			toggleDict.get(type).Toggle.onValueChanged.AddListener((v) -> OnToggleValueChanged.dispatch(capturedType, v));
		}
		if (!UnityObject.exists(gameObject))
			return;
		var tooltipHandlers = gameObject.GetComponentsInChildren(TooltipHandler, true);
		for (handler in tooltipHandlers)
		{
			if (handler == null)
				continue;
			handler.OnPointerEnterSignal.add(OnTooltipHandlerPointerEnterCallback);
			handler.OnPointerExitSignal.add(OnTooltipHandlerPointerExitCallback);
		}
	}

	/** 登记滑动条：缺引用或内部 Slider 缺失时不登记（登记后订阅/取 value 处必然解引用它）。 */
	private function addSlider(type:SliderType, slider:TextSlider):Void
	{
		if (slider == null || slider.Slider == null)
			return;
		sliderDict.set(type, slider);
	}
	/** 登记按钮：文本字典要求 Text 存在（`SetButtonText` 解引用它），按钮字典要求 Button 存在。 */
	private function addButton(textType:TextButtonType, buttonType:ButtonType, textButton:TextButton):Void
	{
		if (textButton == null)
			return;
		if (textButton.Text != null)
			textButtonDict.set(textType, textButton);
		if (textButton.Button != null)
			buttonDict.set(buttonType, textButton.Button);
	}
	/** 登记开关：缺引用或内部 Toggle 缺失时不登记。 */
	private function addToggle(type:ToggleType, toggle:LabeledToggle):Void
	{
		if (toggle == null || toggle.Toggle == null)
			return;
		toggleDict.set(type, toggle);
	}
	// #endregion

	// #region 事件回调
	private function OnTooltipHandlerPointerEnterCallback(handler:TooltipHandler):Void
	{
		OnTooltipShow.dispatch(handler);
	}
	private function OnTooltipHandlerPointerExitCallback(handler:TooltipHandler):Void
	{
		OnTooltipHide.dispatch(handler);
	}
	// #endregion

	private function UpdateWidgetAreas():Void
	{
		// PORT-NOTE: widgetAreas 无声明初值；prefab 数据缺该字段时为 null，
		// 而 hxcpp 上遍历 null 数组会直接崩（不是 Haxe 异常），故判空后直接返回。
		if (widgetAreas == null)
			return;
		for (line in widgetAreas)
		{
			if (line == null || line.gameObject == null)
				continue;
			var hasActiveChild = HasAnyChildrenElement(line);
			line.gameObject.SetActive(hasActiveChild);
		}
	}
	private function HasAnyChildrenElement(parent:Transform):Bool
	{
		for (i in 0...parent.childCount)
		{
			var child = parent.GetChild(i);
			if (child == null || child.gameObject == null || !child.gameObject.activeSelf)
				continue;
			if (child.GetComponent(IOptionsDialogElement) != null)
			{
				return true;
			}
			if (HasAnyChildrenElement(child))
			{
				return true;
			}
		}
		return false;
	}

	public var OnSliderValueChanged:FlxTypedSignal<SliderType->Float->Void> = new FlxTypedSignal();
	public var OnSliderEnd:FlxTypedSignal<SliderType->Float->Void> = new FlxTypedSignal();
	public var OnButtonClick:FlxTypedSignal<ButtonType->Void> = new FlxTypedSignal();
	public var OnToggleValueChanged:FlxTypedSignal<ToggleType->Bool->Void> = new FlxTypedSignal();
	public var OnTooltipShow:FlxTypedSignal<TooltipHandler->Void> = new FlxTypedSignal();
	public var OnTooltipHide:FlxTypedSignal<TooltipHandler->Void> = new FlxTypedSignal();

	private var sliderDict:Map<SliderType, TextSlider> = new Map<SliderType, TextSlider>();
	private var textButtonDict:Map<TextButtonType, TextButton> = new Map<TextButtonType, TextButton>();
	private var buttonDict:Map<ButtonType, Button> = new Map<ButtonType, Button>();
	private var toggleDict:Map<ToggleType, LabeledToggle> = new Map<ToggleType, LabeledToggle>();

	@:serializeField
	private var widgetAreas:Array<Transform>;

	@:serializeField
	private var musicSlider:TextSlider;
	@:serializeField
	private var soundSlider:TextSlider;
	@:serializeField
	private var fastForwardSlider:TextSlider;

	@:serializeField
	private var swapTriggerToggle:LabeledToggle;
	@:serializeField
	private var pauseOnFocusLostToggle:LabeledToggle;

	@:serializeField
	private var diffcultyButton:TextButton;
	@:serializeField
	private var restartButton:TextButton;

	@:serializeField
	private var moreOptionsButton:TextButton;
	@:serializeField
	private var leaveLevelButton:TextButton;

	@:serializeField
	private var backButton:TextButton;
}

enum abstract SliderType(Int)
{
	var Music = 0;
	var Sound = 1;
	var FastForward = 2;
}

enum abstract TextButtonType(Int)
{
	var Difficulty = 0;
	var Restart = 1;

	var MoreOptions = 2;
	var LeaveLevel = 3;

	var Back = 4;
}

enum abstract ButtonType(Int)
{
	var Difficulty = 0;
	var Restart = 1;

	var MoreOptions = 2;
	var LeaveLevel = 3;

	var Back = 4;
}

enum abstract ToggleType(Int)
{
	var SwapTrigger = 0;
	var PauseOnFocusLost = 1;
}

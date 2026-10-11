// Ported from: Assets/Scripts/View/Dialogs/LanguageDialog.cs
package mvz2.ui;

import flixel.util.FlxSignal.FlxTypedSignal;
import unity.tmpro.TMP_Dropdown;
import unity.ui.Button;
import flixel.util.FlxSignal;

class LanguageDialog extends Dialog
{
	public function SetLanguages(languages:Array<String>):Void
	{
		mvz2.states.BootTrace.step('LanguageDialog.SetLanguages: n=${languages == null ? -1 : languages.length} dropdown=${dropdown != null}');
		dropdown.ClearOptions();
		// PORT-NOTE: C# 为 AddOptions(languages.ToList())，TMP_Dropdown 会隐式包装 OptionData；
		// Haxe 无隐式转换，显式构造 TMP_OptionData。
		dropdown.AddOptions([for (lang in languages) new unity.tmpro.TMP_OptionData(lang)]);
	}
	private function Awake():Void
	{
		confirmButton.onClick.AddListener(() -> OnConfirm.dispatch(dropdown.value));
	}
	public var OnConfirm:FlxTypedSignal<Int->Void> = new FlxTypedSignal();

	@:serializeField
	private var dropdown:TMP_Dropdown;
	@:serializeField
	private var confirmButton:Button;
}

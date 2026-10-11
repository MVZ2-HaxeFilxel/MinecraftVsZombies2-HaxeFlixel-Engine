// Ported from: Assets/Scripts/MVZ2/Level/Components/AdviceComponent.cs
package mvz2.level.components;

import haxe.Int64;
import mvz2.level.LevelController;
import mvz2logic.Global;
import mvz2logic.level.components.ComponentInterfaces.IAdviceComponent;
import pvzengine.NamespaceID;
import pvzengine.level.ISerializableLevelComponent;
import pvzengine.level.LevelEngine;

class AdviceComponent extends MVZ2Component implements IAdviceComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, componentID, controller);
	}

	public function ShowAdvice(context:String, textKey:String, priority:Int, timeout:Int, args:Array<String>):Void
	{
		if (AdvicePriority > priority && AdviceTimeout != 0)
			return;
		AdviceContext = context;
		AdviceKey = textKey;
		AdvicePriority = priority;
		AdviceTimeout = timeout;
		AdviceArgs = args;
		AdvicePluralKey = null;
		AdvicePluralNum = 0;
		var ui = Controller.GetUIPreset();
		ui.ShowAdvice(GetAdvice());
	}
	public function ShowAdvicePlural(context:String, textKey:String, textPlural:String, pluralNum:Int64, priority:Int, timeout:Int, args:Array<String>):Void
	{
		if (AdvicePriority > priority && AdviceTimeout != 0)
			return;
		AdviceContext = context;
		AdviceKey = textKey;
		AdvicePriority = priority;
		AdviceTimeout = timeout;
		AdviceArgs = args;
		AdvicePluralKey = textPlural;
		AdvicePluralNum = pluralNum;
		var ui = Controller.GetUIPreset();
		ui.ShowAdvice(GetAdvice());
	}
	public function HideAdvice():Void
	{
		AdviceContext = null;
		AdviceKey = null;
		AdvicePriority = 0;
		AdviceTimeout = 0;
		AdviceArgs = [];
		AdvicePluralKey = null;
		AdvicePluralNum = 0;
		var ui = Controller.GetUIPreset();
		ui.HideAdvice();
	}
	override public function Update():Void
	{
		if (AdviceTimeout <= 0)
			return;
		AdviceTimeout--;
		if (AdviceTimeout > 0)
			return;
		HideAdvice();
	}
	override public function ToSerializable():ISerializableLevelComponent
	{
		var comp = new SerializableAdviceComponent();
		comp.adviceContext = AdviceContext;
		comp.adviceKey = AdviceKey;
		comp.advicePluralKey = AdvicePluralKey;
		comp.advicePluralNum = AdvicePluralNum;
		comp.advicePriority = AdvicePriority;
		comp.adviceTimeout = AdviceTimeout;
		comp.adviceArgs = AdviceArgs != null ? AdviceArgs.copy() : null;
		return comp;
	}
	override public function InitFromSerializable(seri:ISerializableLevelComponent):Void
	{
		if (!Std.isOfType(seri, SerializableAdviceComponent))
			return;
		var comp:SerializableAdviceComponent = cast seri;
		AdviceContext = comp.adviceContext;
		AdviceKey = comp.adviceKey;
		AdvicePluralKey = comp.advicePluralKey;
		AdvicePluralNum = comp.advicePluralNum;
		AdvicePriority = comp.advicePriority;
		AdviceTimeout = comp.adviceTimeout;
		AdviceArgs = comp.adviceArgs != null ? comp.adviceArgs.copy() : [];
	}
	override public function PostLevelLoad():Void
	{
		super.PostLevelLoad();
		if (AdviceTimeout != 0)
		{
			var ui = Controller.GetUIPreset();
			ui.ShowAdvice(GetAdvice());
		}
	}
	public function GetAdvice():String
	{
		if (AdviceKey == null || AdviceKey == "")
			return "";
		if (AdviceContext == null || AdviceContext == "")
		{
			if (AdvicePluralKey == null || AdvicePluralKey == "")
				return Global.Localization.GetText(AdviceKey, AdviceArgs);
			return Global.Localization.GetTextPlural(AdviceKey, AdvicePluralKey, AdvicePluralNum, AdviceArgs);
		}
		else
		{
			if (AdvicePluralKey == null || AdvicePluralKey == "")
				return Global.Localization.GetTextParticular(AdviceKey, AdviceContext, AdviceArgs);
			return Global.Localization.GetTextPluralParticular(AdviceKey, AdvicePluralKey, AdvicePluralNum, AdviceContext, AdviceArgs);
		}
	}
	public var AdviceContext(default, null):String;
	public var AdviceKey(default, null):String;
	public var AdvicePluralKey(default, null):String;
	public var AdvicePluralNum(default, null):Int64;
	public var AdviceArgs(default, null):Array<String> = [];
	public var AdvicePriority(default, null):Int;
	public var AdviceTimeout(default, null):Int;
	// PORT-NOTE: C# 的 static readonly 字段是首次使用时才初始化；hxcpp 会在 main() 之前执行全部静态初始化
	// （__boot_all()），那时 Global.Game / MainManager.Instance 仍为 null，直接求值会段错误。
	// 此处改为惰性 getter（结果缓存一次，等价于 C# 的 readonly static），还原 C# 语义。
	public static var componentID(get, never):NamespaceID;
	private static var _componentID:NamespaceID;
	static function get_componentID():NamespaceID
	{
		if (_componentID == null) _componentID = new NamespaceID(Global.BuiltinNamespace, "advice");
		return _componentID;
	}
}

@:rtti
class SerializableAdviceComponent implements ISerializableLevelComponent
{
	public var adviceContext:String;
	public var adviceKey:String;
	public var advicePluralKey:String;
	public var advicePluralNum:Int64;
	public var advicePriority:Int;
	public var adviceTimeout:Int;
	public var adviceArgs:Array<String>;
	public function new() {}
}

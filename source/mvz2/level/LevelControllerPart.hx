// Ported from: Assets/Scripts/MVZ2/Level/ControllerPart/LevelControllerPart.cs
package mvz2.level;

import mvz2.managers.MainManager;
import mvz2.ui.level.LevelUI.ILevelUI;
import mvz2logic.games.IGlobalGame;
import pvzengine.NamespaceID;
import pvzengine.NamespaceIDReference;
import pvzengine.level.LevelEngine;
import unity.*;
import unity.Debug;
import mvz2.ui.level.LevelUI;
import Main;

interface ILevelControllerPart
{
	public function Init(controller:LevelController):Void;
	public function AddEngineCallbacks(level:LevelEngine):Void;
	public function RemoveEngineCallbacks(level:LevelEngine):Void;
	public function PostLevelStart():Void;
	public function UpdateLogic():Void;
	public function UpdateFrame(deltaTime:Float, simulationSpeed:Float):Void;
	public function PostLevelLoad():Void;
	public function ToSerializable():SerializableLevelControllerPart;
	public function LoadFromSerializable(seri:SerializableLevelControllerPart):Void;
	public var ID(get, never):NamespaceID;
}

// PORT-NOTE: C# 的 abstract class 在 Haxe 中语义不同（这里仍写作普通 class）。
class LevelControllerPart extends MonoBehaviour implements ILevelControllerPart
{
	public function Init(controller:LevelController):Void
	{
		Controller = controller;
	}
	public function AddEngineCallbacks(level:LevelEngine):Void { }
	public function RemoveEngineCallbacks(level:LevelEngine):Void { }
	public function PostLevelStart():Void { }
	public function UpdateLogic():Void { }
	public function UpdateFrame(deltaTime:Float, simulationSpeed:Float):Void { }
	public function PostLevelLoad():Void { }
	public function ToSerializable():SerializableLevelControllerPart
	{
		return GetSerializable();
	}
	// abstract
	public function GetSerializable():SerializableLevelControllerPart
	{
		throw "abstract";
	}
	public function LoadFromSerializable(seri:SerializableLevelControllerPart):Void { }
	public var Game(get, never):IGlobalGame;
	function get_Game():IGlobalGame return Controller.Game;
	public var UI(get, never):ILevelUI;
	function get_UI():ILevelUI return Controller.GetUI();
	public var Main(get, never):MainManager;
	function get_Main():MainManager return MainManager.Instance;
	public var Level(get, never):LevelEngine;
	function get_Level():LevelEngine return Controller.GetEngine();
	public var Controller(default, null):ILevelController = null;
	public var ID(get, never):NamespaceID;
	function get_ID():NamespaceID return id.Get();
	@:serializeField
	private var id:NamespaceIDReference = null;
}

// PORT-NOTE: C# 的 abstract class 在 Haxe 中语义不同（这里仍写作普通 class）。
@:rtti
class SerializableLevelControllerPart
{
	public var id:NamespaceID;
	public function new() {}
}

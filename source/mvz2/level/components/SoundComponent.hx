// Ported from: Assets/Scripts/MVZ2/Level/Components/SoundComponent.cs
package mvz2.level.components;

import haxe.Int64;
import mvz2.level.LevelController;
import mvz2logic.Global;
import mvz2logic.level.components.ComponentInterfaces.ISoundComponent;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.level.ISerializableLevelComponent;
import pvzengine.level.LevelEngine;
import unity.Vector3;
import unity.Mathf;
import unity.Debug;
import unity.UnityObject;
import mvz2.audios.SoundManager;
import mvz2.managers.ResourceManager;
import Main;

class SoundComponent extends MVZ2Component implements ISoundComponent
{
	public function new(level:LevelEngine, controller:LevelController)
	{
		super(level, componentID, controller);
	}
	override public function UpdateFrame(deltaTime:Float, simulationSpeed:Float):Void
	{
		super.UpdateFrame(deltaTime, simulationSpeed);
		loopSoundBuffer = [];
		for (k in loopSounds.keys())
			loopSoundBuffer.push(k);
		for (id in loopSoundBuffer)
		{
			UpdateLoopSoundEntities(id);
		}
		UpdatePlayingLoopSounds(deltaTime);
	}
	// TODO-PORT: C# 重载 PlaySound(NamespaceID, Vector3, float, float)。
	public function PlaySoundAt(id:NamespaceID, position:Vector3, pitch:Float = 1, volume:Float = 1):Void
	{
		var source = Main.SoundManager.Play(id, Controller.LawnToTrans(position), pitch, 1);
		if (source == null)
			return;
		source.volume = volume;
	}
	public function PlaySound(id:NamespaceID, pitch:Float = 1, volume:Float = 1):Void
	{
		var source = Main.SoundManager.Play(id, Vector3.zero, pitch, 0);
		if (source == null)
			return;
		source.volume = volume;
	}
	public function IsPlayingSound(id:NamespaceID):Bool
	{
		return Main.SoundManager.IsPlaying(id);
	}
	// #region 循环音效
	public function IsPlayingLoopSound(id:NamespaceID):Bool
	{
		return playingLoopSounds.contains(id);
	}
	public function StopAllLoopSounds():Void
	{
		for (sound in playingLoopSounds)
		{
			Main.SoundManager.StopLoopSound(sound);
		}
		loopSounds.clear();
		playingLoopSounds = [];
	}
	public function HasLoopSoundEntity(id:NamespaceID, entityId:Int64):Bool
	{
		if (!loopSounds.exists(id))
		{
			return false;
		}
		return loopSounds.get(id).exists(entityId);
	}
	public function AddLoopSoundEntity(id:NamespaceID, entityId:Int64):Bool
	{
		if (!loopSounds.exists(id))
		{
			loopSounds.set(id, new Map());
		}
		var hashSet = loopSounds.get(id);
		if (hashSet.exists(entityId))
			return false;
		hashSet.set(entityId, true);
		return true;
	}
	public function RemoveLoopSoundEntity(id:NamespaceID, entityId:Int64):Bool
	{
		if (!loopSounds.exists(id))
			return false;
		var hashSet = loopSounds.get(id);
		if (hashSet.exists(entityId))
		{
			hashSet.remove(entityId);
			if (setCount(hashSet) <= 0)
				loopSounds.remove(id);

			return true;
		}
		return false;
	}
	public function HasLoopSoundEntities(id:NamespaceID):Bool
	{
		if (!loopSounds.exists(id))
			return false;
		return setCount(loopSounds.get(id)) > 0;
	}
	public function GetLoopSounds():Array<NamespaceID>
	{
		return [for (k in loopSounds.keys()) k];
	}
	// PORT-NOTE: Haxe 的 Map 没有 C# HashSet.Count 的等价属性，这里提供计数辅助方法。
	private static function setCount<T>(set:Map<T, Bool>):Int
	{
		var n = 0;
		for (_ in set.keys())
			n++;
		return n;
	}
	private function PlayLoopSound(id:NamespaceID):Void
	{
		Main.SoundManager.PlayLoopSound(id);
		if (!playingLoopSounds.contains(id))
			playingLoopSounds.push(id);
	}
	private function StopLoopSound(id:NamespaceID):Void
	{
		Main.SoundManager.StopLoopSound(id);
		playingLoopSounds.remove(id);
	}
	private function SetLoopSoundPosition(id:NamespaceID, position:Vector3):Void
	{
		var pos = Controller.LawnToTrans(position);
		Main.SoundManager.SetLoopSoundPosition(id, pos);
	}
	private function GetLoopSoundIntensity(id:NamespaceID):Float
	{
		return Main.SoundManager.GetLoopSoundIntensity(id);
	}
	private function SetLoopSoundIntensity(id:NamespaceID, level:Float):Void
	{
		Main.SoundManager.SetLoopSoundIntensity(id, level);
	}
	private function UpdateLoopSoundEntities(id:NamespaceID):Void
	{
		var entities = loopSounds.get(id);
		var toRemove:Array<Int64> = [];
		for (entityID in entities.keys())
		{
			var ent = Level.FindEntityByID(entityID);
			if (ent == null || !unity.UnityObject.exists(ent))
			{
				toRemove.push(entityID);
			}
		}
		for (entityID in toRemove)
		{
			entities.remove(entityID);
		}
		if (setCount(entities) <= 0)
		{
			loopSounds.remove(id);
			return;
		}
		if (!Controller.IsGameRunning())
		{
			return;
		}
		var entityID:Int64 = 0;
		for (k in entities.keys())
		{
			entityID = k;
			break;
		}
		var entity = Level.FindEntityByID(entityID);
		if (entity != null)
		{
			if (!IsPlayingLoopSound(id))
			{
				PlayLoopSound(id);
			}
			SetLoopSoundPosition(id, entity.Position);
		}
	}
	private function UpdatePlayingLoopSounds(deltaTime:Float):Void
	{
		var i = playingLoopSounds.length - 1;
		while (i >= 0)
		{
			var soundID = playingLoopSounds[i];
			var intensity = GetLoopSoundIntensity(soundID);
			var meta = Main.ResourceManager.GetSoundMeta(soundID);
			var active = HasLoopSoundEntities(soundID) && Controller.IsGameRunning();
			var speed:Float = active ? 1 : -1;
			if (meta != null)
			{
				speed = active ? meta.loopFadeInSpeed : -meta.loopFadeOutSpeed;
			}
			speed *= deltaTime;
			intensity = Mathf.Clamp01(intensity + speed);
			SetLoopSoundIntensity(soundID, intensity);

			if (!active && intensity <= 0)
			{
				StopLoopSound(soundID);
			}
			i--;
		}
	}
	// #endregion
	override public function ToSerializable():ISerializableLevelComponent
	{
		var loopSounds = [for (p in this.loopSounds.keyValueIterator())
		{
			var item = new SerializableLoopSoundItem();
			item.id = p.key;
			item.entities = [for (k in p.value.keys()) k];
			item;
		}];
		var comp = new SerializableSoundComponent();
		comp.loopSounds = loopSounds;
		return comp;
	}
	override public function InitFromSerializable(seri:ISerializableLevelComponent):Void
	{
		super.InitFromSerializable(seri);
		if (!Std.isOfType(seri, SerializableSoundComponent))
			return;
		var serializable:SerializableSoundComponent = cast seri;
		loopSounds = new Map();
		if (serializable.loopSounds != null)
		{
			for (item in serializable.loopSounds)
			{
				if (item == null || !NamespaceID.IsValid(item.id))
					continue;
				var hashSet:Map<Int64, Bool> = new Map();
				if (item.entities != null)
				{
					for (ent in item.entities)
					{
						hashSet.set(ent, true);
					}
				}
				loopSounds.set(item.id, hashSet);
			}
		}
	}
	// PORT-NOTE: C# 的 static readonly 字段是首次使用时才初始化；hxcpp 会在 main() 之前执行全部静态初始化
	// （__boot_all()），那时 Global.Game / MainManager.Instance 仍为 null，直接求值会段错误。
	// 此处改为惰性 getter（结果缓存一次，等价于 C# 的 readonly static），还原 C# 语义。
	public static var componentID(get, never):NamespaceID;
	private static var _componentID:NamespaceID;
	static function get_componentID():NamespaceID
	{
		if (_componentID == null) _componentID = new NamespaceID(Global.BuiltinNamespace, "sound");
		return _componentID;
	}
	private var loopSounds:Map<NamespaceID, Map<Int64, Bool>> = new Map();
	private var playingLoopSounds:Array<NamespaceID> = [];
	private var loopSoundBuffer:Array<NamespaceID> = [];
}

@:rtti
class SerializableSoundComponent implements ISerializableLevelComponent
{
	public var loopSounds:Array<SerializableLoopSoundItem>;
	public function new() {}
}

@:rtti
class SerializableLoopSoundItem
{
	public var id:NamespaceID;
	public var entities:Array<Int64>;
	public function new() {}
}

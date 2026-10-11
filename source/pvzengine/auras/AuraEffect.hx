// Ported from: Assets/Scripts/Engine/Level/Aura/AuraEffect.cs
// PORT-NOTE: C# AuraEffectList.Get<T>() 与 Get(AuraEffectDefinition) 为重载，Haxe 不支持重载，
//   泛型版在移植层命名为 GetOfType（见 AuraEffectList.hx）。
// PORT-NOTE: C# `buffCaches.FirstOrDefault().Key` 与 Dictionary 遍历 → Haxe 用 Map 的 keys() 遍历，
//   删除操作与 C# 一致地在遍历结束后统一执行（removeBuffBuffer）。
package pvzengine.auras;

import unity.UnityObject;
import pvzengine.base.ArrayBuffer;
import pvzengine.buffs.Buff;
import pvzengine.buffs.IBuffTarget;
import pvzengine.level.LevelEngine;
using pvzengine.buffs.BuffTargetExt;
import tools.FrameTimer;

class AuraEffect
{
	public function new(definition:AuraEffectDefinition, id:Int, source:IAuraSource)
	{
		ID = id;
		Definition = definition;
		updateTimer = new FrameTimer(Definition.UpdateInterval);
		Source = source;
	}
	public function UpdateAuraInterval():Void
	{
		updateTimer.Run();
		if (updateTimer.Expired)
		{
			updateTimer.Reset();
			UpdateAura();
		}
	}
	public function PostAdd():Void
	{
		UpdateAura();
		Definition.PostAdd(this);
	}
	public function PostRemove():Void
	{
		ClearBuffs();
		Definition.PostRemove(this);
	}
	public function GetFirstTarget():Null<IBuffTarget>
	{
		for (target in buffCaches.keys())
		{
			return target;
		}
		return null;
	}
	public function GetTargetCount():Int
	{
		var count = 0;
		for (target in buffCaches.keys())
		{
			count++;
		}
		return count;
	}
	public function UpdateAura():Void
	{
		if (!unity.UnityObject.exists(Source))
			return;
		var level = Source.GetLevel();
		targetsBuffer.resize(0);
		Definition.GetAuraTargets(this, targetsBuffer);
		for (target in targetsBuffer)
		{
			var buff = GetTargetBuff(target);
			if (buff == null || buff.Target == null || !unity.UnityObject.exists(buff.Target))
			{
				buff = AddTargetBuff(target);
			}
			Definition.UpdateTargetBuff(this, target, buff);
		}

		removeBuffBuffer.Clear();
		for (target in buffCaches.keys())
		{
			if (!unity.UnityObject.exists(target) || targetsBuffer.indexOf(target) < 0)
			{
				var buff = buffCaches.get(target);
				target.RemoveBuff(buff);
				removeBuffBuffer.Add(target);
			}
		}
		for (i in 0...removeBuffBuffer.Count)
		{
			buffCaches.remove(removeBuffBuffer.Get(i));
		}
	}
	public function ToSerializable():SerializableAuraEffect
	{
		var seri = new SerializableAuraEffect();
		seri.id = ID;
		seri.buffs = [for (target in buffCaches.keys()) target.GetBuffReference(buffCaches.get(target))];
		seri.updateTimer = updateTimer;
		return seri;
	}
	public function LoadFromSerializable(level:LevelEngine, serializable:SerializableAuraEffect):Void
	{
		if (serializable == null)
			return;
		if (serializable.updateTimer != null)
			updateTimer = serializable.updateTimer;
		buffCaches.clear();
		if (serializable.buffs != null)
		{
			for (seriBuff in serializable.buffs)
			{
				var entity = seriBuff.GetTarget(level);
				if (entity == null)
					continue;
				var buff = seriBuff.GetBuff(level);
				if (buff == null)
					continue;
				buffCaches.set(entity, buff);
			}
		}
	}
	private function AddTargetBuff(target:IBuffTarget):Buff
	{
		var buff = target.NewBuff(Definition.BuffID);
		buff.IsFromAura = true;
		target.AddBuff(buff);
		buffCaches.set(target, buff);
		return buff;
	}
	private function GetTargetBuff(entity:IBuffTarget):Null<Buff>
	{
		return buffCaches.get(entity);
	}
	private function ClearBuffs():Void
	{
		for (target in buffCaches.keys())
		{
			var buff = buffCaches.get(target);
			if (buff == null)
				continue;
			buff.Remove();
		}
		buffCaches.clear();
	}
	public var ID(default, null):Int;
	public var Definition(default, null):AuraEffectDefinition;
	public var Source(default, null):IAuraSource;
	public var Level(get, never):LevelEngine;
	private function get_Level():LevelEngine
	{
		return Source.GetLevel();
	}
	private var updateTimer:FrameTimer;
	private var buffCaches:Map<IBuffTarget, Buff> = new Map();
	private var targetsBuffer:Array<IBuffTarget> = [];
	private var removeBuffBuffer:ArrayBuffer<IBuffTarget> = new ArrayBuffer<IBuffTarget>(1024);
}

// Ported from: Assets/Scripts/Engine/Level/Properties/ModifiableProperties.cs
package pvzengine.level;

import pvzengine.IPropertyKey;
import pvzengine.PropertyDictionary;
import pvzengine.PropertyKey;
import pvzengine.SerializablePropertyDictionary;
import pvzengine.modifiers.IModifierProvider;
import pvzengine.modifiers.ModifierSourceItem;
import pvzengine.modifiers.PropertyCalculator;
import tools.GenericHelper;

// PORT-NOTE: C# `Dictionary<IPropertyKey, object?>(new PropertyKeyComparer())` → Haxe 以 int Key 为键的
//   `Map<Int, Dynamic>`（同 PropertyDictionary 的处理），并额外记下键对象用于调试/回填。
// PORT-NOTE: C# 的 `out T? result` 参数改为引用容器 `{value:Dynamic}`（同工程既有约定）。
class ModifiableProperties
{
	public function new(target:IModifiablePropertyTarget, providers:Array<IModifierProvider>)
	{
		Target = target;
		Providers = providers != null ? providers : [];
		for (provider in Providers)
		{
			provider.OnModifiedPropertyNeedsUpdate.add(OnModifiedPropertyNeedsUpdateCallback);
		}
	}

	// #region 设置属性
	public function SetProperty<T>(name:PropertyKey<T>, value:Null<T>):Void
	{
		var beforeValue = GetProperty(name);
		if (properties.SetProperty(name, value))
		{
			UpdateModifiedProperty(name, beforeValue);
		}
	}
	public function SetPropertyObject(name:IPropertyKey, value:Dynamic):Void
	{
		var beforeValue = GetPropertyObject(name);
		if (properties.SetPropertyObject(name, value))
		{
			UpdateModifiedPropertyObject(name, beforeValue);
		}
	}
	public function RemoveProperty(name:IPropertyKey):Bool
	{
		var beforeValue = GetPropertyObject(name);
		if (properties.RemovePropertyObject(name))
		{
			UpdateModifiedPropertyObject(name, beforeValue);
			return true;
		}
		return false;
	}
	// #endregion

	// #region 获取属性
	public function TryGetPropertyObject(name:IPropertyKey, result:{value:Dynamic}, ignoreBuffs:Bool = false):Bool
	{
		if (!ignoreBuffs)
		{
			if (modifiedProperties.TryGetPropertyObject(name, result))
			{
				return true;
			}
		}
		var prop:{value:Dynamic} = {value: null};
		if (properties.TryGetPropertyObject(name, prop))
		{
			result.value = prop.value;
			return true;
		}
		if (fallbackCaches.exists(name.Key))
		{
			result.value = fallbackCaches.get(name.Key);
			return true;
		}
		var fallback:{value:Dynamic} = {value: null};
		if (Target.GetFallbackProperty(name, fallback))
		{
			AddFallbackCache(name, fallback.value);
			result.value = fallback.value;
			return true;
		}
		result.value = name.DefaultValue;
		AddFallbackCache(name, result.value);
		return false;
	}
	public function TryGetProperty<T>(name:PropertyKey<T>, result:{value:Dynamic}, ignoreBuffs:Bool = false):Bool
	{
		var box:{value:Dynamic} = {value: null};
		if (TryGetPropertyObject(name, box, ignoreBuffs))
		{
			if (GenericHelper.TryToGeneric(box.value, result))
			{
				return true;
			}
		}
		result.value = name.DefaultValue;
		return false;
	}
	public function GetProperty<T>(name:PropertyKey<T>, ignoreBuffs:Bool = false):Null<T>
	{
		var box:{value:Dynamic} = {value: null};
		if (TryGetProperty(name, box, ignoreBuffs))
		{
			return box.value;
		}
		return name.DefaultValue;
	}
	public function GetPropertyObject(name:IPropertyKey, ignoreBuffs:Bool = false):Dynamic
	{
		var box:{value:Dynamic} = {value: null};
		if (TryGetPropertyObject(name, box, ignoreBuffs))
		{
			return box.value;
		}
		return name.DefaultValue;
	}
	// #endregion

	// #region 后备缓存
	public function AddFallbackCache(key:IPropertyKey, value:Dynamic):Void
	{
		fallbackCaches.set(key.Key, value);
		fallbackKeyObjects.set(key.Key, key);
	}
	public function RemoveFallbackCache(key:IPropertyKey):Bool
	{
		fallbackKeyObjects.remove(key.Key);
		return fallbackCaches.remove(key.Key);
	}
	public function ClearFallbackCaches():Void
	{
		fallbackCaches.clear();
		fallbackKeyObjects.clear();
	}
	public function GetPropertyNames():Array<IPropertyKey>
	{
		return properties.GetPropertyNames();
	}
	// #endregion

	// #region 修改器
	public function UpdateAllModifiedProperties(triggersEvaluation:Bool):Void
	{
		for (provider in Providers)
		{
			for (key in provider.GetModifiedProperties())
			{
				var beforeValue = GetPropertyObject(key);
				UpdateModifiedPropertyObject(key, beforeValue, triggersEvaluation);
			}
		}
	}
	public function UpdateModifiedPropertyObject(name:IPropertyKey, beforeValue:Dynamic, triggersEvaluation:Bool = true):Void
	{
		var baseValue = GetPropertyObject(name, true);

		modifierContainerBuffer.resize(0);
		for (provider in Providers)
		{
			provider.GetModifiersForProperty(name, modifierContainerBuffer);
		}

		var value = baseValue;
		if (modifierContainerBuffer.length > 0)
		{
			value = PropertyCalculator.CalculateProperty(modifierContainerBuffer, baseValue);
			modifiedProperties.SetPropertyObject(name, value);
		}
		else
		{
			modifiedProperties.RemovePropertyObject(name);
		}
		CallPropertyChanged(name, beforeValue, value, triggersEvaluation);
	}
	public function UpdateModifiedProperty<T>(name:PropertyKey<T>, beforeValue:Null<T>, triggersEvaluation:Bool = true):Void
	{
		var baseValue = GetProperty(name, true);

		modifierContainerBuffer.resize(0);
		for (provider in Providers)
		{
			provider.GetModifiersForProperty(name, modifierContainerBuffer);
		}

		var value = baseValue;
		if (modifierContainerBuffer.length > 0)
		{
			value = PropertyCalculator.CalculateProperty(modifierContainerBuffer, baseValue);
			modifiedProperties.SetProperty(name, value);
		}
		else
		{
			modifiedProperties.RemoveProperty(name);
		}
		CallPropertyChanged(name, beforeValue, value, triggersEvaluation);
	}
	private function CallPropertyChanged(name:IPropertyKey, beforeValue:Dynamic, afterValue:Dynamic, triggersEvaluation:Bool):Void
	{
		RemoveFallbackCache(name);
		Target.OnPropertyChanged(name, beforeValue, afterValue, triggersEvaluation);
	}
	// #endregion

	// #region 序列化
	public function ToSerializable():SerializableModifiableProperties
	{
		var seri = new SerializableModifiableProperties();
		seri.properties = properties.ToSerializable();
		return seri;
	}
	public function LoadFromSerializable(seri:Null<SerializableModifiableProperties>):Void
	{
		if (seri != null)
		{
			properties.LoadFromSerializable(seri.properties);
		}
	}
	// #endregion

	function OnModifiedPropertyNeedsUpdateCallback(name:IPropertyKey):Void
	{
		var beforeValue = GetPropertyObject(name);
		UpdateModifiedPropertyObject(name, beforeValue);
	}

	public var Target(default, null):IModifiablePropertyTarget;
	public var Providers(default, null):Array<IModifierProvider>;
	private var fallbackCaches:Map<Int, Dynamic> = new Map();
	private var fallbackKeyObjects:Map<Int, IPropertyKey> = new Map();
	private var modifierContainerBuffer:Array<ModifierSourceItem> = [];
	private var properties:PropertyDictionary = new PropertyDictionary();
	private var modifiedProperties:PropertyDictionary = new PropertyDictionary();
}

// Ported from: Assets/Scripts/Engine/Level/Properties/ModifiableProperties.cs (class SerializableModifiableProperties)
@:rtti
class SerializableModifiableProperties
{
	public function new() {}

	public var properties:SerializablePropertyDictionary;
}

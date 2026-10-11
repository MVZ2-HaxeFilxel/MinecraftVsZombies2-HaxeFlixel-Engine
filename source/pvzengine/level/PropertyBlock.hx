// Ported from: Assets/Scripts/Engine/Level/Properties/PropertyBlock.cs
package pvzengine.level;

import pvzengine.IPropertyKey;
import pvzengine.PropertyKey;
import pvzengine.SerializablePropertyDictionary;
import pvzengine.level.ModifiableProperties;
import pvzengine.level.ModifiableProperties.SerializableModifiableProperties;
import pvzengine.modifiers.IModifierProvider;

// PORT-NOTE: C# 的私有构造器 PropertyBlock(ModifiableProperties) 与公开构造器
//   PropertyBlock(IModifiablePropertyTarget, params IModifierProvider[]) 在 Haxe 中合并：
//   首参为 ModifiableProperties 时走私有构造器分支（与 Entity 之外的既有调用点一致）。
// PORT-NOTE: C# `params IModifierProvider[] providers` → Haxe 第二个形参改为 Dynamic：
//   既可传单个 IModifierProvider（如 `new PropertyBlock(this, buffs)`），也可传数组。
class PropertyBlock
{
	public function new(containerOrProperties:Dynamic, ?providerArg:Dynamic)
	{
		if (Std.isOfType(containerOrProperties, ModifiableProperties))
		{
			modifiableProperties = cast containerOrProperties;
			return;
		}
		var container:IModifiablePropertyTarget = cast containerOrProperties;
		var providers:Array<IModifierProvider> = [];
		if (providerArg != null)
		{
			if (Std.isOfType(providerArg, Array))
				providers = cast providerArg;
			else
				providers = [cast providerArg];
		}
		modifiableProperties = new ModifiableProperties(container, providers);
	}

	// #region 可修改属性
	public function SetProperty<T>(name:PropertyKey<T>, value:Null<T>):Void
	{
		modifiableProperties.SetProperty(name, value);
	}
	public function SetPropertyObject(name:IPropertyKey, value:Dynamic):Void
	{
		modifiableProperties.SetPropertyObject(name, value);
	}
	public function GetProperty<T>(name:PropertyKey<T>, ignoreBuffs:Bool = false):Null<T>
	{
		return modifiableProperties.GetProperty(name, ignoreBuffs);
	}
	public function GetPropertyObject(name:IPropertyKey, ignoreBuffs:Bool = false):Dynamic
	{
		return modifiableProperties.GetPropertyObject(name, ignoreBuffs);
	}
	public function TryGetProperty<T>(name:PropertyKey<T>, value:{value:Dynamic}, ignoreBuffs:Bool = false):Bool
	{
		return modifiableProperties.TryGetProperty(name, value, ignoreBuffs);
	}
	public function RemoveProperty(name:IPropertyKey):Bool
	{
		return modifiableProperties.RemoveProperty(name);
	}
	public function GetPropertyNames():Array<IPropertyKey>
	{
		return modifiableProperties.GetPropertyNames();
	}
	public function UpdateAllModifiedProperties(triggersEvaluation:Bool):Void
	{
		modifiableProperties.UpdateAllModifiedProperties(triggersEvaluation);
	}
	// #endregion

	// #region 后备缓存
	public function ClearFallbackCaches():Void
	{
		modifiableProperties.ClearFallbackCaches();
	}
	// #endregion

	// #region 序列化
	public function ToSerializable():SerializablePropertyBlock
	{
		var seri = new SerializablePropertyBlock();
		seri.modifiable = modifiableProperties.ToSerializable();
		return seri;
	}
	public function LoadFromSerializable(seri:Null<SerializablePropertyBlock>):Void
	{
		modifiableProperties.LoadFromSerializable(seri != null ? seri.modifiable : null);
	}
	// #endregion

	private var modifiableProperties:ModifiableProperties;
}

// Ported from: Assets/Scripts/Engine/Level/Properties/PropertyBlock.cs (class SerializablePropertyBlock)
@:rtti
class SerializablePropertyBlock
{
	public function new() {}

	public var modifiable:SerializableModifiableProperties;
}

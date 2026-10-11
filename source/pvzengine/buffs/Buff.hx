// Ported from: Assets/Scripts/Engine/Level/Buffs/Buff.cs
// Ported from: Assets/Scripts/Engine/Level/Buffs/Buff_Aura.cs
// Ported from: Assets/Scripts/Engine/Level/Buffs/Buff_Modifiers.cs
// Ported from: Assets/Scripts/Engine/Level/Buffs/Buff_Properties.cs
// PORT-NOTE: C# 中 Buff 为 partial class（4 个文件），按 PORTING.md「partial class 合并为一个类文件」合并到本文件。
// PORT-NOTE: C# 显式接口实现（LevelEngine ILevelObject.GetLevel() 等）在 Haxe 中为普通公开方法。
// PORT-NOTE: C# event Action<Buff, IPropertyKey>? OnPropertyChanged → FlxTypedSignal<Buff->IPropertyKey->Void>，
//   += / -= 改为 add / remove，Invoke 改为 dispatch（与上层 EntityController 对 OnModelInsertion* 的调用形式一致）。
package pvzengine.buffs;

import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Int64;
import pvzengine.IPropertyKey;
import pvzengine.NamespaceID;
import pvzengine.PropertyDictionary;
import pvzengine.PropertyKey;
import pvzengine.auras.AuraEffect;
import pvzengine.auras.AuraEffectDefinition;
import pvzengine.auras.AuraEffectList;
import pvzengine.auras.IAuraSource;
import pvzengine.base.MissingDefinitionException;
import pvzengine.entities.Entity;
import pvzengine.level.ILevelObject;
import pvzengine.level.LevelEngine;
import pvzengine.models.IModelInterface;
import pvzengine.modifiers.IModifierSource;
import pvzengine.modifiers.PropertyModifier;
import pvzengine.seedpacks.SeedPack;
using pvzengine.buffs.BuffTargetExt;
using pvzengine.ContentProviderHelper;
import unity.Debug;
import unity.UnityObject;

@:using(pvzengine.buffs.EngineBuffProps)
class Buff implements IAuraSource implements IModifierSource
{
	// #region 构造器
	public function new(level:LevelEngine, definition:BuffDefinition, id:Int64)
	{
		ID = id;
		Level = level;
		Definition = definition;
		CreateAuraEffects();
		Definition.OnCreate(this);
	}
	// #endregion

	// #region 生命周期
	// C#: internal void AddToTarget(IBuffTarget target)
	public function AddToTarget(target:IBuffTarget):Void
	{
		if (Target != null)
			return;
		Target = target;
		for (modifier in GetModifiers())
		{
			modifier.PostAdd(this, target);
		}
		Level.IncreaseLevelObjectChildReference(Target, this);
		Definition.PostAdd(this);
	}
	public function Update():Void
	{
		if (Definition != null)
			Definition.PostUpdate(this);
		UpdateAuras();
	}
	// C#: internal void RemoveFromTarget()
	public function RemoveFromTarget():Void
	{
		if (Target == null)
			return;
		for (modifier in GetModifiers())
		{
			modifier.PostRemove(this, Target);
		}
		Level.DecreaseLevelObjectChildReference(Target, this);
		Definition.PostRemove(this);
		Target = null;
	}
	public function Remove():Void
	{
		if (Target == null)
			return;
		Target.RemoveBuff(this);
	}
	// #endregion

	// #region 模型
	public function GetModelInsertions():Array<ModelInsertion>
	{
		return Definition.GetModelInsertions();
	}
	public function GetInsertedModel(key:NamespaceID):Null<IModelInterface>
	{
		// C#: if (Target is IModeledBuffTarget modeled) return modeled.GetInsertedModel(key);
		if (Std.isOfType(Target, IModeledBuffTarget))
		{
			var modeled:IModeledBuffTarget = cast Target;
			return modeled.GetInsertedModel(key);
		}
		return null;
	}
	// #endregion

	// #region 源
	public function GetEntity():Null<Entity>
	{
		return Target != null ? Target.GetEntity() : null;
	}
	public function GetSeedPack():Null<SeedPack>
	{
		// C#: return Target as SeedPack;
		return Std.isOfType(Target, SeedPack) ? cast Target : null;
	}
	// #endregion

	// #region 杂项
	// PORT-NOTE: C# 的 override ToString() 在 Haxe 中无父类可覆盖，去掉 override 关键字。
	public function toString():String
	{
		return 'Buff_${ID}(${Definition})';
	}
	// #endregion

	// #region 序列化
	public function ToSerializable():SerializableBuff
	{
		var seri = new SerializableBuff();
		seri.id = ID;
		seri.definitionID = Definition.GetID();
		WritePropertiesToSerializable(seri);
		WriteAurasToSerializable(seri);
		return seri;
	}
	public static function CreateFromSerializable(seri:SerializableBuff, level:LevelEngine, target:IBuffTarget):Null<Buff>
	{
		var definition = level.Content.GetBuffDefinition(seri.definitionID);
		if (definition == null)
		{
			var exception = new MissingDefinitionException('Trying to deserialize a buff with missing definition ${seri.definitionID}.');
			Debug.LogException(exception);
			return null;
		}
		var buff = new Buff(level, definition, seri.id);
		buff.Target = target;
		buff.InitFromSerializable(seri);
		return buff;
	}
	private function InitFromSerializable(seri:SerializableBuff):Void
	{
		InitPropertiesFromSerializable(seri);
	}
	public function LoadFromSerializable(seri:SerializableBuff):Void
	{
		LoadAurasFromSerializable(seri);
	}
	// #endregion

	// #region ILevelObject接口实现
	public function GetLevel():LevelEngine
	{
		return Level;
	}
	public function Exists():Bool
	{
		return Target != null && unity.UnityObject.exists(Target);
	}
	public function OnAddToLevel(level:LevelEngine):Void
	{
		auras.PostAdd();
	}
	public function OnRemoveFromLevel(level:LevelEngine):Void
	{
		auras.PostRemove();
	}
	public function GetChildrenObjects():Array<ILevelObject>
	{
		// C#: yield break;
		return [];
	}
	// #endregion

	// ===================== Buff_Aura.cs =====================
	private function CreateAuraEffects():Void
	{
		var auraDefs = Definition.GetAuras();
		for (i in 0...auraDefs.length)
		{
			var auraDef = auraDefs[i];
			auras.Add(Level, new AuraEffect(auraDef, i, this));
		}
	}
	private function UpdateAuras():Void
	{
		auras.Update();
	}

	// #region 获取
	// PORT-NOTE: C# AuraEffectList.Get<T>() 与 Get(AuraEffectDefinition) 为重载，Haxe 不支持重载，
	// 泛型版在移植层命名为 GetOfType（构造时把类对象作为参数传入）。调用点无法书写显式类型参数，
	// 与上层 mvz2logic.artifacts.Artifact.GetAuraEffect 保持一致的调用形式（省略类型参数）。
	public function GetAuraEffect<T:AuraEffectDefinition>():AuraEffect
	{
		return auras.GetOfType();
	}
	public function GetAuraEffects():Array<AuraEffect>
	{
		return auras.GetAll();
	}
	// #endregion

	// #region 序列化
	private function WriteAurasToSerializable(seri:SerializableBuff):Void
	{
		seri.auras = [for (a in auras.GetAll()) a.ToSerializable()];
	}
	private function LoadAurasFromSerializable(seri:SerializableBuff):Void
	{
		if (seri.auras == null)
			return;
		auras.LoadFromSerializable(Level, seri.auras);
	}
	// #endregion

	// #region 属性字段
	private var auras:AuraEffectList = new AuraEffectList();
	// #endregion

	// ===================== Buff_Modifiers.cs =====================
	public function GetModifiers():Array<PropertyModifier>
	{
		return Definition.GetModifiers();
	}
	// PORT-NOTE: C# 重载 GetModifiers(IPropertyKey)（Haxe 不支持重载）在移植层命名为 GetModifiersForProperty。
	public function GetModifiersForProperty(propName:IPropertyKey):Array<PropertyModifier>
	{
		return Definition.GetModifiersForProperty(propName);
	}
	// PORT-NOTE: C# 显式实现 IModifierSource.GetProperty<T>(PropertyKey<T>) 直接转发到公开的
	// GetProperty<T>，Haxe 中接口方法由 Buff_Properties 区域中的同名公开方法满足，无需重复声明。

	// ===================== Buff_Properties.cs =====================
	public function GetProperty<T>(name:PropertyKey<T>):Null<T>
	{
		return propertyDict.GetProperty(name);
	}
	public function SetProperty<T>(name:PropertyKey<T>, value:Null<T>):Void
	{
		if (propertyDict.SetProperty(name, value))
		{
			OnPropertyChanged.dispatch(this, name);
		}
	}
	private function WritePropertiesToSerializable(seri:SerializableBuff):Void
	{
		seri.propertyDict = propertyDict.ToSerializable();
	}
	private function InitPropertiesFromSerializable(seri:SerializableBuff):Void
	{
		propertyDict.LoadFromSerializable(seri.propertyDict);
	}
	public var OnPropertyChanged:FlxTypedSignal<Buff->IPropertyKey->Void> = new FlxTypedSignal();

	private var propertyDict:PropertyDictionary = new PropertyDictionary();

	// #region 属性字段
	public var ID(default, null):Int64;
	public var Level(default, null):LevelEngine;
	public var Definition(default, null):BuffDefinition;
	public var IsFromAura:Bool = false;
	public var Target(default, null):Null<IBuffTarget>;
	// #endregion
}

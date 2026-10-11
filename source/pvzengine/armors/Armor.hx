// Ported from: Assets/Scripts/Engine/Level/Armors/Armor.cs
// Ported from: Assets/Scripts/Engine/Level/Armors/Armor_Aura.cs
// Ported from: Assets/Scripts/Engine/Level/Armors/Armor_Buff.cs
// Ported from: Assets/Scripts/Engine/Level/Armors/Armor_Properties.cs
// PORT-NOTE: C# 中 Armor 为 partial class（4 个文件），按 PORTING.md「partial class 合并为一个类文件」合并到本文件。
// PORT-NOTE: C# 显式接口实现（LevelEngine ILevelObject.GetLevel()、bool IModifiablePropertyTarget.GetFallbackProperty(...) 等）
//   在 Haxe 中为普通公开方法；out 参数按工程约定改为引用容器 {value:Dynamic}（见 pvzengine.level.IModifiablePropertyTarget）。
// PORT-NOTE: C# 有两个构造函数（private Armor() 与 public Armor(Entity, NamespaceID, ArmorDefinition)），
//   Haxe 不支持重载，合并为可选参数：new Armor() 等价于 private Armor()。
// PORT-NOTE: C# 的 static Exists(Armor?) 与 ILevelObject 的实例方法 Exists() 在 Haxe 中同名冲突
//   （Haxe 不允许同一个类同时存在同名静态与实例字段），实例方法为接口契约所必需，故静态版更名为 ExistsArmor。
//   既有调用点（6 处，如 Armor.Exists(armor)）需在整合阶段改为 Armor.ExistsArmor(...) 或 EngineArmorExt.Exists(...)。
// PORT-NOTE: 既有上层调用点把若干 C# 扩展方法当作 Armor 的实例方法调用（且这些文件没有 `using`），
//   见文件末尾「兼容转发」区域（GetTint/GetColorOffset/GetMaxHealth/GetShellDefinition/SetModelProperty/
//   AddBuff/HasBuff/RemoveBuffs），这些转发方法同时保留 C# 的静态扩展方法形式。
package pvzengine.armors;

import haxe.Int64;
import pvzengine.IPropertyKey;
import pvzengine.NamespaceID;
import pvzengine.PropertyKey;
import pvzengine.auras.AuraEffect;
import pvzengine.auras.AuraEffectDefinition;
import pvzengine.auras.AuraEffectList;
import pvzengine.auras.IAuraSource;
import pvzengine.base.MissingDefinitionException;
import pvzengine.base.MissingSerializeDataException;
import pvzengine.buffs.Buff;
import pvzengine.buffs.BuffList;
import pvzengine.buffs.BuffReference;
import pvzengine.buffs.BuffReference.BuffReferenceArmor;
import pvzengine.buffs.BuffTargetExt;
import pvzengine.buffs.IBuffList;
import pvzengine.buffs.IBuffTarget;
import pvzengine.buffs.IModeledBuffTarget;
import pvzengine.collisions.ColliderConstructor;
import pvzengine.damages.ArmorDestroyInfo;
import pvzengine.damages.DamageEffectList;
import pvzengine.entities.Entity;
import pvzengine.level.ILevelObject;
import pvzengine.level.IModifiablePropertyTarget;
import pvzengine.level.LevelEngine;
import pvzengine.level.PropertyBlock;
// PORT-NOTE: C# 中 SerializablePropertyBlock 与 PropertyBlock 同处 PropertyBlock.cs，
//   移植层为 pvzengine.level.PropertyBlock 模块的子类型，import 需写模块路径。
import pvzengine.level.PropertyBlock.SerializablePropertyBlock;
import pvzengine.models.IModelInterface;
import pvzengine.shells.ShellDefinition;
import tools.GenericHelper;
import unity.Color;
import unity.Mathf;
import unity.UnityObject;
using pvzengine.ContentProviderHelper;

// PORT-NOTE: 既有上层调用点把 EngineArmorProps / EngineArmorExt / BuffTargetExt 的扩展方法当作 Armor 的实例方法
//   调用（armor.GetMaxHealth() / armor.AddBuff(...) 等，且这些文件没有 `using`），按本工程既有做法
//   （pvzengine/entities/Entity.hx、pvzengine/seedpacks/SeedPack.hx）用 @:using 在类型上引入这些静态扩展。
@:using(pvzengine.armors.EngineArmorProps)
@:using(pvzengine.armors.EngineArmorExt)
@:using(pvzengine.buffs.BuffTargetExt)
class Armor implements IModifiablePropertyTarget implements IAuraSource implements IModeledBuffTarget
{
	// #region 构造器
	public function new(?owner:Entity, ?slot:NamespaceID, ?definition:ArmorDefinition)
	{
		Owner = owner;
		Slot = slot;
		Definition = definition;

		properties = new PropertyBlock(this, [buffs]);
		InitBuffEvents();

		if (definition != null)
		{
			Health = this.GetMaxHealth();
			CreateAuraEffects();
		}
	}
	// #endregion

	// #region 生命周期
	public function Update():Void
	{
		Health = Mathf.Min(Health, this.GetMaxHealth());
		if (Definition != null)
			Definition.PostUpdate(this);
		UpdateAuras();
		UpdateBuffs();
	}
	public function Destroy(?result:ArmorDestroyInfo)
	{
		if (result == null)
		{
			result = new ArmorDestroyInfo(Owner, this, Slot, new DamageEffectList(), null, null);
		}
		Owner.DestroyArmor(Slot, result);
	}
	// #endregion

	// #region 碰撞
	public function GetColliderConstructors(entity:Entity, slot:NamespaceID):Array<ColliderConstructor>
	{
		return [for (constructor in Definition.GetColliderConstructors(entity, slot)) constructor];
	}
	// #endregion

	// #region 模型
	public function GetModelInterface():Null<IModelInterface>
	{
		var key = EngineArmorExt.GetModelKeyOfArmorSlot(Slot);
		return Owner.GetChildModel(key);
	}
	// C#: IModeledBuffTarget.GetInsertedModel(NamespaceID key) => this.GetChildModel(key);
	// PORT-NOTE: C# 的接口默认实现在 Haxe 中必须由实现类提供（与 pvzengine.seedpacks.SeedPack、
	//   pvzengine.grids.LawnGrid 的移植写法一致）。
	public function GetInsertedModel(key:NamespaceID):Null<IModelInterface>
	{
		var model = GetModelInterface();
		return model != null ? model.GetChildModel(key) : null;
	}
	// #endregion

	// #region 序列化
	public function ToSerializable():SerializableArmor
	{
		var seri = new SerializableArmor();
		seri.health = Health;
		seri.slot = Slot;
		seri.definitionID = Definition.GetID();
		WriteBuffsToSerializable(seri);
		WriteAurasToSerializable(seri);
		WritePropertiesToSerializable(seri);
		return seri;
	}
	public static function CreateFromSerializable(seri:SerializableArmor, owner:Entity):Null<Armor>
	{
		var definition = owner.Level.Content.GetArmorDefinition(seri.definitionID);
		if (definition == null)
		{
			var exception = new MissingDefinitionException('Trying to deserialize an armor with missing definition ${seri.definitionID}.');
			unity.Debug.LogException(exception);
			return null;
		}
		if (!NamespaceID.IsValid(seri.slot))
		{
			// C#: throw MissingSerializeDataException.Property<SerializableArmor>(nameof(seri.slot));
			// PORT-NOTE: 移植层 Property(propertyName) 不再能取到 typeof(T).Name，调用点需传入完整属性名。
			throw MissingSerializeDataException.Property('SerializableArmor.slot');
		}
		var armor = new Armor();
		armor.Owner = owner;
		armor.Definition = definition;
		armor.Slot = seri.slot;
		armor.Health = seri.health;
		armor.CreateAuraEffects();
		armor.InitFromSerializable(seri);
		return armor;
	}
	private function InitFromSerializable(seri:SerializableArmor):Void
	{
		InitBuffsFromSerializable(seri);
		InitPropertiesFromSerializable(seri);
	}
	public function LoadFromSerializable(seri:SerializableArmor):Void
	{
		LoadBuffsFromSerializable(seri);
		LoadAurasFromSerializable(seri);
		UpdateAllBuffedProperties(false);
	}
	// #endregion

	// #region 杂项
	// PORT-NOTE: C# 为 static bool Exists([NotNullWhen(true)] Armor? armor)，因与实例方法 Exists() 同名冲突而更名。
	public static function ExistsArmor(armor:Null<Armor>):Bool
	{
		return armor != null && armor.Owner != null && armor.Definition != null && armor.Health > 0;
	}

	// PORT-NOTE: C# 的 override ToString() 在 Haxe 中无父类可覆盖，去掉 override 关键字。
	public function toString():String
	{
		return 'Armor_${Definition}';
	}
	// #endregion

	// #region ILevelObject接口实现
	public function GetLevel():LevelEngine
	{
		return Level;
	}
	public function GetEntity():Null<Entity>
	{
		return Owner;
	}
	public function Exists():Bool
	{
		return Owner != null && unity.UnityObject.exists(Owner) && Owner.IsEquippingArmor(this);
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
		return [for (buff in buffs) buff];
	}
	// #endregion

	// ===================== Armor_Aura.cs =====================
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
	// PORT-NOTE: C# AuraEffectList.Get<T>() 与 Get(AuraEffectDefinition) 为重载，泛型版在移植层命名为 GetOfType
	//   （与上层 mvz2logic.artifacts.Artifact.GetAuraEffect 的约定一致）。
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
	private function WriteAurasToSerializable(seri:SerializableArmor):Void
	{
		seri.auras = [for (a in auras.GetAll()) a.ToSerializable()];
	}
	private function LoadAurasFromSerializable(seri:SerializableArmor):Void
	{
		if (seri.auras == null)
			return;
		auras.LoadFromSerializable(Level, seri.auras);
	}
	// #endregion

	// ===================== Armor_Buff.cs =====================
	private function UpdateBuffs():Void
	{
		buffs.Update();
	}

	// #region 增益
	public function GetBuffReference(buff:Buff):BuffReference
	{
		return new BuffReferenceArmor(Owner.ID, Slot, buff.ID);
	}
	private function InitBuffEvents():Void
	{
	}
	// #endregion

	private function WriteBuffsToSerializable(seri:SerializableArmor):Void
	{
		seri.buffs = buffs.ToSerializable();
	}
	private function InitBuffsFromSerializable(seri:SerializableArmor):Void
	{
		buffs.InitFromSerializable(seri.buffs, Level, this);
	}
	private function LoadBuffsFromSerializable(seri:SerializableArmor):Void
	{
		if (seri.buffs != null)
			buffs.LoadFromSerializable(seri.buffs);
	}

	// ===================== Armor_Properties.cs =====================
	// #region 属性
	public function GetProperty<T>(name:PropertyKey<T>, ignoreBuffs:Bool = false):Null<T>
	{
		return properties.GetProperty(name, ignoreBuffs);
	}
	public function SetProperty<T>(name:PropertyKey<T>, value:Null<T>):Void
	{
		properties.SetProperty(name, value);
	}
	private function UpdateAllBuffedProperties(triggersEvaluation:Bool):Void
	{
		properties.UpdateAllModifiedProperties(triggersEvaluation);
	}

	// C#: bool IModifiablePropertyTarget.GetFallbackProperty(IPropertyKey name, out object? value)
	// PORT-NOTE: out 参数按工程约定改为引用容器；注意 Haxe 的类型语法为 {value:Dynamic}（{var value:Dynamic}
	//   是非法类型表达式，pvzengine.level.IModifiablePropertyTarget 与本方法需保持一致）。
	public function GetFallbackProperty(name:IPropertyKey, value:{value:Dynamic}):Bool
	{
		if (Definition != null)
		{
			if (Definition.TryGetPropertyObject(name, value))
			{
				return true;
			}
		}
		value.value = null;
		return false;
	}
	// C#: void IModifiablePropertyTarget.OnPropertyChanged(IPropertyKey name, object? beforeValue, object? afterValue, bool triggersEvaluation)
	public function OnPropertyChanged(name:IPropertyKey, beforeValue:Dynamic, afterValue:Dynamic, triggersEvaluation:Bool):Void
	{
		if (triggersEvaluation)
		{
			if (EngineArmorProps.MAX_HEALTH.Equals(name))
			{
				var before:Float = GenericHelper.ToGeneric(beforeValue);
				var after:Float = GenericHelper.ToGeneric(afterValue);
				Health = Mathf.Min(after, Health * (after / before));
			}
		}
	}
	// #endregion

	public function WritePropertiesToSerializable(seri:SerializableArmor):Void
	{
		seri.properties = properties.ToSerializable();
	}
	public function InitPropertiesFromSerializable(seri:SerializableArmor):Void
	{
		properties.LoadFromSerializable(seri.properties);
	}

	// ===================== 扩展方法（@:using） =====================
	// PORT-NOTE: C# 中 EngineArmorProps / EngineArmorExt / BuffTargetExt 的扩展方法被既有上层调用点当作
	//   Armor 的实例方法调用（armor.GetMaxHealth()、armor.AddBuff(...) 等，这些文件没有 `using`），
	//   故按本工程既有做法（见 pvzengine/entities/Entity.hx、pvzengine/seedpacks/SeedPack.hx 的 @:using）
	//   在类声明上挂 @:using 引入这些静态扩展（C# 的静态形式保持不变，未新增方法）。
	//   HasModelExt（C# 全局命名空间，移植路径待定）的 SetModelProperty 由下方等价方法提供。
	public function SetModelProperty(name:String, value:Dynamic):Void
	{
		// C#: HasModelExt.SetModelProperty(this IHasModel self, string name, object? value)
		var modelInterface = GetModelInterface();
		if (modelInterface != null)
			modelInterface.SetModelProperty(name, value);
	}

	// #region 属性字段
	public var Level(get, never):LevelEngine;
	private function get_Level():LevelEngine
	{
		return Owner.Level;
	}
	public var Owner:Entity;
	public var Slot:NamespaceID;
	public var Definition(default, null):ArmorDefinition;
	public var Health:Float;
	// #endregion

	// #region 增益字段
	// C#: IBuffList IBuffTarget.Buffs => buffs;
	public var Buffs(get, never):IBuffList;
	private function get_Buffs():IBuffList
	{
		return buffs;
	}
	private var buffs:BuffList = new BuffList();
	// #endregion

	// #region 属性字段
	private var properties:PropertyBlock;
	// #endregion

	// #region 光环字段
	private var auras:AuraEffectList = new AuraEffectList();
	// #endregion
}

// Ported from: Assets/Scripts/Engine/Level/Buffs/BuffReference.cs
// PORT-NOTE: C# [Serializable] → Haxe 序列化由 mvz2logic.serialization.SerializeHelper 按类名注册处理
//   （SerializeHelper.hx 注册了 PVZEngine.Buffs.BuffReference* 等名字），本文件保留公共字段与继承层次。
// PORT-NOTE: C# 构造函数 BuffReferenceEntity(long id, long buffId) 等 → Haxe 构造函数（签名不变，long → Int64）。
package pvzengine.buffs;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.level.LevelEngine;
using pvzengine.buffs.BuffTargetExt;

// abstract
@:rtti
class BuffReference
{
	public function new(buffId:Int64)
	{
		this.buffId = buffId;
	}
	public function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		// abstract
		throw 'abstract';
	}
	public function GetBuff(level:LevelEngine):Null<Buff>
	{
		var target = GetTarget(level);
		if (target == null)
			return null;
		return target.GetBuff(buffId);
	}
	public var buffId:Int64;
}

@:rtti
class BuffReferenceEntity extends BuffReference
{
	public function new(id:Int64, buffId:Int64)
	{
		super(buffId);
		entityID = id;
	}
	public override function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		return level.FindEntityByID(entityID);
	}
	public var entityID:Int64;
}

@:rtti
class BuffReferenceArmor extends BuffReference
{
	public function new(id:Int64, armorSlot:NamespaceID, buffId:Int64)
	{
		super(buffId);
		entityID = id;
		this.armorSlot = armorSlot;
	}
	public override function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		var entity = level.FindEntityByID(entityID);
		return entity != null ? entity.GetArmorAtSlot(armorSlot) : null;
	}
	public var entityID:Int64;
	public var armorSlot:NamespaceID;
}

@:rtti
class BuffReferenceLevel extends BuffReference
{
	public function new(buffId:Int64)
	{
		super(buffId);
	}
	public override function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		return level;
	}
}

// abstract
@:rtti
class BuffReferenceSeedPack extends BuffReference
{
	public function new(seedId:Int64, buffId:Int64)
	{
		super(buffId);
		seedID = seedId;
	}
	public var seedID:Int64;
}

@:rtti
class BuffReferenceClassicSeedPack extends BuffReferenceSeedPack
{
	public function new(seedId:Int64, buffId:Int64)
	{
		super(seedId, buffId);
	}
	public override function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		return level.GetSeedPackByID(seedID);
	}
}

@:rtti
class BuffReferenceConveyorSeedPack extends BuffReferenceSeedPack
{
	public function new(seedId:Int64, buffId:Int64)
	{
		super(seedId, buffId);
	}
	public override function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		return level.GetConveyorSeedPackByID(seedID);
	}
}

@:rtti
class BuffReferenceLawnGrid extends BuffReference
{
	public function new(gridIndex:Int, buffId:Int64)
	{
		super(buffId);
		this.gridIndex = gridIndex;
	}
	public override function GetTarget(level:LevelEngine):Null<IBuffTarget>
	{
		// PORT-NOTE: C# 为 LevelEngine.GetGrid(int index) 重载；移植层 LevelEngine.GetGrid(a:Dynamic, ?lane:Int)
		//   在第二实参缺省时按索引查（见 pvzengine.level.LevelEngine.GetGrid 的 PORT-NOTE），故单实参调用等价。
		return level.GetGrid(gridIndex);
	}
	public var gridIndex:Int;
}

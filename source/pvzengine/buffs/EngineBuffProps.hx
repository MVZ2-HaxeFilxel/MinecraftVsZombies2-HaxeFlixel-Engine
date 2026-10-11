// Ported from: Assets/Scripts/Engine/Level/Buffs/EngineBuffProps.cs
// PORT-NOTE: C# [PropertyRegistryRegion(PropertyRegions.buff)] → @:propertyRegistryRegion（与上层
//   mvz2/gamecontent/buffs/VanillaBuffProps.hx 的约定一致）。
// PORT-NOTE: C# PropertyMeta<T> 到 PropertyKey<T> 的隐式转换由移植层 pvzengine.PropertyMeta 的转换定义承担，
//   调用点直接传 PropertyMeta<T>（见 mvz2/modding/ModLoader.hx: buffDefinition.SetProperty(EngineBuffProps.POLARITY, polarity)）。
// PORT-NOTE: C# 的扩展方法 GetClarity(this Buff) / IsPolarity(this Buff) 移植为静态方法（首参数为 Buff），
//   可用 `using pvzengine.buffs.EngineBuffProps;` 以实例形式调用。C# 中 IsPolarity 的形参名就是 entity（原文如此）。
package pvzengine.buffs;

import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;

@:propertyRegistryRegion(PropertyRegions.buff)
class EngineBuffProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	// #region 清晰度
	public static var BUFF_LEVEL:PropertyMeta<Int> = Get("clarity", 0);
	public static function GetClarity(buff:Buff):Int
	{
		return buff.GetProperty(BUFF_LEVEL);
	}
	// #endregion

	// #region 极性
	public static var POLARITY:PropertyMeta<Int> = Get("polarity", 0);
	public static function IsPolarity(entity:Buff):Int
	{
		return entity.GetProperty(POLARITY);
	}
	// #endregion
}

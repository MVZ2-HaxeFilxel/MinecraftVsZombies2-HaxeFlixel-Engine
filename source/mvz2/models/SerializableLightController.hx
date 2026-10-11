// Ported from: Assets/Scripts/View/Models/Light/SerializableLightController.cs
package mvz2.models;

import unity.Color;
import unity.Vector2;

@:rtti
class SerializableLightController
{
	public var scale:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var color:Color = new Color(0, 0, 0, 0); // PORT-NOTE: C# Color 为 struct，default 为 (0,0,0,0) 透明黑；显式初始化避免 abstract-over-class 的 null 解引用

	public function new() {}
}

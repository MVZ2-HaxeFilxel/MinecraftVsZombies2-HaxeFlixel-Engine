package unity.ui;

import unity.Color;

// Minimal UnityEngine.UI.Shadow shim.
class Shadow extends UIBehaviour {
    public var effectColor:Color = new Color(0, 0, 0, 0.5);
    public var effectDistance:unity.Vector2 = new unity.Vector2(1, -1);
    public var useGraphicAlpha:Bool = true;

    public function new() {
        super();
    }
    public function ApplyShadow(verts:Array<Dynamic>, start:Int, end:Int, x:Float, y:Float):Void {}
}

// Minimal UnityEngine.UI.Outline shim.
class Outline extends Shadow {
    public function new() {
        super();
    }
}

// PORT-NOTE: UnityEngine.UI.LayoutRebuilder 的兼容入口已并入真正的布局引擎
// unity/ui/LayoutRebuilder.hx（本文件再声明同名类会与该模块的类型冲突）。

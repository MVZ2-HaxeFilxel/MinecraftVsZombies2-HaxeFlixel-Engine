// Ported from: Assets/Scripts/MVZ2/Models/Components/LineRendererPointLocker.cs
package mvz2.models;

import tools.ObjectExtensions;
import unity.LineRenderer;
import unity.Transform;
import unity.UnityObject;

// [ExecuteAlways]
// [RequireComponent(typeof(LineRenderer))]
class LineRendererPointLocker extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        super.UpdateFrame(deltaTime);
        var renderer = line;
        if (!unity.UnityObject.exists(renderer) || index < 0 || index >= renderer.positionCount)
            return;
        if (target == null)
            return;
        var pos = target.position;
        if (!renderer.useWorldSpace) {
            pos = renderer.transform.InverseTransformPoint(pos);
        }
        renderer.SetPosition(index, pos);
    }
    private var line(get, never):LineRenderer;
    function get_line():LineRenderer {
        if (!unity.UnityObject.exists(_line)) {
            _line = GetComponent(LineRenderer);
        }
        return _line;
    }
    private var _line:LineRenderer;
    private var index:Int;
    private var target:Transform = null;
}

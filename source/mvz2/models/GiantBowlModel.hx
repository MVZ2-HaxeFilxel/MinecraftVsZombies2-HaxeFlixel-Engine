// Ported from: Assets/Scripts/MVZ2/Models/Components/Contraptions/GiantBowlModel.cs
package mvz2.models;

import mvz2.ui.ElementList;
import tools.ObjectExtensions;
import unity.Mathf;
import unity.Vector2;
import unity.Vector3;
import unity.UnityObject;

class GiantBowlModel extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        super.UpdateFrame(deltaTime);
        var count:Int = Model.GetProperty("Count");
        var angle:Float = Model.GetProperty("Angle");
        var radial:Float = Model.GetProperty("Radial");

        if (pointList.Count != count) {
            pointList.updateList(count);
        }
        var radius = Mathf.Lerp(minRadius, maxRadius, radial);
        for (i in 0...count) {
            var point = pointList.getElement(i);
            if (!unity.UnityObject.exists(point))
                continue;

            var off2D = Vector2.up.RotateClockwise(angle + i * (360 / count)) * radius;
            off2D.y *= circleAspect;
            point.transform.localPosition = new Vector3(off2D.x, off2D.y, 0);
        }
    }
    private var pointList:ElementList = null;
    private var maxRadius:Float = 0.64;
    private var minRadius:Float = 0.32;
    private var circleAspect:Float = 0.5;
}

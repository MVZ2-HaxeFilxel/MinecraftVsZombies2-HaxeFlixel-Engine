package unity;

// Minimal UnityEngine.RectTransform shim.
// PORT-NOTE: 字段（anchoredPosition/sizeDelta/anchorMin/anchorMax/pivot）已上移到
// Transform（见 Transform.hx 的 PORT-NOTE），本类仅保留 RectTransform 专属 API 与类型身份。
class RectTransform extends Transform {
    // Unity 的 RectTransform.rect（local 空间、原点在 pivot 的矩形）；由 sizeDelta/pivot 推出。
    public var rect(get, never):Rect;
    function get_rect():Rect {
        return new Rect(-pivot.x * sizeDelta.x, -pivot.y * sizeDelta.y, sizeDelta.x, sizeDelta.y);
    }

    public function new() {
        super();
    }

    // C#: public void SetSizeWithCurrentAnchors(RectTransform.Axis axis, float size)
    // PORT-NOTE: Unity 的界别枚举 RectTransform.Axis 在移植层由 mvz2.ui.LayoutSizeLimiter 自带一份
    // 同名同值（Horizontal=0 / Vertical=1）的 enum abstract。两份 enum abstract 之间没有隐式转换，
    // 为了让该调用点无需改动，形参放宽为 Dynamic（运行期仍按 0/1 分支）。
    public function SetSizeWithCurrentAnchors(axis:Dynamic, size:Float):Void {
        if (axis == 0) sizeDelta.x = size;
        else if (axis == 1) sizeDelta.y = size;
    }
    // C#: public void GetWorldCorners(Vector3[] fourCornersArray)
    public function GetWorldCorners(fourCornersArray:Array<Vector3>):Void {
        var r = rect;
        var m = localToWorldMatrix;
        fourCornersArray[0] = m.MultiplyPoint(new Vector3(r.xMin, r.yMin, 0));
        fourCornersArray[1] = m.MultiplyPoint(new Vector3(r.xMin, r.yMax, 0));
        fourCornersArray[2] = m.MultiplyPoint(new Vector3(r.xMax, r.yMax, 0));
        fourCornersArray[3] = m.MultiplyPoint(new Vector3(r.xMax, r.yMin, 0));
    }
}

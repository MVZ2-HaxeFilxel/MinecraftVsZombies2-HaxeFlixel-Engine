// Ported from: Assets/Scripts/MVZ2/Models/Components/SpriteSizeFitter.cs
package mvz2.models;

import tools.ObjectExtensions;
import unity.Mathf;
import unity.SpriteRenderer;
import unity.Vector2;
import unity.Vector3;
import unity.UnityObject;

// [ExecuteAlways]
// [RequireComponent(typeof(SpriteRenderer))]
class SpriteSizeFitter extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        super.UpdateFrame(deltaTime);
        var renderer = Renderer;
        if (!unity.UnityObject.exists(renderer))
            return;
        var spr = renderer.sprite;
        if (spr == null)
            return;
        var scale = 1.0;
        var sprSize = spr.rect.size; // PORT-NOTE: C# 为 spr.rect.size
        if (mode == SpriteFitMode.SmallerThanSize) {
            scale = Mathf.Min(1, Mathf.Min(maxSize.x / sprSize.x, maxSize.y / sprSize.y));
        } else if (mode == SpriteFitMode.FitSize) {
            scale = Mathf.Min(maxSize.x / sprSize.x, maxSize.y / sprSize.y);
        }
        renderer.transform.localScale = Vector3.one * scale;
    }
    public var Renderer(get, never):SpriteRenderer;
    function get_Renderer():SpriteRenderer {
        if (_sprRenderer == null) {
            _sprRenderer = GetComponent(SpriteRenderer);
        }
        return _sprRenderer;
    }
    private var _sprRenderer:SpriteRenderer;
    private var mode:SpriteFitMode = SpriteFitMode.SmallerThanSize;
    private var maxSize:Vector2 = new Vector2(64, 64);
}

enum abstract SpriteFitMode(Int) from Int to Int {
    var SmallerThanSize = 0;
    var FitSize = 1;
}

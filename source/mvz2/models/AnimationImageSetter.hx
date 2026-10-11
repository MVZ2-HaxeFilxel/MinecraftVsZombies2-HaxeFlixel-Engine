// Ported from: Assets/Scripts/MVZ2/Models/Utilities/AnimationImageSetter.cs
package mvz2.models;

import mvz2.managers.MainManager;
import tools.ObjectExtensions;
import unity.Mathf;
import unity.Sprite;
import unity.ui.Image;
import unity.UnityObject;

// [RequireComponent(typeof(Image))]
// [ExecuteAlways]
class AnimationImageSetter extends unity.MonoBehaviour {
    public function new() {
        super();
    }

    private function OnEnable():Void {
        SetSpriteIndex(index);
    }
    private function LateUpdate():Void {
        if (sprites != null && sprites.length > 0) {
            if (index != beforeIndex) {
                SetSpriteIndex(index);
            }
        }
    }

    public function SetSpritePercent(percent:Float):Void {
        if (sprites == null)
            return;
        SetSpriteIndex(Mathf.FloorToInt(percent * sprites.length));
    }

    public function SetSpriteIndex(i:Int):Void {
        if (sprites == null)
            return;
        index = Mathf.ClampInt(i, 0, sprites.length - 1);
        beforeIndex = index;
        var sprite = sprites[index];
        if (Main != null) {
            sprite = Main.GetFinalSpriteFromSprite(sprite);
        }
        Renderer.sprite = sprite;
    }
    private var Renderer(get, never):Image;
    function get_Renderer():Image {
        if (!unity.UnityObject.exists(image)) {
            image = GetComponent(Image);
        }
        return image;
    }
    private var Main(get, never):MainManager;
    function get_Main():MainManager return MainManager.Instance;
    private var image:Image;
    public var sprites:Array<Sprite>;
    private var beforeIndex:Int = -1;
    private var index:Int = 0;
}

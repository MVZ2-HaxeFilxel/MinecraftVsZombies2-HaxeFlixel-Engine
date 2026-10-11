// Ported from: Assets/Scripts/MVZ2/Models/Utilities/AnimationSpriteSetter.cs
package mvz2.models;

import mvz2.models.ModelComponent;
import Main;  // UNKNOWNIMPORT
import tools.ObjectExtensions;
import unity.Mathf;
import unity.Sprite;
import unity.SpriteRenderer;
import unity.UnityObject;

// [ExecuteAlways]
// [RequireComponent(typeof(SpriteRenderer))]
class AnimationSpriteSetter extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        super.UpdateFrame(deltaTime);
        UpdateSprites();
    }
    public function UpdateSprites():Void {
        if (sprites != null && sprites.length > 0) {
            if (index != beforeIndex || unity.Application.isEditor) {
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
    private var Renderer(get, never):SpriteRenderer;
    function get_Renderer():SpriteRenderer {
        if (!unity.UnityObject.exists(sprRenderer)) {
            sprRenderer = GetComponent(SpriteRenderer);
        }
        return sprRenderer;
    }
    private var sprRenderer:SpriteRenderer;
    public var sprites:Array<Sprite>;
    private var beforeIndex:Int = -1;
    private var index:Int = 0;
}

// Ported from: Assets/Scripts/MVZ2/Models/Components/SpriteSetters/SpriteSetter.cs
package mvz2.models;

import tools.ObjectExtensions;
import Main;  // UNKNOWNIMPORT
import unity.Mathf;
import unity.Sprite;
import unity.SpriteRenderer;
import unity.UnityObject;

// [RequireComponent(typeof(SpriteRenderer))]
// abstract
class SpriteSetter extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        if (sprites != null && sprites.length > 0) {
            var index = GetIndex();
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
        i = Mathf.ClampInt(i, 0, sprites.length - 1);
        beforeIndex = i;
        var sprite = sprites[i];
        if (Main != null) {
            sprite = Main.GetFinalSpriteFromSprite(sprite);
        }
        Renderer.sprite = sprite;
    }
    // abstract
    public function GetIndex():Int {
        throw "abstract";
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
}

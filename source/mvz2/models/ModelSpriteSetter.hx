// Ported from: Assets/Scripts/MVZ2/Models/Components/SpriteSetters/ModelSpriteSetter.cs
package mvz2.models;

import tools.ObjectExtensions;
import Main;  // UNKNOWNIMPORT
import unity.Sprite;
import unity.SpriteRenderer;
import unity.UnityObject;

// [RequireComponent(typeof(SpriteRenderer))]
class ModelSpriteSetter extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        if (sprite != beforeSprite || (unity.Application.isEditor && !unity.Application.isPlaying)) {
            if (Main != null) {
                beforeSprite = sprite;
                // PORT-NOTE: C# 局部变量名 `final` 在 Haxe 中是关键字，重命名为 finalSprite。
                var finalSprite = unity.UnityObject.exists(sprite) ? Main.GetFinalSpriteFromSprite(sprite) : null;
                Renderer.sprite = finalSprite;
            }
        }
    }
    private var Renderer(get, never):SpriteRenderer;
    function get_Renderer():SpriteRenderer {
        if (!unity.UnityObject.exists(sprRenderer)) {
            sprRenderer = GetComponent(SpriteRenderer);
        }
        return sprRenderer;
    }
    private var sprRenderer:SpriteRenderer;
    private var beforeSprite:Sprite;
    public var sprite:Sprite;
}

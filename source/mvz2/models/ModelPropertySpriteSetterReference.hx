// Ported from: Assets/Scripts/MVZ2/Models/Components/SpriteSetters/ModelPropertySpriteSetterReference.cs
package mvz2.models;

import mvz2logic.resources.SpriteReference;
import Main;  // UNKNOWNIMPORT
import tools.ObjectExtensions;
import unity.SpriteRenderer;
import unity.UnityObject;

// [RequireComponent(typeof(SpriteRenderer))]
class ModelPropertySpriteSetterReference extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        var reference = GetSpriteReference();
        if (reference != beforeReference || (unity.Application.isEditor && !unity.Application.isPlaying)) {
            if (Main != null) {
                beforeReference = reference;
                var sprite = Main.GetFinalSpriteFromRef(reference);
                Renderer.sprite = sprite;
            }
        }
    }
    public function GetSpriteReference():SpriteReference {
        if (propertyName == null || propertyName.length == 0)
            return null;
        return Model.GetProperty(propertyName);
    }
    private var Renderer(get, never):SpriteRenderer;
    function get_Renderer():SpriteRenderer {
        if (!unity.UnityObject.exists(sprRenderer)) {
            sprRenderer = GetComponent(SpriteRenderer);
        }
        return sprRenderer;
    }
    private var sprRenderer:SpriteRenderer;
    private var beforeReference:SpriteReference;
    public var propertyName:String;
}

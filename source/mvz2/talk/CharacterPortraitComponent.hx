// Ported from: Assets/Scripts/MVZ2/Talks/Portrait/CharacterPortraitComponent.cs
package mvz2.talk;
import mvz2.talk.CharacterPortraitComponentLayer.CharacterPortraitLayerViewData;  // IMPORTAUTO

import mvz2.ui.ElementList;
import tools.ObjectExtensions;
import unity.Camera;
import unity.RenderTexture;
import unity.UnityObject;

class CharacterPortraitComponent extends unity.MonoBehaviour {
    public function new() {
        super();
    }

    public function SetRenderTexture(renderTexture:RenderTexture):Void {
        renderCamera.targetTexture = renderTexture;
    }
    public function Render():Void {
        renderCamera.Render();
    }
    public function ChangeVariant(viewData:CharacterPortraitViewData):Void {
        layers.updateList(viewData.layers.length, function(i:Int, obj:unity.GameObject) {
            var layer = obj.GetComponent(CharacterPortraitComponentLayer);
            layer.UpdateLayer(viewData.layers[i]);
        });
    }
    public function DestroyGameObject():Void {
        if (unity.UnityObject.exists(gameObject))
            UnityObject.Destroy(gameObject);
    }
    public var renderCamera:Camera = null;
    public var layers:ElementList = null;
}

// C# 中为 MVZ2.Talk 的 CharacterPortraitViewData 结构体。
class CharacterPortraitViewData {
    public var width:Int;
    public var height:Int;
    public var layers:Array<CharacterPortraitLayerViewData>;

    public function new() {}
}

// Ported from: Assets/Scripts/MVZ2/Talks/Portrait/CharacterPortraitComponentLayer.cs
package mvz2.talk;

import tools.ObjectExtensions;
import unity.RectTransform;
import unity.Sprite;
import unity.Vector2;
import unity.ui.Image;
import unity.UnityObject;

class CharacterPortraitComponentLayer extends unity.MonoBehaviour {
    public function new() {
        super();
    }

    public function UpdateLayer(viewData:CharacterPortraitLayerViewData):Void {
        image.sprite = viewData.sprite;
        // PORT-NOTE: C# 中 Image.enabled 为 bool，隐式由 Sprite 转换；Haxe 显式判空。
        image.enabled = viewData.sprite != null;
        rectTransform.anchoredPosition = viewData.position;
        // PORT-NOTE: C# 为 `image.sprite.rect.size`；shim 的 Sprite 提供 rect，故按原逻辑取 rect.size。
        rectTransform.sizeDelta = unity.UnityObject.exists(image.sprite) ? image.sprite.rect.size : Vector2.zero;
    }
    public var rectTransform:RectTransform = null;
    public var image:Image = null;
}

// C# 中为 MVZ2.Talk 的 CharacterPortraitLayerViewData 结构体。
class CharacterPortraitLayerViewData {
    public var position:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    public var size:Vector2 = new Vector2(0, 0); // PORT-NOTE: C# Vector2 为 struct，默认 (0,0)；显式初始化避免 abstract-over-class 的 null 解引用
    public var sprite:Sprite;

    public function new() {
        position = new Vector2();
        size = new Vector2();
    }
}

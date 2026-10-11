// Ported from: Assets/Scripts/MVZ2/Talks/Portrait/CharacterPortrait.cs
package mvz2.talk;
import mvz2.talk.CharacterPortraitComponent.CharacterPortraitViewData;  // IMPORTAUTO

import tools.ObjectExtensions;
import unity.Graphics;
import unity.Mathf;
import unity.Rect;
import unity.RenderTexture;
import unity.Sprite;
import unity.Texture2D;
import unity.UnityObject;
import unity.Vector2;

class CharacterPortrait {
    public function new(component:CharacterPortraitComponent) {
        texture2d = new Texture2D(1, 1);
        this.component = component;
        component.gameObject.SetActive(false);
    }
    public function ChangeVariant(viewData:CharacterPortraitViewData):Void {
        var width = viewData.width;
        var height = viewData.height;

        var cameraRT = RenderTexture.GetTemporary(width, height);
        component.gameObject.SetActive(true);
        component.SetRenderTexture(cameraRT);
        component.ChangeVariant(viewData);
        component.Render();
        component.gameObject.SetActive(false);

        // PORT-NOTE: C# Mathf.Max(int,int) 返回 int；Haxe shim 无法重载，改用等价的 Mathf.MaxInt。
        var scaledWidth = Mathf.MaxInt(1, Mathf.CeilToInt(viewData.width * TextureScale));
        var scaledHeight = Mathf.MaxInt(1, Mathf.CeilToInt(viewData.height * TextureScale));
        var targetRT = cameraRT;
        if (TextureScale != 1) {
            var newTargetRT = RenderTexture.GetTemporary(scaledWidth, scaledHeight);
            Graphics.Blit(targetRT, newTargetRT);
            RenderTexture.ReleaseTemporary(targetRT);
            targetRT = newTargetRT;
        }
        texture2d.Reinitialize(scaledWidth, scaledHeight);

        var previous = RenderTexture.active;

        RenderTexture.active = targetRT;
        texture2d.ReadPixels(new Rect(0, 0, scaledWidth, scaledHeight), 0, 0);
        texture2d.Apply();
        RenderTexture.active = previous;

        RenderTexture.ReleaseTemporary(targetRT);


        if (unity.UnityObject.exists(sprite)) {
            UnityObject.Destroy(sprite);
            sprite = null;
        }
    }
    public function Dispose():Void {
        if (unity.UnityObject.exists(texture2d))
            UnityObject.Destroy(texture2d);
        if (unity.UnityObject.exists(sprite))
            UnityObject.Destroy(sprite);
        component.DestroyGameObject();
    }
    public function GetTexture2D():Texture2D {
        return texture2d;
    }
    public function GetSprite():Sprite {
        if (!unity.UnityObject.exists(sprite)) {
            sprite = Sprite.Create(texture2d, new Rect(0, 0, texture2d.width, texture2d.height), Vector2.one * 0.5);
        }
        return sprite;
    }
    public var TextureScale:Float = 1;

    private var texture2d:Texture2D;
    private var sprite:Sprite;
    private var component:CharacterPortraitComponent;
}

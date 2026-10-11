// Ported from: Assets/Scripts/MVZ2/Localization/ParticleTextureTranslator.cs
package mvz2.localization;
import mvz2.localization.TranslateComponentSprite.TranslateComponentSpriteMultiple;  // IMPORTAUTO
import unity.Component;  // UNKNOWNIMPORT

import mvz2.managers.MainManager;
import tools.ObjectExtensions;
import unity.ParticleSystem;
import unity.Sprite;
import unity.UnityObject;

// [RequireComponent(typeof(ParticleSystem))]
class ParticleTextureTranslator extends TranslateComponentSpriteMultiple<ParticleSystem> {
    public function new() {
        super(ParticleSystem);
    }

    override private function GetKeysInner():Array<Sprite> {
        if (!UnityObject.exists(Component))
            return null;
        var part = Component.textureSheetAnimation;
        var sprites = new Array<Sprite>();
        sprites.resize(part.spriteCount);
        for (i in 0...sprites.length) {
            sprites[i] = part.GetSprite(i);
        }
        return sprites;
    }
    override private function Translate(language:String):Void {
        super.Translate(language);
        if (!UnityObject.exists(Component))
            return;
        var part = Component.textureSheetAnimation;
        var sprites = Keys;
        if (sprites == null)
            return;
        for (i in 0...sprites.length) {
            // PORT-NOTE: C# 为 MainManager.GetFinalSprite(Sprite, string)（重载）；
            // managers 包的移植版将其重命名为 GetFinalSpriteLocalizedFromSprite。
            part.SetSprite(i, MainManager.Instance.GetFinalSpriteLocalizedFromSprite(sprites[i], language));
        }
    }
}

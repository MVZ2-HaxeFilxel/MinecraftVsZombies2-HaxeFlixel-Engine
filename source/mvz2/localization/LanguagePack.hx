// Ported from: Assets/Scripts/MVZ2/Localization/LanguagePack.cs
package mvz2.localization;

import ngettext.Catalog;
import pvzengine.NamespaceID;
import unity.Sprite;

class LanguagePack {
    public function new(key:String) {
        Key = key;
    }
    public function GetOrCreateLanguageAsset(lang:String):LanguageAssets {
        var asset = Lambda.find(assets, a -> a.language == lang);
        if (asset == null) {
            asset = new LanguageAssets(lang);
            assets.push(asset);
        }
        return asset;
    }
    public function GetLanguageAssets(lang:String):LanguageAssets {
        return Lambda.find(assets, a -> a.language == lang);
    }
    public function TryGetString(language:String, text:String, args:Array<Dynamic>):String {
        var asset = Lambda.find(assets, a -> a.language == language);
        if (asset == null)
            return null;
        for (catalog in asset.catalogs) {
            if (catalog.IsTranslationExist(text)) {
                return catalog.GetString(text, args);
            }
        }
        return null;
    }
    public function TryGetStringParticular(language:String, context:String, text:String, args:Array<Dynamic>):String {
        var asset = Lambda.find(assets, a -> a.language == language);
        if (asset == null)
            return null;
        for (catalog in asset.catalogs) {
            if (catalog.IsTranslationExist(context + "\u0004" + text)) {
                return catalog.GetParticularString(context, text, args);
            }
        }
        return null;
    }
    public function TryGetStringPlural(language:String, text:String, textPlural:String, n:haxe.Int64, args:Array<Dynamic>):String {
        var asset = Lambda.find(assets, a -> a.language == language);
        if (asset == null)
            return null;
        for (catalog in asset.catalogs) {
            if (catalog.IsTranslationExist(text)) {
                return catalog.GetPluralString(text, textPlural, n, args);
            }
        }
        return null;
    }
    public function TryGetStringParticularPlural(language:String, context:String, text:String, textPlural:String, n:haxe.Int64, args:Array<Dynamic>):String {
        var asset = Lambda.find(assets, a -> a.language == language);
        if (asset == null)
            return null;
        for (catalog in asset.catalogs) {
            if (catalog.IsTranslationExist(context + "\u0004" + text)) {
                return catalog.GetParticularPluralString(context, text, textPlural, n, args);
            }
        }
        return null;
    }
    public function TryGetSprite(language:String, id:NamespaceID):Sprite {
        for (asset in assets) {
            if (asset.language != language)
                continue;
            return asset.Sprites.get(id);
        }
        return null;
    }
    public function TryGetSpriteSheet(language:String, id:NamespaceID):Array<Sprite> {
        for (asset in assets) {
            if (asset.language != language)
                continue;
            return asset.SpriteSheets.get(id);
        }
        return null;
    }
    public function GetLanguages():Array<String> {
        return assets.map(a -> a.language);
    }
    private var assets:Array<LanguageAssets> = [];
    public var Key(default, null):String;
}

class LanguagePackMetadata {
    public var name:String;
    public var author:String;
    public var description:String;
    public var dataVersion:Int;
    // [JsonIgnore]
    // PORT-NOTE: json2object 的对应语义是 @:jignored；icon 是运行期资源（unity.Sprite），不参与反序列化。
    @:jignored public var icon:Sprite = null;
}

class LanguageAssets {
    public var language:String;
    public var catalogs:Map<String, Catalog> = new Map();
    public var Sprites:Map<NamespaceID, Sprite> = new Map();
    public var SpriteSheets:Map<NamespaceID, Array<Sprite>> = new Map();
    public function new(lang:String) {
        language = lang;
    }
}

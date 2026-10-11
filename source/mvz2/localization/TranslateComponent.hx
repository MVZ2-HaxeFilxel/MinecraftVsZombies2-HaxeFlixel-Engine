// Ported from: Assets/Scripts/MVZ2/Localization/TranslateComponent.cs
package mvz2.localization;

import mvz2.managers.MainManager;
import unity.Component;
import unity.MonoBehaviour;

// abstract
class TranslateComponent<T:Component> extends MonoBehaviour {
    // PORT-NOTE: Haxe 无法把泛型参数当作 Class 值使用（GetComponent<T>() 等价物），
    // 因此由子类在构造时显式传入组件类型。
    public function new(componentType:Class<T>) {
        super();
        this.componentType = componentType;
    }

    private function OnEnable():Void {
        // PORT-NOTE: 移植层的 prefab 注入/SetActive 派发可能早于 MainManager.Instance 就绪
        // （Unity 里 Awake/OnEnable 的引擎顺序掩盖了这一点）。lang 为空时跳过登记，
        // 等语言管理器就绪后的首次 OnLanguageChanged/Translate 由后续流程补齐。
        var lm = MainManager.Instance != null ? MainManager.Instance.LanguageManager : null;
        if (lm == null) {
            mvz2.states.BootTrace.step('TranslateComponent.OnEnable 跳过（lang==null）@'
                + (gameObject != null ? gameObject.name : "?") + ' ' + Type.getClassName(Type.getClass(this)));
            return;
        }
        lm.OnLanguageChanged.add(OnLanguageChangedCallback);
        Translate(lm.GetCurrentLanguage());
    }
    private function OnDisable():Void {
        var lm = MainManager.Instance != null ? MainManager.Instance.LanguageManager : null;
        if (lm == null)
            return;
        lm.OnLanguageChanged.remove(OnLanguageChangedCallback);
    }
    // virtual
    private function Translate(language:String):Void {

    }
    private function OnLanguageChangedCallback(language:String):Void {
        Translate(language);
    }
    public var Component(get, never):Null<T>;
    function get_Component():Null<T> {
        if (component == null && gameObject != null) {
            component = gameObject.GetComponent(componentType);
        }
        return component;
    }
    private var lang(get, never):LanguageManager;
    function get_lang():LanguageManager {
        return MainManager.Instance.LanguageManager;
    }
    private var componentType:Class<T>;
    private var component:T;
}

// Ported from: Assets/Scripts/MVZ2/Models/Components/ShaderPropertySetters/ShaderPropertySetter.cs
package mvz2.models;

import unity.UnityObject;
import tools.ObjectExtensions;

// [RequireComponent(typeof(RendererElement))]
// abstract
class ShaderPropertySetter<T> extends ModelComponent {
    public function new() {
        super();
    }

    override public function UpdateFrame(deltaTime:Float):Void {
        super.UpdateFrame(deltaTime);
        UpdateProperty();
    }
    public function ResetProperty():Void {
        SetProperty(GetDefaultValue());
    }
    public function UpdateProperty():Void {
        SetProperty(GetCurrentValue());
    }
    // abstract
    public function SetProperty(value:T):Void {
        throw "abstract";
    }
    // abstract
    public function GetDefaultValue():T {
        throw "abstract";
    }
    // abstract
    public function GetCurrentValue():T {
        throw "abstract";
    }
    override private function OnEnable():Void {
        super.OnEnable();
        enableTriggered = true;
    }
    private function OnDisable():Void {
        enableTriggered = false;
        ResetProperty();
    }
    private function LateUpdate():Void {
        if (enableTriggered) {
            enableTriggered = false;
            UpdateProperty();
        }
    }
    public var Element(get, never):RendererElement;
    function get_Element():RendererElement {
        if (!unity.UnityObject.exists(element)) {
            element = GetComponent(RendererElement);
        }
        return element;
    }
    private var element:RendererElement;
    private var enableTriggered:Bool = false;
}

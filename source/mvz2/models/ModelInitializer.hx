// Ported from: Assets/Scripts/MVZ2/Models/Utilities/ModelInitializer.cs
package mvz2.models;

import mvz2.models.Model;
import pvzengine.NamespaceID;
import tools.ObjectExtensions;
import unity.Camera;
import unity.UnityObject;
using pvzengine.PropertyKeyHelper;  // EXTUSING

class ModelInitializer extends unity.MonoBehaviour {
    public function new() {
        super();
    }

    function Awake():Void {
        if (unity.UnityObject.exists(model) && NamespaceID.IsValid(modelID) && unity.UnityObject.exists(modelCamera)) {
            model.Init(modelID, modelCamera);
        }
    }

    public var model:Model;
    public var modelID:NamespaceID;
    public var modelCamera:Camera;
}

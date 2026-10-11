// Ported from: Assets/Scripts/MVZ2/Models/ModelManager.cs
package mvz2.models;

import mvz2.managers.MainManager;
import unity.Texture;  // UNKNOWNIMPORT
import pvzengine.NamespaceID;
import tools.ObjectExtensions;
import unity.Camera;
import unity.Debug;
import unity.FilterMode;
import unity.GameObject;
import unity.Mathf;
import unity.Rect;
import unity.RenderTexture;
import unity.Shader;
import unity.Sprite;
import unity.SpriteRenderer;
import unity.Texture2D;
import unity.Transform;
import unity.Vector2;
import unity.Vector3;
import unity.rendering.RenderPipeline;
import unity.rendering.SortingGroup;
import unity.UnityObject;

class ModelManager extends unity.MonoBehaviour {
    public function new() {
        super();
    }

    public function ShotIcon(id:NamespaceID, width:Int, height:Int, modelOffset:Vector2, ?name:String):Sprite {
        var pictureName = name != null ? name : "ModelIcon";
        //激活摄像机与灯光
        modelShotRoot.gameObject.SetActive(true);

        //设置模型
        var builder = new ModelBuilder(id, modelShotCamera);
        var modelInstance = builder.Build(modelShotPositionTransform);
        if (!unity.UnityObject.exists(modelInstance)) {
            Debug.LogWarning('Prefab of model ${id} is missing!');
            return null;
        }
        modelInstance.transform.localPosition = Vector3.zero;
        AlignAllChildrenSpriteRenderers(modelInstance);

        var modelMeta = Main.ResourceManager.GetModelMeta(id);
        if (modelMeta != null && modelMeta.UpdateAnimatorOnShot) {
            modelInstance.UpdateAnimators(0);
        }
        modelInstance.UpdateFrame(0);


        //创建一个用于渲染图片的RenderTexture
        var colorFormat = Main.GraphicsManager.GetSupportedColorFormat();
        var depthFormat = Main.GraphicsManager.GetSupportedDepthFormat();
        // PORT-NOTE: Unity 的 RenderTexture 构造需要 GraphicsFormat；unity shim 使用深度位数。
        var renderTexture = new RenderTexture(width, height, 24);
        renderTexture.antiAliasing = 1;
        renderTexture.filterMode = FilterMode.Trilinear;
        modelShotCamera.targetTexture = renderTexture;
        modelShotCamera.enabled = false;

        // 相机渲染。
        modelShotCamera.orthographicSize = height * 0.005;

        var localPos = modelShotPositionTransform.localPosition;
        localPos.x = modelOffset.x * 0.01;
        localPos.y = modelOffset.y * 0.01;
        modelShotPositionTransform.localPosition = localPos;

        SortingGroup.UpdateAllSortingGroups();

        Shader.SetGlobalInt("_PixelSnap", 1);

        // Create a standard request
        var request = RenderPipeline.request;

        // Check if the request is supported by the active render pipeline
        if (RenderPipeline.SupportsRenderRequest(modelShotCamera, request)) {
            // 2D Texture
            request.destination = renderTexture;
            // Render camera and fill texture2D with its view
            RenderPipeline.SubmitRenderRequest(modelShotCamera, request);
        } else {
            modelShotCamera.Render();
        }
        Shader.SetGlobalInt("_PixelSnap", 0);

        // 从Render Texture读取像素并保存为图片
        var texture = new Texture2D(width, height);
        texture.filterMode = FilterMode.Bilinear;
        RenderTexture.active = renderTexture;
        texture.ReadPixels(new Rect(0, 0, renderTexture.width, renderTexture.height), 0, 0);
        texture.Apply();
        texture.name = pictureName;
        RenderTexture.active = null; // 重置活动的Render Texture
        modelShotCamera.targetTexture = null;
        renderTexture.Release();
        unity.UnityObject.DestroyImmediate(modelInstance.gameObject);

        // 创建Sprite。
        var sprite = main.ResourceManager.CreateSprite(texture, new Rect(0, 0, width, height), Vector2.one * 0.5, pictureName, "modelIcon");

        return sprite;
    }
    private function AlignAllChildrenSpriteRenderers(model:Model):Void {
        var renderers = model.GetComponentsInChildren(SpriteRenderer);
        for (renderer in renderers) {
            var spr = renderer.sprite;
            if (spr == null)
                continue;
            // PORT-NOTE: 本工作包接线后 `SpriteRenderer.sprite` 又可以是 unity.Sprite（逻辑层写入的
            // 资源对象），因此恢复 C# 原逻辑（rect.size / pivot / pixelsPerUnit）；
            // 只有 sprite 被直接写成 flixel.FlxSprite（ModelPrefabAssets 的旧路径）时才用
            // frameWidth/frameHeight/origin 近似，PPU 取默认 100。
            var sprSize:Vector2;
            var pivot:Vector2;
            var pixelsPerUnit:Float;
            if (Std.isOfType(spr, Sprite)) {
                var unitySprite:Sprite = cast spr;
                sprSize = unitySprite.rect.size;
                pivot = unitySprite.pivot;
                pixelsPerUnit = unitySprite.pixelsPerUnit;
            } else {
                var flx:flixel.FlxSprite = cast spr;
                sprSize = new Vector2(flx.frameWidth, flx.frameHeight);
                pivot = new Vector2(flx.origin.x / flx.frameWidth, 1 - flx.origin.y / flx.frameHeight);
                pixelsPerUnit = 100.0;
            }
            var position = renderer.transform.position;
            var scale = renderer.transform.lossyScale;
            // PORT-NOTE: C# 中 scale 是 Vector3 与 Vector2 相乘（隐式转换），移植层显式取 xy。
            var scale2 = new Vector2(scale.x, scale.y);
            var offset = new Vector3(Vector2.Scale(pivot / pixelsPerUnit, scale2).x, Vector2.Scale(pivot / pixelsPerUnit, scale2).y, 0);
            var minCorner = position - offset;
            var flooredMinCorner = new Vector3(Mathf.Round(minCorner.x * pixelsPerUnit) / pixelsPerUnit, Mathf.Round(minCorner.y * pixelsPerUnit) / pixelsPerUnit, minCorner.z);
            var finalOffset = flooredMinCorner - minCorner;
            renderer.transform.position = renderer.transform.position + finalOffset;
        }
    }
    public var Main(get, never):MainManager;
    function get_Main():MainManager return main;
    private var main:MainManager = null;
    private var modelShotRoot:Transform = null;
    private var modelShotPositionTransform:Transform = null;
    private var modelShotCamera:Camera = null;
}

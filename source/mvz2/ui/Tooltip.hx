// Ported from: Assets/Scripts/View/Widgets/Tooltip/Tooltip.cs
package mvz2.ui;

import unity.Canvas;
import unity.RectTransform;
import unity.UnityObject;
import unity.Vector2;
import unity.ui.Shadow;
import unity.tmpro.TextMeshProUGUI;
import unity.MonoBehaviour;
import unity.Vector3;
import unity.ui.LayoutRebuilder;

class Tooltip extends unity.MonoBehaviour
{
	public function Show():Void
	{
		gameObject.SetActive(true);
	}
	public function Hide():Void
	{
		gameObject.SetActive(false);
	}
	public function SetPosition(viewData:TooltipPosition):Void
	{
		var rectTransform:RectTransform = cast transform;
		if (UnityObject.exists(rectTransform))
		{
			rectTransform.pivot = viewData.pivot;
			rectTransform.position = new unity.Vector3(viewData.position.x, viewData.position.y, 0);
			var rootCanvas = UIHelper.GetRootCanvasNonAlloc(rectTransform, canvasListCache);
			if (UnityObject.exists(rootCanvas))
			{
				var rectTrans:RectTransform = cast rootCanvas.transform;
				if (rectTrans != null)
				{
					UIHelper.LimitInsideScreenWithSize(rectTransform, rectTrans,
						// PORT-NOTE: C# 为 `rootTransform.rect.size`；unity shim 的 RectTransform 暂无 rect，
						// 用 UIHelper.GetLocalRect 按同一语义复算（见 UIHelper 的 TODO-PORT）。
						UIHelper.GetLocalRect(rootTransform).size);
				}
			}
		}
	}
	public function SetContent(content:TooltipContent):Void
	{
		nameText.text = content.name;
		errorText.text = content.error;
		descriptionText.text = content.description;
		nameText.gameObject.SetActive(!(content.name == null || content.name == ""));
		errorText.gameObject.SetActive(!(content.error == null || content.error == ""));
		descriptionText.gameObject.SetActive(!(content.description == null || content.description == ""));
		ForceRebuildLayout();
	}
	public function ForceRebuildLayout():Void
	{
		var rectTransform:RectTransform = cast transform;
		LayoutRebuilder.ForceRebuildLayoutImmediate(rectTransform);
	}
	@:serializeField
	var rootTransform:RectTransform;
	@:serializeField
	var nameText:TextMeshProUGUI;
	@:serializeField
	var errorText:TextMeshProUGUI;
	@:serializeField
	var descriptionText:TextMeshProUGUI;
	private var canvasListCache:Array<Canvas> = [];
}

// C# 中为 MVZ2.UI 的 TooltipPosition 结构体。
class TooltipPosition
{
	public var pivot:Vector2 = new Vector2();
	public var position:Vector2 = new Vector2();

	public function new() {}
}

// C# 中为 MVZ2.UI 的 TooltipContent 结构体。
class TooltipContent
{
	public var pivot:Vector2 = new Vector2();
	public var position:Vector2 = new Vector2();
	public var name:String;
	public var error:Null<String>;
	public var description:Null<String>;

	public function new() {}
}

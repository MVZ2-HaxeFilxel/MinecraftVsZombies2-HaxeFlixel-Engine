// Ported from: Assets/Scripts/View/Widgets/ElementListUI.cs
package mvz2.ui;

import unity.Component;
import unity.RectTransform;
import unity.UnityObject;
import unity.ui.LayoutElement;
import unity.ui.Shadow;
import unity.MonoBehaviour;
import unity.ui.LayoutElement.LayoutGroup;
import unity.ui.LayoutRebuilder;

class ElementListUI extends unity.MonoBehaviour
{
	public function updateList(count:Int, ?onUpdate:Int->RectTransform->Void = null, ?onCreateOrEnable:RectTransform->Void = null,
		?onDestroyOrDisable:RectTransform->Void = null, ?dontDestroy:Bool = false, ?rebuild:Bool = false):Void
	{
		if (_template.transform.parent == _listRoot)
		{
			_template.gameObject.SetActive(false);
		}

		var maxNum = Std.int(Math.max(_itemList.length, count));

		for (i in 0...maxNum)
		{
			if (i < count) // 应当出现在列表中
			{
				var item:RectTransform;
				if (i >= _itemList.length) // 目前没有这个项
				{
					//创建列表项
					item = CreateItem();
					Add(item);
					if (onCreateOrEnable != null) onCreateOrEnable(item);
				}
				else // 目前有这个项
				{
					item = _itemList[i];
					if (!item.gameObject.activeSelf && dontDestroy)
					{
						//激活
						item.gameObject.SetActive(true);
						if (onCreateOrEnable != null) onCreateOrEnable(item);
					}
				}
				//更新
				if (onUpdate != null) onUpdate(i, item);
			}
			else // 不应出现在列表中
			{
				var item:RectTransform;
				if (!dontDestroy) // 可以销毁
				{
					if (count < _itemList.length) // 目前有这个项
					{
						// 销毁列表项
						item = _itemList[count];
						DestroyItem(item);
						if (onDestroyOrDisable != null) onDestroyOrDisable(item);
					}
				}
				else // 不可以销毁
				{
					if (i < _itemList.length) // 目前有这个项
					{
						item = _itemList[i];
						if (item.gameObject.activeSelf)
						{
							// 禁用
							item.gameObject.SetActive(false);
							if (onDestroyOrDisable != null) onDestroyOrDisable(item);
						}
					}
				}
			}
		}
		if (!rebuild)
			return;
		for (layoutGroup in _listRoot.GetComponentsInChildren(LayoutGroup))
		{
			if (layoutGroup.transform == _listRoot)
				continue;
			LayoutRebuilder.ForceRebuildLayoutImmediate(cast layoutGroup.transform);
		}
		LayoutRebuilder.ForceRebuildLayoutImmediate(_listRoot);
		for (layoutGroup in _listRoot.GetComponentsInParent(LayoutGroup))
		{
			if (layoutGroup.transform == _listRoot)
				continue;
			LayoutRebuilder.ForceRebuildLayoutImmediate(cast layoutGroup.transform);
		}
	}
	public function Add(item:RectTransform):Void
	{
		_itemList.push(item);
	}
	public function Remove(item:RectTransform):Bool
	{
		return _itemList.remove(item);
	}
	public function RemoveAt(index:Int):Void
	{
		_itemList.splice(index, 1);
	}
	public function CreateItem():RectTransform
	{
		var item = UnityObject.Instantiate(_template, null, null, _listRoot);
		//激活
		item.gameObject.SetActive(true);
		return item;
	}
	public function DestroyItem(item:RectTransform):Bool
	{
		if (Remove(item))
		{
			item.SetParent(null);
			UnityObject.destroy(item.gameObject);
			return true;
		}
		return false;
	}
	public function indexOf(trans:RectTransform):Int
	{
		return _itemList.indexOf(trans);
	}
	// PORT-NOTE: C# 的 indexOf(Component) 重载在 Haxe 中不能与 indexOf(RectTransform) 并存，故改名。
	public function indexOfComponent(comp:Component):Int
	{
		var rectTrans:RectTransform = cast comp.transform;
		if (!UnityObject.exists(rectTrans))
			return -1;
		return indexOf(rectTrans);
	}
	public function getElement(index:Int):Null<RectTransform>
	{
		if (index < 0 || index >= _itemList.length)
			return null;
		return _itemList[index];
	}
	// PORT-NOTE: C# 的泛型重载 getElement<T>(index) 不能与非泛型版本并存，Haxe 需要显式传入组件类型。
	public function getElementAs<T:Component>(index:Int, type:Class<T>):Null<T>
	{
		var element = getElement(index);
		return element != null ? element.GetComponent(type) : null;
	}
	public function getTemplate():RectTransform
	{
		return _template;
	}
	public function getTemplateAs<T:Component>(type:Class<T>):Null<T>
	{
		var template = getTemplate();
		return template != null ? template.GetComponent(type) : null;
	}
	public function getElements():Array<RectTransform>
	{
		return _itemList;
	}
	public function getElementsAs<T:Component>(type:Class<T>):Array<T>
	{
		var result:Array<T> = [];
		for (item in _itemList)
		{
			result.push(item.GetComponent(type));
		}
		return result;
	}
	public var count(get, never):Int;
	function get_count():Int return _itemList.length;
	@:serializeField
	private var _listRoot:RectTransform;
	@:serializeField
	private var _template:RectTransform;
	@:serializeField
	private var _itemList:Array<RectTransform> = [];
}

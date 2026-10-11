// Ported from: Assets/Scripts/Engine/Tools/Unity/PositionTransitor.cs
package tools;

import unity.Application;
import unity.MonoBehaviour;
import unity.Transform;
import unity.Vector3;
import unity.UnityObject;

@:executeInEditMode
@:DisallowMultipleComponent
// PORT-NOTE: C# 的 `abstract class` 在 Haxe 中仍写 `class`，抽象方法 Transit 以 `throw` 占位。
class PositionTransitor extends MonoBehaviour
{
	public function new()
	{
		super();
	}

	// #region 公有方法

	// #region 开始位置
	public function setStartPositionToCurrent():Void
	{
		setStartPosition(transform.position);
	}
	public function setStartTransform(transform:Transform):Void
	{
		_startTransform = transform;
		updatePosition();
	}
	public function setStartPosition(globalPosition:Vector3):Void
	{
		if (isLocalMode)
		{
			_startPosition = globalToLocalPoint(globalPosition);
		}
		else
		{
			_startPosition = globalPosition;
		}
		updatePosition();
	}
	public function setStartLocalPosition(localPosition:Vector3):Void
	{
		if (isLocalMode)
		{
			_startPosition = localPosition;
		}
		else
		{
			_startPosition = localToGlobalPoint(localPosition);
		}
		updatePosition();
	}
	// #endregion

	// #region 目标位置
	public function setTargetTransform(target:Transform):Void
	{
		_targetTransform = target;
		_targetPosition = Vector3.zero;
		updatePosition();
	}
	public function setTargetPosition(targetPos:Vector3):Void
	{
		_targetTransform = null;
		_targetPosition = targetPos;
		updatePosition();
	}
	public function setTargetPositionToCurrent():Void
	{
		setTargetPosition(transform.position);
	}
	// #endregion

	// #region 当前位置
	public function setWorldPosition(pos:Vector3):Void
	{
		transform.position = pos;
	}
	public function getWorldPosition():Vector3
	{
		return transform.position;
	}
	public function setLocalPosition(pos:Vector3):Void
	{
		transform.localPosition = pos;
	}
	public function getLocalPosition():Vector3
	{
		return transform.localPosition;
	}
	public function setPositionByTime(time:Float):Void
	{
		if (isLocalMode)
		{
			var targetPosition = unity.UnityObject.exists(targetTransform) ? targetTransform.position : _targetPosition;
			var globalStartPosition:Vector3;
			var localStartPosition:Vector3;
			if (unity.UnityObject.exists(startTransform))
			{
				globalStartPosition = startTransform.position;
				localStartPosition = globalToLocalPoint(startTransform.position);
			}
			else
			{
				globalStartPosition = localToGlobalPoint(_startPosition);
				localStartPosition = _startPosition;
			}
			targetPosition = globalToLocalPoint(targetPosition);

			var position = Transit(localStartPosition, targetPosition, time);
			setLocalPosition(position);
		}
		else
		{
			var startPosition = unity.UnityObject.exists(startTransform) ? startTransform.position : _startPosition;
			var targetPosition = unity.UnityObject.exists(targetTransform) ? targetTransform.position : _targetPosition;

			var position = Transit(startPosition, targetPosition, time);
			setWorldPosition(position);
		}
	}
	public function setPositionToStart():Void
	{
		setPositionByTime(0);
	}
	public function updatePosition():Void
	{
		setPositionByTime(time);
	}
	// #endregion

	// #endregion

	// #region 私有方法

	// #region 生命周期
	// PORT-NOTE: Unity 消息方法（Reset/OnEnable/LateUpdate）改为普通方法，由场景/状态包装层调用。
	function Reset():Void
	{
		enabled = false;
	}
	function OnEnable():Void
	{
		initStartPosition();
	}
	function LateUpdate():Void
	{
		updatePosition();
	}
	// #endregion

	function Transit(start:Vector3, end:Vector3, time:Float):Vector3
	{
		throw "abstract";
	}
	private function initStartPosition():Void
	{
		if (!Application.isPlaying)
			return;
		setStartPositionToCurrent();
	}
	private function globalToLocalPoint(global:Vector3):Vector3
	{
		if (transform.parent == null)
		{
			return global;
		}
		return transform.parent.InverseTransformPoint(global);
	}
	private function localToGlobalPoint(local:Vector3):Vector3
	{
		if (transform.parent == null)
		{
			return local;
		}
		return transform.parent.TransformPoint(local);
	}
	// #endregion

	// #region 属性字段
	public var startTransform(get, never):Transform;
	inline function get_startTransform():Transform return _startTransform;
	public var targetTransform(get, never):Transform;
	inline function get_targetTransform():Transform return _targetTransform;
	@:range(0, 1)
	@:serializeField
	public var time:Float = 0;
	@:serializeField
	var isLocalMode:Bool = false;
	@:serializeField
	var _startTransform:Transform = null;
	@:serializeField
	var _targetTransform:Transform = null;
	@:serializeField
	var _startPosition:Vector3 = new Vector3();
	@:serializeField
	var _targetPosition:Vector3 = new Vector3();
	// C#: public bool IsLocalMode { get => isLocalMode; set => isLocalMode = value; }
	public var IsLocalMode(get, set):Bool;
	inline function get_IsLocalMode():Bool return isLocalMode;
	inline function set_IsLocalMode(value:Bool):Bool return isLocalMode = value;
	// C#: public Vector3 startPosition { get => _startPosition; }
	public var startPosition(get, never):Vector3;
	inline function get_startPosition():Vector3 return _startPosition;
	// #endregion
}

// Ported from: Assets/Scripts/View/Models/Entity/ModelGroupRenderer.cs
package mvz2.models;
import mvz2.models.GraphicElement.SerializableGraphicElement;  // IMPORTAUTO
import mvz2.models.ModelGroup.SerializableModelGroup;  // IMPORTAUTO

import mvz2logic.Layers;
import unity.Color;
import unity.ParticleSystem;
import unity.Renderer;
import unity.SpriteMask;
import unity.Vector4;
using pvzengine.models.HasModelExt;  // EXTUSING

// abstract
class ModelGroupRenderer extends ModelGroup
{
	public function new() { super(); } // CTORFIX
	// #region 粒子
	override public function SetSimulationSpeed(speed:Float):Void
	{
		super.SetSimulationSpeed(speed);
		for (particle in particles)
		{
			particle.SetSimulationSpeed(speed);
		}
	}
	// #endregion

	// #region 元素管理
	override public function AddElement(element:GraphicElement):Void
	{
		if (!Std.isOfType(element, RendererElement))
			throw 'Wrong model group element type. (element)'; // ArgumentException("Wrong model group element type.", nameof(element))
		renderers.push(cast element);
	}
	override public function UpdateElements():Void
	{
		super.UpdateElements();
		var newRenderers = Lambda.filter(GetComponentsInChildren(Renderer, true),
			g -> ModelHelper.IsDirectChild(g, this) && !Std.isOfType(g, SpriteMask) && g.gameObject.layer != Layers.LIGHT_TEXTURE);
		var rendererElements:Array<RendererElement> = [];
		for (r in newRenderers)
		{
			var element = r.GetComponent(RendererElement);
			if (element == null)
			{
				element = r.gameObject.AddComponent(RendererElement);
			}
			rendererElements.push(element);
		}
		ModelHelper.ReplaceList(renderers, rendererElements);

		var newParticles = Lambda.filter(GetComponentsInChildren(ParticleSystem, true),
			p -> ModelHelper.IsDirectChild(p, this) && p.transform.parent.GetComponentInParent(ParticleSystem) == null);
		var particleElements:Array<ParticlePlayer> = [];
		for (r in newParticles)
		{
			var element = r.GetComponent(ParticlePlayer);
			if (element == null)
			{
				element = r.gameObject.AddComponent(ParticlePlayer);
			}
			particleElements.push(element);
		}
		ModelHelper.ReplaceList(particles, particleElements);
	}
	// #endregion

	// #region 序列化
	function SaveToSerializableRenderer(serializable:SerializableModelGroupRenderer):Void
	{
		SaveToSerializableGroup(serializable);
		serializable.particles = [for (e in particles) e.ToSerializable()];
		serializable.renderers = [for (e in renderers) e.ToSerializable()];
	}
	override function LoadFromSerializable(serializable:SerializableModelGroup):Void
	{
		super.LoadFromSerializable(serializable);
		if (!Std.isOfType(serializable, SerializableModelGroupRenderer))
			return;
		var rendererUnit:SerializableModelGroupRenderer = cast serializable;
		if (renderers != null && rendererUnit.renderers != null)
		{
			for (i in 0...renderers.length)
			{
				if (i >= rendererUnit.renderers.length)
					break;
				var element = renderers[i];
				var data = rendererUnit.renderers[i];
				if (data == null)
					continue;
				element.LoadFromSerializable(data);
			}
		}
		if (particles != null && rendererUnit.particles != null)
		{
			for (i in 0...particles.length)
			{
				if (i >= rendererUnit.particles.length)
					break;
				var particle = particles[i];
				var data = rendererUnit.particles[i];
				if (data == null)
					continue;
				particle.LoadFromSerializable(data);
			}
		}
	}
	// #endregion

	// #region 着色器
	override public function SetShaderInt(name:String, value:Int):Void
	{
		for (element in renderers)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			element.SetInt(name, value);
		}
	}

	override public function SetShaderFloat(name:String, alpha:Float):Void
	{
		for (element in renderers)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			element.SetFloat(name, alpha);
		}
	}
	override public function SetShaderColor(name:String, color:Color):Void
	{
		for (element in renderers)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			element.SetColor(name, color);
		}
	}
	override public function SetShaderVector(name:String, vector:Vector4):Void
	{
		for (element in renderers)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			element.SetVector(name, vector);
		}
	}
	override public function ApplyShaderProperties():Void
	{
		for (element in renderers)
		{
			if (element == null || element.ExcludedInGroup)
				continue;
			element.ApplyShaderProperties();
		}
	}
	// #endregion

	// #region 属性字段
	@:serializeField
	private var renderers:Array<RendererElement> = [];
	@:serializeField
	private var particles:Array<ParticlePlayer> = [];
	// #endregion
}

// abstract
@:rtti
class SerializableModelGroupRenderer extends SerializableModelGroup
{
	public var particles:Array<SerializableParticleSystem>;
	public var renderers:Array<SerializableGraphicElement>;

	public function new()
	{
		super();
	}
}

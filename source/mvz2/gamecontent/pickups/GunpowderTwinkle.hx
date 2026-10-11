// Ported from: Assets/Scripts/Vanilla/GameContent/Pickups/EnergyPickups/GunpowderTwinkle.cs
package mvz2.gamecontent.pickups;

import mvz2.gamecontent.damages.VanillaDamageEffects;
import mvz2.gamecontent.effects.Explosion;
import mvz2.vanilla.audios.VanillaSoundID;
import mvz2.vanilla.entities.VanillaEntityBehaviourNames;
import mvz2.vanilla.entities.VanillaEntityExt;
import mvz2.vanilla.entities.VanillaEntityProps;
import mvz2.vanilla.pickups.VanillaPickupExt;
import mvz2.vanilla.pickups.VanillaPickupProps;
import mvz2.vanilla.properties.VanillaEntityPropertyMeta;
import mvz2.gamecontent.difficulties.VanillaDifficultyLevelProps;
import mvz2logic.entities.LogicEntityExt;
import pvzengine.damages.DamageEffectList;
import pvzengine.definitions.EntityBehaviourDefinition;
import pvzengine.entities.EngineEntityProps;
import pvzengine.entities.Entity;
import pvzengine.modifiers.ColorModifier;
import unity.Color;
import unity.Mathf;
import unity.UnityObject;
using mvz2.gamecontent.difficulties.VanillaDifficultyLevelProps;
using mvz2.vanilla.entities.VanillaEntityExt;
using mvz2.vanilla.entities.VanillaEntityProps;
using mvz2.vanilla.pickups.VanillaPickupExt;
using mvz2logic.entities.LogicEntityExt;

@:autoEntityBehaviourDefinition(VanillaEntityBehaviourNames.gunpowderTwinkle)
class GunpowderTwinkle extends EntityBehaviourDefinition
{
    public function new(nsp:String, name:String)
    {
        super(nsp, name);
        AddModifier(new ColorModifier(EngineEntityProps.COLOR_OFFSET, PROP_COLOR_OFFSET));
    }
    public override function Update(pickup:Entity):Void
    {
        super.Update(pickup);
        var timeout = pickup.Timeout;
        var collected = pickup.IsCollected();
        var r:Float = 0;
        if (!collected && timeout <= TWINKLE_TIMEOUT)
        {
            var percentage = (1 - timeout / TWINKLE_TIMEOUT);
            var x = Mathf.Pow(percentage * TWINKLE_SPEED, 3);
            r = (-Mathf.Cos(x) + 1) * 0.5;
        }
        var offset = new Color(1, 0, 0, r);
        SetColorOffset(pickup, offset);

        if (!collected && timeout <= 1 && unity.UnityObject.exists(pickup))
        {
            var damage = pickup.GetDamage() * pickup.Level.GetGunpowderDamageMultiplier();
            var range = pickup.GetRange();
            var effects = new DamageEffectList([VanillaDamageEffects.EXPLOSION, VanillaDamageEffects.DAMAGE_BODY_AFTER_ARMOR_BROKEN, VanillaDamageEffects.MUTE]);
            pickup.ExplodeAgainstFriendly(pickup.GetCenter(), range, pickup.GetFaction(), damage, effects);

            Explosion.Spawn(pickup, pickup.GetCenter(), range);

            pickup.PlaySound(VanillaSoundID.explosion);

            pickup.Remove();
        }
    }
    public static function GetColorOffset(entity:Entity):Color return entity.GetBehaviourField(PROP_COLOR_OFFSET);
    public static function SetColorOffset(entity:Entity, value:Color):Void entity.SetBehaviourField(PROP_COLOR_OFFSET, value);
    public static inline var TWINKLE_TIMEOUT:Int = 150;
    public static inline var TWINKLE_SPEED:Float = 5;
    private static var PROP_COLOR_OFFSET:VanillaEntityPropertyMeta<Color> = new VanillaEntityPropertyMeta<Color>("color_offset");
}

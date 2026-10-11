package mvz2.supporters;

import mvz2.supporters.SponsorPlanSaveItem;

// Ported from: Assets/Scripts/MVZ2/Sponsors/SponsorSaveItem.cs (class SponsorSaveItem)
@:rtti
class SponsorSaveItem {
    public var name:String;
    public var plans:Array<SponsorPlanSaveItem>;

    public function new(name:String, plans:Array<SponsorPlanSaveItem>) {
        this.name = name;
        this.plans = plans;
    }
}

package mvz2.supporters;

import mvz2.supporters.SponsorQueryResults;
import mvz2.supporters.SponsorSaveItem;
import mvz2.supporters.SponsorPlanSaveItem;
import mvz2.supporters.SponsorPlans;
import mvz2.supporters.SponsorQueryResults.SponsorItem;
import mvz2.supporters.SponsorQueryResults.User;

// Ported from: Assets/Scripts/MVZ2/Sponsors/SponsorSaveItem.cs (class SponsorInfos)
@:rtti
class SponsorInfos {
    public function new(items:Array<SponsorItem>) {
        var saveItems:Array<SponsorSaveItem> = [];
        for (sponsor in items) {
            var planSaveItems:Array<SponsorPlanSaveItem> = [];
            if (sponsor.Plans == null || sponsor.User == null)
                continue;
            for (plan in sponsor.Plans) {
                if (plan == null)
                    continue;
                var outPlan:{type:Int, rank:Int} = {type: 0, rank: 0};
                if (SponsorPlans.TryGetPlanByID(plan.PlanID, outPlan)) {
                    var savePlan = new SponsorPlanSaveItem();
                    savePlan.rank = outPlan.rank;
                    savePlan.rankType = outPlan.type;
                    planSaveItems.push(savePlan);
                }
            }
            if (planSaveItems.length > 0) {
                saveItems.push(new SponsorSaveItem(sponsor.User.Name != null ? sponsor.User.Name : "", planSaveItems));
            }
        }
        sponsors = Lambda.array(saveItems);
    }
    public var lastUpdateTime:haxe.Int64;
    public var sponsors:Array<SponsorSaveItem>;
}

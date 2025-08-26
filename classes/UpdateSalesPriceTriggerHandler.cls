public with sharing class UpdateSalesPriceTriggerHandler extends TriggerHandler {
    protected override void beforeInsert() {
        setDefaultUnitPrice(Trigger.new, null, false);
    }

    protected override void beforeUpdate() {
        setDefaultUnitPrice(Trigger.new, Trigger.oldMap, true);
    }

    private static void setDefaultUnitPrice(List<SObject> newListSObj,
                                            Map<Id, SObject> oldMapSObj,
                                            Boolean isUpdate) {

        List<OpportunityLineItem> newList = new List<OpportunityLineItem>();
        for (SObject sob : newListSObj) newList.add((OpportunityLineItem)sob);

        Map<Id, OpportunityLineItem> oldMap = new Map<Id, OpportunityLineItem>();
        if (oldMapSObj != null) {
            for (Id k : oldMapSObj.keySet()) {
                oldMap.put(k, (OpportunityLineItem)oldMapSObj.get(k));
            }
        }

        Set<Id> pbeIds = new Set<Id>();
        for (OpportunityLineItem oli : newList) {
            if (oli.PricebookEntryId == null) continue;

            Boolean priceMissing = (oli.UnitPrice == null || oli.UnitPrice == 0);
            if (!priceMissing) continue;

            if (!isUpdate) {
                pbeIds.add(oli.PricebookEntryId);
            } else {
                OpportunityLineItem oldRec = oldMap.get(oli.Id);
                if (oldRec == null
                    || oli.PricebookEntryId != oldRec.PricebookEntryId
                    || oldRec.UnitPrice == oli.UnitPrice) {
                    pbeIds.add(oli.PricebookEntryId);
                }
            }
        }
        if (pbeIds.isEmpty()) return;

        Map<Id, PricebookEntry> pbeById = new Map<Id, PricebookEntry>([
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Id IN :pbeIds
        ]);

        for (OpportunityLineItem oli : newList) {
            if (oli.PricebookEntryId == null) continue;
            if (oli.UnitPrice != null && oli.UnitPrice != 0) continue;

            PricebookEntry pbe = pbeById.get(oli.PricebookEntryId);
            if (pbe != null) {
                oli.UnitPrice = pbe.UnitPrice; 
            }
        }
    }
}
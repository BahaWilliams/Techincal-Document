public with sharing class OLILineEditorController {
    public class Row {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal lineTotal;
    }

    public class LinesResult {
        @AuraEnabled public List<Row> rows;
        @AuraEnabled public Decimal   totalQty;
        @AuraEnabled public Decimal   totalAmount;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option() {}
        public Option(String l, String v) { label = l; value = v; }
    }

    public class SwapInit {
        @AuraEnabled public Id                oliId;
        @AuraEnabled public String            currentProductName;
        @AuraEnabled public String            family;
        @AuraEnabled public Decimal           unitPrice;
        @AuraEnabled public Decimal           quantity;
        @AuraEnabled public List<Option>      choices;    
        @AuraEnabled public Map<String,Decimal> priceById; 
    }

    private static OpportunityLineItem getOli(Id oliId) {
        return [
            SELECT Id, OpportunityId, Quantity, UnitPrice,
                   PricebookEntryId,
                   PricebookEntry.Pricebook2Id,
                   PricebookEntry.UnitPrice,            
                   PricebookEntry.Product2Id,
                   PricebookEntry.Product2.Name,
                   PricebookEntry.Product2.Family
            FROM OpportunityLineItem
            WHERE Id = :oliId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static LinesResult listLines(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('opportunityId is required.');
        }

        List<OpportunityLineItem> olis = [
            SELECT Id, Quantity, UnitPrice,
                   PricebookEntry.Product2.Name
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            ORDER BY PricebookEntry.Product2.Name
        ];

        LinesResult res = new LinesResult();
        res.rows = new List<Row>();
        Decimal tq = 0, ta = 0;

        for (OpportunityLineItem oli : olis) {
            Row r = new Row();
            r.id          = oli.Id;
            r.productName = (oli.PricebookEntry != null && oli.PricebookEntry.Product2 != null)
                            ? oli.PricebookEntry.Product2.Name : null;
            r.quantity    = oli.Quantity;
            r.unitPrice   = oli.UnitPrice;
            r.lineTotal   = (oli.UnitPrice == null || oli.Quantity == null)
                            ? 0 : oli.UnitPrice * oli.Quantity;
            res.rows.add(r);

            tq += (oli.Quantity == null ? 0 : oli.Quantity);
            ta += (r.lineTotal   == null ? 0 : r.lineTotal);
        }

        res.totalQty    = tq;
        res.totalAmount = ta;
        return res;
    }

    @AuraEnabled
    public static SwapInit initSwap(Id oliId) {
        if (oliId == null) {
            throw new AuraHandledException('oliId is required.');
        }

        OpportunityLineItem oli = getOli(oliId);

        List<PricebookEntry> sameFamily = [
            SELECT Id, Name, UnitPrice, IsActive,
                   Product2.Name, Product2.Family, Pricebook2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :oli.PricebookEntry.Pricebook2Id
              AND IsActive = true
              AND Product2.Family = :oli.PricebookEntry.Product2.Family
            ORDER BY Product2.Name
        ];

        SwapInit init = new SwapInit();
        init.oliId               = oli.Id;
        init.currentProductName  = oli.PricebookEntry.Product2.Name;
        init.family              = oli.PricebookEntry.Product2.Family;
        init.unitPrice           = oli.UnitPrice;
        init.quantity            = oli.Quantity;
        init.choices             = new List<Option>();
        init.priceById           = new Map<String, Decimal>();

        for (PricebookEntry p : sameFamily) {
            init.choices.add(new Option(p.Product2.Name, (String)p.Id));
            init.priceById.put((String)p.Id, p.UnitPrice);
        }

        return init;
    }

    @AuraEnabled
    public static LinesResult swapProduct(Id oliId, Id newPricebookEntryId) {
        if (oliId == null || newPricebookEntryId == null) {
            throw new AuraHandledException('oliId and newPricebookEntryId are required');
        }

        OpportunityLineItem oldOli = [
            SELECT Id, OpportunityId, Quantity, Discount, Description, ServiceDate
            FROM OpportunityLineItem
            WHERE Id = :oliId
            LIMIT 1
        ];

        PricebookEntry newPbe = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Id = :newPricebookEntryId
            LIMIT 1
        ];

        OpportunityLineItem newOli = new OpportunityLineItem(
            OpportunityId     = oldOli.OpportunityId,
            PricebookEntryId  = newPbe.Id,
            Quantity          = oldOli.Quantity,
            UnitPrice         = newPbe.UnitPrice, 
            Discount          = oldOli.Discount,
            Description       = oldOli.Description,
            ServiceDate       = oldOli.ServiceDate
        );
        insert newOli;

        delete oldOli;

        return listLines(newOli.OpportunityId);
    }

    @AuraEnabled
    public static void deleteOli(Id oliId) {
        if (oliId == null) {
            throw new AuraHandledException('oliId is required.');
        }
        delete [SELECT Id FROM OpportunityLineItem WHERE Id = :oliId LIMIT 1];
    }
}

public with sharing class OLIConnectivityController {
    public class PingResult {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public Integer oliCount;
        @AuraEnabled public Id      pricebookId;
        @AuraEnabled public String  message;
    }

    public class OLIViewRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  productName;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal lineTotal;
        @AuraEnabled public Decimal listPrice; 
        @AuraEnabled public String  productFamily;
    }

    public class LinesResult {
        @AuraEnabled public List<OLIViewRow> rows;
        @AuraEnabled public Decimal totalQty;
        @AuraEnabled public Decimal totalAmount;
    }

    private static Opportunity loadOpp(Id oppId) {
        return [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
    }

    private static List<OpportunityLineItem> loadOlis(Id oppId) {
        return [
            SELECT Id,
                   Quantity,
                   UnitPrice,
                   TotalPrice,
                   PricebookEntry.UnitPrice,             
                   PricebookEntry.Product2.Name,
                   PricebookEntry.Product2.Family,
                   PricebookEntry.Product2Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :oppId
            ORDER BY PricebookEntry.Product2.Name
        ];
    }

    // ====== API methods ======

    @AuraEnabled(cacheable=true)
    public static PingResult pingOli(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('opportunityId is required.');
        }

        Opportunity opp = loadOpp(opportunityId);
        Integer cnt = [
            SELECT COUNT()
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
        ];

        PingResult r   = new PingResult();
        r.ok           = true;
        r.oliCount     = cnt;
        r.pricebookId  = opp.Pricebook2Id;
        r.message      = 'OK';
        return r;
    }

    @AuraEnabled
    public static LinesResult listLines(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('opportunityId is required.');
        }

        List<OpportunityLineItem> olis = loadOlis(opportunityId);

        LinesResult res = new LinesResult();
        res.rows = new List<OLIViewRow>();
        Decimal tq = 0, ta = 0;

        for (OpportunityLineItem oli : olis) {
            OLIViewRow row = new OLIViewRow();
            row.id           = oli.Id;
            row.productName  = oli.PricebookEntry.Product2.Name;
            row.productFamily= oli.PricebookEntry.Product2.Family; 
            row.unitPrice    = oli.UnitPrice;                         
            row.quantity     = oli.Quantity;
            row.lineTotal    = (oli.UnitPrice == null || oli.Quantity == null)
                               ? 0
                               : oli.UnitPrice * oli.Quantity;
            row.listPrice    = oli.PricebookEntry.UnitPrice;         
            res.rows.add(row);

            tq += (oli.Quantity == null ? 0 : oli.Quantity);
            ta += (row.lineTotal == null ? 0 : row.lineTotal);
        }
        res.totalQty    = tq;
        res.totalAmount = ta;
        return res;
    }

    @AuraEnabled
    public static LinesResult updateQuantities(Id opportunityId, Map<Id, Decimal> qtyById) {
        if (opportunityId == null) throw new AuraHandledException('opportunityId is required.');
        if (qtyById == null || qtyById.isEmpty()) return listLines(opportunityId);

        List<OpportunityLineItem> targets = [
            SELECT Id, OpportunityId, Quantity, UnitPrice,
                PricebookEntry.UnitPrice
            FROM OpportunityLineItem
            WHERE Id IN :qtyById.keySet()
        ];

        List<OpportunityLineItem> upds = new List<OpportunityLineItem>();
        for (OpportunityLineItem t : targets) {
            if (t.OpportunityId != opportunityId) continue;
            Decimal newQty = qtyById.get(t.Id);
            if (newQty == null) continue;
            if (newQty < 0) newQty = 0;

            OpportunityLineItem upd = new OpportunityLineItem(
                Id        = t.Id,
                Quantity  = newQty,
                UnitPrice = t.PricebookEntry.UnitPrice
            );
            upds.add(upd);
        }

        if (!upds.isEmpty()) {
            Database.SaveResult[] sr = Database.update(upds, false);
            List<String> errs = new List<String>();
            for (Integer i = 0; i < sr.size(); i++) {
                if (!sr[i].isSuccess()) {
                    for (Database.Error e : sr[i].getErrors()) errs.add(e.getMessage());
                }
            }
            if (!errs.isEmpty()) {
                throw new AuraHandledException('Sebagian baris gagal diupdate: ' + String.join(errs, ' | '));
            }
        }

        return listLines(opportunityId);
    }
}
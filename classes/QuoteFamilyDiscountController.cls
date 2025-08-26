public with sharing class QuoteFamilyDiscountController {
    public class FamilyRow {
        @AuraEnabled public String family;        // bisa null
        @AuraEnabled public Integer lineCount;
        @AuraEnabled public Decimal minDiscount;
        @AuraEnabled public Decimal maxDiscount;
    }

    @AuraEnabled(cacheable=true)
    public static List<FamilyRow> getFamilies(Id quoteId) {
        List<FamilyRow> rows = new List<FamilyRow>();
        for (AggregateResult ar : [
            SELECT PricebookEntry.Product2.Family fam,
                   COUNT(Id) cnt,
                   MIN(Discount) minD,
                   MAX(Discount) maxD
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            GROUP BY PricebookEntry.Product2.Family
        ]) {
            FamilyRow r = new FamilyRow();
            r.family      = (String) ar.get('fam'); // boleh null
            r.lineCount   = (Integer) ar.get('cnt');
            r.minDiscount = (Decimal) ar.get('minD');
            r.maxDiscount = (Decimal) ar.get('maxD');
            rows.add(r);
        }
        return rows;
    }

    @AuraEnabled
    public static Integer applyDiscounts(Id quoteId,
                                        Map<String, Decimal> familyToPct,
                                        Boolean onlyEmpty) {
        if (familyToPct == null || familyToPct.isEmpty()) return 0;

        Set<String> families = new Set<String>();
        Boolean includeNull = false;
        for (String k : familyToPct.keySet()) {
            if (k == '__NULL__') includeNull = true;
            else families.add(k);
        }

        String soql =
            'SELECT Id, Discount, PricebookEntry.Product2.Family ' +
            'FROM QuoteLineItem WHERE QuoteId = :quoteId ';

        if (!families.isEmpty() && includeNull) {
            soql += 'AND (PricebookEntry.Product2.Family IN :families ' +
                    'OR PricebookEntry.Product2.Family = null) ';
        } else if (!families.isEmpty()) {
            soql += 'AND PricebookEntry.Product2.Family IN :families ';
        } else if (includeNull) {
            soql += 'AND PricebookEntry.Product2.Family = null ';
        }

        List<QuoteLineItem> lines = Database.query(soql);

        Integer updated = 0;
        for (QuoteLineItem qli : lines) {
            String fam = qli.PricebookEntry.Product2.Family;
            String key = (fam == null) ? '__NULL__' : fam;
            Decimal d = familyToPct.get(key);
            if (d == null) continue;

            if (onlyEmpty == true && (qli.Discount != null && qli.Discount != 0)) {
                continue; 
            }
            qli.Discount = d;
            updated++;
        }
        if (updated > 0) update lines;
        return updated;
    }

}

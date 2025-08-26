public with sharing class GetProductAmount {
    public class Req {
        @InvocableVariable(required=true) public List<String> productNames;
        @InvocableVariable(required=true) public Id pricebookId;
    }

    @InvocableMethod(label='Get Prices by Product Names')
    public static List<List<PricebookEntry>> run(List<Req> reqs) {
        if (reqs == null || reqs.isEmpty()) throw new AuraHandledException('No request.');
        Req r = reqs[0];
        if (r.productNames == null || r.productNames.isEmpty()) throw new AuraHandledException('productNames is required.');
        if (r.pricebookId == null) throw new AuraHandledException('pricebookId is required.');

        Set<String> cleanNames = new Set<String>();
        
        for (String name : r.productNames) {
            if (String.isNotBlank(name)) {
                String trimmedName = name.trim();
                
                if (trimmedName.contains(';')) {
                    String[] parts = trimmedName.split(';');
                    for (String part : parts) {
                        if (String.isNotBlank(part)) {
                            cleanNames.add(part.trim());
                        }
                    }
                } else {
                    cleanNames.add(trimmedName);
                }
            }
        }
        
        if (cleanNames.isEmpty()) {
            throw new AuraHandledException('No valid product names provided.');
        }

        List<PricebookEntry> rows = [
            SELECT Id, UnitPrice, CurrencyIsoCode, Product2Id, PricebookEntry.Name
            FROM PricebookEntry
            WHERE Pricebook2Id = :r.pricebookId
              AND IsActive = true
              AND PricebookEntry.Name IN :cleanNames
            ORDER BY PricebookEntry.Name
        ];
        return new List<List<PricebookEntry>>{ rows };
    }
}
public with sharing class ProductSelectorFlow {
    public class Request {
        @InvocableVariable(required=true)
        public List<String> families;
    }
    
    @InvocableMethod(label='Get FnB Products by Families')
    public static List<List<Product2>> run(List<Request> reqs) {
        if (reqs == null || reqs.isEmpty()) {
            throw new AuraHandledException('No request received. Map Screen 1 selection to this Apex action.');
        }
        
        Request r = reqs[0];
        
        if (r == null || r.families == null || r.families.isEmpty()) {
            throw new AuraHandledException(
                'Required input "families" is missing. Ensure Screen 1 outputs a selection and is mapped to this action.'
            );
        }
        
        Set<String> familiesSet = new Set<String>();
        for (String s : r.families) {
            if (String.isBlank(s)) continue;
            String val = s.trim();
            if (val.contains(';')) {
                String[] parts = val.split(';');
                for (String part : parts) {
                    if (!String.isBlank(part)) {
                        familiesSet.add(part.trim());
                    }
                }
            } else {
                familiesSet.add(val);
            }
        }
        
        if (familiesSet.isEmpty()) {
            throw new AuraHandledException('Families parsed to empty set. Check mapping/values from Screen 1.');
        }
        
        List<Product2> products = [
            SELECT Id, Name, Family
            FROM Product2
            WHERE IsActive = true
              AND Family IN :familiesSet
            ORDER BY Family, Name
            LIMIT 1000
        ];
        
        return new List<List<Product2>>{ products };
    }
}

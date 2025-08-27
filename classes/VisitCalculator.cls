public class VisitCalculator {

    public static void updateActualVisitsByIndustry(String inputIndustry) {
        List<Target_Visit__c> targetVisits = [
            SELECT Id, Account__c, Industry__c 
            FROM Target_Visit__c 
            WHERE Industry__c = :inputIndustry
        ];

        if (targetVisits.isEmpty()) {
            System.debug('Tidak ada Target Visit dengan industry: ' + inputIndustry);
            return;
        }
        
        Set<Id> accountIds = new Set<Id>();
        for (Target_Visit__c tv : targetVisits) {
            accountIds.add(tv.Account__c);
        }

        List<Visit__c> completedVisits = [
            SELECT Id, Account__c 
            FROM Visit__c 
            WHERE Account__c IN :accountIds 
              AND Visit_Status__c = 'Completed'
        ];

        Map<Id, Integer> visitCountByAccount = new Map<Id, Integer>();
        for (Visit__c visit : completedVisits) {
            if (!visitCountByAccount.containsKey(visit.Account__c)) {
                visitCountByAccount.put(visit.Account__c, 1);
            } else {
                visitCountByAccount.put(visit.Account__c, visitCountByAccount.get(visit.Account__c) + 1);
            }
        }

        for (Target_Visit__c tv : targetVisits) {
            Integer count = visitCountByAccount.containsKey(tv.Account__c) 
                            ? visitCountByAccount.get(tv.Account__c) 
                            : 0;
            tv.Actual_Visit__c = count;
        }

        update targetVisits;
    }
}
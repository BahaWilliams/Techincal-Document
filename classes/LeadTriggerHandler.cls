public with sharing class LeadTriggerHandler extends TriggerHandler {

    protected override void beforeInsert() {
        validateLead((List<Lead>)Trigger.new, null);
    }

    protected override void beforeUpdate() {
        validateLead((List<Lead>)Trigger.new, (Map<Id, Lead>)Trigger.oldMap);
    }

    private static Set<String> CONVERTED_STATUSES;
    static {
        List<LeadStatus> convertedLeadStatuses = [SELECT ApiName FROM LeadStatus WHERE IsConverted = true];
        CONVERTED_STATUSES = new Set<String>();
        for (LeadStatus ls : convertedLeadStatuses) {
            CONVERTED_STATUSES.add(ls.ApiName);
        }
    }

    private void validateLead(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        for (Lead ld : newLeads) {

            if (ld.IsConverted || CONVERTED_STATUSES.contains(ld.Status)) {
                continue;
            }

            Boolean hasEmail = !String.isBlank(ld.Email);
            Boolean hasPhone = !String.isBlank(ld.Phone) || !String.isBlank(ld.MobilePhone);

            if (!hasEmail && !hasPhone) {
                ld.addError('Please provide at least a Phone/Mobile or an Email.');
            }
        }
    }
}
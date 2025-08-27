public class LeadConvertHandler {
    @future
    public static void convertLeadAsync(Id leadId) {
        LeadStatus convertStatus = [SELECT Id, ApiName FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(convertStatus.ApiName);

        try {
            Database.LeadConvertResult lcr = Database.convertLead(lc);
        } catch (Exception e) {
            System.debug('Error converting lead: ' + e.getMessage());
        }
    }
}
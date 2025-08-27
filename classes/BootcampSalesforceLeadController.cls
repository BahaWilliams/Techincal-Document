public with sharing class BootcampSalesforceLeadController {
    //buat lazy reload V
    //buat update langsung di table V
    //buat auto delete V
    //buat validasi input ketika email jika salah maka keluar pop up warning
    //buat validasi input ketika lastname jika salah maka keluar pop up warning
    //buat update button dalam tiap row dimana akan update data
    @AuraEnabled
    public static List<Lead> getLeads(){
        return [SELECT Id, FirstName, LastName, Company FROM Lead ORDER BY CreatedDate DESC LIMIT 10];
    }

    @AuraEnabled    
    public static String saveLead(Object dt){
        String message = '';
        try {
            Map<String,Object> dataLead = (Map<String,Object>) JSON.deserializeUntyped(JSON.serializePretty(dt));

            String email = (String) dataLead.get('email');
            String lastName = (String) dataLead.get('lastName');
            String id = (String) dataLead.get('id');

            if (String.isBlank(email)) {
                throw new AuraHandledException('Email is required.');
            } else if (String.isBlank(lastName)) {
                throw new AuraHandledException('Last name is required.');
            }

            Lead lead;

            if (!String.isBlank(id)) {
                lead = [SELECT Id, FirstName, LastName, Email, Company FROM Lead WHERE Id = :id LIMIT 1];
            } else {
                lead = new Lead();
            }

            lead.FirstName = (String) dataLead.get('firstName');
            lead.LastName = lastName;
            lead.Email = email;
            lead.Company = (String) dataLead.get('company');

            if (!String.isBlank(id)) {
                update lead;
            } else {
                insert lead;
            }

            message = 'success';
        } catch (Exception ex) {
            message = 'error';
            throw new AuraHandledException(ex.getMessage());
        }

        return message;
    }

    @AuraEnabled
    public static String deleteLead(String leadId) {
        try {
            if (String.isBlank(leadId)) {
                throw new AuraHandledException('Lead Id is required for deletion.');
            }

            Lead ld = [SELECT Id FROM Lead WHERE Id = :leadId LIMIT 1];
            delete ld;

            return 'success';
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

}
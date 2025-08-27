public with sharing class BootcampPaymentController {
    @AuraEnabled
    public static List<InvoiceCustom__c> getInvouce(){
        return [SELECT Id, Amount__c, Customer__c, Payment_Date__c, Expire_Date__c, Status__c, Customer__r.Name
        FROM InvoiceCustom__c 
        WHERE Customer__c != null
        ORDER BY CreatedDate 
        DESC LIMIT 5];
    }

    @AuraEnabled
    public static List<Account> getAllAccount() {
        return [SELECT Id, Name
        FROM Account 
        LIMIT 50];
    }


    @AuraEnabled
    public static InvoiceCustom__c createInvoice(InvoiceCustom__c invoice) {
        insert invoice;
        return invoice;
    }


}
public with sharing class LwcPaymentController {

    public class CreateResult {
        @AuraEnabled public Id     recordId;
        @AuraEnabled public String status;
        @AuraEnabled public String externalPaymentId;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklists() {
        Map<String, List<String>> out = new Map<String, List<String>>();
        out.put('paymentMethods', getValues('Payment_Record__c', 'Payment_Method__c'));
        out.put('paymentDates',   getValues('Payment_Record__c', 'Payment_Dates__c'));
        out.put('statuses',       getValues('Payment_Record__c', 'Status__c'));
        return out;
    }

    private static List<String> getValues(String sObj, String field) {
        List<String> vals = new List<String>();
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(sObj);
        if (sType == null) return vals;
        Schema.DescribeSObjectResult d = sType.getDescribe();
        Schema.SObjectField f = d.fields.getMap().get(field);
        if (f == null) return vals;
        for (Schema.PicklistEntry pe : f.getDescribe().getPicklistValues()) {
            if (pe.isActive()) vals.add(pe.getValue());
        }
        return vals;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDerived(Id contactId, Id quoteId) {
        Map<String, Object> out = new Map<String, Object>();
        out.put('email',  null);
        out.put('amount', null);

        if (contactId != null) {
            Contact c = [SELECT Email FROM Contact WHERE Id = :contactId LIMIT 1];
            out.put('email', c.Email);
        }
        if (quoteId != null) {
            Quote q = [SELECT GrandTotal FROM Quote WHERE Id = :quoteId LIMIT 1];
            out.put('amount', (q.GrandTotal != null ? q.GrandTotal.setScale(0) : null));
        }
        return out;
    }

    @AuraEnabled
    public static CreateResult createPayment(
        Id accountId,
        Id contactId,
        Id opportunityId,
        Id quoteId,
        Id contractId,
        String paymentMethod,
        String paymentDates,
        String statusValue,
        Boolean callApiNow,        
        Id contractRecordIdContext 
    ) {
        CreateResult res = new CreateResult();

        String email = null;
        Decimal amount = null;

        if (contactId != null) {
            Contact c = [SELECT Email FROM Contact WHERE Id = :contactId LIMIT 1];
            email = c.Email;
        }
        if (quoteId != null) {
            Quote q = [SELECT GrandTotal FROM Quote WHERE Id = :quoteId LIMIT 1];
            amount = (q.GrandTotal != null ? q.GrandTotal.setScale(0) : null);
        }

        if (contractId == null && contractRecordIdContext != null) {
            contractId = contractRecordIdContext;
        }

        Payment_Record__c pr = new Payment_Record__c(
            Company_Account__c = accountId,
            SalesforceRef__c   = opportunityId,
            Contact__c         = contactId,
            Quote__c           = quoteId,
            Contract__c        = contractId,
            Payment_Method__c  = paymentMethod,
            Payment_Dates__c   = paymentDates,
            Status__c          = statusValue,
            CurrencyIsoCode    = 'IDR',
            Email__c           = email,
            Amount__c          = amount
        );
        insert pr;

        if (Boolean.valueOf(callApiNow)) {
            PaymentControllerAPI.createForRecord(pr.Id, false); 
            res.message = 'Record created & API enqueued (async).';
        } else {
            res.message = 'Record created; Trigger will enqueue API (async).';
        }

        res.recordId = pr.Id;

        Payment_Record__c got = [
            SELECT ExternalPaymentId__c, Status__c
            FROM Payment_Record__c WHERE Id = :pr.Id
        ];
        res.externalPaymentId = got.ExternalPaymentId__c;
        res.status            = got.Status__c;

        return res;
    }
}

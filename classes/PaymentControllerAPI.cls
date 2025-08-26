public with sharing class PaymentControllerAPI {

    public class PaymentDTO {
        @AuraEnabled public Id     recordId;
        @AuraEnabled public String externalPaymentId;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static PaymentDTO createForRecord(Id paymentRecordId, Boolean runSync) {
        if (paymentRecordId == null) {
            throw new AuraHandledException('paymentRecordId is required.');
        }

        Payment_Record__c pr = [
            SELECT Id, Company_Account__r.Name, SalesforceRef__c, Amount__c, Email__c,
                   Contact__r.Email, Contact__r.Phone,
                   Payment_Method__c, Payment_Dates__c, CurrencyIsoCode,
                   ExternalPaymentId__c, Status__c
            FROM Payment_Record__c
            WHERE Id = :paymentRecordId
            LIMIT 1
        ];

        PaymentDTO dto = new PaymentDTO();
        dto.recordId = pr.Id;

        if (runSync == true) {
            try {
                Map<String,Object> body = buildBody(pr);
                System.debug('ROUTE=ControllerSync recordId=' + pr.Id);
                System.debug('REQ BODY (SYNC): ' + JSON.serialize(body));

                HttpResponse res = PaymentService.createNewData(JSON.serialize(body));
                System.debug('RES STATUS (SYNC): ' + res.getStatus());
                System.debug('RES BODY   (SYNC): ' + res.getBody());

                Integer sc = res.getStatusCode();
                if (sc < 200 || sc >= 300) {
                    throw new CalloutException('Create payment failed: ' + res.getStatus() + ' Body: ' + res.getBody());
                }

                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                Map<String, Object> rowMap;
                Object dataNode = parsed.get('data');
                if (dataNode == null) {
                    rowMap = parsed; 
                } else if (dataNode instanceof List<Object>) {
                    List<Object> lst = (List<Object>) dataNode;
                    if (lst.isEmpty()) throw new CalloutException('Create payment success but empty data array.');
                    rowMap = (Map<String, Object>) lst[0];
                } else {
                    rowMap = (Map<String, Object>) dataNode;
                }

                String externalId = (String) rowMap.get('id');
                String apiStatus  = (String) rowMap.get('transaction_status');
                String mapped     = mapApiStatusToPicklist(apiStatus);

                pr.ExternalPaymentId__c = externalId;
                pr.Status__c            = (mapped != null ? mapped : 'Pending');
                update pr;

                dto.externalPaymentId = pr.ExternalPaymentId__c;
                dto.status            = pr.Status__c;
                dto.message           = 'Created via sync';
            } catch (Exception e) {
                pr.Status__c = 'Pending'; 
                update pr;
                dto.status  = 'Pending';
                dto.message = e.getMessage();
            }
        } else {
            CreatePaymentQueueable.enqueueFor(new List<Payment_Record__c>{ pr });
            dto.externalPaymentId = pr.ExternalPaymentId__c;
            dto.status            = pr.Status__c;
            dto.message           = 'Queued';
        }
        return dto;
    }

    private static Map<String, Object> buildBody(Payment_Record__c pr) {
        Map<String, Object> m = new Map<String, Object>();

        String method = mapMethod(pr.Payment_Method__c);
        m.put('payment_method', method);
        m.put('payment_type',   method);

        String details;
        if (method == 'bank_transfer') {
            details = 'BCA';
        } else if (method == 'qris') {
            details = (pr.Payment_Dates__c != null ? pr.Payment_Dates__c.toLowerCase() : 'qris');
        } else if (method == 'cash') {
            details = 'cash';
        } else if (method == 'credit_card') {
            details = 'visa';
        } else if (method == 'debit_card') {
            details = 'debit';
        } else {
            details = method;
        }
        m.put('payment_details', details);

        if (pr.Amount__c != null) m.put('amount', String.valueOf(pr.Amount__c.setScale(2)));

        Map<String, Object> txn = new Map<String, Object>();
        txn.put('salesforce_id', pr.SalesforceRef__c != null ? String.valueOf(pr.SalesforceRef__c) : String.valueOf(pr.Id));
        if (pr.Amount__c != null) txn.put('amount', pr.Amount__c.setScale(0));
        m.put('transaction_detail', txn);

        String email    = (pr.Email__c != null && pr.Email__c.trim() != '') ? pr.Email__c
                         : (pr.Contact__r != null ? pr.Contact__r.Email : null);
        String fullname = (pr.Company_Account__r != null ? pr.Company_Account__r.Name : null);
        String phone    = (pr.Contact__r != null ? pr.Contact__r.Phone : null);

        Map<String, Object> cust = new Map<String, Object>();
        cust.put('first_name', fullname);
        cust.put('fullname',   fullname);
        cust.put('email',      email);
        if (phone != null) cust.put('phone', phone);
        m.put('customer', cust);

        if (pr.CurrencyIsoCode != null) m.put('currency', pr.CurrencyIsoCode);
        if (pr.Payment_Dates__c != null) m.put('schedule', pr.Payment_Dates__c);

        return m;
    }

    private static String mapMethod(String pick) {
        if (pick == null) return 'bank_transfer';
        String p = pick.toLowerCase();
        if (p == 'qris')          return 'qris';
        if (p == 'transfer')      return 'bank_transfer';
        if (p == 'credit card')   return 'credit_card';
        if (p == 'debit')         return 'debit_card';
        if (p == 'cash')          return 'cash';
        return 'bank_transfer';
    }

    private static String mapApiStatusToPicklist(String api) {
        if (api == null) return null;
        String a = api.toLowerCase();
        if (a == 'paid' || a == 'success')    return 'Paid';
        if (a == 'cancel' || a == 'canceled') return 'Cancelled';
        if (a == 'pending' || a == 'created') return 'Pending';
        return null;
    }
}

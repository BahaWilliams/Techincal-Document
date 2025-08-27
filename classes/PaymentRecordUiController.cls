public with sharing class PaymentRecordUiController {

    public class RowDTO {
        @AuraEnabled public String  status;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  paymentMethod;
        @AuraEnabled public String  customerName;
        @AuraEnabled public String  email;
        @AuraEnabled public String  dueDate;
    }

    // LIST Payment_Record__c per Contract
    @AuraEnabled(cacheable=true)
    public static List<RowDTO> listByContract(Id contractId){
        if (contractId == null) return new List<RowDTO>();

        List<RowDTO> out = new List<RowDTO>();
        for (Payment_Record__c p : [
            SELECT Status__c, Amount__c, Payment_Method__c,
                   Email__c, Company_Account__r.Name
            FROM Payment_Record__c
            WHERE Contract__c = :contractId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            RowDTO r = new RowDTO();
            r.status       = p.Status__c;
            r.amount       = p.Amount__c;
            r.paymentMethod= p.Payment_Method__c;
            r.customerName = (p.Company_Account__r != null ? p.Company_Account__r.Name : null);
            r.email        = p.Email__c;
            // r.dueDate      = (p.DueDate__c != null ? String.valueOf(p.DueDate__c) : null);
            out.add(r);
        }
        return out;
    }

    // CREATE Payment_Record__c dari UI + jalankan Queueable (panggil API)
    @AuraEnabled
    public static Id createPaymentForContract(
        Id contractId,
        Id accountId,
        Id opportunityId,
        Id quoteId,
        String email,
        String paymentMethod,   // cash | credit_card | qris | transfer | debit
        String paymentDates,    // Monthly | Weekly
        Date   contractStartDate,   // ⬅️ BARU: tanggal dari UI (opsional)
        Date   contractDueDate      // ⬅️ BARU: tanggal dari UI (opsional)
    ){
        if (contractId == null)   throw new AuraHandledException('Contract wajib dipilih.');
        if (accountId == null)    throw new AuraHandledException('Account wajib dipilih.');
        if (opportunityId == null)throw new AuraHandledException('Opportunity wajib dipilih.');
        if (quoteId == null)      throw new AuraHandledException('Quote wajib dipilih.');
        if (String.isBlank(email))          throw new AuraHandledException('Email wajib diisi.');
        if (String.isBlank(paymentMethod))  throw new AuraHandledException('Payment Method wajib dipilih.');
        if (String.isBlank(paymentDates))   throw new AuraHandledException('Payment Dates wajib dipilih.');

        // Ambil Contract (untuk fallback tanggal & default Account)
        Contract c = [
            SELECT Id, StartDate, Contract_Due_Date__c, AccountId
            FROM Contract
            WHERE Id = :contractId
            LIMIT 1
        ];

        // Ambil Quote total: GrandTotal -> fallback TotalPrice
        Quote q = [
            SELECT Id, GrandTotal, TotalPrice
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        Decimal amount = (q.GrandTotal != null) ? q.GrandTotal :
                        (q.TotalPrice  != null) ? q.TotalPrice : 0;

        // Tentukan tanggal dipakai: UI > Contract > null
        Date startDate = (contractStartDate != null) ? contractStartDate : c.StartDate;
        Date dueDate   = (contractDueDate   != null) ? contractDueDate   : c.Contract_Due_Date__c;

        // Insert Payment_Record__c
        Payment_Record__c pr = new Payment_Record__c();
        pr.Company_Account__c = accountId;
        pr.Contract__c        = contractId;
        pr.SalesforceRef__c   = opportunityId;
        pr.Quote__c           = quoteId;
        pr.Email__c           = email;
        pr.Payment_Method__c  = paymentMethod;
        pr.Payment_Dates__c   = paymentDates;

        if (amount != null) pr.Amount__c = amount;
        // if (startDate != null) pr.CreatedFrom__c = DateTime.newInstance(startDate, Time.newInstance(0,0,0,0));
        // if (dueDate   != null) pr.DueDate__c     = DateTime.newInstance(dueDate,   Time.newInstance(0,0,0,0));

        insert pr;

        // Rekomendasi arsitektur: biarkan Trigger yang enqueue Queueable
        // System.enqueueJob(new CreatePaymentQueueable(new Set<Id>{ pr.Id }));

        return pr.Id;
    }

}

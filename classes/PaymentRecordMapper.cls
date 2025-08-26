public with sharing class PaymentRecordMapper {

    /**
     * pr diharapkan sudah diquery lengkap, contoh:
     * SELECT Id, Name, Amount__c, Payment_Method__c, Payment_Dates__c, CurrencyIsoCode,
     *        SalesforceRef__c, Company_Account__r.Name, Quote__r.GrandTotal,
     *        Contact__r.Email, Email__c
     * FROM Payment_Record__c
     * WHERE Id = :id
     */
    public static Map<String, Object> toCreatePayload(Payment_Record__c pr) {
        if (pr == null) return new Map<String, Object>();

        // --- Normalisasi Payment Method (SF → API)
        String rawMethod = pr.Payment_Method__c;
        String method = normalizeMethod(rawMethod);
        // --- Normalisasi Payment Dates (SF → API)
        String paymentDetails = normalizePaymentDates(pr.Payment_Dates__c);

        // --- Amount: utamakan Amount__c; fallback ke Quote GrandTotal
        Decimal baseAmount = pr.Amount__c;
        if (baseAmount == null && pr.Quote__r != null) {
            baseAmount = pr.Quote__r.GrandTotal;
        }
        // jaga-jaga kalau negatif / null
        if (baseAmount == null) baseAmount = 0;
        if (baseAmount < 0)      baseAmount = 0;

        // integer utk transaction_detail.amount (API kamu terima integer)
        Integer trxAmountInt = Integer.valueOf(baseAmount.setScale(0));
        // string 2 desimal utk root "amount"
        String rootAmountStr = String.valueOf(baseAmount.setScale(2));

        // --- Email customer: Contact__r.Email → fallback ke Email__c
        String emailVal = (pr.Contact__r != null) ? String.valueOf(pr.Contact__r.Email) : null;
        if (String.isBlank(emailVal)) emailVal = pr.Email__c;

        // --- Nama customer: pakai nama Account
        String customerFirstName = (pr.Company_Account__r != null) ? pr.Company_Account__r.Name : null;

        // --- salesforce_id: utamakan Opportunity Id, fallback ke Name
        String salesforceRef = (pr.SalesforceRef__c != null)
            ? String.valueOf(pr.SalesforceRef__c)
            : pr.Name;

        // --- Currency dari record (fallback IDR)
        String currencyCode = String.isBlank(pr.CurrencyIsoCode) ? 'IDR' : pr.CurrencyIsoCode;

        // (Opsional) Validasi minimal sebelum kirim
        // if (String.isBlank(method))         throw new AuraHandledException('Payment Method wajib.');
        // if (String.isBlank(paymentDetails)) throw new AuraHandledException('Payment Dates wajib.');
        // if (String.isBlank(emailVal))       throw new AuraHandledException('Email wajib.');
        // if (String.isBlank(salesforceRef))  throw new AuraHandledException('SalesforceRef (Opp) wajib.');

        // ================= Susun payload =================
        Map<String, Object> payload = new Map<String, Object>{
            'payment_method'     => method,
            'payment_type'       => method,
            'payment_details'    => paymentDetails,          // Monthly/Weekly (atau versi normalized)
            'transaction_detail' => new Map<String, Object>{
                'salesforce_id' => salesforceRef,
                'amount'        => trxAmountInt
            },
            'customer' => new Map<String, Object>{
                'first_name' => customerFirstName,
                'last_name'  => '',
                'email'      => emailVal
            },
            'amount'   => rootAmountStr,                     // "123456.00"
            'currency' => currencyCode                       // biasanya 'IDR'
        };

        // ================= Rapikan null/blank =================
        // Root level
        for (String k : new List<String>(payload.keySet())) {
            Object v = payload.get(k);
            if (v == null || (v instanceof String && String.isBlank((String)v))) {
                // Jangan hapus transaction_detail/customer meskipun kosong; bersihkan di dalamnya
                if (k != 'transaction_detail' && k != 'customer') payload.remove(k);
            }
        }
        // transaction_detail
        if (payload.containsKey('transaction_detail')) {
            Map<String,Object> td = (Map<String,Object>) payload.get('transaction_detail');
            for (String k : new List<String>(td.keySet())) {
                Object v = td.get(k);
                if (v == null || (v instanceof String && String.isBlank((String)v))) {
                    td.remove(k);
                }
            }
            // pastikan salesforce_id tetap ada bila tersedia
            if (td.isEmpty()) payload.remove('transaction_detail');
        }
        // customer
        if (payload.containsKey('customer')) {
            Map<String,Object> cust = (Map<String,Object>) payload.get('customer');
            for (String k : new List<String>(cust.keySet())) {
                Object v = cust.get(k);
                if (v == null || (v instanceof String && String.isBlank((String)v))) {
                    cust.remove(k);
                }
            }
            if (cust.isEmpty()) payload.remove('customer');
        }

        return payload;
    }

    // ===== Helpers untuk normalisasi =====

    private static String normalizeMethod(String val) {
        if (String.isBlank(val)) return null;
        String v = val.trim().toLowerCase();
        // mapping label SF → kode API
        if (v == 'credit card' || v == 'kartu kredit' || v == 'credit_card') return 'credit_card';
        if (v == 'qris')       return 'qris';
        if (v == 'transfer' || v == 'bank transfer' || v == 'bank_transfer') return 'bank_transfer';
        if (v == 'debit')      return 'debit';
        if (v == 'cash' || v == 'tunai') return 'cash';
        // default: kirim apa adanya (lowercase)
        return v;
    }

    private static String normalizePaymentDates(String val) {
        if (String.isBlank(val)) return null;
        String v = val.trim().toLowerCase();
        if (v == 'monthly') return 'Monthly';
        if (v == 'weekly')  return 'Weekly';
        // default: pakai as-is
        return val;
    }
}

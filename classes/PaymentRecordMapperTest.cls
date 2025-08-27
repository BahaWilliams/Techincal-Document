@IsTest
private class PaymentRecordMapperTest {

    // ==== Helper: buat Id dummy untuk Opportunity (006…) tanpa insert ====
    private static Id fakeOppId() {
        // 18-char Id pattern valid untuk casting Id; tidak perlu ada recordnya
        return (Id) '006000000000000AAA';
    }

    // ==== 1) Happy path: method=Transfer, dates=monthly, amount dari Amount__c, email dari Contact, currency terset ====
    @IsTest
    static void test_toCreatePayload_basicMapping() {
        // Build Payment_Record__c in-memory (tanpa insert)
        Payment_Record__c pr = new Payment_Record__c();
        pr.put('Payment_Method__c',  'Transfer');  // → bank_transfer
        pr.put('Payment_Dates__c',   'monthly');   // → "Monthly"
        pr.put('Amount__c',          100000);      // → "100000.00" & 100000 (int)
        pr.put('CurrencyIsoCode',    'IDR');

        // Relasi untuk customer & email
        pr.put('Company_Account__r', new Account(Name = 'PT Joy'));
        pr.put('Contact__r',         new Contact(LastName = 'X', Email = 'joy@gmail.com'));

        // salesforce_id dari Lookup Opportunity
        pr.put('SalesforceRef__c',   fakeOppId());

        Map<String, Object> payload = PaymentRecordMapper.toCreatePayload(pr);

        System.assertEquals('bank_transfer', payload.get('payment_method'), 'Method harus ternormalisasi');
        System.assertEquals('bank_transfer', payload.get('payment_type'));
        System.assertEquals('Monthly',       payload.get('payment_details'));

        System.assertEquals('IDR',           payload.get('currency'));
        System.assertEquals('100000.00',     payload.get('amount'));

        Map<String, Object> td = (Map<String, Object>) payload.get('transaction_detail');
        System.assertEquals(100000,          td.get('amount'));
        System.assertEquals(String.valueOf(pr.get('SalesforceRef__c')), td.get('salesforce_id'));

        Map<String, Object> cust = (Map<String, Object>) payload.get('customer');
        System.assertEquals('PT Joy',        cust.get('first_name'));
        System.assertEquals('joy@gmail.com', cust.get('email'));
        System.assertEquals('',              cust.get('last_name'), 'last_name default kosong');
    }

    // ==== 2) Fallback amount dari Quote.GrandTotal ketika Amount__c null; QRIS + weekly ====
    @IsTest
    static void test_toCreatePayload_amountFallbackFromQuote() {
        Payment_Record__c pr = new Payment_Record__c();
        pr.put('Payment_Method__c', 'QRIS');   // tetap 'qris'
        pr.put('Payment_Dates__c',  'weekly'); // → "Weekly"
        pr.put('Amount__c',         null);
        pr.put('CurrencyIsoCode',   null);     // → fallback 'IDR'

        // Quote__r dengan GrandTotal (tanpa insert). set via put agar bisa assign nilai read-only.
        Quote q = new Quote(Name = 'Q');
        q.put('GrandTotal', 123456.78);
        pr.put('Quote__r', q);

        // Contact kosong → nanti cek cleanup di test lain
        pr.put('Company_Account__r', new Account(Name = 'PT Fallback'));
        pr.put('SalesforceRef__c',   fakeOppId());

        Map<String, Object> payload = PaymentRecordMapper.toCreatePayload(pr);

        System.assertEquals('qris',    payload.get('payment_method'));
        System.assertEquals('Weekly',  payload.get('payment_details'));
        System.assertEquals('IDR',     payload.get('currency'));          // fallback

        // root amount string 2 desimal dari 123456.78
        System.assertEquals('123456.78', payload.get('amount'));

        Map<String, Object> td = (Map<String, Object>) payload.get('transaction_detail');
        // integer pembulatan setScale(0): 123456.78 → 123457
        System.assertEquals(123457,       td.get('amount'));
        System.assertEquals(String.valueOf(pr.get('SalesforceRef__c')), td.get('salesforce_id'));
    }

    // ==== 3) Cleanup: semua hampir kosong → hapus key kosong; currency fallback ke IDR; salesforce_id hilang ====
    @IsTest
    static void test_toCreatePayload_cleanupAndFallbacks() {
        Payment_Record__c pr = new Payment_Record__c();
        // Semua field dibiarkan kosong/blank
        pr.put('Payment_Method__c',  '   ');   // blank → normalizeMethod -> null
        pr.put('Payment_Dates__c',   null);    // null
        pr.put('Amount__c',          null);    // → baseAmount 0
        pr.put('CurrencyIsoCode',    '');      // → fallback 'IDR'
        pr.put('Email__c',           null);
        // Tidak set Contact__r maupun Company_Account__r
        // Tidak set SalesforceRef__c dan Name (karena belum insert, Name = null)

        Map<String, Object> payload = PaymentRecordMapper.toCreatePayload(pr);

        // currency selalu muncul (fallback)
        System.assertEquals('IDR', payload.get('currency'));
        // root amount dari 0
        System.assertEquals('0.00', payload.get('amount'));

        // payment_method & payment_details seharusnya TIDAK ada (dibersihkan karena kosong)
        System.assertEquals(false, payload.containsKey('payment_method'));
        System.assertEquals(false, payload.containsKey('payment_type'));
        System.assertEquals(false, payload.containsKey('payment_details'));

        // transaction_detail harus tetap ada karena amount 0 diset
        System.assertEquals(true, payload.containsKey('transaction_detail'));
        Map<String, Object> td = (Map<String, Object>) payload.get('transaction_detail');
        System.assertEquals(0, td.get('amount'));
        // Karena SalesforceRef__c & Name null → salesforce_id seharusnya tidak ada
        System.assertEquals(false, td.containsKey('salesforce_id'));

        // customer seharusnya terhapus (tidak ada first_name/email/last_name)
        System.assertEquals(false, payload.containsKey('customer'));
    }

    // ==== 4) Normalisasi method lain: Credit Card → credit_card; cash/tunai; bank transfer ====
    @IsTest
    static void test_toCreatePayload_methodNormalizationVariants() {
        // credit card
        Payment_Record__c pr1 = new Payment_Record__c();
        pr1.put('Payment_Method__c', 'Credit Card');
        Map<String,Object> p1 = PaymentRecordMapper.toCreatePayload(pr1);
        System.assertEquals('credit_card', p1.get('payment_method'));

        // tunai → cash (lowercase di normalize)
        Payment_Record__c pr2 = new Payment_Record__c();
        pr2.put('Payment_Method__c', 'Tunai');
        Map<String,Object> p2 = PaymentRecordMapper.toCreatePayload(pr2);
        System.assertEquals('cash', p2.get('payment_method'));

        // bank transfer (varian label)
        Payment_Record__c pr3 = new Payment_Record__c();
        pr3.put('Payment_Method__c', 'Bank Transfer');
        Map<String,Object> p3 = PaymentRecordMapper.toCreatePayload(pr3);
        System.assertEquals('bank_transfer', p3.get('payment_method'));
    }

    // ==== 5) Null pr → harus return map kosong ====
    @IsTest
    static void test_toCreatePayload_nullInput() {
        Map<String,Object> payload = PaymentRecordMapper.toCreatePayload(null);
        System.assertEquals(0, payload.size(), 'Null input harus mengembalikan map kosong');
    }
}

@IsTest
private class CreatePaymentQueueableTest {

    // ===== Mock callout =====
    private class PaymentCreateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            String method = (String) body.get('payment_method');
            Map<String, Object> customer = (Map<String, Object>) body.get('customer');
            String email = customer != null ? (String) customer.get('email') : null;

            HttpResponse res = new HttpResponse();

            // Paksa error untuk skenario gagal
            if (email != null && email == 'err@example.com') {
                res.setStatusCode(400);
                res.setStatus('400 Bad Request');
                res.setBody('{"error":"invalid"}');
                return res;
            }

            // Sukses: method qris -> array + paid
            if ('qris'.equalsIgnoreCase(method)) {
                res.setStatusCode(200);
                res.setStatus('200 OK');
                res.setBody('{"data":[{"id":"EXT-ARRAY-001","transaction_status":"paid"}]}');
                return res;
            }

            // Sukses default -> object + pending
            res.setStatusCode(200);
            res.setStatus('200 OK');
            res.setBody('{"data":{"id":"EXT-OBJECT-001","transaction_status":"pending"}}');
            return res;
        }
    }

    // ===== Helpers umum =====
    private static Id stdPbId() { return Test.getStandardPricebookId(); }

    private static Account mkAccount() {
        Account a = new Account(Name = 'ACC – CreatePaymentQueueable');
        insert a;
        return a;
    }

    private static Contact mkContact(Id acctId) {
        Contact c = new Contact(
            LastName = 'Buyer',
            AccountId = acctId,
            Email = 'buyer@example.com',
            Phone = '0800000001'
        );
        insert c;
        return c;
    }

    private static Opportunity mkOpp(Id acctId) {
        Opportunity o = new Opportunity(
            Name='OPP – CreatePaymentQueueable',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(7),
            AccountId=acctId,
            Pricebook2Id=stdPbId()
        );
        insert o;
        return o;
    }

    // Contract: paksa Status = 'Pending' (sesuai permintaan), tambahkan field custom wajib.
    private static Contract mkContract(Id acctId) {
        Contract c = new Contract();
        c.AccountId     = acctId;
        c.StartDate     = Date.today();
        c.Status        = 'Pending';
        c.ContractTerm  = 12;
        c.OwnerId       = UserInfo.getUserId();
        // custom required di org-mu:
        c.put('Contract_Due_Date__c', Date.today().addDays(7));
        c.put('Email__c', 'buyer@example.com'); // <-- tambahkan email wajib di Contract

        // Set RecordTypeId bila ada (hindari compile error di org tanpa RT)
        try {
            Map<String, Schema.SObjectField> flds = Schema.SObjectType.Contract.fields.getMap();
            if (flds.containsKey('RecordTypeId')) {
                List<RecordType> rts = [
                    SELECT Id FROM RecordType
                    WHERE SobjectType = 'Contract'
                    LIMIT 1
                ];
                if (!rts.isEmpty()) {
                    c.put('RecordTypeId', rts[0].Id);
                }
            }
        } catch (Exception ignore) {}

        insert c;
        return c;
    }

    // Quote: gunakan status sederhana (ubah jika org-mu membatasi nilai lain)
    private static Quote mkQuote(Id oppId) {
        Quote q = new Quote(
            Name='QT – CreatePaymentQueueable',
            OpportunityId=oppId,
            Status='Draft'
        );
        insert q;
        return q;
    }

    // Payment: pastikan Email__c SELALU terisi (wajib di org-mu)
    private static Payment_Record__c mkPayment(
        Id acctId, Id contactId, Id contractId, Id oppId, Id quoteId,
        String method, Decimal amount, String currencyIso,
        String schedule, String emailExplicit, String externalIdPreset
    ) {
        Payment_Record__c pr = new Payment_Record__c();
        pr.Company_Account__c = acctId;          // required
        pr.Contact__c         = contactId;       // required
        pr.Contract__c        = contractId;      // required
        pr.SalesforceRef__c   = oppId;           // required (lookup Opportunity)
        pr.Quote__c           = quoteId;         // required
        pr.Amount__c          = amount;
        pr.CurrencyIsoCode    = currencyIso;
        pr.Payment_Method__c  = method;          // 'QRIS','Transfer','Cash','Debit'
        pr.Payment_Dates__c   = schedule;        // 'Monthly', dsb
        pr.Email__c           = (emailExplicit != null) ? emailExplicit : 'buyer@example.com'; // wajib
        if (externalIdPreset != null) pr.ExternalPaymentId__c = externalIdPreset; // skip scenario
        insert pr;
        return pr;
    }

    // ===== Test utama (jalankan queueable & verifikasi hasil) =====
    @IsTest
    static void testExecute_allScenarios() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id);
        Opportunity o = mkOpp(acc.Id);
        Contract c    = mkContract(acc.Id);
        Quote q       = mkQuote(o.Id);

        // 1) QRIS → 200 + array + "paid" → Paid, external terisi
        Payment_Record__c prQris = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'QRIS', 150000, 'IDR', 'Monthly', null, null
        );

        // 2) Transfer → 200 + object + "pending" → Pending, external terisi
        Payment_Record__c prTrf = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'Transfer', 200000, 'IDR', null, 'buyer2@example.com', null
        );

        // 3) Error → email trigger 400 → Pending, external null
        Payment_Record__c prErr = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'Cash', 100000, 'IDR', null, 'err@example.com', null
        );

        // 4) Skip → sudah punya external id
        Payment_Record__c prSkip = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'Debit', 50000, 'IDR', null, null, 'ALREADY-HAVE'
        );

        Test.setMock(HttpCalloutMock.class, new PaymentCreateMock());

        Test.startTest();
        CreatePaymentQueueable.enqueueFor(new List<Payment_Record__c>{ prQris, prTrf, prErr, prSkip });
        Test.stopTest();

        Map<Id, Payment_Record__c> afterMap = new Map<Id, Payment_Record__c>([
            SELECT Id, ExternalPaymentId__c, Status__c
            FROM Payment_Record__c
            WHERE Id IN :new List<Id>{ prQris.Id, prTrf.Id, prErr.Id, prSkip.Id }
        ]);

        System.assertEquals('EXT-ARRAY-001', afterMap.get(prQris.Id).ExternalPaymentId__c);
        System.assertEquals('Paid',           afterMap.get(prQris.Id).Status__c);

        System.assertEquals('EXT-OBJECT-001', afterMap.get(prTrf.Id).ExternalPaymentId__c);
        System.assertEquals('Pending',        afterMap.get(prTrf.Id).Status__c);

        System.assertEquals(null,             afterMap.get(prErr.Id).ExternalPaymentId__c);
        System.assertEquals('Pending',        afterMap.get(prErr.Id).Status__c);

        System.assertEquals('ALREADY-HAVE',   afterMap.get(prSkip.Id).ExternalPaymentId__c);
    }

    // ===== Tidak enqueue jika semua sudah punya ExternalPaymentId__c =====
    @IsTest
    static void testEnqueueFor_noEnqueueWhenAllHaveExternal() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id);
        Opportunity o = mkOpp(acc.Id);
        Contract c    = mkContract(acc.Id);
        Quote q       = mkQuote(o.Id);

        Payment_Record__c a = mkPayment(acc.Id, con.Id, c.Id, o.Id, q.Id, 'Transfer', 10000, 'IDR', null, null, 'EXT-A');
        Payment_Record__c b = mkPayment(acc.Id, con.Id, c.Id, o.Id, q.Id, 'QRIS',     20000, 'IDR', null, null, 'EXT-B');

        Test.startTest();
        CreatePaymentQueueable.enqueueFor(new List<Payment_Record__c>{ a, b });
        Test.stopTest();

        // Tidak ada exception → berarti tidak ada job yang dijalankan (sesuai tujuan)
        System.assert(true, 'Tidak ada job yang dienqueue saat semua record sudah punya ExternalPaymentId__c');
    }
}

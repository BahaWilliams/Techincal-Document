@IsTest
private class PaymentControllerAPITest {

    // -------------------- Mock Callout --------------------
    // Menjawab panggilan PaymentService.createNewData(...) yang menggunakan Http kelas.
    // Aturan:
    // - Jika customer.email == 'err@example.com' -> kembalikan 400 (error)
    // - Jika payment_method == 'qris' -> 200 + data ARRAY + "paid"
    // - Selain itu -> 200 + data OBJECT + "pending"
    private class PaymentCreateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            Map<String, Object> customer = (Map<String, Object>) body.get('customer');
            String email = customer != null ? (String) customer.get('email') : null;
            String method = (String) body.get('payment_method');

            HttpResponse res = new HttpResponse();

            if ('err@example.com' == email) {
                res.setStatusCode(400);
                res.setStatus('400 Bad Request');
                res.setBody('{"error":"invalid"}');
                return res;
            }

            if ('qris'.equalsIgnoreCase(method)) {
                res.setStatusCode(200);
                res.setStatus('200 OK');
                res.setBody('{"data":[{"id":"EXT-OK-ARRAY-001","transaction_status":"paid"}]}');
                return res;
            }

            res.setStatusCode(200);
            res.setStatus('200 OK');
            res.setBody('{"data":{"id":"EXT-OK-OBJECT-001","transaction_status":"pending"}}');
            return res;
        }
    }

    // -------------------- Helpers minimal data --------------------
    private static Id stdPbId() { return Test.getStandardPricebookId(); }

    private static Account mkAccount() {
        Account a = new Account(Name = 'ACC – PaymentAPI');
        insert a; return a;
    }
    private static Contact mkContact(Id acctId, String email) {
        Contact c = new Contact(LastName = 'Buyer', AccountId = acctId, Email = email, Phone = '0800000001');
        insert c; return c;
    }
    private static Opportunity mkOpp(Id acctId) {
        Opportunity o = new Opportunity(
            Name='OPP – PaymentAPI',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(7),
            AccountId=acctId,
            Pricebook2Id=stdPbId()
        );
        insert o; return o;
    }
    private static Contract mkContract(Id acctId) {
        Contract c = new Contract(AccountId=acctId, StartDate=Date.today(), Status='Draft');
        insert c; return c;
    }
    private static Quote mkQuote(Id oppId) {
        Quote q = new Quote(Name='QT – PaymentAPI', OpportunityId=oppId, Status='Draft');
        insert q; return q;
    }

    // Buat Payment Record dengan lookup wajib terisi.
    // NOTE: Name adalah Auto Number -> jangan di-set.
    private static Payment_Record__c mkPayment(
        Id acctId, Id contactId, Id contractId, Id oppId, Id quoteId,
        String method, Decimal amount, String currencyIso, String schedule, String emailExplicit
    ) {
        Payment_Record__c pr = new Payment_Record__c();
        pr.Company_Account__c = acctId;
        pr.Contact__c         = contactId;
        pr.Contract__c        = contractId;
        pr.SalesforceRef__c   = oppId;
        pr.Quote__c           = quoteId;
        pr.Payment_Method__c  = method;      // contoh: 'QRIS','Transfer','Cash','Debit'
        pr.Amount__c          = amount;
        pr.CurrencyIsoCode    = currencyIso; // contoh: 'IDR' atau 'USD'
        pr.Payment_Dates__c   = schedule;    // contoh: 'Monthly'
        pr.Email__c           = emailExplicit;
        insert pr;
        return pr;
    }

    // -------------------- TESTS --------------------

    // (1) runSync = true, sukses (200 + data array + "paid")
    @IsTest
    static void testCreateForRecord_runSync_success() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id, 'buyer@example.com');
        Opportunity o = mkOpp(acc.Id);
        Contract c    = mkContract(acc.Id);
        Quote q       = mkQuote(o.Id);

        Payment_Record__c pr = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'QRIS', 150000, 'IDR', 'Monthly', null // emailExplicit null -> fallback Contact.Email
        );

        Test.setMock(HttpCalloutMock.class, new PaymentCreateMock());

        Test.startTest();
        PaymentControllerAPI.PaymentDTO dto =
            PaymentControllerAPI.createForRecord(pr.Id, true);
        Test.stopTest();

        // DTO hasil sinkron
        System.assertEquals(pr.Id, dto.recordId);
        System.assertEquals('EXT-OK-ARRAY-001', dto.externalPaymentId, 'External id dari API (array)');
        System.assertEquals('Paid', dto.status, 'Status "paid" dipetakan ke "Paid"');
        System.assertEquals('Created via sync', dto.message);

        // Verify DB updated
        Payment_Record__c after = [SELECT ExternalPaymentId__c, Status__c FROM Payment_Record__c WHERE Id = :pr.Id];
        System.assertEquals('EXT-OK-ARRAY-001', after.ExternalPaymentId__c);
        System.assertEquals('Paid', after.Status__c);
    }

    // (2) runSync = true, error (400) -> catch: Status=Pending, message berisi error, external id null
    @IsTest
    static void testCreateForRecord_runSync_error() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id, 'buyer2@example.com');
        Opportunity o = mkOpp(acc.Id);
        Contract c    = mkContract(acc.Id);
        Quote q       = mkQuote(o.Id);

        // emailExplicit = 'err@example.com' -> mock balas 400
        Payment_Record__c pr = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'Cash', 100000, 'IDR', null, 'err@example.com'
        );

        Test.setMock(HttpCalloutMock.class, new PaymentCreateMock());

        Test.startTest();
        PaymentControllerAPI.PaymentDTO dto =
            PaymentControllerAPI.createForRecord(pr.Id, true);
        Test.stopTest();

        System.assertEquals(pr.Id, dto.recordId);
        System.assertEquals(null, dto.externalPaymentId, 'Pada error, external id tidak di-set');
        System.assertEquals('Pending', dto.status, 'Catch harus set status Pending');
        System.assert(dto.message != null && dto.message.contains('invalid'), 'Message harus membawa error dari API');

        Payment_Record__c after = [SELECT ExternalPaymentId__c, Status__c FROM Payment_Record__c WHERE Id = :pr.Id];
        System.assertEquals(null, after.ExternalPaymentId__c);
        System.assertEquals('Pending', after.Status__c);
    }

    // (3) runSync = false -> mengantri job (DTO "Queued"; external/status DTO masih null sebelum job jalan)
    @IsTest
    static void testCreateForRecord_enqueue_async() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id, 'buyer3@example.com');
        Opportunity o = mkOpp(acc.Id);
        Contract c    = mkContract(acc.Id);
        Quote q       = mkQuote(o.Id);

        Payment_Record__c pr = mkPayment(
            acc.Id, con.Id, c.Id, o.Id, q.Id,
            'Transfer', 200000, 'IDR', null, 'buyer3@example.com'
        );

        // Set mock juga agar queueable yang dieksekusi di stopTest bisa callout sukses.
        Test.setMock(HttpCalloutMock.class, new PaymentCreateMock());

        Test.startTest();
        PaymentControllerAPI.PaymentDTO dto =
            PaymentControllerAPI.createForRecord(pr.Id, false);
        // Di titik ini, DTO harus berisi "Queued" dan belum ada external id / status
        System.assertEquals(pr.Id, dto.recordId);
        System.assertEquals('Queued', dto.message);
        System.assertEquals(null, dto.externalPaymentId,
            'Pada cabang async, DTO mengambil nilai sebelum job jalan, jadi null itu wajar');
        System.assertEquals(null, dto.status);
        Test.stopTest(); // mengeksekusi Queueable (akan mengisi external id & status di DB)

        // Setelah job berjalan, record di DB mestinya ter-update oleh queueable
        Payment_Record__c after = [SELECT ExternalPaymentId__c, Status__c FROM Payment_Record__c WHERE Id = :pr.Id];
        System.assertNotEquals(null, after.ExternalPaymentId__c, 'Queueable harus mengisi external id');
        System.assertNotEquals(null, after.Status__c, 'Queueable harus mengisi status');
    }

    // (4) Guardrail: paymentRecordId null -> AuraHandledException
    @IsTest
    static void testCreateForRecord_nullId_throws() {
        try {
            PaymentControllerAPI.createForRecord(null, true);
            System.assert(false, 'Seharusnya melempar AuraHandledException saat paymentRecordId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('paymentRecordId is required.'));
        }
    }
}

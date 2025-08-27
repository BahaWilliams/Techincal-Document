@IsTest
private class LwcPaymentControllerTest {

    // ===== Mock callout untuk Queueable (CreatePaymentQueueable) =====
    private class PaymentCreateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // baca body untuk menentukan response
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            String method = (String) body.get('payment_method');

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('200 OK');

            // Bila QRIS → array + paid; selain itu → object + pending
            if ('qris'.equalsIgnoreCase(method)) {
                res.setBody('{"data":[{"id":"EXT-ARRAY-001","transaction_status":"paid"}]}');
            } else {
                res.setBody('{"data":{"id":"EXT-OBJECT-001","transaction_status":"pending"}}');
            }
            return res;
        }
    }

    // ===== Helpers data minimal =====
    private static Account mkAccount() {
        Account a = new Account(Name = 'ACC – LWC Payment');
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
            Name='OPP – LWC Payment',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(7),
            AccountId=acctId
        );
        insert o; 
        return o;
    }

    // Contract dengan field custom wajib sesuai org-mu
    private static Contract mkContract(Id acctId) {
        Contract c = new Contract();
        c.AccountId    = acctId;
        c.StartDate    = Date.today();
        c.Status       = 'Pending';                 // sesuai permintaan sebelumnya
        c.ContractTerm = 12;
        c.OwnerId      = UserInfo.getUserId();
        c.put('Contract_Due_Date__c', Date.today().addDays(7)); // custom required
        c.put('Email__c', 'buyer@example.com');                 // custom required
        insert c;
        return c;
    }

    private static Quote mkQuote(Id oppId) {
        Quote q = new Quote(
            Name='QT – LWC Payment',
            OpportunityId=oppId,
            Status='Draft'
        );
        insert q;
        return q;
    }

    // ===== TESTS =====

    @IsTest
    static void test_getPicklists_returnsLists() {
        Test.startTest();
        Map<String, List<String>> pl = LwcPaymentController.getPicklists();
        Test.stopTest();

        System.assertNotEquals(null, pl, 'Map picklists tidak boleh null');
        System.assertEquals(true, pl.containsKey('paymentMethods'));
        System.assertEquals(true, pl.containsKey('paymentDates'));
        System.assertEquals(true, pl.containsKey('statuses'));
        // Tidak memaksa size > 0 karena picklist bisa saja kosong di org tertentu
        System.assertNotEquals(null, pl.get('paymentMethods'));
        System.assertNotEquals(null, pl.get('paymentDates'));
        System.assertNotEquals(null, pl.get('statuses'));
    }

    @IsTest
    static void test_getDerived_emailAndAmount() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id);
        Opportunity o = mkOpp(acc.Id);
        Quote q       = mkQuote(o.Id);

        Test.startTest();
        Map<String, Object> derived = LwcPaymentController.getDerived(con.Id, q.Id);
        Test.stopTest();

        System.assertEquals('buyer@example.com', (String)derived.get('email'), 'Email harus dari Contact');
        // GrandTotal sulit diset tanpa line kalkulasi; amount mungkin null → itu OK
        // Hanya pastikan key ada
        System.assertEquals(true, derived.containsKey('amount'));
    }

    @IsTest
    static void test_createPayment_enqueueViaApiNow_qris_paid() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id);
        Opportunity o = mkOpp(acc.Id);
        Quote q       = mkQuote(o.Id);
        Contract c    = mkContract(acc.Id);

        // Mock callout untuk job queueable
        Test.setMock(HttpCalloutMock.class, new PaymentCreateMock());

        Test.startTest();
        LwcPaymentController.CreateResult res = LwcPaymentController.createPayment(
            acc.Id,
            con.Id,
            o.Id,
            q.Id,
            c.Id,               // contractId explicit
            'QRIS',             // paymentMethod → mock akan balas paid
            'Monthly',          // paymentDates
            'Pending',          // statusValue (nilai awal; nanti akan diupdate oleh job)
            true,               // callApiNow → enqueued async via Queueable
            null                // contractRecordIdContext (tak dipakai karena contractId sudah diisi)
        );
        Test.stopTest();

        System.assertNotEquals(null, res, 'CreateResult tidak boleh null');
        System.assertNotEquals(null, res.recordId, 'Record harus tercipta');
        System.assertEquals('Record created & API enqueued (async).', res.message);

        // Setelah job jalan (stopTest), status harus di-update oleh queueable → 'Paid' untuk QRIS
        // dan external id dari mock
        System.assertEquals('Paid', res.status);
        System.assertEquals('EXT-ARRAY-001', res.externalPaymentId);
    }

    @IsTest
    static void test_createPayment_usesContractRecordIdContext_whenContractIdNull() {
        Account acc   = mkAccount();
        Contact con   = mkContact(acc.Id);
        Opportunity o = mkOpp(acc.Id);
        Quote q       = mkQuote(o.Id);
        Contract c    = mkContract(acc.Id);   // akan dipakai via contractRecordIdContext

        Test.setMock(HttpCalloutMock.class, new PaymentCreateMock());

        Test.startTest();
        LwcPaymentController.CreateResult res = LwcPaymentController.createPayment(
            acc.Id,
            con.Id,
            o.Id,
            q.Id,
            null,              // contractId sengaja null
            'Transfer',        // mock akan balas pending untuk non-QRIS
            'Weekly',
            'Pending',
            true,              // enqueue via API
            c.Id               // dipakai untuk mengisi contractId
        );
        Test.stopTest();

        System.assertNotEquals(null, res.recordId, 'Record harus tercipta');
        // Untuk non-QRIS, mock beri 'pending' → queueable map ke 'Pending'
        System.assertEquals('Pending', res.status);
        System.assertEquals('EXT-OBJECT-001', res.externalPaymentId);
        System.assertEquals('Record created & API enqueued (async).', res.message);
    }
}

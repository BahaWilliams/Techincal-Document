@IsTest
private class QuoteFamilyDiscountControllerTest {

    // ===== Helpers umum =====
    private static Id stdPbId() {
        return Test.getStandardPricebookId();
    }
    private static String corpIso() {
        try {
            return [SELECT IsoCode FROM CurrencyType WHERE IsCorporate = true LIMIT 1].IsoCode;
        } catch (Exception e) {
            return 'USD';
        }
    }

    private static Account mkAccount(String name) {
        Account a = new Account(Name = name);
        insert a; return a;
    }
    private static Opportunity mkOpp(Id accId, Id pbId, String name, String iso) {
        Opportunity o = new Opportunity(
            Name = name,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(7),
            AccountId = accId,
            Pricebook2Id = pbId
        );
        o.put('CurrencyIsoCode', iso);
        insert o; return o;
    }
    private static Quote mkQuote(Id oppId, Id pbId, String iso) {
        Quote q = new Quote(
            Name = 'Q – Family Discount',
            OpportunityId = oppId,
            Pricebook2Id = pbId,
            Status = 'Draft'
        );
        q.put('CurrencyIsoCode', iso);
        insert q; return q;
    }
    private static Product2 mkProduct(String name, String family) {
        Product2 p = new Product2(Name = name, Family = family, IsActive = true);
        insert p; return p;
    }
    private static PricebookEntry mkPbe(Id pbId, Id productId, Decimal listPrice, String iso) {
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id   = productId,
            UnitPrice    = listPrice,
            IsActive     = true
        );
        pbe.put('CurrencyIsoCode', iso);
        insert pbe; return pbe;
    }
    private static QuoteLineItem mkQli(Id quoteId, Id pbeId, Decimal qty, Decimal unitPrice, Decimal discountOrNull) {
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId          = quoteId,
            PricebookEntryId = pbeId,
            Quantity         = qty,
            UnitPrice        = unitPrice
        );
        if (discountOrNull != null) qli.Discount = discountOrNull;
        insert qli; return qli;
    }

    // ===== Setup bundle =====
    private class SetupBundle {
        String iso;
        Id pbId;
        Account acc;
        Opportunity opp;
        Quote q;
        // Families: 'NDL', 'BVR', and null
        Product2 pNdlA; Product2 pNdlB; Product2 pBvr; Product2 pNull;
        PricebookEntry pbeNdlA; PricebookEntry pbeNdlB; PricebookEntry pbeBvr; PricebookEntry pbeNull;
        // QLIs
        QuoteLineItem qliNdl1; // Discount = null
        QuoteLineItem qliNdl2; // Discount = 5  (untuk test onlyEmpty)
        QuoteLineItem qliBvr1; // Discount = null
        QuoteLineItem qliNull; // family null, Discount = null
    }

    private SetupBundle setupData() {
        SetupBundle sb = new SetupBundle();
        sb.iso  = corpIso();
        sb.pbId = stdPbId();
        sb.acc  = mkAccount('ACC – QFD');
        sb.opp  = mkOpp(sb.acc.Id, sb.pbId, 'OPP – QFD', sb.iso);
        sb.q    = mkQuote(sb.opp.Id, sb.pbId, sb.iso);

        // Products (family NDL, BVR, dan null)
        sb.pNdlA = mkProduct('Indomie Goreng', 'NDL');
        sb.pNdlB = mkProduct('Indomie Kuah',   'NDL');
        sb.pBvr  = mkProduct('Ichi Ocha',      'BVR');
        sb.pNull = mkProduct('Tanpa Family',   null);

        // PBEs (currency seragam)
        sb.pbeNdlA = mkPbe(sb.pbId, sb.pNdlA.Id, 5000, sb.iso);
        sb.pbeNdlB = mkPbe(sb.pbId, sb.pNdlB.Id, 6000, sb.iso);
        sb.pbeBvr  = mkPbe(sb.pbId, sb.pBvr.Id,  7000, sb.iso);
        sb.pbeNull = mkPbe(sb.pbId, sb.pNull.Id, 4000, sb.iso);

        // QLIs:
        sb.qliNdl1 = mkQli(sb.q.Id, sb.pbeNdlA.Id, 1, 5000, null); // Discount null
        sb.qliNdl2 = mkQli(sb.q.Id, sb.pbeNdlB.Id, 2, 6000, 5);    // Discount 5
        sb.qliBvr1 = mkQli(sb.q.Id, sb.pbeBvr.Id,  1, 7000, null); // Discount null
        sb.qliNull = mkQli(sb.q.Id, sb.pbeNull.Id, 3, 4000, null); // Discount null (family null)
        return sb;
    }

    // ===== TEST: getFamilies aggregates (COUNT/MIN/MAX) =====
    @IsTest
    static void test_getFamilies() {
        SetupBundle sb = new QuoteFamilyDiscountControllerTest().setupData();

        Test.startTest();
        List<QuoteFamilyDiscountController.FamilyRow> rows =
            QuoteFamilyDiscountController.getFamilies(sb.q.Id);
        Test.stopTest();

        // Harus ada 3 grup: NDL, BVR, (null)
        Map<String, QuoteFamilyDiscountController.FamilyRow> byFam = new Map<String, QuoteFamilyDiscountController.FamilyRow>();
        Integer nullIdx = -1;
        for (Integer i = 0; i < rows.size(); i++) {
            QuoteFamilyDiscountController.FamilyRow r = rows[i];
            if (r.family == null) {
                nullIdx = i;
            } else {
                byFam.put(r.family, r);
            }
        }
        System.assertEquals(true, byFam.containsKey('NDL'), 'Harus ada grup NDL');
        System.assertEquals(true, byFam.containsKey('BVR'), 'Harus ada grup BVR');
        System.assertNotEquals(-1, nullIdx, 'Harus ada grup null family');

        // NDL: 2 baris, min/max discount = 5 (karena satunya null, MIN/MAX abaikan null)
        System.assertEquals(2, byFam.get('NDL').lineCount);
        System.assertEquals(5, byFam.get('NDL').minDiscount);
        System.assertEquals(5, byFam.get('NDL').maxDiscount);

        // BVR: 1 baris, semua discount null → agregasi MIN/MAX kemungkinan null
        System.assertEquals(1, byFam.get('BVR').lineCount);
        // Nilai MIN/MAX bisa null saat semua baris null
        System.assertEquals(null, byFam.get('BVR').minDiscount);
        System.assertEquals(null, byFam.get('BVR').maxDiscount);

        // null family: 1 baris
        System.assertEquals(1, rows[nullIdx].lineCount);
    }

    // ===== TEST: applyDiscounts – families + includeNull, onlyEmpty = true =====
    @IsTest
    static void test_applyDiscounts_familiesPlusNull_onlyEmptyTrue() {
        SetupBundle sb = new QuoteFamilyDiscountControllerTest().setupData();

        Map<String, Decimal> familyToPct = new Map<String, Decimal>{
            'NDL'      => 10,  // NDL: qliNdl1(null) → update, qliNdl2(5) → SKIP (onlyEmpty)
            'BVR'      => 7,   // BVR: qliBvr1(null) → update
            '__NULL__' => 3    // null family: qliNull(null) → update
        };

        Test.startTest();
        Integer updated = QuoteFamilyDiscountController.applyDiscounts(sb.q.Id, familyToPct, true);
        Test.stopTest();

        System.assertEquals(3, updated, 'Harus meng-update 3 baris (NDL null, BVR null, null family)');

        // Verifikasi DB
        Map<Id, QuoteLineItem> after = new Map<Id, QuoteLineItem>([
            SELECT Id, Discount, PricebookEntry.Product2.Family
            FROM QuoteLineItem
            WHERE Id IN :new List<Id>{ sb.qliNdl1.Id, sb.qliNdl2.Id, sb.qliBvr1.Id, sb.qliNull.Id }
        ]);
        System.assertEquals(10, after.get(sb.qliNdl1.Id).Discount, 'NDL null harus jadi 10');
        System.assertEquals(5,  after.get(sb.qliNdl2.Id).Discount, 'NDL non-empty (5) harus SKIP');
        System.assertEquals(7,  after.get(sb.qliBvr1.Id).Discount, 'BVR null harus jadi 7');
        System.assertEquals(3,  after.get(sb.qliNull.Id).Discount, 'Null family harus jadi 3');
    }

    // ===== TEST: applyDiscounts – families only, onlyEmpty = false =====
    @IsTest
    static void test_applyDiscounts_familiesOnly_updateAll() {
        SetupBundle sb = new QuoteFamilyDiscountControllerTest().setupData();

        // Set awal: NDL (null & 5), BVR (null)
        Map<String, Decimal> mapNdlOnly = new Map<String, Decimal>{ 'NDL' => 15 };

        Test.startTest();
        Integer updated = QuoteFamilyDiscountController.applyDiscounts(sb.q.Id, mapNdlOnly, false);
        Test.stopTest();

        System.assertEquals(2, updated, 'Kedua baris NDL harus ter-update (onlyEmpty=false)');

        // Verifikasi DB
        Map<Id, QuoteLineItem> after = new Map<Id, QuoteLineItem>([
            SELECT Id, Discount, PricebookEntry.Product2.Family
            FROM QuoteLineItem
            WHERE Id IN :new List<Id>{ sb.qliNdl1.Id, sb.qliNdl2.Id }
        ]);
        System.assertEquals(15, after.get(sb.qliNdl1.Id).Discount);
        System.assertEquals(15, after.get(sb.qliNdl2.Id).Discount);
    }

    // ===== TEST: applyDiscounts – null only, onlyEmpty = false =====
    @IsTest
    static void test_applyDiscounts_nullOnly_updateAll() {
        SetupBundle sb = new QuoteFamilyDiscountControllerTest().setupData();

        Map<String, Decimal> nullOnly = new Map<String, Decimal>{ '__NULL__' => 8 };

        Test.startTest();
        Integer updated = QuoteFamilyDiscountController.applyDiscounts(sb.q.Id, nullOnly, false);
        Test.stopTest();

        System.assertEquals(1, updated, 'Hanya satu baris dengan family null yang di-update');

        QuoteLineItem after = [
            SELECT Id, Discount, PricebookEntry.Product2.Family
            FROM QuoteLineItem WHERE Id = :sb.qliNull.Id
        ];
        System.assertEquals(8, after.Discount);
    }

    // ===== TEST: applyDiscounts – map kosong → 0 =====
    @IsTest
    static void test_applyDiscounts_emptyMap_returnsZero() {
        SetupBundle sb = new QuoteFamilyDiscountControllerTest().setupData();
        Integer result = QuoteFamilyDiscountController.applyDiscounts(sb.q.Id, new Map<String, Decimal>(), true);
        System.assertEquals(0, result, 'Map kosong harus mengembalikan 0 dan tidak update apa pun');
    }
}

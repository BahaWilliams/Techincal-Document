@IsTest
private class OLIConnectivityControllerTest {

    // ===== Helpers umum =====
    private static Id stdPbId() { return Test.getStandardPricebookId(); }

    // Ambil corporate currency ISO (fallback 'USD' kalau CurrencyType tidak tersedia)
    private static String getCorpIso() {
        try {
            CurrencyType corp = [SELECT IsoCode FROM CurrencyType WHERE IsCorporate = true LIMIT 1];
            return corp.IsoCode;
        } catch (Exception e) {
            return 'USD';
        }
    }

    private static Account mkAccount(String name) {
        Account a = new Account(Name = name);
        insert a; return a;
    }

    private static Opportunity mkOpp(Id accId, Id pbId, String name, String corpIso) {
        Opportunity o = new Opportunity(
            Name         = name,
            StageName    = 'Prospecting',
            CloseDate    = Date.today().addDays(14),
            AccountId    = accId,
            Pricebook2Id = pbId
        );
        // Set currency secara dinamis (aman untuk org multi-currency)
        o.put('CurrencyIsoCode', corpIso);
        insert o;
        return o;
    }

    private static Product2 mkProduct(String name, String family) {
        Product2 p = new Product2(Name = name, Family = family, IsActive = true);
        insert p; return p;
    }

    private static PricebookEntry mkPbe(Id pbId, Id productId, Decimal listPrice, String corpIso) {
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id   = productId,
            UnitPrice    = listPrice,
            IsActive     = true
        );
        // Set currency PBE agar match dengan Opportunity
        pbe.put('CurrencyIsoCode', corpIso);
        insert pbe; 
        return pbe;
    }

    private static OpportunityLineItem mkOli(Id oppId, Id pbeId, Decimal qty, Decimal unitPriceOverride) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = oppId,
            PricebookEntryId = pbeId,
            Quantity         = qty,
            UnitPrice        = unitPriceOverride
        );
        insert oli; 
        return oli;
    }

    // ===== SETUP DATA UTAMA =====
    private class SetupBundle {
        String corpIso;
        Id pbId;
        Account acc;
        Opportunity opp;
        Product2 p1; Product2 p2;
        PricebookEntry pbe1; PricebookEntry pbe2;
        OpportunityLineItem oli1; OpportunityLineItem oli2;
    }

    private SetupBundle setupMainData() {
        SetupBundle sb = new SetupBundle();
        sb.corpIso = getCorpIso();
        sb.pbId    = stdPbId();
        sb.acc     = mkAccount('ACC – OLIConnectivity');
        sb.opp     = mkOpp(sb.acc.Id, sb.pbId, 'OPP – OLIConnectivity', sb.corpIso);

        // Produk & PBE (pastikan CurrencyIsoCode PBE = corpIso)
        sb.p1   = mkProduct('Indomie', 'NDL');
        sb.p2   = mkProduct('Ichi Ocha', 'BVR');
        sb.pbe1 = mkPbe(sb.pbId, sb.p1.Id, 5000, sb.corpIso);
        sb.pbe2 = mkPbe(sb.pbId, sb.p2.Id, 8000, sb.corpIso);

        // OLI dengan UnitPrice override ≠ listPrice (sebelum update akan terlihat bedanya)
        sb.oli1 = mkOli(sb.opp.Id, sb.pbe1.Id, 2, 6000);
        sb.oli2 = mkOli(sb.opp.Id, sb.pbe2.Id, 3, 9000);
        return sb;
    }

    // ===== TEST: pingOli happy path & param null =====
    @IsTest
    static void test_pingOli() {
        SetupBundle sb = new OLIConnectivityControllerTest().setupMainData();

        Test.startTest();
        OLIConnectivityController.PingResult r = OLIConnectivityController.pingOli(sb.opp.Id);
        Test.stopTest();

        System.assertEquals(true, r.ok, 'ok harus true');
        System.assertEquals(2, r.oliCount, 'Harus ada 2 OLI');
        System.assertEquals(sb.pbId, r.pricebookId, 'PricebookId harus sama dengan di Opportunity');
        System.assertEquals('OK', r.message);

        // Param null → exception
        try {
            OLIConnectivityController.pingOli(null);
            System.assert(false, 'Harus melempar error jika opportunityId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('opportunityId is required.'));
        }
    }

    // ===== TEST: listLines mapping & totals =====
    @IsTest
    static void test_listLines_mappingAndTotals() {
        SetupBundle sb = new OLIConnectivityControllerTest().setupMainData();

        // Expected totals (pakai UnitPrice override sebelum updateQuantities)
        Decimal expectedTotal = (2 * 6000) + (3 * 9000); // 42000
        Decimal expectedQty   = 2 + 3;

        OLIConnectivityController.LinesResult res = OLIConnectivityController.listLines(sb.opp.Id);

        System.assertEquals(2, res.rows.size(), 'Harus ada 2 baris');
        System.assertEquals(expectedQty, res.totalQty, 'totalQty harus sesuai');
        System.assertEquals(expectedTotal, res.totalAmount, 'totalAmount harus sesuai');

        // Cek baris pertama (urut by Product Name → Indomie dulu)
        OLIConnectivityController.OLIViewRow row0 = res.rows[0];
        System.assertEquals(sb.oli1.Id, row0.id);
        System.assertEquals('Indomie', row0.productName);
        System.assertEquals('NDL', row0.productFamily);
        System.assertEquals(6000, row0.unitPrice);
        System.assertEquals(2, row0.quantity);
        System.assertEquals(5000, row0.listPrice);
        System.assertEquals(12000, row0.lineTotal);

        OLIConnectivityController.OLIViewRow row1 = res.rows[1];
        System.assertEquals('Ichi Ocha', row1.productName);
        System.assertEquals('BVR', row1.productFamily);
        System.assertEquals(9000, row1.unitPrice);
        System.assertEquals(3, row1.quantity);
        System.assertEquals(8000, row1.listPrice);
        System.assertEquals(27000, row1.lineTotal);

        // Param null → exception
        try {
            OLIConnectivityController.listLines(null);
            System.assert(false, 'Harus melempar error jika opportunityId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('opportunityId is required.'));
        }
    }

    // ===== TEST: updateQuantities jalur lengkap =====
    @IsTest
    static void test_updateQuantities_updatesAndLocksUnitPrice() {
        SetupBundle sb = new OLIConnectivityControllerTest().setupMainData();

        // Tambah Opportunity lain (currency sama) untuk membuktikan OLI lain diabaikan
        Account acc2   = mkAccount('ACC – Other');
        Opportunity opp2 = mkOpp(acc2.Id, sb.pbId, 'OPP – Other', sb.corpIso);
        Product2 p3    = mkProduct('Club', 'BVR');
        PricebookEntry pbe3 = mkPbe(sb.pbId, p3.Id, 4000, sb.corpIso);
        OpportunityLineItem otherOppOli = mkOli(opp2.Id, pbe3.Id, 5, 4500);

        // Map update:
        // - oli1 → 5
        // - oli2 → -1 (dipaksa 0)
        // - otherOppOli (bukan opp target) → diabaikan
        Map<Id, Decimal> qtyMap = new Map<Id, Decimal>{
            sb.oli1.Id => 5,
            sb.oli2.Id => -1,
            otherOppOli.Id => 10
        };

        Test.startTest();
        OLIConnectivityController.LinesResult resAfter = OLIConnectivityController.updateQuantities(sb.opp.Id, qtyMap);
        Test.stopTest();

        // Reload
        OpportunityLineItem oli1After = [
            SELECT Id, Quantity, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem WHERE Id = :sb.oli1.Id
        ];
        OpportunityLineItem oli2After = [
            SELECT Id, Quantity, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem WHERE Id = :sb.oli2.Id
        ];
        OpportunityLineItem otherAfter = [
            SELECT Id, Quantity FROM OpportunityLineItem WHERE Id = :otherOppOli.Id
        ];

        System.assertEquals(5, oli1After.Quantity);
        System.assertEquals(oli1After.PricebookEntry.UnitPrice, oli1After.UnitPrice,
            'UnitPrice harus dikunci ke ListPrice');

        System.assertEquals(0, oli2After.Quantity);
        System.assertEquals(oli2After.PricebookEntry.UnitPrice, oli2After.UnitPrice,
            'UnitPrice harus dikunci ke ListPrice');

        System.assertEquals(5, otherAfter.Quantity, 'OLI di opportunity lain tidak boleh berubah');

        // Setelah dikunci ke list price, total = (5 * 5000) + (0 * 8000) = 25000
        System.assertEquals(5, resAfter.totalQty);
        System.assertEquals(25000, resAfter.totalAmount);

        // Cabang qtyById null → hanya return listLines()
        OLIConnectivityController.LinesResult resNullMap = OLIConnectivityController.updateQuantities(sb.opp.Id, null);
        System.assertEquals(resAfter.totalQty, resNullMap.totalQty);
        System.assertEquals(resAfter.totalAmount, resNullMap.totalAmount);
    }
}

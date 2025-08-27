@IsTest
private class OLILineEditorControllerTest {

    // ---------- Helpers umum ----------
    private static Id stdPbId() { return Test.getStandardPricebookId(); }

    // Ambil corporate ISO currency agar Opp & PBE seragam (hindari FIELD_INTEGRITY_EXCEPTION)
    private static String corpIso() {
        try {
            CurrencyType ct = [SELECT IsoCode FROM CurrencyType WHERE IsCorporate = true LIMIT 1];
            return ct.IsoCode;
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

    private static OpportunityLineItem mkOli(Id oppId, Id pbeId, Decimal qty, Decimal unitPrice) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = oppId,
            PricebookEntryId = pbeId,
            Quantity         = qty,
            UnitPrice        = unitPrice
        );
        insert oli; return oli;
    }

    // Bundle setup agar rapi
    private class SetupBundle {
        String iso;
        Id     pbId;
        Account acc;
        Opportunity opp;
        Product2 pNoodleA; Product2 pNoodleB; Product2 pDrink;
        PricebookEntry pbeNoodleA; PricebookEntry pbeNoodleB; PricebookEntry pbeDrink;
        OpportunityLineItem oliA; // OLI awal yang akan di-swap
    }

    private SetupBundle setupData() {
        SetupBundle sb = new SetupBundle();
        sb.iso  = corpIso();
        sb.pbId = stdPbId();
        sb.acc  = mkAccount('ACC – OLI Line Editor');
        sb.opp  = mkOpp(sb.acc.Id, sb.pbId, 'OPP – OLI Line Editor', sb.iso);

        // Dua produk dalam 1 family yang sama (Noodle) + 1 produk family lain (Drink)
        sb.pNoodleA = mkProduct('Indomie Goreng', 'NDL');
        sb.pNoodleB = mkProduct('Indomie Kuah',   'NDL');
        sb.pDrink   = mkProduct('Ichi Ocha',      'BVR');

        // PBE untuk semuanya dengan currency yang sama
        sb.pbeNoodleA = mkPbe(sb.pbId, sb.pNoodleA.Id, 7000, sb.iso);
        sb.pbeNoodleB = mkPbe(sb.pbId, sb.pNoodleB.Id, 7500, sb.iso);
        sb.pbeDrink   = mkPbe(sb.pbId, sb.pDrink.Id,   8000, sb.iso);

        // Buat OLI awal pakai Noodle A, override UnitPrice supaya terlihat beda dengan list price saat swap
        sb.oliA = mkOli(sb.opp.Id, sb.pbeNoodleA.Id, 3, 7200); // override 7200, qty 3

        return sb;
    }

    // ---------- TESTS ----------

    @IsTest
    static void test_listLines_happy_and_nullParam() {
        SetupBundle sb = new OLILineEditorControllerTest().setupData();

        // Tambah satu OLI lagi agar tabulasi & sorting kelihatan
        OpportunityLineItem oliDrink = mkOli(sb.opp.Id, sb.pbeDrink.Id, 2, 8200); // override

        // expected totals = (3 * 7200) + (2 * 8200) = 21600 + 16400 = 38000
        Decimal expectedTotal = 38000, expectedQty = 5;

        OLILineEditorController.LinesResult res = OLILineEditorController.listLines(sb.opp.Id);
        System.assertEquals(2, res.rows.size(), 'Harus ada 2 baris OLI');
        System.assertEquals(expectedQty, res.totalQty);
        System.assertEquals(expectedTotal, res.totalAmount);

        // Error jika null
        try {
            OLILineEditorController.listLines(null);
            System.assert(false, 'Seharusnya melempar error jika opportunityId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('opportunityId is required.'));
        }
    }

    @IsTest
    static void test_initSwap_happy_and_nullParam() {
        SetupBundle sb = new OLILineEditorControllerTest().setupData();

        OLILineEditorController.SwapInit init = OLILineEditorController.initSwap(sb.oliA.Id);

        System.assertEquals(sb.oliA.Id, init.oliId, 'oliId harus sama');
        System.assertEquals('Indomie Goreng', init.currentProductName);
        System.assertEquals('NDL', init.family);
        System.assertEquals(3, init.quantity);
        System.assertEquals(7200, init.unitPrice);

        // Pilihan harus hanya dari family "NDL" dan pricebook yang sama → Noodle A & Noodle B
        // (sorted by Product2.Name, sehingga Kuah/Goreng tergantung alfabet)
        System.assert(init.choices.size() >= 2, 'Harus ada setidaknya 2 pilihan dari family yang sama');
        // Pastikan priceById mengandung kedua PBE NDL, dan tidak mengandung PBE drink
        System.assertEquals(true, init.priceById.containsKey((String)sb.pbeNoodleA.Id));
        System.assertEquals(true, init.priceById.containsKey((String)sb.pbeNoodleB.Id));
        System.assertEquals(false, init.priceById.containsKey((String)sb.pbeDrink.Id));

        // Error jika null
        try {
            OLILineEditorController.initSwap(null);
            System.assert(false, 'Seharusnya melempar error jika oliId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('oliId is required.'));
        }
    }

    @IsTest
    static void test_swapProduct_happy_and_paramNull() {
        SetupBundle sb = new OLILineEditorControllerTest().setupData();

        // Swap dari Noodle A → Noodle B
        Test.startTest();
        OLILineEditorController.LinesResult after = OLILineEditorController.swapProduct(sb.oliA.Id, sb.pbeNoodleB.Id);
        Test.stopTest();

        // Setelah swap: OLI lama terhapus, OLI baru terinsert:
        // qty tetap 3, UnitPrice harus = list price baru (7500), total = 22500
        System.assertEquals(1, after.rows.size(), 'Setelah swap (tanpa OLI lain), harus ada 1 baris');
        OLILineEditorController.Row r = after.rows[0];
        System.assertEquals(3, r.quantity);
        System.assertEquals(7500, r.unitPrice, 'UnitPrice harus mengikuti list price dari PBE baru');
        System.assertEquals(22500, r.lineTotal);

        // Pastikan OLI lama sudah terhapus
        Boolean oldExists = [SELECT COUNT() FROM OpportunityLineItem WHERE Id = :sb.oliA.Id] > 0;
        System.assertEquals(false, oldExists, 'OLI lama harus terhapus setelah swap');

        // Error param null
        try {
            OLILineEditorController.swapProduct(null, sb.pbeNoodleB.Id);
            System.assert(false, 'Seharusnya error saat oliId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
        try {
            // ambil OLI baru dulu untuk test param kedua null
            OpportunityLineItem newOli = [
                SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :sb.opp.Id LIMIT 1
            ];
            OLILineEditorController.swapProduct(newOli.Id, null);
            System.assert(false, 'Seharusnya error saat newPricebookEntryId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
    }

    @IsTest
    static void test_deleteOli_happy_and_nullParam() {
        SetupBundle sb = new OLILineEditorControllerTest().setupData();

        // Buat satu OLI yang khusus untuk dihapus
        OpportunityLineItem oliDel = mkOli(sb.opp.Id, sb.pbeDrink.Id, 1, 8000);

        Test.startTest();
        OLILineEditorController.deleteOli(oliDel.Id);
        Test.stopTest();

        Integer cnt = [SELECT COUNT() FROM OpportunityLineItem WHERE Id = :oliDel.Id];
        System.assertEquals(0, cnt, 'OLI harus terhapus');

        // Error jika null
        try {
            OLILineEditorController.deleteOli(null);
            System.assert(false, 'Seharusnya error saat oliId null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('oliId is required.'));
        }
    }
}

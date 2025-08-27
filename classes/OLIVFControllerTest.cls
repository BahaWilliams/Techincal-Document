@IsTest
private class OLIVFControllerTest {

    // ===== Helpers umum =====
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
            Name         = name,
            StageName    = 'Prospecting',
            CloseDate    = Date.today().addDays(10),
            AccountId    = accId,
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

    // ====== SETUP bundle ======
    private class SetupBundle {
        String iso;
        Id pbId;
        Account acc;
        Opportunity opp;
        Product2 p1; Product2 p2;
        PricebookEntry pbe1; PricebookEntry pbe2;
        OpportunityLineItem oli1; OpportunityLineItem oli2;
    }
    private SetupBundle setupData() {
        SetupBundle sb = new SetupBundle();
        sb.iso  = corpIso();
        sb.pbId = stdPbId();
        sb.acc  = mkAccount('ACC – OLIVF');
        sb.opp  = mkOpp(sb.acc.Id, sb.pbId, 'OPP – OLIVF', sb.iso);

        // Dua produk berbeda family agar FamilyBox terisi & bisa disort
        sb.p1   = mkProduct('Indomie',   'NDL');
        sb.p2   = mkProduct('Ichi Ocha', 'BVR');
        sb.pbe1 = mkPbe(sb.pbId, sb.p1.Id, 5000, sb.iso);
        sb.pbe2 = mkPbe(sb.pbId, sb.p2.Id, 8000, sb.iso);

        // OLI dengan override UnitPrice (sebelum saveEditor akan berbeda dari list price)
        sb.oli1 = mkOli(sb.opp.Id, sb.pbe1.Id, 2, 6000); // linetotal 12.000
        sb.oli2 = mkOli(sb.opp.Id, sb.pbe2.Id, 3, 9000); // linetotal 27.000
        return sb;
    }

    // ====== TEST: Konstruktor pada konteks Opportunity + editor flow ======
    @IsTest
    static void test_opportunityContext_andEditorFlow() {
        SetupBundle sb = new OLIVFControllerTest().setupData();

        // Siapkan StandardController (Opportunity)
        ApexPages.currentPage().getParameters().put('id', sb.opp.Id);
        ApexPages.StandardController std = new ApexPages.StandardController(sb.opp);

        // Konstruktor otomatis memanggil refresh()
        OLIVFController ctrl = new OLIVFController(std);

        // Asersi dasar rows & totals
        System.assertEquals(sb.opp.Id, ctrl.oppId, 'oppId harus terset pada konteks Opportunity');
        System.assertNotEquals(null, ctrl.rows, 'rows harus terisi');
        System.assertEquals(2, ctrl.rows.size(), 'Harus ada 2 OLI');
        System.assertEquals(5, ctrl.totalQty, '2 + 3 = 5');
        System.assertEquals(42000, ctrl.totalAmount, '12000 + 27000 = 42000');
        System.assert(ctrl.totalAmountFmt != null && ctrl.totalAmountFmt.startsWith('Rp '), 'Format Rupiah harus diawali "Rp "');

        // Family summary terisi dan tersort (BVR, NDL)
        System.assertNotEquals(null, ctrl.familySummary);
        System.assertEquals(2, ctrl.familySummary.size());
        // Setelah sort alfabetis: "BVR" dulu baru "NDL"
        System.assertEquals('BVR', ctrl.familySummary[0].family);
        System.assertEquals('NDL', ctrl.familySummary[1].family);

        // ==== Editor flow ====
        // Pilih oli1 untuk diedit
        ctrl.editRowId = sb.oli1.Id;
        ctrl.openEditor();
        System.assertEquals(true, ctrl.showEditor, 'openEditor harus set showEditor=true');
        System.assertEquals(2, ctrl.editQty, 'editQty harus terisi quantity baris');

        // Ubah qty dan simpan → UnitPrice harus DIKUNCI ke ListPrice
        ctrl.editQty = 4; // dari 2 → 4
        ctrl.saveEditor();

        // Editor direset
        System.assertEquals(false, ctrl.showEditor);
        System.assertEquals(null, ctrl.editRowId);
        System.assertEquals(null, ctrl.editQty);

        // Verifikasi di DB: qty berubah & unit price = list price
        OpportunityLineItem oli1After = [
            SELECT Id, Quantity, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem WHERE Id = :sb.oli1.Id
        ];
        System.assertEquals(4, oli1After.Quantity, 'Quantity harus menjadi 4');
        System.assertEquals(oli1After.PricebookEntry.UnitPrice, oli1After.UnitPrice,
            'UnitPrice harus terkunci ke ListPrice setelah saveEditor');

        // Totals setelah perubahan (OLI1: 4*5000 = 20000; OLI2: 3*8000 = 24000 → total 44000; qty 7)
        System.assertEquals(7, ctrl.totalQty);
        System.assertEquals(44000, ctrl.totalAmount);

        // Coverage untuk cancel & refreshAction
        ctrl.cancelEditor();
        ctrl.refreshAction();
    }

    // ====== TEST: Konstruktor pada konteks Contract (URL oppId) ======
    @IsTest
    static void test_contractContext_withUrlOppId() {
        SetupBundle sb = new OLIVFControllerTest().setupData();

        // Buat Contract minimal (Account wajib + StartDate + Status)
        Contract c = new Contract(AccountId = sb.acc.Id, StartDate = Date.today(), Status = 'Draft');
        insert c;

        // Set parameter halaman: id = contractId, oppId = sb.opp.Id (harus "006..." supaya lolos startsWith)
        ApexPages.currentPage().getParameters().put('id', c.Id);
        ApexPages.currentPage().getParameters().put('oppId', sb.opp.Id);

        // StandardController untuk Contract
        ApexPages.StandardController std = new ApexPages.StandardController(c);
        OLIVFController ctrl = new OLIVFController(std);

        // oppId harus terbaca dari URL
        System.assertEquals(sb.opp.Id, ctrl.oppId, 'oppId harus diambil dari URL pada konteks Contract');

        // rows & totals tetap terhitung
        System.assertEquals(2, ctrl.rows.size());
        System.assertEquals(5, ctrl.totalQty);
        System.assertEquals(42000, ctrl.totalAmount);
        System.assert(ctrl.totalAmountFmt.startsWith('Rp '));
    }
}

@IsTest
private class UpdateSalesPriceTriggerHandlerTest {

    // ===== Helpers umum =====
    private static Id stdPbId() { return Test.getStandardPricebookId(); }

    // Samakan currency Opp & PBE agar aman di org multi-currency
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
            CloseDate = Date.today().addDays(10),
            AccountId = accId,
            Pricebook2Id = pbId
        );
        o.put('CurrencyIsoCode', iso);
        insert o; return o;
    }

    private static Product2 mkProduct(String name) {
        Product2 p = new Product2(Name = name, IsActive = true);
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

    private static OpportunityLineItem mkOli(Id oppId, Id pbeId, Decimal qty, Decimal unitPriceNullable) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = oppId,
            PricebookEntryId = pbeId,
            Quantity         = qty
        );
        if (unitPriceNullable != null) {
            oli.UnitPrice = unitPriceNullable;
        }
        insert oli; // trigger before insert akan mengisi UnitPrice bila null/0
        return oli;
    }

    // ===== TESTS =====

    // (1) beforeInsert: UnitPrice null → diisi dari ListPrice
    @IsTest
    static void test_beforeInsert_setsUnitPriceFromPbe_whenNull() {
        String iso = corpIso();
        Id pbId    = stdPbId();
        Account acc = mkAccount('ACC – Insert Null');
        Opportunity opp = mkOpp(acc.Id, pbId, 'OPP – Insert Null', iso);

        Product2 p  = mkProduct('Produk A');
        PricebookEntry pbe = mkPbe(pbId, p.Id, 5000, iso);

        // Insert OLI tanpa UnitPrice → handler harus mengisi
        OpportunityLineItem oli = mkOli(opp.Id, pbe.Id, 2, null);

        OpportunityLineItem after = [
            SELECT Id, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem WHERE Id = :oli.Id
        ];
        System.assertEquals(after.PricebookEntry.UnitPrice, after.UnitPrice,
            'UnitPrice harus otomatis diisi dari PBE pada beforeInsert');
    }

    // (2) beforeInsert: UnitPrice sudah terisi → tidak dioverride
    @IsTest
    static void test_beforeInsert_keepsProvidedUnitPrice() {
        String iso = corpIso();
        Id pbId    = stdPbId();
        Account acc = mkAccount('ACC – Insert Given');
        Opportunity opp = mkOpp(acc.Id, pbId, 'OPP – Insert Given', iso);

        Product2 p  = mkProduct('Produk B');
        PricebookEntry pbe = mkPbe(pbId, p.Id, 8000, iso);

        // Insert OLI dengan UnitPrice berbeda dari ListPrice → tidak boleh dioverride
        OpportunityLineItem oli = mkOli(opp.Id, pbe.Id, 1, 9000);

        OpportunityLineItem after = [
            SELECT Id, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem WHERE Id = :oli.Id
        ];
        System.assertEquals(9000, after.UnitPrice,
            'UnitPrice yang sudah diisi user tidak boleh dioverride pada beforeInsert');
    }

    // (3) beforeUpdate: ganti PBE + set UnitPrice = 0 → diisi dari ListPrice PBE baru
    @IsTest
    static void test_beforeUpdate_setsFromNewPbe_whenChangedAndZero() {
        String iso = corpIso();
        Id pbId    = stdPbId();
        Account acc = mkAccount('ACC – Update PBE Change');
        Opportunity opp = mkOpp(acc.Id, pbId, 'OPP – Update PBE Change', iso);

        Product2 p1  = mkProduct('Produk C1');
        Product2 p2  = mkProduct('Produk C2');
        PricebookEntry pbe1 = mkPbe(pbId, p1.Id, 7000, iso);
        PricebookEntry pbe2 = mkPbe(pbId, p2.Id, 9000, iso);

        // Awal: UnitPrice terisi (entah dari user atau from PBE)
        OpportunityLineItem oli = mkOli(opp.Id, pbe1.Id, 3, 7500);

        // Update: ganti PBE ke pbe2 & kosongkan harga (0) → handler harus isi dari pbe2.UnitPrice
        oli.PricebookEntryId = pbe2.Id;
        oli.UnitPrice = 0;
        update oli;

        OpportunityLineItem after = [
            SELECT Id, UnitPrice, PricebookEntry.UnitPrice, PricebookEntryId
            FROM OpportunityLineItem WHERE Id = :oli.Id
        ];
        System.assertEquals(pbe2.Id, after.PricebookEntryId, 'Harus pindah ke PBE baru');
        System.assertEquals(after.PricebookEntry.UnitPrice, after.UnitPrice,
            'UnitPrice harus diisi dari ListPrice PBE baru pada beforeUpdate');
    }

    // (4) beforeUpdate: PBE sama, sebelumnya non-zero → sekarang 0 → TIDAK diisi (sesuai logika handler)
    @IsTest
    static void test_beforeUpdate_samePbe_prevNonZero_nowZero_notFilled() {
        String iso = corpIso();
        Id pbId    = stdPbId();
        Account acc = mkAccount('ACC – Update Same PBE');
        Opportunity opp = mkOpp(acc.Id, pbId, 'OPP – Update Same PBE', iso);

        Product2 p  = mkProduct('Produk D');
        PricebookEntry pbe = mkPbe(pbId, p.Id, 6000, iso);

        // Awal: UnitPrice non-zero
        OpportunityLineItem oli = mkOli(opp.Id, pbe.Id, 2, 6100);

        // Update: tetap PBE yang sama, set UnitPrice = 0
        // Menurut logika handler:
        //  - priceMissing = true (0)
        //  - isUpdate = true, old.UnitPrice == new.UnitPrice? (6100 == 0) → false
        //  - PBE tidak berubah → tidak menambahkan pbeId → tidak akan diisi ulang
        oli.UnitPrice = 0;
        update oli;

        OpportunityLineItem after = [
            SELECT Id, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem WHERE Id = :oli.Id
        ];
        System.assertEquals(0, after.UnitPrice,
            'Dengan PBE sama & old.UnitPrice != new.UnitPrice (0), handler tidak mengisi ulang harga');
    }
}

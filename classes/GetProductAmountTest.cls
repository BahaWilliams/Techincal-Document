@IsTest
private class GetProductAmountTest {

    // ===== Helpers =====
    private static Id stdPbId() {
        return Test.getStandardPricebookId();
    }
    private static Product2 addProduct(String name) {
        Product2 p = new Product2(Name = name, IsActive = true);
        insert p; return p;
    }
    private static PricebookEntry addPbe(Id pbId, Id productId, Decimal price, Boolean active) {
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id   = productId,
            UnitPrice    = price,
            IsActive     = active
        );
        insert pbe; return pbe;
    }

    // ===== Positive: split/trim nama + filter isActive + order by Name =====
    @IsTest
    static void testRun_HappyPath_SplitTrimAndOrder() {
        Id pbId = stdPbId();

        // Siapkan produk & PBE (aktif)
        Product2 indomie = addProduct('Indomie');
        Product2 popmie  = addProduct('Pop Mie');
        PricebookEntry pbeIndo = addPbe(pbId, indomie.Id, 7000, true);
        PricebookEntry pbePop  = addPbe(pbId, popmie.Id,  5000, true);

        // Juga siapkan satu PBE non-aktif (harus ter-filter)
        Product2 chitato = addProduct('Chitato');
        PricebookEntry pbeChit = addPbe(pbId, chitato.Id, 12500, false);

        // Build request: ada spasi & multiple names dipisah ';' (+ ada item kosong)
        GetProductAmount.Req req = new GetProductAmount.Req();
        req.pricebookId   = pbId;
        req.productNames  = new List<String>{
            '  Indomie ; Pop Mie  ',
            '   ', null
        };

        Test.startTest();
        List<List<PricebookEntry>> result = GetProductAmount.run(new List<GetProductAmount.Req>{ req });
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Invocable harus mengembalikan list tunggal');
        List<PricebookEntry> rows = result[0];
        System.assertEquals(2, rows.size(), 'Hanya 2 PBE aktif yang cocok (Indomie & Pop Mie)');

        // Urutan harus berdasarkan PricebookEntry.Name (alfabetis)
        // "Indomie" (I) sebelum "Pop Mie" (P)
        System.assertEquals('Indomie', rows[0].Name, 'Baris pertama harus Indomie (sorting by Name)');
        System.assertEquals(7000, rows[0].UnitPrice);
        System.assertEquals('Pop Mie', rows[1].Name);
        System.assertEquals(5000, rows[1].UnitPrice);
    }

    // ===== Negative: berbagai validasi input =====
    @IsTest
    static void testRun_Errors() {
        // (a) reqs null
        try {
            GetProductAmount.run(null);
            System.assert(false, 'Seharusnya melempar No request.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No request.'), 'Pesan harus "No request."');
        }

        // (b) productNames kosong
        GetProductAmount.Req rEmptyNames = new GetProductAmount.Req();
        rEmptyNames.pricebookId  = stdPbId();
        rEmptyNames.productNames = new List<String>();
        try {
            GetProductAmount.run(new List<GetProductAmount.Req>{ rEmptyNames });
            System.assert(false, 'Seharusnya melempar "productNames is required."');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('productNames is required.'), 'Pesan harus "productNames is required."');
        }

        // (c) pricebookId null
        GetProductAmount.Req rNoPb = new GetProductAmount.Req();
        rNoPb.productNames = new List<String>{ 'Indomie' };
        rNoPb.pricebookId  = null;
        try {
            GetProductAmount.run(new List<GetProductAmount.Req>{ rNoPb });
            System.assert(false, 'Seharusnya melempar "pricebookId is required."');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('pricebookId is required.'), 'Pesan harus "pricebookId is required."');
        }

        // (d) semua nama tidak valid → bersihannya kosong → "No valid product names provided."
        GetProductAmount.Req rNoValidNames = new GetProductAmount.Req();
        rNoValidNames.pricebookId  = stdPbId();
        rNoValidNames.productNames = new List<String>{ '   ;   ;  ', '   ' };
        try {
            GetProductAmount.run(new List<GetProductAmount.Req>{ rNoValidNames });
            System.assert(false, 'Seharusnya melempar "No valid product names provided."');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No valid product names provided.'), 'Pesan harus sesuai');
        }
    }
}

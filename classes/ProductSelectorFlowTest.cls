@IsTest
private class ProductSelectorFlowTest {

    // Seed data Product2 untuk pengujian
    private static void seedProducts() {
        List<Product2> prods = new List<Product2>{
            // Noodles (2 aktif + 1 non-aktif)
            new Product2(Name='Indomie',        Family='Noodles',        IsActive=true),
            new Product2(Name='Pop Mie',        Family='Noodles',        IsActive=true),
            new Product2(Name='Old Noodle',     Family='Noodles',        IsActive=false),

            // Dairy (1 aktif)
            new Product2(Name='Indomilk',       Family='Dairy',          IsActive=true),

            // Food Seasoning (1 aktif)
            new Product2(Name='Kecap Indofood', Family='Food Seasoning', IsActive=true),

            // Beverage (1 aktif) -> harus tidak ikut karena di luar filter
            new Product2(Name='Ichi Ocha',      Family='Beverage',       IsActive=true)
        };
        insert prods;
    }

    @IsTest
    static void testHappyPath_FilterByFamilies_SemicolonParsing() {
        seedProducts();

        ProductSelectorFlow.Request req = new ProductSelectorFlow.Request();
        req.families = new List<String>{
            'Noodles;Dairy',
            '  Food Seasoning  '
        };

        Test.startTest();
        List<List<Product2>> wrapped = ProductSelectorFlow.run(new List<ProductSelectorFlow.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, wrapped.size(), 'Outer list harus 1 elemen.');

        List<Product2> result = wrapped[0];
        // Dari seed: Noodles(2 aktif) + Dairy(1) + Food Seasoning(1) = 4
        System.assertEquals(4, result.size(), 'Jumlah produk aktif yang sesuai families harus 4.');

        Set<String> familiesReturned = new Set<String>();
        Set<String> namesReturned    = new Set<String>();
        for (Product2 p : result) {
            familiesReturned.add(p.Family);
            namesReturned.add(p.Name);
        }
        System.assertEquals(
            new Set<String>{'Noodles','Dairy','Food Seasoning'},
            familiesReturned,
            'Families yang dikembalikan harus persis dengan filter.'
        );

        System.assert(namesReturned.contains('Indomie'),        'Indomie harus ada.');
        System.assert(namesReturned.contains('Pop Mie'),        'Pop Mie harus ada.');
        System.assert(namesReturned.contains('Indomilk'),       'Indomilk harus ada.');
        System.assert(namesReturned.contains('Kecap Indofood'), 'Kecap Indofood harus ada.');
        System.assert(!namesReturned.contains('Ichi Ocha'),     'Beverage (Ichi Ocha) tidak boleh ikut.');
        System.assert(!namesReturned.contains('Old Noodle'),    'Produk non-aktif tidak boleh ikut.');
    }

    @IsTest
    static void testThrows_WhenNoRequest() {
        try {
            Test.startTest();
            ProductSelectorFlow.run(null);
            Test.stopTest();
            System.assert(false, 'Seharusnya melempar exception untuk request null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No request'), 'Pesan exception harus terkait No request.');
        }
    }

    @IsTest
    static void testThrows_WhenEmptyFamilies() {
        ProductSelectorFlow.Request req = new ProductSelectorFlow.Request();
        req.families = new List<String>(); // kosong

        try {
            Test.startTest();
            ProductSelectorFlow.run(new List<ProductSelectorFlow.Request>{ req });
            Test.stopTest();
            System.assert(false, 'Seharusnya melempar exception untuk families kosong');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Required input "families"'),
                'Pesan exception harus menyinggung input families required.');
        }
    }

    @IsTest
    static void testThrows_WhenParsedFamiliesEmpty() {
        ProductSelectorFlow.Request req = new ProductSelectorFlow.Request();
        // Nilai yang setelah trim/split menjadi kosong
        req.families = new List<String>{'   ', ' ;  '};

        try {
            Test.startTest();
            ProductSelectorFlow.run(new List<ProductSelectorFlow.Request>{ req });
            Test.stopTest();
            System.assert(false, 'Seharusnya melempar exception ketika hasil parsing families kosong');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Families parsed to empty set'),
                'Pesan exception harus menyinggung empty set.');
        }
    }
}

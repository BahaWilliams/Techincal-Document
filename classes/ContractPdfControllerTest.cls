@IsTest(SeeAllData=true)
private class ContractPdfControllerTest {

    // ===== Helpers =====
    private static Id stdPbId() {
        return Test.getStandardPricebookId();
    }

    private static Account mkAccount() {
        Account a = new Account(Name = 'ACC-Test ContractPdf');
        insert a;
        return a;
    }

    private static Opportunity mkOpp(Id accId, Id pbId) {
        Opportunity o = new Opportunity(
            Name         = 'OPP-Test ContractPdf',
            StageName    = 'Prospecting',
            CloseDate    = Date.today().addDays(10),
            AccountId    = accId,
            Pricebook2Id = pbId
        );
        insert o;
        return o;
    }

    private static Product2 mustFindProductByName(String name) {
        Product2 p = [
            SELECT Id, Name, Family, IsActive
            FROM Product2
            WHERE Name = :name
            LIMIT 1
        ];
        System.assertNotEquals(null, p, 'Product2 "' + name + '" harus ada di org.');
        System.assertEquals(true, p.IsActive, 'Product2 "' + name + '" harus Active.');
        return p;
    }

    private static PricebookEntry getOrCreateStdPbe(Id pbId, Id productId, Decimal listPrice) {
        PricebookEntry pbe = [
            SELECT Id, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :pbId AND Product2Id = :productId
            LIMIT 1
        ];
        if (pbe != null) return pbe;

        pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id   = productId,
            UnitPrice    = listPrice,
            IsActive     = true
        );
        insert pbe;
        return pbe;
    }

    private static OpportunityLineItem addOli(Id oppId, Id pbeId, Decimal qty, Decimal unitPriceOverride) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = oppId,
            PricebookEntryId = pbeId,
            Quantity         = qty,
            UnitPrice        = unitPriceOverride
        );
        insert oli;
        return oli;
    }

    // ===== Test: Opportunity context + editor flow, pakai Product2 existing =====
    @IsTest
    static void test_OpportunityContext_WithExistingProducts() {
        Id pbId = stdPbId();
        Account acc = mkAccount();
        Opportunity opp = mkOpp(acc.Id, pbId);

        // Pakai 3 produk existing (Pop Mie, Indomie, Ichi Ocha)
        Product2 popMie   = mustFindProductByName('Pop Mie');
        Product2 indomie  = mustFindProductByName('Indomie');
        Product2 ichiOcha = mustFindProductByName('Ichi Ocha');

        PricebookEntry pbePop   = getOrCreateStdPbe(pbId, popMie.Id,   5000);
        PricebookEntry pbeIndo  = getOrCreateStdPbe(pbId, indomie.Id,  7000);
        PricebookEntry pbeIchi  = getOrCreateStdPbe(pbId, ichiOcha.Id, 7000);

        // OLI dengan UnitPrice override ≠ ListPrice
        OpportunityLineItem oli1 = addOli(opp.Id, pbePop.Id,  1, 6000);
        OpportunityLineItem oli2 = addOli(opp.Id, pbeIndo.Id, 2, 7500);
        OpportunityLineItem oli3 = addOli(opp.Id, pbeIchi.Id, 3, 7500);

        // ✅ Perbaikan di sini: pakai currentPage() lalu set parameter id
        ApexPages.currentPage().getParameters().put('id', opp.Id);

        ApexPages.StandardController std = new ApexPages.StandardController(opp);
        ContractPdfController ctrl = new ContractPdfController(std);

        // Asersi dasar
        System.assertEquals(opp.Id, ctrl.oppId);
        System.assertNotEquals(null, ctrl.rows);
        System.assert(ctrl.rows.size() >= 3);
        System.assert(ctrl.totalQty > 0);
        System.assert(ctrl.totalAmount > 0);
        System.assert(ctrl.totalAmountFmt != null && ctrl.totalAmountFmt.startsWith('Rp '));

        // Editor flow
        ctrl.editRowId = oli1.Id;
        ctrl.openEditor();
        System.assertEquals(true, ctrl.showEditor);
        System.assertNotEquals(null, ctrl.editQty);

        Decimal newQty = (ctrl.editQty == null ? 2 : ctrl.editQty + 1);
        ctrl.editQty = newQty;
        ctrl.saveEditor();

        System.assertEquals(false, ctrl.showEditor);
        System.assertEquals(null, ctrl.editRowId);
        System.assertEquals(null, ctrl.editQty);

        OpportunityLineItem oliAfter = [
            SELECT Id, Quantity, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem
            WHERE Id = :oli1.Id
        ];
        System.assertEquals(newQty, oliAfter.Quantity);
        System.assertEquals(oliAfter.PricebookEntry.UnitPrice, oliAfter.UnitPrice);

        ctrl.cancelEditor();
        ctrl.refreshAction();
    }
}

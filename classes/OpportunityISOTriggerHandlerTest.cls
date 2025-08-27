@IsTest
private class OpportunityISOTriggerHandlerTest {

    @IsTest
    static void testUsdConvertedToIdr() {
        // Arrange: buat Opportunity dengan USD
        Opportunity oppUsd = new Opportunity(CurrencyIsoCode = 'USD');

        // Act
        Test.startTest();
        insert oppUsd;
        Test.stopTest();

        // Assert
        oppUsd = [SELECT Id, CurrencyIsoCode FROM Opportunity WHERE Id = :oppUsd.Id];
        System.assertEquals('IDR', oppUsd.CurrencyIsoCode,
            'Opportunity dengan USD harus otomatis diganti ke IDR');
    }

    @IsTest
    static void testIdrStaysIdr() {
        // Arrange: buat Opportunity dengan IDR
        Opportunity accIdr = new Opportunity(CurrencyIsoCode = 'IDR');

        // Act
        Test.startTest();
        insert accIdr;
        Test.stopTest();

        // Assert
        accIdr = [SELECT Id, CurrencyIsoCode FROM Opportunity WHERE Id = :accIdr.Id];
        System.assertEquals('IDR', accIdr.CurrencyIsoCode,
            'Opportunity dengan IDR harus tetap IDR (tidak diubah)');
    }
}

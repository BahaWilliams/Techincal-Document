@IsTest
private class ContactTriggerHandlerTest {

    @IsTest
    static void testUsdConvertedToIdr() {
        // Arrange: buat Contact dengan USD
        Contact contUsd = new Contact(CurrencyIsoCode = 'USD');

        // Act
        Test.startTest();
        insert contUsd;
        Test.stopTest();

        // Assert
        contUsd = [SELECT Id, CurrencyIsoCode FROM Contact WHERE Id = :contUsd.Id];
        System.assertEquals('IDR', contUsd.CurrencyIsoCode,
            'Contact dengan USD harus otomatis diganti ke IDR');
    }

    @IsTest
    static void testIdrStaysIdr() {
        // Arrange: buat Contact dengan IDR
        Contact accIdr = new Contact(CurrencyIsoCode = 'IDR');

        // Act
        Test.startTest();
        insert accIdr;
        Test.stopTest();

        // Assert
        accIdr = [SELECT Id, CurrencyIsoCode FROM Contact WHERE Id = :accIdr.Id];
        System.assertEquals('IDR', accIdr.CurrencyIsoCode,
            'Contact dengan IDR harus tetap IDR (tidak diubah)');
    }
}

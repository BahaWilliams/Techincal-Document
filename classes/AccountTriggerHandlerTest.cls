@IsTest
private class AccountTriggerHandlerTest {

    @IsTest
    static void testUsdConvertedToIdr() {
        // Arrange: buat account dengan USD
        Account accUsd = new Account(Name = 'Test-USD', CurrencyIsoCode = 'USD');

        // Act
        Test.startTest();
        insert accUsd;
        Test.stopTest();

        // Assert
        accUsd = [SELECT Id, CurrencyIsoCode FROM Account WHERE Id = :accUsd.Id];
        System.assertEquals('IDR', accUsd.CurrencyIsoCode,
            'Account dengan USD harus otomatis diganti ke IDR');
    }

    @IsTest
    static void testIdrStaysIdr() {
        // Arrange: buat account dengan IDR
        Account accIdr = new Account(Name = 'Test-IDR', CurrencyIsoCode = 'IDR');

        // Act
        Test.startTest();
        insert accIdr;
        Test.stopTest();

        // Assert
        accIdr = [SELECT Id, CurrencyIsoCode FROM Account WHERE Id = :accIdr.Id];
        System.assertEquals('IDR', accIdr.CurrencyIsoCode,
            'Account dengan IDR harus tetap IDR (tidak diubah)');
    }
}

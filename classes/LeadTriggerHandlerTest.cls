@IsTest
private class LeadTriggerHandlerTest {

    // Helper: ambil salah satu status "converted" untuk skip validasi
    private static String getAnyConvertedStatus() {
        LeadStatus ls = [SELECT ApiName FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        System.assertNotEquals(null, ls, 'Org harus punya setidaknya satu converted LeadStatus');
        return ls.ApiName;
    }

    @IsTest
    static void insert_withEmail_only_shouldPass() {
        Lead l = new Lead(
            LastName = 'Doe',
            Company  = 'Acme',
            Email    = 'john@example.com' // punya email, phone kosong
        );
        Test.startTest();
        insert l;
        Test.stopTest();
        System.assertNotEquals(null, l.Id, 'Lead harus berhasil di-insert dengan email saja');
    }

    @IsTest
    static void insert_withPhoneOnly_shouldPass() {
        Lead l = new Lead(
            LastName    = 'Roe',
            Company     = 'Acme',
            MobilePhone = '08123456789' // punya (mobile) phone, email kosong
        );
        Test.startTest();
        insert l;
        Test.stopTest();
        System.assertNotEquals(null, l.Id, 'Lead harus berhasil di-insert dengan phone saja');
    }

    @IsTest
    static void insert_withoutEmailAndPhone_shouldFail() {
        Lead l = new Lead(
            LastName = 'No Contact',
            Company  = 'Acme'
            // Email kosong, Phone & Mobile kosong
        );

        try {
            Test.startTest();
            insert l; // harus melempar DmlException dari addError
            Test.stopTest();
            System.assert(false, 'Seharusnya gagal karena tidak ada Email maupun Phone/Mobile');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Please provide at least a Phone/Mobile or an Email.'),
                'Pesan error harus sesuai dari addError');
        }
    }

    @IsTest
    static void update_toRemoveContacts_shouldFail() {
        // Awalnya valid (punya email)
        Lead l = new Lead(
            LastName = 'Upd Test',
            Company  = 'Acme',
            Email    = 'upd@example.com'
        );
        insert l;

        // Hapus email & phone → harus gagal di beforeUpdate
        l.Email       = null;
        l.Phone       = null;
        l.MobilePhone = null;

        try {
            Test.startTest();
            update l;
            Test.stopTest();
            System.assert(false, 'Seharusnya gagal saat update karena semua contact info dihapus');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Please provide at least a Phone/Mobile or an Email.'),
                'Pesan error harus sesuai dari addError pada beforeUpdate');
        }
    }

    @IsTest
    static void insert_withConvertedStatus_shouldSkipValidation() {
        String converted = getAnyConvertedStatus();

        // Tanpa email & phone, tapi Status converted → handler harus skip
        Lead l = new Lead(
            LastName = 'Conv',
            Company  = 'Acme',
            Status   = converted
        );

        Test.startTest();
        insert l; // tidak boleh error
        Test.stopTest();

        System.assertNotEquals(null, l.Id,
            'Lead dengan converted status harus lolos tanpa contact info (validasi di-skip)');
    }
}

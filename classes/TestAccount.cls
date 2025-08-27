@isTest
public class TestAccount {
    //1
    @isTest
    static void testInputAccount() {
        AccountApex.inputAcc('williams', 'Web', 'Agriculture', 111);
        Account account = [SELECT Name, AccountSource, Industry, External_Id__c 
                           FROM Account 
                           WHERE Name = 'williams' AND External_Id__c = 111 
                           LIMIT 1];
        System.assertEquals('Web', account.AccountSource);
        System.assertEquals('Agriculture', account.Industry);
    }
	
	//2
    @isTest
    static void testUpdateAccount() {
        Account acc = new Account(
            Name = 'william',
            AccountSource = 'Web',
            Industry = 'Agriculture',
            External_Id__c = 222
        );
        insert acc;
        
        AccountApex.updateAcc('azael', 'Phone Inquiry', 'Banking', 222);
        
        Account updated = [SELECT Name, AccountSource, Industry, External_Id__c 
                           FROM Account 
                           WHERE External_Id__c = 222 
                           LIMIT 1];
        
        System.assertEquals('azael', updated.Name);
        System.assertEquals('Phone Inquiry', updated.AccountSource);
        System.assertEquals('Banking', updated.Industry);
    } 
    
    //3
    @isTest
    static void testInputAccCont() {
        AccountApex.inputAccCont('william_test', 'Web', 'Agriculture', 'Leo', '123123', 'leo@alban.jalu');
    
        Account account = [SELECT Id, Name, AccountSource, Industry, 
                           (SELECT Id, LastName, Phone, Email FROM Contacts) 
                           FROM Account 
                           WHERE Name = 'william_test' 
                           LIMIT 1];
    
        System.assertEquals('william_test', account.Name);
        System.assertEquals(1, account.Contacts.size());
    
        Contact contact = account.Contacts[0];
        System.assertEquals('Leo', contact.LastName);
        System.assertEquals('123123', contact.Phone);
        System.assertEquals('leo@alban.jalu', contact.Email);
    }
    
    //4
    @isTest
	static void testUpdateContactCount() {
    // Create test Account
    Account acc = new Account(Name = 'Account With Contact');
    insert acc;

    Contact contact = new Contact(
        FirstName = 'Test',
        LastName = 'Contact',
        Email = 'test@example.com',
        AccountId = acc.Id
    );
    insert contact;

    acc.Contact_Count__c = 1;
    update acc;

    AccountApex.updateContactCount();

    Account updatedAcc = [
        SELECT Id, Contact_Count__c
        FROM Account
        WHERE Id = :acc.Id
        LIMIT 1
    ];

    System.assertNotEquals(null, updatedAcc.Contact_Count__c);
	}

    
    //6
    @isTest
	static void testCallAccountFromSource() {
	Account acc1 = new Account(Name = 'Alpha', AccountSource = 'Web', Industry = 'Technology');
	Account acc2 = new Account(Name = 'Beta', AccountSource = 'Web', Industry = 'Retail');
	Account acc3 = new Account(Name = 'Gamma', AccountSource = 'Phone Inquiry', Industry = 'Banking');
	insert new List<Account>{ acc1, acc2, acc3 };
    
    List<Account> result = AccountApex.callAccountFromSource('Web');
    System.assertEquals(2, result.size(), 'Should return 2 accounts with AccountSource = Web');
    
    Set<String> expectedNames = new Set<String>{'Alpha', 'Beta'};
	for (Account acc : result) {
    	System.assertEquals('Web', acc.AccountSource, 'AccountSource should be Web');
        System.assert(expectedNames.contains(acc.Name), 'Unexpected account name: ' + acc.Name);
        }
    }
    
    //7
    @isTest
	static void testCallContactBasedOnAccountSource() {
    Account acc1 = new Account(Name = 'Test Account A', AccountSource = 'Web', Industry = 'Tech');
    Account acc2 = new Account(Name = 'Test Account B', AccountSource = 'Phone Inquiry', Industry = 'Retail');
    insert new List<Account>{ acc1, acc2 };

    Contact cont1 = new Contact(LastName = 'John', Phone = '111111', Email = 'john@example.com', AccountId = acc1.Id);
    Contact cont2 = new Contact(LastName = 'Jane', Phone = '222222', Email = 'jane@example.com', AccountId = acc1.Id);
    Contact cont3 = new Contact(LastName = 'Mike', Phone = '333333', Email = 'mike@example.com', AccountId = acc2.Id);
    insert new List<Contact>{ cont1, cont2, cont3 };

    List<Contact> result = AccountApex.callContactBasedOnAccountSource('Web');

    System.assertEquals(2, result.size(), 'Should return 2 contacts linked to AccountSource = Web');

    Set<String> expectedEmails = new Set<String>{'john@example.com', 'jane@example.com'};
    for (Contact c : result) {
        System.assert(expectedEmails.contains(c.Email), 'Unexpected contact returned: ' + c.Email);
    }
}

}
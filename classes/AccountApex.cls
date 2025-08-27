public class AccountApex {
    //Alakhazam
    //1
    public static void inputAcc(String accName, String accSource, String industry, Integer externalId) {
    Account acc = new Account();
    acc.Name = accName;
    acc.AccountSource = accSource;
    acc.Industry = industry;
    acc.External_Id__c = externalId;
    
    insert acc;
	}
    
    //2
    public static void updateAcc(String accName, String accSource, String industry, Integer externalId) {
        List<Account> accList = [SELECT Id, Name, AccountSource, Industry 
                                 FROM Account 
                                 WHERE External_Id__c = :externalId];
    
        if (!accList.isEmpty()) {
            Account acc = accList[0];
            acc.Name = accName;
            acc.AccountSource = accSource;
            acc.Industry = industry;
            update acc;
            System.debug('Berhasil update account dengan External_Id__c = ' + externalId);
        } else {
            System.debug('Tidak ada Account ditemukan dengan External_Id__c = ' + externalId);
        }
    }
    
    //3
    public static void inputAccCont(String accName, String accSource, String industry, 
                                    String contactName, String phone, String mail) {
		Account acc = new Account();
        acc.Name = accName;
        acc.AccountSource = accSource;
        acc.Industry = industry;
		insert acc;                     
                                         
		                                        
		Contact cont = new Contact();
        cont.LastName = contactName;
        cont.Phone = phone;
        cont.Email = mail;
		cont.AccountId = acc.Id;        
                                      
        insert cont;                               
    }
    
    //4 salah
     //public static void updateContactCount(String accName) {
     //   Account acc = [SELECT Id, Name FROM Account WHERE Name = :accName LIMIT 10];

     //   Integer totalContacts = [SELECT COUNT() FROM Contact WHERE AccountId = :acc.Id];

     //   acc.Contact_Count__c = totalContacts;
     //   update acc;

     //   System.debug('Jumlah Contact di account ' + acc.Name + ' adalah: ' + totalContacts);
    //}
    
    //4
    public static void updateContactCount() {
        List<Account> allAccounts = [SELECT Id, Name, (SELECT Id FROM Contacts) FROM Account];
        update allAccounts;
        System.debug('upadate contact count ' + allAccounts.size());
        
		List<Account> result = [SELECT Name, Contact_Count__c, (SELECT Id FROM Contacts) FROM Account WHERE Contact_Count__c != null];
		System.debug('total account dengan contact ' + result.size());        
    }
    
    //5
    public static void createAndInsertMapping(String industryValue) {
        List<String> spvNames = new List<String>{'Spv A', 'Spv B', 'Spv C', 'SPV None'};
        Map<String, Account> existingSpvs = new Map<String, Account>();
        
        for (Account acc : [SELECT Id, Name FROM Account WHERE Name IN :spvNames]) {
            existingSpvs.put(acc.Name, acc);
        }

        List<Account> toInsert = new List<Account>();

        if (!existingSpvs.containsKey('Spv A'))
            toInsert.add(new Account(Name = 'Spv A', Industry = 'Agriculture'));

        if (!existingSpvs.containsKey('Spv B'))
            toInsert.add(new Account(Name = 'Spv B', Industry = 'Apparel'));

        if (!existingSpvs.containsKey('Spv C'))
            toInsert.add(new Account(Name = 'Spv C', Industry = 'Banking'));

        if (!existingSpvs.containsKey('SPV None'))
            toInsert.add(new Account(Name = 'SPV None'));

        if (!toInsert.isEmpty()) {
            insert toInsert;

            for (Account acc : toInsert) {
                existingSpvs.put(acc.Name, acc);
            }
        }

        Account targetAcc;
        List<Account> foundAcc = [SELECT Id FROM Account WHERE Industry = :industryValue LIMIT 1];

        if (!foundAcc.isEmpty()) {
            targetAcc = foundAcc[0];
        } else {
            targetAcc = existingSpvs.get('SPV None');
        }

        Account_Mapping__c mapping = new Account_Mapping__c(
            Industry__c = industryValue,
            Account__c = targetAcc.Id
        );
        insert mapping;

        System.debug('Mapping berhasil dibuat ke account: ' + targetAcc.Id);
    }
    
    //6
    public static List<Account> callAccountFromSource(String sourceAcc) {
        List<Account> accList = [SELECT Name, AccountSource, Industry FROM Account WHERE AccountSource = :sourceAcc];
    
        for (Account acc : accList) {
            System.debug('acc name: ' + acc.Name + ', acc source: ' + acc.AccountSource + ', acc industry: ' + acc.Industry);
        }
    
        System.debug('accList: ' + accList);
        return accList;
    }

    //7
    public static List<Contact> callContactBasedOnAccountSource(String accSource){
        List<Contact> contactList = [SELECT  Name, Phone, Email FROM Contact WHERE Account.AccountSource=:accSource];
        
        for(Contact cnt : contactList){
            System.debug('cnt name: ' + cnt.Name + ', cnt phone: ' + cnt.Phone + ', cnt email: ' + cnt.Email);
        }
        
        System.debug('contactList: ' + contactList);
        return contactList; 

    }
}
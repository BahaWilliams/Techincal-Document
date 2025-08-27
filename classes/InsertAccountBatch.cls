public class InsertAccountBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('Start method called...');
        return Database.getQueryLocator([
            SELECT Id, Name, Phone, Industry FROM Account
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        System.debug('Execute method called...');
        List<Account> accountsToInsert = new List<Account>();

        for (Account source : (List<Account>)scope) {
            Account acc = new Account(
                Name = source.Name + ' (Copy)',
                Phone = source.Phone,
                Industry = source.Industry
            );

            accountsToInsert.add(acc);
        }

        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
            System.debug('Inserted ' + accountsToInsert.size() + ' Account(s)');
        } else {
            System.debug('No accounts to insert.');
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Finish method called...');
    }
}

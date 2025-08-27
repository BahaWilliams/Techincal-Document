public class ScreenFlowLearning {
    @InvocableMethod(label='Screen Flow Search' description='Example Apex method called from flow')
     public static List<List<Account>> myInvocableMethod(List<InputValue> inputStrings) {
     List<List<Account>> listAccount = new List<List<Account>>();
     InputValue input = inputStrings[0];
     String query = 'SELECT Id, Industry, ' + input.fieldType + ' FROM Account WHERE ' + input.fieldType + ' LIKE \'%' + input.valueInput + '%\'';
     List<Account> results = Database.query(query);

     listAccount.add(results);

     return listAccount;
     }

    public class InputValue {
        @InvocableVariable
        public String fieldType;

        @InvocableVariable
        public String valueInput;
    }
}
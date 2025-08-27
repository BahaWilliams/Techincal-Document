public class AccountPhoneValidationTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(){
        phoneValidation();
    }
  
  	protected override void beforeUpdate(){
        phoneValidation();
    }
  
  	protected override void beforeDelete(){
        
    }
  
  	protected override void afterInsert(){
        
    }
  
  	protected override void afterUpdate(){
        
    }
  
  	protected override void afterDelete(){
        
    }
 
  	protected override void afterUndelete(){
        
    }
    
    private void phoneValidation(){
        for (Account acc : (List<Account>)Trigger.new) {
        	if (String.isBlank(acc.Phone)) {
            	acc.Phone.addError('Phone number is required.');
        	}
    	}
    }
}
public class AccountRelateTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(){
        relateAccount();
    }
  
  	protected override void beforeUpdate(){
        relateAccount();
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
    
    private void relateAccount(){
        
    }
}
public class AcountCreateOpptyTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(){

    }
  
  	protected override void beforeUpdate(){
        
    }
  
  	protected override void beforeDelete(){
        
    }
  
  	protected override void afterInsert(){
        List<Opportunity> oppsToInsert = new List<Opportunity>();

    	for (Account acc : (List<Account>)Trigger.new) {
    	    if (acc.Type == 'Prospect') {
	            Opportunity opp = new Opportunity();
    	        opp.Name = acc.Name;
        	    opp.AccountId = acc.Id;
            	opp.StageName = 'Prospecting';
            	opp.CloseDate = Date.today().addDays(30);
            	oppsToInsert.add(opp);
        	}
    	}

	    if (!oppsToInsert.isEmpty()) {
    	    insert oppsToInsert;
    	}
    }
  
  	protected override void afterUpdate(){
        
    }
  
  	protected override void afterDelete(){
        
    }
 
  	protected override void afterUndelete(){
        
    }
}
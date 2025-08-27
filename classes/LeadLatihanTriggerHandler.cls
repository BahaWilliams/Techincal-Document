public class LeadLatihanTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(){
        for (Lead lead : (List<Lead>) Trigger.New) {
			String industry = lead.Industry != null ? lead.Industry : '';
            String source = lead.LeadSource != null ? lead.LeadSource : '';
            lead.Concat_Industry_Source__c = industry + ' ' + source;
            lead.Title = industry + ' ' + source;
        }
    }
  
  	protected override void beforeUpdate(){
        for (Lead lead : (List<Lead>)Trigger.New) {
            Lead oldLead = (Lead)Trigger.oldMap.get(lead.Id);
            //1b - Saat update
            if (oldLead.Status == 'Open - Not Contacted' && lead.Status == 'Working - Contacted') {
            	lead.Rating = 'Warm';
			}
            //1c - Saat update
            else if (oldLead.Status == 'Working - Contacted' && (lead.Status == 'Closed - Converted' || lead.Status == 'Closed - Not Converted')) {
            	lead.Rating = 'Cold';
			}
		}
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
}
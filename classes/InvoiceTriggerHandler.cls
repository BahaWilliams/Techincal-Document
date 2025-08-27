public without sharing class InvoiceTriggerHandler extends TriggerHandler {
  	protected override void afterInsert(){
        Set<Id> invoiceId = new Set<Id>();

        for(InvoiceCustom__c invoice: (List<InvoiceCustom__c>) Trigger.new){
            if(String.isBlank(invoice.External_Id__c)){
                invoiceId.add(invoice.Id);
            }
        }

        if(!invoiceId.isEmpty()){
            InvoiceCallout.sendInvoiceToAPI(invoiceId);
        }
    }
  
  	protected override void afterUpdate(){
        Set<Id> invoiceIds = new Set<Id>();

        for (InvoiceCustom__c inv : (List<InvoiceCustom__c>) Trigger.new) {
            InvoiceCustom__c oldInv = (InvoiceCustom__c)Trigger.oldMap.get(inv.Id);

            if (
                inv.Amount__c != oldInv.Amount__c ||
                inv.Status__c != oldInv.Status__c ||
                inv.Payment_Method__c != oldInv.Payment_Method__c ||
                inv.Payment_Date__c != oldInv.Payment_Date__c ||
                inv.Expire_Date__c != oldInv.Expire_Date__c
            ) {
                invoiceIds.add(inv.Id);
            }
        }

        if (!invoiceIds.isEmpty()) {
            System.debug('ngen ' + invoiceIds);
            InvoiceCallout.updateInvoiceAPI(invoiceIds);
        }
    }
  
  	protected override void afterDelete(){
        Set<Id> invoiceId = new Set<Id>();

        for(InvoiceCustom__c invoice: (List<InvoiceCustom__c>) Trigger.new){
            if(String.isBlank(invoice.External_Id__c)){
                invoiceId.add(invoice.Id);
            }
        }

        if(!invoiceId.isEmpty()){
            InvoiceCallout.deleteInvoiceToAPI(invoiceId);
        }
    } 
}
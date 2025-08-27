public without sharing class InvoiceCallout {
    @future(callout=true)
    public static void sendInvoiceToAPI(Set<Id> invoiceIds) {
        List<InvoiceCustom__c> invoices = [
            SELECT Id, Amount__c, Status__c, Payment_Method__c, Payment_Date__c, Expire_Date__c, Customer__c,
            Customer__r.Name, Customer__r.Phone
            FROM InvoiceCustom__c
            WHERE Id IN :invoiceIds
        ];

        List<InvoiceCustom__c> invoiceToUpdate = new List<InvoiceCustom__c>();

        for (InvoiceCustom__c invoice : invoices) {
            Map<String, Object> payload = new Map<String, Object>{
                'amount' => Integer.valueOf(invoice.Amount__c),
                'currency' => 'IDR',
                'status' => invoice.Status__c != null ? invoice.Status__c.toLowerCase() : 'paid',
                'payment_method' => invoice.Payment_Method__c != null ? invoice.Payment_Method__c : 'e-wallet',
                'payment_date' => invoice.Payment_Date__c,
                'expired_date' => invoice.Expire_Date__c,
                'description' => 'Test Description',
                'customer' => new Map<String, Object>{
                    'customer_name' => invoice.Customer__r.Name,
                    'customer_email' => 'james@bond.c0m',
                    'customer_phone' => invoice.Customer__r.Phone
                }
            };

            String body = JSON.serialize(payload);
            HttpResponse response = BootcampGetawayService.createInvoice(body);

            if (response.getStatusCode().toString().startsWith('2')) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (responseBody.containsKey('id')) {
                    invoice.External_ID__c = String.valueOf(responseBody.get('id'));
                    invoiceToUpdate.add(invoice);
                }
            }
        }

        if (!invoiceToUpdate.isEmpty()) {
            update invoiceToUpdate;
        }
    }
    
    @Future(callout= true)
    public static void updateInvoiceAPI(Set<Id> invoiceId) {
        List<InvoiceCustom__c> invoices = [
            SELECT Id, Name, Amount__c, Status__c, Payment_Method__c, Payment_Date__c, Expire_Date__c, Customer__c,
            Customer__r.Name, Customer__r.Phone
            FROM InvoiceCustom__c
            WHERE Id IN :invoiceId
        ];

        List<InvoiceCustom__c> invoiceUpdate = new List<InvoiceCustom__c>();

        for (InvoiceCustom__c inv : invoices) {
            Map<String, Object> payload = new Map<String, Object>{
                'amount' => Integer.valueOf(inv.Amount__c),
                'id' => inv.External_Id__c,
                'currency' => 'IDR',
                'status' => inv.Status__c != null ? inv.Status__c.toLowerCase() : 'paid',
                'payment_method' => inv.Payment_Method__c != null ? inv.Payment_Method__c : 'e-wallet',
                'paid_date' => inv.Payment_Date__c,
                'expired_date' => inv.Expire_Date__c,
                'description' => 'Test Description',
                'customer' => new Map<String, Object>{
                    'customer_name' => inv.Customer__r.Name,
                    'customer_email' => 'james@bond.c0m',
                    'customer_phone' => inv.Customer__r.Phone
                }
            };
                try {
                    String jsonBody = JSON.serialize(payload);
                    HttpResponse response = BootcampGetawayService.updateInvoice(inv.External_Id__c, jsonBody);
                    
                    if (response.getStatusCode().toString().startsWith('2')) {
                        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                        if (responseBody.containsKey('id')) {
                            inv.External_Id__c = String.valueOf(responseBody.get('id'));
                            invoiceUpdate.add(inv);
                        }
                    }       
                } catch (Exception e) {
                    System.debug(e.getMessage());
                }
           
        }
            
        if (!invoiceUpdate.isEmpty()) {
            try {
                update invoiceUpdate;        
                System.debug(invoiceUpdate);
            } catch (Exception E) {
                System.debug('Error  ' + e.getMessage());
            }
        }
    }

    @future(callout=true)
    public static void deleteInvoiceToAPI(Set<Id> invoiceIds) {
        List<InvoiceCustom__c> invoices = [
        SELECT Id, External_Id__c 
        FROM InvoiceCustom__c 
        WHERE Id IN :invoiceIds AND External_Id__c != null
        ];

        for (InvoiceCustom__c invoice : invoices) {
            try {
                HttpResponse response = BootcampGetawayService.deleteInvoice(invoice.External_ID__c);
                if (response.getStatusCode() == 200 || response.getStatusCode() == 204) {
                    System.debug('Successfully deleted: ' + invoice.External_Id__c);
                } else {
                    System.debug('Failed to delete. Status: ' + response.getStatusCode() + ', Body: ' + response.getBody());
                }
            } catch (Exception e) {
                System.debug('Exception during delete callout: ' + e.getMessage());
            }
        }
    }
}
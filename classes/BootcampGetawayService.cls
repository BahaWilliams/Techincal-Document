public without sharing class BootcampGetawayService {
    
    public static HttpResponse getPayment(){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments');
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();
        Http ht = new Http();

        res = ht.send(req);

        System.debug('res: ' + res);
        System.debug('res body: ' + res.getBody());

        return res;
    }

    public static HttpResponse getPaymentId(String id){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments/' + id);
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();
        Http ht = new Http();

        res = ht.send(req);

        System.debug('res: ' + res);
        System.debug('res body: ' + res.getBody());

        return res;
    }

    /*
    public static HttpResponse createPayment(
    String id,
    String opportunityId,
    String accountId,
    Integer amount,
    String currencyCode,
    String status,
    String paymentMethod,
    String description,
    String customerName,
    String customerEmail,
    String customerPhone,
    Datetime createdDate,
    Datetime updatedDate) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('id', id);
        payload.put('salesforce_opportunity_id', opportunityId);
        payload.put('salesforce_account_id', accountId);
        payload.put('amount', amount);
        payload.put('currency', currencyCode);
        payload.put('status', status);
        payload.put('payment_method', paymentMethod);
        payload.put('description', description);
        payload.put('created_date', createdDate);
        payload.put('updated_date', updatedDate);

        Map<String, Object> customer = new Map<String, Object>();
        customer.put('name', customerName);
        customer.put('email', customerEmail);
        customer.put('phone', customerPhone);
        payload.put('customer', customer);

        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        

        String jsonBody = JSON.serialize(payload);
        req.setBody(jsonBody);
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res;
        res = http.send(req);
        
        return res;
    }
    */

    public static HttpResponse createInvoice(String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments');
        req.setMethod('POST');
        req.setBody(body);
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res;
        res = http.send(req);
        
        return res;
    }

    /*
    public static HttpResponse updateInvoice(String body, String externalId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments' + externalId);
        req.setMethod('PATCH');
        req.setBody(body);
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res;
        res = http.send(req);
        
        return res;
    }
    */

    public static HttpResponse updatePayment(String paymentId, String status, Datetime paidDate, String transactionId) {
        Map<String, Object> payload = new Map<String, Object>{
            'status' => status,
            'paid_date' => paidDate,
            'transaction_id' => transactionId
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments/' + paymentId);
        req.setMethod('PATCH');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('res: ' + res);
        System.debug('body: ' + res.getBody());
        return res;
    }

    public static HttpResponse updateInvoice(String paymentId, String body) {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http ht = new Http();

        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments/' + paymentId);
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(120000);

        res = ht.send(req);
        System.debug('PATCH res: ' + res);
        System.debug('PATCH body: ' + res.getBody());
        return res;
    }

    public static HttpResponse deleteInvoice(String paymentId) {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http ht = new Http();

        req.setEndpoint('https://21ce82c1708e.ngrok-free.app/payments/' + paymentId);
        req.setMethod('DELETE');
        req.setTimeout(120000);

        res = ht.send(req);
        System.debug('DELETE res: ' + res.getStatusCode() + ' ' + res.getBody());
        return res;
    }
}
public without sharing class PaymentService {
    public static HttpResponse getAllPayment(){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments');
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();
        Http ht = new Http();
        res = ht.send(req);

        return res;
    }

    public static HttpResponse createNewData(String body){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://b80fe75a974b.ngrok-free.app/payments');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();
        Http ht = new Http();

        try {
            res = ht.send(req);
            System.debug('Response Status: ' + res.getStatus());
            System.debug('Response Body: ' + res.getBody());
        } catch (CalloutException e) {
            System.debug('Callout error: ' + e.getMessage());
            throw e;
        }

        return res;
    }
}
// Method manggil class service
// Service untuk integreasi dan controller untuk mengisi data untuk service
// Insert invoice harus dengan catatan dalam api success(200 success)

//1. buat apex trigger ketika
//a. invoice di insert di salesforce maka akan melakukan integrasi ke server tadi
//b. bikin trigger ketika update ke salesfoce
//c. ketika server delete, maka salesforce detele data juga

//2. buatlah scheduler apex (bebas beberapa menit) update data invoice mejadi expired ketika payment date invoice melebihi
//3. buat batchable apex untuk melakukan insert data account 


//bikin objek invoice dengan filed 
//customer yang lookup account, 
//payment method dengan tipe picklist isinya credit card bank e-wallet, 
//dan status dengan tipe picklist pending paid called refund, dan ammount dengan tipe number.

//bikin external id(bukan unique dan bukan case sensitive) dan 
//payment date dan expire date dengan tipe date time

//update berdasarkan external id

public without sharing class BootcampGatewayController {    
    public static void postPayment() {
        try{
            HttpResponse res = BootcampGetawayService.createInvoice(generateDataPayment());
            if (res.getStatusCode().toString().startsWith('2')){
                if(String.isNotBlank(res.getBody())){
                    Map<String,Object> mapData = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                    String extId = '';
                    if(mapData.containsKey('id')){
                        extId = (String) mapData.get('id');
                    }
                    generateInvoice(extId);
                }
            }
            System.debug('res: ' + res.getBody());
        }catch (Exception ex){
            System.debug('ex: ' + ex.getMessage() + ' - ' + ex.getLineNumber());
        }
    }

    public static void generateInvoice(String externalId){
        InvoiceCustom__c newInv = new InvoiceCustom__c();//InvoiceCustom__c
        newInv.Customer__c = '001gK00000FR2wMQAT';
        newInv.Amount__c = 1000;
        newInv.Status__c = 'Pending';
        newInv.Payment_Method__c = 'Bank Transfer';
        newInv.Payment_Detail__c = 'BCA';
        newInv.Expire_Date__c = System.now().addDays(1);
        newInv.Payment_Date__c = System.now();
        newInv.External_Id__c = externalId;
        Database.insert(newInv,false);
    }

    /*
    private static void generateInvoice(String extId){
        Invoice__c newInv =  new Invoice__c();
        newInv.Account__c = '001dM00002u2QZsQAM';
        newInv.Amount__c = 1000;
        newInv.Status__c = 'Pending';
        newInv.Payment_Method__c = 'Bank Transfer';
        newInv.Payment_Detail__c = 'BCA';
        newInv.Expired_Date__c = System.now().addDays(1);
        newInv.Payment_Date__c = System.now();
        newInv.External_Id__c = extId;
        Database.insert(newInv,false);
    }
    */

    private static String generateDataPayment(){
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeNumberField('amount', 1000);
        gen.writeStringField('currency', 'IDR');
        gen.writeStringField('status', 'Pending');
        gen.writeStringField('payment_method', 'Bank Transfer');
        gen.writeStringField('description', 'BCA');
        gen.writeFieldName('customer');
        gen.writeStartObject();
        gen.writeStringField('fullName', 'Bootcamp Testing');
        gen.writeStringField('email', 'testing@gmail.com');
        gen.writeStringField('phone', '081-232112-21312');
        gen.writeEndObject();
        gen.writeStringField('created_date', String.valueOf(System.now()));
        gen.writeEndObject();
        return gen.getAsString();
    }
}
public with sharing class PaymentController {
    // private static HttpResponse showAllPayment(){
    //     try {
    //         HttpResponse res = PaymentService.getAllPayment();
            
    //         if (res.getStatusCode() == 200) {
    //             return res;
    //         } else {
    //             System.debug('Callout failed. Status Code: ' + res.getStatusCode() + ' - ' + res.getStatus());
    //         }
    //     } catch (Exception ex) {
    //         System.debug('Exception: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
    //     }
    //     return null;
    // }

    // private static HttpResponse newDataPayment(String body){
    //     try {
    //         HttpResponse res = PaymentService.createNewData(body);
            
    //         if (res.getStatusCode() == 200) {
    //             return res;
    //         } else {
    //             System.debug('Callout failed. Status Code: ' + res.getStatusCode() + ' - ' + res.getStatus());
    //         }
    //     } catch (Exception ex) {
    //         System.debug('Exception: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
    //     }
    //     return null;
    // }

    // //show only status, id, and amount
    // @AuraEnabled(cacheable=true)
    // public static List<Map<String, Object>> showData() {
    //     HttpResponse res = showAllPayment();

    //     if (res == null || String.isEmpty(res.getBody())) {
    //         System.debug('Empty response body');
    //         return new List<Map<String, Object>>();
    //     }

    //     List<Map<String, Object>> result = new List<Map<String, Object>>();

    //     try {
    //         String responseBody = res.getBody();
    //         System.debug('Raw Response Body: ' + responseBody);

    //         // Parse top-level JSON object
    //         Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

    //         // Ambil key "data"
    //         if (responseMap.containsKey('data')) {
    //             Object dataObj = responseMap.get('data');

    //             if (dataObj instanceof List<Object>) {
    //                 List<Object> dataList = (List<Object>) dataObj;

    //                 for (Object obj : dataList) {
    //                     Map<String, Object> payment = (Map<String, Object>) obj;

    //                     Map<String, Object> selected = new Map<String, Object>{
    //                         'id' => payment.get('id'),
    //                         'amount' => payment.get('gross_amount'),
    //                         'status' => payment.get('transaction_status'),
    //                         'currency' => payment.get('currency'),
    //                         'payment_method' => payment.get('payment_method'),
    //                         'created_date' => payment.get('created_date'),
    //                         'updated_date' => payment.get('transaction_time'),
    //                         'due_date' => payment.get('due_date'),
    //                         'customer' => payment.get('customer'),
    //                         'payment_details' => payment.get('va_numbers')
    //                     };

    //                     result.add(selected);
    //                 }
    //             }
    //         } else {
    //             System.debug('No "data" key in JSON response');
    //         }
    //     } catch (Exception ex) {
    //         System.debug('JSON parse error: ' + ex.getMessage());
    //     }

    //     System.debug('Parsed Result: ' + JSON.serialize(result));
    //     return result;
    // }

    // @AuraEnabled
    // public static List<Map<String, Object>> createNewPayment(Object data) {
    //     List<Map<String, Object>> result = new List<Map<String, Object>>();
        
    //     try {
    //         String body = JSON.serialize(data);
    //         System.debug('Serialized Body to Send: ' + body);
    //         HttpResponse res = newDataPayment(body); // Method callout
            
    //         if (res != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
    //             System.debug('Response Status: ' + res.getStatus());
    //             System.debug('Response Body: ' + res.getBody());

    //             Map<String, Object> payment = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

    //             Map<String, Object> selected = new Map<String, Object>{
    //                 'id' => payment.get('id'),
    //                 'amount' => payment.get('gross_amount'),
    //                 'status' => payment.get('transaction_status'),
    //                 'currency' => payment.get('currency'),
    //                 'payment_method' => payment.get('payment_type'),
    //                 'created_date' => payment.get('created_date'),
    //                 'updated_date' => payment.get('transaction_time'),
    //                 'due_date' => payment.get('due_date'),
    //                 'customer' => payment.get('customer'),
    //                 'payment_details' => payment.get('va_numbers')
    //             };
    //             result.add(selected);
    //         } else if (res != null) {
    //             System.debug('Callout failed. Status Code: ' + res.getStatusCode() + ' - ' + res.getStatus());
    //             result.add(new Map<String, Object>{ 'error' => 'Failed to create. Status: ' + res.getStatusCode() });
    //         } else {
    //             result.add(new Map<String, Object>{ 'error' => 'No response from server.' });
    //         }
    //     } catch (Exception ex) {
    //         result.add(new Map<String, Object>{ 'error' => 'Exception: ' + ex.getMessage() });
    //     }

    //     return result;
    // }

    // public class PaymentSummaryDTO {
    //     @AuraEnabled public String  id;
    //     @AuraEnabled public String  status;              // transaction_status
    //     @AuraEnabled public Decimal amount;             // gross_amount
    //     @AuraEnabled public String  currencyCode;           // "IDR"
    //     @AuraEnabled public String  paymentMethod;      // payment_method / payment_type
    //     @AuraEnabled public String  createdDate;        // created_date (string dari API)
    //     @AuraEnabled public String  updatedDate;        // transaction_time
    //     @AuraEnabled public String  dueDate;            // due_date
    //     @AuraEnabled public String  customerName;       // customer.first_name + last_name
    //     @AuraEnabled public String  customerEmail;      // customer.email
    //     @AuraEnabled public String  vaBank;             // va_numbers[0].bank
    //     @AuraEnabled public String  vaNumber;           // va_numbers[0].va_number
    //     @AuraEnabled public String  salesforceId;       // transaction_detail.salesforce_id
    //     @AuraEnabled public Decimal trxAmount;          // transaction_detail.amount (jika ada)
    // }

    // // ===== UTIL: parsing aman berbagai tipe =====
    // private static String asString(Object o) {
    //     return o == null ? null : String.valueOf(o);
    // }
    // private static Decimal asDecimal(Object o) {
    //     if (o == null) return null;
    //     if (o instanceof Decimal) return (Decimal)o;
    //     if (o instanceof Integer) return Decimal.valueOf((Integer)o);
    //     if (o instanceof Long)    return Decimal.valueOf((Long)o);
    //     if (o instanceof Double)  return Decimal.valueOf((Double)o);
    //     if (o instanceof String && ((String)o).trim() != '') {
    //         try { return Decimal.valueOf((String)o); } catch (Exception e) { }
    //     }
    //     return null;
    // }
    // private static Map<String,Object> asMap(Object o) {
    //     return (o instanceof Map<String,Object>) ? (Map<String,Object>)o : null;
    // }
    // private static List<Object> asList(Object o) {
    //     return (o instanceof List<Object>) ? (List<Object>)o : null;
    // }

    // // ====== KONVERSI 1 record payment JSON -> DTO ======
    // private static PaymentSummaryDTO toDTO(Map<String,Object> payment) {
    //     PaymentSummaryDTO dto = new PaymentSummaryDTO();
    //     if (payment == null) return dto;

    //     dto.id            = asString(payment.get('id'));
    //     dto.status        = asString(payment.get('transaction_status'));
    //     dto.amount        = asDecimal(payment.get('gross_amount')); // sumber utama jumlah
    //     if (dto.amount == null) dto.amount = asDecimal(payment.get('amount')); // fallback jika API kirim string "amount"
    //     dto.currencyCode      = asString(payment.get('currency'));
    //     // API kamu pakai "payment_method" (di list) & "payment_type" (di create) – pilih salah satu yang ada
    //     dto.paymentMethod = !String.isBlank(asString(payment.get('payment_method')))
    //                         ? asString(payment.get('payment_method'))
    //                         : asString(payment.get('payment_type'));
    //     dto.createdDate   = asString(payment.get('created_date'));
    //     dto.updatedDate   = asString(payment.get('transaction_time'));
    //     dto.dueDate       = asString(payment.get('due_date'));

    //     // Customer
    //     Map<String,Object> cust = asMap(payment.get('customer'));
    //     if (cust != null) {
    //         String fn = asString(cust.get('first_name'));
    //         String ln = asString(cust.get('last_name'));
    //         dto.customerName  = (fn != null ? fn : '') + (String.isBlank(ln) ? '' : ' ' + ln);
    //         dto.customerEmail = asString(cust.get('email'));
    //     }

    //     // VA Numbers (ambil yang pertama)
    //     List<Object> va = asList(payment.get('va_numbers'));
    //     if (va != null && !va.isEmpty()) {
    //         Map<String,Object> first = asMap(va[0]);
    //         if (first != null) {
    //             dto.vaBank   = asString(first.get('bank'));
    //             dto.vaNumber = asString(first.get('va_number'));
    //         }
    //     }

    //     // transaction_detail
    //     Map<String,Object> trx = asMap(payment.get('transaction_detail'));
    //     if (trx != null) {
    //         dto.salesforceId = asString(trx.get('salesforce_id'));
    //         dto.trxAmount    = asDecimal(trx.get('amount'));
    //     }

    //     return dto;
    // }

    // // =========================================================
    // // ================ PUBLIC METHODS (LWC/Aura) ==============
    // // =========================================================

    // // LIST semua pembayaran -> DTO ringkas
    // @AuraEnabled(cacheable=true)
    // public static List<PaymentSummaryDTO> listPayments() {
    //     HttpResponse res;
    //     try {
    //         res = PaymentService.getAllPayment();
    //     } catch (Exception ex) {
    //         throw new AuraHandledException('Gagal memanggil API: ' + ex.getMessage());
    //     }

    //     if (res == null || String.isBlank(res.getBody())) {
    //         return new List<PaymentSummaryDTO>();
    //     }

    //     List<PaymentSummaryDTO> out = new List<PaymentSummaryDTO>();
    //     try {
    //         Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
    //         // Struktur contoh: { "status_code":"200", "status_message":"Sukses", "data":[ {...}, {...} ] }
    //         List<Object> data = asList(root.get('data'));
    //         if (data != null) {
    //             for (Object row : data) {
    //                 Map<String,Object> payment = asMap(row);
    //                 if (payment != null) out.add(toDTO(payment));
    //             }
    //         }
    //     } catch (Exception ex) {
    //         // Jika format berubah, lempar agar UI bisa menampilkan error
    //         throw new AuraHandledException('Gagal parsing response: ' + ex.getMessage());
    //     }
    //     return out;
    // }

    // // CREATE payment -> kembalikan DTO satu record dari response
    // @AuraEnabled
    // public static PaymentSummaryDTO createPayment(Map<String,Object> payload) {
    //     if (payload == null) {
    //         throw new AuraHandledException('Payload tidak boleh kosong.');
    //     }

    //     HttpResponse res;
    //     try {
    //         String body = JSON.serialize(payload);
    //         res = PaymentService.createNewData(body);
    //     } catch (Exception ex) {
    //         throw new AuraHandledException('Gagal membuat payment: ' + ex.getMessage());
    //     }

    //     if (res == null || String.isBlank(res.getBody())) {
    //         throw new AuraHandledException('Server tidak mengembalikan data.');
    //     }

    //     try {
    //         // Umumnya POST kamu mengembalikan 1 objek payment (bukan {status_code, data[]}).
    //         Object o = JSON.deserializeUntyped(res.getBody());
    //         if (o instanceof Map<String,Object>) {
    //             return toDTO((Map<String,Object>)o);
    //         } else if (o instanceof List<Object>) {
    //             // fallback kalau server mengembalikan array
    //             List<Object> arr = (List<Object>)o;
    //             return arr.isEmpty() ? new PaymentSummaryDTO() : toDTO(asMap(arr[0]));
    //         } else {
    //             // fallback kalau server bungkus seperti GET
    //             Map<String,Object> root = (Map<String,Object>)o;
    //             List<Object> data = asList(root.get('data'));
    //             if (data != null && !data.isEmpty()) return toDTO(asMap(data[0]));
    //         }
    //     } catch (Exception ex) {
    //         throw new AuraHandledException('Gagal parsing response create: ' + ex.getMessage());
    //     }
    //     return new PaymentSummaryDTO();
    // }

    // // (Opsional) Ambil detail by Id kalau kamu tambahkan endpoint GET /payments/{id}
    // @AuraEnabled(cacheable=true)
    // public static PaymentSummaryDTO getPaymentDetail(String id) {
    //     if (String.isBlank(id)) throw new AuraHandledException('Id wajib diisi.');
    //     HttpResponse res;
    //     try {
    //         // Jika PaymentService kamu punya getPaymentById, panggil itu.
    //         // Kalau belum ada, hapus method ini.
    //         res = PaymentService.getAllPayment(); // <- placeholder jika belum ada endpoint detail
    //     } catch (Exception ex) {
    //         throw new AuraHandledException('Gagal memanggil API: ' + ex.getMessage());
    //     }
    //     if (res == null || String.isBlank(res.getBody())) return new PaymentSummaryDTO();

    //     try {
    //         Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
    //         List<Object> data = asList(root.get('data'));
    //         if (data != null) {
    //             for (Object row : data) {
    //                 Map<String,Object> payment = asMap(row);
    //                 if (payment != null && id == asString(payment.get('id'))) {
    //                     return toDTO(payment);
    //                 }
    //             }
    //         }
    //     } catch (Exception ex) {
    //         throw new AuraHandledException('Gagal parsing response: ' + ex.getMessage());
    //     }
    //     return new PaymentSummaryDTO();
    // }


    public class PaymentSummaryDTO {
        @AuraEnabled public String  id;             // API payment id
        @AuraEnabled public String  status;         // transaction_status
        @AuraEnabled public Decimal amount;         // gross_amount / amount
        @AuraEnabled public String  currencyCode;   // "IDR"
        @AuraEnabled public String  paymentMethod;  // payment_method / payment_type
        @AuraEnabled public String  createdDate;    // created_date (string)
        @AuraEnabled public String  updatedDate;    // transaction_time
        @AuraEnabled public String  dueDate;        // due_date
        @AuraEnabled public String  customerName;   // first + last
        @AuraEnabled public String  customerEmail;  // email
        @AuraEnabled public String  vaBank;         // va_numbers[0].bank
        @AuraEnabled public String  vaNumber;       // va_numbers[0].va_number
        @AuraEnabled public String  salesforceId;   // transaction_detail.salesforce_id
        @AuraEnabled public Decimal trxAmount;      // transaction_detail.amount
    }
    public class CreateResult {
        @AuraEnabled public String apiPaymentId;  // id dari API eksternal
        @AuraEnabled public Id     sfRecordId;    // Id Payment_Record__c yang dibuat
        @AuraEnabled public PaymentSummaryDTO api; // ringkasan payload API
    }
    public class RowDTO {
        @AuraEnabled public String  status;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  paymentMethod;
        @AuraEnabled public String  customerName;
        @AuraEnabled public String  email;
        @AuraEnabled public String  dueDate;
    }

    // =======================
    // Utils kecil
    // =======================
    private static String asString(Object o) { return o == null ? null : String.valueOf(o); }
    private static Decimal asDecimal(Object o) {
        if (o == null) return null;
        if (o instanceof Decimal) return (Decimal)o;
        if (o instanceof Integer) return Decimal.valueOf((Integer)o);
        if (o instanceof Long)    return Decimal.valueOf((Long)o);
        if (o instanceof Double)  return Decimal.valueOf((Double)o);
        if (o instanceof String && ((String)o).trim() != '') {
            try { return Decimal.valueOf((String)o); } catch (Exception e) {}
        }
        return null;
    }
    private static Map<String,Object> asMap(Object o) {
        return (o instanceof Map<String,Object>) ? (Map<String,Object>)o : null;
    }
    private static List<Object> asList(Object o) {
        return (o instanceof List<Object>) ? (List<Object>)o : null;
    }

    // Konversi 1 objek payment dari API -> DTO
    private static PaymentSummaryDTO toDTO(Map<String,Object> payment) {
        PaymentSummaryDTO dto = new PaymentSummaryDTO();
        if (payment == null) return dto;

        dto.id            = asString(payment.get('id'));
        dto.status        = asString(payment.get('transaction_status'));
        dto.amount        = asDecimal(payment.get('gross_amount'));
        if (dto.amount == null) dto.amount = asDecimal(payment.get('amount'));
        dto.currencyCode  = asString(payment.get('currency'));
        dto.paymentMethod = !String.isBlank(asString(payment.get('payment_method')))
                            ? asString(payment.get('payment_method'))
                            : asString(payment.get('payment_type'));
        dto.createdDate   = asString(payment.get('created_date'));
        dto.updatedDate   = asString(payment.get('transaction_time'));
        dto.dueDate       = asString(payment.get('due_date'));

        Map<String,Object> cust = asMap(payment.get('customer'));
        if (cust != null) {
            String fn = asString(cust.get('first_name'));
            String ln = asString(cust.get('last_name'));
            dto.customerName  = (fn != null ? fn : '') + (String.isBlank(ln) ? '' : ' ' + ln);
            dto.customerEmail = asString(cust.get('email'));
        }

        List<Object> va = asList(payment.get('va_numbers'));
        if (va != null && !va.isEmpty()) {
            Map<String,Object> first = asMap(va[0]);
            if (first != null) {
                dto.vaBank   = asString(first.get('bank'));
                dto.vaNumber = asString(first.get('va_number'));
            }
        }

        Map<String,Object> trx = asMap(payment.get('transaction_detail'));
        if (trx != null) {
            dto.salesforceId = asString(trx.get('salesforce_id'));
            dto.trxAmount    = asDecimal(trx.get('amount'));
        }
        return dto;
    }

    // ============================================================
    // ==============  METHOD UTAMA: CREATE + INSERT  =============
    // ============================================================
    /**
     * 1) Call API eksternal (POST /payments)
     * 2) Insert Payment_Record__c baru sesuai field/relasi kamu
     *    - Amount__c dari Quote (GrandTotal -> TotalPrice), dibulatkan 0 desimal
     *    - CreatedFrom__c dari Contract.StartDate (boleh override)
     *    - DueDate__c dari Contract_Due_Date__c (boleh override)
     *    - Payment_Method__c, Payment_Dates__c sesuai picklist
     *    - CurrencyIsoCode di-set (mis. 'IDR')
     *    - ExternalPaymentId__c & Status__c dari API
     */
    @AuraEnabled
    public static CreateResult createPaymentAndRecord(
        Id contractId,
        Id accountId,
        Id opportunityId,
        Id quoteId,
        String email,
        String paymentMethod,    // cash | credit_card | qris | transfer | debit
        String paymentDates,     // Monthly | Weekly
        Date   contractStartDate,   // opsional override
        Date   contractDueDate,     // opsional override
        String currencyCode        // opsional, default 'IDR'
    ){
        if (String.isBlank(currencyCode)) currencyCode = 'IDR';

        // ---------- Validasi minimal ----------
        if (contractId == null)   throw new AuraHandledException('Contract wajib dipilih.');
        if (accountId == null)    throw new AuraHandledException('Account wajib dipilih.');
        if (opportunityId == null)throw new AuraHandledException('Opportunity wajib dipilih.');
        if (quoteId == null)      throw new AuraHandledException('Quote wajib dipilih.');
        if (String.isBlank(email))          throw new AuraHandledException('Email wajib diisi.');
        if (String.isBlank(paymentMethod))  throw new AuraHandledException('Payment Method wajib dipilih.');
        if (String.isBlank(paymentDates))   throw new AuraHandledException('Payment Dates wajib dipilih.');

        // ---------- Ambil konteks Contract & Quote ----------
        Contract c = [
            SELECT Id, StartDate, Contract_Due_Date__c, AccountId
            FROM Contract WHERE Id = :contractId LIMIT 1
        ];
        Quote q = [
            SELECT Id, GrandTotal, TotalPrice
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];
        Decimal quoteAmt = (q.GrandTotal != null) ? q.GrandTotal :
                           (q.TotalPrice  != null) ? q.TotalPrice : 0;

        // Tentukan tanggal utk record SF (UI > Contract)
        Date startDate = (contractStartDate != null) ? contractStartDate : c.StartDate;
        Date dueDate   = (contractDueDate   != null) ? contractDueDate   : c.Contract_Due_Date__c;

        // (Opsional) Ambil Account Name utk customer.first_name
        Account acc = [
            SELECT Name FROM Account WHERE Id = :accountId LIMIT 1
        ];

        // ---------- Susun payload ke API ----------
        Map<String,Object> payload = new Map<String,Object>{
            'payment_method'   => paymentMethod,
            'payment_details'  => paymentDates,               // Monthly / Weekly
            'transaction_detail' => new Map<String,Object>{
                'salesforce_id' => (String)opportunityId,
                'amount'        => (Integer)Math.round( (quoteAmt == null ? 0 : quoteAmt).setScale(0) )
            },
            'customer' => new Map<String,Object>{
                'first_name' => acc != null ? acc.Name : null,
                'last_name'  => '',
                'email'      => email
            },
            'amount'       => String.valueOf( (quoteAmt == null ? 0 : quoteAmt).setScale(2) ), // "123456.00"
            'payment_type' => paymentMethod,
            'currency'     => currencyCode
        };

        // ---------- Call API ----------
        HttpResponse res;
        try {
            res = PaymentService.createNewData(JSON.serialize(payload));
        } catch (Exception ex) {
            throw new AuraHandledException('Gagal call API: ' + ex.getMessage());
        }
        if (res == null || String.isBlank(res.getBody())) {
            throw new AuraHandledException('API tidak mengembalikan data.');
        }

        // ---------- Parse respons API ----------
        PaymentSummaryDTO apiDto;
        try {
            Object body = JSON.deserializeUntyped(res.getBody());
            if (body instanceof Map<String,Object>) {
                apiDto = toDTO( (Map<String,Object>)body );
            } else if (body instanceof List<Object>) {
                List<Object> arr = (List<Object>)body;
                apiDto = arr.isEmpty() ? new PaymentSummaryDTO() : toDTO((Map<String,Object>)arr[0]);
            } else {
                Map<String,Object> root = (Map<String,Object>)body;
                List<Object> data = asList(root.get('data'));
                apiDto = (data != null && !data.isEmpty()) ? toDTO(asMap(data[0])) : new PaymentSummaryDTO();
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Gagal parsing respons API: ' + ex.getMessage());
        }

        // ---------- Insert Payment_Record__c ----------
        Payment_Record__c pr = new Payment_Record__c();
        pr.Company_Account__c = accountId;
        pr.Contract__c        = contractId;
        pr.SalesforceRef__c   = opportunityId;
        pr.Quote__c           = quoteId;

        pr.Email__c           = email;
        pr.Payment_Method__c  = paymentMethod;  // picklist: cash/credit_card/qris/transfer/debit
        pr.Payment_Dates__c   = paymentDates;   // picklist: Monthly/Weekly
        pr.CurrencyIsoCode    = currencyCode;   // org kamu punya field ini

        if (quoteAmt != null) pr.Amount__c = quoteAmt.setScale(0); // Currency(18,0)
        // if (startDate != null) pr.CreatedFrom__c = DateTime.newInstance(startDate, Time.newInstance(0,0,0,0));
        // if (dueDate   != null) pr.DueDate__c     = DateTime.newInstance(dueDate,   Time.newInstance(0,0,0,0));

        pr.ExternalPaymentId__c = apiDto.id;          // External ID (unique)
        if (!String.isBlank(apiDto.status)) pr.Status__c = apiDto.status;

        try {
            insert pr;
        } catch (DmlException d) {
            // Kalau gagal simpan (mis. external id duplikat), laporkan error jelas
            throw new AuraHandledException('Gagal menyimpan Payment Record: ' + d.getMessage());
        }

        // ---------- Hasil ke caller ----------
        CreateResult out = new CreateResult();
        out.apiPaymentId = apiDto.id;
        out.sfRecordId   = pr.Id;
        out.api          = apiDto;
        return out;
    }

    // ============================================================
    // ==============  LIST Payment Record per Contract  ==========
    // (opsional untuk LWC tabel yang kamu punya)
    // ============================================================
    @AuraEnabled(cacheable=true)
    public static List<RowDTO> listByContract(Id contractId){
        if (contractId == null) return new List<RowDTO>();
        List<RowDTO> out = new List<RowDTO>();
        for (Payment_Record__c p : [
            SELECT Status__c, Amount__c, Payment_Method__c,
                   Email__c, Company_Account__r.Name
            FROM Payment_Record__c
            WHERE Contract__c = :contractId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            RowDTO r = new RowDTO();
            r.status       = p.Status__c;
            r.amount       = p.Amount__c;
            r.paymentMethod= p.Payment_Method__c;
            r.customerName = (p.Company_Account__r != null ? p.Company_Account__r.Name : null);
            r.email        = p.Email__c;
            // r.dueDate      = (p.DueDate__c != null ? String.valueOf(p.DueDate__c) : null);
            out.add(r);
        }
        return out;
    }
}
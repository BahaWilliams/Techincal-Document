public with sharing class PaymentRecordTriggerHandler extends TriggerHandler {

    // Hindari enqueue berulang dalam 1 transaksi
    private static Boolean enqueuedThisTx = false;

    // Kriteria "siap kirim ke API" menyesuaikan mapper & queueable terbaru
    private static Boolean isReady(Payment_Record__c p) {
        if (p == null) return false;

        // Belum pernah disinkron
        if (!String.isBlank(p.ExternalPaymentId__c)) return false;

        // Wajib: method & dates (picklist)
        if (String.isBlank(p.Payment_Method__c)) return false;
        if (String.isBlank(p.Payment_Dates__c))  return false;

        // Wajib: referensi Opp (salesforce_id di payload)
        if (p.SalesforceRef__c == null) return false;

        // Wajib: email diambil dari Contact__r.Email -> butuh Contact__c
        if (p.Contact__c == null) return false;

        // Wajib: sumber amount (mapper utamakan Quote. Boleh fallback ke Amount__c kalau kamu izinkan)
        if (p.Quote__c == null && p.Amount__c == null) return false;

        // (Opsional) Contract__c jika kamu ingin memastikan relasi ada
        // if (p.Contract__c == null) return false;

        return true;
    }

    protected override void afterInsert() {
        Set<Id> toSend = new Set<Id>();
        for (Payment_Record__c pr : (List<Payment_Record__c>) Trigger.new) {
            if (isReady(pr)) {
                toSend.add(pr.Id);
            }
        }
        enqueueIfAny(toSend);
    }

    protected override void afterUpdate() {
        Set<Id> toSend = new Set<Id>();
        Map<Id, Payment_Record__c> oldMap = (Map<Id, Payment_Record__c>) Trigger.oldMap;

        for (Payment_Record__c pr : (List<Payment_Record__c>) Trigger.new) {
            Payment_Record__c oldRec = oldMap.get(pr.Id);

            // Enqueue hanya jika transisi dari "belum ready" -> "ready"
            Boolean becameReady = isReady(pr) && !isReady(oldRec);

            // (Tambahan aman) jika ExternalPaymentId__c baru diisi oleh proses lain, otomatis tidak ready lagi.
            if (becameReady) {
                toSend.add(pr.Id);
            }
        }
        enqueueIfAny(toSend);
    }

    // Helper enqueue queueable satu kali per transaksi
    private static void enqueueIfAny(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return;
        if (enqueuedThisTx) return; // cegah dobel enqueue dalam trx yang sama
        System.enqueueJob(new CreatePaymentQueueable(ids));
        enqueuedThisTx = true;
    }
}

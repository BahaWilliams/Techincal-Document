public with sharing class OLIVFController {

    public Id oppId { get; private set; }

    public List<OLIRow> rows { get; private set; }
    public List<FamilyBox> familySummary { get; private set; }

    public Decimal totalQty    { get; private set; }
    public Decimal totalAmount { get; private set; }
    public String  totalAmountFmt { get { return formatIdr(totalAmount); } }

    public Boolean showEditor { get; set; }
    public Id      editRowId  { get; set; }
    public Decimal editQty    { get; set; }

    private static final Boolean LOCK_UNITPRICE_TO_LISTPRICE = true;

    public OLIVFController(ApexPages.StandardController std) {
        SObject so = std.getRecord();
        String apiName = (so == null) ? null : so.getSObjectType().getDescribe().getName();

        if (apiName == 'Opportunity') {
            this.oppId = std.getId();
        } else if (apiName == 'Contract') {
            String p = ApexPages.currentPage().getParameters().get('oppId');
            if (p != null && p.startsWith('006')) { 
                this.oppId = (Id)p;
            }
            if (this.oppId == null) {
                Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('Contract').getDescribe().fields.getMap();
                if (fields.containsKey('Opportunity__c')) {
                    try {
                        Object v = so.get('Opportunity__c');
                        if (v != null) this.oppId = (Id)v;
                    } catch (Exception e) { /* ignore */ }
                }
            }
        } else {
        }

        refresh();
    }

    public PageReference openEditor() {
        if (rows != null) {
            for (OLIRow r : rows) {
                if (r.id == editRowId) { editQty = r.quantity; break; }
            }
        }
        showEditor = true;
        return null;
    }

    public PageReference cancelEditor() {
        showEditor = false; editRowId = null; editQty = null; return null;
    }

    public PageReference saveEditor() {
        if (editRowId == null) return null;

        OpportunityLineItem oli = [
            SELECT Id, Quantity, UnitPrice, PricebookEntry.UnitPrice
            FROM OpportunityLineItem
            WHERE Id = :editRowId
            LIMIT 1
        ];
        Decimal q = (editQty == null || editQty < 0) ? 0 : editQty;

        OpportunityLineItem upd = new OpportunityLineItem(Id = oli.Id, Quantity = q);

        if (LOCK_UNITPRICE_TO_LISTPRICE) {
            Decimal listPrice = (oli.PricebookEntry != null) ? oli.PricebookEntry.UnitPrice : null;
            if (listPrice != null) upd.UnitPrice = listPrice;
        }

        Database.SaveResult sr = Database.update(upd, false);
        if (!sr.isSuccess()) {
            List<String> msgs = new List<String>();
            for (Database.Error e : sr.getErrors()) msgs.add(e.getMessage());
            throw new AuraHandledException('Gagal menyimpan: ' + String.join(msgs, ' | '));
        }

        showEditor = false; editRowId = null; editQty = null;
        refresh();
        return null;
    }

    public PageReference refreshAction() { refresh(); return null; }

    private void refresh() {
        rows = new List<OLIRow>();
        familySummary = new List<FamilyBox>();
        totalQty = 0; totalAmount = 0;

        if (oppId == null) {
            return;
        }

        List<OpportunityLineItem> olis = [
            SELECT Id, Quantity, UnitPrice, TotalPrice,
                   PricebookEntry.UnitPrice,
                   PricebookEntry.Product2.Name,
                   PricebookEntry.Product2.Family
            FROM OpportunityLineItem
            WHERE OpportunityId = :oppId
            ORDER BY PricebookEntry.Product2.Name
        ];

        Map<String, FamilyBox> byFam = new Map<String, FamilyBox>();

        for (OpportunityLineItem x : olis) {
            Decimal qty  = (x.Quantity == null ? 0 : x.Quantity);
            Decimal ltot = (x.TotalPrice != null)
                           ? x.TotalPrice
                           : ((x.UnitPrice == null || x.Quantity == null) ? 0 : x.UnitPrice * x.Quantity);

            OLIRow r = new OLIRow();
            r.id            = x.Id;
            r.productName   = (x.PricebookEntry != null && x.PricebookEntry.Product2 != null) ? x.PricebookEntry.Product2.Name : null;
            r.productFamily = (x.PricebookEntry != null && x.PricebookEntry.Product2 != null) ? x.PricebookEntry.Product2.Family : null;
            r.unitPrice     = x.UnitPrice;
            r.quantity      = qty;
            r.lineTotal     = ltot;
            r.listPrice     = (x.PricebookEntry != null ? x.PricebookEntry.UnitPrice : null);
            rows.add(r);

            totalQty    += qty;
            totalAmount += ltot;

            String fam = (r.productFamily == null) ? 'Uncategorized' : r.productFamily;
            FamilyBox fb = byFam.get(fam);
            if (fb == null) {
                fb = new FamilyBox();
                fb.family = fam; fb.qty = 0; fb.totalAmount = 0;
                byFam.put(fam, fb);
            }
            fb.qty         += qty;
            fb.totalAmount += ltot;
        }

        familySummary = new List<FamilyBox>(byFam.values());
        if (!familySummary.isEmpty()) familySummary.sort(new FamilySorter());
    }

    public class OLIRow {
        public Id      id            { get; set; }
        public String  productName   { get; set; }
        public String  productFamily { get; set; }
        public Decimal unitPrice     { get; set; }
        public Decimal listPrice     { get; set; }
        public Decimal quantity      { get; set; }
        public Decimal lineTotal     { get; set; }

        public String unitPriceFmt { get { return formatIdr(unitPrice); } }
        public String lineTotalFmt { get { return formatIdr(lineTotal); } }
    }

    public class FamilyBox {
        public String  family      { get; set; }
        public Decimal qty         { get; set; }
        public Decimal totalAmount { get; set; }

        public String totalFmt     { get { return formatIdr(totalAmount); } }
    }

    public class FamilySorter implements System.Comparator<FamilyBox> {
        public Integer compare(FamilyBox a, FamilyBox b) {
            if (a == null || a.family == null) return -1;
            if (b == null || b.family == null) return 1;
            return a.family.toLowerCase().compareTo(b.family.toLowerCase());
        }
    }

    private static String formatIdr(Decimal v) {
        if (v == null) return 'Rp 0';
        return 'Rp ' + v.setScale(0).format();
    }
}

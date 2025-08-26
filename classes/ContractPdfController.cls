public with sharing class ContractPdfController {

    public Id oppId { get; private set; }

    public List<OLIRow> rows { get; private set; }
    public List<FamilyBox> familySummary { get; private set; }

    public Decimal totalQty    { get; private set; }
    public Decimal totalAmount { get; private set; }
    public String  totalAmountFmt { get { return formatIdr(totalAmount); } }

    public Boolean showEditor { get; set; }
    public Id      editRowId  { get; set; }
    public Decimal editQty    { get; set; }

    public String debugInfo { get; private set; }

    private static final Boolean LOCK_UNITPRICE_TO_LISTPRICE = true;

    private static final List<String> HARI = new List<String>{
        'Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'
    };
    private static final List<String> BULAN = new List<String>{
        'Januari','Februari','Maret','April','Mei','Juni',
        'Juli','Agustus','September','Oktober','November','Desember'
    };

    private Contract contractRecord;
    public  ApexPages.StandardController stdController { get; private set; }

    public ContractPdfController(ApexPages.StandardController std) {
        List<String> debugMessages = new List<String>();
        this.stdController  = std;
        this.contractRecord = null;

        SObject so = std.getRecord();
        String apiName = (so == null) ? null : so.getSObjectType().getDescribe().getName();

        debugMessages.add('Context: ' + apiName);
        debugMessages.add('Record ID: ' + std.getId());

        if (apiName == 'Opportunity') {
            this.oppId = std.getId();
            debugMessages.add('Found Opportunity ID: ' + this.oppId);

        } else if (apiName == 'Contract') {
            debugMessages.add('Processing Contract record...');

            String urlOppId = ApexPages.currentPage().getParameters().get('oppId');
            debugMessages.add('URL oppId parameter: ' + urlOppId);

            if (String.isNotBlank(urlOppId)) {
                try {
                    Id testId = (Id) urlOppId;
                    String objectType = testId.getSObjectType().getDescribe().getName();
                    debugMessages.add('URL parameter object type: ' + objectType);
                    if (objectType == 'Opportunity') {
                        this.oppId = testId;
                        debugMessages.add('Valid Opportunity ID from URL: ' + this.oppId);
                    }
                } catch (Exception e) {
                    debugMessages.add('Invalid URL parameter: ' + e.getMessage());
                }
            }

            if (this.oppId == null) {
                debugMessages.add('Trying to find Opportunity from Contract fields...');
                try {
                    Contract cMini = [SELECT Id, AccountId FROM Contract WHERE Id = :std.getId() LIMIT 1];
                    debugMessages.add('Contract AccountId: ' + cMini.AccountId);

                    Map<String, Schema.SObjectField> contractFields = Schema.SObjectType.Contract.fields.getMap();
                    List<String> possibleOppFields = new List<String>();

                    for (String fieldName : contractFields.keySet()) {
                        Schema.DescribeFieldResult fdesc = contractFields.get(fieldName).getDescribe();
                        if (fdesc.getType() == Schema.DisplayType.Reference) {
                            for (Schema.SObjectType rt : fdesc.getReferenceTo()) {
                                if (rt.getDescribe().getName() == 'Opportunity') {
                                    possibleOppFields.add(fieldName);
                                    break;
                                }
                            }
                        }
                    }

                    debugMessages.add('Found possible Opportunity fields: ' + String.join(possibleOppFields, ', '));

                    if (!possibleOppFields.isEmpty()) {
                        String fields = String.join(possibleOppFields, ', ');
                        String soql =
                            'SELECT Id' + (fields == null || fields == '' ? '' : ', ' + fields) +
                            ' FROM Contract WHERE Id = \'' + String.escapeSingleQuotes(String.valueOf(std.getId())) + '\' LIMIT 1';

                        List<Contract> cons = Database.query(soql);
                        if (!cons.isEmpty()) {
                            Contract fullContract = cons[0];
                            for (String fname : possibleOppFields) {
                                Object fv = fullContract.get(fname);
                                if (fv != null) {
                                    this.oppId = (Id) fv;
                                    debugMessages.add('Found Opportunity ID from field ' + fname + ': ' + this.oppId);
                                    break;
                                }
                            }
                        }
                    }

                    if (this.oppId == null && cMini.AccountId != null) {
                        List<Opportunity> recentOpps = [
                            SELECT Id, Name, CreatedDate
                            FROM Opportunity
                            WHERE AccountId = :cMini.AccountId
                              AND StageName != 'Closed Lost'
                            ORDER BY CreatedDate DESC
                            LIMIT 5
                        ];
                        debugMessages.add('Found ' + recentOpps.size() + ' opportunities for Account');
                        if (!recentOpps.isEmpty()) {
                            this.oppId = recentOpps[0].Id;
                            debugMessages.add('Using most recent Opportunity: ' + recentOpps[0].Name + ' (' + this.oppId + ')');
                        }
                    }

                } catch (Exception e) {
                    debugMessages.add('Error querying Contract: ' + e.getMessage());
                }
            }

        } else {
            debugMessages.add('Unknown context: ' + apiName);
        }

        debugMessages.add('Final oppId: ' + this.oppId);
        this.debugInfo = String.join(debugMessages, ' | ');

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

        if (oppId == null) return;

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

    private void ensureContractLoaded() {
        if (stdController == null) return;
        if (contractRecord == null || contractRecord.StartDate == null) {
            contractRecord = [
                SELECT Id, StartDate, EndDate, AccountId, OwnerId, CustomerSignedId,
                       Contract_Due_Date__c
                FROM Contract
                WHERE Id = :stdController.getId()
                LIMIT 1
            ];
        }
    }

    public String getStartDateId() {
        ensureContractLoaded();
        Date d = (contractRecord != null) ? contractRecord.StartDate : null;
        return formatTanggalIndo(d);
    }

    public String getDueDateId() {
        ensureContractLoaded();
        if (contractRecord == null) return '-';

        Object o = contractRecord.get('Contract_Due_Date__c');
        if (o == null) return '-';

        Date d;
        if (o instanceof Date) {
            d = (Date)o;
        } else if (o instanceof Datetime) {
            d = ((Datetime)o).date();
        } else {
            return String.valueOf(o);
        }
        return formatTanggalIndo(d);
    }

    private static String formatTanggalIndo(Date d){
        if (d == null) return '-';
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        Integer isoDow = Integer.valueOf(dt.format('u'));
        Integer dow    = (isoDow == 7) ? 1 : isoDow + 1;
        return HARI[dow-1] + ', ' + d.day() + ' ' + BULAN[d.month()-1] + ' ' + d.year();
    }
}

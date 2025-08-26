public with sharing class ContractPdfSaveController {
    private final Id recordId;
    public ContractPdfSaveController(ApexPages.StandardController sc){
        this.recordId = sc.getId();
    }

    public PageReference saveAndRedirect(){
        // render PDF dari page Contract_PDF
        PageReference pdf = Page.ContractPdf;
        pdf.getParameters().put('id', recordId);
        Blob body = pdf.getContentAsPDF();  // allowed dari request Visualforce

        // simpan ke Files (ContentVersion) & link ke Contract
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Contract-' + String.valueOf(recordId).substring(0,5) + '-' +
                   Date.today().format();
        cv.PathOnClient = 'Contract.pdf';
        cv.VersionData = body;
        cv.FirstPublishLocationId = recordId; // parent record
        insert cv;

        // kembali ke record Contract
        PageReference back = new ApexPages.StandardController(
            [SELECT Id FROM Contract WHERE Id = :recordId]
        ).view();
        back.setRedirect(true);
        return back;
    }
}
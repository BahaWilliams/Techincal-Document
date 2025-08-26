public with sharing class OpportunityISOTriggerHandler extends TriggerHandler {
    public static final String DEFAULT_ISO = 'IDR';

    protected override void beforeInsert() {
        for (Opportunity opp : (List<Opportunity>) Trigger.new) {
            if (String.isBlank(opp.CurrencyIsoCode) || opp.CurrencyIsoCode == 'USD') {
                opp.CurrencyIsoCode = DEFAULT_ISO;
            }
        }
    }
}
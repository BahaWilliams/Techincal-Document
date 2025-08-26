public with sharing class ContactTriggerHandler extends TriggerHandler {
    public static final String DEFAULT_ISO = 'IDR';

    protected override void beforeInsert() {
        for (Contact cont : (List<Contact>) Trigger.new) {
            if (String.isBlank(cont.CurrencyIsoCode) || cont.CurrencyIsoCode == 'USD') {
                cont.CurrencyIsoCode = DEFAULT_ISO;
            }
        }
    }
}
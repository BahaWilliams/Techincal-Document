public with sharing class AccountTriggerHandler extends TriggerHandler {
    public static final String DEFAULT_ISO = 'IDR';

    protected override void beforeInsert() {
        for (Account acc : (List<Account>) Trigger.new) {
            if (String.isBlank(acc.CurrencyIsoCode) || acc.CurrencyIsoCode == 'USD') {
                acc.CurrencyIsoCode = DEFAULT_ISO;
            }
        }
    }
}
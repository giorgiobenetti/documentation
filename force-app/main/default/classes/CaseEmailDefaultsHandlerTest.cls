@IsTest
private class CaseEmailDefaultsHandlerTest {
    @IsTest
    static void onInitDefaults_handlesNullList() {
        CaseEmailDefaultsHandler h = new CaseEmailDefaultsHandler();
        h.onInitDefaults(null);
    }

    @IsTest
    static void onInitDefaults_handlesEmptyList() {
        CaseEmailDefaultsHandler h = new CaseEmailDefaultsHandler();
        h.onInitDefaults(new List<QuickAction.QuickActionDefaults>());
    }

    @IsTest
    static void onInitDefaults_skipsNullEntries() {
        CaseEmailDefaultsHandler h = new CaseEmailDefaultsHandler();
        h.onInitDefaults(new List<QuickAction.QuickActionDefaults>{ null });
    }

    @IsTest
    static void resolveFromAddress_returnsNullForBlankOrUnknown() {
        System.assertEquals(null, CaseEmailDefaultsHandler.resolveFromAddress(null));
        System.assertEquals(null, CaseEmailDefaultsHandler.resolveFromAddress(''));
        System.assertEquals(null, CaseEmailDefaultsHandler.resolveFromAddress('   '));
        System.assertEquals(null, CaseEmailDefaultsHandler.resolveFromAddress('Unknown Company'));
    }

    @IsTest
    static void resolveFromAddress_knownCompanies() {
        System.assertEquals('info@investire.biz', CaseEmailDefaultsHandler.resolveFromAddress('Investire.biz'));
        System.assertEquals('info@forecaster.biz', CaseEmailDefaultsHandler.resolveFromAddress('Forecaster.biz'));
        System.assertEquals('info@itcup.it', CaseEmailDefaultsHandler.resolveFromAddress('It Cup'));
        System.assertEquals('info@itcup.it', CaseEmailDefaultsHandler.resolveFromAddress('  It Cup  '));
    }

    @IsTest
    static void applyDefaults_noOpWhenNullInputs() {
        EmailMessage em = new EmailMessage();
        System.assertEquals(null, CaseEmailDefaultsHandler.applyDefaults(null, em));

        Case c = new Case(Subject = 't', Status = 'New', Origin = 'Email');
        insert c;
        System.assertEquals(null, CaseEmailDefaultsHandler.applyDefaults(c.Id, null));
    }

    @IsTest
    static void applyDefaults_returnsFrom_investire() {
        Case c = new Case(
            Subject = 't',
            Status = 'New',
            Origin = 'Email',
            Company__c = 'Investire.biz'
        );
        insert c;

        Case row = [SELECT Company__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            'info@investire.biz',
            CaseEmailDefaultsHandler.resolveFromAddress(row.Company__c),
            'Company__c on Case must match picklist value exactly after insert. Got: [' + row.Company__c + ']'
        );

        EmailMessage em = new EmailMessage();
        System.assertEquals('info@investire.biz', CaseEmailDefaultsHandler.applyDefaults(row.Id, em));
    }

    @IsTest
    static void applyDefaults_returnsFrom_forecaster() {
        Case c = new Case(
            Subject = 't',
            Status = 'New',
            Origin = 'Email',
            Company__c = 'Forecaster.biz'
        );
        insert c;

        Case row = [SELECT Company__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            'info@forecaster.biz',
            CaseEmailDefaultsHandler.resolveFromAddress(row.Company__c),
            'Company__c on Case must match picklist value exactly after insert. Got: [' + row.Company__c + ']'
        );

        EmailMessage em = new EmailMessage();
        System.assertEquals('info@forecaster.biz', CaseEmailDefaultsHandler.applyDefaults(row.Id, em));
    }

    @IsTest
    static void applyDefaults_returnsFrom_itCup() {
        Case c = new Case(
            Subject = 't',
            Status = 'New',
            Origin = 'Email',
            Company__c = 'It Cup'
        );
        insert c;

        Case row = [SELECT Company__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            'info@itcup.it',
            CaseEmailDefaultsHandler.resolveFromAddress(row.Company__c),
            'Company__c on Case must match picklist value exactly after insert. Got: [' + row.Company__c + ']'
        );

        EmailMessage em = new EmailMessage();
        System.assertEquals('info@itcup.it', CaseEmailDefaultsHandler.applyDefaults(row.Id, em));
    }
}

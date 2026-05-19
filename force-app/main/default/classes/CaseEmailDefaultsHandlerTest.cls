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
    }

    @IsTest
    static void applyDefaults_noOpWhenNullInputs() {
        EmailMessage em = new EmailMessage();
        CaseEmailDefaultsHandler.applyDefaults(null, em);

        Case c = new Case(Subject = 't', Status = 'New', Origin = 'Email');
        insert c;
        CaseEmailDefaultsHandler.applyDefaults(c.Id, null);
    }

    @IsTest
    static void applyDefaults_setsValidatedFromAddress_investire() {
        Case c = new Case(
            Subject = 't',
            Status = 'New',
            Origin = 'Email',
            Company__c = 'Investire.biz'
        );
        insert c;

        EmailMessage em = new EmailMessage();
        CaseEmailDefaultsHandler.applyDefaults(c.Id, em);
        System.assertEquals('info@investire.biz', em.ValidatedFromAddress);
    }

    @IsTest
    static void applyDefaults_setsValidatedFromAddress_forecaster() {
        Case c = new Case(
            Subject = 't',
            Status = 'New',
            Origin = 'Email',
            Company__c = 'Forecaster.biz'
        );
        insert c;

        EmailMessage em = new EmailMessage();
        CaseEmailDefaultsHandler.applyDefaults(c.Id, em);
        System.assertEquals('info@forecaster.biz', em.ValidatedFromAddress);
    }

    @IsTest
    static void applyDefaults_setsValidatedFromAddress_itCup() {
        Case c = new Case(
            Subject = 't',
            Status = 'New',
            Origin = 'Email',
            Company__c = 'It Cup'
        );
        insert c;

        EmailMessage em = new EmailMessage();
        CaseEmailDefaultsHandler.applyDefaults(c.Id, em);
        System.assertEquals('info@itcup.it', em.ValidatedFromAddress);
    }

    @IsTest
    static void applyDefaults_leavesFromNullWhenCompanyUnknown() {
        Case c = new Case(Subject = 't', Status = 'New', Origin = 'Email');
        insert c;

        EmailMessage em = new EmailMessage();
        CaseEmailDefaultsHandler.applyDefaults(c.Id, em);
        System.assertEquals(null, em.ValidatedFromAddress);
    }
}

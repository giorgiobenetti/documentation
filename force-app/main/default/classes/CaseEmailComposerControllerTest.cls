@IsTest
private class CaseEmailComposerControllerTest {
    @IsTest
    static void getComposerDefaults_throwsWhenCaseIdMissing() {
        try {
            CaseEmailComposerController.getComposerDefaults(null, null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('Case Id'));
        }
    }

    @IsTest
    static void getComposerDefaults_throwsWhenSuppliedEmailMissing() {
        Case c = new Case(Subject = 'Unit test case', Status = 'New', Origin = 'Email');
        insert c;

        try {
            CaseEmailComposerController.getComposerDefaults(c.Id, null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('SuppliedEmail'));
        }
    }

    @IsTest
    static void getComposerDefaults_throwsWhenCompanyMissing() {
        Case c = new Case(
            Subject = 'Unit test case',
            SuppliedEmail = 'customer@example.com',
            Status = 'New',
            Origin = 'Email'
        );
        insert c;

        try {
            CaseEmailComposerController.getComposerDefaults(c.Id, null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('Company__c'));
        }
    }
}

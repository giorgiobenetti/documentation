@IsTest
private class CaseEmailComposerControllerTest {
    @IsTest
    static void testThrowsWhenCaseIdMissing() {
        try {
            CaseEmailComposerController.getComposerDefaults(null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('Case Id'), 'Expected Case Id message');
        }
    }

    @IsTest
    static void testThrowsWhenSuppliedEmailMissing() {
        Case c = new Case(Subject = 'Unit test case', Status = 'New', Origin = 'Email');
        insert c;

        try {
            CaseEmailComposerController.getComposerDefaults(c.Id, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('SuppliedEmail'), 'Expected SuppliedEmail message');
        }
    }

    @IsTest
    static void testThrowsWhenCompanyMissing() {
        Case c = new Case(
            Subject = 'Unit test case',
            SuppliedEmail = 'customer@example.com',
            Status = 'New',
            Origin = 'Email'
        );
        insert c;

        try {
            CaseEmailComposerController.getComposerDefaults(c.Id, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('Company__c'), 'Expected Company__c message');
        }
    }
}

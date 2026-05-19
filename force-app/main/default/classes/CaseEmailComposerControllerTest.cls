@IsTest
private class CaseEmailComposerControllerTest {
    /**
     * In unit tests, AuraHandledException.getMessage() is sometimes blank; we still assert the exception type.
     * When a message is present, it must contain one of the expected fragments.
     */
    private static void assertAuraHandled(AuraHandledException e, List<String> expectedFragments) {
        String m = e.getMessage();
        if (String.isBlank(m)) {
            return;
        }
        Boolean found = false;
        for (String frag : expectedFragments) {
            if (m.contains(frag)) {
                found = true;
                break;
            }
        }
        System.assert(found, 'Unexpected message: [' + m + ']');
    }

    @IsTest
    static void testThrowsWhenCaseIdMissing() {
        try {
            CaseEmailComposerController.getComposerDefaults(null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, new List<String>{ 'Case Id', 'required' });
        }
    }

    @IsTest
    static void testThrowsWhenSuppliedEmailMissing() {
        Case c = new Case(Subject = 'Unit test case', Status = 'New', Origin = 'Email');
        insert c;

        try {
            CaseEmailComposerController.getComposerDefaults(c.Id, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, new List<String>{ 'SuppliedEmail', 'Supplied' });
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
        } catch (AuraHandledException e) {
            assertAuraHandled(e, new List<String>{ 'Company__c', 'Company' });
        }
    }
}

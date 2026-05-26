global class CaseEmailDefaultsHandler implements QuickAction.QuickActionDefaultsHandler {
    global void onInitDefaults(QuickAction.QuickActionDefaults[] defaultsList) {
        if (defaultsList == null) {
            return;
        }

        if (defaultsList.isEmpty()) {
            return;
        }

        for (QuickAction.QuickActionDefaults defaults : defaultsList) {
            if (defaults == null) {
                continue;
            }

            if (!(defaults instanceof QuickAction.SendEmailQuickActionDefaults)) {
                continue;
            }

            if (defaults.getTargetSObject() == null) {
                continue;
            }

            if (defaults.getTargetSObject().getSObjectType() != EmailMessage.sObjectType) {
                continue;
            }

            EmailMessage emailMessage = (EmailMessage) defaults.getTargetSObject();

            Id contextId = defaults.getContextId();

            if (contextId == null) {
                continue;
            }

            applyDefaults(contextId, emailMessage);
        }
    }

    @TestVisible
    public static String applyDefaults(Id caseId, EmailMessage emailMessage) {
        if (caseId == null || emailMessage == null) {
            return null;
        }

        Case c = [
            SELECT Id, Company__c, SuppliedEmail, Subject
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        String fromAddress = resolveFromAddress(c.Company__c);

        if (fromAddress != null) {
            emailMessage.ValidatedFromAddress = fromAddress;
        }
        return fromAddress;
    }

    @TestVisible
    public static String resolveFromAddress(String company) {
        if (String.isBlank(company)) {
            return null;
        }

        String key = company.trim();

        if (key == 'Investire.biz') {
            return 'info@investire.biz';
        }

        if (key == 'Forecaster.biz') {
            return 'info@forecaster.biz';
        }

        if (key == 'It Cup') {
            return 'info@itcup.it';
        }

        return null;
    }
}

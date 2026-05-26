/**
 * Prepares default values for the standard Case Send Email quick action (Lightning composer).
 * Mapping rows live in Custom Metadata Type Reply_Email_Mapping__mdt.
 */
public without sharing class CaseEmailComposerController {
    public static final String COMPANY_FORECASTER = 'Forecaster.biz';

    /**
     * Serializable defaults for the Lightning email quick action (encodeDefaultFieldValues).
     */
    public class ComposerDefaults {
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
    }

    /**
     * Loads Case data, resolves template + org-wide From mapping, and returns merged HTML for the composer.
     * @param caseId Case record Id
     * @param languageCode For Forecaster.biz only: {@code IT} or {@code EN}; otherwise null
     */
    @AuraEnabled
    public static ComposerDefaults getComposerDefaults(Id caseId, String languageCode) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }

        Case c = [
            SELECT Id, Company__c, SuppliedEmail, Subject
            FROM Case
            WHERE Id = :caseId
            WITH USER_MODE
            LIMIT 1
        ];

        if (String.isBlank(c.SuppliedEmail)) {
            throw new AuraHandledException('Case.SuppliedEmail is empty. Cannot pre-fill the To address.');
        }
        if (String.isBlank(c.Company__c)) {
            throw new AuraHandledException('Case.Company__c is empty. Select the company before replying.');
        }

        Boolean isForecaster = COMPANY_FORECASTER.equalsIgnoreCase(c.Company__c.trim());
        if (isForecaster && String.isBlank(languageCode)) {
            throw new AuraHandledException('LANGUAGE_REQUIRED');
        }

        String companyKey = c.Company__c.trim();
        Reply_Email_Mapping__mdt mapping = resolveMapping(companyKey, isForecaster, languageCode);

        EmailTemplate template = [
            SELECT Id, DeveloperName, TemplateType
            FROM EmailTemplate
            WHERE DeveloperName = :mapping.Template_Developer_Name__c AND IsActive = TRUE
            WITH USER_MODE
            LIMIT 1
        ];

        if (!isSupportedClassicTemplate(template.TemplateType)) {
            throw new AuraHandledException(
                'Template "' +
                    mapping.Template_Developer_Name__c +
                    '" has type "' +
                    template.TemplateType +
                    '". Use a Classic template (text, html, custom, or visualforce). Lightning Email Templates are not supported by this merge path.'
            );
        }

        Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(
            String.valueOf(template.Id),
            null,
            String.valueOf(c.Id)
        );

        String mergedBody = rendered.getHtmlBody();
        if (String.isBlank(mergedBody)) {
            String plain = rendered.getPlainTextBody();
            mergedBody = String.isBlank(plain)
                ? '<p></p>'
                : '<pre>' + escapeHtml(plain) + '</pre>';
        }

        ComposerDefaults out = new ComposerDefaults();
        out.fromAddress = mapping.From_Address__c != null ? mapping.From_Address__c.trim() : null;
        out.toAddress = c.SuppliedEmail.trim();
        out.subject = buildReplySubject(c.Subject, rendered.getSubject());
        out.htmlBody = mergedBody;
        return out;
    }

    private static Boolean isSupportedClassicTemplate(String templateType) {
        if (String.isBlank(templateType)) {
            return true;
        }
        String t = templateType.toLowerCase();
        return t == 'text' || t == 'html' || t == 'custom' || t == 'visualforce';
    }

    private static Reply_Email_Mapping__mdt resolveMapping(String companyPicklistValue, Boolean isForecaster, String languageCode) {
        String company = companyPicklistValue.trim();

        if (isForecaster) {
            String lang = languageCode.trim();
            // NOPMD(ApexCRUDViolation) - Custom Metadata is subscriber configuration
            List<Reply_Email_Mapping__mdt> rows = [
                SELECT DeveloperName, Picklist_Value__c, From_Address__c, Template_Developer_Name__c, Language_Code__c
                FROM Reply_Email_Mapping__mdt
                WHERE Picklist_Value__c = :company AND Language_Code__c != NULL AND Language_Code__c != ''
            ];
            for (Reply_Email_Mapping__mdt row : rows) {
                if (row.Language_Code__c != null && row.Language_Code__c.trim().equalsIgnoreCase(lang)) {
                    return row;
                }
            }
            throw new AuraHandledException(
                'No Reply_Email_Mapping__mdt row found for Forecaster language "' + languageCode + '".'
            );
        }

        // NOPMD(ApexCRUDViolation) - Custom Metadata is subscriber configuration
        List<Reply_Email_Mapping__mdt> defaultRows = [
            SELECT DeveloperName, Picklist_Value__c, From_Address__c, Template_Developer_Name__c, Language_Code__c
            FROM Reply_Email_Mapping__mdt
            WHERE Picklist_Value__c = :company AND (Language_Code__c = NULL OR Language_Code__c = '')
        ];

        if (defaultRows.isEmpty()) {
            throw new AuraHandledException(
                'No Reply_Email_Mapping__mdt default row (blank Language) for Company "' +
                    company +
                    '". Check Picklist_Value__c matches the Case picklist API value exactly.'
            );
        }
        if (defaultRows.size() > 1) {
            throw new AuraHandledException(
                'Multiple default Reply_Email_Mapping__mdt rows (blank Language) for Company "' +
                    company +
                    '". Leave exactly one row per company with blank Language_Code__c.'
            );
        }
        return defaultRows[0];
    }

    private static String buildReplySubject(String caseSubject, String templateSubject) {
        String base = String.isNotBlank(caseSubject) ? caseSubject : templateSubject;
        if (String.isBlank(base)) {
            return 'RE: ';
        }
        String trimmed = base.trim();
        if (trimmed.length() >= 3 && trimmed.substring(0, 3).equalsIgnoreCase('re:')) {
            return trimmed;
        }
        return 'RE: ' + trimmed;
    }

    private static String escapeHtml(String input) {
        if (input == null) {
            return '';
        }
        return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }
}

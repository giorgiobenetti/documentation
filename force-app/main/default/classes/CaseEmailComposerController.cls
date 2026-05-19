/**
 * Prepares default values for the standard Case Send Email quick action (Lightning composer).
 * Mapping rows live in Custom Metadata Type Reply_Email_Mapping__mdt.
 */
public with sharing class CaseEmailComposerController {
    public static final String COMPANY_FORECASTER = 'Forecaster.biz';

    public class ComposerDefaults {
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
    }

    @AuraEnabled
    public static ComposerDefaults getComposerDefaults(Id caseId, String languageCode) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }

        Case c = [
            SELECT Id, Company__c, SuppliedEmail, Subject
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
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

        Reply_Email_Mapping__mdt mapping = resolveMapping(c.Company__c, isForecaster, languageCode);

        EmailTemplate template = [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName = :mapping.Template_Developer_Name__c AND IsActive = TRUE
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

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
        out.fromAddress = mapping.From_Address__c;
        out.toAddress = c.SuppliedEmail.trim();
        out.subject = buildReplySubject(c.Subject, rendered.getSubject());
        out.htmlBody = mergedBody;
        return out;
    }

    private static Reply_Email_Mapping__mdt resolveMapping(String companyPicklistValue, Boolean isForecaster, String languageCode) {
        List<Reply_Email_Mapping__mdt> rows = [
            SELECT From_Address__c, Template_Developer_Name__c, Language_Code__c
            FROM Reply_Email_Mapping__mdt
            WHERE Picklist_Value__c = :companyPicklistValue
        ];

        if (rows.isEmpty()) {
            throw new AuraHandledException(
                'No Reply_Email_Mapping__mdt row found for Company "' + companyPicklistValue + '".'
            );
        }

        if (isForecaster) {
            String lang = languageCode.trim();
            for (Reply_Email_Mapping__mdt row : rows) {
                if (row.Language_Code__c != null && row.Language_Code__c.equalsIgnoreCase(lang)) {
                    return row;
                }
            }
            throw new AuraHandledException(
                'No Reply_Email_Mapping__mdt row found for Forecaster language "' + languageCode + '".'
            );
        }

        for (Reply_Email_Mapping__mdt row : rows) {
            if (String.isBlank(row.Language_Code__c)) {
                return row;
            }
        }

        throw new AuraHandledException(
            'No default (blank language) Reply_Email_Mapping__mdt row found for Company "' +
                companyPicklistValue +
                '".'
        );
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

import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import CASE_COMPANY from '@salesforce/schema/Case.Company__c';
import CASE_SUPPLIED_EMAIL from '@salesforce/schema/Case.SuppliedEmail';

import getComposerDefaults from '@salesforce/apex/CaseEmailComposerController.getComposerDefaults';

const CASE_FIELDS = [CASE_COMPANY, CASE_SUPPLIED_EMAIL];
const FORECASTER = 'Forecaster.biz';
/** Adjust if your org renames the standard Send Email quick action. */
const CASE_SEND_EMAIL_QUICK_ACTION = 'Case.SendEmail';

export default class CaseSmartReplyButton extends NavigationMixin(LightningElement) {
    @api recordId;

    showLangModal = false;
    busy = false;

    caseWire;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase(value) {
        this.caseWire = value;
    }

    get companyValue() {
        const data = this.caseWire?.data;
        return data ? getFieldValue(data, CASE_COMPANY) : null;
    }

    get isForecaster() {
        const c = (this.companyValue || '').trim();
        return c.localeCompare(FORECASTER, undefined, { sensitivity: 'accent' }) === 0;
    }

    handleOpenClick() {
        const err = this.validateCaseWire();
        if (err) {
            this.toastError(err);
            return;
        }
        if (this.isForecaster) {
            this.showLangModal = true;
            return;
        }
        this.openComposer(null);
    }

    handleLanguageIt() {
        this.showLangModal = false;
        this.openComposer('IT');
    }

    handleLanguageEn() {
        this.showLangModal = false;
        this.openComposer('EN');
    }

    handleCloseModal() {
        this.showLangModal = false;
    }

    validateCaseWire() {
        if (!this.recordId) {
            return 'Record Id mancante: aggiungi il componente alla pagina record del Case.';
        }
        if (this.caseWire?.loading) {
            return 'Caricamento Case in corso, riprova tra un attimo.';
        }
        if (this.caseWire?.error) {
            return this.reduceErrors(this.caseWire.error).join('; ');
        }
        const email = getFieldValue(this.caseWire.data, CASE_SUPPLIED_EMAIL);
        if (!email) {
            return 'Il Case non ha SuppliedEmail (mittente originale).';
        }
        const company = getFieldValue(this.caseWire.data, CASE_COMPANY);
        if (!company) {
            return 'Seleziona Company__c sul Case prima di rispondere.';
        }
        return null;
    }

    async openComposer(languageCode) {
        const err = this.validateCaseWire();
        if (err) {
            this.toastError(err);
            return;
        }

        this.busy = true;
        try {
            const defaults = await getComposerDefaults({
                caseId: this.recordId,
                languageCode: languageCode || null
            });

            const defaultFieldValues = encodeDefaultFieldValues({
                FromAddress: defaults.fromAddress,
                ToAddress: defaults.toAddress,
                Subject: defaults.subject,
                HTMLBody: defaults.htmlBody,
                RelatedToId: this.recordId
            });

            this[NavigationMixin.Navigate]({
                type: 'standard__quickAction',
                attributes: {
                    apiName: CASE_SEND_EMAIL_QUICK_ACTION
                },
                state: {
                    recordId: this.recordId,
                    defaultFieldValues
                }
            });
        } catch (e) {
            const message = this.reduceErrors(e).join('; ') || 'Errore imprevisto.';
            this.toastError(message);
        } finally {
            this.busy = false;
        }
    }

    toastError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Impossibile aprire il composer',
                message,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }

    reduceErrors(error) {
        if (!error) {
            return [];
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message);
        }
        if (error.body && Array.isArray(error.body.output?.errors)) {
            return error.body.output.errors.map((e) => e.message);
        }
        if (error.body && typeof error.body.message === 'string') {
            return [error.body.message];
        }
        if (typeof error.message === 'string') {
            return [error.message];
        }
        return [String(error)];
    }
}

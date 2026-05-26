# Case: risposta email guidata (Email-to-Case)

Questo pacchetto aggiunge un pulsante Lightning sulla pagina record del **Case** che apre il **composer email nativo** (azione standard **Send Email**) con:

- **From** precompilato (stringa che deve coincidere con l’indirizzo Org-Wide Email visibile nel composer)
- **To** = `Case.SuppliedEmail`
- **Subject** = `RE:` + `Case.Subject` (se l’oggetto non inizia già con `RE:`)
- **Body HTML** = merge del **Classic Email Template** scelto in base a `Case.Company__c` (e alla lingua per Forecaster.biz)

La mappatura è configurabile senza codice tramite **Custom Metadata** `Reply_Email_Mapping__mdt`.

## Prerequisiti in org

- Lightning Experience.
- Campo **Case.Company__c** (picklist) con valori esattamente: `Investire.biz`, `Forecaster.biz`, `It Cup` (se usi altre etichette, aggiorna i record MDT `Picklist_Value__c`).
- **Email-to-Case** e indirizzi **Org-Wide Email** già allineati alle tre caselle.
- Template email **Classic** attivi; aggiorna `Template_Developer_Name__c` nei record MDT con i **Developer Name** reali (sostituisci i placeholder `REPLACE_*` distribuiti con il sorgente).
- Gli utenti devono poter **leggere** Case (campi usati), **EmailTemplate** attivi usati in merge, e avere accesso all’azione **Send Email** sul Case.

## Deploy (Salesforce CLI)

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

### Deploy solo questa funzionalità (consigliato se il progetto contiene altro)

Puoi rilasciare **solo** Apex, LWC, Custom Metadata e permission set del Case email usando il manifest:

```bash
sf project deploy start --manifest manifest/package-case-email-reply-only.xml --target-org <alias>
```

In alternativa, dalla root del progetto, punta a **una cartella** (es. solo un LWC dopo una modifica):

```bash
sf project deploy start --source-dir force-app/main/default/lwc/caseSmartReplyButton --target-org <alias>
```

Regola pratica: se deployi **solo** il bundle LWC, l’Apex controller deve **già esistere** nell’org (o va deployato nello stesso changeset / nello stesso comando). Stesso discorso per i record **Custom Metadata** e il **tipo** MDT.

Assegna il permission set **Case Smart Email Reply** agli agenti (oltre ai permessi Case/email già previsti).

## Pagina Lightning

1. **Setup** → **Lightning App Builder** → apri la pagina record **Case** usata dal team.
2. Trascina il componente **Case Smart Reply** in una sezione visibile (es. barra laterale o tab).
3. Salva e **Attiva** per l’app Service / Sales usata dagli agenti.

## Azione Send Email (API name)

Il componente naviga verso `standard__quickAction` con `apiName: Case.SendEmail`. Se in Setup → **Object Manager** → **Case** → **Buttons, Links, and Actions** l’azione **Send Email** ha un nome API diverso (es. `Send_Email`), modifica la costante `CASE_SEND_EMAIL_QUICK_ACTION` in `caseSmartReplyButton.js` e ridistribuisci.

## Layout dell’azione Send Email

I valori predefiniti da LWC rispettano i campi documentati per `encodeDefaultFieldValues` (`FromAddress`, `ToAddress`, `Subject`, `HtmlBody` / `HTMLBody`, `RelatedToId`). Se un campo risulta **sola lettura** nel layout dell’azione email, Salesforce **ignora** i valori passati: in particolare **Subject** e **corpo** non si precompilano. In Setup apri il layout dell’azione **Send Email** sul Case e assicurati che **From**, **To**, **Subject** e **Body** siano **modificabili** (non Read-Only). Vedi anche la guida Salesforce sugli attributi dell’azione email.

Nel LWC usiamo la chiave **`HtmlBody`** (come negli esempi ufficiali) e azzeriamo **Cc/Bcc** espliciti per evitare che restino valori “appiccicati” dal composer precedente.

## Forecaster.biz: lingua

Per `Company__c = Forecaster.biz` il pulsante mostra prima la scelta **Italiano** / **English**; la lingua selezionata (`IT` o `EN`) determina quale riga MDT viene usata (template IT vs EN).

## Limiti noti

- Corpi HTML molto grandi possono superare i limiti del meccanismo di default values: in quel caso valuta template più leggeri o invii via Flow.
- Il merge usa `Messaging.renderStoredEmailTemplate` con `whatId` = Case: i merge field del template devono essere compatibili con il Case come **Related To**.

## Test Apex

La classe di test copre i messaggi di errore principali quando mancano `SuppliedEmail` o `Company__c`. I percorsi “felici” dipendono da picklist, template e MDT presenti nell’org: estendi i test in org se serve coverage aggiuntiva.

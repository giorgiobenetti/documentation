# Deploy nel sandbox Salesforce

Questa guida usa la **Salesforce CLI** (`sf`). I metadati sono nella cartella `force-app` alla root del repository.

## 1. Installare la CLI (sul tuo PC o CI)

```bash
npm install -g @salesforce/cli
sf --version
```

(Alternativa ufficiale: pacchetti installer da [Install the Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli).)

## 2. Collegare il sandbox (una tantum)

I sandbox usano l’URL **test**:

```bash
sf org login web --instance-url https://test.salesforce.com --alias MIO_SANDBOX
```

Si apre il browser: accedi con le credenziali del sandbox e autorizza.  
Per vedere gli org collegati:

```bash
sf org list
```

Se preferisci **JWT** (CI o senza browser), segui la documentazione Salesforce “Authorize an Org Using the JWT Flow”.

## 3. Deploy dei metadati

Dalla root del repo (dove c’è `sfdx-project.json`):

```bash
sf project deploy start --source-dir force-app --target-org MIO_SANDBOX
```

Deploy più rapido se l’org richiede test Apex ma vuoi limitarti alla classe del progetto:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org MIO_SANDBOX \
  --test-level RunSpecifiedTests \
  --tests CaseEmailComposerControllerTest
```

Solo in ambienti di sviluppo dove le policy lo consentono (sconsigliato verso produzione):

```bash
sf project deploy start --source-dir force-app --target-org MIO_SANDBOX --test-level NoTestRun
```

In caso di errori, riesegui con `--verbose` o apri il report:

```bash
sf project deploy report --job-id <ID> --target-org MIO_SANDBOX
```

## 4. Dopo il deploy (Setup in org)

1. **Custom Metadata**  
   In **Setup** → cerca **Custom Metadata Types** → **Reply Email Mapping** → apri i record e sostituisci `REPLACE_*` in **Email Template Developer Name** con i Developer Name reali dei template Classic.  
   Verifica che **From Address** coincida con l’indirizzo Org-Wide mostrato nel composer.

2. **Permission set**  
   **Setup** → **Permission Sets** → **Case Smart Email Reply** → **Manage Assignments** → assegna agli utenti del supporto.

3. **Pagina Case**  
   **Lightning App Builder** sulla pagina record **Case** → aggiungi il componente **Case Smart Reply** → Salva e Attiva.

4. **Send Email**  
   Se il composer non si apre, in **Object Manager** → **Case** → **Buttons, Actions, and Actions** controlla il **nome API** dell’azione *Send Email* e allinea la costante `CASE_SEND_EMAIL_QUICK_ACTION` in `caseSmartReplyButton.js` se diverso da `Case.SendEmail`.

## 5. Problemi frequenti

| Sintomo | Cosa controllare |
|--------|-------------------|
| Deploy fallisce su `Case.Company__c` / LWC | Il campo deve esistere sul Case nel sandbox (stesso API name `Company__c`). |
| Errore sui test obbligatori | Usa `RunSpecifiedTests` come sopra, oppure correggi i test richiesti dalle policy dell’org. |
| Toast “template merge failed” | Developer name del template errato o template non attivo; merge field non validi sul Case. |
| From / To vuoti nel composer | Campi in sola lettura nel layout dell’azione Send Email; `From_Address__c` non coincide con l’OWA. |

## Script opzionale

Dalla root del repo:

```bash
chmod +x scripts/deploy-salesforce-sandbox.sh
./scripts/deploy-salesforce-sandbox.sh MIO_SANDBOX
```

Esegue il deploy con `RunSpecifiedTests` sulla classe di test del progetto.

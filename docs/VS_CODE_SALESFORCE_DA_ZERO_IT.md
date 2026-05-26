# Salesforce in VS Code da zero (Windows / macOS / Linux)

Guida per aprire o creare un **progetto Salesforce (SFDX)** in Visual Studio Code, collegare un **sandbox** e fare il **deploy** dei metadati (es. cartella `force-app` di questo repository).

---

## Cosa installeremo

1. **Visual Studio Code** (editor)
2. **Salesforce CLI** (`sf` nel terminale)
3. Estensione **Salesforce Extension Pack** (in VS Code)

Opzionale ma consigliato per Apex/LSP stabile: **Java 17** (JDK), richiesto dall’estensione Apex se lavori molto su Apex.

---

## Passo 1 — Installare VS Code

1. Scarica VS Code da: https://code.visualstudio.com/
2. Installa e avvia VS Code.

**Verifica:** si apre la finestra principale senza errori.

---

## Passo 2 — Installare la Salesforce CLI (`sf`)

Apri un **terminale** (fuori da VS Code va bene; su Windows “Prompt dei comandi” o PowerShell).

```bash
sf --version
```

- Se vedi un numero di versione, la CLI è già installata → vai al **Passo 3**.
- Se il comando non esiste:

**Con Node.js (consigliato se hai già Node):**

```bash
npm install -g @salesforce/cli
sf --version
```

**Oppure** usa l’installer ufficiale per il tuo sistema operativo:  
https://developer.salesforce.com/tools/salesforcecli  

**Verifica:** `sf --version` stampa una versione (es. `@salesforce/cli/2.x`).

---

## Passo 3 — Estensioni Salesforce in VS Code

1. In VS Code apri il pannello **Extensions** (icona quadrati a sinistra o `Ctrl+Shift+X` / `Cmd+Shift+X`).
2. Cerca **Salesforce Extension Pack** (publisher: Salesforce).
3. Clicca **Install**.

**Verifica:** nella barra laterale compare l’icona Salesforce (fulmine); nel **Command Palette** (`Ctrl+Shift+P` / `Cmd+Shift+P`) compaiono comandi che iniziano con **SFDX:** o **Salesforce**.

---

## Passo 4 — Ottenere il codice del progetto

Hai due strade equivalenti; scegline **una**.

### Opzione A — Cloni questo repository (consigliato se usi già Git)

1. Installa **Git** se non ce l’hai: https://git-scm.com/
2. Nel terminale:

```bash
cd <cartella-dove-tieni-i-progetti>
git clone <URL-del-tuo-repo>
cd documentation
```

3. In VS Code: **File → Open Folder** e seleziona la cartella `documentation` (deve contenere `sfdx-project.json` e `force-app`).

### Opzione B — Nuovo progetto vuoto + copia manuale

1. Terminale:

```bash
cd <cartella-dove-tieni-i-progetti>
sf project generate --name mio-progetto-salesforce
code mio-progetto-salesforce
```

2. Copia dentro la cartella del progetto la directory **`force-app`** (e il file **`sfdx-project.json`**) dal repository che contiene la soluzione Case email, in modo che la root del progetto in VS Code abbia:

- `sfdx-project.json`
- `force-app/main/default/...`

---

## Passo 5 — Collegare il sandbox a VS Code

1. In VS Code apri il **Command Palette**: `Ctrl+Shift+P` (Windows/Linux) o `Cmd+Shift+P` (macOS).
2. Esegui: **SFDX: Authorize an Org** (o **Salesforce: Authorize an Org**, a seconda della versione dell’estensione).
3. Scegli **Project Default** (o equivalente).
4. Scegli **Sandbox** (URL `https://test.salesforce.com`).
5. Assegna un **alias** (es. `mio-sandbox`).
6. Si apre il browser: accedi al sandbox e autorizza.

**Verifica:** in basso a sinistra in VS Code compare l’alias dell’org selezionato; oppure nel terminale:

```bash
sf org list
```

Vedi il sandbox con **Connected** (o stato equivalente).

---

## Passo 6 — Deploy dei metadati verso il sandbox

### Da terminale (sempre valido)

Dalla **root del progetto** (dove c’è `sfdx-project.json`):

```bash
sf project deploy start --source-dir force-app --target-org mio-sandbox
```

(Sostituisci `mio-sandbox` con l’alias scelto al passo 5.)

Con test mirati (se l’org lo richiede e vuoi andare veloce):

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org mio-sandbox \
  --test-level RunSpecifiedTests \
  --tests CaseEmailComposerControllerTest
```

### Da VS Code (UI)

1. Nel **Explorer**, tasto destro sulla cartella **`force-app`** (o su `manifest/package.xml` se in futuro ne usi uno).
2. Scegli **SFDX: Deploy Source to Org** (o voce equivalente “Deploy to Org” nel menu contestuale Salesforce).

Se non vedi il comando, usa il **Command Palette** e cerca **Deploy**.

---

## Passo 7 — Dopo il primo deploy (in Salesforce Setup)

1. **Custom Metadata** `Reply Email Mapping`: aggiorna i Developer Name dei template (rimuovi i `REPLACE_*`).
2. **Permission Set** `Case Smart Email Reply`: assegnalo agli utenti.
3. **Lightning App Builder** sulla pagina **Case**: aggiungi il componente **Case Smart Reply**.

Dettagli: `docs/CASE_SMART_EMAIL_REPLY.md` e `docs/DEPLOY_SANDBOX_IT.md`.

---

## Problemi frequenti

| Problema | Cosa fare |
|----------|-----------|
| `sf` non trovato dopo `npm install -g` | Chiudi e riapri il terminale; verifica che la cartella globale `npm` sia nel `PATH`. |
| Authorize non apre il browser | Esegui da terminale: `sf org login web --instance-url https://test.salesforce.com --alias mio-sandbox` |
| Deploy fallisce per test | Usa `RunSpecifiedTests` come sopra o chiedi all’admin la policy test dell’org. |
| LWC riferisce `Case.Company__c` | Il campo deve esistere nel sandbox con lo stesso API name. |

---

## Come proseguire “assieme”

Rispondi indicando **dove sei bloccato** (es. “Passo 2, `sf` non si installa”) e incolla **l’errore completo** dal terminale o uno screenshot del messaggio in VS Code: si corregge il passo successivo in base a quello.

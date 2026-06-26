# Import Withdrawal Request (multi-mese)

Modulo VBA per importare un file `.xlsx` con un foglio per mese (es. `January 2026`) e produrre un output aggregato per **NAME**.

## Output (`Withdrawal_Output`)

| LOGIN | NAME | AMOUNT | PAYMENT DATE | TOTAL BALANCE |
|-------|------|--------|--------------|---------------|
| … | … | somma | data più recente | somma |

- **AMOUNT** e **TOTAL BALANCE**: sommati per nome sui mesi selezionati.
- **PAYMENT DATE**: la data più recente tra le righe dello stesso nome.
- **LOGIN**: primo login non vuoto trovato per quel nome.

## Regole di import

- Si leggono solo i fogli il cui nome contiene un mese inglese + anno (es. `January 2026`).
- Intestazioni cercate nella prima riga che contiene `LOGIN`, `NAME`, `AMOUNT` (prime ~25 righe).
- **Escluse le righe evidenziate** (sfondo colorato su qualsiasi cella della riga).
- Escluse righe con **NAME** vuoto.

## Installazione nel file Excel di lavoro

1. Apri il tuo file Excel destinazione (quello con il bottone).
2. `Alt+F11` → **File → Importa file…** → seleziona `WithdrawalImport.bas`.
3. Torna in Excel, foglio **Dashboard** (o dove preferisci):
   - **Inserisci → Moduli → Pulsante** (o forma con assegnazione macro).
   - Assegna la macro **`ImportWithdrawalRequests`**.
   - Etichetta suggerita: `Importa Withdrawal Request`.
4. **Debug → Compila VBAProject** (nessun errore).

## Utilizzo

1. Clic sul pulsante **Importa Withdrawal Request**.
2. Scegli il file sorgente `.xlsx`.
3. Nella finestra **Seleziona mesi**:
   - `1,2,3` = mesi 1, 2 e 3 dell’elenco
   - `1-3` = stesso intervallo
   - vuoto o `1-N` = tutti i mesi trovati
4. Controlla il foglio **`Withdrawal_Output`**.

## Note

- Se una riga evidenziata viene contata per errore, in Excel il colore di sfondo deve essere “Nessun riempimento” sulle celle usate; righe grigie/chiare di formattazione condizionale vengono escluse.
- Se le intestazioni del sorgente differiscono (es. typo `Counrty Office`), non influisce: si usano solo LOGIN, NAME, AMOUNT, Payment Date, Total Balance.

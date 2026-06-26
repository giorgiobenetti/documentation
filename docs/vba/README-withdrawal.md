# Import Withdrawal Request — con pulsante

## Setup (una volta sola)

1. Apri Excel → crea un nuovo file e **salvalo come `.xlsm`** (Excel con macro).
2. `Alt+F11` → **File → Importa file…** → `WithdrawalImport.bas`
3. `Alt+F8` → esegui **`SetupWithdrawalImportButton`**
4. Compare il foglio **Dashboard** con il pulsante **Importa Withdrawal Request**
5. Salva il file `.xlsm`

## Uso quotidiano

1. Apri il tuo file `.xlsm`
2. Foglio **Dashboard** → clic **Importa Withdrawal Request**
3. Scegli il file sorgente `.xlsx` (fogli tipo `January 2026`)
4. Seleziona i mesi: `1,2,3` oppure `1-6` (vuoto = tutti)
5. Output nel foglio **`Withdrawal_Output`**

## Colonne output

| LOGIN | NAME | AMOUNT | PAYMENT DATE | TOTAL BALANCE |

Aggregato per **NAME** (somma importi; data pagamento più recente).

## Regole

- Solo fogli con nome mese + anno (January … December + 20xx)
- **Escluse righe evidenziate** (sfondo colorato)
- Escluse righe senza NAME

## File nel repo

- Codice: `docs/vba/WithdrawalImport.bas`
- Branch: `cursor/withdrawal-import-139a`
- Link: https://github.com/giorgiobenetti/documentation/blob/cursor/withdrawal-import-139a/docs/vba/WithdrawalImport.bas

## Macro disponibili

| Macro | Cosa fa |
|-------|---------|
| `SetupWithdrawalImportButton` | Crea il pulsante (esegui 1 volta) |
| `ImportWithdrawalRequests` | Import (la lancia il pulsante) |

# FirstPromoter Stripe Historical Import Tool

Questa cartella contiene il modulo VBA importabile `FP_Import_Tool.bas` per un workbook Excel `.xlsm` con questi fogli:

1. `Exchange_Rates`
2. `Coupon_Map`
3. `Payments`
4. `Filter_Output`
5. `FP_Import_Log`

## Installazione nel workbook

1. Apri il file `.xlsm` in Excel per Windows.
2. Premi `ALT+F11` per aprire l'editor VBA.
3. Rimuovi o rinomina il vecchio modulo `FP_Import_Tool`.
4. Usa `File > Import File...` e importa `FP_Import_Tool.bas`. In alternativa, puoi copiare/incollare il contenuto in un modulo standard; in questo caso il file fornito non contiene righe `Attribute`, che in VBE causano errore di sintassi se incollate manualmente.
5. Imposta la costante `FP_API_KEY` nel modulo, ad esempio `Private Const FP_API_KEY As String = "sk_live_..."`.

## Correzioni incluse

- Accesso ai fogli tramite workbook corretto e ricerca case-insensitive sui nomi, evitando riferimenti globali a `Sheets`.
- Parser CSV BCE basato sulle intestazioni `TIME_PERIOD` e `OBS_VALUE`, con supporto per campi quotati.
- Conversione EUR/USD coerente con il tasso BCE `USD per 1 EUR`: importi USD convertiti in EUR con `amount / rate`; importi EUR lasciati invariati.
- Filtri indipendenti per `Already Paid` e `To Be Paid`, con righe verdi per pagati e gialle per da pagare.
- Invio FirstPromoter con importo in centesimi, `event_id` uguale all'id pagamento Stripe, URL encoding dei parametri e marcatura `Yes` in colonna 11 dopo risposte HTTP 2xx.

## Layout atteso

### `Payments`

Il modulo cerca le intestazioni nelle prime 10 righe. Se non le trova, usa il layout storico con dati dalla riga 4:

| Colonna | Campo |
| --- | --- |
| A | `id` |
| B | `Created date UTC` |
| C | `Converted Amount` |
| D | `Converted Amount Refunded` |
| E | `Converted Currency` |
| F | `Refunded date UTC` |
| G | `Customer Email` |
| H | `Dispute Date UTC` |

### `Filter_Output`

- `B4`: lista coupon separati da virgola, punto e virgola o nuova riga.
- `B5:D5`: intervallo `Already Paid`.
- `B6:D6`: intervallo `To Be Paid`.
- Output dalla riga 11, colonne `A:K`; la colonna `K` viene usata come stato importazione (`No`, `Yes`, `Error`).

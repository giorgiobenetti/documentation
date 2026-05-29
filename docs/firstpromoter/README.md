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
- Invio FirstPromoter con importo in centesimi, `event_id` uguale all'id pagamento Stripe, parametro query `promo_code` per attribuire la vendita al coupon FirstPromoter, URL encoding dei parametri, timeout HTTP espliciti e marcatura `Yes` in colonna 11 solo dopo risposta HTTP 200.

## Troubleshooting invio FirstPromoter

Se alcune righe risultano inviate ma non compaiono in FirstPromoter, controlla `FP_Import_Log`:

- `200` = vendita tracciata e commissione generata;
- `204` = nessun lead/referral trovato, quindi nessuna commissione generata;
- `409` = `event_id` duplicato, la vendita era gia stata inviata;
- `0` = errore HTTP/VBA prima di ricevere una risposta API.

La query inviata viene scritta in colonna H del log per verificare `promo_code`, `email`, `amount` ed `event_id`.

Se `SendToFirstPromoter` mostra `Operazione terminata`, la richiesta HTTP e stata interrotta da Excel/Windows/MSXML prima di ricevere una risposta API. La versione aggiornata usa `MSXML2.ServerXMLHTTP.6.0` e registra l'errore per singola riga in `FP_Import_Log` con stato `0`, invece di fermare tutto l'import.

In quel caso controlla:

- che la costante `FP_API_KEY` sia valorizzata;
- che il PC abbia accesso HTTPS a `https://firstpromoter.com`;
- la colonna risposta in `FP_Import_Log`, che conterra il dettaglio `VBA HTTP error ...`;
- eventuali proxy/firewall aziendali che interrompono le chiamate HTTPS da Excel/VBA.
- Se Excel segnala errori su `NumberFormat`, la formattazione e solo estetica: il modulo usa `SetNumberFormatSafe` per non bloccare l'import quando Excel non accetta un formato locale.
- Le scritture su log e colonna stato sono non bloccanti, cosi una cella protetta/formattata non interrompe l'invio gia effettuato.

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

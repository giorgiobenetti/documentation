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
5. Imposta la costante `FP_API_KEY` nel modulo usando la chiave corretta per la modalita API scelta.
   - API v2: usa la `API key` normale e imposta anche `FP_ACCOUNT_ID`.
   - API v1 legacy: usa la `Legacy API key` e lascia `FP_ACCOUNT_ID` vuoto.
6. Se il tuo account e FirstPromoter v2, imposta `FP_ACCOUNT_ID`; se resta vuota, il modulo usa la API legacy v1.

## Correzioni incluse

- Accesso ai fogli tramite workbook corretto e ricerca case-insensitive sui nomi, evitando riferimenti globali a `Sheets`.
- Parser CSV BCE basato sulle intestazioni `TIME_PERIOD` e `OBS_VALUE`, con supporto per campi quotati.
- Conversione EUR/USD coerente con il tasso BCE `USD per 1 EUR`: importi USD convertiti in EUR con `amount / rate`; importi EUR lasciati invariati.
- Filtri indipendenti per `Already Paid` e `To Be Paid`, con righe verdi per pagati e gialle per da pagare.
- Invio FirstPromoter con importo in centesimi, `event_id` uguale all'id pagamento Stripe e `promo_code` per attribuire la vendita al coupon FirstPromoter. Supporta API v1 con query string e `X-API-KEY`, oppure API v2 con JSON, `Authorization: Bearer` e `Account-ID`.

## Troubleshooting invio FirstPromoter

### Scelta API v1/v2

La documentazione FirstPromoter e divisa in due flussi:

- v1: `POST https://firstpromoter.com/api/v1/track/sale`, parametri in query string, header `X-API-KEY`, risposta `204` quando non viene trovata una referral sale.
- v2: `POST https://api.firstpromoter.com/api/v2/track/sale`, JSON body, header `Authorization: Bearer <API key>` e `Account-ID`, risposta `404` quando referral/promoter non vengono trovati.

Se stai usando la UI FirstPromoter v2 e la sezione Tracking Coupons, imposta `FP_ACCOUNT_ID` con l'Account ID indicato in Settings > Integrations e usa la `API key` normale, non la `Legacy API key`. Questo forza il modulo a usare la API v2.

### Verifica locale senza inviare

Usa `DiagnoseFirstPromoterSelectedRow` selezionando una riga in `Filter_Output`: la macro non invia nulla a FirstPromoter, ma verifica che id pagamento, data, email cliente, coupon, importo EUR e API key siano leggibili, poi mostra la query che verrebbe inviata.

Se alcune righe risultano inviate ma non compaiono in FirstPromoter, controlla `FP_Import_Log`:

- `200` = vendita tracciata e commissione generata;
- `2024` non e uno status HTTP FirstPromoter valido: se lo vedi come errore VBA/Excel, controlla in quale colonna viene scritto e usa `DiagnoseFirstPromoterSelectedRow`;
- `204` = v1: nessun lead/referral trovato, oppure `promo_code` non associato a un Tracking Coupon unico/attivo del promoter;
- `404` = v2: referral/promoter non trovato oppure promoter bannato;
- `409` = `event_id` duplicato, la vendita era gia stata inviata;
- `0` = errore HTTP/VBA prima di ricevere una risposta API.

`FP_Import_Log` viene compilato dalla riga 4 con queste colonne diagnostiche:

| Colonna | Contenuto |
| --- | --- |
| A | Timestamp |
| B | Riga in `Filter_Output` |
| C | Payment ID |
| D | Coupon / promo code |
| E | Importo EUR |
| F | HTTP status (`200`, `204`, `400`, `404`, `409`, `0`, ecc.) |
| G | Significato sintetico |
| H | Response API oppure errore VBA con stage |
| I | Payload inviato; in v1 query string, in v2 JSON |
| J | API mode usata (`v1` o `v2`) |

Se il log non si compila, la macro ora mostra un errore esplicito: controlla che `FP_Import_Log` non sia protetto e che le celle A:J siano scrivibili.

Se `SendToFirstPromoter` mostra `Operazione terminata`, la richiesta HTTP e stata interrotta da Excel/Windows/MSXML prima di ricevere una risposta API. La versione aggiornata usa `MSXML2.ServerXMLHTTP.6.0` e registra l'errore per singola riga in `FP_Import_Log` con stato `0`, invece di fermare tutto l'import.

In quel caso controlla:

- che la costante `FP_API_KEY` sia valorizzata;
- che il PC abbia accesso HTTPS a `https://firstpromoter.com` per v1 oppure `https://api.firstpromoter.com` per v2;
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

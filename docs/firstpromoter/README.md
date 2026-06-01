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
   - API v2: usa la `API key` normale, imposta `FP_ACCOUNT_ID` e imposta anche `FP_LEGACY_API_KEY` per poter correggere `customer_since` prima di creare la sale.
   - API v1 legacy: usa la `Legacy API key` in `FP_API_KEY` e lascia `FP_ACCOUNT_ID` vuoto.
6. Se il tuo account e FirstPromoter v2, imposta `FP_ACCOUNT_ID`; se resta vuota, il modulo usa la API legacy v1.

## Correzioni incluse

- Accesso ai fogli tramite workbook corretto e ricerca case-insensitive sui nomi, evitando riferimenti globali a `Sheets`.
- Parser CSV BCE basato sulle intestazioni `TIME_PERIOD` e `OBS_VALUE`, con supporto per campi quotati.
- Conversione EUR/USD coerente con il tasso BCE `USD per 1 EUR`: importi USD convertiti in EUR con `amount / rate`; importi EUR lasciati invariati.
- Filtri indipendenti per `Already Paid` e `To Be Paid`, con righe verdi per pagati e gialle per da pagare.
- Invio FirstPromoter con importo in centesimi, `event_id` uguale all'id pagamento Stripe e colonna Coupon inviata sia come `promo_code` sia come `ref_id` per attribuire la vendita al promoter. Se disponibile, lo Stripe Customer ID viene inviato come `uid`. In API v2 il modulo crea prima il lead via `/track/signup`, forza `customer_since` storico via `/api/v1/leads/update`, e registra la sale solo se questo backdate riesce.

## Troubleshooting invio FirstPromoter

### Scelta API v1/v2

La documentazione FirstPromoter e divisa in due flussi:

- v1: `POST https://firstpromoter.com/api/v1/track/sale`, parametri in query string, header `X-API-KEY`, risposta `204` quando non viene trovata una referral sale.
- v2: `POST https://api.firstpromoter.com/api/v2/track/sale`, JSON body, header `Authorization: Bearer <API key>` e `Account-ID`, risposta `404` quando referral/promoter non vengono trovati.

Se stai usando la UI FirstPromoter v2 e la sezione Tracking Coupons, imposta `FP_ACCOUNT_ID` con l'Account ID indicato in Settings > Integrations e usa la `API key` normale in `FP_API_KEY`. Imposta inoltre `FP_LEGACY_API_KEY` con la Legacy API key: serve solo per chiamare `PUT /api/v1/leads/update` e backdatare `customer_since`. Questo forza il modulo a usare la API v2 in modo sicuro.

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
| D | Coupon / promo code, inviato anche come `ref_id` |
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


### Date storiche e `uid`

Per API v2 il modulo ora usa un flusso protetto:

1. invia una signup storica con `created_at`, `uid` e `ref_id`;
2. chiama `PUT https://firstpromoter.com/api/v1/leads/update` con la `FP_LEGACY_API_KEY` per impostare `customer_since` alla data storica;
3. invia la sale solo se il backdate di `customer_since` ha successo.

Questo evita di creare commissioni pagabili quando FirstPromoter terrebbe `Customer Since` alla data odierna. Se `FP_LEGACY_API_KEY` manca o l'update `customer_since` fallisce, la sale non viene inviata e la riga va in errore nel log.

Se un lead/customer e gia stato creato da un test precedente con `Customer Since` odierno, esegui il nuovo flusso su una riga di test e verifica nel log che l'update `customer_since` risponda `200`. Se FirstPromoter non aggiorna quel record, va corretto/eliminato lato FirstPromoter prima di reimportare.

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
| opzionale | `Customer ID`, `Customer`, oppure `Stripe Customer ID` per inviare `uid` a FirstPromoter |

### `Filter_Output`

- `B4`: lista coupon separati da virgola, punto e virgola o nuova riga.
- `B5:D5`: intervallo `Already Paid`.
- `B6:D6`: intervallo `To Be Paid`.
- Output dalla riga 11, colonne `A:L`; la colonna `K` viene usata come stato importazione (`No`, `Yes`, `Error`, `No Referral`, `Duplicate`); la colonna `L` contiene lo Stripe Customer ID / `uid` quando disponibile.

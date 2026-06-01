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
5. Crea le Named Range workbook-level `FP_API_KEY` e `FP_ACCOUNT_ID` nel file Excel. Il modulo legge prima queste Named Range; le costanti nel codice sono solo fallback vuoti.
   - `FP_API_KEY` = API key normale FirstPromoter v2.
   - `FP_ACCOUNT_ID` = Account ID FirstPromoter.
   - `FP_LEGACY_API_KEY` non serve per il nuovo flusso referral-only.

## Correzioni incluse

- Accesso ai fogli tramite workbook corretto e ricerca case-insensitive sui nomi, evitando riferimenti globali a `Sheets`.
- Parser CSV BCE basato sulle intestazioni `TIME_PERIOD` e `OBS_VALUE`, con supporto per campi quotati.
- Conversione EUR/USD coerente con il tasso BCE `USD per 1 EUR`: importi USD convertiti in EUR con `amount / rate`; importi EUR lasciati invariati.
- Filtri indipendenti per `Already Paid` e `To Be Paid`, con righe verdi per pagati e gialle per da pagare.
- Invio FirstPromoter referral-only tramite WinHTTP: usa `/api/v2/track/signup` con email cliente, `uid` = Stripe Customer ID, `ref_id` = Coupon. Non crea sale, commissioni o payout storici.

## Troubleshooting invio FirstPromoter

### Flusso referral-only

Il modulo ora usa solo FirstPromoter API v2 per importare referral/lead storici:

`POST https://api.firstpromoter.com/api/v2/track/signup`

Header richiesti:

- `Authorization: Bearer <FP_API_KEY>`
- `Account-ID: <FP_ACCOUNT_ID>`
- `Content-Type: application/json`

Payload inviato per ogni riga:

```json
{
  "email": "cliente@example.com",
  "uid": "cus_...",
  "ref_id": "GO20",
  "created_at": "2026-05-10T00:00:00Z",
  "skip_email_notification": true
}
```

Questo crea/aggiorna il referral associato al promoter, ma non crea vendite, commissioni o payout. I rinnovi futuri dovranno essere tracciati da FirstPromoter usando lo stesso `uid` Stripe customer id.

Le chiamate FirstPromoter usano `WinHttp.WinHttpRequest.5.1` e inviano i body JSON come byte con `Content-Type: application/json; charset=utf-8`, per evitare che l endpoint li interpreti come richieste non-JSON.

### Test singola riga

Per testare una riga senza ciclo massivo, seleziona una riga in `Filter_Output` e lancia `TestFirstPromoterSignupSelectedRow`. Mostra HTTP status, response e payload della sola chiamata `/track/signup`.

### Verifica locale senza inviare

Usa `DiagnoseFirstPromoterSelectedRow` selezionando una riga in `Filter_Output`: la macro non invia nulla a FirstPromoter, ma verifica che id pagamento, data, email cliente, coupon, importo EUR e API key siano leggibili, poi mostra la query che verrebbe inviata.

Se alcune righe risultano inviate ma non compaiono in FirstPromoter, controlla `FP_Import_Log`:

- `200` = referral importato;
- `2024` non e uno status HTTP FirstPromoter valido: se lo vedi come errore VBA/Excel, controlla in quale colonna viene scritto e usa `DiagnoseFirstPromoterSelectedRow`;
- `422` = referral gia esistente;
- `401`/`403` = problema API key o Account ID;
- `404` = `ref_id` non trovato/non valido;
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

Se `FP_Import_Log` non e scrivibile, la macro crea/usa automaticamente `FP_Debug_Log` e scrive li gli stessi dettagli. Il messaggio di conferma indica il foglio log effettivo usato.

Se `SendToFirstPromoter` mostra `Operazione terminata`, la richiesta HTTP e stata interrotta da Excel/Windows/MSXML prima di ricevere una risposta API. La versione aggiornata usa `MSXML2.ServerXMLHTTP.6.0` e registra l'errore per singola riga in `FP_Import_Log` con stato `0`, invece di fermare tutto l'import.

In quel caso controlla:

- che la costante `FP_API_KEY` sia valorizzata;
- che il PC abbia accesso HTTPS a `https://firstpromoter.com` per v1 oppure `https://api.firstpromoter.com` per v2;
- la colonna risposta in `FP_Import_Log`, che conterra il dettaglio `VBA HTTP error ...`;
- eventuali proxy/firewall aziendali che interrompono le chiamate HTTPS da Excel/VBA.
- Se Excel segnala errori su `NumberFormat`, la formattazione e solo estetica: il modulo usa `SetNumberFormatSafe` per non bloccare l'import quando Excel non accetta un formato locale.
- Le scritture su log e colonna stato sono non bloccanti, cosi una cella protetta/formattata non interrompe l'invio gia effettuato.



### Paid / Unpaid nel nuovo flusso

`GenerateOutput` continua ad assegnare lo stato in colonna J:

- `Already Paid`: riga storica gia saldata fuori da FirstPromoter, verde;
- `To Be Paid`: riga non ancora saldata nello storico, gialla.

Nel nuovo flusso referral-only questa distinzione non crea payout: entrambe le categorie vengono importate solo come referral/lead, senza sale e senza commissioni. La distinzione resta utile per controllo operativo e riconciliazione esterna.

Gli intervalli data `Already Paid` e `To Be Paid` non possono sovrapporsi: se si intersecano, `GenerateOutput` si ferma con errore.

### Date storiche e `uid`

Per ogni referral importato il modulo invia:

- `created_at` = data storica del pagamento/riga;
- `uid` = Stripe Customer ID (`cus_...`) dalla colonna L di `Filter_Output`;
- `ref_id` = coupon/promoter code dalla colonna D.

Questo consente a FirstPromoter di associare il cliente storico al promoter senza creare commissioni passate. I rinnovi futuri dovranno arrivare a FirstPromoter con lo stesso `uid`.

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
- Output dalla riga 11, colonne `A:L`; la colonna `K` viene usata come stato importazione (`No`, `Referral Imported`, `Referral Exists`, `Referral Error`); la colonna `L` contiene lo Stripe Customer ID / `uid` quando disponibile.

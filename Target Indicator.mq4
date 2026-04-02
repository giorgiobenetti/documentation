//+------------------------------------------------------------------+
//|                                             Target Indicator.mq4 |
//|                                                    Investire.biz |
//|                                        https://www.Investire.biz |
//+------------------------------------------------------------------+
#property copyright "Investire.biz"
#property link      "https://www.Investire.biz"
#property version   "1.00"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//|   Data di scadenza                                               |
//+------------------------------------------------------------------+
// --- Parametri licenza
input string allowedServer = "TriveEurope-Live2"; // Nome del server autorizzato
string       supportEmail  = "info@investire.biz"; // Email supporto

datetime expirationDate = D'2026.04.07 00:00';

//+------------------------------------------------------------------+
//|   INPUT DELL'UTENTE                                              |
//+------------------------------------------------------------------+
input color coloreLivelli = clrBlue; // Colore Livelli Target

//+------------------------------------------------------------------+
//|   VARIABILI GLOBALI                                              |
//+------------------------------------------------------------------+
color coloreBottone      = clrGreenYellow; // Colore Sfondo Bottone
color coloreTesto        = clrBlack;       // Colore Testo Bottone
color coloreLati         = clrBlue;        // Colore Lati di triangolazione
color coloreBordoBottone = clrNONE;
int   larghezza          = 20;             // Estensione temporale livello

// Variabile globale per tenere traccia dello stato della modalità di stampa
bool isPrintingModeActive = false;

datetime firstClickTime   = 0;
double   firstClickPrice  = 0.0;
datetime secondClickTime  = 0;
double   secondClickPrice = 0.0;
datetime lastClickTime    = 0;
double   lastClickPrice   = 0.0;
int      clickCounter     = 0; // Contatore per i clic
int      nOggetti         = 0; // Contatore oggetti creati

//+------------------------------------------------------------------+
//| Utility MT4                                                      |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(name);
   }
}

int CurrentPeriodSeconds()
{
   int sec = PeriodSeconds();
   if(sec > 0)
      return sec;

   int tf = Period();
   switch(tf)
   {
      case PERIOD_M1:  return 60;
      case PERIOD_M5:  return 300;
      case PERIOD_M15: return 900;
      case PERIOD_M30: return 1800;
      case PERIOD_H1:  return 3600;
      case PERIOD_H4:  return 14400;
      case PERIOD_D1:  return 86400;
      case PERIOD_W1:  return 604800;
      case PERIOD_MN1: return 2592000;
   }
   return 60;
}

//--- License check (date + server) — NON intrusivo
bool CheckLicenseLocal(const datetime expiration, const string pSupportEmail,
                       const string productName, const string labelId,
                       const string pAllowedServer)
{
   datetime now = TimeCurrent();
   bool date_ok   = (now <= expiration);
   bool server_ok = (AccountServer() == pAllowedServer);

   if(date_ok && server_ok)
      return true;

   string msg1 = "Licenza " + productName + " scaduta o non valida per questo server.";
   string msg2 = "Contatta: " + pSupportEmail + " per una versione aggiornata.";
   string fullMsg = msg1 + " " + msg2;

   Print(fullMsg);
   MessageBox(fullMsg, "Errore Licenza", MB_OK | MB_ICONERROR);

   string labelIdLocal = (labelId == "" ? "BIZExpiredIndicatorText" : labelId);
   if(ObjectFind(labelIdLocal) < 0)
      ObjectCreate(labelIdLocal, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, labelIdLocal, OBJPROP_TEXT, fullMsg);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, labelIdLocal, OBJPROP_FONT, "Arial");

   return false;
}

//+------------------------------------------------------------------+
//|   FUNZIONE D'INIZIALIZZAZIONE                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   coloreLati = coloreLivelli;

   if(!CheckLicenseLocal(expirationDate, supportEmail, "Target Indicator", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   if(!ButtonCreate(0, "TIButton", 0, 90, 10, 80, 30, CORNER_RIGHT_UPPER, "Target", "Arial", 10,
                    coloreTesto, coloreBottone, coloreBordoBottone, false, false, false, true, 0))
   {
      Print("Errore nel creare il bottone");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|   FUNZIONE DI CANCELLAZIONE OGGETTI                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix("TI");
   DeleteObjectsByPrefix("ExpiredIndicatorText");
   ObjectDelete("BIZExpiredIndicatorText");
}

//+------------------------------------------------------------------+
//|   FUNZIONE ITERATIVA                                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   return(rates_total);
}

//+--------------------------------------------------------------------------------+
//| Gestione degli eventi del grafico, inclusi i click sui bottoni                 |
//+--------------------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   int    sub_window = 0;

   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "TIButton")
   {
      isPrintingModeActive = !isPrintingModeActive;
      clickCounter = 0;
      DeleteObjectsByPrefix("TITargetIndicator");
      nOggetti = 0;

      if(isPrintingModeActive)
         Print("Modalità di stampa attivata.");
      else
         Print("Modalità di stampa disattivata.");
   }
   else if(id == CHARTEVENT_CLICK && isPrintingModeActive)
   {
      int      x = (int)lparam;
      int      y = (int)dparam;
      datetime t = 0;
      double   p = 0.0;
      clickCounter++;

      if(ChartXYToTimePrice(0, x, y, sub_window, t, p))
      {
         if(clickCounter == 2)
         {
            firstClickTime = t;
            firstClickPrice = p;
            nOggetti += 1;
            Print("Primo salvato");
         }
         else if(clickCounter == 3)
         {
            secondClickTime = t;
            secondClickPrice = p;
            if(!TrendCreate("TITargetIndicator" + IntegerToString(nOggetti), firstClickTime, firstClickPrice,
                            secondClickTime, secondClickPrice, coloreLati, 1))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;
            Print("Secondo salvato");
            ChartRedraw(0);
         }
         else if(clickCounter == 4)
         {
            lastClickTime = t;
            lastClickPrice = p;

            TrendCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime, lastClickPrice,
                        secondClickTime, secondClickPrice, coloreLati, 1);
            nOggetti += 1;

            double AB = secondClickPrice - firstClickPrice;
            double AC = lastClickPrice - firstClickPrice;
            double CB = secondClickPrice - lastClickPrice;

            int timeExtension = CurrentPeriodSeconds() * larghezza;

            if(!TrendCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime, lastClickPrice + AB,
                            lastClickTime + timeExtension, lastClickPrice + AB, coloreLivelli, 2))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;
            if(!ArrowRightPriceCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime + timeExtension,
                                      lastClickPrice + AB, coloreLivelli, 1))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;

            if(!TrendCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime, lastClickPrice + AC,
                            lastClickTime + timeExtension, lastClickPrice + AC, coloreLivelli, 2))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;
            if(!ArrowRightPriceCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime + timeExtension,
                                      lastClickPrice + AC, coloreLivelli, 1))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;

            if(!TrendCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime, secondClickPrice + AB,
                            lastClickTime + timeExtension, secondClickPrice + AB, coloreLivelli, 2))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;
            if(!ArrowRightPriceCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime + timeExtension,
                                      secondClickPrice + AB, coloreLivelli, 1))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;

            if(!TrendCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime, secondClickPrice + CB,
                            lastClickTime + timeExtension, secondClickPrice + CB, coloreLivelli, 2))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;
            if(!ArrowRightPriceCreate("TITargetIndicator" + IntegerToString(nOggetti), lastClickTime + timeExtension,
                                      secondClickPrice + CB, coloreLivelli, 1))
            {
               Print("Errore nello stampare la linea.");
            }
            nOggetti += 1;

            clickCounter = 0;
            isPrintingModeActive = false;
            ObjectSetInteger(0, "TIButton", OBJPROP_STATE, false);
            Print("Terzo salvato");
            ChartRedraw(0);
         }
      }
   }
}

//+--------------------------------------------------------------------------------+
//| Crea il bottone                                                                |
//+--------------------------------------------------------------------------------+
bool ButtonCreate(const long chart_ID,
                  const string name,
                  const int sub_window,
                  const int x,
                  const int y,
                  const int width,
                  const int height,
                  const ENUM_BASE_CORNER corner,
                  const string text,
                  const string font,
                  const int font_size,
                  const color clr,
                  const color back_clr,
                  const color border_clr,
                  const bool state,
                  const bool back,
                  const bool selection,
                  const bool hidden,
                  const long z_order)
{
   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_BUTTON, sub_window, 0, 0))
   {
      Print(__FUNCTION__, ": fallimento nel creare il bottone! Error code = ", GetLastError());
      return(false);
   }
   ObjectSetInteger(chart_ID, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_ID, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_ID, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(chart_ID, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(chart_ID, name, OBJPROP_CORNER, corner);
   ObjectSetString(chart_ID, name, OBJPROP_TEXT, text);
   ObjectSetString(chart_ID, name, OBJPROP_FONT, font);
   ObjectSetInteger(chart_ID, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_BGCOLOR, back_clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_BORDER_COLOR, border_clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
   ObjectSetInteger(chart_ID, name, OBJPROP_STATE, state);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
   return(true);
}

//+--------------------------------------------------------------------------------+
//| Crea la trendline dalle coordinate fornite                                     |
//+--------------------------------------------------------------------------------+
bool TrendCreate(const string name,
                 datetime time1,
                 double price1,
                 datetime time2,
                 double price2,
                 const color clr,
                 const int width)
{
   const long            chart_ID = 0;
   const int             sub_window = 0;
   const ENUM_LINE_STYLE style = STYLE_SOLID;
   const bool            back = false;
   const bool            selection = false;
   const bool            ray_left = false;
   const bool            ray_right = false;
   const bool            hidden = true;
   const long            z_order = 0;

   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_TREND, sub_window, time1, price1, time2, price2))
   {
      Print(__FUNCTION__, ": fallimento nel creare una trend line! Error code = ", GetLastError());
      return(false);
   }
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
   ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_RAY_LEFT, ray_left);
   ObjectSetInteger(chart_ID, name, OBJPROP_RAY_RIGHT, ray_right);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
   return(true);
}

//+--------------------------------------------------------------------------------+
//| Crea l'etichetta prezzo a destra                                               |
//+--------------------------------------------------------------------------------+
bool ArrowRightPriceCreate(const string name,
                           datetime time,
                           double price,
                           const color clr,
                           const int width)
{
   const long            chart_ID = 0;
   const int             sub_window = 0;
   const ENUM_LINE_STYLE style = STYLE_SOLID;
   const bool            back = false;
   const bool            selection = false;
   const bool            hidden = true;
   const long            z_order = 0;

   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_ARROW_RIGHT_PRICE, sub_window, time, price))
   {
      Print(__FUNCTION__, ": fallimento nella creazione dell'etichetta prezzo a destra! Error code = ", GetLastError());
      return(false);
   }
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
   ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
   return(true);
}

//+--------------------------------------------------------------------------------+
//| INDICATORE SCADUTO                                                             |
//+--------------------------------------------------------------------------------+
void indicatoreScaduto()
{
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int center_x = chart_width / 2;
   int center_y = chart_height / 2;

   string messageLine1 = "La licenza per l'indicatore Target Indicator è scaduta.";
   string messageLine2 = "Per informazioni contatta info@investire.biz";

   Print("La licenza per l'indicatore Target Indicator è scaduta. Per informazioni contatta info@investire.biz");

   ObjectCreate(0, "ExpiredIndicatorText", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "ExpiredIndicatorText", OBJPROP_TEXT, messageLine1);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_YDISTANCE, center_y);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_ANCHOR, ANCHOR_CENTER);

   ObjectCreate(0, "ExpiredIndicatorText2", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "ExpiredIndicatorText2", OBJPROP_TEXT, messageLine2);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_YDISTANCE, center_y + 30);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_ANCHOR, ANCHOR_CENTER);
}

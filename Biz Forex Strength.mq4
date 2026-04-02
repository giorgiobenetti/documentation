//+------------------------------------------------------------------+
//|                                           Biz Forex Strength.mq4 |
//|                                                    Investire.biz |
//|                                        https://www.Investire.biz |
//+------------------------------------------------------------------+
#property copyright "Investire.biz"
#property link      "https://www.Investire.biz"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 8

//+------------------------------------------------------------------+
//|   Data di scadenza                                               |
//+------------------------------------------------------------------+
datetime expirationDate = D'2026.04.07 00:00';
input string allowedServer = "IG-LIVE"; // Nome del server autorizzato
string       supportEmail  = "info@investire.biz"; // Email supporto

//+------------------------------------------------------------------+
//|   INPUT DELL'UTENTE                                              |
//+------------------------------------------------------------------+
input int ma_period_ = 14;
input int ma_delta   = 1;

//+------------------------------------------------------------------+
//|   Variabili globali                                              |
//+------------------------------------------------------------------+
double EURx[], GBPx[], AUDx[], NZDx[], USDx[], CADx[], CHFx[], JPYx[];
double EUR, GBP, AUD, NZD, USD, CAD, CHF, JPY, A1, A2, A3, A4, A5, A6, A7;

string Currencies[] = {"AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"};
int xTabella = 30, yTabella = 15, spaziox = 22, spazioy = 20, widthTabella = 22, heightTabella = 20;
string OBJ_PREFIX = "BFS_";

string symbols[28] =
{
   "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY",
   "CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD",
   "EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD",
   "NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"
};
string symbolsWithSuffix[28];

double Ln1 = -5, Ln2 = -10, Ln3 = -15, Ln4 = -20, Ln5 = -25;
double Lp1 = 5, Lp2 = 10, Lp3 = 15, Lp4 = 20, Lp5 = 25;

#define AUDCAD 0
#define AUDCHF 1
#define AUDJPY 2
#define AUDNZD 3
#define AUDUSD 4
#define CADCHF 5
#define CADJPY 6
#define CHFJPY 7
#define EURAUD 8
#define EURCAD 9
#define EURCHF 10
#define EURGBP 11
#define EURJPY 12
#define EURNZD 13
#define EURUSD 14
#define GBPAUD 15
#define GBPCAD 16
#define GBPCHF 17
#define GBPJPY 18
#define GBPNZD 19
#define GBPUSD 20
#define NZDCAD 21
#define NZDCHF 22
#define NZDJPY 23
#define NZDUSD 24
#define USDCAD 25
#define USDCHF 26
#define USDJPY 27

//+------------------------------------------------------------------+
//| Utility                                                          |
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

string RowName(const int idx)   { return OBJ_PREFIX + Currencies[idx]; }
string CellName(const int idx, const int cell) { return OBJ_PREFIX + Currencies[idx] + IntegerToString(cell); }
string ValueName(const int idx) { return OBJ_PREFIX + "Valore" + Currencies[idx]; }

void DeleteLegacyTableObjects()
{
   for(int i = 0; i < 8; i++)
   {
      ObjectDelete(Currencies[i]);
      ObjectDelete("Valore" + Currencies[i]);
      for(int j = 0; j < 8; j++)
         ObjectDelete(Currencies[i] + IntegerToString(j));
   }
}

double MAValue(const int index, const int shift)
{
   return iMA(symbolsWithSuffix[index], PERIOD_CURRENT, ma_period_, 0, MODE_LWMA, PRICE_CLOSE, shift);
}

bool BuildRelRatios(const int shift, double &rel[])
{
   for(int p = 0; p < 28; p++)
   {
      double now  = MAValue(p, shift);
      double prev = MAValue(p, shift + ma_delta);
      if(!MathIsValidNumber(now) || !MathIsValidNumber(prev) || now <= 0.0 || prev <= 0.0)
         return(false);
      rel[p] = now / prev;
   }
   return(true);
}

void ResetTableToNeutral()
{
   for(int i = 0; i < 8; i++)
   {
      ObjectSetString(0, ValueName(i), OBJPROP_TEXT, "--");
      for(int j = 0; j < 8; j++)
         ObjectSetInteger(0, CellName(i, j), OBJPROP_BGCOLOR, clrWhite);
   }
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
//|   Funzione d'inizializzazione                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "Biz Forex Strength", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   datetime currentDateTime = TimeCurrent();
   if(currentDateTime > expirationDate)
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   string ShortName = "Biz Forex Strength(" + IntegerToString(ma_period_) + "/" + IntegerToString(ma_delta) + ") >>";
   IndicatorShortName(ShortName);

   SetIndexBuffer(0, EURx);
   SetIndexBuffer(1, GBPx);
   SetIndexBuffer(2, AUDx);
   SetIndexBuffer(3, NZDx);
   SetIndexBuffer(4, USDx);
   SetIndexBuffer(5, CADx);
   SetIndexBuffer(6, CHFx);
   SetIndexBuffer(7, JPYx);
   SetIndexStyle(0, DRAW_NONE);
   SetIndexStyle(1, DRAW_NONE);
   SetIndexStyle(2, DRAW_NONE);
   SetIndexStyle(3, DRAW_NONE);
   SetIndexStyle(4, DRAW_NONE);
   SetIndexStyle(5, DRAW_NONE);
   SetIndexStyle(6, DRAW_NONE);
   SetIndexStyle(7, DRAW_NONE);

   ArraySetAsSeries(EURx, true);
   ArraySetAsSeries(GBPx, true);
   ArraySetAsSeries(AUDx, true);
   ArraySetAsSeries(NZDx, true);
   ArraySetAsSeries(USDx, true);
   ArraySetAsSeries(CADx, true);
   ArraySetAsSeries(CHFx, true);
   ArraySetAsSeries(JPYx, true);

   if(!CreateHandles())
      return(INIT_FAILED);

   DeleteObjectsByPrefix(OBJ_PREFIX);
   DeleteLegacyTableObjects();
   SetVariablesBasedOnTimeframe();
   CreaTabella();
   ResetTableToNeutral();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|   FUNZIONE DI CANCELLAZIONE OGGETTI                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(OBJ_PREFIX);
   DeleteLegacyTableObjects();
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
   datetime currentDateTime = TimeCurrent();
   if(currentDateTime > expirationDate)
      return(0);

   int minBars = rates_total;
   for(int i = 0; i < ArraySize(symbolsWithSuffix); i++)
   {
      int barsCount = iBars(symbolsWithSuffix[i], PERIOD_CURRENT);
      if(barsCount <= (ma_period_ + ma_delta + 1))
      {
         Print(__FUNCTION__, ": ", symbolsWithSuffix[i], " Non pronto");
         CheckLoadHistory(symbolsWithSuffix[i], PERIOD_CURRENT, ma_period_ + ma_delta + 50);
         ResetTableToNeutral();
         return(0);
      }
      minBars = (int)MathMin(minBars, barsCount);
   }

   int limit = rates_total;
   if(prev_calculated > rates_total || prev_calculated <= 0)
      limit = minBars - ma_delta - 1;
   else
      limit = rates_total - prev_calculated + 1;

   if(limit <= 0)
   {
      ResetTableToNeutral();
      return(rates_total);
   }

   for(int i = 0; i < limit; i++)
   {
      double rel[28];
      if(!BuildRelRatios(i, rel))
      {
         ResetTableToNeutral();
         return(0);
      }

      A1 = rel[EURAUD];  // EURAUD*
      A2 = rel[GBPAUD];  // GBPAUD*
      A3 = rel[AUDNZD];  // AUDNZD
      A4 = rel[AUDUSD];  // AUDUSD
      A5 = rel[AUDCAD];  // AUDCAD
      A6 = rel[AUDCHF];  // AUDCHF
      A7 = rel[AUDJPY];  // AUDJPY
      AUD = (1 / A1 * 1 / A2 * A3 * A4 * A5 * A6 * A7) - 1;
      AUDx[i] = AUD;

      A1 = rel[EURCAD];  // EURCAD*
      A2 = rel[GBPCAD];  // GBPCAD*
      A3 = rel[AUDCAD];  // AUDCAD*
      A4 = rel[NZDCAD];  // NZDCAD*
      A5 = rel[USDCAD];  // USDCAD*
      A6 = rel[CADCHF];  // CADCHF
      A7 = rel[CADJPY];  // CADJPY
      CAD = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * 1 / A5 * A6 * A7) - 1;
      CADx[i] = CAD;

      A1 = rel[EURCHF];  // EURCHF*
      A2 = rel[GBPCHF];  // GBPCHF*
      A3 = rel[AUDCHF];  // AUDCHF*
      A4 = rel[NZDCHF];  // NZDCHF*
      A5 = rel[USDCHF];  // USDCHF*
      A6 = rel[CADCHF];  // CADCHF*
      A7 = rel[CHFJPY];  // CHFJPY
      CHF = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * 1 / A5 * 1 / A6 * A7) - 1;
      CHFx[i] = CHF;

      A1 = rel[EURGBP];  // EURGBP
      A2 = rel[EURAUD];  // EURAUD
      A3 = rel[EURNZD];  // EURNZD
      A4 = rel[EURUSD];  // EURUSD
      A5 = rel[EURCAD];  // EURCAD
      A6 = rel[EURCHF];  // EURCHF
      A7 = rel[EURJPY];  // EURJPY
      EUR = (A1 * A2 * A3 * A4 * A5 * A6 * A7) - 1;
      EURx[i] = EUR;

      A1 = rel[EURGBP];  // EURGBP*
      A2 = rel[GBPAUD];  // GBPAUD
      A3 = rel[GBPNZD];  // GBPNZD
      A4 = rel[GBPUSD];  // GBPUSD
      A5 = rel[GBPCAD];  // GBPCAD
      A6 = rel[GBPCHF];  // GBPCHF
      A7 = rel[GBPJPY];  // GBPJPY
      GBP = (1 / A1 * A2 * A3 * A4 * A5 * A6 * A7) - 1;
      GBPx[i] = GBP;

      A1 = rel[EURJPY];  // EURJPY*
      A2 = rel[GBPJPY];  // GBPJPY*
      A3 = rel[AUDJPY];  // AUDJPY*
      A4 = rel[NZDJPY];  // NZDJPY*
      A5 = rel[USDJPY];  // USDJPY*
      A6 = rel[CADJPY];  // CADJPY*
      A7 = rel[CHFJPY];  // CHFJPY*
      JPY = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * 1 / A5 * 1 / A6 * 1 / A7) - 1;
      JPYx[i] = JPY;

      A1 = rel[EURNZD];  // EURNZD*
      A2 = rel[GBPNZD];  // GBPNZD*
      A3 = rel[AUDNZD];  // AUDNZD*
      A4 = rel[NZDUSD];  // NZDUSD
      A5 = rel[NZDCAD];  // NZDCAD
      A6 = rel[NZDCHF];  // NZDCHF
      A7 = rel[NZDJPY];  // NZDJPY
      NZD = (1 / A1 * 1 / A2 * 1 / A3 * A4 * A5 * A6 * A7) - 1;
      NZDx[i] = NZD;

      A1 = rel[EURUSD];  // EURUSD*
      A2 = rel[GBPUSD];  // GBPUSD*
      A3 = rel[AUDUSD];  // AUDUSD*
      A4 = rel[NZDUSD];  // NZDUSD*
      A5 = rel[USDCAD];  // USDCAD
      A6 = rel[USDCHF];  // USDCHF
      A7 = rel[USDJPY];  // USDJPY
      USD = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * A5 * A6 * A7) - 1;
      USDx[i] = USD;
   }

   aggiornacolori(0, AUDx[0] * 10000.0);
   aggiornacolori(1, CADx[0] * 10000.0);
   aggiornacolori(2, CHFx[0] * 10000.0);
   aggiornacolori(3, EURx[0] * 10000.0);
   aggiornacolori(4, GBPx[0] * 10000.0);
   aggiornacolori(5, JPYx[0] * 10000.0);
   aggiornacolori(6, NZDx[0] * 10000.0);
   aggiornacolori(7, USDx[0] * 10000.0);

   return(rates_total);
}

//+------------------------------------------------------------------+
//|   Funzione CreateHandles                                         |
//+------------------------------------------------------------------+
bool CreateHandles()
{
   string SymbolSuffix = StringSubstr(Symbol(), 6, StringLen(Symbol()) - 6);
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = symbols[i] + SymbolSuffix;
      symbolsWithSuffix[i] = symbol;
      if(!CheckMarketWatch(symbol))
         return(false);
      CheckLoadHistory(symbol, PERIOD_CURRENT, ma_period_ + ma_delta + 100);
   }
   return(true);
}

//+------------------------------------------------------------------+
//|   Funzione CheckMarketWatch                                      |
//+------------------------------------------------------------------+
bool CheckMarketWatch(string symbol)
{
   ResetLastError();
   if(SymbolSelect(symbol, true))
      return(true);

   int err = GetLastError();
   Print(__FUNCTION__, ": Errore ad aggiungere/verificare il simbolo ", symbol, " codice=", err);
   return(false);
}

//+------------------------------------------------------------------+
//|   Funzione CheckLoadHistory                                      |
//+------------------------------------------------------------------+
void CheckLoadHistory(string symbol, int period, const int size)
{
   if(iBars(symbol, period) < size)
   {
      iClose(symbol, period, size - 1);
      iTime(symbol, period, size - 1);
   }
}

//+------------------------------------------------------------------+
//|   Funzione Tabella                                               |
//+------------------------------------------------------------------+
void CreaTabella()
{
   for(int i = 0; i < 8; i++)
   {
      ObjectCreate(0, RowName(i), OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, RowName(i), OBJPROP_XDISTANCE, xTabella + spaziox * 11);
      ObjectSetInteger(0, RowName(i), OBJPROP_YDISTANCE, yTabella + spazioy * i + 1);
      ObjectSetInteger(0, RowName(i), OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, RowName(i), OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, RowName(i), OBJPROP_TEXT, Currencies[i]);
      ObjectSetInteger(0, RowName(i), OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, RowName(i), OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, RowName(i), OBJPROP_BACK, false);
      ObjectSetInteger(0, RowName(i), OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, RowName(i), OBJPROP_SELECTED, false);

      for(int j = 0; j < 8; j++)
      {
         ObjectCreate(0, CellName(i, j), OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_XDISTANCE, xTabella + spaziox * 2 + spaziox * j);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_YDISTANCE, yTabella + spazioy * i);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_XSIZE, widthTabella);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_YSIZE, heightTabella);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_BGCOLOR, clrWhite);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_COLOR, clrBlack);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_BACK, false);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_SELECTED, false);
         ObjectSetInteger(0, CellName(i, j), OBJPROP_HIDDEN, true);
      }

      ObjectCreate(0, ValueName(i), OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ValueName(i), OBJPROP_XDISTANCE, xTabella);
      ObjectSetInteger(0, ValueName(i), OBJPROP_YDISTANCE, yTabella + spazioy * i + 1);
      ObjectSetInteger(0, ValueName(i), OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, ValueName(i), OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, ValueName(i), OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, ValueName(i), OBJPROP_BACK, false);
      ObjectSetInteger(0, ValueName(i), OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ValueName(i), OBJPROP_SELECTED, false);
      ObjectSetInteger(0, ValueName(i), OBJPROP_ALIGN, ALIGN_CENTER);
   }
}

//+------------------------------------------------------------------+
//|   Funzione aggiorna colori della tabella                         |
//+------------------------------------------------------------------+
void aggiornacolori(int OrdineMoneta, double valoreAggiornare)
{
   ObjectSetString(0, ValueName(OrdineMoneta), OBJPROP_TEXT, IntegerToString((int)valoreAggiornare));
   if(valoreAggiornare <= Ln5)
   {
      ObjectSetInteger(0, CellName(OrdineMoneta, 0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 3), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 4), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, CellName(OrdineMoneta, 5), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, CellName(OrdineMoneta, 6), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, CellName(OrdineMoneta, 7), OBJPROP_BGCOLOR, clrRed);
   }
   else if(valoreAggiornare > Ln5 && valoreAggiornare <= Ln4)
   {
      ObjectSetInteger(0, CellName(OrdineMoneta, 0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 3), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, CellName(OrdineMoneta, 4), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, CellName(OrdineMoneta, 5), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, CellName(OrdineMoneta, 6), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, CellName(OrdineMoneta, 7), OBJPROP_BGCOLOR, clrRed);
   }
   else if(valoreAggiornare > Ln4 && valoreAggiornare <= Ln3)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare > Ln3 && valoreAggiornare <= Ln2)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare > Ln2 && valoreAggiornare <= Ln1)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare >= Lp1 && valoreAggiornare < Lp2)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare >= Lp2 && valoreAggiornare < Lp3)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare >= Lp3 && valoreAggiornare < Lp4)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare >= Lp4 && valoreAggiornare < Lp5)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else if(valoreAggiornare >= Lp5)
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
   else
   {
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(0), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(1), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(2), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(3), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(4), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(5), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(6), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, Currencies[OrdineMoneta] + IntegerToString(7), OBJPROP_BGCOLOR, clrWhite);
   }
}

//+------------------------------------------------------------------+
//|   Setting scala indicatore in base al timeframe                  |
//+------------------------------------------------------------------+
void SetVariablesBasedOnTimeframe()
{
   int currentTimeframe = Period();
   if(currentTimeframe == PERIOD_M1)
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
   else if(currentTimeframe == PERIOD_M5)
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
   else if(currentTimeframe == PERIOD_M15)
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
   else if(currentTimeframe == PERIOD_M30)
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
   else if(currentTimeframe == PERIOD_H1)
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
   else if(currentTimeframe == PERIOD_H4)
   {
      Lp5 = 75; Lp4 = 60; Lp3 = 45; Lp2 = 30; Lp1 = 15;
      Ln1 = -15; Ln2 = -30; Ln3 = -45; Ln4 = -60; Ln5 = -75;
   }
   else if(currentTimeframe == PERIOD_D1)
   {
      Lp5 = 100; Lp4 = 80; Lp3 = 60; Lp2 = 40; Lp1 = 20;
      Ln1 = -20; Ln2 = -40; Ln3 = -60; Ln4 = -80; Ln5 = -100;
   }
   else if(currentTimeframe == PERIOD_W1)
   {
      Lp5 = 250; Lp4 = 200; Lp3 = 150; Lp2 = 100; Lp1 = 50;
      Ln1 = -50; Ln2 = -100; Ln3 = -150; Ln4 = -200; Ln5 = -250;
   }
   else if(currentTimeframe == PERIOD_MN1)
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
}

//+--------------------------------------------------------------------------------+
//| INDICATORE SCADUTO                                                             |
//+--------------------------------------------------------------------------------+
void indicatoreScaduto()
{
   long chart_width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long center_x = chart_width / 2;
   long center_y = chart_height / 2;

   string messageLine1 = "La licenza per l'indicatore Biz Forex Strength è scaduta.";
   string messageLine2 = "Per informazioni contatta info@investire.biz";

   Print("La licenza per l'indicatore Biz Forex Strength è scaduta. Per informazioni contatta info@investire.biz");

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

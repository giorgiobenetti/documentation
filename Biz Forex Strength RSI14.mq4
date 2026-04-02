//+------------------------------------------------------------------+
//|                                     Biz Forex Strength RSI14.mq4 |
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
input int rsi_period_ = 14;
input int rsi_delta   = 1;

//+------------------------------------------------------------------+
//|   Variabili globali                                              |
//+------------------------------------------------------------------+
double EURx[], GBPx[], AUDx[], NZDx[], USDx[], CADx[], CHFx[], JPYx[];
double EUR, GBP, AUD, NZD, USD, CAD, CHF, JPY, A1, A2, A3, A4, A5, A6, A7;

string Currencies[] = {"AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"};
int xTabella = 30, yTabella = 15, spaziox = 22, spazioy = 20, widthTabella = 22, heightTabella = 20;
string OBJ_PREFIX = "BFSR_";

string symbols[28] =
{
   "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY",
   "CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD",
   "EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD",
   "NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"
};
string symbolsWithSuffix[28];
string symbolSuffix = "";

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
#define USDCAD 26
#define USDCHF 26
#define USDJPY 27

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

void ResetTableToNeutral()
{
   for(int i = 0; i < 8; i++)
   {
      ObjectSetString(0, ValueName(i), OBJPROP_TEXT, "--");
      for(int j = 0; j < 8; j++)
         ObjectSetInteger(0, CellName(i, j), OBJPROP_BGCOLOR, clrWhite);
   }
}

double RsiValue(const int index, const int shift)
{
   return iRSI(symbolsWithSuffix[index], PERIOD_CURRENT, rsi_period_, PRICE_CLOSE, shift);
}

bool BuildRelRatios(const int shift, double &rel[])
{
   for(int p = 0; p < 28; p++)
   {
      double now  = RsiValue(p, shift);
      double prev = RsiValue(p, shift + rsi_delta);
      if(!MathIsValidNumber(now) || !MathIsValidNumber(prev) || now <= 0.0 || prev <= 0.0)
         return(false);
      rel[p] = now / prev;
   }
   return(true);
}

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

bool CheckMarketWatch(string symbol)
{
   ResetLastError();
   if(SymbolSelect(symbol, true))
      return(true);
   Print(__FUNCTION__, ": Errore ad aggiungere/verificare il simbolo ", symbol, " codice=", GetLastError());
   return(false);
}

void CheckLoadHistory(string symbol, int period, const int size)
{
   if(iBars(symbol, period) < size)
   {
      iClose(symbol, period, size - 1);
      iTime(symbol, period, size - 1);
   }
}

bool CreateHandles()
{
   string current = Symbol();
   symbolSuffix = "";
   if(StringLen(current) > 6)
      symbolSuffix = StringSubstr(current, 6, StringLen(current) - 6);

   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = symbols[i] + symbolSuffix;
      if(!CheckMarketWatch(symbol))
         return(false);
      symbolsWithSuffix[i] = symbol;
      CheckLoadHistory(symbolsWithSuffix[i], PERIOD_CURRENT, rsi_period_ + rsi_delta + 100);
   }
   return(true);
}

void SetVariablesBasedOnTimeframe()
{
   int currentTimeframe = Period();
   if(currentTimeframe == PERIOD_H4)
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
   else
   {
      Lp5 = 25; Lp4 = 20; Lp3 = 15; Lp2 = 10; Lp1 = 5;
      Ln1 = -5; Ln2 = -10; Ln3 = -15; Ln4 = -20; Ln5 = -25;
   }
}

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
         ObjectSetInteger(0, CellName(i, j), OBJPROP_HIDDEN, true);
      }
      ObjectCreate(0, ValueName(i), OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ValueName(i), OBJPROP_XDISTANCE, xTabella);
      ObjectSetInteger(0, ValueName(i), OBJPROP_YDISTANCE, yTabella + spazioy * i + 1);
      ObjectSetInteger(0, ValueName(i), OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, ValueName(i), OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, ValueName(i), OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, ValueName(i), OBJPROP_ALIGN, ALIGN_CENTER);
   }
}

void SetRowColors(const int OrdineMoneta,
                  const color c0, const color c1, const color c2, const color c3,
                  const color c4, const color c5, const color c6, const color c7)
{
   ObjectSetInteger(0, CellName(OrdineMoneta, 0), OBJPROP_BGCOLOR, c0);
   ObjectSetInteger(0, CellName(OrdineMoneta, 1), OBJPROP_BGCOLOR, c1);
   ObjectSetInteger(0, CellName(OrdineMoneta, 2), OBJPROP_BGCOLOR, c2);
   ObjectSetInteger(0, CellName(OrdineMoneta, 3), OBJPROP_BGCOLOR, c3);
   ObjectSetInteger(0, CellName(OrdineMoneta, 4), OBJPROP_BGCOLOR, c4);
   ObjectSetInteger(0, CellName(OrdineMoneta, 5), OBJPROP_BGCOLOR, c5);
   ObjectSetInteger(0, CellName(OrdineMoneta, 6), OBJPROP_BGCOLOR, c6);
   ObjectSetInteger(0, CellName(OrdineMoneta, 7), OBJPROP_BGCOLOR, c7);
}

void aggiornacolori(int OrdineMoneta, double valoreAggiornare)
{
   ObjectSetString(0, ValueName(OrdineMoneta), OBJPROP_TEXT, IntegerToString((int)valoreAggiornare));
   if(valoreAggiornare <= Ln5)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrWhite, clrRed, clrRed, clrRed, clrRed);
   else if(valoreAggiornare > Ln5 && valoreAggiornare <= Ln4)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrWhite, clrRed, clrRed, clrRed, clrRed);
   else if(valoreAggiornare > Ln4 && valoreAggiornare <= Ln3)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrWhite, clrRed, clrRed, clrRed, clrWhite);
   else if(valoreAggiornare > Ln3 && valoreAggiornare <= Ln2)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrWhite, clrRed, clrRed, clrWhite, clrWhite);
   else if(valoreAggiornare > Ln2 && valoreAggiornare <= Ln1)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrWhite, clrRed, clrWhite, clrWhite, clrWhite);
   else if(valoreAggiornare >= Lp1 && valoreAggiornare < Lp2)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrGreen, clrWhite, clrWhite, clrWhite, clrWhite);
   else if(valoreAggiornare >= Lp2 && valoreAggiornare < Lp3)
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrGreen, clrGreen, clrWhite, clrWhite, clrWhite, clrWhite);
   else if(valoreAggiornare >= Lp3 && valoreAggiornare < Lp4)
      SetRowColors(OrdineMoneta, clrWhite, clrGreen, clrGreen, clrGreen, clrWhite, clrWhite, clrWhite, clrWhite);
   else if(valoreAggiornare >= Lp4 && valoreAggiornare < Lp5)
      SetRowColors(OrdineMoneta, clrGreen, clrGreen, clrGreen, clrGreen, clrWhite, clrWhite, clrWhite, clrWhite);
   else if(valoreAggiornare >= Lp5)
      SetRowColors(OrdineMoneta, clrGreen, clrGreen, clrGreen, clrGreen, clrWhite, clrWhite, clrWhite, clrWhite);
   else
      SetRowColors(OrdineMoneta, clrWhite, clrWhite, clrWhite, clrWhite, clrWhite, clrWhite, clrWhite, clrWhite);
}

void indicatoreScaduto()
{
   long chart_width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long center_x = chart_width / 2;
   long center_y = chart_height / 2;
   ObjectCreate(0, "ExpiredIndicatorText", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "ExpiredIndicatorText", OBJPROP_TEXT, "La licenza per l'indicatore Biz Forex Strength RSI14 è scaduta.");
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_YDISTANCE, center_y);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_ANCHOR, ANCHOR_CENTER);
}

int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "Biz Forex Strength RSI14", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   IndicatorShortName("Biz Forex Strength RSI(" + IntegerToString(rsi_period_) + "/" + IntegerToString(rsi_delta) + ")");
   SetIndexBuffer(0, EURx); SetIndexStyle(0, DRAW_NONE);
   SetIndexBuffer(1, GBPx); SetIndexStyle(1, DRAW_NONE);
   SetIndexBuffer(2, AUDx); SetIndexStyle(2, DRAW_NONE);
   SetIndexBuffer(3, NZDx); SetIndexStyle(3, DRAW_NONE);
   SetIndexBuffer(4, USDx); SetIndexStyle(4, DRAW_NONE);
   SetIndexBuffer(5, CADx); SetIndexStyle(5, DRAW_NONE);
   SetIndexBuffer(6, CHFx); SetIndexStyle(6, DRAW_NONE);
   SetIndexBuffer(7, JPYx); SetIndexStyle(7, DRAW_NONE);

   ArraySetAsSeries(EURx, true); ArraySetAsSeries(GBPx, true);
   ArraySetAsSeries(AUDx, true); ArraySetAsSeries(NZDx, true);
   ArraySetAsSeries(USDx, true); ArraySetAsSeries(CADx, true);
   ArraySetAsSeries(CHFx, true); ArraySetAsSeries(JPYx, true);

   if(!CreateHandles()) return(INIT_FAILED);

   DeleteObjectsByPrefix(OBJ_PREFIX);
   SetVariablesBasedOnTimeframe();
   CreaTabella();
   ResetTableToNeutral();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(OBJ_PREFIX);
   DeleteObjectsByPrefix("ExpiredIndicatorText");
   ObjectDelete("BIZExpiredIndicatorText");
}

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
   if(TimeCurrent() > expirationDate || AccountServer() != allowedServer)
      return(0);

   int limit = rates_total;
   for(int i = 0; i < ArraySize(symbolsWithSuffix); i++)
   {
      int barsCount = iBars(symbolsWithSuffix[i], PERIOD_CURRENT);
      if(barsCount <= 0) return(0);
      limit = (int)MathMin(limit, barsCount);
   }

   if(prev_calculated > rates_total || prev_calculated <= 0)
      limit = limit - rsi_delta;
   else
      limit = rates_total - prev_calculated + 1;

   if(limit <= 0) return(rates_total);

   for(int i = 0; i < limit; i++)
   {
      double rel[28];
      if(!BuildRelRatios(i, rel)) continue;

      A1 = rel[EURAUD]; A2 = rel[GBPAUD]; A3 = rel[AUDNZD]; A4 = rel[AUDUSD]; A5 = rel[AUDCAD]; A6 = rel[AUDCHF]; A7 = rel[AUDJPY];
      AUD = (1 / A1 * 1 / A2 * A3 * A4 * A5 * A6 * A7) - 1; AUDx[i] = AUD;

      A1 = rel[EURCAD]; A2 = rel[GBPCAD]; A3 = rel[AUDCAD]; A4 = rel[NZDCAD]; A5 = rel[USDCAD]; A6 = rel[CADCHF]; A7 = rel[CADJPY];
      CAD = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * 1 / A5 * A6 * A7) - 1; CADx[i] = CAD;

      A1 = rel[EURCHF]; A2 = rel[GBPCHF]; A3 = rel[AUDCHF]; A4 = rel[NZDCHF]; A5 = rel[USDCHF]; A6 = rel[CADCHF]; A7 = rel[CHFJPY];
      CHF = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * 1 / A5 * 1 / A6 * A7) - 1; CHFx[i] = CHF;

      A1 = rel[EURGBP]; A2 = rel[EURAUD]; A3 = rel[EURNZD]; A4 = rel[EURUSD]; A5 = rel[EURCAD]; A6 = rel[EURCHF]; A7 = rel[EURJPY];
      EUR = (A1 * A2 * A3 * A4 * A5 * A6 * A7) - 1; EURx[i] = EUR;

      A1 = rel[EURGBP]; A2 = rel[GBPAUD]; A3 = rel[GBPNZD]; A4 = rel[GBPUSD]; A5 = rel[GBPCAD]; A6 = rel[GBPCHF]; A7 = rel[GBPJPY];
      GBP = (1 / A1 * A2 * A3 * A4 * A5 * A6 * A7) - 1; GBPx[i] = GBP;

      A1 = rel[EURJPY]; A2 = rel[GBPJPY]; A3 = rel[AUDJPY]; A4 = rel[NZDJPY]; A5 = rel[USDJPY]; A6 = rel[CADJPY]; A7 = rel[CHFJPY];
      JPY = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * 1 / A5 * 1 / A6 * 1 / A7) - 1; JPYx[i] = JPY;

      A1 = rel[EURNZD]; A2 = rel[GBPNZD]; A3 = rel[AUDNZD]; A4 = rel[NZDUSD]; A5 = rel[NZDCAD]; A6 = rel[NZDCHF]; A7 = rel[NZDJPY];
      NZD = (1 / A1 * 1 / A2 * 1 / A3 * A4 * A5 * A6 * A7) - 1; NZDx[i] = NZD;

      A1 = rel[EURUSD]; A2 = rel[GBPUSD]; A3 = rel[AUDUSD]; A4 = rel[NZDUSD]; A5 = rel[USDCAD]; A6 = rel[USDCHF]; A7 = rel[USDJPY];
      USD = (1 / A1 * 1 / A2 * 1 / A3 * 1 / A4 * A5 * A6 * A7) - 1; USDx[i] = USD;
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

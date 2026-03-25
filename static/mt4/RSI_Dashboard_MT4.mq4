//+------------------------------------------------------------------+
//|                     RSI Dashboard (MT4 - LICENSE MESSAGE)        |
//|                         Powered by Investire.biz                 |
//+------------------------------------------------------------------+
#property strict

//-------------------- INPUT ----------------------------------------
input int rsiPeriod = 14;
input ENUM_TIMEFRAMES rsiTimeframeMain = PERIOD_H4;
input ENUM_TIMEFRAMES rsiTimeframeSecondary = PERIOD_M15;
input double overbought = 70.0;
input double oversold = 30.0;
input int divergenceLookbackBars = 200;
input int divergencePivotLeft = 2;
input int divergencePivotRight = 2;

// --- LICENZA
input datetime expirationDate = D'2026.05.31 23:59:59';
input string allowedServer = "IG-LIVE";

//-------------------- TESTI ----------------------------------------
string title = "DASHBOARD RSI - IG LIVE";
string poweredByText = "Powered by Investire.biz";
string supportEmail = "info@investire.biz";

//-------------------- INTERNAL -------------------------------------
string PREFIX = "RSIDASH_";
bool g_blocked = false;
color COLOR_BRAND_GREEN = C'87,190,124';   // #57be7c
color COLOR_SIGNAL_GREEN = C'130,230,170'; // verde chiaro per strumenti

// snapshot stile grafico originale
bool g_chartStyleSaved = false;
long g_oldBg = clrWhite;
long g_oldFg = clrBlack;
long g_oldChartUp = clrBlack;
long g_oldChartDown = clrBlack;
long g_oldBull = clrBlack;
long g_oldBear = clrBlack;
long g_oldLine = clrBlack;
long g_oldGrid = true;
long g_oldShowOHLC = true;
long g_oldShowBid = true;
long g_oldShowAsk = true;
long g_oldShowPeriodSep = true;

//+------------------------------------------------------------------+
//| Utility: format dd/mm/yyyy                                       |
//+------------------------------------------------------------------+
string FormatDateDDMMYYYY(datetime t)
{
   int d = TimeDay(t);
   int m = TimeMonth(t);
   int y = TimeYear(t);

   string sd = (d < 10 ? "0" : "") + IntegerToString(d);
   string sm = (m < 10 ? "0" : "") + IntegerToString(m);
   return(sd + "/" + sm + "/" + IntegerToString(y));
}

string TfToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return("M1");
      case PERIOD_M5:   return("M5");
      case PERIOD_M15:  return("M15");
      case PERIOD_M30:  return("M30");
      case PERIOD_H1:   return("H1");
      case PERIOD_H4:   return("H4");
      case PERIOD_D1:   return("D1");
      case PERIOD_W1:   return("W1");
      case PERIOD_MN1:  return("MN1");
      default:          return(IntegerToString((int)tf));
   }
}

string GetRsiState(double value)
{
   if(value >= overbought) return("Ipercomprato");
   if(value <= oversold)   return("Ipervenduto");
   return("Neutro");
}

string GetRsiStateCode(double value)
{
   if(value >= overbought) return("OC");
   if(value <= oversold)   return("OV");
   return("N");
}

color GetRsiStateColor(double value)
{
   if(value >= overbought) return(clrRed);
   if(value <= oversold)   return(COLOR_SIGNAL_GREEN);
   return(clrBlack);
}

bool IsSwingLow(const string symbol, ENUM_TIMEFRAMES tf, int shift, int leftBars, int rightBars)
{
   double center = iLow(symbol, tf, shift);
   if(center <= 0) return(false);

   for(int i = 1; i <= leftBars; i++)
      if(iLow(symbol, tf, shift + i) <= center) return(false);

   for(int j = 1; j <= rightBars; j++)
      if(iLow(symbol, tf, shift - j) < center) return(false);

   return(true);
}

bool IsSwingHigh(const string symbol, ENUM_TIMEFRAMES tf, int shift, int leftBars, int rightBars)
{
   double center = iHigh(symbol, tf, shift);
   if(center <= 0) return(false);

   for(int i = 1; i <= leftBars; i++)
      if(iHigh(symbol, tf, shift + i) >= center) return(false);

   for(int j = 1; j <= rightBars; j++)
      if(iHigh(symbol, tf, shift - j) > center) return(false);

   return(true);
}

bool FindRecentTwoSwingLows(const string symbol, ENUM_TIMEFRAMES tf, int lookbackBars, int leftBars, int rightBars, int &recentShift, int &olderShift)
{
   recentShift = -1;
   olderShift = -1;

   int totalBars = Bars(symbol, tf);
   int startShift = rightBars + 1;
   int endShift = MathMin(lookbackBars, totalBars - leftBars - 1);
   if(endShift <= startShift) return(false);

   for(int shift = startShift; shift <= endShift; shift++)
   {
      if(!IsSwingLow(symbol, tf, shift, leftBars, rightBars)) continue;

      if(recentShift < 0) recentShift = shift;
      else
      {
         olderShift = shift;
         return(true);
      }
   }

   return(false);
}

bool FindRecentTwoSwingHighs(const string symbol, ENUM_TIMEFRAMES tf, int lookbackBars, int leftBars, int rightBars, int &recentShift, int &olderShift)
{
   recentShift = -1;
   olderShift = -1;

   int totalBars = Bars(symbol, tf);
   int startShift = rightBars + 1;
   int endShift = MathMin(lookbackBars, totalBars - leftBars - 1);
   if(endShift <= startShift) return(false);

   for(int shift = startShift; shift <= endShift; shift++)
   {
      if(!IsSwingHigh(symbol, tf, shift, leftBars, rightBars)) continue;

      if(recentShift < 0) recentShift = shift;
      else
      {
         olderShift = shift;
         return(true);
      }
   }

   return(false);
}

int GetRsiDivergence(const string symbol, ENUM_TIMEFRAMES tf)
{
   bool bullish = false;
   bool bearish = false;
   int bullishShift = 1000000;
   int bearishShift = 1000000;

   int lowRecent = -1, lowOlder = -1;
   if(FindRecentTwoSwingLows(symbol, tf, divergenceLookbackBars, divergencePivotLeft, divergencePivotRight, lowRecent, lowOlder))
   {
      double priceLowRecent = iLow(symbol, tf, lowRecent);
      double priceLowOlder = iLow(symbol, tf, lowOlder);
      double rsiLowRecent = iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE, lowRecent);
      double rsiLowOlder = iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE, lowOlder);

      if(priceLowRecent < priceLowOlder && rsiLowRecent > rsiLowOlder)
      {
         bullish = true;
         bullishShift = lowRecent;
      }
   }

   int highRecent = -1, highOlder = -1;
   if(FindRecentTwoSwingHighs(symbol, tf, divergenceLookbackBars, divergencePivotLeft, divergencePivotRight, highRecent, highOlder))
   {
      double priceHighRecent = iHigh(symbol, tf, highRecent);
      double priceHighOlder = iHigh(symbol, tf, highOlder);
      double rsiHighRecent = iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE, highRecent);
      double rsiHighOlder = iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE, highOlder);

      if(priceHighRecent > priceHighOlder && rsiHighRecent < rsiHighOlder)
      {
         bearish = true;
         bearishShift = highRecent;
      }
   }

   if(bullish && bearish)
      return((bullishShift < bearishShift) ? 1 : -1);
   if(bullish) return(1);
   if(bearish) return(-1);
   return(0);
}

string DivergenceToText(int divType)
{
   if(divType > 0) return("Rialz");
   if(divType < 0) return("Ribass");
   return("-");
}

//+------------------------------------------------------------------+
//| Utility: delete only our objects                                 |
//+------------------------------------------------------------------+
void DeleteMyObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PREFIX, 0) == 0)
         ObjectDelete(0, name);
   }
}

void SaveChartStyle()
{
   if(g_chartStyleSaved) return;

   g_oldBg = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   g_oldFg = ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   g_oldChartUp = ChartGetInteger(0, CHART_COLOR_CHART_UP);
   g_oldChartDown = ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
   g_oldBull = ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   g_oldBear = ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   g_oldLine = ChartGetInteger(0, CHART_COLOR_CHART_LINE);

   g_oldGrid = ChartGetInteger(0, CHART_SHOW_GRID);
   g_oldShowOHLC = ChartGetInteger(0, CHART_SHOW_OHLC);
   g_oldShowBid = ChartGetInteger(0, CHART_SHOW_BID_LINE);
   g_oldShowAsk = ChartGetInteger(0, CHART_SHOW_ASK_LINE);
   g_oldShowPeriodSep = ChartGetInteger(0, CHART_SHOW_PERIOD_SEP);

   g_chartStyleSaved = true;
}

void ApplyDashboardChartStyle()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrWhite);

   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, false);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);
}

void RestoreChartStyle()
{
   if(!g_chartStyleSaved) return;

   ChartSetInteger(0, CHART_COLOR_BACKGROUND, g_oldBg);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, g_oldFg);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, g_oldChartUp);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, g_oldChartDown);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, g_oldBull);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, g_oldBear);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, g_oldLine);

   ChartSetInteger(0, CHART_SHOW_GRID, g_oldGrid);
   ChartSetInteger(0, CHART_SHOW_OHLC, g_oldShowOHLC);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, g_oldShowBid);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, g_oldShowAsk);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, g_oldShowPeriodSep);
}

void DrawBackgroundPanel()
{
   string name = PREFIX + "bg";
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 0);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 0);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//-------------------- Drawing helpers ------------------------------
void DrawLabel(string name, int x, int y, string text, int fontSize, color c)
{
   name = PREFIX + name;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 20);
}

void DrawButton(string name, int x, int y, string text, string tooltip, int width, int height)
{
   name = PREFIX + name;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tooltip);

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, COLOR_BRAND_GREEN);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 30);
}

void DrawCenterText(string name, string text, int fontSize, color c, int yOffset)
{
   name = PREFIX + name;

   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int x = w / 2;
   int y = (h / 2) + yOffset;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 20);

   // se supportato: centra il testo
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
}

//-------------------- License screens ------------------------------
void ShowLicenseExpired()
{
   DeleteMyObjects();
   g_blocked = true;
   DrawBackgroundPanel();

   string d = FormatDateDDMMYYYY(expirationDate);

   DrawCenterText("ERR1", "LA LICENZA PER LA TUA DASHBOARD E SCADUTA", 24, clrRed,  -50);
   DrawCenterText("ERR2", "Scaduta il giorno " + d,                     16, clrBlack, 0);
   DrawCenterText("ERR3", "Scrivi a " + supportEmail,                   16, clrBlue,  40);

   ChartRedraw();
}

void ShowServerNotAllowed(string server)
{
   DeleteMyObjects();
   g_blocked = true;
   DrawBackgroundPanel();

   DrawCenterText("ERR1", "SERVER NON AUTORIZZATO",                      24, clrRed,  -50);
   DrawCenterText("ERR2", "Server rilevato: " + server,                  16, clrBlack, 0);
   DrawCenterText("ERR3", "Scrivi a " + supportEmail,                    16, clrBlue,  40);

   ChartRedraw();
}

//-------------------- Dashboard update -----------------------------
void UpdateDashboard()
{
   if(g_blocked) return;

   DrawBackgroundPanel();

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   DrawButton("btn_update", chartW - 110, 35, "Aggiorna", "update", 80, 30);

   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PREFIX, 0) != 0) continue;

      // Mantieni area fissa dashboard
      if(name == PREFIX+"bg" || name == PREFIX+"title" || name == PREFIX+"powered_by" || name == PREFIX+"btn_update")
         continue;

      ObjectDelete(0, name);
   }

   int x1 = 10;
   int x2 = (chartW / 2) + 10;
   int y1 = 74, y2 = 74;
   string tfMain = TfToString(rsiTimeframeMain);
   string tfSecondary = TfToString(rsiTimeframeSecondary);

   // Header colonna sinistra
   DrawLabel("hdr_l_sym",    x1,      56, "SYM",      8, clrDimGray);
   DrawLabel("hdr_l_h4",     x1 + 70, 56, tfMain,     8, clrDimGray);
   DrawLabel("hdr_l_m15",    x1 + 165,56, tfSecondary,8, clrDimGray);
   DrawLabel("hdr_l_div_h4", x1 + 260,56, "DIV H4",   8, clrDimGray);
   DrawLabel("hdr_l_div_m",  x1 + 335,56, "DIV M15",  8, clrDimGray);

   // Header colonna destra
   DrawLabel("hdr_r_sym",    x2,      56, "SYM",      8, clrDimGray);
   DrawLabel("hdr_r_h4",     x2 + 70, 56, tfMain,     8, clrDimGray);
   DrawLabel("hdr_r_m15",    x2 + 165,56, tfSecondary,8, clrDimGray);
   DrawLabel("hdr_r_div_h4", x2 + 260,56, "DIV H4",   8, clrDimGray);
   DrawLabel("hdr_r_div_m",  x2 + 335,56, "DIV M15",  8, clrDimGray);

   DrawLabel("legend", 200, 35, "Stati RSI: N=Neutro  OC=Ipercomprato  OV=Ipervenduto", 8, clrGray);

   int symTotal = SymbolsTotal(true);
   int count = 0;

   for(int i = 0; i < symTotal && count < 40; i++)
   {
      string symbol = SymbolName(i, true);

      double rsiMain = iRSI(symbol, rsiTimeframeMain, rsiPeriod, PRICE_CLOSE, 0);
      double rsiSecondary = iRSI(symbol, rsiTimeframeSecondary, rsiPeriod, PRICE_CLOSE, 0);

      if(rsiMain == EMPTY_VALUE || rsiSecondary == EMPTY_VALUE) continue;
      if(rsiMain < 0 || rsiMain > 100 || rsiSecondary < 0 || rsiSecondary > 100) continue;

      string statoMain = GetRsiState(rsiMain);
      string statoSecondary = GetRsiState(rsiSecondary);
      string stateMainCode = GetRsiStateCode(rsiMain);
      string stateSecondaryCode = GetRsiStateCode(rsiSecondary);
      string divMain = DivergenceToText(GetRsiDivergence(symbol, rsiTimeframeMain));
      string divSecondary = DivergenceToText(GetRsiDivergence(symbol, rsiTimeframeSecondary));

      // Colore riga basato solo sul timeframe principale (H4 di default).
      color rowColor = clrBlack;
      if(statoMain != "Neutro")
         rowColor = GetRsiStateColor(rsiMain);

      int x = (count < 20) ? x1 : x2;
      int y = (count < 20) ? y1 : y2;

      DrawLabel("row_sym_"+IntegerToString(count),      x,       y, symbol,                                  9, rowColor);
      DrawLabel("row_h4_"+IntegerToString(count),       x + 70,  y, DoubleToString(rsiMain, 1) + " " + stateMainCode,      9, rowColor);
      DrawLabel("row_m15_"+IntegerToString(count),      x + 165, y, DoubleToString(rsiSecondary, 1) + " " + stateSecondaryCode, 9, rowColor);
      DrawLabel("row_div_h4_"+IntegerToString(count),   x + 260, y, divMain,                                 9, rowColor);
      DrawLabel("row_div_m15_"+IntegerToString(count),  x + 335, y, divSecondary,                            9, rowColor);
      DrawButton("btn_"+symbol, x + 410, y - 2, "Vai", symbol, 45, 18);

      if(count < 20) y1 += 22; else y2 += 22;
      count++;
   }

   ChartRedraw();
}

//-------------------- Init / Deinit -------------------------------
int OnInit()
{
   DeleteMyObjects();
   g_blocked = false;

   SaveChartStyle();
   ApplyDashboardChartStyle();
   DrawBackgroundPanel();

   if(TimeCurrent() > expirationDate)
   {
      ShowLicenseExpired();
      return(INIT_SUCCEEDED);
   }

   string currentBroker = AccountServer();
   if(StringFind(currentBroker, allowedServer) < 0)
   {
      ShowServerNotAllowed(currentBroker);
      return(INIT_SUCCEEDED);
   }

   DrawLabel("title", 10, 10, title, 18, COLOR_BRAND_GREEN);
   DrawLabel("powered_by", 10, 35, poweredByText, 9, clrGray);
   DrawButton("btn_update", (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 110, 35, "Aggiorna", "update", 80, 30);

   UpdateDashboard();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteMyObjects();
   RestoreChartStyle();
   ChartRedraw();
}

void OnTick() {}

//-------------------- Click / chart events -------------------------
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      // Ridisegna pannello/schermata in caso di resize o cambio grafico
      if(g_blocked)
      {
         if(TimeCurrent() > expirationDate) ShowLicenseExpired();
         else
         {
            string currentBroker = AccountServer();
            if(StringFind(currentBroker, allowedServer) < 0) ShowServerNotAllowed(currentBroker);
         }
      }
      else
      {
         UpdateDashboard();
      }
      return;
   }

   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // se bloccato, ridisegna (utile dopo resize)
   if(g_blocked)
   {
      if(TimeCurrent() > expirationDate) ShowLicenseExpired();
      else
      {
         string currentBroker2 = AccountServer();
         if(StringFind(currentBroker2, allowedServer) < 0) ShowServerNotAllowed(currentBroker2);
      }
      return;
   }

   // accettiamo solo click su oggetti nostri
   if(StringFind(sparam, PREFIX, 0) != 0) return;

   if(sparam == PREFIX+"btn_update")
   {
      UpdateDashboard();
      return;
   }

   if(StringFind(sparam, PREFIX+"btn_", 0) == 0)
   {
      string symbol = StringSubstr(sparam, StringLen(PREFIX+"btn_"));
      long newChart = ChartOpen(symbol, rsiTimeframeMain);

      if(newChart <= 0)
         Print("Errore apertura grafico per ", symbol, ". Codice: ", GetLastError());

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
}

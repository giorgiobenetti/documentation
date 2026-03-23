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

color GetRsiStateColor(double value, bool primary)
{
   if(value >= overbought) return(primary ? clrRed : clrTomato);
   if(value <= oversold)   return(primary ? clrDarkGreen : clrSeaGreen);
   return(clrBlack);
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

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrBlue);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
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

   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PREFIX, 0) != 0) continue;

      // Mantieni area fissa dashboard
      if(name == PREFIX+"bg" || name == PREFIX+"title" || name == PREFIX+"powered_by" || name == PREFIX+"btn_update")
         continue;

      if(StringFind(name, PREFIX+"line_", 0) == 0 || StringFind(name, PREFIX+"btn_", 0) == 0)
         ObjectDelete(0, name);
   }

   int x1 = 10,  y1 = 70;
   int x2 = 560, y2 = 70;
   string tfMain = TfToString(rsiTimeframeMain);
   string tfSecondary = TfToString(rsiTimeframeSecondary);

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

      // Priorita' colore al timeframe principale (H4 di default).
      color rowColor = clrBlack;
      if(statoMain != "Neutro")
         rowColor = GetRsiStateColor(rsiMain, true);
      else if(statoSecondary != "Neutro")
         rowColor = GetRsiStateColor(rsiSecondary, false);

      int x = (count < 20) ? x1 : x2;
      int y = (count < 20) ? y1 : y2;

      string rowText = symbol +
                       " | " + tfMain + ": " + DoubleToString(rsiMain, 2) + " " + statoMain +
                       " | " + tfSecondary + ": " + DoubleToString(rsiSecondary, 2) + " " + statoSecondary;

      DrawLabel("line_"+IntegerToString(count), x, y, rowText, 9, rowColor);
      DrawButton("btn_"+symbol, x + 430, y - 2, "Vai", symbol, 45, 18);

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

   DrawLabel("title", 10, 10, title, 18, clrLime);
   DrawLabel("powered_by", 10, 35, poweredByText, 9, clrGray);
   DrawButton("btn_update", 700, 35, "Aggiorna", "update", 80, 30);

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

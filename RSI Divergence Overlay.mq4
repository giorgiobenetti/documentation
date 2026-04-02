//+------------------------------------------------------------------+
//|                 RSI Divergence Overlay (MT4)                     |
//|         Standalone indicator (separate from dashboard)           |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0

//+------------------------------------------------------------------+
//|   Data di scadenza                                               |
//+------------------------------------------------------------------+
datetime expirationDate = D'2026.04.07 00:00';
input string allowedServer = "IG-LIVE"; // Nome del server autorizzato
string       supportEmail  = "info@investire.biz"; // Email supporto

// ---------- Inputs ----------
input int             InpRsiPeriod            = 14;
input ENUM_TIMEFRAMES InpMainTimeframe        = PERIOD_H4;
input ENUM_TIMEFRAMES InpSecondaryTimeframe   = PERIOD_M15;
input int             InpLookbackBars         = 200;
input int             InpPivotLeft            = 2;
input int             InpPivotRight           = 2;
input int             InpUpdateSeconds        = 2;
input bool            InpShowMainTf           = true;
input bool            InpShowSecondaryTf      = true;
input bool            InpShowLabels           = true;
input int             InpLabelFontSize        = 9;
input int             InpLineWidth            = 2;
input ENUM_LINE_STYLE InpMainLineStyle        = STYLE_SOLID;
input ENUM_LINE_STYLE InpSecondaryLineStyle   = STYLE_DOT;

// Colors
input color InpMainBullColor      = C'130,230,170'; // same light-green family
input color InpMainBearColor      = clrRed;
input color InpSecondaryBullColor = C'87,190,124';
input color InpSecondaryBearColor = C'255,110,110';

string PREFIX = "RSIDIVOVR_";

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
   if(ObjectFind(0, labelIdLocal) < 0)
      ObjectCreate(0, labelIdLocal, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, labelIdLocal, OBJPROP_TEXT, fullMsg);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, labelIdLocal, OBJPROP_FONT, "Arial");

   return false;
}

void indicatoreScaduto()
{
   long chart_width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long center_x = chart_width / 2;
   long center_y = chart_height / 2;

   string messageLine1 = "La licenza per l'indicatore RSI Divergence Overlay è scaduta.";
   string messageLine2 = "Per informazioni contatta info@investire.biz";

   Print("La licenza per l'indicatore RSI Divergence Overlay è scaduta. Per informazioni contatta info@investire.biz");

   ObjectCreate(0,"ExpiredIndicatorText",OBJ_LABEL,0,0,0);
   ObjectSetString(0, "ExpiredIndicatorText", OBJPROP_TEXT, messageLine1);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_XDISTANCE,center_x);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_YDISTANCE,center_y);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_FONTSIZE,18);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_COLOR,clrOrange);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_ANCHOR,ANCHOR_CENTER);

   ObjectCreate(0,"ExpiredIndicatorText2",OBJ_LABEL,0,0,0);
   ObjectSetString(0, "ExpiredIndicatorText2", OBJPROP_TEXT, messageLine2);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_XDISTANCE,center_x);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_YDISTANCE,center_y+30);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_FONTSIZE,18);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_COLOR,clrOrange);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_ANCHOR,ANCHOR_CENTER);
}

string TfToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
      default:         return(IntegerToString((int)tf));
   }
}

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

bool GetRsiDivergenceDetails(const string symbol,
                             ENUM_TIMEFRAMES tf,
                             int &divType,
                             int &olderShift,
                             int &recentShift,
                             double &olderPrice,
                             double &recentPrice)
{
   divType = 0;
   olderShift = -1;
   recentShift = -1;
   olderPrice = 0.0;
   recentPrice = 0.0;

   bool bullish = false;
   bool bearish = false;
   int bullRecent = 1000000, bullOlder = -1;
   int bearRecent = 1000000, bearOlder = -1;
   double bullRecentPrice = 0.0, bullOlderPrice = 0.0;
   double bearRecentPrice = 0.0, bearOlderPrice = 0.0;

   int lowRecent = -1, lowOlder = -1;
   if(FindRecentTwoSwingLows(symbol, tf, InpLookbackBars, InpPivotLeft, InpPivotRight, lowRecent, lowOlder))
   {
      double priceLowRecent = iLow(symbol, tf, lowRecent);
      double priceLowOlder = iLow(symbol, tf, lowOlder);
      double rsiLowRecent = iRSI(symbol, tf, InpRsiPeriod, PRICE_CLOSE, lowRecent);
      double rsiLowOlder = iRSI(symbol, tf, InpRsiPeriod, PRICE_CLOSE, lowOlder);
      if(rsiLowRecent != EMPTY_VALUE && rsiLowOlder != EMPTY_VALUE)
      {
         if(priceLowRecent < priceLowOlder && rsiLowRecent > rsiLowOlder)
         {
            bullish = true;
            bullRecent = lowRecent;
            bullOlder = lowOlder;
            bullRecentPrice = priceLowRecent;
            bullOlderPrice = priceLowOlder;
         }
      }
   }

   int highRecent = -1, highOlder = -1;
   if(FindRecentTwoSwingHighs(symbol, tf, InpLookbackBars, InpPivotLeft, InpPivotRight, highRecent, highOlder))
   {
      double priceHighRecent = iHigh(symbol, tf, highRecent);
      double priceHighOlder = iHigh(symbol, tf, highOlder);
      double rsiHighRecent = iRSI(symbol, tf, InpRsiPeriod, PRICE_CLOSE, highRecent);
      double rsiHighOlder = iRSI(symbol, tf, InpRsiPeriod, PRICE_CLOSE, highOlder);
      if(rsiHighRecent != EMPTY_VALUE && rsiHighOlder != EMPTY_VALUE)
      {
         if(priceHighRecent > priceHighOlder && rsiHighRecent < rsiHighOlder)
         {
            bearish = true;
            bearRecent = highRecent;
            bearOlder = highOlder;
            bearRecentPrice = priceHighRecent;
            bearOlderPrice = priceHighOlder;
         }
      }
   }

   // Same priority logic used in dashboard:
   // if both are present, keep the most recent one (smaller shift).
   if(bullish && bearish)
   {
      if(bullRecent < bearRecent)
      {
         divType = 1;
         recentShift = bullRecent;
         olderShift = bullOlder;
         recentPrice = bullRecentPrice;
         olderPrice = bullOlderPrice;
      }
      else
      {
         divType = -1;
         recentShift = bearRecent;
         olderShift = bearOlder;
         recentPrice = bearRecentPrice;
         olderPrice = bearOlderPrice;
      }
      return(true);
   }
   if(bullish)
   {
      divType = 1;
      recentShift = bullRecent;
      olderShift = bullOlder;
      recentPrice = bullRecentPrice;
      olderPrice = bullOlderPrice;
      return(true);
   }
   if(bearish)
   {
      divType = -1;
      recentShift = bearRecent;
      olderShift = bearOlder;
      recentPrice = bearRecentPrice;
      olderPrice = bearOlderPrice;
      return(true);
   }
   return(false);
}

void DrawTfDivergence(ENUM_TIMEFRAMES tf, bool enabled, bool isMainTf)
{
   string tfName = TfToString(tf);
   string lineName = PREFIX + "LINE_" + tfName;
   string textName = PREFIX + "TEXT_" + tfName;

   if(!enabled)
   {
      ObjectDelete(0, lineName);
      ObjectDelete(0, textName);
      return;
   }

   int divType = 0;
   int olderShift = -1, recentShift = -1;
   double olderPrice = 0.0, recentPrice = 0.0;
   if(!GetRsiDivergenceDetails(Symbol(), tf, divType, olderShift, recentShift, olderPrice, recentPrice))
   {
      ObjectDelete(0, lineName);
      ObjectDelete(0, textName);
      return;
   }

   datetime t1 = iTime(Symbol(), tf, olderShift);
   datetime t2 = iTime(Symbol(), tf, recentShift);
   if(t1 <= 0 || t2 <= 0)
   {
      ObjectDelete(0, lineName);
      ObjectDelete(0, textName);
      return;
   }

   color c = clrBlack;
   if(isMainTf)
      c = (divType > 0 ? InpMainBullColor : InpMainBearColor);
   else
      c = (divType > 0 ? InpSecondaryBullColor : InpSecondaryBearColor);

   ENUM_LINE_STYLE style = (isMainTf ? InpMainLineStyle : InpSecondaryLineStyle);
   if(ObjectFind(0, lineName) < 0)
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, olderPrice, t2, recentPrice);
   else
   {
      ObjectMove(0, lineName, 0, t1, olderPrice);
      ObjectMove(0, lineName, 1, t2, recentPrice);
   }
   ObjectSetInteger(0, lineName, OBJPROP_RAY, false);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, c);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, false);

   if(!InpShowLabels)
   {
      ObjectDelete(0, textName);
      return;
   }

   if(ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_TEXT, 0, t2, recentPrice);

   double atr = iATR(Symbol(), tf, 14, 0);
   if(atr <= 0.0) atr = MarketInfo(Symbol(), MODE_POINT) * 90.0;
   if(atr <= 0.0) atr = 0.0010;
   double labelY = recentPrice + (divType > 0 ? -atr * 0.30 : atr * 0.30);
   string labelTxt = "DIV " + tfName + " " + (divType > 0 ? "Rialz" : "Ribass");
   ObjectMove(0, textName, 0, t2, labelY);
   ObjectSetString(0, textName, OBJPROP_TEXT, labelTxt);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, c);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, InpLabelFontSize);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, false);
}

void UpdateOverlay()
{
   DrawTfDivergence(InpMainTimeframe, InpShowMainTf, true);
   DrawTfDivergence(InpSecondaryTimeframe, InpShowSecondaryTf, false);
   ChartRedraw(0);
}

int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "RSI Divergence Overlay", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   IndicatorShortName("RSI Divergence Overlay");
   UpdateOverlay();
   EventSetTimer(MathMax(1, InpUpdateSeconds));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteMyObjects();
   ObjectDelete(0, "BIZExpiredIndicatorText");
   ObjectDelete(0, "ExpiredIndicatorText");
   ObjectDelete(0, "ExpiredIndicatorText2");
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
   if(TimeCurrent() > expirationDate)
      return(0);
   if(AccountServer() != allowedServer)
      return(0);

   UpdateOverlay();
   return(rates_total);
}

void OnTimer()
{
   if(TimeCurrent() > expirationDate) return;
   if(AccountServer() != allowedServer) return;
   UpdateOverlay();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(TimeCurrent() > expirationDate) return;
      if(AccountServer() != allowedServer) return;
      UpdateOverlay();
   }
}

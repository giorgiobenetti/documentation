//+------------------------------------------------------------------+
//|                 Floating P/L Badge (MT4 - Elegant)               |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0

// ---------- Inputs ----------
input int    InpStartY          = 14;               // Initial top-center Y (px)
input string InpTextFont        = "Arial";
input int    InpTextFontSize    = 22;
input int    InpPadX            = 18;               // Horizontal padding
input int    InpPadY            = 12;               // Vertical padding
input int    InpSafetyX         = 10;               // Extra anti-clipping pixels
input int    InpSafetyY         = 6;                // Extra anti-clipping pixels
input int    InpMinWidth        = 140;              // Minimum badge width
input int    InpMinHeight       = 62;               // Minimum badge height
input int    InpBorderWidth     = 1;
input double InpFlatEpsilon     = 0.01;             // Flat threshold (account ccy)
input int    InpUpdateMs        = 250;              // Timer interval (ms)

// Colors
input color  InpColorProfit     = C'22,163,74';     // Elegant green
input color  InpColorLoss       = C'220,0,0';       // Red
input color  InpColorFlat       = C'120,120,120';   // Gray
input color  InpTextColor       = clrWhite;
input color  InpBorderColor     = C'35,35,35';

// ---------- Object names ----------
string g_prefix = "";
string g_box = "";
string g_text = "";

// ---------- State ----------
int  g_x = 0;
int  g_y = 0;
bool g_userMoved = false;

// ---------- Helpers ----------
bool SymbolFloatingPL(double &total)
{
   total = 0.0;
   bool hasPositions = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      hasPositions = true;
      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(hasPositions);
}

string MoneyFmt(double v)
{
   string sign = (v > 0.0 ? "+" : "");
   return(sign + DoubleToString(v, 2) + " " + AccountCurrency());
}

color BadgeColor(double pl, bool hasPositions)
{
   if(!hasPositions) return(InpColorFlat);
   if(MathAbs(pl) <= InpFlatEpsilon) return(InpColorFlat);
   if(pl > 0.0) return(InpColorProfit);
   return(InpColorLoss);
}

int GetChartWidth()
{
   return((int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS));
}

int CenterXForWidth(int badgeWidth)
{
   int w = GetChartWidth();
   int x = (w - badgeWidth) / 2;
   if(x < 0) x = 0;
   return(x);
}

void DeleteByPrefix(const string prefix)
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

void CleanupLegacyObjects()
{
   // Cleanup old templates/versions that can leave stale badges on chart.
   DeleteByPrefix("PLRectBox_");
   DeleteByPrefix("PLRectText_");
   DeleteByPrefix(g_prefix);
}

void EnsureRectangleLabel(const string name)
{
   if(ObjectFind(0, name) >= 0) return;

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_y);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
}

void EnsureTextLabel(const string name)
{
   if(ObjectFind(0, name) >= 0) return;

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_FONT, InpTextFont);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpTextFontSize);
}

void SyncDraggedPosition()
{
   if(ObjectFind(0, g_box) < 0) return;

   int liveX = (int)ObjectGetInteger(0, g_box, OBJPROP_XDISTANCE);
   int liveY = (int)ObjectGetInteger(0, g_box, OBJPROP_YDISTANCE);

   if((bool)ObjectGetInteger(0, g_box, OBJPROP_SELECTED) || liveX != g_x || liveY != g_y)
   {
      g_x = liveX;
      g_y = liveY;
      g_userMoved = true;
   }
}

void CreateOrUpdateObjects(double pl, bool hasPositions)
{
   string txt = hasPositions ? MoneyFmt(pl) : ("0.00 " + AccountCurrency());
   color bg = BadgeColor(pl, hasPositions);

   EnsureRectangleLabel(g_box);
   EnsureTextLabel(g_text);
   SyncDraggedPosition();

   ObjectSetString(0, g_text, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, g_text, OBJPROP_COLOR, InpTextColor);
   ObjectSetString(0, g_text, OBJPROP_FONT, InpTextFont);
   ObjectSetInteger(0, g_text, OBJPROP_FONTSIZE, InpTextFontSize);

   // Force MT4 to compute rendered label size.
   ChartRedraw(0);

   int tw = (int)ObjectGetInteger(0, g_text, OBJPROP_XSIZE);
   int th = (int)ObjectGetInteger(0, g_text, OBJPROP_YSIZE);
   if(tw <= 0) tw = (int)MathRound(StringLen(txt) * InpTextFontSize * 0.70);
   if(th <= 0) th = (int)MathRound(InpTextFontSize * 1.35);

   int bw = MathMax(InpMinWidth, tw + 2 * InpPadX + InpSafetyX);
   int bh = MathMax(InpMinHeight, th + 2 * InpPadY + InpSafetyY);

   // Keep auto-centered only until user drags the badge.
   if(!g_userMoved)
   {
      g_x = CenterXForWidth(bw);
      g_y = InpStartY;
   }

   ObjectSetInteger(0, g_box, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_box, OBJPROP_XDISTANCE, g_x);
   ObjectSetInteger(0, g_box, OBJPROP_YDISTANCE, g_y);
   ObjectSetInteger(0, g_box, OBJPROP_XSIZE, bw);
   ObjectSetInteger(0, g_box, OBJPROP_YSIZE, bh);
   ObjectSetInteger(0, g_box, OBJPROP_WIDTH, MathMax(0, InpBorderWidth));
   ObjectSetInteger(0, g_box, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, g_box, OBJPROP_COLOR, InpBorderColor);

   int tx = g_x + (bw / 2) - (tw / 2);
   int ty = g_y + (bh / 2) - (th / 2);
   ObjectSetInteger(0, g_text, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_text, OBJPROP_XDISTANCE, tx);
   ObjectSetInteger(0, g_text, OBJPROP_YDISTANCE, ty);
}

void DeleteObjects()
{
   if(ObjectFind(0, g_text) >= 0) ObjectDelete(0, g_text);
   if(ObjectFind(0, g_box) >= 0) ObjectDelete(0, g_box);
}

// ---------- MT4 events ----------
int OnInit()
{
   g_prefix = "PLBadgeElegant_" + IntegerToString((int)ChartID()) + "_" + Symbol() + "_";
   g_box = g_prefix + "Box";
   g_text = g_prefix + "Text";

   g_x = 0;
   g_y = InpStartY;
   g_userMoved = false;

   IndicatorShortName("Floating PL Badge Elegant");
   CleanupLegacyObjects();

   EventSetMillisecondTimer(MathMax(100, InpUpdateMs));

   double pl = 0.0;
   bool hasPositions = SymbolFloatingPL(pl);
   CreateOrUpdateObjects(pl, hasPositions);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteObjects();

   // Defensive cleanup in case template had older object names.
   CleanupLegacyObjects();
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
   double pl = 0.0;
   bool hasPositions = SymbolFloatingPL(pl);
   CreateOrUpdateObjects(pl, hasPositions);
   return(rates_total);
}

void OnTimer()
{
   double pl = 0.0;
   bool hasPositions = SymbolFloatingPL(pl);
   CreateOrUpdateObjects(pl, hasPositions);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      // If user has not moved it, keep it always top-center on resize.
      if(!g_userMoved)
      {
         double pl = 0.0;
         bool hasPositions = SymbolFloatingPL(pl);
         CreateOrUpdateObjects(pl, hasPositions);
      }
      return;
   }

   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE)
   {
      if(sparam == g_box)
      {
         g_x = (int)ObjectGetInteger(0, g_box, OBJPROP_XDISTANCE);
         g_y = (int)ObjectGetInteger(0, g_box, OBJPROP_YDISTANCE);
         g_userMoved = true;
      }
   }
}

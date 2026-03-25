//+------------------------------------------------------------------+
//|            Floating P/L Round Badge (MT4 - Draggable)            |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0

// ---------- Inputs ----------
input int    InpStartY           = 12;               // Default top-center Y
input int    InpTextFontSize     = 17;               // P/L text size
input int    InpMinDiameter      = 92;               // Minimum circle diameter
input int    InpTextPadding      = 16;               // Inner padding around text
input int    InpSafetyPixels     = 8;                // Anti-clipping safety
input int    InpCircleFontMin    = 98;               // Base circle glyph size
input int    InpRingExtraSize    = 8;                // Outer ring thickness (visual)
input int    InpUpdateMs         = 250;              // Refresh interval
input double InpFlatEpsilon      = 0.01;             // Flat threshold

// Colors
input color  InpColorProfit      = C'24,168,98';
input color  InpColorLoss        = C'224,40,40';
input color  InpColorFlat        = C'125,125,125';
input color  InpTextColor        = clrWhite;
input color  InpRingColor        = C'35,35,35';

// ---------- Object names ----------
string g_prefix = "";
string g_ring = "";
string g_circle = "";
string g_text = "";

// ---------- State ----------
int  g_x = 0;
int  g_y = 0;
bool g_userMoved = false;

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

void DeleteIfExists(const string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void CleanupLegacyObjects()
{
   string id = IntegerToString((int)ChartID()) + "_" + Symbol();

   // Previous rectangular versions
   DeleteIfExists("PLRectBox_" + id);
   DeleteIfExists("PLRectText_" + id);

   // Previous elegant version
   DeleteByPrefix("PLBadgeElegant_" + id + "_");

   // Current round version (only this chart/symbol namespace)
   DeleteByPrefix("PLRoundBadge_" + id + "_");
}

void EnsureCircleLabel(const string name, bool selectable, int zorder)
{
   bool created = false;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      created = true;
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
   if(created) ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, "●");
}

void EnsureValueLabel()
{
   if(ObjectFind(0, g_text) < 0)
      ObjectCreate(0, g_text, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, g_text, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_text, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_text, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, g_text, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_text, OBJPROP_ZORDER, 20);
   ObjectSetString(0, g_text, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, g_text, OBJPROP_FONTSIZE, InpTextFontSize);
}

int ChartWidth()
{
   return((int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS));
}

void SyncDraggedPosition()
{
   if(ObjectFind(0, g_circle) < 0) return;

   int liveX = (int)ObjectGetInteger(0, g_circle, OBJPROP_XDISTANCE);
   int liveY = (int)ObjectGetInteger(0, g_circle, OBJPROP_YDISTANCE);
   if((bool)ObjectGetInteger(0, g_circle, OBJPROP_SELECTED) || liveX != g_x || liveY != g_y)
   {
      g_x = liveX;
      g_y = liveY;
      g_userMoved = true;
   }
}

void CreateOrUpdateObjects(double pl, bool hasPositions)
{
   string txt = hasPositions ? MoneyFmt(pl) : ("0.00 " + AccountCurrency());
   color fill = BadgeColor(pl, hasPositions);

   EnsureCircleLabel(g_ring, false, 5);
   EnsureCircleLabel(g_circle, true, 10);
   EnsureValueLabel();
   SyncDraggedPosition();

   ObjectSetString(0, g_text, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, g_text, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, g_text, OBJPROP_FONTSIZE, InpTextFontSize);

   // Measure text first.
   ChartRedraw(0);
   int tw = (int)ObjectGetInteger(0, g_text, OBJPROP_XSIZE);
   int th = (int)ObjectGetInteger(0, g_text, OBJPROP_YSIZE);
   if(tw <= 0) tw = (int)MathRound(StringLen(txt) * InpTextFontSize * 0.64);
   if(th <= 0) th = (int)MathRound(InpTextFontSize * 1.35);

   int needed = MathMax(InpMinDiameter, MathMax(tw, th) + 2 * InpTextPadding + InpSafetyPixels);

   // Scale circle glyph to fit text.
   int circleFont = MathMax(InpCircleFontMin, needed);
   ObjectSetInteger(0, g_circle, OBJPROP_FONTSIZE, circleFont);
   ObjectSetInteger(0, g_ring, OBJPROP_FONTSIZE, circleFont + InpRingExtraSize);

   ObjectSetInteger(0, g_circle, OBJPROP_COLOR, fill);
   ObjectSetInteger(0, g_ring, OBJPROP_COLOR, InpRingColor);

   ChartRedraw(0);
   int cw = (int)ObjectGetInteger(0, g_circle, OBJPROP_XSIZE);
   int ch = (int)ObjectGetInteger(0, g_circle, OBJPROP_YSIZE);
   int rw = (int)ObjectGetInteger(0, g_ring, OBJPROP_XSIZE);
   int rh = (int)ObjectGetInteger(0, g_ring, OBJPROP_YSIZE);

   if(cw <= 0) cw = needed;
   if(ch <= 0) ch = needed;
   if(rw <= 0) rw = cw + InpRingExtraSize;
   if(rh <= 0) rh = ch + InpRingExtraSize;

   if(!g_userMoved)
   {
      g_x = (ChartWidth() - cw) / 2;
      if(g_x < 0) g_x = 0;
      g_y = InpStartY;
   }

   int ringX = g_x - (rw - cw) / 2;
   int ringY = g_y - (rh - ch) / 2;

   ObjectSetInteger(0, g_ring, OBJPROP_XDISTANCE, ringX);
   ObjectSetInteger(0, g_ring, OBJPROP_YDISTANCE, ringY);
   ObjectSetInteger(0, g_circle, OBJPROP_XDISTANCE, g_x);
   ObjectSetInteger(0, g_circle, OBJPROP_YDISTANCE, g_y);

   int tx = g_x + (cw / 2) - (tw / 2);
   int ty = g_y + (ch / 2) - (th / 2);
   ObjectSetInteger(0, g_text, OBJPROP_XDISTANCE, tx);
   ObjectSetInteger(0, g_text, OBJPROP_YDISTANCE, ty);
}

void DeleteObjects()
{
   if(ObjectFind(0, g_text) >= 0) ObjectDelete(0, g_text);
   if(ObjectFind(0, g_circle) >= 0) ObjectDelete(0, g_circle);
   if(ObjectFind(0, g_ring) >= 0) ObjectDelete(0, g_ring);
}

int OnInit()
{
   g_prefix = "PLRoundBadge_" + IntegerToString((int)ChartID()) + "_" + Symbol() + "_";
   g_ring = g_prefix + "Ring";
   g_circle = g_prefix + "Circle";
   g_text = g_prefix + "Text";

   g_x = 0;
   g_y = InpStartY;
   g_userMoved = false;

   IndicatorShortName("Floating PL Round Badge");
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
      // Keep top-center while not manually moved by user.
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
      if(sparam == g_circle)
      {
         g_x = (int)ObjectGetInteger(0, g_circle, OBJPROP_XDISTANCE);
         g_y = (int)ObjectGetInteger(0, g_circle, OBJPROP_YDISTANCE);
         g_userMoved = true;
      }
   }
}

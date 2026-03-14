#property strict
#property indicator_chart_window
#property indicator_buffers 0

// ---------- Inputs ----------
input int    InpCorner          = 0;      // 0=TL,1=TR,2=BL,3=BR
input int    InpX               = 20;     // Badge top-left X (px)
input int    InpY               = 20;     // Badge top-left Y (px)

input string InpTextFont        = "Arial";
input int    InpTextFontSize    = 22;

input int    InpPadX            = 18;     // Horizontal padding inside badge (px)
input int    InpPadY            = 12;     // Vertical padding inside badge (px)
input int    InpSafetyX         = 10;     // Extra safety pixels to avoid clipping (px)
input int    InpSafetyY         = 6;      // Extra safety pixels (px)

input int    InpMinWidth        = 120;    // Minimum badge width (px)
input int    InpMinHeight       = 60;     // Minimum badge height (px)
input int    InpBorderWidth     = 1;

input double InpFlatEpsilon     = 0.01;   // Flat threshold (account currency)
input int    InpUpdateMs        = 250;    // Update interval (ms)

// Colors
input color  InpColorProfit     = clrBlack;         // Profit: black background
input color  InpColorLoss       = C'220,0,0';       // Loss: red background
input color  InpColorFlat       = C'160,160,160';   // Flat/no positions: gray
input color  InpTextColor       = clrWhite;

// ---------- Object names ----------
string g_box, g_text;

// Persisted position
int g_corner, g_x, g_y;

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

   return hasPositions;
}

color BadgeColor(double pl, bool hasPositions)
{
   if(!hasPositions) return InpColorFlat;
   if(MathAbs(pl) <= InpFlatEpsilon) return InpColorFlat;
   if(pl > 0.0) return InpColorProfit;
   return InpColorLoss;
}

string MoneyFmt(double v)
{
   return DoubleToString(v, 2) + " " + AccountCurrency();
}

void EnsureRectangleLabel(const string name)
{
   if(ObjectFind(0, name) >= 0) return;

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, g_corner);
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
   ObjectSetInteger(0, name, OBJPROP_CORNER, g_corner);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_FONT, InpTextFont);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpTextFontSize);
}

void SyncDraggedPosition()
{
   if(ObjectFind(0, g_box) < 0)
      return;

   // While dragging, continuously adopt live coordinates.
   // This prevents timer updates from snapping the badge back to the left.
   if((bool)ObjectGetInteger(0, g_box, OBJPROP_SELECTED))
   {
      g_corner = (int)ObjectGetInteger(0, g_box, OBJPROP_CORNER);
      g_x      = (int)ObjectGetInteger(0, g_box, OBJPROP_XDISTANCE);
      g_y      = (int)ObjectGetInteger(0, g_box, OBJPROP_YDISTANCE);
   }
}

void CreateOrUpdateObjects(double pl, bool hasPositions)
{
   string txt = MoneyFmt(pl);
   color  bg  = BadgeColor(pl, hasPositions);

   EnsureRectangleLabel(g_box);
   EnsureTextLabel(g_text);
   SyncDraggedPosition();

   // Update text first so MT4 computes rendered size.
   ObjectSetInteger(0, g_text, OBJPROP_CORNER, g_corner);
   ObjectSetString(0, g_text, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, g_text, OBJPROP_COLOR, InpTextColor);
   ObjectSetString(0, g_text, OBJPROP_FONT, InpTextFont);
   ObjectSetInteger(0, g_text, OBJPROP_FONTSIZE, InpTextFontSize);

   ChartRedraw(0);

   int tw = (int)ObjectGetInteger(0, g_text, OBJPROP_XSIZE);
   int th = (int)ObjectGetInteger(0, g_text, OBJPROP_YSIZE);

   if(tw <= 0) tw = (int)MathRound(StringLen(txt) * InpTextFontSize * 0.70);
   if(th <= 0) th = (int)MathRound(InpTextFontSize * 1.35);

   int bw = MathMax(InpMinWidth,  tw + 2 * InpPadX + InpSafetyX);
   int bh = MathMax(InpMinHeight, th + 2 * InpPadY + InpSafetyY);

   ObjectSetInteger(0, g_box, OBJPROP_CORNER, g_corner);
   ObjectSetInteger(0, g_box, OBJPROP_XDISTANCE, g_x);
   ObjectSetInteger(0, g_box, OBJPROP_YDISTANCE, g_y);
   ObjectSetInteger(0, g_box, OBJPROP_XSIZE, bw);
   ObjectSetInteger(0, g_box, OBJPROP_YSIZE, bh);
   ObjectSetInteger(0, g_box, OBJPROP_WIDTH, MathMax(0, InpBorderWidth));

   // Fill + border: same color for a clean, solid badge.
   ObjectSetInteger(0, g_box, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, g_box, OBJPROP_COLOR,   bg);

   int tx = g_x + (bw / 2) - (tw / 2);
   int ty = g_y + (bh / 2) - (th / 2);

   ObjectSetInteger(0, g_text, OBJPROP_XDISTANCE, tx);
   ObjectSetInteger(0, g_text, OBJPROP_YDISTANCE, ty);
}

void DeleteObjects()
{
   if(ObjectFind(0, g_text) >= 0) ObjectDelete(0, g_text);
   if(ObjectFind(0, g_box)  >= 0) ObjectDelete(0, g_box);
}

// ---------- MT4 events ----------
int OnInit()
{
   g_corner = InpCorner;
   g_x      = InpX;
   g_y      = InpY;

   long cid = ChartID();
   g_box  = "PLRectBox_"  + IntegerToString((int)cid) + "_" + Symbol();
   g_text = "PLRectText_" + IntegerToString((int)cid) + "_" + Symbol();

   EventSetMillisecondTimer(MathMax(100, InpUpdateMs));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteObjects();
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
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE)
   {
      if(sparam == g_box)
      {
         g_corner = (int)ObjectGetInteger(0, g_box, OBJPROP_CORNER);
         g_x      = (int)ObjectGetInteger(0, g_box, OBJPROP_XDISTANCE);
         g_y      = (int)ObjectGetInteger(0, g_box, OBJPROP_YDISTANCE);
      }
   }
}

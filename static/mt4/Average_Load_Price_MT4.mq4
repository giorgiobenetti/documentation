//+------------------------------------------------------------------+
//|               Average Load Price (MT4 - Standalone)              |
//|      Mostra il prezzo medio di carico BUY/SELL su grafico        |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0

enum EDisplayMode
{
   DISPLAY_BOTH = 0,
   DISPLAY_BUY_ONLY = 1,
   DISPLAY_SELL_ONLY = 2
};

// ---------- Inputs ----------
input EDisplayMode    DisplayMode = DISPLAY_BOTH;
input bool            OnlyCurrentSymbol = true;
input int             UpdateSeconds = 1;
input color           BuyLineColor = clrLime;
input color           SellLineColor = clrRed;
input int             LineWidth = 2;
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;
input bool            ShowInfoPanel = true;
input int             PanelX = 10;   // distanza dal bordo destro
input int             PanelY = 12;   // distanza dal bordo basso
input int             PanelFontSize = 10;
input string          PanelFontName = "Arial";
input bool            UseBoldText = true;
input color           PanelTextColor = clrWhite;
input double          MarginCallPercent = 50.0; // soglia margin call (% margine)
input bool            ShowTargetLine = true;
input double          TargetLinePrice = 0.0; // se 0 usa Bid iniziale
input color           TargetLineColor = clrDeepSkyBlue;
input int             TargetLineWidth = 2;
input ENUM_LINE_STYLE TargetLineStyle = STYLE_DASH;
input bool            IncludeSwapCommissionInTarget = true;

string g_prefix = "";
string g_buyLine = "";
string g_sellLine = "";
string g_targetLine = "";
string g_info1 = "";
string g_info2 = "";
string g_info3 = "";
string g_info4 = "";
string g_info5 = "";

bool IsMarketPosition(const int orderType)
{
   return(orderType == OP_BUY || orderType == OP_SELL);
}

bool IsDirectionEnabled(const int orderType)
{
   if(DisplayMode == DISPLAY_BOTH) return(true);
   if(DisplayMode == DISPLAY_BUY_ONLY && orderType == OP_BUY) return(true);
   if(DisplayMode == DISPLAY_SELL_ONLY && orderType == OP_SELL) return(true);
   return(false);
}

bool CalculateAverageLoadPrice(const int orderType, double &avgPrice, double &totalLots, int &ordersCount)
{
   avgPrice = 0.0;
   totalLots = 0.0;
   ordersCount = 0;
   double weightedSum = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      int type = OrderType();
      if(type != orderType || !IsMarketPosition(type))
         continue;

      if(OnlyCurrentSymbol && OrderSymbol() != Symbol())
         continue;

      double lots = OrderLots();
      double openPrice = OrderOpenPrice();
      if(lots <= 0.0 || openPrice <= 0.0)
         continue;

      totalLots += lots;
      weightedSum += (openPrice * lots);
      ordersCount++;
   }

   if(totalLots <= 0.0 || ordersCount <= 0)
      return(false);

   avgPrice = weightedSum / totalLots;
   return(true);
}

double PipSize()
{
   int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double point = MarketInfo(Symbol(), MODE_POINT);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
}

void DeleteIfExists(const string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void EnsureHLine(const string name, double price, color c)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, LineWidth));
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void EnsureTargetLine(double &targetPrice)
{
   if(!ShowTargetLine)
   {
      DeleteIfExists(g_targetLine);
      targetPrice = 0.0;
      return;
   }

   bool created = false;
   if(ObjectFind(0, g_targetLine) < 0)
   {
      double initialPrice = (TargetLinePrice > 0.0 ? TargetLinePrice : Bid);
      ObjectCreate(0, g_targetLine, OBJ_HLINE, 0, 0, initialPrice);
      created = true;
   }

   targetPrice = ObjectGetDouble(0, g_targetLine, OBJPROP_PRICE1);
   if(targetPrice <= 0.0)
      targetPrice = (TargetLinePrice > 0.0 ? TargetLinePrice : Bid);

   ObjectSetDouble(0, g_targetLine, OBJPROP_PRICE1, targetPrice);
   ObjectSetInteger(0, g_targetLine, OBJPROP_COLOR, TargetLineColor);
   ObjectSetInteger(0, g_targetLine, OBJPROP_STYLE, TargetLineStyle);
   ObjectSetInteger(0, g_targetLine, OBJPROP_WIDTH, MathMax(1, TargetLineWidth));
   ObjectSetInteger(0, g_targetLine, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_targetLine, OBJPROP_SELECTABLE, true);
    if(created) ObjectSetInteger(0, g_targetLine, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_targetLine, OBJPROP_HIDDEN, false);
}

void DrawPanelLine(const string name, int x, int y, const string text, color c)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   string fontToUse = PanelFontName;
   if(UseBoldText)
      fontToUse = PanelFontName + " Bold";

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, PanelFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString (0, name, OBJPROP_FONT, fontToUse);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
}

string PriceFmt(const double v)
{
   return(DoubleToString(v, Digits));
}

string MoneyFmt(const double v)
{
   return(DoubleToString(v, 2) + " " + AccountCurrency());
}

string MarginLevelFmt()
{
   double margin = AccountMargin();
   if(margin <= 0.0)
      return("N/A");
   double ml = (AccountEquity() / margin) * 100.0;
   return(DoubleToString(ml, 1) + "%");
}

string MarginCallPriceText(double buyLots, double sellLots)
{
   if(!OnlyCurrentSymbol)
      return("MC@50%: N/A (OnlyCurrentSymbol=false)");

   double margin = AccountMargin();
   if(margin <= 0.0)
      return("MC@50%: N/A (margin=0)");

   double triggerPct = MarginCallPercent;
   if(triggerPct <= 0.0) triggerPct = 50.0;
   double triggerEquity = margin * (triggerPct / 100.0);
   double lossToCall = AccountEquity() - triggerEquity;
   if(lossToCall <= 0.0)
      return("MC@50%: ATTIVA/IMMINENTE");

   double netLots = buyLots - sellLots;
   if(MathAbs(netLots) < 0.0000001)
      return("MC@50%: N/A (net lots=0)");

   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return("MC@50%: N/A (tick data)");

   // dPL = (deltaPrice / tickSize) * tickValue * netLots
   // set dPL = -lossToCall and solve deltaPrice
   double deltaPrice = (-lossToCall * tickSize) / (tickValue * netLots);
   double currentRef = (netLots > 0.0 ? Bid : Ask);
   double callPrice = currentRef + deltaPrice;

   if(callPrice <= 0.0)
      return("MC@50%: N/A (prezzo<=0)");

   double pip = PipSize();
   double distPips = 0.0;
   if(pip > 0.0)
      distPips = MathAbs(currentRef - callPrice) / pip;

   string side = (netLots > 0.0 ? "LONG" : "SHORT");
   return(
      "MC@" + DoubleToString(triggerPct, 0) + "%: " + DoubleToString(callPrice, Digits) +
      " | dist: " + DoubleToString(distPips, 1) + " pips" +
      " | net: " + side
   );
}

bool CalculateProjectedProfitAtTarget(double targetPrice, double &targetProfit, double &targetLots, int &targetOrders)
{
   targetProfit = 0.0;
   targetLots = 0.0;
   targetOrders = 0;

   if(!ShowTargetLine) return(false);
   if(!OnlyCurrentSymbol) return(false); // target line e' un prezzo del simbolo corrente
   if(targetPrice <= 0.0) return(false);

   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return(false);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      int type = OrderType();
      if(!IsMarketPosition(type)) continue;
      if(!IsDirectionEnabled(type)) continue;
      if(OrderSymbol() != Symbol()) continue;

      double lots = OrderLots();
      double openPrice = OrderOpenPrice();
      if(lots <= 0.0 || openPrice <= 0.0)
         continue;

      double priceDiff = 0.0;
      if(type == OP_BUY) priceDiff = targetPrice - openPrice;
      else if(type == OP_SELL) priceDiff = openPrice - targetPrice;

      double projected = (priceDiff / tickSize) * tickValue * lots;
      if(IncludeSwapCommissionInTarget)
         projected += (OrderSwap() + OrderCommission());

      targetProfit += projected;
      targetLots += lots;
      targetOrders++;
   }

   return(targetOrders > 0);
}

void UpdateIndicator()
{
   double buyAvg = 0.0, buyLots = 0.0;
   int buyCount = 0;
   bool hasBuy = CalculateAverageLoadPrice(OP_BUY, buyAvg, buyLots, buyCount);

   double sellAvg = 0.0, sellLots = 0.0;
   int sellCount = 0;
   bool hasSell = CalculateAverageLoadPrice(OP_SELL, sellAvg, sellLots, sellCount);

   bool showBuy = IsDirectionEnabled(OP_BUY);
   bool showSell = IsDirectionEnabled(OP_SELL);
   double targetPrice = 0.0;
   EnsureTargetLine(targetPrice);

   if(showBuy && hasBuy) EnsureHLine(g_buyLine, buyAvg, BuyLineColor);
   else DeleteIfExists(g_buyLine);

   if(showSell && hasSell) EnsureHLine(g_sellLine, sellAvg, SellLineColor);
   else DeleteIfExists(g_sellLine);

   if(!ShowInfoPanel)
   {
      DeleteIfExists(g_info1);
      DeleteIfExists(g_info2);
      DeleteIfExists(g_info3);
      DeleteIfExists(g_info4);
      DeleteIfExists(g_info5);
      ChartRedraw(0);
      return;
   }

   string mcText = MarginCallPriceText(buyLots, sellLots);

   if(showBuy && hasBuy)
   {
      DrawPanelLine(
         g_info1,
         PanelX,
         PanelY + 36,
         "BUY avg: " + PriceFmt(buyAvg) +
         " | lotti: " + DoubleToString(buyLots, 2) +
         " | ordini: " + IntegerToString(buyCount),
         BuyLineColor
      );
   }
   else
   {
      DrawPanelLine(g_info1, PanelX, PanelY + 36, "BUY avg: -", PanelTextColor);
   }

   if(showSell && hasSell)
   {
      DrawPanelLine(
         g_info2,
         PanelX,
         PanelY + 18,
         "SELL avg: " + PriceFmt(sellAvg) +
         " | lotti: " + DoubleToString(sellLots, 2) +
         " | ordini: " + IntegerToString(sellCount),
         SellLineColor
      );
   }
   else
   {
      DrawPanelLine(g_info2, PanelX, PanelY + 18, "SELL avg: -", PanelTextColor);
   }

   double accountPL = AccountProfit();
   color plColor = PanelTextColor;
   if(accountPL > 0.0) plColor = BuyLineColor;
   else if(accountPL < 0.0) plColor = SellLineColor;

   DrawPanelLine(
      g_info4,
      PanelX,
      PanelY + 54,
      mcText,
      PanelTextColor
   );

   double targetProfit = 0.0, targetLots = 0.0;
   int targetOrders = 0;
   bool hasTargetProjection = CalculateProjectedProfitAtTarget(targetPrice, targetProfit, targetLots, targetOrders);
   color targetColor = PanelTextColor;
   string targetText = "TP line: N/A";
   if(hasTargetProjection)
   {
      if(targetProfit > 0.0) targetColor = BuyLineColor;
      else if(targetProfit < 0.0) targetColor = SellLineColor;
      targetText =
         "TP@" + PriceFmt(targetPrice) +
         " => " + MoneyFmt(targetProfit) +
         " | lotti: " + DoubleToString(targetLots, 2) +
         " | ordini: " + IntegerToString(targetOrders);
   }
   else if(ShowTargetLine && !OnlyCurrentSymbol)
   {
      targetText = "TP line: N/A (OnlyCurrentSymbol=false)";
   }

   DrawPanelLine(
      g_info5,
      PanelX,
      PanelY + 72,
      targetText,
      targetColor
   );

   DrawPanelLine(
      g_info3,
      PanelX,
      PanelY,
      "EQ: " + MoneyFmt(AccountEquity()) +
      " | MG: " + MoneyFmt(AccountMargin()) +
      " | P/L: " + MoneyFmt(accountPL) +
      " | ML: " + MarginLevelFmt(),
      plColor
   );

   ChartRedraw(0);
}

void DeleteAllObjects()
{
   DeleteIfExists(g_buyLine);
   DeleteIfExists(g_sellLine);
   DeleteIfExists(g_info1);
   DeleteIfExists(g_info2);
   DeleteIfExists(g_info3);
   DeleteIfExists(g_info4);
   DeleteIfExists(g_info5);
   DeleteIfExists(g_targetLine);
}

int OnInit()
{
   g_prefix = "AVGLOAD_" + IntegerToString((int)ChartID()) + "_" + Symbol() + "_" + IntegerToString(Period()) + "_";
   g_buyLine = g_prefix + "BUY_LINE";
   g_sellLine = g_prefix + "SELL_LINE";
   g_targetLine = g_prefix + "TARGET_LINE";
   g_info1 = g_prefix + "INFO_1";
   g_info2 = g_prefix + "INFO_2";
   g_info3 = g_prefix + "INFO_3";
   g_info4 = g_prefix + "INFO_4";
   g_info5 = g_prefix + "INFO_5";

   IndicatorShortName("Average Load Price MT4");
   EventSetTimer(MathMax(1, UpdateSeconds));
   UpdateIndicator();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteAllObjects();
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
   UpdateIndicator();
   return(rates_total);
}

void OnTimer()
{
   UpdateIndicator();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE)
   {
      if(sparam == g_targetLine)
         UpdateIndicator();
   }
}

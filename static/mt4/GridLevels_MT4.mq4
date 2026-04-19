#property strict
#property indicator_chart_window
#property indicator_buffers 0

enum EDirection
{
   DIR_BUY  = 0,
   DIR_SELL = 1
};

input double          BasePrice = 0.0;
input EDirection      Direction = DIR_BUY;
input int             StepPips  = 15;
input int             Levels    = 15;
input color           LineColor = clrDodgerBlue;
input int             LineWidth = 3;
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;

string prefix;

double PipSize()
{
   int digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double point = MarketInfo(Symbol(), MODE_POINT);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
}

void DeleteOld()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(name);
   }
}

void DrawLabel(string msg)
{
   string name = prefix + "LABEL";
   if(ObjectFind(name) < 0)
      ObjectCreate(name, OBJ_LABEL, 0, 0, 0);

   ObjectSet(name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSet(name, OBJPROP_XDISTANCE, 10);
   ObjectSet(name, OBJPROP_YDISTANCE, 10);
   ObjectSetText(name, msg, 11, "Arial", clrLime);
}

bool DrawLevelSegment(string name,
                      datetime t1,
                      datetime t2,
                      double price,
                      color clr,
                      int width,
                      ENUM_LINE_STYLE style)
{
   if(ObjectFind(name) < 0)
   {
      if(!ObjectCreate(name, OBJ_TREND, 0, t1, price, t2, price))
         return(false);
   }

   ObjectMove(name, 0, t1, price);
   ObjectMove(name, 1, t2, price);
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_WIDTH, MathMax(1, width));
   ObjectSet(name, OBJPROP_STYLE, style);
   ObjectSet(name, OBJPROP_RAY, false);
   ObjectSet(name, OBJPROP_BACK, false);
   ObjectSet(name, OBJPROP_SELECTABLE, false);
   ObjectSet(name, OBJPROP_SELECTED, false);
   ObjectSet(name, OBJPROP_HIDDEN, false);
   return(true);
}

void DrawLevels(double base)
{
   double pip   = PipSize();
   double step  = StepPips * pip;
   int digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   int bars     = Bars;
   if(step <= 0.0 || bars < 5)
      return;

   int leftBar = WindowFirstVisibleBar();
   if(leftBar < 0)
      leftBar = bars - 1;
   if(leftBar > bars - 1)
      leftBar = bars - 1;

   datetime t1 = Time[leftBar];
   datetime t2 = Time[0];
   if(t1 <= 0 || t2 <= 0 || t2 <= t1)
      return;

   base = NormalizeDouble(base, digits);

   // Prezzo base evidenziato (segmento, non linea infinita)
   DrawLevelSegment(prefix + "BASE", t1, t2, base, clrYellow, 2, STYLE_SOLID);

   for(int i = 1; i <= Levels; i++)
   {
      double price = (Direction == DIR_BUY) ? base - i * step : base + i * step;
      price = NormalizeDouble(price, digits);
      string name = prefix + "L" + IntegerToString(i);
      DrawLevelSegment(name, t1, t2, price, LineColor, LineWidth, LineStyle);
   }
}

double ResolveBasePrice()
{
   if(BasePrice > 0.0)
      return(BasePrice);
   if(Direction == DIR_BUY)
      return(MarketInfo(Symbol(), MODE_BID));
   return(MarketInfo(Symbol(), MODE_ASK));
}

int init()
{
   prefix = "GridLevels_" + Symbol() + "_" + IntegerToString(Period()) + "_";
   DeleteOld();
   IndicatorShortName("Grid Levels MT4");
   return(0);
}

int start()
{
   if(Levels <= 0 || StepPips <= 0)
   {
      DeleteOld();
      return(0);
   }

   double base = ResolveBasePrice();
   DeleteOld();
   DrawLevels(base);

   DrawLabel(
      "GridLevels ON | base=" + DoubleToString(base, Digits) +
      " | step=" + IntegerToString(StepPips) + " pips" +
      " | levels=" + IntegerToString(Levels) +
      " | dir=" + (Direction == DIR_BUY ? "BUY" : "SELL")
   );

   WindowRedraw();
   return(0);
}

int deinit()
{
   DeleteOld();
   return(0);
}

//+------------------------------------------------------------------+
//|                                               BIZ Volatility.mq4 |
//+------------------------------------------------------------------+
#property copyright "Investire.biz"
#property link      "https://investire.biz/"
#property version   "1.00"
#property strict

#property indicator_separate_window
#property indicator_buffers 12

// 0-1: weekly
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// 2-6: daily histogram by weekday
#property indicator_color3  C'255,165,0'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
#property indicator_color4  C'0,204,255'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2
#property indicator_color5  C'0,255,0'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2
#property indicator_color6  C'255,0,255'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2
#property indicator_color7  C'155,2,255'
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

// 7-11: daily average line by weekday
#property indicator_color8  C'255,165,0'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2
#property indicator_color9  C'0,204,255'
#property indicator_style9  STYLE_SOLID
#property indicator_width9  2
#property indicator_color10 C'0,255,0'
#property indicator_style10 STYLE_SOLID
#property indicator_width10 2
#property indicator_color11 C'255,0,255'
#property indicator_style11 STYLE_SOLID
#property indicator_width11 2
#property indicator_color12 C'155,2,255'
#property indicator_style12 STYLE_SOLID
#property indicator_width12 2

// --- Parametri licenza
input string allowedServer = "IG-LIVE";
string       supportEmail  = "info@investire.biz";
datetime     expirationDate = D'2026.04.07 00:00';

// Input
input int   periodo               = 10;
input bool  attLineeGrafiche      = false;
input bool  NotificheSettimanali  = false;
input bool  NotificheGiornaliere  = false;
input color coloreAvgSettimanale  = clrBlue;
input color coloreAvgMonday       = C'255,165,0';
input color coloreAvgTuesday      = C'0,204,255';
input color coloreAvgWednesday    = C'0,255,0';
input color coloreAvgThursday     = C'255,0,255';
input color coloreAvgFriday       = C'155,2,255';

// Buffers
double WeekyRangeBuffer[];
double AvgWeeklyBuffer[];

double DailyMondayBuffer[];
double DailyTuesdayBuffer[];
double DailyWednesdayBuffer[];
double DailyThursdayBuffer[];
double DailyFridayBuffer[];

double AvgDailyMondayBuffer[];
double AvgDailyTuesdayBuffer[];
double AvgDailyWednesdayBuffer[];
double AvgDailyThursdayBuffer[];
double AvgDailyFridayBuffer[];

// Runtime state
double PIP_SIZE = 0.0;
double massimo = 0.0;
double minimo = 0.0;
double massimoWeek = 0.0;
double minimoWeek = 0.0;
int    currentDay = -1;

double livelloMassimoDaily = 0.0;
double livelloMinimoDaily = 0.0;
double livelloMassimoWeek = 0.0;
double livelloMinimoWeek = 0.0;

int allarmeWeekly = 0;
int StatoAllarmeWeekly = 0;
int allarmeDaily = 0;
int StatoAllarmeDaily = 0;

int g_indicatorWindow = 1;

// Storico volatilita completata
double VolatilityMonday[];
double VolatilityTuesday[];
double VolatilityWednesday[];
double VolatilityThursday[];
double VolatilityFriday[];
double VolatilityWeekly[];

// Forward declarations
void   indicatoreScaduto();
double ArrayAverage(double &array[], int count);
bool   ArrowRightPriceCreate(const long chart_ID=0,const string name="EtichettaVI",
                             datetime time=0,double price=0,const color clr=clrRed);
void   ChangeArrowEmptyPoint(datetime &time,double &price);
bool   HLineCreate(const long chart_ID=0,const string name="VIHLine",
                   double price=0,const ENUM_LINE_STYLE stile=STYLE_SOLID,
                   const int width=1,const color clr=clrRed);

void DeleteObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

void UpdateIndicatorWindow()
{
   int wnd = WindowFind("BIZ Volatility");
   if(wnd >= 1)
      g_indicatorWindow = wnd;
   else
      g_indicatorWindow = 1;
}

void AppendValue(double &arr[], const double value)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n] = value;
}

void ClearAllOutputBuffers(const int rates_total)
{
   for(int i = 0; i < rates_total; i++)
   {
      WeekyRangeBuffer[i] = EMPTY_VALUE;
      AvgWeeklyBuffer[i] = EMPTY_VALUE;
      DailyMondayBuffer[i] = EMPTY_VALUE;
      DailyTuesdayBuffer[i] = EMPTY_VALUE;
      DailyWednesdayBuffer[i] = EMPTY_VALUE;
      DailyThursdayBuffer[i] = EMPTY_VALUE;
      DailyFridayBuffer[i] = EMPTY_VALUE;
      AvgDailyMondayBuffer[i] = EMPTY_VALUE;
      AvgDailyTuesdayBuffer[i] = EMPTY_VALUE;
      AvgDailyWednesdayBuffer[i] = EMPTY_VALUE;
      AvgDailyThursdayBuffer[i] = EMPTY_VALUE;
      AvgDailyFridayBuffer[i] = EMPTY_VALUE;
   }
}

void SetDailyWeekdayPlots(const int i, const int dayOfWeek,
                          const double dailyRange, const double dailyAverage)
{
   // Histogram
   if(dayOfWeek == 1) DailyMondayBuffer[i] = dailyRange;
   if(dayOfWeek == 2) DailyTuesdayBuffer[i] = dailyRange;
   if(dayOfWeek == 3) DailyWednesdayBuffer[i] = dailyRange;
   if(dayOfWeek == 4) DailyThursdayBuffer[i] = dailyRange;
   if(dayOfWeek == 5) DailyFridayBuffer[i] = dailyRange;

   // Average line
   if(dayOfWeek == 1) AvgDailyMondayBuffer[i] = dailyAverage;
   if(dayOfWeek == 2) AvgDailyTuesdayBuffer[i] = dailyAverage;
   if(dayOfWeek == 3) AvgDailyWednesdayBuffer[i] = dailyAverage;
   if(dayOfWeek == 4) AvgDailyThursdayBuffer[i] = dailyAverage;
   if(dayOfWeek == 5) AvgDailyFridayBuffer[i] = dailyAverage;
}

double GetAvgWeekdayValue(const int dayOfWeek, const int i)
{
   if(dayOfWeek == 1) return AvgDailyMondayBuffer[i];
   if(dayOfWeek == 2) return AvgDailyTuesdayBuffer[i];
   if(dayOfWeek == 3) return AvgDailyWednesdayBuffer[i];
   if(dayOfWeek == 4) return AvgDailyThursdayBuffer[i];
   if(dayOfWeek == 5) return AvgDailyFridayBuffer[i];
   return EMPTY_VALUE;
}

void SetAvgWeekdayValue(const int dayOfWeek, const int i, const double value)
{
   if(dayOfWeek == 1) AvgDailyMondayBuffer[i] = value;
   if(dayOfWeek == 2) AvgDailyTuesdayBuffer[i] = value;
   if(dayOfWeek == 3) AvgDailyWednesdayBuffer[i] = value;
   if(dayOfWeek == 4) AvgDailyThursdayBuffer[i] = value;
   if(dayOfWeek == 5) AvgDailyFridayBuffer[i] = value;
}

color GetWeekdayColor(const int dayOfWeek)
{
   if(dayOfWeek == 1) return coloreAvgMonday;
   if(dayOfWeek == 2) return coloreAvgTuesday;
   if(dayOfWeek == 3) return coloreAvgWednesday;
   if(dayOfWeek == 4) return coloreAvgThursday;
   if(dayOfWeek == 5) return coloreAvgFriday;
   return clrBlack;
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

int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "BIZ Volatility", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   IndicatorShortName("BIZ Volatility");
   UpdateIndicatorWindow();

   SetIndexStyle(0, DRAW_HISTOGRAM, STYLE_SOLID, 2, clrYellow);
   SetIndexLabel(0, "Weekly Volatility");
   SetIndexBuffer(0, WeekyRangeBuffer);

   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexLabel(1, "Weekly Volatility Average");
   SetIndexBuffer(1, AvgWeeklyBuffer);

   SetIndexStyle(2, DRAW_HISTOGRAM, STYLE_SOLID, 2, coloreAvgMonday);
   SetIndexLabel(2, "Daily Volatility Monday");
   SetIndexBuffer(2, DailyMondayBuffer);

   SetIndexStyle(3, DRAW_HISTOGRAM, STYLE_SOLID, 2, coloreAvgTuesday);
   SetIndexLabel(3, "Daily Volatility Tuesday");
   SetIndexBuffer(3, DailyTuesdayBuffer);

   SetIndexStyle(4, DRAW_HISTOGRAM, STYLE_SOLID, 2, coloreAvgWednesday);
   SetIndexLabel(4, "Daily Volatility Wednesday");
   SetIndexBuffer(4, DailyWednesdayBuffer);

   SetIndexStyle(5, DRAW_HISTOGRAM, STYLE_SOLID, 2, coloreAvgThursday);
   SetIndexLabel(5, "Daily Volatility Thursday");
   SetIndexBuffer(5, DailyThursdayBuffer);

   SetIndexStyle(6, DRAW_HISTOGRAM, STYLE_SOLID, 2, coloreAvgFriday);
   SetIndexLabel(6, "Daily Volatility Friday");
   SetIndexBuffer(6, DailyFridayBuffer);

   SetIndexStyle(7, DRAW_LINE, STYLE_SOLID, 2, coloreAvgMonday);
   SetIndexLabel(7, "Daily Volatility Average Monday");
   SetIndexBuffer(7, AvgDailyMondayBuffer);

   SetIndexStyle(8, DRAW_LINE, STYLE_SOLID, 2, coloreAvgTuesday);
   SetIndexLabel(8, "Daily Volatility Average Tuesday");
   SetIndexBuffer(8, AvgDailyTuesdayBuffer);

   SetIndexStyle(9, DRAW_LINE, STYLE_SOLID, 2, coloreAvgWednesday);
   SetIndexLabel(9, "Daily Volatility Average Wednesday");
   SetIndexBuffer(9, AvgDailyWednesdayBuffer);

   SetIndexStyle(10, DRAW_LINE, STYLE_SOLID, 2, coloreAvgThursday);
   SetIndexLabel(10, "Daily Volatility Average Thursday");
   SetIndexBuffer(10, AvgDailyThursdayBuffer);

   SetIndexStyle(11, DRAW_LINE, STYLE_SOLID, 2, coloreAvgFriday);
   SetIndexLabel(11, "Daily Volatility Average Friday");
   SetIndexBuffer(11, AvgDailyFridayBuffer);

   // Keep MT5 parity: always Point*10 as in the original source.
   PIP_SIZE = Point * 10.0;

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix("BIZExpiredIndicatorText");
   DeleteObjectsByPrefix("VI");
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
   if(rates_total < 2)
      return 0;

   UpdateIndicatorWindow();
   ClearAllOutputBuffers(rates_total);
   int dayByBar[];
   ArrayResize(dayByBar, rates_total);

   ArrayResize(VolatilityMonday, 0);
   ArrayResize(VolatilityTuesday, 0);
   ArrayResize(VolatilityWednesday, 0);
   ArrayResize(VolatilityThursday, 0);
   ArrayResize(VolatilityFriday, 0);
   ArrayResize(VolatilityWeekly, 0);

   allarmeWeekly = 0;
   StatoAllarmeWeekly = 0;
   allarmeDaily = 0;
   StatoAllarmeDaily = 0;

   // In MT4 these arrays are timeseries (0 = current bar), so process oldest -> newest.
   int oldest = rates_total - 1;
   currentDay = TimeDayOfWeek(time[oldest]);
   massimo = high[oldest];
   minimo = low[oldest];
   massimoWeek = high[oldest];
   minimoWeek = low[oldest];
   dayByBar[oldest] = currentDay;

   for(int i = oldest - 1; i >= 0; i--)
   {
      int dayOfWeek = TimeDayOfWeek(time[i]);

      if(dayOfWeek != currentDay)
      {
         double daily_range = MathRound((massimo - minimo) / PIP_SIZE);
         double weekly_range = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

         switch(currentDay)
         {
            case 1: AppendValue(VolatilityMonday, daily_range); break;
            case 2: AppendValue(VolatilityTuesday, daily_range); break;
            case 3: AppendValue(VolatilityWednesday, daily_range); break;
            case 4: AppendValue(VolatilityThursday, daily_range); break;
            case 5:
               AppendValue(VolatilityFriday, daily_range);
               AppendValue(VolatilityWeekly, weekly_range);
               massimoWeek = high[i];
               minimoWeek = low[i];
               break;
            default: break; // 0 and 6 ignored
         }

         currentDay = dayOfWeek;
         massimo = high[i];
         minimo = low[i];

         if(high[i] > massimoWeek) massimoWeek = high[i];
         if(low[i] < minimoWeek) minimoWeek = low[i];
      }
      else
      {
         if(high[i] > massimo) massimo = high[i];
         if(low[i] < minimo) minimo = low[i];
         if(high[i] > massimoWeek) massimoWeek = high[i];
         if(low[i] < minimoWeek) minimoWeek = low[i];
      }

      double dailyRange = MathRound((massimo - minimo) / PIP_SIZE);
      double weeklyRange = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);
      double avgWeekly = MathRound(ArrayAverage(VolatilityWeekly, MathMin(periodo, ArraySize(VolatilityWeekly))));

      double avgMon = MathRound(ArrayAverage(VolatilityMonday, MathMin(periodo, ArraySize(VolatilityMonday))));
      double avgTue = MathRound(ArrayAverage(VolatilityTuesday, MathMin(periodo, ArraySize(VolatilityTuesday))));
      double avgWed = MathRound(ArrayAverage(VolatilityWednesday, MathMin(periodo, ArraySize(VolatilityWednesday))));
      double avgThu = MathRound(ArrayAverage(VolatilityThursday, MathMin(periodo, ArraySize(VolatilityThursday))));
      double avgFri = MathRound(ArrayAverage(VolatilityFriday, MathMin(periodo, ArraySize(VolatilityFriday))));

      double currentAverage = 0.0;
      switch(currentDay)
      {
         case 1: currentAverage = avgMon; break;
         case 2: currentAverage = avgTue; break;
         case 3: currentAverage = avgWed; break;
         case 4: currentAverage = avgThu; break;
         case 5: currentAverage = avgFri; break;
         default: currentAverage = 0.0; break;
      }
      color labelColor = GetWeekdayColor(currentDay);
      dayByBar[i] = currentDay;

      WeekyRangeBuffer[i] = weeklyRange;
      AvgWeeklyBuffer[i] = avgWeekly;
      SetDailyWeekdayPlots(i, currentDay, dailyRange, currentAverage);

      if(avgWeekly > 0.0)
      {
         if(weeklyRange < avgWeekly)
         {
            livelloMassimoWeek = minimoWeek + avgWeekly * PIP_SIZE;
            livelloMinimoWeek = massimoWeek - avgWeekly * PIP_SIZE;
            StatoAllarmeWeekly = 0;
            allarmeWeekly = 0;
         }
         else
         {
            if(StatoAllarmeWeekly == 0)
               allarmeWeekly = 1;
            StatoAllarmeWeekly = 1;
         }
      }

      if(currentAverage > 0.0)
      {
         if(currentAverage > dailyRange)
         {
            livelloMassimoDaily = minimo + currentAverage * PIP_SIZE;
            livelloMinimoDaily = massimo - currentAverage * PIP_SIZE;
            StatoAllarmeDaily = 0;
            allarmeDaily = 0;
         }
         else
         {
            if(StatoAllarmeDaily == 0)
               allarmeDaily = 1;
            StatoAllarmeDaily = 1;
         }
      }

      // Latest bar for MT4 timeseries.
      if(i == 0)
      {
         ArrowRightPriceCreate(0, "VIEtichettaWeekly", time[0], avgWeekly, coloreAvgSettimanale);
         ArrowRightPriceCreate(0, "VIEtichettaDaily", time[0], currentAverage, labelColor);

         if(attLineeGrafiche)
         {
            HLineCreate(0, "VIHLine1Weekly", livelloMassimoWeek, STYLE_SOLID, 2, coloreAvgSettimanale);
            HLineCreate(0, "VIHLine2Weekly", livelloMinimoWeek, STYLE_SOLID, 2, coloreAvgSettimanale);
            HLineCreate(0, "VIHLine1", livelloMassimoDaily, STYLE_SOLID, 2, labelColor);
            HLineCreate(0, "VIHLine2", livelloMinimoDaily, STYLE_SOLID, 2, labelColor);
         }
         else
         {
            ObjectDelete(0, "VIHLine1Weekly");
            ObjectDelete(0, "VIHLine2Weekly");
            ObjectDelete(0, "VIHLine1");
            ObjectDelete(0, "VIHLine2");
         }

         if(NotificheSettimanali && allarmeWeekly == 1)
         {
            string weeklyMessage = "Volatilita media settimanale superata su " + Symbol();
            Alert(weeklyMessage);
            SendNotification(weeklyMessage);
            allarmeWeekly = 0;
         }

         if(NotificheGiornaliere && allarmeDaily == 1)
         {
            string dailyMessage = "Volatilita media giornaliera superata su " + Symbol();
            Alert(dailyMessage);
            SendNotification(dailyMessage);
            allarmeDaily = 0;
         }
      }
   }

   // Bridge weekday transitions so the colored daily average line
   // behaves like MT5 DRAW_COLOR_LINE (continuous line with color shifts).
   for(int i = rates_total - 2; i >= 0; i--)
   {
      int olderDay = dayByBar[i + 1];
      int newerDay = dayByBar[i];

      if(olderDay >= 1 && olderDay <= 5 && newerDay >= 1 && newerDay <= 5 && olderDay != newerDay)
      {
         double newerAvg = GetAvgWeekdayValue(newerDay, i);
         double olderAvg = GetAvgWeekdayValue(olderDay, i + 1);

         if(newerAvg != EMPTY_VALUE)
            SetAvgWeekdayValue(olderDay, i, newerAvg);
         if(olderAvg != EMPTY_VALUE)
            SetAvgWeekdayValue(newerDay, i + 1, olderAvg);
      }
   }

   ChartRedraw(0);
   return rates_total;
}

void indicatoreScaduto()
{
   long chart_width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long center_x = chart_width / 2;
   long center_y = chart_height / 2;

   string messageLine1 = "La licenza per l'indicatore e scaduta.";
   string messageLine2 = "Per informazioni contatta info@investire.biz";
   Print("La licenza per l'indicatore e scaduta. Per informazioni contatta info@investire.biz");

   ObjectCreate(0, "BIZExpiredIndicatorText", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "BIZExpiredIndicatorText", OBJPROP_TEXT, messageLine1);
   ObjectSetInteger(0, "BIZExpiredIndicatorText", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "BIZExpiredIndicatorText", OBJPROP_YDISTANCE, center_y);
   ObjectSetInteger(0, "BIZExpiredIndicatorText", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "BIZExpiredIndicatorText", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "BIZExpiredIndicatorText", OBJPROP_ANCHOR, ANCHOR_CENTER);

   ObjectCreate(0, "BIZExpiredIndicatorText2", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "BIZExpiredIndicatorText2", OBJPROP_TEXT, messageLine2);
   ObjectSetInteger(0, "BIZExpiredIndicatorText2", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "BIZExpiredIndicatorText2", OBJPROP_YDISTANCE, center_y + 30);
   ObjectSetInteger(0, "BIZExpiredIndicatorText2", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "BIZExpiredIndicatorText2", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "BIZExpiredIndicatorText2", OBJPROP_ANCHOR, ANCHOR_CENTER);
}

double ArrayAverage(double &array[], int count)
{
   if(count <= 0 || ArraySize(array) == 0)
      return 0.0;

   count = MathMin(count, ArraySize(array));

   double sum = 0.0;
   for(int i = ArraySize(array) - count; i < ArraySize(array); i++)
      sum += array[i];

   return sum / count;
}

bool ArrowRightPriceCreate(const long chart_ID,
                           const string name,
                           datetime time,
                           double price,
                           const color clr)
{
   ChangeArrowEmptyPoint(time, price);
   if(ObjectFind(chart_ID, name) >= 0)
      ObjectDelete(chart_ID, name);

   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_ARROW_RIGHT_PRICE, g_indicatorWindow, time, price))
   {
      Print(__FUNCTION__, ": failed creating right-price label. Error=", GetLastError());
      return false;
   }

   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, 0);
   return true;
}

void ChangeArrowEmptyPoint(datetime &time,double &price)
{
   if(!time)
      time = TimeCurrent();
   if(!price)
      price = Bid;
}

bool HLineCreate(const long chart_ID,
                 const string name,
                 double price,
                 const ENUM_LINE_STYLE stile,
                 const int width,
                 const color clr)
{
   if(!price)
      price = Bid;

   if(ObjectFind(chart_ID, name) >= 0)
      ObjectDelete(chart_ID, name);

   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_HLINE, g_indicatorWindow, 0, price))
   {
      Print(__FUNCTION__, ": failed creating horizontal line. Error=", GetLastError());
      return false;
   }

   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, stile);
   ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, 0);
   return true;
}

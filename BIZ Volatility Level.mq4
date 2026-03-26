//+------------------------------------------------------------------+
//|                                         BIZ Volatility Level.mq4 |
//|                                                    Investire.biz |
//|                                           https://investire.biz/ |
//+------------------------------------------------------------------+
#property strict
#property copyright "Investire.biz"
#property link      "https://investire.biz/"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 12

// Weekly lines
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2
#property indicator_color2 clrBlue
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2

// Daily HIGH lines split by weekday
#property indicator_color3 C'255,165,0'   // Monday
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2
#property indicator_color4 C'0,204,255'   // Tuesday
#property indicator_style4 STYLE_SOLID
#property indicator_width4 2
#property indicator_color5 C'0,255,0'     // Wednesday
#property indicator_style5 STYLE_SOLID
#property indicator_width5 2
#property indicator_color6 C'255,0,255'   // Thursday
#property indicator_style6 STYLE_SOLID
#property indicator_width6 2
#property indicator_color7 C'155,2,255'   // Friday
#property indicator_style7 STYLE_SOLID
#property indicator_width7 2

// Daily LOW lines split by weekday
#property indicator_color8 C'255,165,0'   // Monday
#property indicator_style8 STYLE_SOLID
#property indicator_width8 2
#property indicator_color9 C'0,204,255'   // Tuesday
#property indicator_style9 STYLE_SOLID
#property indicator_width9 2
#property indicator_color10 C'0,255,0'    // Wednesday
#property indicator_style10 STYLE_SOLID
#property indicator_width10 2
#property indicator_color11 C'255,0,255'  // Thursday
#property indicator_style11 STYLE_SOLID
#property indicator_width11 2
#property indicator_color12 C'155,2,255'  // Friday
#property indicator_style12 STYLE_SOLID
#property indicator_width12 2

// --- Parametri licenza
input string allowedServer = "IG-LIVE";            // Nome del server autorizzato
string       supportEmail  = "info@investire.biz"; // Email supporto
datetime     expirationDate = D'2026.04.07 00:00';

// Input
input int   periodo              = 10;             // Period
input bool  NotificheSettimanali = false;          // Weekly notification
input bool  NotificheGiornaliere = false;          // Daily notification
input color coloreAvgSettimanale = clrBlue;        // Weekly levels color
input color coloreAvgMonday      = C'255,165,0';   // Monday levels color
input color coloreAvgTuesday     = C'0,204,255';   // Tuesday levels color
input color coloreAvgWednesday   = C'0,255,0';     // Wednesday levels color
input color coloreAvgThursday    = C'255,0,255';   // Thursday levels color
input color coloreAvgFriday      = C'155,2,255';   // Friday levels color

// Indicator buffers
double HighAvgWeeklyBuffer[];
double LowAvgWeeklyBuffer[];
double HighAvgDailyMonBuffer[];
double HighAvgDailyTueBuffer[];
double HighAvgDailyWedBuffer[];
double HighAvgDailyThuBuffer[];
double HighAvgDailyFriBuffer[];
double LowAvgDailyMonBuffer[];
double LowAvgDailyTueBuffer[];
double LowAvgDailyWedBuffer[];
double LowAvgDailyThuBuffer[];
double LowAvgDailyFriBuffer[];

// Working values
double WeekyRangeBuffer;
double DailyRangeBuffer;
double AvgWeeklyBuffer;
double AvgMondayBuffer;
double AvgTuesdayBuffer;
double AvgWednesdayBuffer;
double AvgThursdayBuffer;
double AvgFridayBuffer;
double LastHighDailyLevel;
double LastLowDailyLevel;

// PIP size
double PIP_SIZE;

// Current extrema
double massimo;
double minimo;
double massimoWeek;
double minimoWeek;
int    currentDay = -1;

// Historical vol arrays
double VolatilityMonday[];
double VolatilityTuesday[];
double VolatilityWednesday[];
double VolatilityThursday[];
double VolatilityFriday[];
double VolatilityWeekly[];

int allarmeWeekly      = 0;
int StatoAllarmeWeekly = 0;
int allarmeDaily       = 0;
int StatoAllarmeDaily  = 0;

//+------------------------------------------------------------------+
//| License check (date + server)                                    |
//+------------------------------------------------------------------+
bool CheckLicenseLocal(const datetime expiration,
                       const string pSupportEmail,
                       const string productName,
                       const string labelId,
                       const string pAllowedServer)
{
   datetime now = TimeCurrent();
   bool date_ok = (now <= expiration);
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

//+------------------------------------------------------------------+
//| Utility                                                           |
//+------------------------------------------------------------------+
void ClearDailyBuffersAt(const int i)
{
   HighAvgDailyMonBuffer[i] = EMPTY_VALUE;
   HighAvgDailyTueBuffer[i] = EMPTY_VALUE;
   HighAvgDailyWedBuffer[i] = EMPTY_VALUE;
   HighAvgDailyThuBuffer[i] = EMPTY_VALUE;
   HighAvgDailyFriBuffer[i] = EMPTY_VALUE;
   LowAvgDailyMonBuffer[i]  = EMPTY_VALUE;
   LowAvgDailyTueBuffer[i]  = EMPTY_VALUE;
   LowAvgDailyWedBuffer[i]  = EMPTY_VALUE;
   LowAvgDailyThuBuffer[i]  = EMPTY_VALUE;
   LowAvgDailyFriBuffer[i]  = EMPTY_VALUE;
}

void SetDailyBuffersAt(const int i, const int weekday, const double highLevel, const double lowLevel)
{
   ClearDailyBuffersAt(i);
   switch(weekday)
   {
      case 1:
         HighAvgDailyMonBuffer[i] = highLevel;
         LowAvgDailyMonBuffer[i] = lowLevel;
         break;
      case 2:
         HighAvgDailyTueBuffer[i] = highLevel;
         LowAvgDailyTueBuffer[i] = lowLevel;
         break;
      case 3:
         HighAvgDailyWedBuffer[i] = highLevel;
         LowAvgDailyWedBuffer[i] = lowLevel;
         break;
      case 4:
         HighAvgDailyThuBuffer[i] = highLevel;
         LowAvgDailyThuBuffer[i] = lowLevel;
         break;
      case 5:
         HighAvgDailyFriBuffer[i] = highLevel;
         LowAvgDailyFriBuffer[i] = lowLevel;
         break;
      default:
         break;
   }
}

double GetPrevDailyHighLevel(const int i)
{
   if(i <= 0)
      return 0.0;
   if(HighAvgDailyMonBuffer[i - 1] != EMPTY_VALUE) return HighAvgDailyMonBuffer[i - 1];
   if(HighAvgDailyTueBuffer[i - 1] != EMPTY_VALUE) return HighAvgDailyTueBuffer[i - 1];
   if(HighAvgDailyWedBuffer[i - 1] != EMPTY_VALUE) return HighAvgDailyWedBuffer[i - 1];
   if(HighAvgDailyThuBuffer[i - 1] != EMPTY_VALUE) return HighAvgDailyThuBuffer[i - 1];
   if(HighAvgDailyFriBuffer[i - 1] != EMPTY_VALUE) return HighAvgDailyFriBuffer[i - 1];
   return 0.0;
}

double GetPrevDailyLowLevel(const int i)
{
   if(i <= 0)
      return 0.0;
   if(LowAvgDailyMonBuffer[i - 1] != EMPTY_VALUE) return LowAvgDailyMonBuffer[i - 1];
   if(LowAvgDailyTueBuffer[i - 1] != EMPTY_VALUE) return LowAvgDailyTueBuffer[i - 1];
   if(LowAvgDailyWedBuffer[i - 1] != EMPTY_VALUE) return LowAvgDailyWedBuffer[i - 1];
   if(LowAvgDailyThuBuffer[i - 1] != EMPTY_VALUE) return LowAvgDailyThuBuffer[i - 1];
   if(LowAvgDailyFriBuffer[i - 1] != EMPTY_VALUE) return LowAvgDailyFriBuffer[i - 1];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "BIZ Volatility Level", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   SetIndexBuffer(0, HighAvgWeeklyBuffer);
   SetIndexBuffer(1, LowAvgWeeklyBuffer);
   SetIndexBuffer(2, HighAvgDailyMonBuffer);
   SetIndexBuffer(3, HighAvgDailyTueBuffer);
   SetIndexBuffer(4, HighAvgDailyWedBuffer);
   SetIndexBuffer(5, HighAvgDailyThuBuffer);
   SetIndexBuffer(6, HighAvgDailyFriBuffer);
   SetIndexBuffer(7, LowAvgDailyMonBuffer);
   SetIndexBuffer(8, LowAvgDailyTueBuffer);
   SetIndexBuffer(9, LowAvgDailyWedBuffer);
   SetIndexBuffer(10, LowAvgDailyThuBuffer);
   SetIndexBuffer(11, LowAvgDailyFriBuffer);

   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 2, coloreAvgMonday);
   SetIndexStyle(3, DRAW_LINE, STYLE_SOLID, 2, coloreAvgTuesday);
   SetIndexStyle(4, DRAW_LINE, STYLE_SOLID, 2, coloreAvgWednesday);
   SetIndexStyle(5, DRAW_LINE, STYLE_SOLID, 2, coloreAvgThursday);
   SetIndexStyle(6, DRAW_LINE, STYLE_SOLID, 2, coloreAvgFriday);
   SetIndexStyle(7, DRAW_LINE, STYLE_SOLID, 2, coloreAvgMonday);
   SetIndexStyle(8, DRAW_LINE, STYLE_SOLID, 2, coloreAvgTuesday);
   SetIndexStyle(9, DRAW_LINE, STYLE_SOLID, 2, coloreAvgWednesday);
   SetIndexStyle(10, DRAW_LINE, STYLE_SOLID, 2, coloreAvgThursday);
   SetIndexStyle(11, DRAW_LINE, STYLE_SOLID, 2, coloreAvgFriday);

   SetIndexLabel(0, "High Weekly Volatility Average");
   SetIndexLabel(1, "Low Weekly Volatility Average");
   SetIndexLabel(2, "High Daily Volatility Average (Mon)");
   SetIndexLabel(3, "High Daily Volatility Average (Tue)");
   SetIndexLabel(4, "High Daily Volatility Average (Wed)");
   SetIndexLabel(5, "High Daily Volatility Average (Thu)");
   SetIndexLabel(6, "High Daily Volatility Average (Fri)");
   SetIndexLabel(7, "Low Daily Volatility Average (Mon)");
   SetIndexLabel(8, "Low Daily Volatility Average (Tue)");
   SetIndexLabel(9, "Low Daily Volatility Average (Wed)");
   SetIndexLabel(10, "Low Daily Volatility Average (Thu)");
   SetIndexLabel(11, "Low Daily Volatility Average (Fri)");

   for(int b = 0; b < 12; b++)
      SetIndexEmptyValue(b, EMPTY_VALUE);

   PIP_SIZE = MarketInfo(Symbol(), MODE_POINT) * 10.0;

   ArrayResize(VolatilityMonday, 0);
   ArrayResize(VolatilityTuesday, 0);
   ArrayResize(VolatilityWednesday, 0);
   ArrayResize(VolatilityThursday, 0);
   ArrayResize(VolatilityFriday, 0);
   ArrayResize(VolatilityWeekly, 0);

   LastHighDailyLevel = 0.0;
   LastLowDailyLevel = 0.0;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "BIZExpiredIndicatorText");
   ObjectDelete(0, "BIZExpiredIndicatorText2");
   ObjectDelete(0, "prezziVIEtichettaWeeklyHigh");
   ObjectDelete(0, "prezziVIEtichettaWeeklyLow");
   ObjectDelete(0, "prezziVIEtichettaDailyHigh");
   ObjectDelete(0, "prezziVIEtichettaDailyLow");
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
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
   if(rates_total <= 0)
      return 0;

   int start = prev_calculated;
   if(start == 0)
   {
      start = 1; // i-1 safe
      currentDay = TimeDayOfWeek(time[0]);
      massimo = high[0];
      minimo = low[0];
      massimoWeek = high[0];
      minimoWeek = low[0];
      ClearDailyBuffersAt(0);
      HighAvgWeeklyBuffer[0] = EMPTY_VALUE;
      LowAvgWeeklyBuffer[0] = EMPTY_VALUE;
   }

   for(int i = start; i < rates_total; i++)
   {
      int dayOfWeek = TimeDayOfWeek(time[i]);

      if(dayOfWeek != currentDay)
      {
         double daily_range = MathRound((massimo - minimo) / PIP_SIZE);
         double weekly_range = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

         switch(currentDay)
         {
            case 1: // Monday
               ArrayResize(VolatilityMonday, ArraySize(VolatilityMonday) + 1);
               VolatilityMonday[ArraySize(VolatilityMonday) - 1] = daily_range;
               break;
            case 2: // Tuesday
               ArrayResize(VolatilityTuesday, ArraySize(VolatilityTuesday) + 1);
               VolatilityTuesday[ArraySize(VolatilityTuesday) - 1] = daily_range;
               break;
            case 3: // Wednesday
               ArrayResize(VolatilityWednesday, ArraySize(VolatilityWednesday) + 1);
               VolatilityWednesday[ArraySize(VolatilityWednesday) - 1] = daily_range;
               break;
            case 4: // Thursday
               ArrayResize(VolatilityThursday, ArraySize(VolatilityThursday) + 1);
               VolatilityThursday[ArraySize(VolatilityThursday) - 1] = daily_range;
               break;
            case 5: // Friday
               ArrayResize(VolatilityFriday, ArraySize(VolatilityFriday) + 1);
               VolatilityFriday[ArraySize(VolatilityFriday) - 1] = daily_range;
               ArrayResize(VolatilityWeekly, ArraySize(VolatilityWeekly) + 1);
               VolatilityWeekly[ArraySize(VolatilityWeekly) - 1] = weekly_range;
               massimoWeek = high[i];
               minimoWeek = low[i];
               break;
            default:
               break;
         }

         currentDay = dayOfWeek;
         massimo = high[i];
         minimo = low[i];
      }
      else
      {
         if(high[i] > massimo) massimo = high[i];
         if(low[i] < minimo) minimo = low[i];
      }

      if(high[i] > massimoWeek) massimoWeek = high[i];
      if(low[i] < minimoWeek) minimoWeek = low[i];

      DailyRangeBuffer = MathRound((massimo - minimo) / PIP_SIZE);
      WeekyRangeBuffer = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

      AvgWeeklyBuffer = MathRound(ArrayAverage(VolatilityWeekly, MathMin(periodo, ArraySize(VolatilityWeekly))));
      AvgMondayBuffer = MathRound(ArrayAverage(VolatilityMonday, MathMin(periodo, ArraySize(VolatilityMonday))));
      AvgTuesdayBuffer = MathRound(ArrayAverage(VolatilityTuesday, MathMin(periodo, ArraySize(VolatilityTuesday))));
      AvgWednesdayBuffer = MathRound(ArrayAverage(VolatilityWednesday, MathMin(periodo, ArraySize(VolatilityWednesday))));
      AvgThursdayBuffer = MathRound(ArrayAverage(VolatilityThursday, MathMin(periodo, ArraySize(VolatilityThursday))));
      AvgFridayBuffer = MathRound(ArrayAverage(VolatilityFriday, MathMin(periodo, ArraySize(VolatilityFriday))));

      double currentAverage = 0.0;
      color labelColor = clrBlack;
      switch(currentDay)
      {
         case 1: currentAverage = AvgMondayBuffer; labelColor = coloreAvgMonday; break;
         case 2: currentAverage = AvgTuesdayBuffer; labelColor = coloreAvgTuesday; break;
         case 3: currentAverage = AvgWednesdayBuffer; labelColor = coloreAvgWednesday; break;
         case 4: currentAverage = AvgThursdayBuffer; labelColor = coloreAvgThursday; break;
         case 5: currentAverage = AvgFridayBuffer; labelColor = coloreAvgFriday; break;
         default: break;
      }

      double livelloHighWeek = 0.0;
      double livelloLowWeek = 0.0;
      if(AvgWeeklyBuffer > 0.0)
      {
         if(WeekyRangeBuffer < AvgWeeklyBuffer)
         {
            livelloHighWeek = minimoWeek + AvgWeeklyBuffer * PIP_SIZE;
            livelloLowWeek = massimoWeek - AvgWeeklyBuffer * PIP_SIZE;
            StatoAllarmeWeekly = 0;
            allarmeWeekly = 0;
         }
         else
         {
            livelloHighWeek = (i > 0 ? HighAvgWeeklyBuffer[i - 1] : massimoWeek);
            livelloLowWeek = (i > 0 ? LowAvgWeeklyBuffer[i - 1] : minimoWeek);
            if(StatoAllarmeWeekly == 0) allarmeWeekly = 1;
            StatoAllarmeWeekly = 1;
         }
      }
      else
      {
         livelloHighWeek = massimoWeek;
         livelloLowWeek = minimoWeek;
      }

      HighAvgWeeklyBuffer[i] = livelloHighWeek;
      LowAvgWeeklyBuffer[i] = livelloLowWeek;

      double livelloHighDay = 0.0;
      double livelloLowDay = 0.0;
      if(currentAverage > 0.0)
      {
         if(currentAverage > DailyRangeBuffer)
         {
            livelloHighDay = minimo + currentAverage * PIP_SIZE;
            livelloLowDay = massimo - currentAverage * PIP_SIZE;
            StatoAllarmeDaily = 0;
            allarmeDaily = 0;
         }
         else
         {
            livelloHighDay = GetPrevDailyHighLevel(i);
            livelloLowDay = GetPrevDailyLowLevel(i);
            if(livelloHighDay == 0.0) livelloHighDay = LastHighDailyLevel;
            if(livelloLowDay == 0.0) livelloLowDay = LastLowDailyLevel;
            if(StatoAllarmeDaily == 0) allarmeDaily = 1;
            StatoAllarmeDaily = 1;
         }
      }
      else
      {
         livelloHighDay = massimo;
         livelloLowDay = minimo;
      }

      LastHighDailyLevel = livelloHighDay;
      LastLowDailyLevel = livelloLowDay;
      SetDailyBuffersAt(i, currentDay, livelloHighDay, livelloLowDay);

      if(i == rates_total - 1)
      {
         string labelNameWeekHigh = "prezziVIEtichettaWeeklyHigh";
         string labelNameWeekLow = "prezziVIEtichettaWeeklyLow";
         ObjectDelete(0, labelNameWeekHigh);
         ObjectDelete(0, labelNameWeekLow);
         ArrowRightPriceCreate(0, labelNameWeekHigh, time[i], HighAvgWeeklyBuffer[i], coloreAvgSettimanale);
         ArrowRightPriceCreate(0, labelNameWeekLow, time[i], LowAvgWeeklyBuffer[i], coloreAvgSettimanale);

         string labelNameDayHigh = "prezziVIEtichettaDailyHigh";
         string labelNameDayLow = "prezziVIEtichettaDailyLow";
         ObjectDelete(0, labelNameDayHigh);
         ObjectDelete(0, labelNameDayLow);
         ArrowRightPriceCreate(0, labelNameDayHigh, time[i], livelloHighDay, labelColor);
         ArrowRightPriceCreate(0, labelNameDayLow, time[i], livelloLowDay, labelColor);

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
         ChartRedraw();
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| FUNZIONE INDICATORE SCADUTO                                      |
//+------------------------------------------------------------------+
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

//+--------------------------------------------------------------------------------+
//| Function to calculate average of an array                                      |
//+--------------------------------------------------------------------------------+
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

//+--------------------------------------------------------------------------------+
//| Crea l'etichetta prezzo a destra                                               |
//+--------------------------------------------------------------------------------+
bool ArrowRightPriceCreate(const long chart_ID = 0,
                           const string name = "EtichettaVI",
                           datetime time = 0,
                           double price = 0,
                           const color clr = clrRed)
{
   ChangeArrowEmptyPoint(time, price);
   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_ARROW_RIGHT_PRICE, 0, time, price))
   {
      Print(__FUNCTION__, ": fallimento nella creazione dell'etichetta prezzo a destra! Error code = ", GetLastError());
      return(false);
   }
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, 0);
   return(true);
}

//+--------------------------------------------------------------------------------+
//| Imposta valori default per punti vuoti                                         |
//+--------------------------------------------------------------------------------+
void ChangeArrowEmptyPoint(datetime &time, double &price)
{
   if(!time)
      time = TimeCurrent();
   if(!price)
      price = MarketInfo(Symbol(), MODE_BID);
}

//+------------------------------------------------------------------+
//|                                         BIZ Volatility Level.mq4 |
//|                                                    Investire.biz |
//|                                           https://investire.biz/ |
//+------------------------------------------------------------------+
#property strict
#property copyright "Investire.biz"
#property link      "https://investire.biz/"
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 4

// plot Volatilita settimanale
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2

// plot Volatilita settimanale
#property indicator_color2 clrBlue
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2

// plot medie di volatilita giornaliera
#property indicator_color3 clrNONE
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2

#property indicator_color4 clrNONE
#property indicator_style4 STYLE_SOLID
#property indicator_width4 2

// --- Parametri licenza
input string allowedServer = "IG-LIVE";            // Nome del server autorizzato
string       supportEmail  = "info@investire.biz"; // Email supporto
datetime     expirationDate = D'2026.04.07 00:00';

// Input variable for period to calculate average volatility
input int   periodo              = 10;            // Period
input bool  NotificheSettimanali = false;         // Weekly Notification
input bool  NotificheGiornaliere = false;         // Daily Notification
input color coloreAvgSettimanale = clrBlue;       // Weekly Range Average
input color coloreAvgMonday      = C'255,165,0';  // Monday Range Average
input color coloreAvgTuesday     = C'0,204,255';  // Tuesday Range Average
input color coloreAvgWednesday   = C'0,255,0';    // Wednesday Range Average
input color coloreAvgThursday    = C'255,0,255';  // Thursday Range Average
input color coloreAvgFriday      = C'155,2,255';  // Friday Range Average

//--- indicator buffers (calcolo)
double HighAvgWeeklyBuffer[];
double LowAvgWeeklyBuffer[];
double HighAvgDailyBuffer[];
double LowAvgDailyBuffer[];

double WeekyRangeBuffer;
double DailyRangeBuffer;
double AvgWeeklyBuffer;

double AvgMondayBuffer;
double AvgTuesdayBuffer;
double AvgWednesdayBuffer;
double AvgThursdayBuffer;
double AvgFridayBuffer;

//--- PIP_SIZE variable
double PIP_SIZE;

//--- Variables for daily high and low
double massimo;
double minimo;
double massimoWeek;
double minimoWeek;
int currentDay = -1;

//--- Arrays for storing daily volatility by day of the week
double VolatilityMonday[];
double VolatilityTuesday[];
double VolatilityWednesday[];
double VolatilityThursday[];
double VolatilityFriday[];
double VolatilityWeekly[];

int allarmeWeekly = 0;
int StatoAllarmeWeekly = 0;
int allarmeDaily = 0;
int StatoAllarmeDaily = 0;

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
   bool date_ok   = (now <= expiration);
   bool server_ok = (AccountServer() == pAllowedServer);

   if(date_ok && server_ok) return true;

   string msg1 = "Licenza " + productName + " scaduta o non valida per questo server.";
   string msg2 = "Contatta: " + pSupportEmail + " per una versione aggiornata.";
   string fullMsg = msg1 + " " + msg2;

   Print(fullMsg);
   MessageBox(fullMsg, "Errore Licenza", MB_OK | MB_ICONERROR);

   string labelIdLocal = (labelId=="" ? "BIZExpiredIndicatorText" : labelId);
   if(ObjectFind(0, labelIdLocal) < 0)
      ObjectCreate(0, labelIdLocal, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_YDISTANCE, 20);
   ObjectSetString (0, labelIdLocal, OBJPROP_TEXT, fullMsg);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, labelIdLocal, OBJPROP_FONTSIZE, 14);
   ObjectSetString (0, labelIdLocal, OBJPROP_FONT, "Arial");

   return false;
}

//+------------------------------------------------------------------+
//| Utility                                                          |
//+------------------------------------------------------------------+
color DayColor(const int dayOfWeek)
{
   switch(dayOfWeek)
   {
      case 1: return coloreAvgMonday;
      case 2: return coloreAvgTuesday;
      case 3: return coloreAvgWednesday;
      case 4: return coloreAvgThursday;
      case 5: return coloreAvgFriday;
      default: return clrBlack;
   }
}

void EnsureTrendLine(const string name, const color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_RAY, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void DrawSegment(const string prefix, const int i, const datetime &time[], const double v1, const double v2, const color clr)
{
   if(i <= 0) return;
   string name = prefix + IntegerToString(i);
   EnsureTrendLine(name, clr);
   ObjectMove(0, name, 0, time[i-1], v1);
   ObjectMove(0, name, 1, time[i],   v2);
}

void ClearDailySegments()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int j = total - 1; j >= 0; j--)
   {
      string name = ObjectName(0, j);
      if(StringFind(name, "BIZ_DAILY_H_") == 0 || StringFind(name, "BIZ_DAILY_L_") == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
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
   SetIndexBuffer(2, HighAvgDailyBuffer);
   SetIndexBuffer(3, LowAvgDailyBuffer);

   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(2, DRAW_NONE);
   SetIndexStyle(3, DRAW_NONE);

   SetIndexLabel(0, "High Weekly Volatility Average");
   SetIndexLabel(1, "Low Weekly Volatility Average");
   SetIndexLabel(2, "High Daily Volatility Average");
   SetIndexLabel(3, "Low Daily Volatility Average");

   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexEmptyValue(2, EMPTY_VALUE);
   SetIndexEmptyValue(3, EMPTY_VALUE);

   // --- Determine the PIP_SIZE based on the current symbol
   PIP_SIZE = MarketInfo(Symbol(), MODE_POINT) * 10.0;

   // Initialize arrays
   ArrayResize(VolatilityMonday, 0);
   ArrayResize(VolatilityTuesday, 0);
   ArrayResize(VolatilityWednesday, 0);
   ArrayResize(VolatilityThursday, 0);
   ArrayResize(VolatilityFriday, 0);
   ArrayResize(VolatilityWeekly, 0);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| FUNZIONE DI DEINIZIALIZZAZIONE                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "BIZExpiredIndicatorText");
   ObjectDelete(0, "BIZExpiredIndicatorText2");
   ObjectDelete(0, "prezziVIEtichettaWeeklyHigh");
   ObjectDelete(0, "prezziVIEtichettaWeeklyLow");
   ObjectDelete(0, "prezziVIEtichettaDailyHigh");
   ObjectDelete(0, "prezziVIEtichettaDailyLow");
   ClearDailySegments();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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

   // Force chronological indexing (0 = oldest, rates_total-1 = newest),
   // matching the original MT5 code flow.
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume, false);
   ArraySetAsSeries(spread, false);

   int start = prev_calculated;
   if(start == 0)
   {
      start = 1; // as in original MT5
      currentDay = TimeDayOfWeek(time[0]);
      massimo = high[0];
      minimo = low[0];
      massimoWeek = high[0];
      minimoWeek = low[0];
      HighAvgWeeklyBuffer[0] = EMPTY_VALUE;
      LowAvgWeeklyBuffer[0] = EMPTY_VALUE;
      HighAvgDailyBuffer[0] = EMPTY_VALUE;
      LowAvgDailyBuffer[0] = EMPTY_VALUE;
      ClearDailySegments();
   }

   for(int i = start; i < rates_total; i++)
   {
      int dayOfWeek = TimeDayOfWeek(time[i]);

      if(dayOfWeek != currentDay)
      {
         // Save previous day volatility in corresponding array
         double daily_range = MathRound((massimo - minimo) / PIP_SIZE);
         double weekly_range = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

         switch(currentDay)
         {
            case 0:  // Domenica
               break;
            case 1:  // Lunedi
               ArrayResize(VolatilityMonday, ArraySize(VolatilityMonday) + 1);
               VolatilityMonday[ArraySize(VolatilityMonday) - 1] = daily_range;
               massimo = high[i];
               minimo = low[i];
               break;
            case 2:  // Martedi
               ArrayResize(VolatilityTuesday, ArraySize(VolatilityTuesday) + 1);
               VolatilityTuesday[ArraySize(VolatilityTuesday) - 1] = daily_range;
               break;
            case 3:  // Mercoledi
               ArrayResize(VolatilityWednesday, ArraySize(VolatilityWednesday) + 1);
               VolatilityWednesday[ArraySize(VolatilityWednesday) - 1] = daily_range;
               break;
            case 4:  // Giovedi
               ArrayResize(VolatilityThursday, ArraySize(VolatilityThursday) + 1);
               VolatilityThursday[ArraySize(VolatilityThursday) - 1] = daily_range;
               break;
            case 5:  // Venerdi
               ArrayResize(VolatilityFriday, ArraySize(VolatilityFriday) + 1);
               VolatilityFriday[ArraySize(VolatilityFriday) - 1] = daily_range;
               ArrayResize(VolatilityWeekly, ArraySize(VolatilityWeekly) + 1);
               VolatilityWeekly[ArraySize(VolatilityWeekly) - 1] = weekly_range;
               massimoWeek = high[i];
               minimoWeek = low[i];
               break;
            case 6:  // Sabato
               break;
            default:
               break;
         }

         // New day, reset highs and lows
         currentDay = dayOfWeek;
         massimo = high[i];
         minimo = low[i];
         if(high[i] > massimoWeek) massimoWeek = high[i];
         if(low[i] < minimoWeek) minimoWeek = low[i];
      }
      else
      {
         // Update current day and week highs/lows
         if(high[i] > massimo) massimo = high[i];
         if(low[i] < minimo) minimo = low[i];
         if(high[i] > massimoWeek) massimoWeek = high[i];
         if(low[i] < minimoWeek) minimoWeek = low[i];
      }

      // Ranges in pips
      DailyRangeBuffer = MathRound((massimo - minimo) / PIP_SIZE);
      WeekyRangeBuffer = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

      // Averages
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
            livelloHighWeek = HighAvgWeeklyBuffer[i-1];
            livelloLowWeek  = LowAvgWeeklyBuffer[i-1];
            if(StatoAllarmeWeekly == 0) allarmeWeekly = 1;
            StatoAllarmeWeekly = 1;
         }
      }
      else
      {
         livelloHighWeek = massimoWeek;
         livelloLowWeek  = minimoWeek;
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
            livelloLowDay  = massimo - currentAverage * PIP_SIZE;
            StatoAllarmeDaily = 0;
            allarmeDaily = 0;
         }
         else
         {
            livelloHighDay = HighAvgDailyBuffer[i-1];
            livelloLowDay  = LowAvgDailyBuffer[i-1];
            if(StatoAllarmeDaily == 0) allarmeDaily = 1;
            StatoAllarmeDaily = 1;
         }
      }
      else
      {
         livelloHighDay = massimo;
         livelloLowDay  = minimo;
      }

      HighAvgDailyBuffer[i] = livelloHighDay;
      LowAvgDailyBuffer[i] = livelloLowDay;

      // Draw daily segments in MT4 with same data, colored by day (visual layer only)
      DrawSegment("BIZ_DAILY_H_", i, time, HighAvgDailyBuffer[i-1], HighAvgDailyBuffer[i], DayColor(currentDay));
      DrawSegment("BIZ_DAILY_L_", i, time, LowAvgDailyBuffer[i-1],  LowAvgDailyBuffer[i],  DayColor(currentDay));

      if(i == rates_total - 1)
      {
         // Weekly labels
         string labelNameWeekHigh = "prezziVIEtichettaWeeklyHigh";
         string labelNameWeekLow = "prezziVIEtichettaWeeklyLow";
         ObjectDelete(0, labelNameWeekHigh);
         ObjectDelete(0, labelNameWeekLow);
         ArrowRightPriceCreate(0, labelNameWeekHigh, time[i], HighAvgWeeklyBuffer[i], coloreAvgSettimanale);
         ArrowRightPriceCreate(0, labelNameWeekLow, time[i], LowAvgWeeklyBuffer[i], coloreAvgSettimanale);

         // Daily labels
         string labelNameDayHigh = "prezziVIEtichettaDailyHigh";
         string labelNameDayLow = "prezziVIEtichettaDailyLow";
         ObjectDelete(0, labelNameDayHigh);
         ObjectDelete(0, labelNameDayLow);
         ArrowRightPriceCreate(0, labelNameDayHigh, time[i], HighAvgDailyBuffer[i], labelColor);
         ArrowRightPriceCreate(0, labelNameDayLow, time[i], LowAvgDailyBuffer[i], labelColor);

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
      int err = GetLastError();
      // Fallback for terminals/brokers where OBJ_ARROW_RIGHT_PRICE is unavailable.
      if(!ObjectCreate(chart_ID, name, OBJ_TEXT, 0, time, price))
      {
         Print(__FUNCTION__, ": fallimento nella creazione etichetta prezzo! Error code = ", err);
         return(false);
      }
      ObjectSetString(chart_ID, name, OBJPROP_TEXT, DoubleToString(price, Digits));
      ObjectSetInteger(chart_ID, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(chart_ID, name, OBJPROP_FONTSIZE, 10);
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
//| Controlla i valori di punto di ancoraggio ed imposta i default               |
//+--------------------------------------------------------------------------------+
void ChangeArrowEmptyPoint(datetime &time, double &price)
{
   if(!time)  time = TimeCurrent();
   if(!price) price = MarketInfo(Symbol(), MODE_BID);
}

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
#property indicator_buffers 4

// plot Volatilita' settimanale
#property indicator_label1  "High Weekly Volatility Average"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// plot Volatilita' settimanale
#property indicator_label2  "Low Weekly Volatility Average"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// plot Volatilita' giornaliera
#property indicator_label3  "High Daily Volatility Average"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "Low Daily Volatility Average"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

// --- Parametri licenza
input string allowedServer = "TriveEurope-Live2 Ig"; // Nome del server autorizzato
string supportEmail = "info@investire.biz";          // Email supporto
datetime expirationDate = D'2026.04.07 00:00';

// Input variable for period to calculate average volatility
input int  periodo               = 10;                // Period
input bool NotificheSettimanali  = false;             // Weekly Notification
input bool NotificheGiornaliere  = false;             // Daily Notification
input color coloreAvgSettimanale = clrBlue;           // Weekly Range Average
input color coloreAvgMonday      = C'255,165,0';      // Monday Range Average
input color coloreAvgTuesday     = C'0,204,255';      // Tuesday Range Average
input color coloreAvgWednesday   = C'0,255,0';        // Wednesday Range Average
input color coloreAvgThursday    = C'255,0,255';      // Thursday Range Average
input color coloreAvgFriday      = C'155,2,255';      // Friday Range Average

//--- indicator buffers
double HighAvgWeeklyBuffer[];
double LowAvgWeeklyBuffer[];
double HighAvgDailyBuffer[];
double LowAvgDailyBuffer[];
double WeekyRangeBuffer;
double DailyRangeBuffer;
double AvgWeeklyBuffer;
double AvgDailyBuffer;

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

void DeleteObjectsByPrefix(const string prefix);

//+------------------------------------------------------------------+
//| License check (date + server)                                    |
//+------------------------------------------------------------------+
bool CheckLicenseLocal(const datetime expiration, const string pSupportEmail,
                       const string productName, const string labelId,
                       const string pAllowedServer)
{
   datetime now = TimeCurrent();
   bool date_ok = (now <= expiration);
   bool server_ok = (AccountServer() == pAllowedServer);

   if(date_ok && server_ok)
      return(true);

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

   return(false);
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

   IndicatorBuffers(4);
   SetIndexBuffer(0, HighAvgWeeklyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, LowAvgWeeklyBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, HighAvgDailyBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, LowAvgDailyBuffer, INDICATOR_DATA);

   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 2, clrOrange);
   SetIndexStyle(3, DRAW_LINE, STYLE_SOLID, 2, clrOrange);

   SetIndexLabel(0, "High Weekly Volatility Average");
   SetIndexLabel(1, "Low Weekly Volatility Average");
   SetIndexLabel(2, "High Daily Volatility Average");
   SetIndexLabel(3, "Low Daily Volatility Average");

   //--- Determine the PIP_SIZE based on the current symbol
   PIP_SIZE = MarketInfo(Symbol(), MODE_POINT) * 10.0;

   // Initialize the arrays
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
   DeleteObjectsByPrefix("prezziVI");
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
      return(0);

   int start = prev_calculated;
   if(start == 0)
   {
      start = 1; // Skip the first bar to avoid accessing out-of-range data
      MqlDateTime firstBarTime;
      TimeToStruct(time[0], firstBarTime);
      currentDay = firstBarTime.day_of_week;
      massimo = high[0];
      minimo = low[0];
      massimoWeek = high[0];
      minimoWeek = low[0];
   }

   for(int i = start; i < rates_total; i++)
   {
      MqlDateTime currentTime;
      TimeToStruct(time[i], currentTime);
      int dayOfWeek = currentTime.day_of_week;

      if(dayOfWeek != currentDay)
      {
         // Save the previous day's volatility in the correct array
         double daily_range = MathRound((massimo - minimo) / PIP_SIZE);
         double weekly_range = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

         switch(currentDay)
         {
            case 0: // Domenica
               break;
            case 1: // Lunedì
               ArrayResize(VolatilityMonday, ArraySize(VolatilityMonday) + 1);
               VolatilityMonday[ArraySize(VolatilityMonday) - 1] = daily_range;
               break;
            case 2: // Martedì
               ArrayResize(VolatilityTuesday, ArraySize(VolatilityTuesday) + 1);
               VolatilityTuesday[ArraySize(VolatilityTuesday) - 1] = daily_range;
               break;
            case 3: // Mercoledì
               ArrayResize(VolatilityWednesday, ArraySize(VolatilityWednesday) + 1);
               VolatilityWednesday[ArraySize(VolatilityWednesday) - 1] = daily_range;
               break;
            case 4: // Giovedì
               ArrayResize(VolatilityThursday, ArraySize(VolatilityThursday) + 1);
               VolatilityThursday[ArraySize(VolatilityThursday) - 1] = daily_range;
               break;
            case 5: // Venerdì
               ArrayResize(VolatilityFriday, ArraySize(VolatilityFriday) + 1);
               VolatilityFriday[ArraySize(VolatilityFriday) - 1] = daily_range;
               ArrayResize(VolatilityWeekly, ArraySize(VolatilityWeekly) + 1);
               VolatilityWeekly[ArraySize(VolatilityWeekly) - 1] = weekly_range;
               massimoWeek = high[i];
               minimoWeek = low[i];
               break;
            case 6: // Sabato
               break;
            default:
               break;
         }

         // New day, reset the high and low
         currentDay = dayOfWeek;
         massimo = high[i];
         minimo = low[i];
         if(high[i] > massimoWeek)
            massimoWeek = high[i];
         if(low[i] < minimoWeek)
            minimoWeek = low[i];
      }
      else
      {
         // Update the current day's high and low
         if(high[i] > massimo)
            massimo = high[i];
         if(low[i] < minimo)
            minimo = low[i];
         if(high[i] > massimoWeek)
            massimoWeek = high[i];
         if(low[i] < minimoWeek)
            minimoWeek = low[i];
      }

      // Calculate ranges in pips
      DailyRangeBuffer = MathRound((massimo - minimo) / PIP_SIZE);
      WeekyRangeBuffer = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

      // Calculate averages
      AvgWeeklyBuffer = MathRound(ArrayAverage(VolatilityWeekly, MathMin(periodo, ArraySize(VolatilityWeekly))));
      AvgMondayBuffer = MathRound(ArrayAverage(VolatilityMonday, MathMin(periodo, ArraySize(VolatilityMonday))));
      AvgTuesdayBuffer = MathRound(ArrayAverage(VolatilityTuesday, MathMin(periodo, ArraySize(VolatilityTuesday))));
      AvgWednesdayBuffer = MathRound(ArrayAverage(VolatilityWednesday, MathMin(periodo, ArraySize(VolatilityWednesday))));
      AvgThursdayBuffer = MathRound(ArrayAverage(VolatilityThursday, MathMin(periodo, ArraySize(VolatilityThursday))));
      AvgFridayBuffer = MathRound(ArrayAverage(VolatilityFriday, MathMin(periodo, ArraySize(VolatilityFriday))));

      // Select daily average and label color for the current weekday
      double currentAverage = 0.0;
      color labelColor = clrBlack;

      switch(currentDay)
      {
         case 1:
            currentAverage = AvgMondayBuffer;
            labelColor = coloreAvgMonday;
            break;
         case 2:
            currentAverage = AvgTuesdayBuffer;
            labelColor = coloreAvgTuesday;
            break;
         case 3:
            currentAverage = AvgWednesdayBuffer;
            labelColor = coloreAvgWednesday;
            break;
         case 4:
            currentAverage = AvgThursdayBuffer;
            labelColor = coloreAvgThursday;
            break;
         case 5:
            currentAverage = AvgFridayBuffer;
            labelColor = coloreAvgFriday;
            break;
         default:
            break;
      }

      double livelloHighWeek = 0.0;
      double livellolowWeek = 0.0;
      if(AvgWeeklyBuffer > 0.0)
      {
         if(WeekyRangeBuffer < AvgWeeklyBuffer)
         {
            livelloHighWeek = minimoWeek + AvgWeeklyBuffer * PIP_SIZE;
            livellolowWeek = massimoWeek - AvgWeeklyBuffer * PIP_SIZE;
            StatoAllarmeWeekly = 0;
            allarmeWeekly = 0;
         }
         else
         {
            livelloHighWeek = HighAvgWeeklyBuffer[i - 1];
            livellolowWeek = LowAvgWeeklyBuffer[i - 1];
            if(StatoAllarmeWeekly == 0)
               allarmeWeekly = 1;
            StatoAllarmeWeekly = 1;
         }
      }
      else
      {
         livelloHighWeek = massimoWeek;
         livellolowWeek = minimoWeek;
      }

      HighAvgWeeklyBuffer[i] = livelloHighWeek;
      LowAvgWeeklyBuffer[i] = livellolowWeek;

      double livelloHighDay = 0.0;
      double livellolowDay = 0.0;
      if(currentAverage > 0.0)
      {
         if(currentAverage > DailyRangeBuffer)
         {
            livelloHighDay = minimo + currentAverage * PIP_SIZE;
            livellolowDay = massimo - currentAverage * PIP_SIZE;
            StatoAllarmeDaily = 0;
            allarmeDaily = 0;
         }
         else
         {
            livelloHighDay = HighAvgDailyBuffer[i - 1];
            livellolowDay = LowAvgDailyBuffer[i - 1];
            if(StatoAllarmeDaily == 0)
               allarmeDaily = 1;
            StatoAllarmeDaily = 1;
         }
      }
      else
      {
         livelloHighDay = massimo;
         livellolowDay = minimo;
      }

      HighAvgDailyBuffer[i] = livelloHighDay;
      LowAvgDailyBuffer[i] = livellolowDay;

      if(i == rates_total - 1)
      {
         // creazione etichette Settimanali
         string labelNameWeekHigh = "prezziVIEtichettaWeeklyHigh";
         string labelNameWeekLow = "prezziVIEtichettaWeeklyLow";
         ObjectDelete(0, labelNameWeekHigh);
         ObjectDelete(0, labelNameWeekLow);
         ArrowRightPriceCreate(0, labelNameWeekHigh, time[i], HighAvgWeeklyBuffer[i], coloreAvgSettimanale);
         ArrowRightPriceCreate(0, labelNameWeekLow, time[i], LowAvgWeeklyBuffer[i], coloreAvgSettimanale);

         // creazione etichette giornaliere
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
      return(0.0);

   count = MathMin(count, ArraySize(array));
   double sum = 0.0;

   for(int i = ArraySize(array) - count; i < ArraySize(array); i++)
      sum += array[i];

   return(sum / count);
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
      Print(__FUNCTION__, ": fallimento creazione etichetta prezzo! Error code = ", GetLastError());
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
//| Controlla i valori di punto di ancoraggio ed imposta i default                |
//+--------------------------------------------------------------------------------+
void ChangeArrowEmptyPoint(datetime &time, double &price)
{
   if(!time)
      time = TimeCurrent();
   if(!price)
      price = MarketInfo(Symbol(), MODE_BID);
}

void DeleteObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(name);
   }
}

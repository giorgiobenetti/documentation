//+------------------------------------------------------------------+
//|                                               BIZ Volatility.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Investire.biz"
#property link      "https://investire.biz/"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Indicator settings                                               |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 6

// plot 1 - Weekly Volatility
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// plot 2 - Weekly Volatility Average
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// plot 3 - Daily Volatility (color histogram by weekday)
#property indicator_color3  C'255,165,0',C'0,204,255',C'0,255,0',C'255,0,255',C'155,2,255'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

// plot 4 - Daily Volatility Average (color line by weekday)
#property indicator_color4  C'255,165,0',C'0,204,255',C'0,255,0',C'255,0,255',C'155,2,255'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

// --- Parametri licenza
input string allowedServer = "IG-LIVE";               // Nome del server autorizzato
string       supportEmail  = "info@investire.biz";    // Email supporto
datetime expirationDate    = D'2026.04.07 00:00';

//--- indicator buffers
double WeekyRangeBuffer[];
double DailyRangeBuffer[];
double AvgWeeklyBuffer[];
double AvgDailyBuffer[];
double ColorDailyBuffer[];
double ColorAvgDailyBuffer[];

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
int    currentDay = -1;

double livelloMassimoDaily;
double livelloMinimoDaily;
double livelloMassimoWeek;
double livelloMinimoWeek;

int allarmeWeekly      = 0;
int StatoAllarmeWeekly = 0;
int allarmeDaily       = 0;
int StatoAllarmeDaily  = 0;

//--- Arrays for storing daily volatility by day of the week
double VolatilityMonday[];
double VolatilityTuesday[];
double VolatilityWednesday[];
double VolatilityThursday[];
double VolatilityFriday[];
double VolatilityWeekly[];

// Input variable for period to calculate average volatility
input int  periodo               = 10;                       // Period
input bool attLineeGrafiche      = false;                    // Level
input bool NotificheSettimanali  = false;                    // Weekly Notification
input bool NotificheGiornaliere  = false;                    // Daily Notification
input color coloreAvgSettimanale = clrBlue;                  // Weekly Range Average
input color coloreAvgMonday      = C'255,165,0';             // Monday Range Average
input color coloreAvgTuesday     = C'0,204,255';             // Tuesday Range Average
input color coloreAvgWednesday   = C'0,255,0';               // Wednesday Range Average
input color coloreAvgThursday    = C'255,0,255';             // Thursday Range Average
input color coloreAvgFriday      = C'155,2,255';             // Friday Range Average

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
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

   const string labelIdLocal = (labelId == "" ? "BIZExpiredIndicatorText" : labelId);
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
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "BIZ Volatility", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   IndicatorShortName("BIZ Volatility");

   SetIndexStyle(0, DRAW_HISTOGRAM, STYLE_SOLID, 2, clrYellow);
   SetIndexLabel(0, "Weekly Volatility");
   SetIndexBuffer(0, WeekyRangeBuffer);

   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexLabel(1, "Weekly Volatility Average");
   SetIndexBuffer(1, AvgWeeklyBuffer);

   SetIndexStyle(2, DRAW_COLOR_HISTOGRAM, STYLE_SOLID, 2);
   SetIndexLabel(2, "Daily Volatility");
   SetIndexBuffer(2, DailyRangeBuffer);
   SetIndexBuffer(3, ColorDailyBuffer);

   SetIndexStyle(3, DRAW_COLOR_LINE, STYLE_SOLID, 2);
   SetIndexLabel(3, "Daily Volatility Average");
   SetIndexBuffer(4, AvgDailyBuffer);
   SetIndexBuffer(5, ColorAvgDailyBuffer);

   //--- Determine the PIP_SIZE based on the current symbol
   PIP_SIZE = Point * 10.0;

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
   DeleteObjectsByPrefix("BIZExpiredIndicatorText");
   DeleteObjectsByPrefix("VI");
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

   int start = prev_calculated;
   if(start == 0)
   {
      start = 1;
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
         double daily_range = MathRound((massimo - minimo) / PIP_SIZE);
         double weekly_range = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);

         switch(currentDay)
         {
            case 0:  // Domenica
               break;
            case 1:  // Lunedì
               ArrayResize(VolatilityMonday, ArraySize(VolatilityMonday) + 1);
               VolatilityMonday[ArraySize(VolatilityMonday) - 1] = daily_range;
               massimo = high[i];
               minimo = low[i];
               break;
            case 2:  // Martedì
               ArrayResize(VolatilityTuesday, ArraySize(VolatilityTuesday) + 1);
               VolatilityTuesday[ArraySize(VolatilityTuesday) - 1] = daily_range;
               break;
            case 3:  // Mercoledì
               ArrayResize(VolatilityWednesday, ArraySize(VolatilityWednesday) + 1);
               VolatilityWednesday[ArraySize(VolatilityWednesday) - 1] = daily_range;
               break;
            case 4:  // Giovedì
               ArrayResize(VolatilityThursday, ArraySize(VolatilityThursday) + 1);
               VolatilityThursday[ArraySize(VolatilityThursday) - 1] = daily_range;
               break;
            case 5:  // Venerdì
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
         if(high[i] > massimo)
            massimo = high[i];
         if(low[i] < minimo)
            minimo = low[i];

         if(high[i] > massimoWeek)
            massimoWeek = high[i];
         if(low[i] < minimoWeek)
            minimoWeek = low[i];
      }

      DailyRangeBuffer[i] = MathRound((massimo - minimo) / PIP_SIZE);
      WeekyRangeBuffer[i] = MathRound((massimoWeek - minimoWeek) / PIP_SIZE);
      AvgWeeklyBuffer[i] = MathRound(ArrayAverage(VolatilityWeekly, MathMin(periodo, ArraySize(VolatilityWeekly))));

      AvgMondayBuffer = MathRound(ArrayAverage(VolatilityMonday, MathMin(periodo, ArraySize(VolatilityMonday))));
      AvgTuesdayBuffer = MathRound(ArrayAverage(VolatilityTuesday, MathMin(periodo, ArraySize(VolatilityTuesday))));
      AvgWednesdayBuffer = MathRound(ArrayAverage(VolatilityWednesday, MathMin(periodo, ArraySize(VolatilityWednesday))));
      AvgThursdayBuffer = MathRound(ArrayAverage(VolatilityThursday, MathMin(periodo, ArraySize(VolatilityThursday))));
      AvgFridayBuffer = MathRound(ArrayAverage(VolatilityFriday, MathMin(periodo, ArraySize(VolatilityFriday))));

      double currentAverage = 0.0;
      color  labelColor = clrBlack;
      int    colorindex = 0;

      switch(currentDay)
      {
         case 1:
            currentAverage = AvgMondayBuffer;
            labelColor = coloreAvgMonday;
            colorindex = 0;
            break;
         case 2:
            currentAverage = AvgTuesdayBuffer;
            labelColor = coloreAvgTuesday;
            colorindex = 1;
            break;
         case 3:
            currentAverage = AvgWednesdayBuffer;
            labelColor = coloreAvgWednesday;
            colorindex = 2;
            break;
         case 4:
            currentAverage = AvgThursdayBuffer;
            labelColor = coloreAvgThursday;
            colorindex = 3;
            break;
         case 5:
            currentAverage = AvgFridayBuffer;
            labelColor = coloreAvgFriday;
            colorindex = 4;
            break;
         default:
            break;
      }

      AvgDailyBuffer[i] = currentAverage;
      ColorDailyBuffer[i] = colorindex;
      ColorAvgDailyBuffer[i] = colorindex;

      if(AvgWeeklyBuffer[i] > 0.0)
      {
         if(WeekyRangeBuffer[i] < AvgWeeklyBuffer[i])
         {
            livelloMassimoWeek = minimoWeek + AvgWeeklyBuffer[i] * PIP_SIZE;
            livelloMinimoWeek = massimoWeek - AvgWeeklyBuffer[i] * PIP_SIZE;
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
         if(currentAverage > DailyRangeBuffer[i])
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

      if(i == rates_total - 1)
      {
         string labelName = "VIEtichettaWeekly";
         ObjectDelete(0, labelName);
         ArrowRightPriceCreate(0, labelName, time[i], AvgWeeklyBuffer[i], coloreAvgSettimanale);

         labelName = "VIEtichettaDaily";
         ObjectDelete(0, labelName);
         ArrowRightPriceCreate(0, labelName, time[i], currentAverage, labelColor);

         if(attLineeGrafiche)
         {
            ObjectDelete(0, "VIHLine1Weekly");
            ObjectDelete(0, "VIHLine2Weekly");
            HLineCreate(0, "VIHLine1Weekly", livelloMassimoWeek, STYLE_SOLID, 2, coloreAvgSettimanale);
            HLineCreate(0, "VIHLine2Weekly", livelloMinimoWeek, STYLE_SOLID, 2, coloreAvgSettimanale);

            ObjectDelete(0, "VIHLine1");
            ObjectDelete(0, "VIHLine2");
            HLineCreate(0, "VIHLine1", livelloMassimoDaily, STYLE_SOLID, 2, labelColor);
            HLineCreate(0, "VIHLine2", livelloMinimoDaily, STYLE_SOLID, 2, labelColor);
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

         ChartRedraw(0);
      }
   }

   return rates_total;
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

   return (sum / count);
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
   if(!ObjectCreate(chart_ID, name, OBJ_ARROW_RIGHT_PRICE, 1, time, price))
   {
      Print(__FUNCTION__, ": fallimento nella creazione dell'etichetta prezzo a destra! Error code = ", GetLastError());
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

//+--------------------------------------------------------------------------------+
//| Controlla i valori di punto di ancoraggio                                      |
//+--------------------------------------------------------------------------------+
void ChangeArrowEmptyPoint(datetime &time, double &price)
{
   if(!time)
      time = TimeCurrent();
   if(!price)
      price = Bid;
}

//+--------------------------------------------------------------------------------+
//| Crea la linea orizzontale                                                      |
//+--------------------------------------------------------------------------------+
bool HLineCreate(const long chart_ID = 0,
                 const string name = "VIHLine",
                 double price = 0,
                 const ENUM_LINE_STYLE stile = STYLE_SOLID,
                 const int width = 1,
                 const color clr = clrRed)
{
   if(!price)
      price = Bid;

   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_HLINE, 0, 0, price))
   {
      Print(__FUNCTION__, ": fallimento nel creare la linea orizzontale! Error code = ", GetLastError());
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

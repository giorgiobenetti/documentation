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

int allarmeWeekly = 0;
int StatoAllarmeWeekly = 0;
int allarmeDaily = 0;
int StatoAllarmeDaily = 0;
datetime lastDailyStart = 0;
datetime lastWeeklyStart = 0;

void DeleteObjectsByPrefix(const string prefix);
bool GetDailyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, color &labelColor, double &avgRange);
bool GetWeeklyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, double &avgRange);
color GetWeekdayColor(const int dow);

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

   bool seriesMode = (time[0] > time[rates_total - 1]);
   int begin = seriesMode ? rates_total - 1 : 0;
   int end = seriesMode ? -1 : rates_total;
   int step = seriesMode ? -1 : 1;

   for(int i = begin; i != end; i += step)
   {
      double dailyHigh = EMPTY_VALUE;
      double dailyLow = EMPTY_VALUE;
      double weeklyHigh = EMPTY_VALUE;
      double weeklyLow = EMPTY_VALUE;
      color dailyColor = clrOrange;
      double avgDailyRange = 0.0;
      double avgWeeklyRange = 0.0;

      if(GetDailyProjection(time[i], periodo, dailyHigh, dailyLow, dailyColor, avgDailyRange))
      {
         HighAvgDailyBuffer[i] = dailyHigh;
         LowAvgDailyBuffer[i] = dailyLow;
      }
      else
      {
         HighAvgDailyBuffer[i] = EMPTY_VALUE;
         LowAvgDailyBuffer[i] = EMPTY_VALUE;
      }

      if(GetWeeklyProjection(time[i], periodo, weeklyHigh, weeklyLow, avgWeeklyRange))
      {
         HighAvgWeeklyBuffer[i] = weeklyHigh;
         LowAvgWeeklyBuffer[i] = weeklyLow;
      }
      else
      {
         HighAvgWeeklyBuffer[i] = EMPTY_VALUE;
         LowAvgWeeklyBuffer[i] = EMPTY_VALUE;
      }
   }

   int lastIndex = seriesMode ? 0 : rates_total - 1;
   color labelColor = clrOrange;
   double lastDailyHigh = EMPTY_VALUE;
   double lastDailyLow = EMPTY_VALUE;
   double lastWeeklyHigh = EMPTY_VALUE;
   double lastWeeklyLow = EMPTY_VALUE;
   double avgDailyLast = 0.0;
   double avgWeeklyLast = 0.0;

   bool hasDaily = GetDailyProjection(time[lastIndex], periodo, lastDailyHigh, lastDailyLow, labelColor, avgDailyLast);
   bool hasWeekly = GetWeeklyProjection(time[lastIndex], periodo, lastWeeklyHigh, lastWeeklyLow, avgWeeklyLast);

   if(hasWeekly)
   {
      datetime wStart = iTime(Symbol(), PERIOD_W1, iBarShift(Symbol(), PERIOD_W1, time[lastIndex], false));
      if(wStart != 0 && wStart != lastWeeklyStart)
      {
         lastWeeklyStart = wStart;
         StatoAllarmeWeekly = 0;
         allarmeWeekly = 0;
      }

      int wShift = iBarShift(Symbol(), PERIOD_W1, time[lastIndex], false);
      double currentWHigh = iHigh(Symbol(), PERIOD_W1, wShift);
      double currentWLow = iLow(Symbol(), PERIOD_W1, wShift);
      if(StatoAllarmeWeekly == 0 && (currentWHigh >= lastWeeklyHigh || currentWLow <= lastWeeklyLow))
      {
         allarmeWeekly = 1;
         StatoAllarmeWeekly = 1;
      }
   }

   if(hasDaily)
   {
      datetime dStart = iTime(Symbol(), PERIOD_D1, iBarShift(Symbol(), PERIOD_D1, time[lastIndex], false));
      if(dStart != 0 && dStart != lastDailyStart)
      {
         lastDailyStart = dStart;
         StatoAllarmeDaily = 0;
         allarmeDaily = 0;
      }

      int dShift = iBarShift(Symbol(), PERIOD_D1, time[lastIndex], false);
      double currentDHigh = iHigh(Symbol(), PERIOD_D1, dShift);
      double currentDLow = iLow(Symbol(), PERIOD_D1, dShift);
      if(StatoAllarmeDaily == 0 && (currentDHigh >= lastDailyHigh || currentDLow <= lastDailyLow))
      {
         allarmeDaily = 1;
         StatoAllarmeDaily = 1;
      }
   }

   string labelNameWeekHigh = "prezziVIEtichettaWeeklyHigh";
   string labelNameWeekLow = "prezziVIEtichettaWeeklyLow";
   string labelNameDayHigh = "prezziVIEtichettaDailyHigh";
   string labelNameDayLow = "prezziVIEtichettaDailyLow";

   ObjectDelete(0, labelNameWeekHigh);
   ObjectDelete(0, labelNameWeekLow);
   ObjectDelete(0, labelNameDayHigh);
   ObjectDelete(0, labelNameDayLow);

   if(hasWeekly)
   {
      ArrowRightPriceCreate(0, labelNameWeekHigh, time[lastIndex], lastWeeklyHigh, coloreAvgSettimanale);
      ArrowRightPriceCreate(0, labelNameWeekLow, time[lastIndex], lastWeeklyLow, coloreAvgSettimanale);
   }

   if(hasDaily)
   {
      ArrowRightPriceCreate(0, labelNameDayHigh, time[lastIndex], lastDailyHigh, labelColor);
      ArrowRightPriceCreate(0, labelNameDayLow, time[lastIndex], lastDailyLow, labelColor);
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

   ChartRedraw();

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
//| Colore linea/etichetta per giorno settimana                                    |
//+--------------------------------------------------------------------------------+
color GetWeekdayColor(const int dow)
{
   switch(dow)
   {
      case 1: return(coloreAvgMonday);
      case 2: return(coloreAvgTuesday);
      case 3: return(coloreAvgWednesday);
      case 4: return(coloreAvgThursday);
      case 5: return(coloreAvgFriday);
   }
   return(clrOrange);
}

//+--------------------------------------------------------------------------------+
//| Proiezione giornaliera: media ultimi N stesso giorno (lun-ven)                 |
//| proiettata dal close del giorno precedente                                      |
//+--------------------------------------------------------------------------------+
bool GetDailyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, color &labelColor, double &avgRange)
{
   int dayShift = iBarShift(Symbol(), PERIOD_D1, barTime, false);
   if(dayShift < 0)
      return(false);

   datetime dayOpenTime = iTime(Symbol(), PERIOD_D1, dayShift);
   int dayOfWeek = TimeDayOfWeek(dayOpenTime);
   labelColor = GetWeekdayColor(dayOfWeek);
   if(dayOfWeek < 1 || dayOfWeek > 5)
      return(false);

   double baseClose = iClose(Symbol(), PERIOD_D1, dayShift + 1); // close giorno precedente
   if(baseClose <= 0.0)
      return(false);

   int d1Bars = iBars(Symbol(), PERIOD_D1);
   double sum = 0.0;
   int count = 0;

   for(int s = dayShift + 1; s < d1Bars && count < lookback; s++)
   {
      datetime t = iTime(Symbol(), PERIOD_D1, s);
      if(TimeDayOfWeek(t) != dayOfWeek)
         continue;

      double r = iHigh(Symbol(), PERIOD_D1, s) - iLow(Symbol(), PERIOD_D1, s);
      if(r > 0.0)
      {
         sum += r;
         count++;
      }
   }

   if(count <= 0)
      return(false);

   avgRange = sum / count;
   levelHigh = baseClose + avgRange;
   levelLow = baseClose - avgRange;
   return(true);
}

//+--------------------------------------------------------------------------------+
//| Proiezione settimanale: media ultimi N range settimanali                       |
//| proiettata dal close della settimana precedente                                |
//+--------------------------------------------------------------------------------+
bool GetWeeklyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, double &avgRange)
{
   int weekShift = iBarShift(Symbol(), PERIOD_W1, barTime, false);
   if(weekShift < 0)
      return(false);

   double baseClose = iClose(Symbol(), PERIOD_W1, weekShift + 1); // close settimana precedente
   if(baseClose <= 0.0)
      return(false);

   int w1Bars = iBars(Symbol(), PERIOD_W1);
   double sum = 0.0;
   int count = 0;

   for(int s = weekShift + 1; s < w1Bars && count < lookback; s++)
   {
      double r = iHigh(Symbol(), PERIOD_W1, s) - iLow(Symbol(), PERIOD_W1, s);
      if(r > 0.0)
      {
         sum += r;
         count++;
      }
   }

   if(count <= 0)
      return(false);

   avgRange = sum / count;
   levelHigh = baseClose + avgRange;
   levelLow = baseClose - avgRange;
   return(true);
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

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
#property indicator_buffers 8

// 0-1: weekly
#property indicator_label1  "High Weekly Volatility Average"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Low Weekly Volatility Average"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// 2-4: daily high by weekday group
#property indicator_label3  "High Daily Mon-Tue"
#property indicator_type3   DRAW_LINE
#property indicator_color3  C'255,165,0'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "High Daily Wed-Thu"
#property indicator_type4   DRAW_LINE
#property indicator_color4  C'0,255,0'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "High Daily Fri"
#property indicator_type5   DRAW_LINE
#property indicator_color5  C'155,2,255'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

// 5-7: daily low by weekday group
#property indicator_label6  "Low Daily Mon-Tue"
#property indicator_type6   DRAW_LINE
#property indicator_color6  C'255,0,255'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

#property indicator_label7  "Low Daily Wed-Thu"
#property indicator_type7   DRAW_LINE
#property indicator_color7  C'0,204,255'
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

#property indicator_label8  "Low Daily Fri"
#property indicator_type8   DRAW_LINE
#property indicator_color8  C'255,165,0'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

// --- Parametri licenza
input string allowedServer = "TriveEurope-Live2 Ig"; // Nome del server autorizzato
string supportEmail = "info@investire.biz";          // Email supporto
datetime expirationDate = D'2026.04.07 00:00';

// Input variabili
input int  periodo               = 10;                // Period
input int  MaxBarsDaCalcolare    = 2500;              // Limite barre per stabilita' performance
input int  MaxGiorniDailyOggetti = 120;               // Giorni da disegnare come linee daily
input bool NotificheSettimanali  = false;             // Weekly Notification
input bool NotificheGiornaliere  = false;             // Daily Notification
input bool EscludiDomenica       = true;              // Esclude sessione domenicale dai calcoli
input color coloreAvgSettimanale = clrBlue;           // Weekly Range Average
input color coloreAvgMonday      = C'255,165,0';      // Monday Range Average
input color coloreAvgTuesday     = C'0,204,255';      // Tuesday Range Average
input color coloreAvgWednesday   = C'0,255,0';        // Wednesday Range Average
input color coloreAvgThursday    = C'255,0,255';      // Thursday Range Average
input color coloreAvgFriday      = C'155,2,255';      // Friday Range Average

//--- indicator buffers
double HighAvgWeeklyBuffer[];
double LowAvgWeeklyBuffer[];
double HighDailyMonTueBuffer[];
double HighDailyWedThuBuffer[];
double HighDailyFriBuffer[];
double LowDailyMonTueBuffer[];
double LowDailyWedThuBuffer[];
double LowDailyFriBuffer[];

int allarmeWeekly = 0;
int StatoAllarmeWeekly = 0;
int allarmeDaily = 0;
int StatoAllarmeDaily = 0;
datetime lastDailyStart = 0;
datetime lastWeeklyStart = 0;
datetime lastDailyObjectsRefresh = 0;

void DeleteObjectsByPrefix(const string prefix);
bool GetDailyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, color &labelColor, double &avgRange, int &weekdayOut);
bool GetWeeklyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, double &avgRange);
bool GetWeekStatsNoSunday(const int weekShift, double &weekHigh, double &weekLow, double &weekClose);
bool GetRangeStatsNoSunday(const ENUM_TIMEFRAMES tf, const datetime windowStart, const datetime windowEnd, double &rangeHigh, double &rangeLow, double &lastClose);
int  GetNormalizedWeekday(const datetime dayOpenTime);
void DrawDailySegmentsAsObjects(const datetime &time[], const int rates_total);
void ResetAllBuffers();
void DrawDailySegment(const datetime tStart, const datetime tEnd, const double hi, const double lo, const int dow);
void DeleteDailySegments();
color GetWeekdayColor(const int dow);
void indicatoreScaduto();
bool ArrowRightPriceCreate(const long chart_ID = 0, const string name = "EtichettaVI", datetime time = 0, double price = 0, const color clr = clrRed);
void ChangeArrowEmptyPoint(datetime &time, double &price);

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

   IndicatorBuffers(8);
   SetIndexBuffer(0, HighAvgWeeklyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, LowAvgWeeklyBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, HighDailyMonTueBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, HighDailyWedThuBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, HighDailyFriBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, LowDailyMonTueBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, LowDailyWedThuBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, LowDailyFriBuffer, INDICATOR_DATA);

   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrBlue);
   // Daily lines are rendered as chart objects for true weekday colors.
   SetIndexStyle(2, DRAW_NONE);
   SetIndexStyle(3, DRAW_NONE);
   SetIndexStyle(4, DRAW_NONE);
   SetIndexStyle(5, DRAW_NONE);
   SetIndexStyle(6, DRAW_NONE);
   SetIndexStyle(7, DRAW_NONE);

   SetIndexLabel(0, "High Weekly Volatility Average");
   SetIndexLabel(1, "Low Weekly Volatility Average");
   SetIndexLabel(2, "High Daily Mon-Tue");
   SetIndexLabel(3, "High Daily Wed-Thu");
   SetIndexLabel(4, "High Daily Fri");
   SetIndexLabel(5, "Low Daily Mon-Tue");
   SetIndexLabel(6, "Low Daily Wed-Thu");
   SetIndexLabel(7, "Low Daily Fri");

   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexEmptyValue(2, EMPTY_VALUE);
   SetIndexEmptyValue(3, EMPTY_VALUE);
   SetIndexEmptyValue(4, EMPTY_VALUE);
   SetIndexEmptyValue(5, EMPTY_VALUE);
   SetIndexEmptyValue(6, EMPTY_VALUE);
   SetIndexEmptyValue(7, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| FUNZIONE DI DEINIZIALIZZAZIONE                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "BIZExpiredIndicatorText");
   ObjectDelete(0, "BIZExpiredIndicatorText2");
   DeleteDailySegments();
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

   int lookback = MathMax(1, periodo);
   if(lookback > 50)
      lookback = 50;

   int cappedBars = MathMax(200, MaxBarsDaCalcolare);
   if(cappedBars > 10000)
      cappedBars = 10000;
   int barsToCalc = cappedBars;
   if(barsToCalc > rates_total)
      barsToCalc = rates_total;

   bool seriesMode = (time[0] > time[rates_total - 1]);
   int begin = seriesMode ? barsToCalc - 1 : rates_total - barsToCalc;
   int end = seriesMode ? -1 : rates_total;
   int step = seriesMode ? -1 : 1;

   // Primo caricamento: svuota tutti i buffer per evitare artefatti grafici
   if(prev_calculated == 0)
      ResetAllBuffers();

   int lastWeekShift = -1;
   bool weekReady = false;
   double cachedWeeklyHigh = EMPTY_VALUE;
   double cachedWeeklyLow = EMPTY_VALUE;
   double cachedAvgWeekly = 0.0;

   for(int i = begin; i != end; i += step)
   {
      int weekShift = iBarShift(Symbol(), PERIOD_W1, time[i], false);

      if(weekShift >= 0)
      {
         if(weekShift != lastWeekShift)
         {
            lastWeekShift = weekShift;
            weekReady = GetWeeklyProjection(time[i], lookback, cachedWeeklyHigh, cachedWeeklyLow, cachedAvgWeekly);
         }
         if(weekReady)
         {
            HighAvgWeeklyBuffer[i] = cachedWeeklyHigh;
            LowAvgWeeklyBuffer[i] = cachedWeeklyLow;
         }
         else
         {
            HighAvgWeeklyBuffer[i] = EMPTY_VALUE;
            LowAvgWeeklyBuffer[i] = EMPTY_VALUE;
         }
      }
   }

   int lastIndex = seriesMode ? 0 : rates_total - 1;

   if(prev_calculated == 0 || lastDailyObjectsRefresh != time[lastIndex])
   {
      DrawDailySegmentsAsObjects(time, rates_total);
      lastDailyObjectsRefresh = time[lastIndex];
   }

   color labelColor = clrOrange;
   double lastDailyHigh = EMPTY_VALUE;
   double lastDailyLow = EMPTY_VALUE;
   double lastWeeklyHigh = EMPTY_VALUE;
   double lastWeeklyLow = EMPTY_VALUE;
   double avgDailyLast = 0.0;
   double avgWeeklyLast = 0.0;
   int lastDailyDow = 0;

   bool hasDaily = GetDailyProjection(time[lastIndex], lookback, lastDailyHigh, lastDailyLow, labelColor, avgDailyLast, lastDailyDow);
   bool hasWeekly = GetWeeklyProjection(time[lastIndex], lookback, lastWeeklyHigh, lastWeeklyLow, avgWeeklyLast);

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
//| Normalizza il giorno: domenica -> lunedi (se esclusa)                          |
//+--------------------------------------------------------------------------------+
int GetNormalizedWeekday(const datetime dayOpenTime)
{
   int dow = TimeDayOfWeek(dayOpenTime); // 0=dom ... 6=sab
   if(EscludiDomenica && dow == 0)
      return(1);
   return(dow);
}

//+--------------------------------------------------------------------------------+
//| Pulisce i buffer daily alla barra index                                         |
//+--------------------------------------------------------------------------------+
void ClearDailyBuffersAt(const int index)
{
   HighDailyMonTueBuffer[index] = EMPTY_VALUE;
   HighDailyWedThuBuffer[index] = EMPTY_VALUE;
   HighDailyFriBuffer[index] = EMPTY_VALUE;
   LowDailyMonTueBuffer[index] = EMPTY_VALUE;
   LowDailyWedThuBuffer[index] = EMPTY_VALUE;
   LowDailyFriBuffer[index] = EMPTY_VALUE;
}

//+--------------------------------------------------------------------------------+
//| Scrive i livelli daily nel buffer gruppo colore                                 |
//+--------------------------------------------------------------------------------+
void SetDailyBuffersAt(const int index, const int dow, const double hi, const double lo)
{
   if(dow == 1 || dow == 2)
   {
      HighDailyMonTueBuffer[index] = hi;
      LowDailyMonTueBuffer[index] = lo;
   }
   else if(dow == 3 || dow == 4)
   {
      HighDailyWedThuBuffer[index] = hi;
      LowDailyWedThuBuffer[index] = lo;
   }
   else if(dow == 5)
   {
      HighDailyFriBuffer[index] = hi;
      LowDailyFriBuffer[index] = lo;
   }
}

//+--------------------------------------------------------------------------------+
//| Proiezione giornaliera: media ultimi N stesso giorno (lun-ven)                 |
//| proiettata dal close del giorno precedente, escludendo domenica                |
//+--------------------------------------------------------------------------------+
bool GetDailyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, color &labelColor, double &avgRange, int &weekdayOut)
{
   int dayShift = iBarShift(Symbol(), PERIOD_D1, barTime, false);
   if(dayShift < 0)
      return(false);

   datetime dayOpenTime = iTime(Symbol(), PERIOD_D1, dayShift);
   int dayOfWeek = GetNormalizedWeekday(dayOpenTime);
   weekdayOut = dayOfWeek;
   labelColor = GetWeekdayColor(dayOfWeek);
   if(dayOfWeek < 1 || dayOfWeek > 5)
      return(false);

   // Base close: close reale dell'ultimo giorno valido precedente (su H1, no domenica)
   double baseClose = 0.0;
   int d1Bars = iBars(Symbol(), PERIOD_D1);
   for(int s = dayShift + 1; s < d1Bars; s++)
   {
      datetime t = iTime(Symbol(), PERIOD_D1, s);
      int dow = TimeDayOfWeek(t);
      if(EscludiDomenica && dow == 0)
         continue;

      datetime prevDayStart = t;
      datetime prevDayEnd = (s > 0 ? iTime(Symbol(), PERIOD_D1, s - 1) : prevDayStart + 24 * 60 * 60);
      if(prevDayEnd <= prevDayStart)
         continue;

      double tmpHi = 0.0, tmpLo = 0.0, tmpClose = 0.0;
      if(GetRangeStatsNoSunday(PERIOD_H1, prevDayStart, prevDayEnd, tmpHi, tmpLo, tmpClose) && tmpClose > 0.0)
      {
         baseClose = tmpClose;
         break;
      }

      // Fallback robusto: close D1 se non ci sono abbastanza barre H1
      double closeD1 = iClose(Symbol(), PERIOD_D1, s);
      if(closeD1 > 0.0)
      {
         baseClose = closeD1;
         break;
      }
   }
   if(baseClose <= 0.0)
      return(false);

   double sum = 0.0;
   int count = 0;
   for(int s2 = dayShift + 1; s2 < d1Bars && count < lookback; s2++)
   {
      datetime t2 = iTime(Symbol(), PERIOD_D1, s2);
      int dow2 = GetNormalizedWeekday(t2);
      if(dow2 != dayOfWeek)
         continue;
      if(EscludiDomenica && TimeDayOfWeek(t2) == 0)
         continue;

      datetime dayStart = iTime(Symbol(), PERIOD_D1, s2);
      datetime dayEnd = (s2 > 0 ? iTime(Symbol(), PERIOD_D1, s2 - 1) : dayStart + 24 * 60 * 60);
      double sampleHi = 0.0, sampleLo = 0.0, sampleClose = 0.0;
      if(!GetRangeStatsNoSunday(PERIOD_H1, dayStart, dayEnd, sampleHi, sampleLo, sampleClose))
         continue;

      double r = MathAbs(sampleHi - sampleLo);
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
//| Aggrega statistiche settimana ignorando la domenica                             |
//+--------------------------------------------------------------------------------+
bool GetWeekStatsNoSunday(const int weekShift, double &weekHigh, double &weekLow, double &weekClose)
{
   datetime wOpen = iTime(Symbol(), PERIOD_W1, weekShift);
   if(wOpen <= 0)
      return(false);
   datetime wEnd = (weekShift > 0 ? iTime(Symbol(), PERIOD_W1, weekShift - 1) : wOpen + 7 * 24 * 60 * 60);
   if(wEnd <= wOpen)
      return(false);
   return(GetRangeStatsNoSunday(PERIOD_H1, wOpen, wEnd, weekHigh, weekLow, weekClose));
}

//+--------------------------------------------------------------------------------+
//| Proiezione settimanale: media ultimi N range settimanali                       |
//| proiettata dal close della settimana precedente (domenica esclusa)             |
//+--------------------------------------------------------------------------------+
bool GetWeeklyProjection(const datetime barTime, const int lookback, double &levelHigh, double &levelLow, double &avgRange)
{
   int weekShift = iBarShift(Symbol(), PERIOD_W1, barTime, false);
   if(weekShift < 0)
      return(false);

   double baseHi = 0.0, baseLo = 0.0, baseClose = 0.0;
   if(!GetWeekStatsNoSunday(weekShift + 1, baseHi, baseLo, baseClose))
      return(false);

   int w1Bars = iBars(Symbol(), PERIOD_W1);
   double sum = 0.0;
   int count = 0;
   for(int s = weekShift + 1; s < w1Bars && count < lookback; s++)
   {
      double wh = 0.0, wl = 0.0, wc = 0.0;
      if(!GetWeekStatsNoSunday(s, wh, wl, wc))
         continue;
      double r = MathAbs(wh - wl);
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
//| Range/close in finestra temporale ignorando eventuale domenica                 |
//+--------------------------------------------------------------------------------+
bool GetRangeStatsNoSunday(const ENUM_TIMEFRAMES tf, const datetime windowStart, const datetime windowEnd, double &rangeHigh, double &rangeLow, double &lastClose)
{
   if(windowStart <= 0 || windowEnd <= windowStart)
      return(false);

   int newestShift = iBarShift(Symbol(), tf, windowEnd - 1, false);
   int oldestShift = iBarShift(Symbol(), tf, windowStart, false);
   if(newestShift < 0 || oldestShift < 0)
      return(false);
   if(newestShift > oldestShift)
   {
      int tmp = newestShift;
      newestShift = oldestShift;
      oldestShift = tmp;
   }

   bool found = false;
   rangeHigh = -DBL_MAX;
   rangeLow = DBL_MAX;
   datetime latestBarTime = 0;
   lastClose = 0.0;

   for(int i = newestShift; i <= oldestShift; i++)
   {
      datetime bt = iTime(Symbol(), tf, i);
      if(bt < windowStart || bt >= windowEnd)
         continue;

      if(EscludiDomenica && TimeDayOfWeek(bt) == 0)
         continue;

      double bh = iHigh(Symbol(), tf, i);
      double bl = iLow(Symbol(), tf, i);
      if(bh > rangeHigh)
         rangeHigh = bh;
      if(bl < rangeLow)
         rangeLow = bl;

      if(bt >= latestBarTime)
      {
         latestBarTime = bt;
         lastClose = iClose(Symbol(), tf, i);
      }
      found = true;
   }

   if(!found || rangeHigh <= -DBL_MAX / 2 || rangeLow >= DBL_MAX / 2 || lastClose <= 0.0)
      return(false);

   return(true);
}

void ResetAllBuffers()
{
   ArrayInitialize(HighAvgWeeklyBuffer, EMPTY_VALUE);
   ArrayInitialize(LowAvgWeeklyBuffer, EMPTY_VALUE);
   ArrayInitialize(HighDailyMonTueBuffer, EMPTY_VALUE);
   ArrayInitialize(HighDailyWedThuBuffer, EMPTY_VALUE);
   ArrayInitialize(HighDailyFriBuffer, EMPTY_VALUE);
   ArrayInitialize(LowDailyMonTueBuffer, EMPTY_VALUE);
   ArrayInitialize(LowDailyWedThuBuffer, EMPTY_VALUE);
   ArrayInitialize(LowDailyFriBuffer, EMPTY_VALUE);
}

//+--------------------------------------------------------------------------------+
//| Disegna segmenti daily come oggetti (colori esatti lun-mar-mer-gio-ven)       |
//+--------------------------------------------------------------------------------+
void DrawDailySegmentsAsObjects(const datetime &time[], const int rates_total)
{
   DeleteDailySegments();

   int lookback = MathMax(1, periodo);
   if(lookback > 50)
      lookback = 50;

   int totalD1 = iBars(Symbol(), PERIOD_D1);
   if(totalD1 <= 1)
      return;

   // Disegna un numero limitato di giorni per stabilita' (sufficiente anche in zoom out)
   int daysToDraw = MathMin(totalD1 - 1, MathMax(lookback * 4, 80));
   for(int shift = daysToDraw; shift >= 0; shift--)
   {
      datetime dayStart = iTime(Symbol(), PERIOD_D1, shift);
      if(dayStart <= 0)
         continue;

      if(EscludiDomenica && TimeDayOfWeek(dayStart) == 0)
         continue;

      datetime dayEnd = (shift > 0 ? iTime(Symbol(), PERIOD_D1, shift - 1) : dayStart + 24 * 60 * 60);
      if(dayEnd <= dayStart)
         continue;

      double hi = 0.0, lo = 0.0, avg = 0.0;
      color lineColor = clrOrange;
      int dow = 0;
      if(!GetDailyProjection(dayStart + 60, lookback, hi, lo, lineColor, avg, dow))
         continue;

      DrawDailySegment(dayStart, dayEnd, hi, lo, dow);
   }
}

//+--------------------------------------------------------------------------------+
//| Disegna 2 segmenti (high/low) per un giorno                                    |
//+--------------------------------------------------------------------------------+
void DrawDailySegment(const datetime tStart, const datetime tEnd, const double hi, const double lo, const int dow)
{
   color c = GetWeekdayColor(dow);
   string suffix = IntegerToString((int)tStart);
   string nameH = "prezziVIDailySegH_" + suffix;
   string nameL = "prezziVIDailySegL_" + suffix;

   if(!ObjectCreate(0, nameH, OBJ_TREND, 0, tStart, hi, tEnd, hi))
      ObjectMove(0, nameH, 0, tStart, hi);
   ObjectMove(0, nameH, 1, tEnd, hi);
   ObjectSetInteger(0, nameH, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nameH, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nameH, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nameH, OBJPROP_RAY, false);
   ObjectSetInteger(0, nameH, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nameH, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nameH, OBJPROP_HIDDEN, true);

   if(!ObjectCreate(0, nameL, OBJ_TREND, 0, tStart, lo, tEnd, lo))
      ObjectMove(0, nameL, 0, tStart, lo);
   ObjectMove(0, nameL, 1, tEnd, lo);
   ObjectSetInteger(0, nameL, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nameL, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nameL, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nameL, OBJPROP_RAY, false);
   ObjectSetInteger(0, nameL, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nameL, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nameL, OBJPROP_HIDDEN, true);
}

//+--------------------------------------------------------------------------------+
//| Cancella tutti i segmenti daily creati da questo indicatore                    |
//+--------------------------------------------------------------------------------+
void DeleteDailySegments()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, "prezziVIDailySegH_", 0) == 0 || StringFind(name, "prezziVIDailySegL_", 0) == 0)
         ObjectDelete(name);
   }
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

//+------------------------------------------------------------------+
//|                          IB_PivotPoints (MT4)                    |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 7

//+------------------------------------------------------------------+
//|   Data di scadenza                                               |
//+------------------------------------------------------------------+
datetime expirationDate = D'2026.04.07 00:00';
input string allowedServer = "IG-LIVE"; // Nome del server autorizzato
string       supportEmail  = "info@investire.biz"; // Email supporto

enum ENUM_PIVOT_TYPE { Pivot_Standard, Pivot_Camarilla, Pivot_DeMark, Pivot_Fibonacci, Pivot_Woodie };
enum ENUM_PIVOT_TF   { TF_H1=PERIOD_H1, TF_H4=PERIOD_H4, TF_Daily=PERIOD_D1, TF_Weekly=PERIOD_W1, TF_Monthly=PERIOD_MN1 };

input ENUM_PIVOT_TYPE InpPivotType          = Pivot_Standard;
input ENUM_PIVOT_TF   InpPivotTF            = TF_Daily;

input bool            InpShowHistory        = true;   // mostra periodi precedenti
input int             InpPeriodsBack        = 10;     // quanti periodi del TF pivot indietro

input bool            InpExtendTodayRight   = true;   // estendi SOLO a destra il periodo corrente
input bool            InpShowLabels         = true;   // etichette PP/R/S
input int             InpLabelBarsFromRight = 2;      // distanza dal bordo destro (in barre)

input color           ColorPP               = clrBlue;
input color           ColorRes              = clrRed;
input color           ColorSupp             = clrDarkGreen;
input int             LineWidthPP           = 1;
input int             LineWidthLevels       = 1;

//--- Buffers
double BufferPP[], BufferR1[], BufferS1[], BufferR2[], BufferS2[], BufferR3[], BufferS3[];

//--- Oggetti
string OBJ_PREFIX = "IBPIV_";

//------------------------- helper -----------------------------------
void HideAt(const int i)
{
   BufferPP[i]=EMPTY_VALUE; BufferR1[i]=EMPTY_VALUE; BufferS1[i]=EMPTY_VALUE;
   BufferR2[i]=EMPTY_VALUE; BufferS2[i]=EMPTY_VALUE; BufferR3[i]=EMPTY_VALUE; BufferS3[i]=EMPTY_VALUE;
}

string ExtName(const string level) { return(OBJ_PREFIX + "EXT_" + level); }
string LblName(const string level) { return(OBJ_PREFIX + "LBL_" + level); }

void ApplyTextStyle(const string name, const color clr)
{
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

datetime LabelTimeAnchor(const datetime &timeArr[], const int rates_total)
{
   int idx = InpLabelBarsFromRight;
   if(idx < 0) idx = 0;
   if(idx > rates_total-1) idx = rates_total-1;
   return(timeArr[idx]); // vicino al bordo destro
}

void UpsertLabel(const string name, const string text, const datetime t, const double price, const color clr)
{
   if(!InpShowLabels || price == EMPTY_VALUE) { ObjectDelete(0, name); return; }

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectMove(0, name, 0, t, price);
   ApplyTextStyle(name, clr);
}

// Linea orizzontale che parte da (t1,price) e si estende SOLO a destra (MT4)
void UpsertRayLine(const string name, const datetime t1, const double price,
                   const color clr, const int width, const int style)
{
   if(price == EMPTY_VALUE) { ObjectDelete(0, name); return; }

   // secondo punto leggermente dopo (serve per definire la trendline)
   int ps = PeriodSeconds();
   if(ps <= 0) ps = 60;
   datetime t2 = t1 + ps;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   else
   {
      ObjectMove(0, name, 0, t1, price);
      ObjectMove(0, name, 1, t2, price);
   }

   // chiave MT4: estensione a destra
   ObjectSetInteger(0, name, OBJPROP_RAY, true);

   // stile
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DeleteAllObjects()
{
   ObjectDelete(0, ExtName("PP"));
   ObjectDelete(0, ExtName("R1")); ObjectDelete(0, ExtName("S1"));
   ObjectDelete(0, ExtName("R2")); ObjectDelete(0, ExtName("S2"));
   ObjectDelete(0, ExtName("R3")); ObjectDelete(0, ExtName("S3"));

   ObjectDelete(0, LblName("PP"));
   ObjectDelete(0, LblName("R1")); ObjectDelete(0, LblName("S1"));
   ObjectDelete(0, LblName("R2")); ObjectDelete(0, LblName("S2"));
   ObjectDelete(0, LblName("R3")); ObjectDelete(0, LblName("S3"));
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

void indicatoreScaduto()
{
   long chart_width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long center_x = chart_width / 2;
   long center_y = chart_height / 2;

   string messageLine1 = "La licenza per l'indicatore IB_PivotPoints è scaduta.";
   string messageLine2 = "Per informazioni contatta info@investire.biz";

   Print("La licenza per l'indicatore IB_PivotPoints è scaduta. Per informazioni contatta info@investire.biz");

   ObjectCreate(0,"ExpiredIndicatorText",OBJ_LABEL,0,0,0);
   ObjectSetString(0, "ExpiredIndicatorText", OBJPROP_TEXT, messageLine1);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_XDISTANCE,center_x);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_YDISTANCE,center_y);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_FONTSIZE,18);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_COLOR,clrOrange);
   ObjectSetInteger(0,"ExpiredIndicatorText",OBJPROP_ANCHOR,ANCHOR_CENTER);

   ObjectCreate(0,"ExpiredIndicatorText2",OBJ_LABEL,0,0,0);
   ObjectSetString(0, "ExpiredIndicatorText2", OBJPROP_TEXT, messageLine2);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_XDISTANCE,center_x);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_YDISTANCE,center_y+30);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_FONTSIZE,18);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_COLOR,clrOrange);
   ObjectSetInteger(0,"ExpiredIndicatorText2",OBJPROP_ANCHOR,ANCHOR_CENTER);
}

void CalcPivotsForShift(const int tfShift, double &pp,double &r1,double &s1,double &r2,double &s2,double &r3,double &s3)
{
   pp=EMPTY_VALUE; r1=EMPTY_VALUE; s1=EMPTY_VALUE; r2=EMPTY_VALUE; s2=EMPTY_VALUE; r3=EMPTY_VALUE; s3=EMPTY_VALUE;

   int prevShift = tfShift + 1;

   double H = iHigh(NULL,  (int)InpPivotTF, prevShift);
   double L = iLow(NULL,   (int)InpPivotTF, prevShift);
   double C = iClose(NULL, (int)InpPivotTF, prevShift);
   double O = iOpen(NULL,  (int)InpPivotTF, prevShift);

   if(H<=0 || L<=0 || C<=0) return;

   switch(InpPivotType)
   {
      case Pivot_Standard:
         pp = (H + L + C) / 3.0;
         r1 = (2.0 * pp) - L;     s1 = (2.0 * pp) - H;
         r2 = pp + (H - L);       s2 = pp - (H - L);
         r3 = H + 2.0 * (pp - L); s3 = L - 2.0 * (H - pp);
         break;

      case Pivot_Camarilla:
         pp = (H + L + C) / 3.0;
         r1 = C + (H - L) * 1.1 / 12.0; s1 = C - (H - L) * 1.1 / 12.0;
         r2 = C + (H - L) * 1.1 /  6.0; s2 = C - (H - L) * 1.1 /  6.0;
         r3 = C + (H - L) * 1.1 /  4.0; s3 = C - (H - L) * 1.1 /  4.0;
         break;

      case Pivot_Fibonacci:
         pp = (H + L + C) / 3.0;
         r1 = pp + (H - L) * 0.382; s1 = pp - (H - L) * 0.382;
         r2 = pp + (H - L) * 0.618; s2 = pp - (H - L) * 0.618;
         r3 = pp + (H - L) * 1.000; s3 = pp - (H - L) * 1.000;
         break;

      case Pivot_Woodie:
         pp = (H + L + 2.0 * O) / 4.0;
         r1 = (2.0 * pp) - L; s1 = (2.0 * pp) - H;
         r2 = pp + (H - L);   s2 = pp - (H - L);
         break;

      case Pivot_DeMark:
      {
         double x_val;
         if(C < O)      x_val = H + 2.0 * L + C;
         else if(C > O) x_val = 2.0 * H + L + C;
         else           x_val = H + L + 2.0 * C;

         pp = x_val / 4.0;
         r1 = x_val / 2.0 - L;
         s1 = x_val / 2.0 - H;
      }
      break;
   }
}

//------------------------------ init/deinit --------------------------
int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "IB_PivotPoints", "BIZExpiredIndicatorText", allowedServer))
   {
      indicatoreScaduto();
      return(INIT_SUCCEEDED);
   }

   IndicatorShortName("IB_PivotPoints");

   SetIndexBuffer(0, BufferPP); SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, LineWidthPP,      ColorPP);
   SetIndexBuffer(1, BufferR1); SetIndexStyle(1, DRAW_LINE, STYLE_DASH,  LineWidthLevels, ColorRes);
   SetIndexBuffer(2, BufferS1); SetIndexStyle(2, DRAW_LINE, STYLE_DASH,  LineWidthLevels, ColorSupp);
   SetIndexBuffer(3, BufferR2); SetIndexStyle(3, DRAW_LINE, STYLE_DASH,  LineWidthLevels, ColorRes);
   SetIndexBuffer(4, BufferS2); SetIndexStyle(4, DRAW_LINE, STYLE_DASH,  LineWidthLevels, ColorSupp);
   SetIndexBuffer(5, BufferR3); SetIndexStyle(5, DRAW_LINE, STYLE_DASH,  LineWidthLevels, ColorRes);
   SetIndexBuffer(6, BufferS3); SetIndexStyle(6, DRAW_LINE, STYLE_DASH,  LineWidthLevels, ColorSupp);

   for(int p=0; p<7; p++) SetIndexEmptyValue(p, EMPTY_VALUE);

   DeleteAllObjects();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteAllObjects();
   ObjectDelete(0, "BIZExpiredIndicatorText");
   ObjectDelete(0, "ExpiredIndicatorText");
   ObjectDelete(0, "ExpiredIndicatorText2");
}

//------------------------------ calculate ----------------------------
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
   if(TimeCurrent() > expirationDate)
      return(0);

   if(AccountServer() != allowedServer)
      return(0);

   if(rates_total < 100) return(0);

   int start = (prev_calculated <= 0) ? (rates_total - 1) : (rates_total - prev_calculated);
   if(start > rates_total - 1) start = rates_total - 1;

   // ---- Storico a blocchi con buffer
   for(int i = start; i >= 0; i--)
   {
      int tfShift = iBarShift(NULL, (int)InpPivotTF, time[i], false);
      if(tfShift < 0) { HideAt(i); continue; }

      if(!InpShowHistory)
      {
         if(tfShift > 0) { HideAt(i); continue; }
      }
      else
      {
         if(tfShift > InpPeriodsBack) { HideAt(i); continue; }
      }

      double pp,r1,s1,r2,s2,r3,s3;
      CalcPivotsForShift(tfShift, pp,r1,s1,r2,s2,r3,s3);
      if(pp == EMPTY_VALUE) { HideAt(i); continue; }

      BufferPP[i]=pp;
      BufferR1[i]=r1; BufferS1[i]=s1;
      BufferR2[i]=r2; BufferS2[i]=s2;
      BufferR3[i]=r3; BufferS3[i]=s3;

      // spezza tra periodi pivot (niente collegamenti verticali)
      if(i < rates_total - 1)
      {
         int tfShiftNext = iBarShift(NULL, (int)InpPivotTF, time[i+1], false);
         if(tfShiftNext != tfShift) HideAt(i+1);
      }
   }

   // ---- Periodo corrente: estensione SOLO a destra + labels
   double pp0,r10,s10,r20,s20,r30,s30;
   CalcPivotsForShift(0, pp0,r10,s10,r20,s20,r30,s30);

   if(InpExtendTodayRight && pp0 != EMPTY_VALUE)
   {
      datetime t0 = time[0]; // ancora sulla barra più recente

      UpsertRayLine(ExtName("PP"), t0, pp0, ColorPP,  LineWidthPP,      STYLE_SOLID);
      UpsertRayLine(ExtName("R1"), t0, r10, ColorRes, LineWidthLevels,  STYLE_DASH);
      UpsertRayLine(ExtName("S1"), t0, s10, ColorSupp,LineWidthLevels,  STYLE_DASH);
      UpsertRayLine(ExtName("R2"), t0, r20, ColorRes, LineWidthLevels,  STYLE_DASH);
      UpsertRayLine(ExtName("S2"), t0, s20, ColorSupp,LineWidthLevels,  STYLE_DASH);
      UpsertRayLine(ExtName("R3"), t0, r30, ColorRes, LineWidthLevels,  STYLE_DASH);
      UpsertRayLine(ExtName("S3"), t0, s30, ColorSupp,LineWidthLevels,  STYLE_DASH);

      datetime tLabel = LabelTimeAnchor(time, rates_total);
      UpsertLabel(LblName("PP"), "PP", tLabel, pp0, ColorPP);
      UpsertLabel(LblName("R1"), "R1", tLabel, r10, ColorRes);
      UpsertLabel(LblName("S1"), "S1", tLabel, s10, ColorSupp);
      UpsertLabel(LblName("R2"), "R2", tLabel, r20, ColorRes);
      UpsertLabel(LblName("S2"), "S2", tLabel, s20, ColorSupp);
      UpsertLabel(LblName("R3"), "R3", tLabel, r30, ColorRes);
      UpsertLabel(LblName("S3"), "S3", tLabel, s30, ColorSupp);
   }
   else
   {
      DeleteAllObjects();
   }

   return(rates_total);
}

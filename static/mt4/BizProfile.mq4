//+------------------------------------------------------------------+
//|                                                   BizProfile.mq4 |
//|                                                    Investire.biz |
//|                                        https://www.Investire.biz |
//+------------------------------------------------------------------+
#property copyright "Investire.biz"
#property link      "https://www.Investire.biz"
#property version   "1.00"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//|   Data di scadenza                                               |
//+------------------------------------------------------------------+
input string allowedServerContains = "IG"; // Match parziale sul nome server
string supportEmail = "info@investire.biz";
datetime expirationDate = D'2026.04.07 00:00';

//+------------------------------------------------------------------+
//|   Definizioni                                                    |
//+------------------------------------------------------------------+
#define PUT_IN_RANGE(A, L, H) ((H) < (L) ? (A) : ((A) < (L) ? (L) : ((A) > (H) ? (H) : (A))))
#define COLOR_IS_NONE(C) (((C) >> 24) != 0)
#define RGB_TO_COLOR(R, G, B) ((color)((((B) & 0x0000FF) << 16) + (((G) & 0x0000FF) << 8) + ((R) & 0x0000FF)))
#define ROUND_PRICE(A, P) ((int)((A) / P + 0.5))
#define NORM_PRICE(A, P) (((int)((A) / P + 0.5)) * P)

enum ENUM_VP_BAR_STYLE
{
   VP_BAR_STYLE_LINE,
   VP_BAR_STYLE_BAR,
   VP_BAR_STYLE_FILLED,
   VP_BAR_STYLE_OUTLINE,
   VP_BAR_STYLE_COLOR
};

enum ENUM_HG_DIRECTION
{
   HG_DIRECTION_LEFT = 0,
   HG_DIRECTION_RIGHT = 1
};

enum ENUM_VP_SOURCE
{
   VP_SOURCE_TICKS = 0, // MT4 fallback su M1
   VP_SOURCE_M1 = 1,
   VP_SOURCE_M5 = 5,
   VP_SOURCE_M15 = 15,
   VP_SOURCE_M30 = 30
};

enum ENUM_TIME_SHIFT
{
   TIME_SHIFT_PLUS_720 = 720,
   TIME_SHIFT_PLUS_660 = 660,
   TIME_SHIFT_PLUS_600 = 600,
   TIME_SHIFT_PLUS_540 = 540,
   TIME_SHIFT_PLUS_480 = 480,
   TIME_SHIFT_PLUS_420 = 420,
   TIME_SHIFT_PLUS_360 = 360,
   TIME_SHIFT_PLUS_300 = 300,
   TIME_SHIFT_PLUS_240 = 240,
   TIME_SHIFT_PLUS_180 = 180,
   TIME_SHIFT_PLUS_120 = 120,
   TIME_SHIFT_PLUS_60 = 60,
   TIME_SHIFT_0 = 0,
   TIME_SHIFT_MINUS_60 = -60,
   TIME_SHIFT_MINUS_120 = -120,
   TIME_SHIFT_MINUS_180 = -180,
   TIME_SHIFT_MINUS_240 = -240,
   TIME_SHIFT_MINUS_300 = -300,
   TIME_SHIFT_MINUS_360 = -360,
   TIME_SHIFT_MINUS_420 = -420,
   TIME_SHIFT_MINUS_480 = -480,
   TIME_SHIFT_MINUS_540 = -540,
   TIME_SHIFT_MINUS_600 = -600,
   TIME_SHIFT_MINUS_660 = -660,
   TIME_SHIFT_MINUS_720 = -720
};

enum ENUM_VOLUME_TYPE
{
   VOLUME_TYPE_TICK = 0,
   VOLUME_TYPE_REAL = 1 // in MT4 fallback su tick volume
};

//+------------------------------------------------------------------+
//|   INPUT DELL'UTENTE                                              |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES RangePeriod = PERIOD_D1;
input int RangeCount = 10;
input ENUM_TIME_SHIFT TimeShift = TIME_SHIFT_0;
input int ModeStep = 100;
input int HgPointScale = 2;
input ENUM_VOLUME_TYPE VolumeType = VOLUME_TYPE_TICK;
input ENUM_VP_SOURCE DataSource = VP_SOURCE_M1;

input ENUM_VP_BAR_STYLE HgBarStyle = VP_BAR_STYLE_FILLED;
input ENUM_HG_DIRECTION DrawDirection = HG_DIRECTION_RIGHT;
input bool EstendiMax = true;
input color HgColor = C'168,168,255';
input color HgColor2 = C'255,157,157';
input int HgLineWidth = 1;

input color ModeColor = clrNONE;
input color MaxColor = clrNONE;
input color MedianColor = clrNONE;
input color VwapColor = clrNONE;
input int ModeLineWidth = 1;
input ENUM_LINE_STYLE StatLineStyle = STYLE_SOLID;

string Id = "BIZ Profile";
bool ShowHorizon = true;
double Zoom = 0;
int WaitMilliseconds = 1000;
int RangeLength = 0; // minuti, 0 = RangePeriod
input bool UpdateOnlyOnNewSourceBar = true; // riduce carico: aggiorna solo a nuova barra del source TF

//+------------------------------------------------------------------+
//|   Variabili globali                                              |
//+------------------------------------------------------------------+
string _prefix;
datetime _drawHistory[];
bool _lastOK = false;
int _modeStep = 0;
color _prevBackgroundColor = clrNONE;
int _rangeCount = 1;
ENUM_VP_BAR_STYLE _hgBarStyle = VP_BAR_STYLE_FILLED;
double _hgPoint = 0;
int _hgPointDigits = 0;
color _defaultHgColor1 = clrNONE;
color _defaultHgColor2 = clrNONE;
color _hgColor1 = clrNONE;
color _hgColor2 = clrNONE;
int _hgLineWidth = 1;
color _modeColor = clrNONE;
color _maxColor = clrNONE;
color _medianColor = clrNONE;
color _vwapColor = clrNONE;
int _modeLineWidth = 1;
ENUM_LINE_STYLE _statLineStyle = STYLE_SOLID;
color _modeLevelColor = clrNONE;
ENUM_LINE_STYLE _modeLevelStyle = STYLE_DOT;
int _modeLevelWidth = 1;
bool _showHg = false;
bool _showModes = false;
bool _showMax = false;
bool _showMedian = false;
bool _showVwap = false;
bool _showModeLevel = false;
double _zoom = 0;
int _timeShiftSeconds = 0;
ENUM_TIMEFRAMES _dataPeriod = PERIOD_M1;
bool _ticksFallbackNotified = false;
bool _historyWarningPrinted = false;
bool _fallbackInfoPrinted = false;
datetime _lastSourceBarTime = 0;
bool _forceUpdate = true;
bool _didVisualUpdate = false;

//+------------------------------------------------------------------+
//|   Millisecond timer                                              |
//+------------------------------------------------------------------+
class MillisecondTimer
{
private:
   int _milliseconds;
   uint _lastTick;

public:
   MillisecondTimer(const int milliseconds = 1000, const bool reset = true)
   {
      _milliseconds = milliseconds;
      if(_milliseconds < 1)
         _milliseconds = 1;
      if(reset)
         Reset();
      else
         _lastTick = 0;
   }

   bool Check()
   {
      uint now = GetTickCount();
      if((now - _lastTick) >= (uint)_milliseconds)
      {
         _lastTick = now;
         return true;
      }
      return false;
   }

   void Reset()
   {
      _lastTick = GetTickCount();
   }
};

MillisecondTimer *_updateTimer = NULL;

//+------------------------------------------------------------------+
//|   Utility                                                        |
//+------------------------------------------------------------------+
int PeriodSecondsSafe(const ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return 60;
      case PERIOD_M5: return 300;
      case PERIOD_M15: return 900;
      case PERIOD_M30: return 1800;
      case PERIOD_H1: return 3600;
      case PERIOD_H4: return 14400;
      case PERIOD_D1: return 86400;
      case PERIOD_W1: return 604800;
      case PERIOD_MN1: return 2592000;
      default: return 60;
   }
}

bool IsAllowedServer(const string allowedContains)
{
   string server = AccountServer();
   string needle = allowedContains;
   StringToUpper(server);
   StringToUpper(needle);
   if(StringLen(needle) == 0)
      return true;
   return (StringFind(server, needle, 0) >= 0);
}

bool CheckLicenseLocal(const datetime expiration, const string pSupportEmail,
                       const string productName, const string labelId,
                       const string allowedContains)
{
   datetime now = TimeCurrent();
   bool date_ok = (now <= expiration);
   bool server_ok = IsAllowedServer(allowedContains);
   if(date_ok && server_ok)
      return true;

   string msg1 = "Licenza " + productName + " scaduta o non valida per questo server.";
   string msg2 = "Contatta: " + pSupportEmail + " per una versione aggiornata.";
   string fullMsg = msg1 + " " + msg2;

   Print(fullMsg);
   MessageBox(fullMsg, "Errore Licenza", MB_OK | MB_ICONERROR);

   string labelIdLocal = (labelId == "" ? "BIZExpiredIndicatorText" : labelId);
   if(ObjectFind(labelIdLocal) < 0)
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

int ArrayIndexOfDatetime(const datetime &arr[], const datetime value, const int startingFrom = 0)
{
   int size = ArraySize(arr);
   for(int i = startingFrom; i < size; i++)
      if(arr[i] == value)
         return i;
   return -1;
}

int ArrayIndexOfInt(const int &arr[], const int value, const int startingFrom = 0)
{
   int size = ArraySize(arr);
   for(int i = startingFrom; i < size; i++)
      if(arr[i] == value)
         return i;
   return -1;
}

int ArrayAddDatetime(datetime &arr[], const datetime value, const bool checkUnique = false, const int reserveSize = 100)
{
   if(checkUnique)
   {
      int exists = ArrayIndexOfDatetime(arr, value);
      if(exists != -1)
         return exists;
   }
   int newSize = ArrayResize(arr, ArraySize(arr) + 1, reserveSize);
   if(newSize <= 0)
      return -1;
   int pos = newSize - 1;
   arr[pos] = value;
   return pos;
}

double SumDouble(const double &arr[])
{
   int size = ArraySize(arr);
   if(size <= 0)
      return 0.0;
   double s = 0.0;
   for(int i = 0; i < size; i++)
      s += arr[i];
   return s;
}

int ArrayMaximumDouble(const double &arr[])
{
   int size = ArraySize(arr);
   if(size <= 0)
      return -1;
   int k = 0;
   double best = arr[0];
   for(int i = 1; i < size; i++)
   {
      if(arr[i] > best)
      {
         best = arr[i];
         k = i;
      }
   }
   return k;
}

int ArrayMaxRangeDouble(const double &arr[], const int from, const int count)
{
   int size = ArraySize(arr);
   if(size <= 0 || count <= 0 || from < 0 || from >= size)
      return -1;
   int end = from + count;
   if(end > size)
      end = size;
   int k = from;
   double best = arr[from];
   for(int i = from + 1; i < end; i++)
   {
      if(arr[i] > best)
      {
         best = arr[i];
         k = i;
      }
   }
   return k;
}

int ArrayMedian(const double &values[])
{
   int size = ArraySize(values);
   if(size <= 0)
      return -1;
   double halfVolume = SumDouble(values) / 2.0;
   double v = 0;
   for(int i = 0; i < size; i++)
   {
      v += values[i];
      if(v >= halfVolume)
         return i;
   }
   return -1;
}

string TrimRight(string s, const ushort ch)
{
   int len = StringLen(s);
   int cut = len;
   for(int i = len - 1; i >= 0; i--)
   {
      if(StringGetCharacter(s, i) == ch)
         cut--;
      else
         break;
   }
   if(cut != len)
   {
      if(cut == 0)
         s = "";
      else
         s = StringSubstr(s, 0, cut);
   }
   return s;
}

string DoubleToStringSep(const double d, const int digits, const uchar separator)
{
   string s = DoubleToString(d, digits);
   if(separator != '.')
   {
      int p = StringFind(s, ".", 0);
      if(p != -1)
         StringSetCharacter(s, p, separator);
   }
   return s;
}

string DoubleToCompactString(const double d, const int digits = 8, const uchar separator = '.')
{
   string s = DoubleToStringSep(d, digits, separator);
   string sep = CharToString((uchar)separator);
   if(StringFind(s, sep, 0) != -1)
   {
      s = TrimRight(s, '0');
      s = TrimRight(s, separator);
   }
   return s;
}

double MathRoundStep(const double value, const double step)
{
   if(step == 0)
      return value;
   return MathRound(value / step) * step;
}

void SwapInt(int &value1, int &value2)
{
   int tmp = value1;
   value1 = value2;
   value2 = tmp;
}

int GetPointDigits(const double point, const int maxDigits)
{
   if(point == 0)
      return maxDigits;
   string pointString = DoubleToCompactString(point, maxDigits);
   int pointStringLen = StringLen(pointString);
   int dotPos = StringFind(pointString, ".", 0);
   return(dotPos < 0 ? StringLen(TrimRight(pointString, '0')) - pointStringLen : pointStringLen - dotPos - 1);
}

int GetPointDigits(const double point)
{
   if(point == 0)
      return Digits;
   return GetPointDigits(point, Digits);
}

int HgModes(const double &values[], const int modeStep, int &modes[])
{
   int modeCount = 0;
   ArrayFree(modes);
   int size = ArraySize(values);
   for(int i = modeStep; i < size - modeStep; i++)
   {
      int maxFrom = i - modeStep;
      int maxRange = 2 * modeStep + 1;
      int k = ArrayMaxRangeDouble(values, maxFrom, maxRange);
      if(k != i)
         continue;
      for(int j = i - modeStep; j <= i + modeStep; j++)
      {
         if(values[j] != values[k])
            continue;
         modeCount++;
         ArrayResize(modes, modeCount, size);
         modes[modeCount - 1] = j;
      }
   }
   return modeCount;
}

int HgVwap(const double &volumes[], const double low, const double step)
{
   if(step == 0)
      return -1;
   int size = ArraySize(volumes);
   if(size <= 0)
      return -1;
   double vwap = 0;
   double totalVolume = 0;
   for(int i = 0; i < size; i++)
   {
      double price = low + i * step;
      double volume = volumes[i];
      vwap += price * volume;
      totalVolume += volume;
   }
   if(totalVolume == 0)
      return -1;
   vwap /= totalVolume;
   return (int)((vwap - low) / step + 0.5);
}

bool ColorToRGB(const color c, int &r, int &g, int &b)
{
   if(COLOR_IS_NONE(c))
      return false;
   b = (c & 0xFF0000) >> 16;
   g = (c & 0x00FF00) >> 8;
   r = (c & 0x0000FF);
   return true;
}

color MixColors(const color color1, const color color2, double mix, double step = 16)
{
   step = PUT_IN_RANGE(step, 1.0, 255.0);
   mix = PUT_IN_RANGE(mix, 0.0, 1.0);
   int r1, g1, b1;
   int r2, g2, b2;
   ColorToRGB(color1, r1, g1, b1);
   ColorToRGB(color2, r2, g2, b2);
   int r = PUT_IN_RANGE((int)MathRoundStep(r1 + mix * (r2 - r1), step), 0, 255);
   int g = PUT_IN_RANGE((int)MathRoundStep(g1 + mix * (g2 - g1), step), 0, 255);
   int b = PUT_IN_RANGE((int)MathRoundStep(b1 + mix * (b2 - b1), step), 0, 255);
   return RGB_TO_COLOR(r, g, b);
}

bool ColorIsNone(const color c)
{
   return COLOR_IS_NONE(c);
}

void AddTimeframeUnique(ENUM_TIMEFRAMES &arr[], const ENUM_TIMEFRAMES tf)
{
   int size = ArraySize(arr);
   for(int i = 0; i < size; i++)
      if(arr[i] == tf)
         return;
   ArrayResize(arr, size + 1);
   arr[size] = tf;
}

void BuildFallbackPeriods(const ENUM_TIMEFRAMES preferredPeriod, ENUM_TIMEFRAMES &periods[])
{
   ArrayResize(periods, 0);
   AddTimeframeUnique(periods, preferredPeriod);

   // Fallback progressivo verso timeframe piu' alti per coprire range con storico scarso.
   if(preferredPeriod <= PERIOD_M1)
   {
      AddTimeframeUnique(periods, PERIOD_M5);
      AddTimeframeUnique(periods, PERIOD_M15);
      AddTimeframeUnique(periods, PERIOD_M30);
      AddTimeframeUnique(periods, PERIOD_H1);
   }
   else if(preferredPeriod <= PERIOD_M5)
   {
      AddTimeframeUnique(periods, PERIOD_M15);
      AddTimeframeUnique(periods, PERIOD_M30);
      AddTimeframeUnique(periods, PERIOD_H1);
   }
   else if(preferredPeriod <= PERIOD_M15)
   {
      AddTimeframeUnique(periods, PERIOD_M30);
      AddTimeframeUnique(periods, PERIOD_H1);
   }
   else if(preferredPeriod <= PERIOD_M30)
   {
      AddTimeframeUnique(periods, PERIOD_H1);
   }
}

bool IsRangeCoveredByPeriod(const datetime timeFrom, const datetime timeTo, const ENUM_TIMEFRAMES period)
{
   int ps = PeriodSecondsSafe(period);
   if(ps <= 0)
      ps = 60;

   datetime nowTime = TimeCurrent();
   datetime requiredTo = (timeTo < nowTime ? timeTo : nowTime);
   if(requiredTo < timeFrom)
      requiredTo = timeFrom;

   int bFrom = iBarShift(Symbol(), period, timeFrom, false);
   int bTo = iBarShift(Symbol(), period, requiredTo, false);
   if(bFrom < 0 || bTo < 0)
      return false;

   datetime t1 = iTime(Symbol(), period, bFrom);
   datetime t2 = iTime(Symbol(), period, bTo);
   if(t1 <= 0 || t2 <= 0)
      return false;

   datetime oldest = (t1 < t2 ? t1 : t2);
   datetime newest = (t1 > t2 ? t1 : t2);
   int tolerance = 2 * ps;
   if(oldest > (timeFrom + tolerance))
      return false;
   if((newest + ps) < (requiredTo - tolerance))
      return false;
   return true;
}

//+------------------------------------------------------------------+
//|   Data source selection                                          |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetDataPeriod(const ENUM_VP_SOURCE dataSource)
{
   switch(dataSource)
   {
      case VP_SOURCE_TICKS:
         if(!_ticksFallbackNotified)
         {
            Print("VP_SOURCE_TICKS non supportato in MT4: fallback automatico a M1.");
            _ticksFallbackNotified = true;
         }
         return PERIOD_M1;
      case VP_SOURCE_M1: return PERIOD_M1;
      case VP_SOURCE_M5: return PERIOD_M5;
      case VP_SOURCE_M15: return PERIOD_M15;
      case VP_SOURCE_M30: return PERIOD_M30;
      default: return PERIOD_M1;
   }
}

datetime GetHorizon(const ENUM_VP_SOURCE dataSource, const ENUM_TIMEFRAMES dataPeriod)
{
   if(dataSource == VP_SOURCE_TICKS)
      return TimeCurrent();
   int bars = iBars(Symbol(), dataPeriod);
   if(bars <= 0)
      return TimeCurrent();
   return iTime(Symbol(), dataPeriod, bars - 1);
}

//+------------------------------------------------------------------+
//|   Bar time helpers                                               |
//+------------------------------------------------------------------+
int GetTimeBarRight(const datetime t, ENUM_TIMEFRAMES period = PERIOD_CURRENT)
{
   int bar = iBarShift(Symbol(), period, t, false);
   if(bar < 0)
      bar = 0;
   datetime bt = iTime(Symbol(), period, bar);
   if((bt != t) && (bar == 0))
   {
      datetime nowBarTime = iTime(Symbol(), period, 0);
      int ps = PeriodSecondsSafe(period);
      if(ps <= 0)
         ps = 60;
      bar = (int)((nowBarTime - t) / ps);
   }
   else
   {
      if(bt < t)
         bar--;
   }
   if(bar < 0)
      bar = 0;
   return bar;
}

datetime GetBarTime(const int shift, ENUM_TIMEFRAMES period = PERIOD_CURRENT)
{
   if(shift >= 0)
      return iTime(Symbol(), period, shift);
   return iTime(Symbol(), period, 0) - shift * PeriodSecondsSafe(period);
}

//+------------------------------------------------------------------+
//|   Draw functions                                                 |
//+------------------------------------------------------------------+
void ObjectDisable(const string name)
{
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawVLine(const string name, const datetime time1, const color lineColor, const int width, const int style, const bool back)
{
   if(ObjectFind(name) >= 0)
      ObjectDelete(name);
   ObjectCreate(0, name, OBJ_VLINE, 0, time1, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

void DrawHorizon(const string lineName, const datetime t)
{
   DrawVLine(lineName, t, clrRed, 1, STYLE_DOT, false);
   ObjectDisable(lineName);
}

void SetBarStyle(const string name, const color lineColor, const int width, const ENUM_VP_BAR_STYLE barStyle, const ENUM_LINE_STYLE lineStyle, const bool back)
{
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, (lineStyle == STYLE_SOLID ? width : 1));
   ObjectSetInteger(0, name, OBJPROP_RAY, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_FILL, (barStyle == VP_BAR_STYLE_FILLED) || (barStyle == VP_BAR_STYLE_COLOR));
}

void DrawBar(const string name, const datetime time1, const datetime time2, const double price, const color lineColor, const int width, const ENUM_VP_BAR_STYLE barStyle, const ENUM_LINE_STYLE lineStyle, const bool back)
{
   ObjectDelete(name);
   if((barStyle == VP_BAR_STYLE_BAR) || (barStyle == VP_BAR_STYLE_FILLED) || (barStyle == VP_BAR_STYLE_COLOR))
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price - _hgPoint / 2.0, time2, price + _hgPoint / 2.0);
   }
   else if(barStyle == VP_BAR_STYLE_OUTLINE)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price + _hgPoint);
   }
   else
   {
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
   }
   SetBarStyle(name, lineColor, width, barStyle, lineStyle, back);
}

void DrawLevel(const string name, const double price)
{
   ObjectDelete(name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, _modeLevelColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, _modeLevelStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, (_modeLevelStyle == STYLE_SOLID ? _modeLevelWidth : 1));
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

datetime CalculateCurrentPeriodEndTime()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime s;
   TimeToStruct(currentTime, s);

   if(RangePeriod >= PERIOD_D1)
   {
      s.hour = 23;
      s.min = 59;
      s.sec = 59;
      return StructToTime(s);
   }
   int ps = PeriodSecondsSafe(RangePeriod);
   if(ps <= 0)
      ps = 60;
   datetime nextPeriodStart = currentTime - (currentTime % ps) + ps;
   return nextPeriodStart - 1;
}

void DrawHg(const string prefix, const double lowPrice, const double &volumes[], const int barFrom, const int barTo, double zoom,
            const int &modes[], const int max = -1, const int median = -1, const int vwap = -1, const datetime extendMaxTo = 0)
{
   int size = ArraySize(volumes);
   if(size == 0)
      return;

   if(barFrom > barTo)
      zoom = -zoom;

   color cl = _hgColor1;
   int maxIdx = ArrayMaximumDouble(volumes);
   double maxValue = (maxIdx >= 0 ? volumes[maxIdx] : 0);
   if(maxValue == 0)
      maxValue = 1;

   bool isOutline = (_hgBarStyle == VP_BAR_STYLE_OUTLINE);
   int bar1 = barFrom;
   int bar2 = barTo;
   int modeBar2 = barTo;

   for(int i = 0; i < size; i++)
   {
      double price = NormalizeDouble(lowPrice + i * _hgPoint, _hgPointDigits);
      string priceString = DoubleToString(price, _hgPointDigits);
      string name = prefix + priceString;
      double volume = volumes[i];
      double nextVolume = 0;

      if(isOutline)
      {
         if(i < size - 1)
         {
            nextVolume = volumes[i + 1];
            bar1 = (int)(barFrom + volume * zoom);
            bar2 = (int)(barFrom + nextVolume * zoom);
            modeBar2 = bar1;
         }
      }
      else if(_hgBarStyle != VP_BAR_STYLE_COLOR)
      {
         bar2 = (int)(barFrom + volume * zoom);
         modeBar2 = bar2;
      }

      datetime timeFrom = GetBarTime(barFrom);
      datetime timeTo = GetBarTime(barTo);
      datetime t1 = GetBarTime(bar1);
      datetime t2 = GetBarTime(bar2);
      datetime mt2 = GetBarTime(modeBar2);

      bool isMode = (ArrayIndexOfInt(modes, i) != -1);
      bool isMax = (_showMax && (i == max));
      bool isMedian = (_showMedian && (i == median));
      bool isVwap = (_showVwap && (i == vwap));

      if(_showModeLevel && isMode)
         DrawLevel(name + " level", price);

      if(_showHg && !(isOutline && (i == size - 1)))
      {
         bool drawHgBar = true;
         if(isOutline)
         {
            if(i < size - 1 && volume <= 0.0 && nextVolume <= 0.0)
               drawHgBar = false;
         }
         else if(volume <= 0.0)
         {
            drawHgBar = false;
         }
         if(drawHgBar)
         {
            if(_hgColor1 != _hgColor2)
               cl = MixColors(_hgColor1, _hgColor2, (isOutline ? MathMax(volume, nextVolume) : volume) / maxValue, 8);
            DrawBar(name, t1, t2, price, cl, _hgLineWidth, _hgBarStyle, STYLE_SOLID, true);
         }
      }

      if(isMedian)
      {
         DrawBar(name + " median", timeFrom, timeTo, price, _medianColor, _modeLineWidth, VP_BAR_STYLE_LINE, _statLineStyle, false);
      }
      else if(isVwap)
      {
         DrawBar(name + " vwap", timeFrom, timeTo, price, _vwapColor, _modeLineWidth, VP_BAR_STYLE_LINE, _statLineStyle, false);
      }
      else if(isMax || (_showModes && isMode))
      {
         color modeColor = isMax ? _maxColor : _modeColor;

         if(isMax && EstendiMax && extendMaxTo > 0)
         {
            if(DrawDirection == HG_DIRECTION_RIGHT)
            {
               if(extendMaxTo > mt2)
                  mt2 = extendMaxTo;
            }
            else
            {
               if(extendMaxTo > timeFrom)
                  timeFrom = extendMaxTo;
            }
         }

         if(_hgBarStyle == VP_BAR_STYLE_LINE)
            DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_LINE, STYLE_SOLID, false);
         else if(_hgBarStyle == VP_BAR_STYLE_BAR)
            DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_BAR, STYLE_SOLID, false);
         else if(_hgBarStyle == VP_BAR_STYLE_FILLED)
            DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_FILLED, STYLE_SOLID, false);
         else if(_hgBarStyle == VP_BAR_STYLE_OUTLINE)
            DrawBar(name + "+", timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_LINE, STYLE_SOLID, false);
         else if(_hgBarStyle == VP_BAR_STYLE_COLOR)
            DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_FILLED, STYLE_SOLID, false);
      }
   }
}

bool GetRangeBars(const datetime timeFrom, const datetime timeTo, int &barFrom, int &barTo)
{
   barFrom = GetTimeBarRight(timeFrom);
   barTo = GetTimeBarRight(timeTo);
   return true;
}

bool UpdateAutoColors()
{
   if(!_showHg)
      return false;
   bool isNone1 = ColorIsNone(_defaultHgColor1);
   bool isNone2 = ColorIsNone(_defaultHgColor2);
   if(isNone1 && isNone2)
      return false;

   color newBgColor = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND, 0);
   if(newBgColor == _prevBackgroundColor)
      return false;

   _hgColor1 = isNone1 ? newBgColor : _defaultHgColor1;
   _hgColor2 = isNone2 ? newBgColor : _defaultHgColor2;
   _prevBackgroundColor = newBgColor;
   return true;
}

//+------------------------------------------------------------------+
//|   Histogram calculation (MT4 bars)                               |
//+------------------------------------------------------------------+
int GetHg(const datetime timeFrom, const datetime timeTo, const double point, const ENUM_TIMEFRAMES dataPeriod,
          const ENUM_VOLUME_TYPE appliedVolume, double &low, double &volumes[])
{
   int first = iBarShift(Symbol(), dataPeriod, timeTo, false);
   int last = iBarShift(Symbol(), dataPeriod, timeFrom, false);
   if(first < 0 || last < 0)
      return 0;
   if(last < first)
      SwapInt(last, first);

   bool inited = false;
   double high = 0;
   for(int shift = first; shift <= last; shift++)
   {
      double rLow = NORM_PRICE(iLow(Symbol(), dataPeriod, shift), point);
      double rHigh = NORM_PRICE(iHigh(Symbol(), dataPeriod, shift), point);
      if(!inited)
      {
         low = rLow;
         high = rHigh;
         inited = true;
      }
      else
      {
         if(rLow < low)
            low = rLow;
         if(rHigh > high)
            high = rHigh;
      }
   }
   if(!inited)
      return 0;

   int lowIndex = ROUND_PRICE(low, point);
   int highIndex = ROUND_PRICE(high, point);
   int hgSize = highIndex - lowIndex + 1;
   if(hgSize <= 0)
      return 0;

   ArrayResize(volumes, hgSize);
   ArrayInitialize(volumes, 0.0);

   for(int s = first; s <= last; s++)
   {
      double o = iOpen(Symbol(), dataPeriod, s);
      double h = iHigh(Symbol(), dataPeriod, s);
      double l = iLow(Symbol(), dataPeriod, s);
      double c = iClose(Symbol(), dataPeriod, s);
      int oi = ROUND_PRICE(o, point) - lowIndex;
      int hi = ROUND_PRICE(h, point) - lowIndex;
      int li = ROUND_PRICE(l, point) - lowIndex;
      int ci = ROUND_PRICE(c, point) - lowIndex;
      double v = (double)iVolume(Symbol(), dataPeriod, s); // MT4: tick volume
      if(appliedVolume == VOLUME_TYPE_REAL)
         v = (double)iVolume(Symbol(), dataPeriod, s); // fallback

      double dv;
      int pri;
      if(ci >= oi)
      {
         dv = v / (oi - li + hi - li + hi - ci + 1.0);
         for(pri = oi; pri >= li; pri--)
            if(pri >= 0 && pri < hgSize)
               volumes[pri] += dv;
         for(pri = li + 1; pri <= hi; pri++)
            if(pri >= 0 && pri < hgSize)
               volumes[pri] += dv;
         for(pri = hi - 1; pri >= ci; pri--)
            if(pri >= 0 && pri < hgSize)
               volumes[pri] += dv;
      }
      else
      {
         dv = v / (hi - oi + hi - li + ci - li + 1.0);
         for(pri = oi; pri <= hi; pri++)
            if(pri >= 0 && pri < hgSize)
               volumes[pri] += dv;
         for(pri = hi - 1; pri >= li; pri--)
            if(pri >= 0 && pri < hgSize)
               volumes[pri] += dv;
         for(pri = li + 1; pri <= ci; pri++)
            if(pri >= 0 && pri < hgSize)
               volumes[pri] += dv;
      }
   }
   return hgSize;
}

int GetHgWithFallback(const datetime timeFrom, const datetime timeTo, const double point, const ENUM_TIMEFRAMES preferredPeriod,
                      const ENUM_VOLUME_TYPE appliedVolume, double &low, double &volumes[], ENUM_TIMEFRAMES &usedPeriod)
{
   ENUM_TIMEFRAMES periods[];
   BuildFallbackPeriods(preferredPeriod, periods);
   int size = ArraySize(periods);
   for(int i = 0; i < size; i++)
   {
      ENUM_TIMEFRAMES tf = periods[i];
      if(!IsRangeCoveredByPeriod(timeFrom, timeTo, tf))
         continue;
      int count = GetHg(timeFrom, timeTo, point, tf, appliedVolume, low, volumes);
      if(count > 0)
      {
         usedPeriod = tf;
         return count;
      }
   }
   usedPeriod = preferredPeriod;
   return 0;
}

//+------------------------------------------------------------------+
//|   Core update                                                    |
//+------------------------------------------------------------------+
bool Update()
{
   _didVisualUpdate = false;
   if(UpdateOnlyOnNewSourceBar && !_forceUpdate)
   {
      datetime currentSourceBarTime = iTime(Symbol(), _dataPeriod, 0);
      if(currentSourceBarTime > 0 && currentSourceBarTime == _lastSourceBarTime)
         return true;
   }

   datetime ranges[];
   ArraySetAsSeries(ranges, true);
   ArrayResize(ranges, _rangeCount);
   for(int i = 0; i < _rangeCount; i++)
   {
      ranges[i] = iTime(Symbol(), RangePeriod, i);
      if(ranges[i] <= 0)
         return false;
   }

   if(RangePeriod == PERIOD_W1)
   {
      for(int w = 0; w < _rangeCount; w++)
         ranges[w] += 1440 * 60;
   }

   int rangeLengthSeconds = (RangeLength == 0 ? PeriodSecondsSafe(RangePeriod) : RangeLength * 60);
   if(rangeLengthSeconds <= 0)
      return false;

   datetime lastTickTime = TimeCurrent();
   if(ShowHorizon)
   {
      datetime horizon = GetHorizon(DataSource, _dataPeriod);
      DrawHorizon(_prefix + "hz", horizon);
   }

   int modes[];
   double volumes[];
   double lowPrice = 0;
   bool totalResult = true;
   bool anyDraw = false;

   for(int i = 0; i < _rangeCount; i++)
   {
      datetime rangeStart = ranges[i] + _timeShiftSeconds;
      if(TimeDayOfWeek(rangeStart) == 0)
         rangeStart -= 2 * 1440 * 60;

      if((i != 0) && (ArrayIndexOfDatetime(_drawHistory, rangeStart) != -1))
         continue;

      datetime rangeEnd;
      if(i == 0)
      {
         rangeEnd = ranges[i] + _timeShiftSeconds + rangeLengthSeconds - 1;
      }
      else
      {
         rangeEnd = ranges[i - 1] + _timeShiftSeconds - 1;
         if(TimeDayOfWeek(rangeEnd) == 0)
            rangeEnd -= 2 * 1440 * 60;
      }

      int barFrom, barTo;
      if(!GetRangeBars(rangeStart, rangeEnd, barFrom, barTo))
      {
         totalResult = false;
         continue;
      }
      string prefix = _prefix + IntegerToString((int)(rangeStart / PeriodSecondsSafe(RangePeriod))) + " ";

      // MT4: VP_SOURCE_TICKS fallback automatico a M1 (gestito in _dataPeriod)
      ENUM_TIMEFRAMES usedPeriod = _dataPeriod;
      int count = GetHgWithFallback(rangeStart, rangeEnd, _hgPoint, _dataPeriod, VolumeType, lowPrice, volumes, usedPeriod);
      if(count <= 0)
      {
         if(!_historyWarningPrinted)
         {
            Print("Storico incompleto per ", Symbol(), " TF=", (int)_dataPeriod, ". "
                  "Carica piu' storico (soprattutto M1) per vedere tutti i blocchi correttamente.");
            _historyWarningPrinted = true;
         }
         totalResult = false;
         continue;
      }
      if(usedPeriod != _dataPeriod && !_fallbackInfoPrinted)
      {
         Print("Storico non completo su TF=", (int)_dataPeriod, " -> fallback automatico TF=", (int)usedPeriod, " per alcuni blocchi.");
         _fallbackInfoPrinted = true;
      }

      if(rangeEnd < lastTickTime)
         ArrayAddDatetime(_drawHistory, rangeStart, true);

      ArrayFree(modes);
      if(_showModes)
         HgModes(volumes, _modeStep, modes);
      int maxPos = _showMax ? ArrayMaximumDouble(volumes) : -1;
      int medianPos = _showMedian ? ArrayMedian(volumes) : -1;
      int vwapPos = _showVwap ? HgVwap(volumes, lowPrice, _hgPoint) : -1;

      int maxIdx = ArrayMaximumDouble(volumes);
      double maxVolume = (maxIdx >= 0 ? volumes[maxIdx] : 1.0);
      if(maxVolume == 0)
         maxVolume = 1.0;
      double zoom = _zoom > 0 ? _zoom : ((double)(barFrom - barTo) / maxVolume);

      if(DrawDirection == HG_DIRECTION_LEFT)
         SwapInt(barFrom, barTo);

      DeleteObjectsByPrefix(prefix);
      datetime extendMaxTo = 0;
      // Evita che i profili storici vengano "schiacciati" da estensioni dei massimi fino a oggi.
      if(EstendiMax && i == 0)
         extendMaxTo = CalculateCurrentPeriodEndTime();
      DrawHg(prefix, lowPrice, volumes, barFrom, barTo, zoom, modes, maxPos, medianPos, vwapPos, extendMaxTo);
      anyDraw = true;
   }

   _didVisualUpdate = anyDraw;
   if(totalResult)
   {
      _lastSourceBarTime = iTime(Symbol(), _dataPeriod, 0);
      _forceUpdate = false;
      return true;
   }

   // In caso di dati incompleti ritenta al prossimo giro timer.
   _forceUpdate = true;
   return false;
}

void CheckTimer()
{
   if(_updateTimer == NULL)
      return;

   if(_updateTimer.Check() || !_lastOK)
   {
      _lastOK = Update();
      if(_didVisualUpdate)
         ChartRedraw();
      _updateTimer.Reset();
   }
}

//+------------------------------------------------------------------+
//|   Events                                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!CheckLicenseLocal(expirationDate, supportEmail, "BIZ Profile", "BIZExpiredIndicatorText", allowedServerContains))
   {
      indicatoreScaduto();
      return INIT_SUCCEEDED;
   }

   _prefix = Id + " " + IntegerToString((int)RangePeriod) + " ";
   _rangeCount = (RangeCount > 0 ? RangeCount : 1);
   _hgPoint = Point * HgPointScale;
   _modeStep = (HgPointScale > 0 ? ModeStep / HgPointScale : ModeStep);
   if(_modeStep < 1)
      _modeStep = 1;

   ArrayFree(_drawHistory);
   _hgBarStyle = HgBarStyle;
   _hgPointDigits = GetPointDigits(_hgPoint);
   _defaultHgColor1 = HgColor;
   _defaultHgColor2 = HgColor2;
   _hgLineWidth = HgLineWidth;
   _modeColor = ModeColor;
   _maxColor = MaxColor;
   _medianColor = MedianColor;
   _vwapColor = VwapColor;
   _modeLineWidth = ModeLineWidth;
   _statLineStyle = StatLineStyle;
   _modeLevelColor = _modeColor;
   _modeLevelStyle = STYLE_DOT;
   _modeLevelWidth = 1;
   _showModeLevel = false;

   _showHg = !(ColorIsNone(_defaultHgColor1) && ColorIsNone(_defaultHgColor2));
   _showModes = !ColorIsNone(_modeColor);
   _showMax = !ColorIsNone(_maxColor);
   _showMedian = !ColorIsNone(_medianColor);
   _showVwap = !ColorIsNone(_vwapColor);
   _zoom = MathAbs(Zoom);
   _updateTimer = new MillisecondTimer(WaitMilliseconds, false);
   int ps = PeriodSecondsSafe(RangePeriod);
   _timeShiftSeconds = (((int)TimeShift * 60) % ps);
   if(_timeShiftSeconds < 0)
      _timeShiftSeconds += ps;
   _dataPeriod = GetDataPeriod(DataSource);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(_prefix);
   ObjectDelete("ExpiredIndicatorText");
   ObjectDelete("ExpiredIndicatorText2");
   ObjectDelete("BIZExpiredIndicatorText");
   EventKillTimer();
   if(_updateTimer != NULL)
   {
      delete _updateTimer;
      _updateTimer = NULL;
   }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(UpdateAutoColors())
      {
         ArrayFree(_drawHistory);
         _forceUpdate = true;
         CheckTimer();
      }
   }
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[])
{
   if(UpdateAutoColors())
      ArrayFree(_drawHistory);
   CheckTimer();
   return rates_total;
}

void OnTimer()
{
   CheckTimer();
}

//+--------------------------------------------------------------------------------+
//| INDICATORE SCADUTO                                                             |
//+--------------------------------------------------------------------------------+
void indicatoreScaduto()
{
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int center_x = chart_width / 2;
   int center_y = chart_height / 2;
   string messageLine1 = "La licenza per l'indicatore BizProfile e' scaduta.";
   string messageLine2 = "Per informazioni contatta info@investire.biz";
   Print("La licenza per l'indicatore BizProfile e' scaduta. Per informazioni contatta info@investire.biz");

   ObjectCreate(0, "ExpiredIndicatorText", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "ExpiredIndicatorText", OBJPROP_TEXT, messageLine1);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_YDISTANCE, center_y);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "ExpiredIndicatorText", OBJPROP_ANCHOR, ANCHOR_CENTER);

   ObjectCreate(0, "ExpiredIndicatorText2", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "ExpiredIndicatorText2", OBJPROP_TEXT, messageLine2);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_XDISTANCE, center_x);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_YDISTANCE, center_y + 30);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_FONTSIZE, 18);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "ExpiredIndicatorText2", OBJPROP_ANCHOR, ANCHOR_CENTER);
}


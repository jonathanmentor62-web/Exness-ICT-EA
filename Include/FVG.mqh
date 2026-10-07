#ifndef __EXNESS_GOLD_FVG_MQH__
#define __EXNESS_GOLD_FVG_MQH__

enum ENUM_FVG_DIRECTION
{
   FVG_NONE = 0,
   FVG_BULLISH,
   FVG_BEARISH
};

struct FVGZone
{
   bool valid;
   bool mitigated;
   bool invalidated;
   bool retested;

   ENUM_FVG_DIRECTION direction;

   double upper;
   double lower;
   double midpoint;
   double size;

   int signalShift;
   datetime signalTime;
};


//====================================================================
// RESET
//====================================================================

void ResetFVG(FVGZone &fvg)
{
   fvg.valid = false;
   fvg.mitigated = false;
   fvg.invalidated = false;
   fvg.retested = false;

   fvg.direction = FVG_NONE;

   fvg.upper = 0.0;
   fvg.lower = 0.0;
   fvg.midpoint = 0.0;
   fvg.size = 0.0;

   fvg.signalShift = -1;
   fvg.signalTime = 0;
}


//====================================================================
// BASIC DETECTION
//====================================================================

bool DetectBullishFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumSize,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(shift < 1)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= shift + 2)
      return false;

   double oldestHigh = iHigh(symbol, timeframe, shift + 2);
   double newestLow  = iLow(symbol, timeframe, shift);

   if(oldestHigh <= 0.0 || newestLow <= 0.0)
      return false;

   if(newestLow <= oldestHigh)
      return false;

   double size = newestLow - oldestHigh;

   if(size < minimumSize)
      return false;

   fvg.valid = true;
   fvg.direction = FVG_BULLISH;

   fvg.lower = oldestHigh;
   fvg.upper = newestLow;
   fvg.midpoint = (fvg.lower + fvg.upper) / 2.0;
   fvg.size = size;

   fvg.signalShift = shift;
   fvg.signalTime = iTime(symbol, timeframe, shift);

   return true;
}


bool DetectBearishFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumSize,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(shift < 1)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= shift + 2)
      return false;

   double newestHigh = iHigh(symbol, timeframe, shift);
   double oldestLow  = iLow(symbol, timeframe, shift + 2);

   if(newestHigh <= 0.0 || oldestLow <= 0.0)
      return false;

   if(newestHigh >= oldestLow)
      return false;

   double size = oldestLow - newestHigh;

   if(size < minimumSize)
      return false;

   fvg.valid = true;
   fvg.direction = FVG_BEARISH;

   fvg.lower = newestHigh;
   fvg.upper = oldestLow;
   fvg.midpoint = (fvg.lower + fvg.upper) / 2.0;
   fvg.size = size;

   fvg.signalShift = shift;
   fvg.signalTime = iTime(symbol, timeframe, shift);

   return true;
}


//====================================================================
// GENERIC DETECTION
//====================================================================

int DetectFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumSize,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(DetectBullishFVG(
      symbol,
      timeframe,
      shift,
      minimumSize,
      fvg
   ))
      return 1;

   if(DetectBearishFVG(
      symbol,
      timeframe,
      shift,
      minimumSize,
      fvg
   ))
      return -1;

   return 0;
}


//====================================================================
// SEARCH
//====================================================================

bool FindRecentBullishFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int startShift,
   int lookback,
   double minimumSize,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(startShift < 1)
      startShift = 1;

   if(lookback <= 0)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= startShift + 2)
      return false;

   int endShift = MathMin(
      startShift + lookback - 1,
      bars - 3
   );

   for(int shift = startShift; shift <= endShift; shift++)
   {
      if(DetectBullishFVG(
         symbol,
         timeframe,
         shift,
         minimumSize,
         fvg
      ))
         return true;
   }

   return false;
}


bool FindRecentBearishFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int startShift,
   int lookback,
   double minimumSize,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(startShift < 1)
      startShift = 1;

   if(lookback <= 0)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= startShift + 2)
      return false;

   int endShift = MathMin(
      startShift + lookback - 1,
      bars - 3
   );

   for(int shift = startShift; shift <= endShift; shift++)
   {
      if(DetectBearishFVG(
         symbol,
         timeframe,
         shift,
         minimumSize,
         fvg
      ))
         return true;
   }

   return false;
}


bool FindDirectionalFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int direction,
   int startShift,
   int lookback,
   double minimumSize,
   FVGZone &fvg
)
{
   if(direction > 0)
      return FindRecentBullishFVG(
         symbol,
         timeframe,
         startShift,
         lookback,
         minimumSize,
         fvg
      );

   if(direction < 0)
      return FindRecentBearishFVG(
         symbol,
         timeframe,
         startShift,
         lookback,
         minimumSize,
         fvg
      );

   ResetFVG(fvg);
   return false;
}


//====================================================================
// PRICE LOCATION
//====================================================================

bool IsPriceInsideFVG(
   double price,
   FVGZone &fvg
)
{
   if(!fvg.valid || fvg.invalidated)
      return false;

   return
      price >= fvg.lower &&
      price <= fvg.upper;
}


bool IsPriceAboveFVG(
   double price,
   FVGZone &fvg
)
{
   return
      fvg.valid &&
      price > fvg.upper;
}


bool IsPriceBelowFVG(
   double price,
   FVGZone &fvg
)
{
   return
      fvg.valid &&
      price < fvg.lower;
}


//====================================================================
// MITIGATION / RETEST
//====================================================================

bool IsFVGMitigated(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   FVGZone &fvg,
   int currentShift
)
{
   if(!fvg.valid || currentShift < 1)
      return false;

   double high = iHigh(symbol, timeframe, currentShift);
   double low  = iLow(symbol, timeframe, currentShift);

   if(high <= 0.0 || low <= 0.0)
      return false;

   bool touched =
      high >= fvg.lower &&
      low <= fvg.upper;

   if(touched)
      fvg.mitigated = true;

   return fvg.mitigated;
}


bool IsFVGRetest(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   FVGZone &fvg,
   int shift
)
{
   if(!fvg.valid || shift < 1)
      return false;

   double high = iHigh(symbol, timeframe, shift);
   double low  = iLow(symbol, timeframe, shift);

   double open = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0)
      return false;

   bool touched =
      high >= fvg.lower &&
      low <= fvg.upper;

   if(!touched)
      return false;

   // Bullish FVG: rejection back upward.
   if(fvg.direction == FVG_BULLISH)
   {
      if(close > open && close >= fvg.midpoint)
      {
         fvg.retested = true;
         return true;
      }
   }

   // Bearish FVG: rejection back downward.
   if(fvg.direction == FVG_BEARISH)
   {
      if(close < open && close <= fvg.midpoint)
      {
         fvg.retested = true;
         return true;
      }
   }

   return false;
}


//====================================================================
// INVALIDATION
//====================================================================

bool IsFVGInvalidated(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   FVGZone &fvg,
   int shift
)
{
   if(!fvg.valid || shift < 1)
      return false;

   double close = iClose(symbol, timeframe, shift);

   if(close <= 0.0)
      return false;

   // Bullish FVG becomes invalid if price closes below it.
   if(fvg.direction == FVG_BULLISH)
   {
      if(close < fvg.lower)
      {
         fvg.invalidated = true;
         return true;
      }
   }

   // Bearish FVG becomes invalid if price closes above it.
   if(fvg.direction == FVG_BEARISH)
   {
      if(close > fvg.upper)
      {
         fvg.invalidated = true;
         return true;
      }
   }

   return false;
}


//====================================================================
// FRESHNESS
//====================================================================

bool IsFreshFVG(
   FVGZone &fvg
)
{
   return
      fvg.valid &&
      !fvg.mitigated &&
      !fvg.invalidated;
}


//====================================================================
// DIRECTION HELPERS
//====================================================================

bool IsBullishFVG(FVGZone &fvg)
{
   return
      fvg.valid &&
      fvg.direction == FVG_BULLISH;
}


bool IsBearishFVG(FVGZone &fvg)
{
   return
      fvg.valid &&
      fvg.direction == FVG_BEARISH;
}


//====================================================================
// TEXT
//====================================================================

string FVGDirectionToString(
   ENUM_FVG_DIRECTION direction
)
{
   switch(direction)
   {
      case FVG_BULLISH:
         return "BULLISH FVG";

      case FVG_BEARISH:
         return "BEARISH FVG";

      default:
         return "NONE";
   }
}


string FVGDescription(FVGZone &fvg)
{
   if(!fvg.valid)
      return "INVALID FVG";

   return StringFormat(
      "%s | Lower=%f | Upper=%f | Mid=%f | Size=%f | Mitigated=%s | Retested=%s | Invalidated=%s",
      FVGDirectionToString(fvg.direction),
      fvg.lower,
      fvg.upper,
      fvg.midpoint,
      fvg.size,
      fvg.mitigated ? "YES" : "NO",
      fvg.retested ? "YES" : "NO",
      fvg.invalidated ? "YES" : "NO"
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
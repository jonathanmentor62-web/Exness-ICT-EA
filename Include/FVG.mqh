//+------------------------------------------------------------------+
//| FVG.mqh                                                          |
//| ICT Fair Value Gap detection                                     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_FVG_MQH__
#define __EXNESS_ICT_FVG_MQH__

//====================================================================
// FVG TYPES
//====================================================================

enum ENUM_FVG_DIRECTION
{
   FVG_NONE = 0,
   FVG_BULLISH,
   FVG_BEARISH
};


//====================================================================
// FVG STRUCTURE
//====================================================================

struct FVGZone
{
   bool               valid;

   ENUM_FVG_DIRECTION direction;

   double             upper;
   double             lower;

   double             size;

   int                signalShift;

   datetime           signalTime;
};


//====================================================================
// RESET
//====================================================================

void ResetFVG(
   FVGZone &fvg
)
{
   fvg.valid = false;

   fvg.direction = FVG_NONE;

   fvg.upper = 0.0;
   fvg.lower = 0.0;
   fvg.size = 0.0;

   fvg.signalShift = -1;
   fvg.signalTime = 0;
}


//====================================================================
// BASIC FVG HELPERS
//====================================================================

// Calculate the size of a potential bullish FVG.
//
// Three candles:
//
// Oldest        Middle        Newest
//   C3            C2            C1
//
// Bullish FVG exists when:
//
// C1 low > C3 high
//
// Gap:
//
// C3 high ---------------- lower
//                           |
//                           | FVG
//                           |
// C1 low  ---------------- upper
double CalculateBullishFVGSize(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   if(shift < 1)
      return 0.0;

   double newestLow =
      iLow(
         symbol,
         timeframe,
         shift
      );

   double oldestHigh =
      iHigh(
         symbol,
         timeframe,
         shift + 2
      );

   if(newestLow <= 0.0 || oldestHigh <= 0.0)
      return 0.0;

   if(newestLow <= oldestHigh)
      return 0.0;

   return newestLow - oldestHigh;
}


// Calculate the size of a potential bearish FVG.
//
// Bearish FVG exists when:
//
// C1 high < C3 low
double CalculateBearishFVGSize(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   if(shift < 1)
      return 0.0;

   double newestHigh =
      iHigh(
         symbol,
         timeframe,
         shift
      );

   double oldestLow =
      iLow(
         symbol,
         timeframe,
         shift + 2
      );

   if(newestHigh <= 0.0 || oldestLow <= 0.0)
      return 0.0;

   if(newestHigh >= oldestLow)
      return 0.0;

   return oldestLow - newestHigh;
}


//====================================================================
// BULLISH FVG
//====================================================================

// Detect a bullish three-candle imbalance.
//
// shift = newest closed candle.
//
// Candle relationships:
//
// oldest candle high < newest candle low
//
// The middle candle is the displacement/impulse candle.
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

   if(bars <= 0)
      return false;

   if(shift + 2 >= bars)
      return false;

   double oldestHigh =
      iHigh(
         symbol,
         timeframe,
         shift + 2
      );

   double newestLow =
      iLow(
         symbol,
         timeframe,
         shift
      );

   if(oldestHigh <= 0.0 || newestLow <= 0.0)
      return false;

   // Bullish imbalance.
   if(newestLow <= oldestHigh)
      return false;

   double gapSize =
      newestLow - oldestHigh;

   if(gapSize < minimumSize)
      return false;

   fvg.valid = true;

   fvg.direction = FVG_BULLISH;

   fvg.lower = oldestHigh;
   fvg.upper = newestLow;

   fvg.size = gapSize;

   fvg.signalShift = shift;

   fvg.signalTime =
      iTime(
         symbol,
         timeframe,
         shift
      );

   return true;
}


//====================================================================
// BEARISH FVG
//====================================================================

// Detect a bearish three-candle imbalance.
//
// Bearish imbalance:
//
// newest candle high < oldest candle low
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

   if(bars <= 0)
      return false;

   if(shift + 2 >= bars)
      return false;

   double newestHigh =
      iHigh(
         symbol,
         timeframe,
         shift
      );

   double oldestLow =
      iLow(
         symbol,
         timeframe,
         shift + 2
      );

   if(newestHigh <= 0.0 || oldestLow <= 0.0)
      return false;

   // Bearish imbalance.
   if(newestHigh >= oldestLow)
      return false;

   double gapSize =
      oldestLow - newestHigh;

   if(gapSize < minimumSize)
      return false;

   fvg.valid = true;

   fvg.direction = FVG_BEARISH;

   fvg.lower = newestHigh;
   fvg.upper = oldestLow;

   fvg.size = gapSize;

   fvg.signalShift = shift;

   fvg.signalTime =
      iTime(
         symbol,
         timeframe,
         shift
      );

   return true;
}


//====================================================================
// GENERIC FVG DETECTION
//====================================================================

// Returns:
//
//  1 = bullish FVG
// -1 = bearish FVG
//  0 = no FVG
//
// The function checks the newest closed candle first.
int DetectFVG(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumSize,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   FVGZone bullish;

   if(DetectBullishFVG(
      symbol,
      timeframe,
      shift,
      minimumSize,
      bullish
   ))
   {
      fvg = bullish;

      return 1;
   }

   FVGZone bearish;

   if(DetectBearishFVG(
      symbol,
      timeframe,
      shift,
      minimumSize,
      bearish
   ))
   {
      fvg = bearish;

      return -1;
   }

   return 0;
}


//====================================================================
// FVG SEARCH
//====================================================================

// Search backward for the most recent bullish FVG.
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

   if(bars <= 0)
      return false;

   int endShift =
      MathMin(
         startShift + lookback - 1,
         bars - 3
      );

   if(startShift > endShift)
      return false;

   for(int shift = startShift;
       shift <= endShift;
       shift++)
   {
      if(DetectBullishFVG(
         symbol,
         timeframe,
         shift,
         minimumSize,
         fvg
      ))
      {
         return true;
      }
   }

   return false;
}


// Search backward for the most recent bearish FVG.
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

   if(bars <= 0)
      return false;

   int endShift =
      MathMin(
         startShift + lookback - 1,
         bars - 3
      );

   if(startShift > endShift)
      return false;

   for(int shift = startShift;
       shift <= endShift;
       shift++)
   {
      if(DetectBearishFVG(
         symbol,
         timeframe,
         shift,
         minimumSize,
         fvg
      ))
      {
         return true;
      }
   }

   return false;
}


//====================================================================
// DIRECTIONAL FVG SEARCH
//====================================================================

// direction:
//
//  1 = bullish
// -1 = bearish
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
   ResetFVG(fvg);

   if(direction > 0)
   {
      return FindRecentBullishFVG(
         symbol,
         timeframe,
         startShift,
         lookback,
         minimumSize,
         fvg
      );
   }

   if(direction < 0)
   {
      return FindRecentBearishFVG(
         symbol,
         timeframe,
         startShift,
         lookback,
         minimumSize,
         fvg
      );
   }

   return false;
}


//====================================================================
// FVG DIRECTION HELPERS
//====================================================================

bool IsBullishFVG(
   FVGZone &fvg
)
{
   return
      fvg.valid &&
      fvg.direction == FVG_BULLISH;
}


bool IsBearishFVG(
   FVGZone &fvg
)
{
   return
      fvg.valid &&
      fvg.direction == FVG_BEARISH;
}


//====================================================================
// PRICE LOCATION
//====================================================================

// Determine whether price is inside the FVG.
bool IsPriceInsideFVG(
   double price,
   FVGZone &fvg
)
{
   if(!fvg.valid)
      return false;

   return
      price >= fvg.lower &&
      price <= fvg.upper;
}


// Determine whether price has entered the bullish FVG.
bool HasPriceEnteredBullishFVG(
   double price,
   FVGZone &fvg
)
{
   if(!IsBullishFVG(fvg))
      return false;

   return price <= fvg.upper;
}


// Determine whether price has entered the bearish FVG.
bool HasPriceEnteredBearishFVG(
   double price,
   FVGZone &fvg
)
{
   if(!IsBearishFVG(fvg))
      return false;

   return price >= fvg.lower;
}


//====================================================================
// TEXT HELPERS
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


string FVGDescription(
   FVGZone &fvg
)
{
   if(!fvg.valid)
      return "INVALID FVG";

   return StringFormat(
      "%s | Lower=%f | Upper=%f | Size=%f | Shift=%d",
      FVGDirectionToString(fvg.direction),
      fvg.lower,
      fvg.upper,
      fvg.size,
      fvg.signalShift
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+

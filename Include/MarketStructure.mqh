//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Market-structure detection for Exness ICT EA                    |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_MARKET_STRUCTURE_MQH__
#define __EXNESS_ICT_MARKET_STRUCTURE_MQH__

//+------------------------------------------------------------------+
//| Structure direction                                              |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_DIRECTION
{
   STRUCTURE_UNKNOWN = 0,
   STRUCTURE_BULLISH = 1,
   STRUCTURE_BEARISH = -1
};

//+------------------------------------------------------------------+
//| Validate structure-analysis parameters                            |
//+------------------------------------------------------------------+
bool IsValidStructureParameters(
   const int leftBars,
   const int rightBars,
   const int lookback
)
{
   if(leftBars < 1)
      return(false);

   if(rightBars < 1)
      return(false);

   if(lookback < 1)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Check whether a candle is a confirmed swing high                |
//+------------------------------------------------------------------+
bool IsSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const int leftBars,
   const int rightBars
)
{
   if(!IsValidStructureParameters(
      leftBars,
      rightBars,
      1
   ))
   {
      return(false);
   }

   // A swing requires candles to its right that are already closed.
   if(shift <= rightBars)
      return(false);

   int totalBars = Bars(
      symbol,
      timeframe
   );

   if(totalBars <= 0)
      return(false);

   // Need enough older candles on the left side.
   if(shift + leftBars >= totalBars)
      return(false);

   double centerHigh = iHigh(
      symbol,
      timeframe,
      shift
   );

   if(centerHigh <= 0.0)
      return(false);

   // Older candles.
   for(int i = 1; i <= leftBars; i++)
   {
      double comparisonHigh = iHigh(
         symbol,
         timeframe,
         shift + i
      );

      if(comparisonHigh <= 0.0)
         return(false);

      if(centerHigh <= comparisonHigh)
         return(false);
   }

   // More recent candles.
   for(int i = 1; i <= rightBars; i++)
   {
      double comparisonHigh = iHigh(
         symbol,
         timeframe,
         shift - i
      );

      if(comparisonHigh <= 0.0)
         return(false);

      if(centerHigh <= comparisonHigh)
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Check whether a candle is a confirmed swing low                 |
//+------------------------------------------------------------------+
bool IsSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const int leftBars,
   const int rightBars
)
{
   if(!IsValidStructureParameters(
      leftBars,
      rightBars,
      1
   ))
   {
      return(false);
   }

   if(shift <= rightBars)
      return(false);

   int totalBars = Bars(
      symbol,
      timeframe
   );

   if(totalBars <= 0)
      return(false);

   if(shift + leftBars >= totalBars)
      return(false);

   double centerLow = iLow(
      symbol,
      timeframe,
      shift
   );

   if(centerLow <= 0.0)
      return(false);

   // Older candles.
   for(int i = 1; i <= leftBars; i++)
   {
      double comparisonLow = iLow(
         symbol,
         timeframe,
         shift + i
      );

      if(comparisonLow <= 0.0)
         return(false);

      if(centerLow >= comparisonLow)
         return(false);
   }

   // More recent candles.
   for(int i = 1; i <= rightBars; i++)
   {
      double comparisonLow = iLow(
         symbol,
         timeframe,
         shift - i
      );

      if(comparisonLow <= 0.0)
         return(false);

      if(centerLow >= comparisonLow)
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Find most recent confirmed swing high                            |
//+------------------------------------------------------------------+
int FindRecentSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int startShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(!IsValidStructureParameters(
      leftBars,
      rightBars,
      lookback
   ))
   {
      return(-1);
   }

   if(startShift <= rightBars)
      return(-1);

   int totalBars = Bars(
      symbol,
      timeframe
   );

   if(totalBars <= 0)
      return(-1);

   int lastPossibleShift =
      totalBars - leftBars - 1;

   if(lastPossibleShift < startShift)
      return(-1);

   int lastShift = MathMin(
      startShift + lookback - 1,
      lastPossibleShift
   );

   for(
      int shift = startShift;
      shift <= lastShift;
      shift++
   )
   {
      if(IsSwingHigh(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         return(shift);
      }
   }

   return(-1);
}

//+------------------------------------------------------------------+
//| Find most recent confirmed swing low                             |
//+------------------------------------------------------------------+
int FindRecentSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int startShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(!IsValidStructureParameters(
      leftBars,
      rightBars,
      lookback
   ))
   {
      return(-1);
   }

   if(startShift <= rightBars)
      return(-1);

   int totalBars = Bars(
      symbol,
      timeframe
   );

   if(totalBars <= 0)
      return(-1);

   int lastPossibleShift =
      totalBars - leftBars - 1;

   if(lastPossibleShift < startShift)
      return(-1);

   int lastShift = MathMin(
      startShift + lookback - 1,
      lastPossibleShift
   );

   for(
      int shift = startShift;
      shift <= lastShift;
      shift++
   )
   {
      if(IsSwingLow(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         return(shift);
      }
   }

   return(-1);
}

//+------------------------------------------------------------------+
//| Find the swing high before another swing high                    |
//+------------------------------------------------------------------+
int FindPreviousSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int recentSwingShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(recentSwingShift < 0)
      return(-1);

   int startShift =
      recentSwingShift + rightBars + 1;

   return(FindRecentSwingHigh(
      symbol,
      timeframe,
      startShift,
      lookback,
      leftBars,
      rightBars
   ));
}

//+------------------------------------------------------------------+
//| Find the swing low before another swing low                      |
//+------------------------------------------------------------------+
int FindPreviousSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int recentSwingShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(recentSwingShift < 0)
      return(-1);

   int startShift =
      recentSwingShift + rightBars + 1;

   return(FindRecentSwingLow(
      symbol,
      timeframe,
      startShift,
      lookback,
      leftBars,
      rightBars
   ));
}

//+------------------------------------------------------------------+
//| Determine established market structure                           |
//|                                                                  |
//| Bullish = Higher High + Higher Low                               |
//| Bearish = Lower High + Lower Low                                 |
//| Otherwise = Unknown                                              |
//+------------------------------------------------------------------+
ENUM_STRUCTURE_DIRECTION GetStructureDirection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int referenceShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(!IsValidStructureParameters(
      leftBars,
      rightBars,
      lookback
   ))
   {
      return(STRUCTURE_UNKNOWN);
   }

   if(referenceShift <= rightBars)
      return(STRUCTURE_UNKNOWN);

   // Find the latest confirmed swing high and low that existed
   // before the reference candle.
   int recentHigh = FindRecentSwingHigh(
      symbol,
      timeframe,
      referenceShift + rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   int recentLow = FindRecentSwingLow(
      symbol,
      timeframe,
      referenceShift + rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(recentHigh < 0 || recentLow < 0)
      return(STRUCTURE_UNKNOWN);

   int previousHigh = FindPreviousSwingHigh(
      symbol,
      timeframe,
      recentHigh,
      lookback,
      leftBars,
      rightBars
   );

   int previousLow = FindPreviousSwingLow(
      symbol,
      timeframe,
      recentLow,
      lookback,
      leftBars,
      rightBars
   );

   if(previousHigh < 0 || previousLow < 0)
      return(STRUCTURE_UNKNOWN);

   double recentHighPrice = iHigh(
      symbol,
      timeframe,
      recentHigh
   );

   double previousHighPrice = iHigh(
      symbol,
      timeframe,
      previousHigh
   );

   double recentLowPrice = iLow(
      symbol,
      timeframe,
      recentLow
   );

   double previousLowPrice = iLow(
      symbol,
      timeframe,
      previousLow
   );

   if(
      recentHighPrice <= 0.0 ||
      previousHighPrice <= 0.0 ||
      recentLowPrice <= 0.0 ||
      previousLowPrice <= 0.0
   )
   {
      return(STRUCTURE_UNKNOWN);
   }

   bool higherHigh =
      recentHighPrice > previousHighPrice;

   bool higherLow =
      recentLowPrice > previousLowPrice;

   bool lowerHigh =
      recentHighPrice < previousHighPrice;

   bool lowerLow =
      recentLowPrice < previousLowPrice;

   if(higherHigh && higherLow)
      return(STRUCTURE_BULLISH);

   if(lowerHigh && lowerLow)
      return(STRUCTURE_BEARISH);

   return(STRUCTURE_UNKNOWN);
}

//+------------------------------------------------------------------+
//| Get most recent swing-high shift                                 |
//+------------------------------------------------------------------+
int GetRecentSwingHighShift(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   return(FindRecentSwingHigh(
      symbol,
      timeframe,
      rightBars + 1,
      lookback,
      leftBars,
      rightBars
   ));
}

//+------------------------------------------------------------------+
//| Get most recent swing-low shift                                  |
//+------------------------------------------------------------------+
int GetRecentSwingLowShift(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   return(FindRecentSwingLow(
      symbol,
      timeframe,
      rightBars + 1,
      lookback,
      leftBars,
      rightBars
   ));
}

//+------------------------------------------------------------------+
//| Get most recent confirmed swing-high price                       |
//+------------------------------------------------------------------+
double GetRecentSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   int shift = GetRecentSwingHighShift(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(0.0);

   return(iHigh(
      symbol,
      timeframe,
      shift
   ));
}

//+------------------------------------------------------------------+
//| Get most recent confirmed swing-low price                        |
//+------------------------------------------------------------------+
double GetRecentSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   int shift = GetRecentSwingLowShift(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(0.0);

   return(iLow(
      symbol,
      timeframe,
      shift
   ));
}

//+------------------------------------------------------------------+
//| Get structure direction as text                                  |
//+------------------------------------------------------------------+
string StructureDirectionToString(
   const ENUM_STRUCTURE_DIRECTION direction
)
{
   switch(direction)
   {
      case STRUCTURE_BULLISH:
         return("BULLISH");

      case STRUCTURE_BEARISH:
         return("BEARISH");

      default:
         return("UNKNOWN");
   }
}

#endif

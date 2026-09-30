//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Market structure detection for Exness ICT EA                    |
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
//| Check confirmed swing high                                      |
//+------------------------------------------------------------------+
bool IsSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const int leftBars,
   const int rightBars
)
{
   if(shift <= rightBars)
      return(false);

   if(leftBars <= 0 || rightBars <= 0)
      return(false);

   int totalBars = Bars(symbol, timeframe);

   if(totalBars <= 0)
      return(false);

   if(shift + leftBars >= totalBars)
      return(false);

   double centerHigh = iHigh(symbol, timeframe, shift);

   if(centerHigh <= 0.0)
      return(false);

   for(int i = 1; i <= leftBars; i++)
   {
      if(centerHigh <= iHigh(symbol, timeframe, shift + i))
         return(false);
   }

   for(int i = 1; i <= rightBars; i++)
   {
      if(centerHigh <= iHigh(symbol, timeframe, shift - i))
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Check confirmed swing low                                       |
//+------------------------------------------------------------------+
bool IsSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const int leftBars,
   const int rightBars
)
{
   if(shift <= rightBars)
      return(false);

   if(leftBars <= 0 || rightBars <= 0)
      return(false);

   int totalBars = Bars(symbol, timeframe);

   if(totalBars <= 0)
      return(false);

   if(shift + leftBars >= totalBars)
      return(false);

   double centerLow = iLow(symbol, timeframe, shift);

   if(centerLow <= 0.0)
      return(false);

   for(int i = 1; i <= leftBars; i++)
   {
      if(centerLow >= iLow(symbol, timeframe, shift + i))
         return(false);
   }

   for(int i = 1; i <= rightBars; i++)
   {
      if(centerLow >= iLow(symbol, timeframe, shift - i))
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
   if(startShift <= rightBars || lookback <= 0)
      return(-1);

   int totalBars = Bars(symbol, timeframe);

   if(totalBars <= 0)
      return(-1);

   int lastShift = MathMin(
      startShift + lookback,
      totalBars - leftBars - 1
   );

   if(lastShift < startShift)
      return(-1);

   for(int shift = startShift; shift <= lastShift; shift++)
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
   if(startShift <= rightBars || lookback <= 0)
      return(-1);

   int totalBars = Bars(symbol, timeframe);

   if(totalBars <= 0)
      return(-1);

   int lastShift = MathMin(
      startShift + lookback,
      totalBars - leftBars - 1
   );

   if(lastShift < startShift)
      return(-1);

   for(int shift = startShift; shift <= lastShift; shift++)
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
//| Find previous swing high after the latest one                    |
//+------------------------------------------------------------------+
int FindPreviousSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int latestShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(latestShift < 0)
      return(-1);

   int startShift = latestShift + rightBars + 1;

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
//| Find previous swing low after the latest one                     |
//+------------------------------------------------------------------+
int FindPreviousSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int latestShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(latestShift < 0)
      return(-1);

   int startShift = latestShift + rightBars + 1;

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
//| Determine established structure                                  |
//| Requires both higher-high/higher-low or lower-high/lower-low.    |
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
   if(referenceShift <= rightBars)
      return(STRUCTURE_UNKNOWN);

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

   double recentHighPrice   = iHigh(symbol, timeframe, recentHigh);
   double previousHighPrice = iHigh(symbol, timeframe, previousHigh);

   double recentLowPrice    = iLow(symbol, timeframe, recentLow);
   double previousLowPrice  = iLow(symbol, timeframe, previousLow);

   if(recentHighPrice <= 0.0 ||
      previousHighPrice <= 0.0 ||
      recentLowPrice <= 0.0 ||
      previousLowPrice <= 0.0)
   {
      return(STRUCTURE_UNKNOWN);
   }

   bool higherHigh = recentHighPrice > previousHighPrice;
   bool higherLow  = recentLowPrice  > previousLowPrice;

   bool lowerHigh  = recentHighPrice < previousHighPrice;
   bool lowerLow   = recentLowPrice  < previousLowPrice;

   if(higherHigh && higherLow)
      return(STRUCTURE_BULLISH);

   if(lowerHigh && lowerLow)
      return(STRUCTURE_BEARISH);

   return(STRUCTURE_UNKNOWN);
}

//+------------------------------------------------------------------+
//| Get recent swing high price                                      |
//+------------------------------------------------------------------+
double GetRecentSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   int shift = FindRecentSwingHigh(
      symbol,
      timeframe,
      rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(0.0);

   return(iHigh(symbol, timeframe, shift));
}

//+------------------------------------------------------------------+
//| Get recent swing low price                                       |
//+------------------------------------------------------------------+
double GetRecentSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   int shift = FindRecentSwingLow(
      symbol,
      timeframe,
      rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(0.0);

   return(iLow(symbol, timeframe, shift));
}

#endif

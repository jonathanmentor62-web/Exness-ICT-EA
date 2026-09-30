//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| H4 market-structure detection for Exness ICT EA                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_MARKET_STRUCTURE_MQH__
#define __EXNESS_ICT_MARKET_STRUCTURE_MQH__

//-------------------------------------------------------------------
// Check whether a candle is a confirmed swing high.
//-------------------------------------------------------------------
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

   double centerHigh = iHigh(symbol, timeframe, shift);

   if(centerHigh <= 0.0)
      return(false);

   // Older candles
   for(int i = 1; i <= leftBars; i++)
   {
      if(centerHigh <= iHigh(symbol, timeframe, shift + i))
         return(false);
   }

   // More recent candles
   for(int i = 1; i <= rightBars; i++)
   {
      if(centerHigh <= iHigh(symbol, timeframe, shift - i))
         return(false);
   }

   return(true);
}

//-------------------------------------------------------------------
// Check whether a candle is a confirmed swing low.
//-------------------------------------------------------------------
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

   double centerLow = iLow(symbol, timeframe, shift);

   if(centerLow <= 0.0)
      return(false);

   // Older candles
   for(int i = 1; i <= leftBars; i++)
   {
      if(centerLow >= iLow(symbol, timeframe, shift + i))
         return(false);
   }

   // More recent candles
   for(int i = 1; i <= rightBars; i++)
   {
      if(centerLow >= iLow(symbol, timeframe, shift - i))
         return(false);
   }

   return(true);
}

//-------------------------------------------------------------------
// Find the most recent confirmed swing high.
//-------------------------------------------------------------------
int FindRecentSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int startShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   for(int shift = startShift; shift <= startShift + lookback; shift++)
   {
      if(IsSwingHigh(symbol, timeframe, shift, leftBars, rightBars))
         return(shift);
   }

   return(-1);
}

//-------------------------------------------------------------------
// Find the most recent confirmed swing low.
//-------------------------------------------------------------------
int FindRecentSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int startShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   for(int shift = startShift; shift <= startShift + lookback; shift++)
   {
      if(IsSwingLow(symbol, timeframe, shift, leftBars, rightBars))
         return(shift);
   }

   return(-1);
}

//-------------------------------------------------------------------
// Get the price of the most recent confirmed swing high.
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Get the price of the most recent confirmed swing low.
//-------------------------------------------------------------------
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

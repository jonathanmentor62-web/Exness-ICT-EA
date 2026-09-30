//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Market-structure detection for Exness ICT EA                    |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_MARKET_STRUCTURE_MQH__
#define __EXNESS_ICT_MARKET_STRUCTURE_MQH__

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
   if(shift <= rightBars)
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
   if(shift <= rightBars)
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
//| Find the most recent confirmed swing high                       |
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
   if(lookback <= 0)
      return(-1);

   int totalBars = Bars(symbol, timeframe);

   if(totalBars <= 0)
      return(-1);

   int lastShift = MathMin(
      startShift + lookback,
      totalBars - leftBars - 1
   );

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
//| Find the most recent confirmed swing low                        |
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
   if(lookback <= 0)
      return(-1);

   int totalBars = Bars(symbol, timeframe);

   if(totalBars <= 0)
      return(-1);

   int lastShift = MathMin(
      startShift + lookback,
      totalBars - leftBars - 1
   );

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
//| Get most recent confirmed swing high price                      |
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
//| Get most recent confirmed swing low price                       |
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

//+------------------------------------------------------------------+
//| Liquidity.mqh                                                    |
//| Liquidity and sweep detection for Exness ICT EA                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_LIQUIDITY_MQH__
#define __EXNESS_ICT_LIQUIDITY_MQH__

struct LiquidityLevel
{
   double   price;
   datetime time;
   int      shift;
   bool     valid;
};

//+------------------------------------------------------------------+
//| High immediately preceding candleShift                          |
//+------------------------------------------------------------------+
double GetPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 0)
      return(0.0);

   int previousShift = candleShift + 1;

   double value = iHigh(
      symbol,
      timeframe,
      previousShift
   );

   return(value > 0.0 ? value : 0.0);
}

//+------------------------------------------------------------------+
//| Low immediately preceding candleShift                           |
//+------------------------------------------------------------------+
double GetPreviousLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 0)
      return(0.0);

   int previousShift = candleShift + 1;

   double value = iLow(
      symbol,
      timeframe,
      previousShift
   );

   return(value > 0.0 ? value : 0.0);
}

//+------------------------------------------------------------------+
//| Get most recent buy-side liquidity                              |
//+------------------------------------------------------------------+
LiquidityLevel GetBuySideLiquidity(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   LiquidityLevel level;

   level.price = 0.0;
   level.time  = 0;
   level.shift = -1;
   level.valid = false;

   int shift = FindRecentSwingHigh(
      symbol,
      timeframe,
      rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(level);

   double price = iHigh(symbol, timeframe, shift);

   if(price <= 0.0)
      return(level);

   level.price = price;
   level.time  = iTime(symbol, timeframe, shift);
   level.shift = shift;
   level.valid = true;

   return(level);
}

//+------------------------------------------------------------------+
//| Get most recent sell-side liquidity                             |
//+------------------------------------------------------------------+
LiquidityLevel GetSellSideLiquidity(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   LiquidityLevel level;

   level.price = 0.0;
   level.time  = 0;
   level.shift = -1;
   level.valid = false;

   int shift = FindRecentSwingLow(
      symbol,
      timeframe,
      rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(level);

   double price = iLow(symbol, timeframe, shift);

   if(price <= 0.0)
      return(level);

   level.price = price;
   level.time  = iTime(symbol, timeframe, shift);
   level.shift = shift;
   level.valid = true;

   return(level);
}

//+------------------------------------------------------------------+
//| Buy-side liquidity sweep                                        |
//+------------------------------------------------------------------+
bool DidSweepBuySide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 1 || liquidityPrice <= 0.0)
      return(false);

   double candleHigh = iHigh(
      symbol,
      timeframe,
      candleShift
   );

   return(candleHigh > liquidityPrice);
}

//+------------------------------------------------------------------+
//| Sell-side liquidity sweep                                       |
//+------------------------------------------------------------------+
bool DidSweepSellSide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 1 || liquidityPrice <= 0.0)
      return(false);

   double candleLow = iLow(
      symbol,
      timeframe,
      candleShift
   );

   return(candleLow < liquidityPrice);
}

//+------------------------------------------------------------------+
//| Previous candle high sweep                                      |
//+------------------------------------------------------------------+
bool SweptPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 1)
      return(false);

   double previousHigh = GetPreviousHigh(
      symbol,
      timeframe,
      candleShift
   );

   double candleHigh = iHigh(
      symbol,
      timeframe,
      candleShift
   );

   if(previousHigh <= 0.0 || candleHigh <= 0.0)
      return(false);

   return(candleHigh > previousHigh);
}

//+------------------------------------------------------------------+
//| Previous candle low sweep                                       |
//+------------------------------------------------------------------+
bool SweptPreviousLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 1)
      return(false);

   double previousLow = GetPreviousLow(
      symbol,
      timeframe,
      candleShift
   );

   double candleLow = iLow(
      symbol,
      timeframe,
      candleShift
   );

   if(previousLow <= 0.0 || candleLow <= 0.0)
      return(false);

   return(candleLow < previousLow);
}

#endif

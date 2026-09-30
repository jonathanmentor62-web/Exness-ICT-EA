//+------------------------------------------------------------------+
//| Liquidity.mqh                                                    |
//| Liquidity and sweep detection for Exness ICT EA                  |
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
//| Get previous closed candle high                                  |
//+------------------------------------------------------------------+
double GetPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe
)
{
   return(iHigh(symbol, timeframe, 1));
}

//+------------------------------------------------------------------+
//| Get previous closed candle low                                   |
//+------------------------------------------------------------------+
double GetPreviousLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe
)
{
   return(iLow(symbol, timeframe, 1));
}

//+------------------------------------------------------------------+
//| Find the most recent confirmed swing-high liquidity              |
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

   level.price = iHigh(symbol, timeframe, shift);
   level.time  = iTime(symbol, timeframe, shift);
   level.shift = shift;
   level.valid = (level.price > 0.0);

   return(level);
}

//+------------------------------------------------------------------+
//| Find the most recent confirmed swing-low liquidity               |
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

   level.price = iLow(symbol, timeframe, shift);
   level.time  = iTime(symbol, timeframe, shift);
   level.shift = shift;
   level.valid = (level.price > 0.0);

   return(level);
}

//+------------------------------------------------------------------+
//| Check whether price swept a buy-side liquidity level             |
//| A sweep requires the candle high to trade above the level.       |
//+------------------------------------------------------------------+
bool DidSweepBuySide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(liquidityPrice <= 0.0)
      return(false);

   double candleHigh = iHigh(symbol, timeframe, candleShift);

   return(candleHigh > liquidityPrice);
}

//+------------------------------------------------------------------+
//| Check whether price swept a sell-side liquidity level            |
//| A sweep requires the candle low to trade below the level.        |
//+------------------------------------------------------------------+
bool DidSweepSellSide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(liquidityPrice <= 0.0)
      return(false);

   double candleLow = iLow(symbol, timeframe, candleShift);

   return(candleLow < liquidityPrice);
}

//+------------------------------------------------------------------+
//| Previous high/low liquidity sweep helpers                        |
//+------------------------------------------------------------------+
bool SweptPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   double previousHigh = GetPreviousHigh(symbol, timeframe);

   if(previousHigh <= 0.0)
      return(false);

   return(iHigh(symbol, timeframe, candleShift) > previousHigh);
}

bool SweptPreviousLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   double previousLow = GetPreviousLow(symbol, timeframe);

   if(previousLow <= 0.0)
      return(false);

   return(iLow(symbol, timeframe, candleShift) < previousLow);
}

#endif

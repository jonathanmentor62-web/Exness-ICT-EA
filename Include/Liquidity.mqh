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
//| Get high of candle immediately preceding candleShift             |
//+------------------------------------------------------------------+
double GetPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   int previousShift = candleShift + 1;

   if(previousShift < 0)
      return(0.0);

   return(iHigh(symbol, timeframe, previousShift));
}

//+------------------------------------------------------------------+
//| Get low of candle immediately preceding candleShift              |
//+------------------------------------------------------------------+
double GetPreviousLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   int previousShift = candleShift + 1;

   if(previousShift < 0)
      return(0.0);

   return(iLow(symbol, timeframe, previousShift));
}

//+------------------------------------------------------------------+
//| Find most recent confirmed buy-side liquidity                   |
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
//| Find most recent confirmed sell-side liquidity                  |
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
//| Check whether candle swept buy-side liquidity                   |
//+------------------------------------------------------------------+
bool DidSweepBuySide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0 || liquidityPrice <= 0.0)
      return(false);

   double candleHigh = iHigh(symbol, timeframe, candleShift);

   if(candleHigh <= 0.0)
      return(false);

   return(candleHigh > liquidityPrice);
}

//+------------------------------------------------------------------+
//| Check whether candle swept sell-side liquidity                  |
//+------------------------------------------------------------------+
bool DidSweepSellSide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0 || liquidityPrice <= 0.0)
      return(false);

   double candleLow = iLow(symbol, timeframe, candleShift);

   if(candleLow <= 0.0)
      return(false);

   return(candleLow < liquidityPrice);
}

//+------------------------------------------------------------------+
//| Check whether candle swept the previous candle's high            |
//+------------------------------------------------------------------+
bool SweptPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 0)
      return(false);

   double previousHigh = GetPreviousHigh(
      symbol,
      timeframe,
      candleShift
   );

   if(previousHigh <= 0.0)
      return(false);

   double candleHigh = iHigh(
      symbol,
      timeframe,
      candleShift
   );

   if(candleHigh <= 0.0)
      return(false);

   return(candleHigh > previousHigh);
}

//+------------------------------------------------------------------+
//| Check whether candle swept the previous candle's low             |
//+------------------------------------------------------------------+
bool SweptPreviousLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 0)
      return(false);

   double previousLow = GetPreviousLow(
      symbol,
      timeframe,
      candleShift
   );

   if(previousLow <= 0.0)
      return(false);

   double candleLow = iLow(
      symbol,
      timeframe,
      candleShift
   );

   if(candleLow <= 0.0)
      return(false);

   return(candleLow < previousLow);
}

#endif

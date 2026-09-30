//+------------------------------------------------------------------+
//| Liquidity.mqh                                                    |
//| Liquidity and sweep detection for Exness ICT EA                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_LIQUIDITY_MQH__
#define __EXNESS_ICT_LIQUIDITY_MQH__

//====================================================================
// LIQUIDITY STRUCTURE
//====================================================================

struct LiquidityLevel
{
   double   price;
   datetime time;
   int      shift;
   bool     valid;
};

//====================================================================
// BASIC VALIDATION
//====================================================================

bool IsValidLiquidityPrice(const double price)
{
   return(price > 0.0);
}

//====================================================================
// PREVIOUS CANDLE LEVELS
//====================================================================

double GetPreviousHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   if(candleShift < 0)
      return(0.0);

   int previousShift = candleShift + 1;

   double price = iHigh(
      symbol,
      timeframe,
      previousShift
   );

   if(!IsValidLiquidityPrice(price))
      return(0.0);

   return(price);
}

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

   double price = iLow(
      symbol,
      timeframe,
      previousShift
   );

   if(!IsValidLiquidityPrice(price))
      return(0.0);

   return(price);
}

//====================================================================
// CONFIRMED SWING LIQUIDITY
//====================================================================

//+------------------------------------------------------------------+
//| Get most recent confirmed buy-side liquidity                     |
//|                                                                  |
//| Buy-side liquidity = confirmed swing high.                       |
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

   int shift = GetRecentSwingHighShift(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(level);

   double price = iHigh(
      symbol,
      timeframe,
      shift
   );

   if(!IsValidLiquidityPrice(price))
      return(level);

   datetime levelTime = iTime(
      symbol,
      timeframe,
      shift
   );

   if(levelTime <= 0)
      return(level);

   level.price = price;
   level.time  = levelTime;
   level.shift = shift;
   level.valid = true;

   return(level);
}

//+------------------------------------------------------------------+
//| Get most recent confirmed sell-side liquidity                    |
//|                                                                  |
//| Sell-side liquidity = confirmed swing low.                       |
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

   int shift = GetRecentSwingLowShift(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars
   );

   if(shift < 0)
      return(level);

   double price = iLow(
      symbol,
      timeframe,
      shift
   );

   if(!IsValidLiquidityPrice(price))
      return(level);

   datetime levelTime = iTime(
      symbol,
      timeframe,
      shift
   );

   if(levelTime <= 0)
      return(level);

   level.price = price;
   level.time  = levelTime;
   level.shift = shift;
   level.valid = true;

   return(level);
}

//====================================================================
// PREVIOUS-CANDLE LIQUIDITY
//====================================================================

//+------------------------------------------------------------------+
//| Check if candle swept previous candle high                       |
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
//| Check if candle swept previous candle low                        |
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

//====================================================================
// GENERIC LIQUIDITY SWEEPS
//====================================================================

//+------------------------------------------------------------------+
//| Detect buy-side liquidity sweep                                  |
//|                                                                  |
//| Price trades above the liquidity level.                          |
//|                                                                  |
//| NOTE: This function detects the raid itself.                    |
//| It does NOT require a close back below the level.               |
//+------------------------------------------------------------------+

bool DidSweepBuySide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0)
      return(false);

   if(liquidityPrice <= 0.0)
      return(false);

   double candleHigh = iHigh(
      symbol,
      timeframe,
      candleShift
   );

   if(candleHigh <= 0.0)
      return(false);

   return(candleHigh > liquidityPrice);
}

//+------------------------------------------------------------------+
//| Detect sell-side liquidity sweep                                |
//|                                                                  |
//| Price trades below the liquidity level.                          |
//+------------------------------------------------------------------+

bool DidSweepSellSide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0)
      return(false);

   if(liquidityPrice <= 0.0)
      return(false);

   double candleLow = iLow(
      symbol,
      timeframe,
      candleShift
   );

   if(candleLow <= 0.0)
      return(false);

   return(candleLow < liquidityPrice);
}

//====================================================================
// SWEEP + CLOSE BACK INSIDE
//====================================================================

//+------------------------------------------------------------------+
//| Buy-side liquidity swept and price closed back below level       |
//|                                                                  |
//| This is particularly useful for detecting a potential bearish    |
//| liquidity raid before bearish displacement/MSS.                  |
//+------------------------------------------------------------------+

bool SweptAndClosedBelowBuySide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0)
      return(false);

   if(liquidityPrice <= 0.0)
      return(false);

   double candleHigh = iHigh(
      symbol,
      timeframe,
      candleShift
   );

   double candleClose = iClose(
      symbol,
      timeframe,
      candleShift
   );

   if(candleHigh <= 0.0 || candleClose <= 0.0)
      return(false);

   bool swept = candleHigh > liquidityPrice;
   bool closedBackBelow = candleClose < liquidityPrice;

   return(swept && closedBackBelow);
}

//+------------------------------------------------------------------+
//| Sell-side liquidity swept and price closed back above level      |
//|                                                                  |
//| Useful for detecting a potential bullish liquidity raid before   |
//| bullish displacement/MSS.                                        |
//+------------------------------------------------------------------+

bool SweptAndClosedAboveSellSide(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0)
      return(false);

   if(liquidityPrice <= 0.0)
      return(false);

   double candleLow = iLow(
      symbol,
      timeframe,
      candleShift
   );

   double candleClose = iClose(
      symbol,
      timeframe,
      candleShift
   );

   if(candleLow <= 0.0 || candleClose <= 0.0)
      return(false);

   bool swept = candleLow < liquidityPrice;
   bool closedBackAbove = candleClose > liquidityPrice;

   return(swept && closedBackAbove);
}

//====================================================================
// PREVIOUS CANDLE SWEEP + REJECTION
//====================================================================

//+------------------------------------------------------------------+
//| Previous high swept and candle closed back below                 |
//+------------------------------------------------------------------+

bool SweptPreviousHighAndClosedBackBelow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   double previousHigh = GetPreviousHigh(
      symbol,
      timeframe,
      candleShift
   );

   if(previousHigh <= 0.0)
      return(false);

   return(
      SweptAndClosedBelowBuySide(
         symbol,
         timeframe,
         candleShift,
         previousHigh
      )
   );
}

//+------------------------------------------------------------------+
//| Previous low swept and candle closed back above                  |
//+------------------------------------------------------------------+

bool SweptPreviousLowAndClosedBackAbove(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift
)
{
   double previousLow = GetPreviousLow(
      symbol,
      timeframe,
      candleShift
   );

   if(previousLow <= 0.0)
      return(false);

   return(
      SweptAndClosedAboveSellSide(
         symbol,
         timeframe,
         candleShift,
         previousLow
      )
   );
}

//====================================================================
// LIQUIDITY DISTANCE
//====================================================================

//+------------------------------------------------------------------+
//| Distance from candle high to liquidity level                     |
//+------------------------------------------------------------------+

double GetBuySideSweepDistance(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0 || liquidityPrice <= 0.0)
      return(0.0);

   double high = iHigh(
      symbol,
      timeframe,
      candleShift
   );

   if(high <= 0.0)
      return(0.0);

   if(high <= liquidityPrice)
      return(0.0);

   return(high - liquidityPrice);
}

//+------------------------------------------------------------------+
//| Distance from candle low to liquidity level                      |
//+------------------------------------------------------------------+

double GetSellSideSweepDistance(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0 || liquidityPrice <= 0.0)
      return(0.0);

   double low = iLow(
      symbol,
      timeframe,
      candleShift
   );

   if(low <= 0.0)
      return(0.0);

   if(low >= liquidityPrice)
      return(0.0);

   return(liquidityPrice - low);
}

//====================================================================
// LIQUIDITY INVALIDATION
//====================================================================

//+------------------------------------------------------------------+
//| Determine whether buy-side liquidity has been broken             |
//| and accepted above.                                               |
//+------------------------------------------------------------------+

bool IsBuySideLiquidityBroken(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0 || liquidityPrice <= 0.0)
      return(false);

   double candleClose = iClose(
      symbol,
      timeframe,
      candleShift
   );

   if(candleClose <= 0.0)
      return(false);

   return(candleClose > liquidityPrice);
}

//+------------------------------------------------------------------+
//| Determine whether sell-side liquidity has been broken            |
//| and accepted below.                                               |
//+------------------------------------------------------------------+

bool IsSellSideLiquidityBroken(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const double liquidityPrice
)
{
   if(candleShift < 0 || liquidityPrice <= 0.0)
      return(false);

   double candleClose = iClose(
      symbol,
      timeframe,
      candleShift
   );

   if(candleClose <= 0.0)
      return(false);

   return(candleClose < liquidityPrice);
}

//====================================================================
// LIQUIDITY TYPE HELPERS
//====================================================================

//+------------------------------------------------------------------+
//| Check whether a liquidity level is usable                        |
//+------------------------------------------------------------------+

bool IsValidLiquidityLevel(
   const LiquidityLevel &level
)
{
   if(!level.valid)
      return(false);

   if(level.price <= 0.0)
      return(false);

   if(level.shift < 0)
      return(false);

   if(level.time <= 0)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Compare two liquidity levels                                     |
//+------------------------------------------------------------------+

bool AreLiquidityLevelsEqual(
   const LiquidityLevel &first,
   const LiquidityLevel &second,
   const double tolerance
)
{
   if(!IsValidLiquidityLevel(first))
      return(false);

   if(!IsValidLiquidityLevel(second))
      return(false);

   if(tolerance < 0.0)
      return(false);

   return(
      MathAbs(first.price - second.price) <= tolerance
   );
}

//+------------------------------------------------------------------+
//| Return the distance between liquidity levels                     |
//+------------------------------------------------------------------+

double GetLiquidityLevelDistance(
   const LiquidityLevel &first,
   const LiquidityLevel &second
)
{
   if(!IsValidLiquidityLevel(first))
      return(0.0);

   if(!IsValidLiquidityLevel(second))
      return(0.0);

   return(
      MathAbs(first.price - second.price)
   );
}

//====================================================================
// END
//====================================================================

#endif

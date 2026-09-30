//+------------------------------------------------------------------+
//| Liquidity.mqh                                                    |
//| ICT liquidity and liquidity sweep detection                      |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_LIQUIDITY_MQH__
#define __EXNESS_ICT_LIQUIDITY_MQH__

#include "MarketStructure.mqh"

//====================================================================
// LIQUIDITY TYPES
//====================================================================

enum ENUM_LIQUIDITY_TYPE
{
   LIQUIDITY_NONE = 0,
   LIQUIDITY_BUY_SIDE,
   LIQUIDITY_SELL_SIDE
};


//====================================================================
// LIQUIDITY LEVEL
//====================================================================

struct LiquidityLevel
{
   bool                valid;
   ENUM_LIQUIDITY_TYPE type;

   double              price;

   int                 shift;
   datetime            time;
};


//====================================================================
// LIQUIDITY SWEEP
//====================================================================

struct LiquiditySweep
{
   bool                valid;

   ENUM_LIQUIDITY_TYPE type;

   double              liquidityPrice;
   double              sweepExtreme;

   int                 liquidityShift;
   int                 signalShift;

   datetime            liquidityTime;
   datetime            signalTime;
};


//====================================================================
// RESET HELPERS
//====================================================================

void ResetLiquidityLevel(
   LiquidityLevel &level
)
{
   level.valid = false;

   level.type = LIQUIDITY_NONE;

   level.price = 0.0;

   level.shift = -1;
   level.time = 0;
}


void ResetLiquiditySweep(
   LiquiditySweep &sweep
)
{
   sweep.valid = false;

   sweep.type = LIQUIDITY_NONE;

   sweep.liquidityPrice = 0.0;
   sweep.sweepExtreme = 0.0;

   sweep.liquidityShift = -1;
   sweep.signalShift = -1;

   sweep.liquidityTime = 0;
   sweep.signalTime = 0;
}


//====================================================================
// BUY-SIDE LIQUIDITY
//====================================================================

// Buy-side liquidity is represented by a confirmed swing high.
//
// Typical ICT interpretation:
// Buy stops tend to accumulate above obvious highs.
//
// The latest confirmed swing high is therefore treated as the
// nearest detectable buy-side liquidity pool.
bool FindNearestBuySideLiquidity(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   SwingPoint swingHigh;

   if(!FindRecentSwingHigh(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swingHigh
   ))
   {
      return false;
   }

   level.valid = true;

   level.type = LIQUIDITY_BUY_SIDE;

   level.price = swingHigh.price;

   level.shift = swingHigh.shift;
   level.time = swingHigh.time;

   return true;
}


//====================================================================
// SELL-SIDE LIQUIDITY
//====================================================================

// Sell-side liquidity is represented by a confirmed swing low.
//
// Typical ICT interpretation:
// Sell stops tend to accumulate below obvious lows.
bool FindNearestSellSideLiquidity(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   SwingPoint swingLow;

   if(!FindRecentSwingLow(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swingLow
   ))
   {
      return false;
   }

   level.valid = true;

   level.type = LIQUIDITY_SELL_SIDE;

   level.price = swingLow.price;

   level.shift = swingLow.shift;
   level.time = swingLow.time;

   return true;
}


//====================================================================
// LIQUIDITY PRICE HELPERS
//====================================================================

double GetNearestBuySideLiquidityPrice(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   LiquidityLevel level;

   if(!FindNearestBuySideLiquidity(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      level
   ))
   {
      return 0.0;
   }

   return level.price;
}


double GetNearestSellSideLiquidityPrice(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   LiquidityLevel level;

   if(!FindNearestSellSideLiquidity(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      level
   ))
   {
      return 0.0;
   }

   return level.price;
}


//====================================================================
// SWEEP DETECTION
//====================================================================

// Detect a buy-side liquidity sweep.
//
// Price must:
// 1. Trade above the liquidity level.
// 2. Then close back below the liquidity level.
//
// This models a sweep of buy-side liquidity rather than simply
// detecting a normal breakout.
bool DetectBuySideLiquiditySweep(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars,
   double minimumSweepDistance,
   LiquiditySweep &sweep
)
{
   ResetLiquiditySweep(sweep);

   if(signalShift < 1)
      return false;

   LiquidityLevel level;

   if(!FindNearestBuySideLiquidity(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      level
   ))
   {
      return false;
   }

   // The liquidity level must be older than the signal candle.
   if(level.shift <= signalShift)
      return false;

   double high =
      iHigh(
         symbol,
         timeframe,
         signalShift
      );

   double close =
      iClose(
         symbol,
         timeframe,
         signalShift
      );

   if(high <= 0.0 || close <= 0.0)
      return false;

   // Price must actually trade above the liquidity level.
   if(high <= level.price)
      return false;

   double sweepDistance =
      high - level.price;

   if(sweepDistance < minimumSweepDistance)
      return false;

   // A sweep requires rejection back below the liquidity level.
   if(close >= level.price)
      return false;

   sweep.valid = true;

   sweep.type = LIQUIDITY_BUY_SIDE;

   sweep.liquidityPrice = level.price;

   sweep.sweepExtreme = high;

   sweep.liquidityShift = level.shift;

   sweep.signalShift = signalShift;

   sweep.liquidityTime = level.time;

   sweep.signalTime =
      iTime(
         symbol,
         timeframe,
         signalShift
      );

   return true;
}


//====================================================================
// SELL-SIDE SWEEP
//====================================================================

// Detect a sell-side liquidity sweep.
//
// Price must:
// 1. Trade below the liquidity level.
// 2. Then close back above the liquidity level.
bool DetectSellSideLiquiditySweep(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars,
   double minimumSweepDistance,
   LiquiditySweep &sweep
)
{
   ResetLiquiditySweep(sweep);

   if(signalShift < 1)
      return false;

   LiquidityLevel level;

   if(!FindNearestSellSideLiquidity(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      level
   ))
   {
      return false;
   }

   // The liquidity level must be older than the signal candle.
   if(level.shift <= signalShift)
      return false;

   double low =
      iLow(
         symbol,
         timeframe,
         signalShift
      );

   double close =
      iClose(
         symbol,
         timeframe,
         signalShift
      );

   if(low <= 0.0 || close <= 0.0)
      return false;

   // Price must actually trade below the liquidity level.
   if(low >= level.price)
      return false;

   double sweepDistance =
      level.price - low;

   if(sweepDistance < minimumSweepDistance)
      return false;

   // A sweep requires rejection back above the liquidity level.
   if(close <= level.price)
      return false;

   sweep.valid = true;

   sweep.type = LIQUIDITY_SELL_SIDE;

   sweep.liquidityPrice = level.price;

   sweep.sweepExtreme = low;

   sweep.liquidityShift = level.shift;

   sweep.signalShift = signalShift;

   sweep.liquidityTime = level.time;

   sweep.signalTime =
      iTime(
         symbol,
         timeframe,
         signalShift
      );

   return true;
}


//====================================================================
// GENERIC LIQUIDITY SWEEP
//====================================================================

// Returns:
//
//  1 = buy-side sweep
// -1 = sell-side sweep
//  0 = no sweep
//
// This helper checks both directions.
int DetectLiquiditySweep(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars,
   double minimumSweepDistance,
   LiquiditySweep &sweep
)
{
   ResetLiquiditySweep(sweep);

   LiquiditySweep buySideSweep;

   if(DetectBuySideLiquiditySweep(
      symbol,
      timeframe,
      signalShift,
      lookback,
      leftBars,
      rightBars,
      minimumSweepDistance,
      buySideSweep
   ))
   {
      sweep = buySideSweep;

      return 1;
   }


   LiquiditySweep sellSideSweep;

   if(DetectSellSideLiquiditySweep(
      symbol,
      timeframe,
      signalShift,
      lookback,
      leftBars,
      rightBars,
      minimumSweepDistance,
      sellSideSweep
   ))
   {
      sweep = sellSideSweep;

      return -1;
   }

   return 0;
}


//====================================================================
// LIQUIDITY RELATIONSHIP HELPERS
//====================================================================

// Determine whether price is above a liquidity level.
bool IsAboveLiquidity(
   double price,
   LiquidityLevel &level
)
{
   if(!level.valid)
      return false;

   return price > level.price;
}


// Determine whether price is below a liquidity level.
bool IsBelowLiquidity(
   double price,
   LiquidityLevel &level
)
{
   if(!level.valid)
      return false;

   return price < level.price;
}


// Determine whether price is at/near a liquidity level.
//
// The tolerance is expressed in price units.
bool IsNearLiquidity(
   double price,
   LiquidityLevel &level,
   double tolerance
)
{
   if(!level.valid)
      return false;

   if(tolerance < 0.0)
      tolerance = 0.0;

   return MathAbs(price - level.price) <= tolerance;
}


//====================================================================
// SWEEP TYPE HELPERS
//====================================================================

bool IsBuySideSweep(
   LiquiditySweep &sweep
)
{
   return
      sweep.valid &&
      sweep.type == LIQUIDITY_BUY_SIDE;
}


bool IsSellSideSweep(
   LiquiditySweep &sweep
)
{
   return
      sweep.valid &&
      sweep.type == LIQUIDITY_SELL_SIDE;
}


//====================================================================
// TEXT HELPERS
//====================================================================

string LiquidityTypeToString(
   ENUM_LIQUIDITY_TYPE type
)
{
   switch(type)
   {
      case LIQUIDITY_BUY_SIDE:
         return "BUY-SIDE LIQUIDITY";

      case LIQUIDITY_SELL_SIDE:
         return "SELL-SIDE LIQUIDITY";

      default:
         return "NONE";
   }
}


string LiquiditySweepDescription(
   LiquiditySweep &sweep
)
{
   if(!sweep.valid)
      return "INVALID LIQUIDITY SWEEP";

   return StringFormat(
      "%s | Liquidity=%f | Extreme=%f | SignalShift=%d",
      LiquidityTypeToString(sweep.type),
      sweep.liquidityPrice,
      sweep.sweepExtreme,
      sweep.signalShift
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+

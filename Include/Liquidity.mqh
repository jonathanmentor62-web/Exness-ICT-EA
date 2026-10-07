//+------------------------------------------------------------------+
//| Liquidity.mqh                                                    |
//| Gold Multi-Strategy EA - Liquidity Engine                       |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_LIQUIDITY_MQH__
#define __EXNESS_GOLD_LIQUIDITY_MQH__

#include "MarketStructure.mqh"

//==================================================================
// LIQUIDITY TYPES
//==================================================================

enum ENUM_LIQUIDITY_TYPE
{
   LIQUIDITY_NONE = 0,
   LIQUIDITY_BUY_SIDE,
   LIQUIDITY_SELL_SIDE,
   LIQUIDITY_EQUAL_HIGH,
   LIQUIDITY_EQUAL_LOW,
   LIQUIDITY_PREVIOUS_DAY_HIGH,
   LIQUIDITY_PREVIOUS_DAY_LOW,
   LIQUIDITY_PREVIOUS_WEEK_HIGH,
   LIQUIDITY_PREVIOUS_WEEK_LOW
};


//==================================================================
// LIQUIDITY LEVEL
//==================================================================

struct LiquidityLevel
{
   bool                 valid;
   ENUM_LIQUIDITY_TYPE  type;

   double               price;

   int                  shift;
   datetime             time;
};


//==================================================================
// LIQUIDITY SWEEP
//==================================================================

struct LiquiditySweep
{
   bool                 valid;

   ENUM_LIQUIDITY_TYPE  type;

   double               liquidityPrice;
   double               sweepExtreme;

   int                  liquidityShift;
   int                  signalShift;

   datetime              liquidityTime;
   datetime              signalTime;
};


//==================================================================
// RESET
//==================================================================

void ResetLiquidityLevel(
   LiquidityLevel &level
)
{
   level.valid = false;
   level.type  = LIQUIDITY_NONE;
   level.price = 0.0;
   level.shift = -1;
   level.time  = 0;
}


void ResetLiquiditySweep(
   LiquiditySweep &sweep
)
{
   sweep.valid = false;
   sweep.type  = LIQUIDITY_NONE;

   sweep.liquidityPrice = 0.0;
   sweep.sweepExtreme   = 0.0;

   sweep.liquidityShift = -1;
   sweep.signalShift    = -1;

   sweep.liquidityTime = 0;
   sweep.signalTime    = 0;
}


//==================================================================
// SWING LIQUIDITY
//==================================================================

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
      return false;

   level.valid = true;
   level.type  = LIQUIDITY_BUY_SIDE;
   level.price = swingHigh.price;
   level.shift = swingHigh.shift;
   level.time  = swingHigh.time;

   return true;
}


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
      return false;

   level.valid = true;
   level.type  = LIQUIDITY_SELL_SIDE;
   level.price = swingLow.price;
   level.shift = swingLow.shift;
   level.time  = swingLow.time;

   return true;
}


//==================================================================
// PREVIOUS DAY LIQUIDITY
//==================================================================

bool FindPreviousDayHigh(
   string symbol,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   double price = iHigh(
      symbol,
      PERIOD_D1,
      1
   );

   datetime time = iTime(
      symbol,
      PERIOD_D1,
      1
   );

   if(price <= 0.0 || time <= 0)
      return false;

   level.valid = true;
   level.type  = LIQUIDITY_PREVIOUS_DAY_HIGH;
   level.price = price;
   level.shift = 1;
   level.time  = time;

   return true;
}


bool FindPreviousDayLow(
   string symbol,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   double price = iLow(
      symbol,
      PERIOD_D1,
      1
   );

   datetime time = iTime(
      symbol,
      PERIOD_D1,
      1
   );

   if(price <= 0.0 || time <= 0)
      return false;

   level.valid = true;
   level.type  = LIQUIDITY_PREVIOUS_DAY_LOW;
   level.price = price;
   level.shift = 1;
   level.time  = time;

   return true;
}


//==================================================================
// PREVIOUS WEEK LIQUIDITY
//==================================================================

bool FindPreviousWeekHigh(
   string symbol,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   double price = iHigh(
      symbol,
      PERIOD_W1,
      1
   );

   datetime time = iTime(
      symbol,
      PERIOD_W1,
      1
   );

   if(price <= 0.0 || time <= 0)
      return false;

   level.valid = true;
   level.type  = LIQUIDITY_PREVIOUS_WEEK_HIGH;
   level.price = price;
   level.shift = 1;
   level.time  = time;

   return true;
}


bool FindPreviousWeekLow(
   string symbol,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   double price = iLow(
      symbol,
      PERIOD_W1,
      1
   );

   datetime time = iTime(
      symbol,
      PERIOD_W1,
      1
   );

   if(price <= 0.0 || time <= 0)
      return false;

   level.valid = true;
   level.type  = LIQUIDITY_PREVIOUS_WEEK_LOW;
   level.price = price;
   level.shift = 1;
   level.time  = time;

   return true;
}


//==================================================================
// EQUAL HIGHS
//==================================================================

bool FindEqualHighs(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   double tolerancePoints,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   int bars = Bars(symbol,timeframe);

   if(bars <= 0)
      return false;

   int maxShift = MathMin(
      lookback,
      bars-3
   );

   if(maxShift < 2)
      return false;

   double tolerance =
      tolerancePoints *
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   for(int first=2; first<=maxShift; first++)
   {
      double firstHigh =
         iHigh(symbol,timeframe,first);

      if(firstHigh <= 0.0)
         continue;

      for(int second=first+1;
          second<=maxShift;
          second++)
      {
         double secondHigh =
            iHigh(symbol,timeframe,second);

         if(secondHigh <= 0.0)
            continue;

         if(MathAbs(firstHigh-secondHigh)
            <= tolerance)
         {
            level.valid = true;
            level.type  = LIQUIDITY_EQUAL_HIGH;
            level.price = (firstHigh+secondHigh)/2.0;
            level.shift = first;
            level.time  =
               iTime(
                  symbol,
                  timeframe,
                  first
               );

            return true;
         }
      }
   }

   return false;
}


//==================================================================
// EQUAL LOWS
//==================================================================

bool FindEqualLows(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   double tolerancePoints,
   LiquidityLevel &level
)
{
   ResetLiquidityLevel(level);

   int bars = Bars(symbol,timeframe);

   if(bars <= 0)
      return false;

   int maxShift = MathMin(
      lookback,
      bars-3
   );

   if(maxShift < 2)
      return false;

   double tolerance =
      tolerancePoints *
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   for(int first=2; first<=maxShift; first++)
   {
      double firstLow =
         iLow(symbol,timeframe,first);

      if(firstLow <= 0.0)
         continue;

      for(int second=first+1;
          second<=maxShift;
          second++)
      {
         double secondLow =
            iLow(symbol,timeframe,second);

         if(secondLow <= 0.0)
            continue;

         if(MathAbs(firstLow-secondLow)
            <= tolerance)
         {
            level.valid = true;
            level.type  = LIQUIDITY_EQUAL_LOW;
            level.price = (firstLow+secondLow)/2.0;
            level.shift = first;
            level.time  =
               iTime(
                  symbol,
                  timeframe,
                  first
               );

            return true;
         }
      }
   }

   return false;
}


//==================================================================
// PRICE HELPERS
//==================================================================

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
      return 0.0;

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
      return 0.0;

   return level.price;
}


//==================================================================
// GENERIC SWEEP DETECTION
//==================================================================

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
      return false;

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

   if(high <= level.price)
      return false;

   double distance =
      high-level.price;

   if(distance < minimumSweepDistance)
      return false;

   if(close >= level.price)
      return false;

   sweep.valid = true;
   sweep.type  = level.type;

   sweep.liquidityPrice = level.price;
   sweep.sweepExtreme   = high;

   sweep.liquidityShift = level.shift;
   sweep.signalShift    = signalShift;

   sweep.liquidityTime = level.time;

   sweep.signalTime =
      iTime(
         symbol,
         timeframe,
         signalShift
      );

   return true;
}


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
      return false;

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

   if(low >= level.price)
      return false;

   double distance =
      level.price-low;

   if(distance < minimumSweepDistance)
      return false;

   if(close <= level.price)
      return false;

   sweep.valid = true;
   sweep.type  = level.type;

   sweep.liquidityPrice = level.price;
   sweep.sweepExtreme   = low;

   sweep.liquidityShift = level.shift;
   sweep.signalShift    = signalShift;

   sweep.liquidityTime = level.time;

   sweep.signalTime =
      iTime(
         symbol,
         timeframe,
         signalShift
      );

   return true;
}


//==================================================================
// GENERIC SWEEP
//==================================================================

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

   LiquiditySweep buySweep;

   if(DetectBuySideLiquiditySweep(
      symbol,
      timeframe,
      signalShift,
      lookback,
      leftBars,
      rightBars,
      minimumSweepDistance,
      buySweep
   ))
   {
      sweep = buySweep;
      return 1;
   }


   LiquiditySweep sellSweep;

   if(DetectSellSideLiquiditySweep(
      symbol,
      timeframe,
      signalShift,
      lookback,
      leftBars,
      rightBars,
      minimumSweepDistance,
      sellSweep
   ))
   {
      sweep = sellSweep;
      return -1;
   }

   return 0;
}


//==================================================================
// LIQUIDITY RELATIONSHIPS
//==================================================================

bool IsAboveLiquidity(
   double price,
   LiquidityLevel &level
)
{
   if(!level.valid)
      return false;

   return price > level.price;
}


bool IsBelowLiquidity(
   double price,
   LiquidityLevel &level
)
{
   if(!level.valid)
      return false;

   return price < level.price;
}


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

   return MathAbs(
      price-level.price
   ) <= tolerance;
}


//==================================================================
// SWEEP TYPE
//==================================================================

bool IsBuySideSweep(
   LiquiditySweep &sweep
)
{
   return
      sweep.valid &&
      (sweep.type == LIQUIDITY_BUY_SIDE ||
       sweep.type == LIQUIDITY_EQUAL_HIGH ||
       sweep.type == LIQUIDITY_PREVIOUS_DAY_HIGH ||
       sweep.type == LIQUIDITY_PREVIOUS_WEEK_HIGH);
}


bool IsSellSideSweep(
   LiquiditySweep &sweep
)
{
   return
      sweep.valid &&
      (sweep.type == LIQUIDITY_SELL_SIDE ||
       sweep.type == LIQUIDITY_EQUAL_LOW ||
       sweep.type == LIQUIDITY_PREVIOUS_DAY_LOW ||
       sweep.type == LIQUIDITY_PREVIOUS_WEEK_LOW);
}


//==================================================================
// TEXT
//==================================================================

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

      case LIQUIDITY_EQUAL_HIGH:
         return "EQUAL HIGHS";

      case LIQUIDITY_EQUAL_LOW:
         return "EQUAL LOWS";

      case LIQUIDITY_PREVIOUS_DAY_HIGH:
         return "PREVIOUS DAY HIGH";

      case LIQUIDITY_PREVIOUS_DAY_LOW:
         return "PREVIOUS DAY LOW";

      case LIQUIDITY_PREVIOUS_WEEK_HIGH:
         return "PREVIOUS WEEK HIGH";

      case LIQUIDITY_PREVIOUS_WEEK_LOW:
         return "PREVIOUS WEEK LOW";

      default:
         return "NONE";
   }
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OrderBlock.mqh                                                   |
//| Gold Multi-Strategy EA - Order Block Engine                     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_ORDER_BLOCK_MQH__
#define __EXNESS_GOLD_ORDER_BLOCK_MQH__

#include "MarketStructure.mqh"
#include "StructureSignal.mqh"

//====================================================================
// ORDER BLOCK TYPES
//====================================================================

enum ENUM_ORDER_BLOCK_DIRECTION
{
   ORDER_BLOCK_NONE = 0,
   ORDER_BLOCK_BULLISH,
   ORDER_BLOCK_BEARISH
};


//====================================================================
// ORDER BLOCK
//====================================================================

struct OrderBlock
{
   bool valid;

   bool mitigated;
   bool invalidated;
   bool retested;

   ENUM_ORDER_BLOCK_DIRECTION direction;

   double upper;
   double lower;
   double midpoint;

   double open;
   double close;

   double range;
   double body;

   int shift;
   datetime time;
};


//====================================================================
// RESET
//====================================================================

void ResetOrderBlock(OrderBlock &ob)
{
   ob.valid = false;

   ob.mitigated = false;
   ob.invalidated = false;
   ob.retested = false;

   ob.direction = ORDER_BLOCK_NONE;

   ob.upper = 0.0;
   ob.lower = 0.0;
   ob.midpoint = 0.0;

   ob.open = 0.0;
   ob.close = 0.0;

   ob.range = 0.0;
   ob.body = 0.0;

   ob.shift = -1;
   ob.time = 0;
}


//====================================================================
// CANDLE HELPERS
//====================================================================

bool OB_IsBullishCandle(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return
      iClose(symbol, timeframe, shift) >
      iOpen(symbol, timeframe, shift);
}


bool OB_IsBearishCandle(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return
      iClose(symbol, timeframe, shift) <
      iOpen(symbol, timeframe, shift);
}


//====================================================================
// BUILD ORDER BLOCK
//====================================================================

bool OB_Build(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   ENUM_ORDER_BLOCK_DIRECTION direction,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   double high  = iHigh(symbol, timeframe, shift);
   double low   = iLow(symbol, timeframe, shift);
   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0)
      return false;

   if(high <= low)
      return false;

   ob.valid = true;

   ob.direction = direction;

   ob.upper = high;
   ob.lower = low;

   ob.midpoint = (high + low) / 2.0;

   ob.open = open;
   ob.close = close;

   ob.range = high - low;
   ob.body = MathAbs(close - open);

   ob.shift = shift;
   ob.time = iTime(symbol, timeframe, shift);

   return true;
}


//====================================================================
// BULLISH ORDER BLOCK
//====================================================================

bool FindBullishOrderBlock(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int displacementShift,
   int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(displacementShift < 1 || lookback <= 0)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= displacementShift + 1)
      return false;

   int startShift = displacementShift + 1;

   int endShift = MathMin(
      startShift + lookback - 1,
      bars - 1
   );

   for(int shift = startShift; shift <= endShift; shift++)
   {
      // Bullish OB = last bearish candle before bullish move.
      if(!OB_IsBearishCandle(
         symbol,
         timeframe,
         shift
      ))
         continue;

      if(OB_Build(
         symbol,
         timeframe,
         shift,
         ORDER_BLOCK_BULLISH,
         ob
      ))
         return true;
   }

   return false;
}


//====================================================================
// BEARISH ORDER BLOCK
//====================================================================

bool FindBearishOrderBlock(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int displacementShift,
   int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(displacementShift < 1 || lookback <= 0)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= displacementShift + 1)
      return false;

   int startShift = displacementShift + 1;

   int endShift = MathMin(
      startShift + lookback - 1,
      bars - 1
   );

   for(int shift = startShift; shift <= endShift; shift++)
   {
      // Bearish OB = last bullish candle before bearish move.
      if(!OB_IsBullishCandle(
         symbol,
         timeframe,
         shift
      ))
         continue;

      if(OB_Build(
         symbol,
         timeframe,
         shift,
         ORDER_BLOCK_BEARISH,
         ob
      ))
         return true;
   }

   return false;
}


//====================================================================
// DIRECTIONAL ORDER BLOCK
//====================================================================

bool FindDirectionalOrderBlock(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int direction,
   int displacementShift,
   int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(direction > 0)
   {
      return FindBullishOrderBlock(
         symbol,
         timeframe,
         displacementShift,
         lookback,
         ob
      );
   }

   if(direction < 0)
   {
      return FindBearishOrderBlock(
         symbol,
         timeframe,
         displacementShift,
         lookback,
         ob
      );
   }

   return false;
}


//====================================================================
// ORDER BLOCK FROM STRUCTURE SIGNAL
//====================================================================

bool FindOrderBlockFromSignal(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   StructureSignal &signal,
   int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(!signal.valid)
      return false;

   int direction = GetSignalDirection(signal);

   if(direction == 0)
      return false;

   return FindDirectionalOrderBlock(
      symbol,
      timeframe,
      direction,
      signal.signalShift,
      lookback,
      ob
   );
}


//====================================================================
// PRICE LOCATION
//====================================================================

bool IsPriceInsideOrderBlock(
   double price,
   OrderBlock &ob
)
{
   if(!ob.valid || ob.invalidated)
      return false;

   return
      price >= ob.lower &&
      price <= ob.upper;
}


bool IsPriceAboveOrderBlock(
   double price,
   OrderBlock &ob
)
{
   return
      ob.valid &&
      price > ob.upper;
}


bool IsPriceBelowOrderBlock(
   double price,
   OrderBlock &ob
)
{
   return
      ob.valid &&
      price < ob.lower;
}


//====================================================================
// MITIGATION
//====================================================================

bool IsOrderBlockMitigated(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   OrderBlock &ob,
   int shift
)
{
   if(!ob.valid || shift < 1)
      return false;

   double high = iHigh(symbol, timeframe, shift);
   double low  = iLow(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0)
      return false;

   bool touched =
      high >= ob.lower &&
      low <= ob.upper;

   if(touched)
      ob.mitigated = true;

   return ob.mitigated;
}


//====================================================================
// RETEST
//====================================================================

bool IsOrderBlockRetest(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   OrderBlock &ob,
   int shift
)
{
   if(!ob.valid || shift < 1)
      return false;

   double high  = iHigh(symbol, timeframe, shift);
   double low   = iLow(symbol, timeframe, shift);
   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0)
      return false;

   bool touched =
      high >= ob.lower &&
      low <= ob.upper;

   if(!touched)
      return false;

   // Bullish OB: price enters and closes bullish.
   if(ob.direction == ORDER_BLOCK_BULLISH)
   {
      if(close > open && close >= ob.midpoint)
      {
         ob.retested = true;
         return true;
      }
   }

   // Bearish OB: price enters and closes bearish.
   if(ob.direction == ORDER_BLOCK_BEARISH)
   {
      if(close < open && close <= ob.midpoint)
      {
         ob.retested = true;
         return true;
      }
   }

   return false;
}


//====================================================================
// INVALIDATION
//====================================================================

bool IsOrderBlockInvalidated(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   OrderBlock &ob,
   int shift
)
{
   if(!ob.valid || shift < 1)
      return false;

   double close =
      iClose(symbol, timeframe, shift);

   if(close <= 0.0)
      return false;

   // Bullish OB invalidated by a close below it.
   if(ob.direction == ORDER_BLOCK_BULLISH)
   {
      if(close < ob.lower)
      {
         ob.invalidated = true;
         return true;
      }
   }

   // Bearish OB invalidated by a close above it.
   if(ob.direction == ORDER_BLOCK_BEARISH)
   {
      if(close > ob.upper)
      {
         ob.invalidated = true;
         return true;
      }
   }

   return false;
}


//====================================================================
// FRESHNESS
//====================================================================

bool IsFreshOrderBlock(
   OrderBlock &ob
)
{
   return
      ob.valid &&
      !ob.mitigated &&
      !ob.invalidated;
}


//====================================================================
// DIRECTION HELPERS
//====================================================================

bool IsBullishOrderBlock(
   OrderBlock &ob
)
{
   return
      ob.valid &&
      ob.direction == ORDER_BLOCK_BULLISH;
}


bool IsBearishOrderBlock(
   OrderBlock &ob
)
{
   return
      ob.valid &&
      ob.direction == ORDER_BLOCK_BEARISH;
}


//====================================================================
// MIDPOINT
//====================================================================

double GetOrderBlockMidpoint(
   OrderBlock &ob
)
{
   if(!ob.valid)
      return 0.0;

   return ob.midpoint;
}


//====================================================================
// TEXT
//====================================================================

string OrderBlockDirectionToString(
   ENUM_ORDER_BLOCK_DIRECTION direction
)
{
   switch(direction)
   {
      case ORDER_BLOCK_BULLISH:
         return "BULLISH ORDER BLOCK";

      case ORDER_BLOCK_BEARISH:
         return "BEARISH ORDER BLOCK";

      default:
         return "NONE";
   }
}


string OrderBlockDescription(
   OrderBlock &ob
)
{
   if(!ob.valid)
      return "INVALID ORDER BLOCK";

   return StringFormat(
      "%s | Lower=%f | Upper=%f | Mid=%f | Shift=%d | Mitigated=%s | Retested=%s | Invalidated=%s",
      OrderBlockDirectionToString(ob.direction),
      ob.lower,
      ob.upper,
      ob.midpoint,
      ob.shift,
      ob.mitigated ? "YES" : "NO",
      ob.retested ? "YES" : "NO",
      ob.invalidated ? "YES" : "NO"
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
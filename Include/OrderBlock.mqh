//+------------------------------------------------------------------+
//| OrderBlock.mqh                                                   |
//| ICT Order Block detection                                       |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_ORDER_BLOCK_MQH__
#define __EXNESS_ICT_ORDER_BLOCK_MQH__

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
// ORDER BLOCK STRUCTURE
//====================================================================

struct OrderBlock
{
   bool valid;

   ENUM_ORDER_BLOCK_DIRECTION direction;

   double upper;
   double lower;

   double open;
   double close;

   int shift;
   datetime time;
};


//====================================================================
// RESET
//====================================================================

void ResetOrderBlock(OrderBlock &ob)
{
   ob.valid = false;

   ob.direction = ORDER_BLOCK_NONE;

   ob.upper = 0.0;
   ob.lower = 0.0;

   ob.open = 0.0;
   ob.close = 0.0;

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
// BULLISH ORDER BLOCK
//====================================================================

// A bullish order block is searched for immediately before bullish
// displacement.
//
// The preferred candle is the last bearish candle before the
// bullish displacement.
//
// The complete candle range is used as the OB zone.
bool FindBullishOrderBlock(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int displacementShift,
   int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(displacementShift < 1)
      return false;

   if(lookback <= 0)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   int startShift = displacementShift + 1;

   int endShift =
      MathMin(
         startShift + lookback - 1,
         bars - 1
      );

   if(startShift > endShift)
      return false;

   for(int shift = startShift;
       shift <= endShift;
       shift++)
   {
      if(!OB_IsBearishCandle(
         symbol,
         timeframe,
         shift
      ))
      {
         continue;
      }

      double high =
         iHigh(
            symbol,
            timeframe,
            shift
         );

      double low =
         iLow(
            symbol,
            timeframe,
            shift
         );

      double open =
         iOpen(
            symbol,
            timeframe,
            shift
         );

      double close =
         iClose(
            symbol,
            timeframe,
            shift
         );

      if(high <= low)
         continue;

      ob.valid = true;

      ob.direction = ORDER_BLOCK_BULLISH;

      ob.upper = high;
      ob.lower = low;

      ob.open = open;
      ob.close = close;

      ob.shift = shift;

      ob.time =
         iTime(
            symbol,
            timeframe,
            shift
         );

      return true;
   }

   return false;
}


//====================================================================
// BEARISH ORDER BLOCK
//====================================================================

// A bearish order block is searched for immediately before bearish
// displacement.
//
// The preferred candle is the last bullish candle before the
// bearish displacement.
bool FindBearishOrderBlock(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int displacementShift,
   int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(displacementShift < 1)
      return false;

   if(lookback <= 0)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   int startShift = displacementShift + 1;

   int endShift =
      MathMin(
         startShift + lookback - 1,
         bars - 1
      );

   if(startShift > endShift)
      return false;

   for(int shift = startShift;
       shift <= endShift;
       shift++)
   {
      if(!OB_IsBullishCandle(
         symbol,
         timeframe,
         shift
      ))
      {
         continue;
      }

      double high =
         iHigh(
            symbol,
            timeframe,
            shift
         );

      double low =
         iLow(
            symbol,
            timeframe,
            shift
         );

      double open =
         iOpen(
            symbol,
            timeframe,
            shift
         );

      double close =
         iClose(
            symbol,
            timeframe,
            shift
         );

      if(high <= low)
         continue;

      ob.valid = true;

      ob.direction = ORDER_BLOCK_BEARISH;

      ob.upper = high;
      ob.lower = low;

      ob.open = open;
      ob.close = close;

      ob.shift = shift;

      ob.time =
         iTime(
            symbol,
            timeframe,
            shift
         );

      return true;
   }

   return false;
}


//====================================================================
// DIRECTIONAL ORDER BLOCK
//====================================================================

// direction:
//
//  1 = bullish
// -1 = bearish
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

// Automatically use the direction of a StructureSignal.
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

   int direction =
      GetSignalDirection(signal);

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
   if(!ob.valid)
      return false;

   return
      price >= ob.lower &&
      price <= ob.upper;
}


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
// ORDER BLOCK MIDPOINT
//====================================================================

double GetOrderBlockMidpoint(
   OrderBlock &ob
)
{
   if(!ob.valid)
      return 0.0;

   return
      (ob.upper + ob.lower) / 2.0;
}


//====================================================================
// ORDER BLOCK TEXT
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
      "%s | Lower=%f | Upper=%f | Shift=%d",
      OrderBlockDirectionToString(ob.direction),
      ob.lower,
      ob.upper,
      ob.shift
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+

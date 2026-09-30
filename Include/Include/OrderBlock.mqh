//+------------------------------------------------------------------+
//| OrderBlock.mqh                                                   |
//| Deterministic Order Block detection for Exness ICT EA            |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_ORDER_BLOCK_MQH__
#define __EXNESS_ICT_ORDER_BLOCK_MQH__

enum ENUM_OB_DIRECTION
{
   OB_NONE = 0,
   OB_BULLISH,
   OB_BEARISH
};

enum ENUM_OB_STATUS
{
   OB_STATUS_NONE = 0,
   OB_STATUS_ACTIVE,
   OB_STATUS_MITIGATED,
   OB_STATUS_INVALIDATED
};

struct OrderBlock
{
   ENUM_OB_DIRECTION direction;
   ENUM_OB_STATUS    status;

   double upper;
   double lower;
   double midpoint;
   double size;

   datetime formationTime;

   int formationShift;
   int displacementShift;

   bool valid;
   bool mitigated;
   bool invalidated;
};

//+------------------------------------------------------------------+
//| Reset order block                                                |
//+------------------------------------------------------------------+
void ResetOrderBlock(OrderBlock &ob)
{
   ob.direction         = OB_NONE;
   ob.status            = OB_STATUS_NONE;

   ob.upper             = 0.0;
   ob.lower             = 0.0;
   ob.midpoint          = 0.0;
   ob.size              = 0.0;

   ob.formationTime     = 0;

   ob.formationShift    = -1;
   ob.displacementShift = -1;

   ob.valid              = false;
   ob.mitigated          = false;
   ob.invalidated        = false;
}

//+------------------------------------------------------------------+
//| Validate candle                                                   |
//+------------------------------------------------------------------+
bool IsValidOBCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 0)
      return(false);

   double high  = iHigh(symbol,timeframe,shift);
   double low   = iLow(symbol,timeframe,shift);
   double open  = iOpen(symbol,timeframe,shift);
   double close = iClose(symbol,timeframe,shift);

   if(high <= 0.0 || low <= 0.0)
      return(false);

   if(open <= 0.0 || close <= 0.0)
      return(false);

   if(high < low)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Bearish candle                                                    |
//+------------------------------------------------------------------+
bool IsOBCandleBearish(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(!IsValidOBCandle(symbol,timeframe,shift))
      return(false);

   return(
      iClose(symbol,timeframe,shift)
      <
      iOpen(symbol,timeframe,shift)
   );
}

//+------------------------------------------------------------------+
//| Bullish candle                                                    |
//+------------------------------------------------------------------+
bool IsOBCandleBullish(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(!IsValidOBCandle(symbol,timeframe,shift))
      return(false);

   return(
      iClose(symbol,timeframe,shift)
      >
      iOpen(symbol,timeframe,shift)
   );
}

//+------------------------------------------------------------------+
//| Build bullish order block                                        |
//| The last bearish candle before bullish displacement.             |
//+------------------------------------------------------------------+
bool BuildBullishOrderBlock(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int formationShift,
   const int displacementShift,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(formationShift < 1)
      return(false);

   if(displacementShift < 1)
      return(false);

   if(!IsOBCandleBearish(
      symbol,timeframe,formationShift
   ))
      return(false);

   if(!IsBullishDisplacement(
      symbol,timeframe,displacementShift
   ))
      return(false);

   double high = iHigh(
      symbol,timeframe,formationShift
   );

   double low = iLow(
      symbol,timeframe,formationShift
   );

   datetime formationTime =
      iTime(symbol,timeframe,formationShift);

   if(high <= 0.0 || low <= 0.0)
      return(false);

   if(formationTime <= 0)
      return(false);

   ob.direction         = OB_BULLISH;
   ob.status            = OB_STATUS_ACTIVE;

   ob.upper             = high;
   ob.lower             = low;
   ob.midpoint          = (high + low) / 2.0;
   ob.size              = high - low;

   ob.formationTime     = formationTime;

   ob.formationShift    = formationShift;
   ob.displacementShift = displacementShift;

   ob.valid             = true;
   ob.mitigated         = false;
   ob.invalidated       = false;

   return(true);
}

//+------------------------------------------------------------------+
//| Build bearish order block                                        |
//| The last bullish candle before bearish displacement.             |
//+------------------------------------------------------------------+
bool BuildBearishOrderBlock(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int formationShift,
   const int displacementShift,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(formationShift < 1)
      return(false);

   if(displacementShift < 1)
      return(false);

   if(!IsOBCandleBullish(
      symbol,timeframe,formationShift
   ))
      return(false);

   if(!IsBearishDisplacement(
      symbol,timeframe,displacementShift
   ))
      return(false);

   double high = iHigh(
      symbol,timeframe,formationShift
   );

   double low = iLow(
      symbol,timeframe,formationShift
   );

   datetime formationTime =
      iTime(symbol,timeframe,formationShift);

   if(high <= 0.0 || low <= 0.0)
      return(false);

   if(formationTime <= 0)
      return(false);

   ob.direction         = OB_BEARISH;
   ob.status            = OB_STATUS_ACTIVE;

   ob.upper             = high;
   ob.lower             = low;
   ob.midpoint          = (high + low) / 2.0;
   ob.size              = high - low;

   ob.formationTime     = formationTime;

   ob.formationShift    = formationShift;
   ob.displacementShift = displacementShift;

   ob.valid             = true;
   ob.mitigated         = false;
   ob.invalidated       = false;

   return(true);
}

//+------------------------------------------------------------------+
//| Find bullish order block                                         |
//+------------------------------------------------------------------+
bool FindBullishOrderBlock(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int displacementShift,
   const int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(displacementShift < 1)
      return(false);

   if(lookback < 1)
      return(false);

   int totalBars = Bars(symbol,timeframe);

   if(totalBars <= displacementShift + 1)
      return(false);

   int firstShift = displacementShift + 1;
   int lastShift  = MathMin(
      displacementShift + lookback,
      totalBars - 1
   );

   for(int shift=firstShift;shift<=lastShift;shift++)
   {
      if(!IsOBCandleBearish(
         symbol,timeframe,shift
      ))
         continue;

      if(BuildBullishOrderBlock(
         symbol,timeframe,
         shift,
         displacementShift,
         ob
      ))
      {
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Find bearish order block                                         |
//+------------------------------------------------------------------+
bool FindBearishOrderBlock(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int displacementShift,
   const int lookback,
   OrderBlock &ob
)
{
   ResetOrderBlock(ob);

   if(displacementShift < 1)
      return(false);

   if(lookback < 1)
      return(false);

   int totalBars = Bars(symbol,timeframe);

   if(totalBars <= displacementShift + 1)
      return(false);

   int firstShift = displacementShift + 1;
   int lastShift  = MathMin(
      displacementShift + lookback,
      totalBars - 1
   );

   for(int shift=firstShift;shift<=lastShift;shift++)
   {
      if(!IsOBCandleBullish(
         symbol,timeframe,shift
      ))
         continue;

      if(BuildBearishOrderBlock(
         symbol,timeframe,
         shift,
         displacementShift,
         ob
      ))
      {
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Price inside order block                                         |
//+------------------------------------------------------------------+
bool IsPriceInsideOrderBlock(
   const double price,
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(false);

   if(price <= 0.0)
      return(false);

   return(
      price >= ob.lower &&
      price <= ob.upper
   );
}

//+------------------------------------------------------------------+
//| Candle touches order block                                       |
//+------------------------------------------------------------------+
bool DidCandleTouchOrderBlock(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(false);

   if(candleShift < 0)
      return(false);

   double high = iHigh(
      symbol,timeframe,candleShift
   );

   double low = iLow(
      symbol,timeframe,candleShift
   );

   if(high <= 0.0 || low <= 0.0)
      return(false);

   return(
      high >= ob.lower &&
      low <= ob.upper
   );
}

//+------------------------------------------------------------------+
//| Bullish OB mitigation                                            |
//+------------------------------------------------------------------+
bool IsBullishOrderBlockMitigated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid || ob.direction != OB_BULLISH)
      return(false);

   if(candleShift < 0)
      return(false);

   double low = iLow(
      symbol,timeframe,candleShift
   );

   if(low <= 0.0)
      return(false);

   return(low <= ob.upper);
}

//+------------------------------------------------------------------+
//| Bearish OB mitigation                                            |
//+------------------------------------------------------------------+
bool IsBearishOrderBlockMitigated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid || ob.direction != OB_BEARISH)
      return(false);

   if(candleShift < 0)
      return(false);

   double high = iHigh(
      symbol,timeframe,candleShift
   );

   if(high <= 0.0)
      return(false);

   return(high >= ob.lower);
}

//+------------------------------------------------------------------+
//| Generic mitigation                                               |
//+------------------------------------------------------------------+
bool IsOrderBlockMitigated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(false);

   if(ob.direction == OB_BULLISH)
      return(
         IsBullishOrderBlockMitigated(
            symbol,timeframe,candleShift,ob
         )
      );

   if(ob.direction == OB_BEARISH)
      return(
         IsBearishOrderBlockMitigated(
            symbol,timeframe,candleShift,ob
         )
      );

   return(false);
}

//+------------------------------------------------------------------+
//| Bullish OB invalidation                                          |
//| A closed candle below the OB invalidates the bullish zone.       |
//+------------------------------------------------------------------+
bool IsBullishOrderBlockInvalidated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid || ob.direction != OB_BULLISH)
      return(false);

   if(candleShift < 0)
      return(false);

   double close = iClose(
      symbol,timeframe,candleShift
   );

   if(close <= 0.0)
      return(false);

   return(close < ob.lower);
}

//+------------------------------------------------------------------+
//| Bearish OB invalidation                                          |
//| A closed candle above the OB invalidates the bearish zone.       |
//+------------------------------------------------------------------+
bool IsBearishOrderBlockInvalidated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid || ob.direction != OB_BEARISH)
      return(false);

   if(candleShift < 0)
      return(false);

   double close = iClose(
      symbol,timeframe,candleShift
   );

   if(close <= 0.0)
      return(false);

   return(close > ob.upper);
}

//+------------------------------------------------------------------+
//| Generic invalidation                                             |
//+------------------------------------------------------------------+
bool IsOrderBlockInvalidated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(false);

   if(ob.direction == OB_BULLISH)
      return(
         IsBullishOrderBlockInvalidated(
            symbol,timeframe,candleShift,ob
         )
      );

   if(ob.direction == OB_BEARISH)
      return(
         IsBearishOrderBlockInvalidated(
            symbol,timeframe,candleShift,ob
         )
      );

   return(false);
}

//+------------------------------------------------------------------+
//| Update order block status                                        |
//+------------------------------------------------------------------+
void UpdateOrderBlockStatus(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   OrderBlock &ob
)
{
   if(!ob.valid)
      return;

   if(IsOrderBlockInvalidated(
      symbol,timeframe,candleShift,ob
   ))
   {
      ob.status     = OB_STATUS_INVALIDATED;
      ob.invalidated = true;
      ob.valid       = false;
      return;
   }

   if(IsOrderBlockMitigated(
      symbol,timeframe,candleShift,ob
   ))
   {
      ob.status    = OB_STATUS_MITIGATED;
      ob.mitigated = true;
      return;
   }

   ob.status = OB_STATUS_ACTIVE;
}

//+------------------------------------------------------------------+
//| Entry-zone check                                                  |
//+------------------------------------------------------------------+
bool IsBullishOrderBlockEntryZone(
   const double price,
   const OrderBlock &ob
)
{
   if(!ob.valid || ob.direction != OB_BULLISH)
      return(false);

   return(IsPriceInsideOrderBlock(price,ob));
}

//+------------------------------------------------------------------+
//| Entry-zone check                                                  |
//+------------------------------------------------------------------+
bool IsBearishOrderBlockEntryZone(
   const double price,
   const OrderBlock &ob
)
{
   if(!ob.valid || ob.direction != OB_BEARISH)
      return(false);

   return(IsPriceInsideOrderBlock(price,ob));
}

//+------------------------------------------------------------------+
//| Generic entry-zone check                                         |
//+------------------------------------------------------------------+
bool IsOrderBlockEntryZone(
   const double price,
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(false);

   return(IsPriceInsideOrderBlock(price,ob));
}

//+------------------------------------------------------------------+
//| Get OB midpoint                                                   |
//+------------------------------------------------------------------+
double GetOrderBlockMidpoint(
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(0.0);

   return(ob.midpoint);
}

//+------------------------------------------------------------------+
//| Get OB size                                                       |
//+------------------------------------------------------------------+
double GetOrderBlockSize(
   const OrderBlock &ob
)
{
   if(!ob.valid)
      return(0.0);

   return(ob.size);
}

//+------------------------------------------------------------------+
//| Direction string                                                  |
//+------------------------------------------------------------------+
string OrderBlockDirectionToString(
   const ENUM_OB_DIRECTION direction
)
{
   switch(direction)
   {
      case OB_BULLISH:
         return("BULLISH_OB");

      case OB_BEARISH:
         return("BEARISH_OB");

      default:
         return("NONE");
   }
}

//+------------------------------------------------------------------+
//| Status string                                                     |
//+------------------------------------------------------------------+
string OrderBlockStatusToString(
   const ENUM_OB_STATUS status
)
{
   switch(status)
   {
      case OB_STATUS_ACTIVE:
         return("ACTIVE");

      case OB_STATUS_MITIGATED:
         return("MITIGATED");

      case OB_STATUS_INVALIDATED:
         return("INVALIDATED");

      default:
         return("NONE");
   }
}

//+------------------------------------------------------------------+
#endif

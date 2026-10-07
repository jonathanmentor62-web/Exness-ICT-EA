//+------------------------------------------------------------------+
//| AdvancedBlocks.mqh                                               |
//| Gold Multi-Strategy EA - Advanced ICT/SMC Block Engine           |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_ADVANCED_BLOCKS_MQH__
#define __EXNESS_GOLD_ADVANCED_BLOCKS_MQH__

#include "Config.mqh"
#include "MarketStructure.mqh"
#include "StructureSignal.mqh"
#include "Liquidity.mqh"
#include "FVG.mqh"
#include "OrderBlock.mqh"

//-------------------------------------------------------------------
// Advanced block types
//-------------------------------------------------------------------
enum ENUM_ADVANCED_BLOCK_TYPE
{
   ADV_BLOCK_NONE = 0,
   ADV_BLOCK_BREAKER_BULLISH,
   ADV_BLOCK_BREAKER_BEARISH,
   ADV_BLOCK_MITIGATION_BULLISH,
   ADV_BLOCK_MITIGATION_BEARISH,
   ADV_BLOCK_DISPLACEMENT_BULLISH,
   ADV_BLOCK_DISPLACEMENT_BEARISH
};

//-------------------------------------------------------------------
// Advanced block direction
//-------------------------------------------------------------------
enum ENUM_ADVANCED_BLOCK_DIRECTION
{
   ADV_DIRECTION_NONE = 0,
   ADV_DIRECTION_BULLISH,
   ADV_DIRECTION_BEARISH
};

//-------------------------------------------------------------------
// Advanced block structure
//-------------------------------------------------------------------
struct AdvancedBlock
{
   bool valid;

   ENUM_ADVANCED_BLOCK_TYPE type;
   ENUM_ADVANCED_BLOCK_DIRECTION direction;

   double upper;
   double lower;
   double midpoint;

   double originOpen;
   double originClose;
   double originHigh;
   double originLow;

   double displacementHigh;
   double displacementLow;

   bool mitigated;
   bool retested;
   bool invalidated;
   bool fresh;

   bool linkedToFVG;
   bool linkedToOrderBlock;
   bool linkedToLiquidity;
   bool linkedToStructure;

   int originShift;
   int displacementShift;

   datetime originTime;
   datetime displacementTime;
   datetime signalTime;

   double score;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset advanced block
//-------------------------------------------------------------------
void ResetAdvancedBlock(AdvancedBlock &block)
{
   block.valid = false;

   block.type = ADV_BLOCK_NONE;
   block.direction = ADV_DIRECTION_NONE;

   block.upper = 0.0;
   block.lower = 0.0;
   block.midpoint = 0.0;

   block.originOpen = 0.0;
   block.originClose = 0.0;
   block.originHigh = 0.0;
   block.originLow = 0.0;

   block.displacementHigh = 0.0;
   block.displacementLow = 0.0;

   block.mitigated = false;
   block.retested = false;
   block.invalidated = false;
   block.fresh = false;

   block.linkedToFVG = false;
   block.linkedToOrderBlock = false;
   block.linkedToLiquidity = false;
   block.linkedToStructure = false;

   block.originShift = -1;
   block.displacementShift = -1;

   block.originTime = 0;
   block.displacementTime = 0;
   block.signalTime = 0;

   block.score = 0.0;

   block.reason = "";
   block.evidence = "";
}

//-------------------------------------------------------------------
// Direction helpers
//-------------------------------------------------------------------
bool AB_IsBullish(const AdvancedBlock &block)
{
   return block.valid &&
          block.direction == ADV_DIRECTION_BULLISH;
}

bool AB_IsBearish(const AdvancedBlock &block)
{
   return block.valid &&
          block.direction == ADV_DIRECTION_BEARISH;
}

//-------------------------------------------------------------------
// Type helpers
//-------------------------------------------------------------------
bool AB_IsBreaker(const AdvancedBlock &block)
{
   return block.valid &&
          (block.type == ADV_BLOCK_BREAKER_BULLISH ||
           block.type == ADV_BLOCK_BREAKER_BEARISH);
}

bool AB_IsMitigation(const AdvancedBlock &block)
{
   return block.valid &&
          (block.type == ADV_BLOCK_MITIGATION_BULLISH ||
           block.type == ADV_BLOCK_MITIGATION_BEARISH);
}

bool AB_IsDisplacementOrigin(const AdvancedBlock &block)
{
   return block.valid &&
          (block.type == ADV_BLOCK_DISPLACEMENT_BULLISH ||
           block.type == ADV_BLOCK_DISPLACEMENT_BEARISH);
}

//-------------------------------------------------------------------
// Candle helpers
//-------------------------------------------------------------------
double AB_Open(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const int shift)
{
   return iOpen(symbol, timeframe, shift);
}

double AB_Close(const string symbol,
                const ENUM_TIMEFRAMES timeframe,
                const int shift)
{
   return iClose(symbol, timeframe, shift);
}

double AB_High(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const int shift)
{
   return iHigh(symbol, timeframe, shift);
}

double AB_Low(const string symbol,
              const ENUM_TIMEFRAMES timeframe,
              const int shift)
{
   return iLow(symbol, timeframe, shift);
}

datetime AB_Time(const string symbol,
                 const ENUM_TIMEFRAMES timeframe,
                 const int shift)
{
   return iTime(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
// Candle direction
//-------------------------------------------------------------------
bool AB_IsBullishCandle(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const int shift)
{
   double open = AB_Open(symbol,timeframe,shift);
   double close = AB_Close(symbol,timeframe,shift);

   return open > 0.0 &&
          close > 0.0 &&
          close > open;
}

bool AB_IsBearishCandle(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const int shift)
{
   double open = AB_Open(symbol,timeframe,shift);
   double close = AB_Close(symbol,timeframe,shift);

   return open > 0.0 &&
          close > 0.0 &&
          close < open;
}

//-------------------------------------------------------------------
// Candle measurements
//-------------------------------------------------------------------
double AB_CandleRange(const string symbol,
                      const ENUM_TIMEFRAMES timeframe,
                      const int shift)
{
   double high = AB_High(symbol,timeframe,shift);
   double low = AB_Low(symbol,timeframe,shift);

   if(high <= 0.0 || low <= 0.0 || high <= low)
      return 0.0;

   return high - low;
}

double AB_CandleBody(const string symbol,
                     const ENUM_TIMEFRAMES timeframe,
                     const int shift)
{
   double open = AB_Open(symbol,timeframe,shift);
   double close = AB_Close(symbol,timeframe,shift);

   if(open <= 0.0 || close <= 0.0)
      return 0.0;

   return MathAbs(close - open);
}

double AB_BodyRatio(const string symbol,
                    const ENUM_TIMEFRAMES timeframe,
                    const int shift)
{
   double range = AB_CandleRange(symbol,timeframe,shift);
   double body = AB_CandleBody(symbol,timeframe,shift);

   if(range <= 0.0)
      return 0.0;

   return body / range;
}

//-------------------------------------------------------------------
// Price inside block
//-------------------------------------------------------------------
bool AB_IsPriceInside(const AdvancedBlock &block,
                      const double price)
{
   if(!block.valid || price <= 0.0)
      return false;

   return price >= block.lower &&
          price <= block.upper;
}

//-------------------------------------------------------------------
// Price above block
//-------------------------------------------------------------------
bool AB_IsPriceAbove(const AdvancedBlock &block,
                     const double price)
{
   if(!block.valid || price <= 0.0)
      return false;

   return price > block.upper;
}

//-------------------------------------------------------------------
// Price below block
//-------------------------------------------------------------------
bool AB_IsPriceBelow(const AdvancedBlock &block,
                     const double price)
{
   if(!block.valid || price <= 0.0)
      return false;

   return price < block.lower;
}

//-------------------------------------------------------------------
// Midpoint
//-------------------------------------------------------------------
double AB_Midpoint(const AdvancedBlock &block)
{
   if(!block.valid)
      return 0.0;

   return (block.upper + block.lower) * 0.5;
}
//-------------------------------------------------------------------
// Build block from candle
//-------------------------------------------------------------------
void AB_BuildFromCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const ENUM_ADVANCED_BLOCK_TYPE type,
   const ENUM_ADVANCED_BLOCK_DIRECTION direction,
   AdvancedBlock &block)
{
   ResetAdvancedBlock(block);

   if(shift < 1)
      return;

   double open  = AB_Open(symbol,timeframe,shift);
   double close = AB_Close(symbol,timeframe,shift);
   double high  = AB_High(symbol,timeframe,shift);
   double low   = AB_Low(symbol,timeframe,shift);

   if(open <= 0.0 || close <= 0.0 || high <= 0.0 || low <= 0.0)
      return;

   if(high <= low)
      return;

   block.valid = true;
   block.type = type;
   block.direction = direction;

   block.upper = high;
   block.lower = low;
   block.midpoint = (high + low) * 0.5;

   block.originOpen = open;
   block.originClose = close;
   block.originHigh = high;
   block.originLow = low;

   block.originShift = shift;
   block.originTime = AB_Time(symbol,timeframe,shift);
   block.signalTime = block.originTime;

   block.fresh = true;

   block.score = 0.0;

   if(direction == ADV_DIRECTION_BULLISH &&
      AB_IsBearishCandle(symbol,timeframe,shift))
   {
      block.score += 10.0;
   }

   if(direction == ADV_DIRECTION_BEARISH &&
      AB_IsBullishCandle(symbol,timeframe,shift))
   {
      block.score += 10.0;
   }
}

//-------------------------------------------------------------------
// Find bullish breaker block
//-------------------------------------------------------------------
bool AB_FindBullishBreaker(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   if(!ICT_ENABLE_BREAKER_BLOCK)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars < 10)
      return false;

   int maximum = MathMin(lookback,bars - 3);

   for(int shift = 2; shift <= maximum; shift++)
   {
      if(!AB_IsBearishCandle(symbol,timeframe,shift))
         continue;

      double blockHigh = AB_High(symbol,timeframe,shift);
      double blockLow  = AB_Low(symbol,timeframe,shift);

      if(blockHigh <= blockLow)
         continue;

      bool laterBullishBreak = false;

      for(int newer = shift - 1; newer >= 1; newer--)
      {
         double newerClose = AB_Close(symbol,timeframe,newer);

         if(newerClose > blockHigh)
         {
            laterBullishBreak = true;

            out.displacementShift = newer;
            out.displacementTime =
               AB_Time(symbol,timeframe,newer);

            out.displacementHigh =
               AB_High(symbol,timeframe,newer);

            out.displacementLow =
               AB_Low(symbol,timeframe,newer);

            break;
         }
      }

      if(!laterBullishBreak)
         continue;

      AB_BuildFromCandle(
         symbol,
         timeframe,
         shift,
         ADV_BLOCK_BREAKER_BULLISH,
         ADV_DIRECTION_BULLISH,
         out
      );

      if(!out.valid)
         continue;

      out.linkedToStructure = true;
      out.score += 20.0;

      if(out.displacementShift > 0)
      {
         double displacementBody =
            AB_BodyRatio(
               symbol,
               timeframe,
               out.displacementShift
            );

         if(displacementBody >= ICT_MIN_BODY_RATIO)
            out.score += 10.0;
      }

      out.reason =
         "Bullish breaker: bearish origin block was broken upward.";

      out.evidence =
         "Bearish block high was displaced and price closed above it.";

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Find bearish breaker block
//-------------------------------------------------------------------
bool AB_FindBearishBreaker(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   if(!ICT_ENABLE_BREAKER_BLOCK)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars < 10)
      return false;

   int maximum = MathMin(lookback,bars - 3);

   for(int shift = 2; shift <= maximum; shift++)
   {
      if(!AB_IsBullishCandle(symbol,timeframe,shift))
         continue;

      double blockHigh = AB_High(symbol,timeframe,shift);
      double blockLow  = AB_Low(symbol,timeframe,shift);

      if(blockHigh <= blockLow)
         continue;

      bool laterBearishBreak = false;

      for(int newer = shift - 1; newer >= 1; newer--)
      {
         double newerClose = AB_Close(symbol,timeframe,newer);

         if(newerClose < blockLow)
         {
            laterBearishBreak = true;

            out.displacementShift = newer;
            out.displacementTime =
               AB_Time(symbol,timeframe,newer);

            out.displacementHigh =
               AB_High(symbol,timeframe,newer);

            out.displacementLow =
               AB_Low(symbol,timeframe,newer);

            break;
         }
      }

      if(!laterBearishBreak)
         continue;

      AB_BuildFromCandle(
         symbol,
         timeframe,
         shift,
         ADV_BLOCK_BREAKER_BEARISH,
         ADV_DIRECTION_BEARISH,
         out
      );

      if(!out.valid)
         continue;

      out.linkedToStructure = true;
      out.score += 20.0;

      if(out.displacementShift > 0)
      {
         double displacementBody =
            AB_BodyRatio(
               symbol,
               timeframe,
               out.displacementShift
            );

         if(displacementBody >= ICT_MIN_BODY_RATIO)
            out.score += 10.0;
      }

      out.reason =
         "Bearish breaker: bullish origin block was broken downward.";

      out.evidence =
         "Bullish block low was displaced and price closed below it.";

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Find directional breaker
//-------------------------------------------------------------------
bool AB_FindBreaker(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const ENUM_ADVANCED_BLOCK_DIRECTION direction,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(direction == ADV_DIRECTION_BULLISH)
   {
      return AB_FindBullishBreaker(
         symbol,
         timeframe,
         lookback,
         out
      );
   }

   if(direction == ADV_DIRECTION_BEARISH)
   {
      return AB_FindBearishBreaker(
         symbol,
         timeframe,
         lookback,
         out
      );
   }

   return false;
}
//-------------------------------------------------------------------
// Find bullish mitigation block
//-------------------------------------------------------------------
bool AB_FindBullishMitigation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   if(!ICT_ENABLE_MITIGATION_BLOCK)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars < 10)
      return false;

   int maximum = MathMin(lookback,bars - 3);

   for(int shift = 2; shift <= maximum; shift++)
   {
      // A bullish mitigation block begins with a bearish candle.
      if(!AB_IsBearishCandle(symbol,timeframe,shift))
         continue;

      double blockHigh = AB_High(symbol,timeframe,shift);
      double blockLow  = AB_Low(symbol,timeframe,shift);

      if(blockHigh <= blockLow)
         continue;

      bool bullishResponse = false;
      int responseShift = -1;

      // Search newer candles for a bullish reaction.
      for(int newer = shift - 1; newer >= 1; newer--)
      {
         double close = AB_Close(symbol,timeframe,newer);

         if(close > blockHigh)
         {
            bullishResponse = true;
            responseShift = newer;
            break;
         }
      }

      if(!bullishResponse)
         continue;

      AB_BuildFromCandle(
         symbol,
         timeframe,
         shift,
         ADV_BLOCK_MITIGATION_BULLISH,
         ADV_DIRECTION_BULLISH,
         out
      );

      if(!out.valid)
         continue;

      out.linkedToStructure = true;
      out.displacementShift = responseShift;

      out.displacementTime =
         AB_Time(symbol,timeframe,responseShift);

      out.displacementHigh =
         AB_High(symbol,timeframe,responseShift);

      out.displacementLow =
         AB_Low(symbol,timeframe,responseShift);

      out.score += 15.0;

      if(AB_BodyRatio(
            symbol,
            timeframe,
            responseShift) >= ICT_MIN_BODY_RATIO)
      {
         out.score += 10.0;
      }

      out.reason =
         "Bullish mitigation block detected after bullish response.";

      out.evidence =
         "Bearish origin candle was reclaimed by bullish price action.";

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Find bearish mitigation block
//-------------------------------------------------------------------
bool AB_FindBearishMitigation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   if(!ICT_ENABLE_MITIGATION_BLOCK)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars < 10)
      return false;

   int maximum = MathMin(lookback,bars - 3);

   for(int shift = 2; shift <= maximum; shift++)
   {
      // A bearish mitigation block begins with a bullish candle.
      if(!AB_IsBullishCandle(symbol,timeframe,shift))
         continue;

      double blockHigh = AB_High(symbol,timeframe,shift);
      double blockLow  = AB_Low(symbol,timeframe,shift);

      if(blockHigh <= blockLow)
         continue;

      bool bearishResponse = false;
      int responseShift = -1;

      // Search newer candles for a bearish reaction.
      for(int newer = shift - 1; newer >= 1; newer--)
      {
         double close = AB_Close(symbol,timeframe,newer);

         if(close < blockLow)
         {
            bearishResponse = true;
            responseShift = newer;
            break;
         }
      }

      if(!bearishResponse)
         continue;

      AB_BuildFromCandle(
         symbol,
         timeframe,
         shift,
         ADV_BLOCK_MITIGATION_BEARISH,
         ADV_DIRECTION_BEARISH,
         out
      );

      if(!out.valid)
         continue;

      out.linkedToStructure = true;
      out.displacementShift = responseShift;

      out.displacementTime =
         AB_Time(symbol,timeframe,responseShift);

      out.displacementHigh =
         AB_High(symbol,timeframe,responseShift);

      out.displacementLow =
         AB_Low(symbol,timeframe,responseShift);

      out.score += 15.0;

      if(AB_BodyRatio(
            symbol,
            timeframe,
            responseShift) >= ICT_MIN_BODY_RATIO)
      {
         out.score += 10.0;
      }

      out.reason =
         "Bearish mitigation block detected after bearish response.";

      out.evidence =
         "Bullish origin candle was rejected by bearish price action.";

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Find directional mitigation block
//-------------------------------------------------------------------
bool AB_FindMitigation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const ENUM_ADVANCED_BLOCK_DIRECTION direction,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(direction == ADV_DIRECTION_BULLISH)
   {
      return AB_FindBullishMitigation(
         symbol,
         timeframe,
         lookback,
         out
      );
   }

   if(direction == ADV_DIRECTION_BEARISH)
   {
      return AB_FindBearishMitigation(
         symbol,
         timeframe,
         lookback,
         out
      );
   }

   return false;
}

//-------------------------------------------------------------------
// Check whether price has mitigated the block
//-------------------------------------------------------------------
bool AB_CheckMitigation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   if(block.invalidated)
      return false;

   double currentBid = 0.0;
   double currentAsk = 0.0;

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   currentBid = tick.bid;
   currentAsk = tick.ask;

   double price =
      block.direction == ADV_DIRECTION_BULLISH
      ? currentAsk
      : currentBid;

   if(price <= 0.0)
      return false;

   if(AB_IsPriceInside(block,price))
   {
      block.mitigated = true;
      block.retested = true;
      block.fresh = false;

      return true;
   }

   return false;
}
//-------------------------------------------------------------------
// Find bullish displacement-origin block
//-------------------------------------------------------------------
bool AB_FindBullishDisplacementOrigin(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars < 10)
      return false;

   int maximum = MathMin(lookback,bars - 3);

   for(int shift = 1; shift <= maximum; shift++)
   {
      if(!AB_IsBullishCandle(symbol,timeframe,shift))
         continue;

      double range = AB_CandleRange(symbol,timeframe,shift);
      double bodyRatio =
         AB_BodyRatio(symbol,timeframe,shift);

      if(range <= 0.0)
         continue;

      // Displacement must have a strong body.
      if(bodyRatio < ICT_MIN_BODY_RATIO)
         continue;

      double open  = AB_Open(symbol,timeframe,shift);
      double close = AB_Close(symbol,timeframe,shift);
      double high  = AB_High(symbol,timeframe,shift);
      double low   = AB_Low(symbol,timeframe,shift);

      if(close <= open)
         continue;

      // The candle immediately before displacement is the
      // potential origin candle.
      int originShift = shift + 1;

      if(originShift >= bars)
         continue;

      double originHigh =
         AB_High(symbol,timeframe,originShift);

      double originLow =
         AB_Low(symbol,timeframe,originShift);

      if(originHigh <= originLow)
         continue;

      // Strong bullish displacement should close above
      // the previous candle's high.
      if(close <= originHigh)
         continue;

      AB_BuildFromCandle(
         symbol,
         timeframe,
         originShift,
         ADV_BLOCK_DISPLACEMENT_BULLISH,
         ADV_DIRECTION_BULLISH,
         out
      );

      if(!out.valid)
         continue;

      out.displacementShift = shift;
      out.displacementTime =
         AB_Time(symbol,timeframe,shift);

      out.displacementHigh = high;
      out.displacementLow = low;

      out.linkedToStructure = true;

      out.score += 20.0;

      if(bodyRatio >= 0.70)
         out.score += 10.0;

      out.reason =
         "Bullish displacement-origin zone detected.";

      out.evidence =
         "Strong bullish candle displaced above the origin candle.";

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Find bearish displacement-origin block
//-------------------------------------------------------------------
bool AB_FindBearishDisplacementOrigin(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars < 10)
      return false;

   int maximum = MathMin(lookback,bars - 3);

   for(int shift = 1; shift <= maximum; shift++)
   {
      if(!AB_IsBearishCandle(symbol,timeframe,shift))
         continue;

      double range = AB_CandleRange(symbol,timeframe,shift);
      double bodyRatio =
         AB_BodyRatio(symbol,timeframe,shift);

      if(range <= 0.0)
         continue;

      // Displacement must have a strong body.
      if(bodyRatio < ICT_MIN_BODY_RATIO)
         continue;

      double open  = AB_Open(symbol,timeframe,shift);
      double close = AB_Close(symbol,timeframe,shift);
      double high  = AB_High(symbol,timeframe,shift);
      double low   = AB_Low(symbol,timeframe,shift);

      if(close >= open)
         continue;

      // The candle immediately before displacement is the
      // potential origin candle.
      int originShift = shift + 1;

      if(originShift >= bars)
         continue;

      double originHigh =
         AB_High(symbol,timeframe,originShift);

      double originLow =
         AB_Low(symbol,timeframe,originShift);

      if(originHigh <= originLow)
         continue;

      // Strong bearish displacement should close below
      // the previous candle's low.
      if(close >= originLow)
         continue;

      AB_BuildFromCandle(
         symbol,
         timeframe,
         originShift,
         ADV_BLOCK_DISPLACEMENT_BEARISH,
         ADV_DIRECTION_BEARISH,
         out
      );

      if(!out.valid)
         continue;

      out.displacementShift = shift;
      out.displacementTime =
         AB_Time(symbol,timeframe,shift);

      out.displacementHigh = high;
      out.displacementLow = low;

      out.linkedToStructure = true;

      out.score += 20.0;

      if(bodyRatio >= 0.70)
         out.score += 10.0;

      out.reason =
         "Bearish displacement-origin zone detected.";

      out.evidence =
         "Strong bearish candle displaced below the origin candle.";

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Find directional displacement origin
//-------------------------------------------------------------------
bool AB_FindDisplacementOrigin(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const ENUM_ADVANCED_BLOCK_DIRECTION direction,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(direction == ADV_DIRECTION_BULLISH)
   {
      return AB_FindBullishDisplacementOrigin(
         symbol,
         timeframe,
         lookback,
         out
      );
   }

   if(direction == ADV_DIRECTION_BEARISH)
   {
      return AB_FindBearishDisplacementOrigin(
         symbol,
         timeframe,
         lookback,
         out
      );
   }

   return false;
}

//-------------------------------------------------------------------
// Check whether displacement was strong
//-------------------------------------------------------------------
bool AB_HasStrongDisplacement(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   if(block.displacementShift < 0)
      return false;

   double ratio =
      AB_BodyRatio(
         symbol,
         timeframe,
         block.displacementShift
      );

   return ratio >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Get block range
//-------------------------------------------------------------------
double AB_Range(const AdvancedBlock &block)
{
   if(!block.valid)
      return 0.0;

   if(block.upper <= block.lower)
      return 0.0;

   return block.upper - block.lower;
}

//-------------------------------------------------------------------
// Get block score
//-------------------------------------------------------------------
double AB_Score(const AdvancedBlock &block)
{
   if(!block.valid)
      return 0.0;

   return block.score;
}

//-------------------------------------------------------------------
// Check whether block is structurally usable
//-------------------------------------------------------------------
bool AB_IsStructurallyUsable(
   const AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   if(block.invalidated)
      return false;

   if(block.upper <= block.lower)
      return false;

   if(block.direction == ADV_DIRECTION_NONE)
      return false;

   return true;
}
//-------------------------------------------------------------------
// Link advanced block to an FVG
//-------------------------------------------------------------------
bool AB_LinkFVG(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   FVGZone fvg;
   ResetFVG(fvg);

   bool found = FindDirectionalFVG(
      symbol,
      timeframe,
      block.direction == ADV_DIRECTION_BULLISH,
      ICT_FVG_LOOKBACK,
      fvg
   );

   if(!found || !fvg.valid)
      return false;

   // Zones must overlap or be very close.
   bool overlap =
      (block.lower <= fvg.upper &&
       block.upper >= fvg.lower);

   if(!overlap)
      return false;

   block.linkedToFVG = true;
   block.score += 10.0;

   if(IsPriceInsideFVG(fvg,
                       block.midpoint))
   {
      block.score += 5.0;
   }

   return true;
}

//-------------------------------------------------------------------
// Link advanced block to an Order Block
//-------------------------------------------------------------------
bool AB_LinkOrderBlock(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   OrderBlock ob;
   ResetOrderBlock(ob);

   bool found = FindDirectionalOrderBlock(
      symbol,
      timeframe,
      block.direction == ADV_DIRECTION_BULLISH,
      ICT_OB_LOOKBACK,
      ob
   );

   if(!found || !ob.valid)
      return false;

   bool overlap =
      (block.lower <= ob.upper &&
       block.upper >= ob.lower);

   if(!overlap)
      return false;

   block.linkedToOrderBlock = true;
   block.score += 10.0;

   if(IsPriceInsideOrderBlock(ob,
                              block.midpoint))
   {
      block.score += 5.0;
   }

   return true;
}

//-------------------------------------------------------------------
// Link advanced block to liquidity
//-------------------------------------------------------------------
bool AB_LinkLiquidity(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   double tolerancePoints = 50.0;

   if(block.direction == ADV_DIRECTION_BULLISH)
   {
      LiquidityLevel sellLiquidity;

      if(FindNearestSellSideLiquidity(
            symbol,
            timeframe,
            block.lower,
            tolerancePoints,
            sellLiquidity))
      {
         block.linkedToLiquidity = true;
         block.score += 5.0;
         return true;
      }
   }

   if(block.direction == ADV_DIRECTION_BEARISH)
   {
      LiquidityLevel buyLiquidity;

      if(FindNearestBuySideLiquidity(
            symbol,
            timeframe,
            block.upper,
            tolerancePoints,
            buyLiquidity))
      {
         block.linkedToLiquidity = true;
         block.score += 5.0;
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Check block invalidation
//-------------------------------------------------------------------
bool AB_CheckInvalidation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   if(block.invalidated)
      return true;

   double close =
      AB_Close(symbol,timeframe,1);

   if(close <= 0.0)
      return false;

   // Bullish blocks are invalidated by a decisive close
   // below their lower boundary.
   if(block.direction == ADV_DIRECTION_BULLISH)
   {
      if(close < block.lower)
      {
         block.invalidated = true;
         block.fresh = false;
         return true;
      }
   }

   // Bearish blocks are invalidated by a decisive close
   // above their upper boundary.
   if(block.direction == ADV_DIRECTION_BEARISH)
   {
      if(close > block.upper)
      {
         block.invalidated = true;
         block.fresh = false;
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Check block retest
//-------------------------------------------------------------------
bool AB_CheckRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid || block.invalidated)
      return false;

   double high = AB_High(symbol,timeframe,1);
   double low  = AB_Low(symbol,timeframe,1);
   double close = AB_Close(symbol,timeframe,1);

   if(high <= 0.0 || low <= 0.0 || close <= 0.0)
      return false;

   bool touched =
      (low <= block.upper &&
       high >= block.lower);

   if(!touched)
      return false;

   if(block.direction == ADV_DIRECTION_BULLISH)
   {
      if(close >= block.midpoint)
      {
         block.retested = true;
         block.mitigated = true;
         block.fresh = false;
         block.score += 10.0;
         return true;
      }
   }

   if(block.direction == ADV_DIRECTION_BEARISH)
   {
      if(close <= block.midpoint)
      {
         block.retested = true;
         block.mitigated = true;
         block.fresh = false;
         block.score += 10.0;
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Refresh block state
//-------------------------------------------------------------------
void AB_RefreshState(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   AdvancedBlock &block)
{
   if(!block.valid)
      return;

   if(AB_CheckInvalidation(
         symbol,
         timeframe,
         block))
   {
      return;
   }

   AB_CheckRetest(
      symbol,
      timeframe,
      block
   );

   AB_CheckMitigation(
      symbol,
      timeframe,
      block
   );
}

//-------------------------------------------------------------------
// Build complete advanced block analysis
//-------------------------------------------------------------------
bool AB_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const ENUM_ADVANCED_BLOCK_DIRECTION direction,
   const int lookback,
   AdvancedBlock &out)
{
   ResetAdvancedBlock(out);

   if(!RE_IsGoldSymbol(symbol))
      return false;

   bool found = false;

   // Priority:
   // 1. Breaker
   // 2. Mitigation
   // 3. Displacement origin
   if(direction == ADV_DIRECTION_BULLISH)
   {
      if(ICT_ENABLE_BREAKER_BLOCK)
      {
         found = AB_FindBullishBreaker(
            symbol,
            timeframe,
            lookback,
            out
         );
      }

      if(!found && ICT_ENABLE_MITIGATION_BLOCK)
      {
         found = AB_FindBullishMitigation(
            symbol,
            timeframe,
            lookback,
            out
         );
      }

      if(!found)
      {
         found = AB_FindBullishDisplacementOrigin(
            symbol,
            timeframe,
            lookback,
            out
         );
      }
   }
   else if(direction == ADV_DIRECTION_BEARISH)
   {
      if(ICT_ENABLE_BREAKER_BLOCK)
      {
         found = AB_FindBearishBreaker(
            symbol,
            timeframe,
            lookback,
            out
         );
      }

      if(!found && ICT_ENABLE_MITIGATION_BLOCK)
      {
         found = AB_FindBearishMitigation(
            symbol,
            timeframe,
            lookback,
            out
         );
      }

      if(!found)
      {
         found = AB_FindBearishDisplacementOrigin(
            symbol,
            timeframe,
            lookback,
            out
         );
      }
   }

   if(!found || !out.valid)
      return false;

   AB_LinkFVG(
      symbol,
      timeframe,
      out
   );

   AB_LinkOrderBlock(
      symbol,
      timeframe,
      out
   );

   AB_LinkLiquidity(
      symbol,
      timeframe,
      out
   );

   AB_RefreshState(
      symbol,
      timeframe,
      out
   );

   return AB_IsStructurallyUsable(out);
}

//-------------------------------------------------------------------
// Direction string
//-------------------------------------------------------------------
string AB_DirectionToString(
   const ENUM_ADVANCED_BLOCK_DIRECTION direction)
{
   if(direction == ADV_DIRECTION_BULLISH)
      return "BULLISH";

   if(direction == ADV_DIRECTION_BEARISH)
      return "BEARISH";

   return "NONE";
}

//-------------------------------------------------------------------
// Type string
//-------------------------------------------------------------------
string AB_TypeToString(
   const ENUM_ADVANCED_BLOCK_TYPE type)
{
   switch(type)
   {
      case ADV_BLOCK_BREAKER_BULLISH:
         return "BULLISH BREAKER";

      case ADV_BLOCK_BREAKER_BEARISH:
         return "BEARISH BREAKER";

      case ADV_BLOCK_MITIGATION_BULLISH:
         return "BULLISH MITIGATION";

      case ADV_BLOCK_MITIGATION_BEARISH:
         return "BEARISH MITIGATION";

      case ADV_BLOCK_DISPLACEMENT_BULLISH:
         return "BULLISH DISPLACEMENT ORIGIN";

      case ADV_BLOCK_DISPLACEMENT_BEARISH:
         return "BEARISH DISPLACEMENT ORIGIN";
   }

   return "NONE";
}

//-------------------------------------------------------------------
// Advanced block description
//-------------------------------------------------------------------
string AB_Description(
   const AdvancedBlock &block)
{
   if(!block.valid)
      return "No advanced block.";

   string text =
      AB_TypeToString(block.type) +
      " | score=" +
      DoubleToString(block.score,1);

   if(block.mitigated)
      text += " | mitigated";

   if(block.retested)
      text += " | retested";

   if(block.invalidated)
      text += " | invalidated";

   if(block.linkedToFVG)
      text += " | FVG";

   if(block.linkedToOrderBlock)
      text += " | OB";

   if(block.linkedToLiquidity)
      text += " | liquidity";

   return text;
}

//-------------------------------------------------------------------
// Advanced block actionability
//-------------------------------------------------------------------
bool AB_IsActionable(
   const AdvancedBlock &block)
{
   if(!block.valid)
      return false;

   if(block.invalidated)
      return false;

   if(block.direction == ADV_DIRECTION_NONE)
      return false;

   // A block becomes significantly stronger when it has
   // at least one additional structural confluence.
   int confirmations = 0;

   if(block.linkedToFVG)
      confirmations++;

   if(block.linkedToOrderBlock)
      confirmations++;

   if(block.linkedToLiquidity)
      confirmations++;

   if(block.linkedToStructure)
      confirmations++;

   if(block.retested)
      confirmations++;

   return confirmations >= 2;
}

//-------------------------------------------------------------------
// Print advanced block
//-------------------------------------------------------------------
void AB_Print(
   const AdvancedBlock &block)
{
   if(!block.valid)
   {
      Print("AdvancedBlocks: no valid block.");
      return;
   }

   Print(
      "AdvancedBlocks: ",
      AB_Description(block),
      " | zone=",
      DoubleToString(block.lower,_Digits),
      "-",
      DoubleToString(block.upper,_Digits),
      " | direction=",
      AB_DirectionToString(block.direction),
      " | actionable=",
      AB_IsActionable(block) ? "YES" : "NO"
   );
}

#endif
//+------------------------------------------------------------------+
//| ReversalEngine.mqh                                               |
//| Gold Multi-Strategy EA - Reversal Analysis                       |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_REVERSAL_ENGINE_MQH__
#define __EXNESS_GOLD_REVERSAL_ENGINE_MQH__

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "MarketStructure.mqh"
#include "StructureSignal.mqh"
#include "Liquidity.mqh"
#include "FVG.mqh"
#include "OrderBlock.mqh"

//-------------------------------------------------------------------
// Reversal type
//-------------------------------------------------------------------
enum ENUM_REVERSAL_TYPE
{
   REVERSAL_NONE = 0,
   REVERSAL_LIQUIDITY_SWEEP,
   REVERSAL_FAILED_BREAKOUT,
   REVERSAL_REJECTION,
   REVERSAL_EXHAUSTION,
   REVERSAL_STRUCTURE_SHIFT,
   REVERSAL_FVG_REACTION,
   REVERSAL_ORDER_BLOCK_REACTION
};

//-------------------------------------------------------------------
// Reversal direction
//-------------------------------------------------------------------
enum ENUM_REVERSAL_DIRECTION
{
   REVERSAL_DIRECTION_NONE = 0,
   REVERSAL_DIRECTION_BULLISH,
   REVERSAL_DIRECTION_BEARISH
};

//-------------------------------------------------------------------
// Reversal analysis
//-------------------------------------------------------------------
struct ReversalAnalysis
{
   bool valid;
   bool goldSafe;

   ENUM_REVERSAL_TYPE primaryType;
   ENUM_REVERSAL_DIRECTION direction;

   bool liquiditySweep;
   bool buySideSweep;
   bool sellSideSweep;

   bool failedBreakout;
   bool bullishFailedBreakout;
   bool bearishFailedBreakout;

   bool rejection;
   bool bullishRejection;
   bool bearishRejection;

   bool exhaustion;
   bool bullishExhaustion;
   bool bearishExhaustion;

   bool structureShift;
   bool bullishMSS;
   bool bearishMSS;
   bool bullishCHoCH;
   bool bearishCHoCH;

   bool fvgReaction;
   bool orderBlockReaction;

   bool premiumContext;
   bool discountContext;

   double liquidityPrice;
   double reversalLevel;
   double entryZoneLow;
   double entryZoneHigh;

   double score;

   datetime signalTime;
   int signalShift;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset
//-------------------------------------------------------------------
void ResetReversalAnalysis(
   ReversalAnalysis &r)
{
   r.valid = false;
   r.goldSafe = false;

   r.primaryType = REVERSAL_NONE;
   r.direction = REVERSAL_DIRECTION_NONE;

   r.liquiditySweep = false;
   r.buySideSweep = false;
   r.sellSideSweep = false;

   r.failedBreakout = false;
   r.bullishFailedBreakout = false;
   r.bearishFailedBreakout = false;

   r.rejection = false;
   r.bullishRejection = false;
   r.bearishRejection = false;

   r.exhaustion = false;
   r.bullishExhaustion = false;
   r.bearishExhaustion = false;

   r.structureShift = false;
   r.bullishMSS = false;
   r.bearishMSS = false;
   r.bullishCHoCH = false;
   r.bearishCHoCH = false;

   r.fvgReaction = false;
   r.orderBlockReaction = false;

   r.premiumContext = false;
   r.discountContext = false;

   r.liquidityPrice = 0.0;
   r.reversalLevel = 0.0;
   r.entryZoneLow = 0.0;
   r.entryZoneHigh = 0.0;

   r.score = 0.0;

   r.signalTime = 0;
   r.signalShift = -1;

   r.reason = "";
   r.evidence = "";
}

//-------------------------------------------------------------------
// Gold validation
//-------------------------------------------------------------------
bool RV_IsGold(
   const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//-------------------------------------------------------------------
// Reversal type string
//-------------------------------------------------------------------
string RV_TypeToString(
   const ENUM_REVERSAL_TYPE type)
{
   switch(type)
   {
      case REVERSAL_LIQUIDITY_SWEEP:
         return "LIQUIDITY SWEEP";

      case REVERSAL_FAILED_BREAKOUT:
         return "FAILED BREAKOUT";

      case REVERSAL_REJECTION:
         return "REJECTION";

      case REVERSAL_EXHAUSTION:
         return "EXHAUSTION";

      case REVERSAL_STRUCTURE_SHIFT:
         return "STRUCTURE SHIFT";

      case REVERSAL_FVG_REACTION:
         return "FVG REACTION";

      case REVERSAL_ORDER_BLOCK_REACTION:
         return "ORDER BLOCK REACTION";

      default:
         return "NONE";
   }
}

//-------------------------------------------------------------------
// Direction string
//-------------------------------------------------------------------
string RV_DirectionToString(
   const ENUM_REVERSAL_DIRECTION direction)
{
   if(direction == REVERSAL_DIRECTION_BULLISH)
      return "BULLISH";

   if(direction == REVERSAL_DIRECTION_BEARISH)
      return "BEARISH";

   return "NONE";
}

//-------------------------------------------------------------------
// Candle access
//-------------------------------------------------------------------
double RV_Open(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iOpen(
      symbol,
      timeframe,
      shift);
}

//-------------------------------------------------------------------
double RV_Close(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iClose(
      symbol,
      timeframe,
      shift);
}

//-------------------------------------------------------------------
double RV_High(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iHigh(
      symbol,
      timeframe,
      shift);
}

//-------------------------------------------------------------------
double RV_Low(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iLow(
      symbol,
      timeframe,
      shift);
}

//-------------------------------------------------------------------
datetime RV_Time(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iTime(
      symbol,
      timeframe,
      shift);
}

//-------------------------------------------------------------------
// Candle range
//-------------------------------------------------------------------
double RV_Range(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high =
      RV_High(
         symbol,
         timeframe,
         shift);

   double low =
      RV_Low(
         symbol,
         timeframe,
         shift);

   if(high <= 0.0 ||
      low <= 0.0 ||
      high < low)
   {
      return 0.0;
   }

   return high - low;
}

//-------------------------------------------------------------------
// Candle body
//-------------------------------------------------------------------
double RV_Body(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open =
      RV_Open(
         symbol,
         timeframe,
         shift);

   double close =
      RV_Close(
         symbol,
         timeframe,
         shift);

   if(open <= 0.0 ||
      close <= 0.0)
   {
      return 0.0;
   }

   return MathAbs(close - open);
}

//-------------------------------------------------------------------
// Body ratio
//-------------------------------------------------------------------
double RV_BodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range =
      RV_Range(
         symbol,
         timeframe,
         shift);

   if(range <= 0.0)
      return 0.0;

   return RV_Body(
             symbol,
             timeframe,
             shift) / range;
}

//-------------------------------------------------------------------
// Bullish candle
//-------------------------------------------------------------------
bool RV_BullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return RV_Close(symbol,timeframe,shift)
          >
          RV_Open(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Bearish candle
//-------------------------------------------------------------------
bool RV_BearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return RV_Close(symbol,timeframe,shift)
          <
          RV_Open(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Upper wick
//-------------------------------------------------------------------
double RV_UpperWick(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high =
      RV_High(symbol,timeframe,shift);

   double open =
      RV_Open(symbol,timeframe,shift);

   double close =
      RV_Close(symbol,timeframe,shift);

   return high -
          MathMax(open,close);
}

//-------------------------------------------------------------------
// Lower wick
//-------------------------------------------------------------------
double RV_LowerWick(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double low =
      RV_Low(symbol,timeframe,shift);

   double open =
      RV_Open(symbol,timeframe,shift);

   double close =
      RV_Close(symbol,timeframe,shift);

   return MathMin(open,close) -
          low;
}

//-------------------------------------------------------------------
// Strong rejection candle
//-------------------------------------------------------------------
bool RV_IsRejectionCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double body =
      RV_Body(symbol,timeframe,shift);

   double range =
      RV_Range(symbol,timeframe,shift);

   if(body <= 0.0 ||
      range <= 0.0)
   {
      return false;
   }

   double upper =
      RV_UpperWick(symbol,timeframe,shift);

   double lower =
      RV_LowerWick(symbol,timeframe,shift);

   return upper >= body * 1.5 ||
          lower >= body * 1.5;
}

//-------------------------------------------------------------------
// Strong bullish rejection
//-------------------------------------------------------------------
bool RV_BullishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!RV_IsRejectionCandle(
         symbol,
         timeframe,
         shift))
   {
      return false;
   }

   double lower =
      RV_LowerWick(
         symbol,
         timeframe,
         shift);

   double upper =
      RV_UpperWick(
         symbol,
         timeframe,
         shift);

   return RV_BullishCandle(
            symbol,
            timeframe,
            shift)
          &&
          lower > upper;
}

//-------------------------------------------------------------------
// Strong bearish rejection
//-------------------------------------------------------------------
bool RV_BearishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!RV_IsRejectionCandle(
         symbol,
         timeframe,
         shift))
   {
      return false;
   }

   double lower =
      RV_LowerWick(
         symbol,
         timeframe,
         shift);

   double upper =
      RV_UpperWick(
         symbol,
         timeframe,
         shift);

   return RV_BearishCandle(
            symbol,
            timeframe,
            shift)
          &&
          upper > lower;
}
//-------------------------------------------------------------------
// Detect bullish exhaustion
//-------------------------------------------------------------------
bool RV_BullishExhaustion(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double range =
      RV_Range(
         symbol,
         timeframe,
         1);

   double body =
      RV_Body(
         symbol,
         timeframe,
         1);

   double upper =
      RV_UpperWick(
         symbol,
         timeframe,
         1);

   if(range <= 0.0 ||
      body <= 0.0)
   {
      return false;
   }

   return RV_BullishCandle(
            symbol,
            timeframe,
            1)
          &&
          upper >= body * 1.5;
}

//-------------------------------------------------------------------
// Detect bearish exhaustion
//-------------------------------------------------------------------
bool RV_BearishExhaustion(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double range =
      RV_Range(
         symbol,
         timeframe,
         1);

   double body =
      RV_Body(
         symbol,
         timeframe,
         1);

   double lower =
      RV_LowerWick(
         symbol,
         timeframe,
         1);

   if(range <= 0.0 ||
      body <= 0.0)
   {
      return false;
   }

   return RV_BearishCandle(
            symbol,
            timeframe,
            1)
          &&
          lower >= body * 1.5;
}

//-------------------------------------------------------------------
// Detect bullish engulfing
//-------------------------------------------------------------------
bool RV_BullishEngulfing(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!RV_BullishCandle(
         symbol,
         timeframe,
         1))
   {
      return false;
   }

   if(!RV_BearishCandle(
         symbol,
         timeframe,
         2))
   {
      return false;
   }

   double currentOpen =
      RV_Open(symbol,timeframe,1);

   double currentClose =
      RV_Close(symbol,timeframe,1);

   double previousOpen =
      RV_Open(symbol,timeframe,2);

   double previousClose =
      RV_Close(symbol,timeframe,2);

   return currentOpen <= previousClose &&
          currentClose >= previousOpen;
}

//-------------------------------------------------------------------
// Detect bearish engulfing
//-------------------------------------------------------------------
bool RV_BearishEngulfing(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!RV_BearishCandle(
         symbol,
         timeframe,
         1))
   {
      return false;
   }

   if(!RV_BullishCandle(
         symbol,
         timeframe,
         2))
   {
      return false;
   }

   double currentOpen =
      RV_Open(symbol,timeframe,1);

   double currentClose =
      RV_Close(symbol,timeframe,1);

   double previousOpen =
      RV_Open(symbol,timeframe,2);

   double previousClose =
      RV_Close(symbol,timeframe,2);

   return currentOpen >= previousClose &&
          currentClose <= previousOpen;
}

//-------------------------------------------------------------------
// Detect liquidity sweep
//-------------------------------------------------------------------
bool RV_DetectLiquiditySweep(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   ReversalAnalysis &out)
{
   LiquiditySweep sweep;

   ResetLiquiditySweep(sweep);

   if(!DetectLiquiditySweep(
         symbol,
         timeframe,
         1,
         ICT_STRUCTURE_LOOKBACK,
         sweep))
   {
      return false;
   }

   if(!sweep.valid)
      return false;

   out.liquiditySweep = true;

   out.buySideSweep =
      IsBuySideSweep(sweep);

   out.sellSideSweep =
      IsSellSideSweep(sweep);

   out.liquidityPrice =
      sweep.level.price;

   if(out.sellSideSweep)
   {
      out.direction =
         REVERSAL_DIRECTION_BULLISH;

      out.reversalLevel =
         sweep.level.price;
   }
   else if(out.buySideSweep)
   {
      out.direction =
         REVERSAL_DIRECTION_BEARISH;

      out.reversalLevel =
         sweep.level.price;
   }

   return true;
}

//-------------------------------------------------------------------
// Detect bullish failed breakout
//-------------------------------------------------------------------
bool RV_BullishFailedBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentLow =
      GetRecentSwingLowPrice(
         symbol,
         timeframe);

   if(recentLow <= 0.0)
      return false;

   double low =
      RV_Low(
         symbol,
         timeframe,
         1);

   double close =
      RV_Close(
         symbol,
         timeframe,
         1);

   return low < recentLow &&
          close > recentLow;
}

//-------------------------------------------------------------------
// Detect bearish failed breakout
//-------------------------------------------------------------------
bool RV_BearishFailedBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentHigh =
      GetRecentSwingHighPrice(
         symbol,
         timeframe);

   if(recentHigh <= 0.0)
      return false;

   double high =
      RV_High(
         symbol,
         timeframe,
         1);

   double close =
      RV_Close(
         symbol,
         timeframe,
         1);

   return high > recentHigh &&
          close < recentHigh;
}

//-------------------------------------------------------------------
// Detect failed breakout
//-------------------------------------------------------------------
bool RV_DetectFailedBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   ReversalAnalysis &out)
{
   bool bullish =
      RV_BullishFailedBreakout(
         symbol,
         timeframe);

   bool bearish =
      RV_BearishFailedBreakout(
         symbol,
         timeframe);

   if(!bullish && !bearish)
      return false;

   out.failedBreakout = true;

   out.bullishFailedBreakout = bullish;
   out.bearishFailedBreakout = bearish;

   if(bullish && !bearish)
   {
      out.direction =
         REVERSAL_DIRECTION_BULLISH;

      out.reversalLevel =
         GetRecentSwingLowPrice(
            symbol,
            timeframe);
   }

   if(bearish && !bullish)
   {
      out.direction =
         REVERSAL_DIRECTION_BEARISH;

      out.reversalLevel =
         GetRecentSwingHighPrice(
            symbol,
            timeframe);
   }

   return true;
}

//-------------------------------------------------------------------
// Detect structure shift
//-------------------------------------------------------------------
bool RV_DetectStructureShift(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   ReversalAnalysis &out)
{
   StructureSignal signal;

   ResetStructureSignal(signal);

   if(!AnalyzeStructureSignal(
         symbol,
         timeframe,
         1,
         ICT_STRUCTURE_LOOKBACK,
         signal))
   {
      return false;
   }

   if(!signal.valid)
      return false;

   out.bullishMSS =
      signal.bullishMSS;

   out.bearishMSS =
      signal.bearishMSS;

   out.structureShift =
      signal.bullishMSS ||
      signal.bearishMSS;

   if(out.bullishMSS)
   {
      out.direction =
         REVERSAL_DIRECTION_BULLISH;

      out.reversalLevel =
         signal.brokenLevel;
   }

   if(out.bearishMSS)
   {
      out.direction =
         REVERSAL_DIRECTION_BEARISH;

      out.reversalLevel =
         signal.brokenLevel;
   }

   return out.structureShift;
}

//-------------------------------------------------------------------
// Detect FVG reaction
//-------------------------------------------------------------------
bool RV_DetectFVGReaction(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   ReversalAnalysis &out)
{
   FVGZone bullishFVG;
   FVGZone bearishFVG;

   ResetFVG(bullishFVG);
   ResetFVG(bearishFVG);

   bool foundBullish =
      FindRecentBullishFVG(
         symbol,
         timeframe,
         ICT_FVG_LOOKBACK,
         bullishFVG);

   bool foundBearish =
      FindRecentBearishFVG(
         symbol,
         timeframe,
         ICT_FVG_LOOKBACK,
         bearishFVG);

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   double price =
      (tick.bid + tick.ask) * 0.5;

   if(foundBullish &&
      IsPriceInsideFVG(
         bullishFVG,
         price))
   {
      out.fvgReaction = true;

      if(out.direction ==
         REVERSAL_DIRECTION_NONE)
      {
         out.direction =
            REVERSAL_DIRECTION_BULLISH;
      }

      out.entryZoneLow =
         bullishFVG.lower;

      out.entryZoneHigh =
         bullishFVG.upper;

      return true;
   }

   if(foundBearish &&
      IsPriceInsideFVG(
         bearishFVG,
         price))
   {
      out.fvgReaction = true;

      if(out.direction ==
         REVERSAL_DIRECTION_NONE)
      {
         out.direction =
            REVERSAL_DIRECTION_BEARISH;
      }

      out.entryZoneLow =
         bearishFVG.lower;

      out.entryZoneHigh =
         bearishFVG.upper;

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect Order Block reaction
//-------------------------------------------------------------------
bool RV_DetectOrderBlockReaction(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   ReversalAnalysis &out)
{
   OrderBlock bullishOB;
   OrderBlock bearishOB;

   ResetOrderBlock(bullishOB);
   ResetOrderBlock(bearishOB);

   bool foundBullish =
      FindBullishOrderBlock(
         symbol,
         timeframe,
         ICT_OB_LOOKBACK,
         bullishOB);

   bool foundBearish =
      FindBearishOrderBlock(
         symbol,
         timeframe,
         ICT_OB_LOOKBACK,
         bearishOB);

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   double price =
      (tick.bid + tick.ask) * 0.5;

   if(foundBullish &&
      IsPriceInsideOrderBlock(
         bullishOB,
         price))
   {
      out.orderBlockReaction = true;

      if(out.direction ==
         REVERSAL_DIRECTION_NONE)
      {
         out.direction =
            REVERSAL_DIRECTION_BULLISH;
      }

      out.entryZoneLow =
         bullishOB.lower;

      out.entryZoneHigh =
         bullishOB.upper;

      return true;
   }

   if(foundBearish &&
      IsPriceInsideOrderBlock(
         bearishOB,
         price))
   {
      out.orderBlockReaction = true;

      if(out.direction ==
         REVERSAL_DIRECTION_NONE)
      {
         out.direction =
            REVERSAL_DIRECTION_BEARISH;
      }

      out.entryZoneLow =
         bearishOB.lower;

      out.entryZoneHigh =
         bearishOB.upper;

      return true;
   }

   return false;
}
//-------------------------------------------------------------------
// Determine reversal type
//-------------------------------------------------------------------
ENUM_REVERSAL_TYPE RV_DeterminePrimaryType(
   const ReversalAnalysis &r)
{
   // Liquidity sweep gets highest priority because it is
   // the main reversal trigger in the ICT/SMC framework.
   if(r.liquiditySweep)
      return REVERSAL_LIQUIDITY_SWEEP;

   if(r.failedBreakout)
      return REVERSAL_FAILED_BREAKOUT;

   if(r.structureShift)
      return REVERSAL_STRUCTURE_SHIFT;

   if(r.orderBlockReaction)
      return REVERSAL_ORDER_BLOCK_REACTION;

   if(r.fvgReaction)
      return REVERSAL_FVG_REACTION;

   if(r.rejection)
      return REVERSAL_REJECTION;

   if(r.exhaustion)
      return REVERSAL_EXHAUSTION;

   return REVERSAL_NONE;
}

//-------------------------------------------------------------------
// Determine reversal direction from evidence
//-------------------------------------------------------------------
ENUM_REVERSAL_DIRECTION RV_DetermineDirection(
   const ReversalAnalysis &r)
{
   double bullishScore = 0.0;
   double bearishScore = 0.0;

   if(r.sellSideSweep)
      bullishScore += 25.0;

   if(r.buySideSweep)
      bearishScore += 25.0;

   if(r.bullishFailedBreakout)
      bullishScore += 20.0;

   if(r.bearishFailedBreakout)
      bearishScore += 20.0;

   if(r.bullishMSS || r.bullishCHoCH)
      bullishScore += 25.0;

   if(r.bearishMSS || r.bearishCHoCH)
      bearishScore += 25.0;

   if(r.bullishRejection)
      bullishScore += 10.0;

   if(r.bearishRejection)
      bearishScore += 10.0;

   if(r.bullishExhaustion)
      bearishScore += 10.0;

   if(r.bearishExhaustion)
      bullishScore += 10.0;

   if(r.fvgReaction)
   {
      if(r.direction == REVERSAL_DIRECTION_BULLISH)
         bullishScore += 5.0;

      if(r.direction == REVERSAL_DIRECTION_BEARISH)
         bearishScore += 5.0;
   }

   if(r.orderBlockReaction)
   {
      if(r.direction == REVERSAL_DIRECTION_BULLISH)
         bullishScore += 5.0;

      if(r.direction == REVERSAL_DIRECTION_BEARISH)
         bearishScore += 5.0;
   }

   if(bullishScore > bearishScore &&
      bullishScore >= 25.0)
   {
      return REVERSAL_DIRECTION_BULLISH;
   }

   if(bearishScore > bullishScore &&
      bearishScore >= 25.0)
   {
      return REVERSAL_DIRECTION_BEARISH;
   }

   return REVERSAL_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Calculate reversal score
//-------------------------------------------------------------------
double RV_CalculateScore(
   const ReversalAnalysis &r)
{
   double score = 0.0;

   if(r.liquiditySweep)
      score += 20.0;

   if(r.sellSideSweep &&
      r.direction == REVERSAL_DIRECTION_BULLISH)
   {
      score += 10.0;
   }

   if(r.buySideSweep &&
      r.direction == REVERSAL_DIRECTION_BEARISH)
   {
      score += 10.0;
   }

   if(r.failedBreakout)
      score += 15.0;

   if(r.structureShift)
      score += 20.0;

   if(r.bullishMSS ||
      r.bearishMSS)
   {
      score += 5.0;
   }

   if(r.rejection)
      score += 10.0;

   if(r.exhaustion)
      score += 10.0;

   if(r.fvgReaction)
      score += 5.0;

   if(r.orderBlockReaction)
      score += 5.0;

   if(r.premiumContext ||
      r.discountContext)
   {
      score += 5.0;
   }

   return MathMin(score,100.0);
}

//-------------------------------------------------------------------
// Build reversal evidence
//-------------------------------------------------------------------
void RV_BuildEvidence(
   ReversalAnalysis &r)
{
   r.evidence = "";

   if(r.sellSideSweep)
      r.evidence += "Sell-side liquidity swept; ";

   if(r.buySideSweep)
      r.evidence += "Buy-side liquidity swept; ";

   if(r.bullishFailedBreakout)
      r.evidence += "Bullish failed breakout; ";

   if(r.bearishFailedBreakout)
      r.evidence += "Bearish failed breakout; ";

   if(r.bullishMSS)
      r.evidence += "Bullish MSS; ";

   if(r.bearishMSS)
      r.evidence += "Bearish MSS; ";

   if(r.bullishCHoCH)
      r.evidence += "Bullish CHoCH; ";

   if(r.bearishCHoCH)
      r.evidence += "Bearish CHoCH; ";

   if(r.bullishRejection)
      r.evidence += "Bullish rejection; ";

   if(r.bearishRejection)
      r.evidence += "Bearish rejection; ";

   if(r.bullishExhaustion)
      r.evidence += "Bullish exhaustion; ";

   if(r.bearishExhaustion)
      r.evidence += "Bearish exhaustion; ";

   if(r.fvgReaction)
      r.evidence += "FVG reaction; ";

   if(r.orderBlockReaction)
      r.evidence += "Order Block reaction; ";

   if(r.premiumContext)
      r.evidence += "Premium context; ";

   if(r.discountContext)
      r.evidence += "Discount context; ";
}

//-------------------------------------------------------------------
// Build reversal reason
//-------------------------------------------------------------------
void RV_BuildReason(
   ReversalAnalysis &r)
{
   r.reason =
      "Type=" +
      RV_TypeToString(
         r.primaryType) +
      " | Direction=" +
      RV_DirectionToString(
         r.direction) +
      " | Score=" +
      DoubleToString(
         r.score,
         1);
}

//-------------------------------------------------------------------
// Analyze reversal on one timeframe
//-------------------------------------------------------------------
bool RV_AnalyzeTimeframe(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   ReversalAnalysis &out)
{
   ResetReversalAnalysis(out);

   if(!RV_IsGold(symbol))
   {
      out.reason =
         "Non-gold symbol rejected.";

      return false;
   }

   int bars =
      Bars(
         symbol,
         timeframe);

   if(bars < ICT_MIN_HISTORY_BARS)
   {
      out.reason =
         "Insufficient history.";

      return false;
   }

   out.goldSafe = true;

   //----------------------------------------------------------------
   // Liquidity
   //----------------------------------------------------------------
   RV_DetectLiquiditySweep(
      symbol,
      timeframe,
      out);

   //----------------------------------------------------------------
   // Failed breakout
   //----------------------------------------------------------------
   RV_DetectFailedBreakout(
      symbol,
      timeframe,
      out);

   //----------------------------------------------------------------
   // Structure shift
   //----------------------------------------------------------------
   RV_DetectStructureShift(
      symbol,
      timeframe,
      out);

   //----------------------------------------------------------------
   // Rejection
   //----------------------------------------------------------------
   out.bullishRejection =
      RV_BullishRejection(
         symbol,
         timeframe,
         1);

   out.bearishRejection =
      RV_BearishRejection(
         symbol,
         timeframe,
         1);

   out.rejection =
      out.bullishRejection ||
      out.bearishRejection;

   //----------------------------------------------------------------
   // Exhaustion
   //----------------------------------------------------------------
   out.bullishExhaustion =
      RV_BullishExhaustion(
         symbol,
         timeframe);

   out.bearishExhaustion =
      RV_BearishExhaustion(
         symbol,
         timeframe);

   out.exhaustion =
      out.bullishExhaustion ||
      out.bearishExhaustion;

   //----------------------------------------------------------------
   // FVG reaction
   //----------------------------------------------------------------
   RV_DetectFVGReaction(
      symbol,
      timeframe,
      out);

   //----------------------------------------------------------------
   // Order Block reaction
   //----------------------------------------------------------------
   RV_DetectOrderBlockReaction(
      symbol,
      timeframe,
      out);

   //----------------------------------------------------------------
   // Final direction
   //----------------------------------------------------------------
   ENUM_REVERSAL_DIRECTION detectedDirection =
      RV_DetermineDirection(out);

   if(detectedDirection !=
      REVERSAL_DIRECTION_NONE)
   {
      out.direction =
         detectedDirection;
   }

   //----------------------------------------------------------------
   // Primary type
   //----------------------------------------------------------------
   out.primaryType =
      RV_DeterminePrimaryType(out);

   //----------------------------------------------------------------
   // Score
   //----------------------------------------------------------------
   out.score =
      RV_CalculateScore(out);

   out.signalShift = 1;

   out.signalTime =
      RV_Time(
         symbol,
         timeframe,
         1);

   //----------------------------------------------------------------
   // Reversal level fallback
   //----------------------------------------------------------------
   if(out.reversalLevel <= 0.0)
   {
      if(out.direction ==
         REVERSAL_DIRECTION_BULLISH)
      {
         out.reversalLevel =
            RV_Low(
               symbol,
               timeframe,
               1);
      }
      else if(out.direction ==
              REVERSAL_DIRECTION_BEARISH)
      {
         out.reversalLevel =
            RV_High(
               symbol,
               timeframe,
               1);
      }
   }

   //----------------------------------------------------------------
   // Evidence
   //----------------------------------------------------------------
   RV_BuildEvidence(out);

   RV_BuildReason(out);

   //----------------------------------------------------------------
   // Minimum structural validity
   //----------------------------------------------------------------
   out.valid =
      out.goldSafe &&
      out.direction !=
         REVERSAL_DIRECTION_NONE &&
      out.primaryType !=
         REVERSAL_NONE &&
      out.score >= 40.0;

   return out.valid;
}

//-------------------------------------------------------------------
// Analyze current gold reversal
//-------------------------------------------------------------------
bool RV_AnalyzeGold(
   const string symbol,
   ReversalAnalysis &out)
{
   return RV_AnalyzeTimeframe(
      symbol,
      ICT_PRIMARY_TF,
      out);
}
//-------------------------------------------------------------------
// Bullish reversal permission
//-------------------------------------------------------------------
bool RV_BullishPermission(
   const ReversalAnalysis &r)
{
   if(!r.valid)
      return false;

   if(r.direction !=
      REVERSAL_DIRECTION_BULLISH)
   {
      return false;
   }

   // A high-quality bullish reversal should have
   // at least one major structural/reversal trigger.
   bool majorTrigger =
      r.sellSideSweep ||
      r.bullishFailedBreakout ||
      r.bullishMSS ||
      r.bullishCHoCH;

   if(!majorTrigger)
      return false;

   return r.score >= 50.0;
}

//-------------------------------------------------------------------
// Bearish reversal permission
//-------------------------------------------------------------------
bool RV_BearishPermission(
   const ReversalAnalysis &r)
{
   if(!r.valid)
      return false;

   if(r.direction !=
      REVERSAL_DIRECTION_BEARISH)
   {
      return false;
   }

   bool majorTrigger =
      r.buySideSweep ||
      r.bearishFailedBreakout ||
      r.bearishMSS ||
      r.bearishCHoCH;

   if(!majorTrigger)
      return false;

   return r.score >= 50.0;
}

//-------------------------------------------------------------------
// Multi-timeframe bullish reversal alignment
//-------------------------------------------------------------------
bool RV_BullishMTFAlignment(
   const string symbol,
   ReversalAnalysis &h4,
   ReversalAnalysis &h1,
   ReversalAnalysis &m15)
{
   if(!RV_AnalyzeTimeframe(
         symbol,
         PERIOD_H4,
         h4))
   {
      return false;
   }

   if(!RV_AnalyzeTimeframe(
         symbol,
         PERIOD_H1,
         h1))
   {
      return false;
   }

   if(!RV_AnalyzeTimeframe(
         symbol,
         PERIOD_M15,
         m15))
   {
      return false;
   }

   if(!RV_BullishPermission(h4) &&
      !RV_BullishPermission(h1) &&
      !RV_BullishPermission(m15))
   {
      return false;
   }

   int confirmations = 0;

   if(RV_BullishPermission(h4))
      confirmations++;

   if(RV_BullishPermission(h1))
      confirmations++;

   if(RV_BullishPermission(m15))
      confirmations++;

   return confirmations >= 2;
}

//-------------------------------------------------------------------
// Multi-timeframe bearish reversal alignment
//-------------------------------------------------------------------
bool RV_BearishMTFAlignment(
   const string symbol,
   ReversalAnalysis &h4,
   ReversalAnalysis &h1,
   ReversalAnalysis &m15)
{
   if(!RV_AnalyzeTimeframe(
         symbol,
         PERIOD_H4,
         h4))
   {
      return false;
   }

   if(!RV_AnalyzeTimeframe(
         symbol,
         PERIOD_H1,
         h1))
   {
      return false;
   }

   if(!RV_AnalyzeTimeframe(
         symbol,
         PERIOD_M15,
         m15))
   {
      return false;
   }

   if(!RV_BearishPermission(h4) &&
      !RV_BearishPermission(h1) &&
      !RV_BearishPermission(m15))
   {
      return false;
   }

   int confirmations = 0;

   if(RV_BearishPermission(h4))
      confirmations++;

   if(RV_BearishPermission(h1))
      confirmations++;

   if(RV_BearishPermission(m15))
      confirmations++;

   return confirmations >= 2;
}

//-------------------------------------------------------------------
// Multi-timeframe reversal score
//-------------------------------------------------------------------
double RV_MTFScore(
   const ReversalAnalysis &h4,
   const ReversalAnalysis &h1,
   const ReversalAnalysis &m15)
{
   double score = 0.0;

   if(h4.valid)
      score += MathMin(h4.score,40.0);

   if(h1.valid)
      score += MathMin(h1.score,30.0);

   if(m15.valid)
      score += MathMin(m15.score,30.0);

   return MathMin(score,100.0);
}

//-------------------------------------------------------------------
// Dominant reversal direction
//-------------------------------------------------------------------
ENUM_REVERSAL_DIRECTION RV_DominantDirection(
   const ReversalAnalysis &h4,
   const ReversalAnalysis &h1,
   const ReversalAnalysis &m15)
{
   double bullish = 0.0;
   double bearish = 0.0;

   if(h4.valid)
   {
      if(h4.direction ==
         REVERSAL_DIRECTION_BULLISH)
         bullish += h4.score;

      if(h4.direction ==
         REVERSAL_DIRECTION_BEARISH)
         bearish += h4.score;
   }

   if(h1.valid)
   {
      if(h1.direction ==
         REVERSAL_DIRECTION_BULLISH)
         bullish += h1.score;

      if(h1.direction ==
         REVERSAL_DIRECTION_BEARISH)
         bearish += h1.score;
   }

   if(m15.valid)
   {
      if(m15.direction ==
         REVERSAL_DIRECTION_BULLISH)
         bullish += m15.score;

      if(m15.direction ==
         REVERSAL_DIRECTION_BEARISH)
         bearish += m15.score;
   }

   if(bullish > bearish &&
      bullish >= 60.0)
   {
      return REVERSAL_DIRECTION_BULLISH;
   }

   if(bearish > bullish &&
      bearish >= 60.0)
   {
      return REVERSAL_DIRECTION_BEARISH;
   }

   return REVERSAL_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Reversal ready for confluence
//-------------------------------------------------------------------
bool RV_ReadyForConfluence(
   const ReversalAnalysis &h4,
   const ReversalAnalysis &h1,
   const ReversalAnalysis &m15)
{
   ENUM_REVERSAL_DIRECTION direction =
      RV_DominantDirection(
         h4,
         h1,
         m15);

   if(direction ==
      REVERSAL_DIRECTION_NONE)
   {
      return false;
   }

   double score =
      RV_MTFScore(
         h4,
         h1,
         m15);

   return score >= 60.0;
}

//-------------------------------------------------------------------
// Reversal description
//-------------------------------------------------------------------
string RV_Description(
   const ReversalAnalysis &r)
{
   string text =
      "Type=" +
      RV_TypeToString(
         r.primaryType) +
      " | Direction=" +
      RV_DirectionToString(
         r.direction) +
      " | Score=" +
      DoubleToString(
         r.score,
         1);

   if(r.evidence != "")
      text +=
         " | " +
         r.evidence;

   return text;
}

//-------------------------------------------------------------------
// Print reversal analysis
//-------------------------------------------------------------------
void RV_PrintAnalysis(
   const string label,
   const ReversalAnalysis &r)
{
   Print(
      "[ReversalEngine] ",
      label,
      " | ",
      RV_Description(r)
   );
}

//-------------------------------------------------------------------
// Print multi-timeframe reversal state
//-------------------------------------------------------------------
void RV_PrintMultiTimeframe(
   const ReversalAnalysis &h4,
   const ReversalAnalysis &h1,
   const ReversalAnalysis &m15)
{
   RV_PrintAnalysis(
      "H4",
      h4);

   RV_PrintAnalysis(
      "H1",
      h1);

   RV_PrintAnalysis(
      "M15",
      m15);

   ENUM_REVERSAL_DIRECTION direction =
      RV_DominantDirection(
         h4,
         h1,
         m15);

   double score =
      RV_MTFScore(
         h4,
         h1,
         m15);

   Print(
      "[ReversalEngine] Multi-Timeframe | Direction=",
      RV_DirectionToString(direction),
      " | Score=",
      DoubleToString(score,1)
   );
}

//-------------------------------------------------------------------
// Engine status
//-------------------------------------------------------------------
string RV_Status(
   const string symbol)
{
   if(!RV_IsGold(symbol))
      return "ReversalEngine: non-gold symbol rejected.";

   ReversalAnalysis h4;
   ReversalAnalysis h1;
   ReversalAnalysis m15;

   bool h4Valid =
      RV_AnalyzeTimeframe(
         symbol,
         PERIOD_H4,
         h4);

   bool h1Valid =
      RV_AnalyzeTimeframe(
         symbol,
         PERIOD_H1,
         h1);

   bool m15Valid =
      RV_AnalyzeTimeframe(
         symbol,
         PERIOD_M15,
         m15);

   if(!h4Valid &&
      !h1Valid &&
      !m15Valid)
   {
      return
         "ReversalEngine: no valid reversal data.";
   }

   ENUM_REVERSAL_DIRECTION direction =
      RV_DominantDirection(
         h4,
         h1,
         m15);

   double score =
      RV_MTFScore(
         h4,
         h1,
         m15);

   return
      "ReversalEngine: " +
      RV_DirectionToString(direction) +
      " | MTF score=" +
      DoubleToString(score,1);
}

//-------------------------------------------------------------------
// Development safety
//-------------------------------------------------------------------
bool RV_DevelopmentSafe()
{
   return ICT_DEVELOPMENT_MODE;
}

#endif
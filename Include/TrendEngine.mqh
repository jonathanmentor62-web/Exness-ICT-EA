//+------------------------------------------------------------------+
//| TrendEngine.mqh                                                  |
//| Gold Multi-Strategy EA - Multi-Timeframe Trend Analysis          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_TREND_ENGINE_MQH__
#define __EXNESS_GOLD_TREND_ENGINE_MQH__

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "MarketStructure.mqh"

//-------------------------------------------------------------------
// Trend state
//-------------------------------------------------------------------
enum ENUM_TREND_STATE
{
   TREND_UNKNOWN = 0,
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_RANGING,
   TREND_TRANSITION
};

//-------------------------------------------------------------------
// Trend phase
//-------------------------------------------------------------------
enum ENUM_TREND_PHASE
{
   TREND_PHASE_NONE = 0,
   TREND_PHASE_IMPULSE,
   TREND_PHASE_PULLBACK,
   TREND_PHASE_CONTINUATION,
   TREND_PHASE_EXHAUSTION,
   TREND_PHASE_RANGE
};

//-------------------------------------------------------------------
// Trend direction
//-------------------------------------------------------------------
enum ENUM_TREND_DIRECTION
{
   TREND_DIRECTION_NONE = 0,
   TREND_DIRECTION_BULLISH,
   TREND_DIRECTION_BEARISH
};

//-------------------------------------------------------------------
// Complete trend analysis
//-------------------------------------------------------------------
struct TrendAnalysis
{
   bool valid;
   bool goldSafe;

   ENUM_TREND_STATE state;
   ENUM_TREND_PHASE phase;
   ENUM_TREND_DIRECTION direction;

   int bullishStructurePoints;
   int bearishStructurePoints;

   bool higherHigh;
   bool higherLow;
   bool lowerHigh;
   bool lowerLow;

   bool bullishStructure;
   bool bearishStructure;

   bool bullishContinuation;
   bool bearishContinuation;

   bool bullishPullback;
   bool bearishPullback;

   bool bullishMomentum;
   bool bearishMomentum;

   bool bullishExhaustion;
   bool bearishExhaustion;

   bool rangeDetected;

   double recentHigh;
   double previousHigh;
   double recentLow;
   double previousLow;

   double score;

   datetime signalTime;
   int signalShift;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset
//-------------------------------------------------------------------
void ResetTrendAnalysis(
   TrendAnalysis &t)
{
   t.valid = false;
   t.goldSafe = false;

   t.state = TREND_UNKNOWN;
   t.phase = TREND_PHASE_NONE;
   t.direction = TREND_DIRECTION_NONE;

   t.bullishStructurePoints = 0;
   t.bearishStructurePoints = 0;

   t.higherHigh = false;
   t.higherLow = false;
   t.lowerHigh = false;
   t.lowerLow = false;

   t.bullishStructure = false;
   t.bearishStructure = false;

   t.bullishContinuation = false;
   t.bearishContinuation = false;

   t.bullishPullback = false;
   t.bearishPullback = false;

   t.bullishMomentum = false;
   t.bearishMomentum = false;

   t.bullishExhaustion = false;
   t.bearishExhaustion = false;

   t.rangeDetected = false;

   t.recentHigh = 0.0;
   t.previousHigh = 0.0;
   t.recentLow = 0.0;
   t.previousLow = 0.0;

   t.score = 0.0;

   t.signalTime = 0;
   t.signalShift = -1;

   t.reason = "";
   t.evidence = "";
}

//-------------------------------------------------------------------
// Gold validation
//-------------------------------------------------------------------
bool TE_IsGold(
   const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//-------------------------------------------------------------------
// Trend state string
//-------------------------------------------------------------------
string TE_StateToString(
   const ENUM_TREND_STATE state)
{
   switch(state)
   {
      case TREND_BULLISH:
         return "BULLISH";

      case TREND_BEARISH:
         return "BEARISH";

      case TREND_RANGING:
         return "RANGING";

      case TREND_TRANSITION:
         return "TRANSITION";

      default:
         return "UNKNOWN";
   }
}

//-------------------------------------------------------------------
// Trend phase string
//-------------------------------------------------------------------
string TE_PhaseToString(
   const ENUM_TREND_PHASE phase)
{
   switch(phase)
   {
      case TREND_PHASE_IMPULSE:
         return "IMPULSE";

      case TREND_PHASE_PULLBACK:
         return "PULLBACK";

      case TREND_PHASE_CONTINUATION:
         return "CONTINUATION";

      case TREND_PHASE_EXHAUSTION:
         return "EXHAUSTION";

      case TREND_PHASE_RANGE:
         return "RANGE";

      default:
         return "NONE";
   }
}

//-------------------------------------------------------------------
// Trend direction string
//-------------------------------------------------------------------
string TE_DirectionToString(
   const ENUM_TREND_DIRECTION direction)
{
   if(direction == TREND_DIRECTION_BULLISH)
      return "BULLISH";

   if(direction == TREND_DIRECTION_BEARISH)
      return "BEARISH";

   return "NONE";
}

//-------------------------------------------------------------------
// Recent swing high
//-------------------------------------------------------------------
double TE_RecentHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return GetRecentSwingHighPrice(
      symbol,
      timeframe);
}

//-------------------------------------------------------------------
// Recent swing low
//-------------------------------------------------------------------
double TE_RecentLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return GetRecentSwingLowPrice(
      symbol,
      timeframe);
}

//-------------------------------------------------------------------
// Detect higher high
//-------------------------------------------------------------------
bool TE_HigherHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentHigh = 0.0;
   double previousHigh = 0.0;

   return IsHigherHigh(
      symbol,
      timeframe,
      recentHigh,
      previousHigh);
}

//-------------------------------------------------------------------
// Detect lower high
//-------------------------------------------------------------------
bool TE_LowerHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentHigh = 0.0;
   double previousHigh = 0.0;

   return IsLowerHigh(
      symbol,
      timeframe,
      recentHigh,
      previousHigh);
}

//-------------------------------------------------------------------
// Detect higher low
//-------------------------------------------------------------------
bool TE_HigherLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentLow = 0.0;
   double previousLow = 0.0;

   return IsHigherLow(
      symbol,
      timeframe,
      recentLow,
      previousLow);
}

//-------------------------------------------------------------------
// Detect lower low
//-------------------------------------------------------------------
bool TE_LowerLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentLow = 0.0;
   double previousLow = 0.0;

   return IsLowerLow(
      symbol,
      timeframe,
      recentLow,
      previousLow);
}

//-------------------------------------------------------------------
// Determine structural trend direction
//-------------------------------------------------------------------
ENUM_TREND_DIRECTION TE_GetStructureDirection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   bool hh =
      TE_HigherHigh(
         symbol,
         timeframe);

   bool hl =
      TE_HigherLow(
         symbol,
         timeframe);

   bool lh =
      TE_LowerHigh(
         symbol,
         timeframe);

   bool ll =
      TE_LowerLow(
         symbol,
         timeframe);

   if(hh && hl && !ll)
      return TREND_DIRECTION_BULLISH;

   if(lh && ll && !hh)
      return TREND_DIRECTION_BEARISH;

   return TREND_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Structure alignment
//-------------------------------------------------------------------
bool TE_BullishStructure(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return TE_HigherHigh(
             symbol,
             timeframe)
          &&
          TE_HigherLow(
             symbol,
             timeframe);
}

//-------------------------------------------------------------------
bool TE_BearishStructure(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return TE_LowerHigh(
             symbol,
             timeframe)
          &&
          TE_LowerLow(
             symbol,
             timeframe);
}
//-------------------------------------------------------------------
// Candle access
//-------------------------------------------------------------------
double TE_Open(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iOpen(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
double TE_Close(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iClose(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
double TE_High(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iHigh(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
double TE_Low(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iLow(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
datetime TE_Time(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iTime(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
// Candle range
//-------------------------------------------------------------------
double TE_Range(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high = TE_High(symbol, timeframe, shift);
   double low  = TE_Low(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;

   return high - low;
}

//-------------------------------------------------------------------
// Candle body
//-------------------------------------------------------------------
double TE_Body(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = TE_Open(symbol, timeframe, shift);
   double close = TE_Close(symbol, timeframe, shift);

   if(open <= 0.0 || close <= 0.0)
      return 0.0;

   return MathAbs(close - open);
}

//-------------------------------------------------------------------
// Body ratio
//-------------------------------------------------------------------
double TE_BodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range = TE_Range(
      symbol,
      timeframe,
      shift);

   double body = TE_Body(
      symbol,
      timeframe,
      shift);

   if(range <= 0.0)
      return 0.0;

   return body / range;
}

//-------------------------------------------------------------------
// Bullish candle
//-------------------------------------------------------------------
bool TE_BullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = TE_Open(symbol, timeframe, shift);
   double close = TE_Close(symbol, timeframe, shift);

   return close > open;
}

//-------------------------------------------------------------------
// Bearish candle
//-------------------------------------------------------------------
bool TE_BearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = TE_Open(symbol, timeframe, shift);
   double close = TE_Close(symbol, timeframe, shift);

   return close < open;
}

//-------------------------------------------------------------------
// Strong bullish momentum
//-------------------------------------------------------------------
bool TE_BullishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!TE_BullishCandle(
         symbol,
         timeframe,
         shift))
      return false;

   return TE_BodyRatio(
             symbol,
             timeframe,
             shift)
          >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Strong bearish momentum
//-------------------------------------------------------------------
bool TE_BearishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!TE_BearishCandle(
         symbol,
         timeframe,
         shift))
      return false;

   return TE_BodyRatio(
             symbol,
             timeframe,
             shift)
          >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Detect bullish continuation
//-------------------------------------------------------------------
bool TE_BullishContinuation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BullishStructure(
         symbol,
         timeframe))
      return false;

   bool currentBullish =
      TE_BullishMomentum(
         symbol,
         timeframe,
         1);

   if(!currentBullish)
      return false;

   double recentHigh =
      TE_RecentHigh(
         symbol,
         timeframe);

   double close =
      TE_Close(
         symbol,
         timeframe,
         1);

   if(recentHigh <= 0.0 || close <= 0.0)
      return false;

   return close >= recentHigh;
}

//-------------------------------------------------------------------
// Detect bearish continuation
//-------------------------------------------------------------------
bool TE_BearishContinuation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BearishStructure(
         symbol,
         timeframe))
      return false;

   bool currentBearish =
      TE_BearishMomentum(
         symbol,
         timeframe,
         1);

   if(!currentBearish)
      return false;

   double recentLow =
      TE_RecentLow(
         symbol,
         timeframe);

   double close =
      TE_Close(
         symbol,
         timeframe,
         1);

   if(recentLow <= 0.0 || close <= 0.0)
      return false;

   return close <= recentLow;
}

//-------------------------------------------------------------------
// Detect bullish pullback
//-------------------------------------------------------------------
bool TE_BullishPullback(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BullishStructure(
         symbol,
         timeframe))
      return false;

   double recentLow =
      TE_RecentLow(
         symbol,
         timeframe);

   double close =
      TE_Close(
         symbol,
         timeframe,
         1);

   if(recentLow <= 0.0 || close <= 0.0)
      return false;

   // Price has returned toward the bullish structural low
   // without closing below it.
   return close > recentLow &&
          close < TE_High(
                     symbol,
                     timeframe,
                     1);
}

//-------------------------------------------------------------------
// Detect bearish pullback
//-------------------------------------------------------------------
bool TE_BearishPullback(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BearishStructure(
         symbol,
         timeframe))
      return false;

   double recentHigh =
      TE_RecentHigh(
         symbol,
         timeframe);

   double close =
      TE_Close(
         symbol,
         timeframe,
         1);

   if(recentHigh <= 0.0 || close <= 0.0)
      return false;

   return close < recentHigh &&
          close > TE_Low(
                     symbol,
                     timeframe,
                     1);
}

//-------------------------------------------------------------------
// Detect bullish momentum
//-------------------------------------------------------------------
bool TE_HasBullishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   for(int shift = 1; shift <= 3; shift++)
   {
      if(TE_BullishMomentum(
            symbol,
            timeframe,
            shift))
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bearish momentum
//-------------------------------------------------------------------
bool TE_HasBearishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   for(int shift = 1; shift <= 3; shift++)
   {
      if(TE_BearishMomentum(
            symbol,
            timeframe,
            shift))
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Trend transition detection
//-------------------------------------------------------------------
bool TE_IsTransition(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   bool bullish =
      TE_BullishStructure(
         symbol,
         timeframe);

   bool bearish =
      TE_BearishStructure(
         symbol,
         timeframe);

   if(bullish && bearish)
      return true;

   return false;
} 
//-------------------------------------------------------------------
// Candle access
//-------------------------------------------------------------------
double TE_Open(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iOpen(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
double TE_Close(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iClose(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
double TE_High(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iHigh(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
double TE_Low(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iLow(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
datetime TE_Time(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iTime(symbol, timeframe, shift);
}

//-------------------------------------------------------------------
// Candle range
//-------------------------------------------------------------------
double TE_Range(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high = TE_High(symbol, timeframe, shift);
   double low  = TE_Low(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;

   return high - low;
}

//-------------------------------------------------------------------
// Candle body
//-------------------------------------------------------------------
double TE_Body(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = TE_Open(symbol, timeframe, shift);
   double close = TE_Close(symbol, timeframe, shift);

   if(open <= 0.0 || close <= 0.0)
      return 0.0;

   return MathAbs(close - open);
}

//-------------------------------------------------------------------
// Body ratio
//-------------------------------------------------------------------
double TE_BodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range = TE_Range(
      symbol,
      timeframe,
      shift);

   if(range <= 0.0)
      return 0.0;

   return TE_Body(
      symbol,
      timeframe,
      shift) / range;
}

//-------------------------------------------------------------------
// Bullish candle
//-------------------------------------------------------------------
bool TE_BullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = TE_Open(symbol, timeframe, shift);
   double close = TE_Close(symbol, timeframe, shift);

   return close > open;
}

//-------------------------------------------------------------------
// Bearish candle
//-------------------------------------------------------------------
bool TE_BearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = TE_Open(symbol, timeframe, shift);
   double close = TE_Close(symbol, timeframe, shift);

   return close < open;
}

//-------------------------------------------------------------------
// Strong bullish momentum candle
//-------------------------------------------------------------------
bool TE_StrongBullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!TE_BullishCandle(symbol,timeframe,shift))
      return false;

   return TE_BodyRatio(
             symbol,
             timeframe,
             shift)
          >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Strong bearish momentum candle
//-------------------------------------------------------------------
bool TE_StrongBearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!TE_BearishCandle(symbol,timeframe,shift))
      return false;

   return TE_BodyRatio(
             symbol,
             timeframe,
             shift)
          >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Recent price direction
//-------------------------------------------------------------------
ENUM_TREND_DIRECTION TE_GetCandleDirection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(TE_BullishCandle(symbol,timeframe,shift))
      return TREND_DIRECTION_BULLISH;

   if(TE_BearishCandle(symbol,timeframe,shift))
      return TREND_DIRECTION_BEARISH;

   return TREND_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Detect bullish momentum
//-------------------------------------------------------------------
bool TE_BullishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   for(int shift = 1; shift <= 3; shift++)
   {
      if(TE_StrongBullishCandle(
            symbol,
            timeframe,
            shift))
      {
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bearish momentum
//-------------------------------------------------------------------
bool TE_BearishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   for(int shift = 1; shift <= 3; shift++)
   {
      if(TE_StrongBearishCandle(
            symbol,
            timeframe,
            shift))
      {
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bullish continuation
//-------------------------------------------------------------------
bool TE_BullishContinuation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BullishStructure(
         symbol,
         timeframe))
   {
      return false;
   }

   bool recentBullish =
      TE_BullishCandle(
         symbol,
         timeframe,
         1);

   if(!recentBullish)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Detect bearish continuation
//-------------------------------------------------------------------
bool TE_BearishContinuation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BearishStructure(
         symbol,
         timeframe))
   {
      return false;
   }

   bool recentBearish =
      TE_BearishCandle(
         symbol,
         timeframe,
         1);

   if(!recentBearish)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Detect bullish pullback
//-------------------------------------------------------------------
bool TE_BullishPullback(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BullishStructure(
         symbol,
         timeframe))
   {
      return false;
   }

   if(!TE_BearishCandle(
         symbol,
         timeframe,
         1))
   {
      return false;
   }

   double recentLow =
      TE_RecentLow(
         symbol,
         timeframe);

   if(recentLow <= 0.0)
      return false;

   double close =
      TE_Close(
         symbol,
         timeframe,
         1);

   return close > recentLow;
}

//-------------------------------------------------------------------
// Detect bearish pullback
//-------------------------------------------------------------------
bool TE_BearishPullback(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!TE_BearishStructure(
         symbol,
         timeframe))
   {
      return false;
   }

   if(!TE_BullishCandle(
         symbol,
         timeframe,
         1))
   {
      return false;
   }

   double recentHigh =
      TE_RecentHigh(
         symbol,
         timeframe);

   if(recentHigh <= 0.0)
      return false;

   double close =
      TE_Close(
         symbol,
         timeframe,
         1);

   return close < recentHigh;
}

//-------------------------------------------------------------------
// Detect possible bullish exhaustion
//-------------------------------------------------------------------
bool TE_BullishExhaustion(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double range =
      TE_Range(
         symbol,
         timeframe,
         1);

   double body =
      TE_Body(
         symbol,
         timeframe,
         1);

   if(range <= 0.0 || body <= 0.0)
      return false;

   double upperWick =
      TE_High(symbol,timeframe,1)
      -
      MathMax(
         TE_Open(symbol,timeframe,1),
         TE_Close(symbol,timeframe,1));

   return TE_BullishCandle(
            symbol,
            timeframe,
            1)
          &&
          upperWick > body;
}

//-------------------------------------------------------------------
// Detect possible bearish exhaustion
//-------------------------------------------------------------------
bool TE_BearishExhaustion(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double range =
      TE_Range(
         symbol,
         timeframe,
         1);

   double body =
      TE_Body(
         symbol,
         timeframe,
         1);

   if(range <= 0.0 || body <= 0.0)
      return false;

   double lowerWick =
      MathMin(
         TE_Open(symbol,timeframe,1),
         TE_Close(symbol,timeframe,1))
      -
      TE_Low(symbol,timeframe,1);

   return TE_BearishCandle(
            symbol,
            timeframe,
            1)
          &&
          lowerWick > body;
}

//-------------------------------------------------------------------
// Detect range
//-------------------------------------------------------------------
bool TE_IsRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   double recentHigh =
      TE_RecentHigh(
         symbol,
         timeframe);

   double recentLow =
      TE_RecentLow(
         symbol,
         timeframe);

   if(recentHigh <= 0.0 ||
      recentLow <= 0.0 ||
      recentHigh <= recentLow)
   {
      return false;
   }

   double range =
      recentHigh - recentLow;

   if(range <= 0.0)
      return false;

   bool bullish =
      TE_BullishStructure(
         symbol,
         timeframe);

   bool bearish =
      TE_BearishStructure(
         symbol,
         timeframe);

   return !bullish && !bearish;
}

//-------------------------------------------------------------------
// Multi-timeframe trend alignment
//-------------------------------------------------------------------
bool TE_MultiTimeframeBullish(
   const string symbol)
{
   ENUM_TREND_DIRECTION h4 =
      TE_GetStructureDirection(
         symbol,
         PERIOD_H4);

   ENUM_TREND_DIRECTION h1 =
      TE_GetStructureDirection(
         symbol,
         PERIOD_H1);

   return h4 == TREND_DIRECTION_BULLISH &&
          h1 == TREND_DIRECTION_BULLISH;
}

//-------------------------------------------------------------------
bool TE_MultiTimeframeBearish(
   const string symbol)
{
   ENUM_TREND_DIRECTION h4 =
      TE_GetStructureDirection(
         symbol,
         PERIOD_H4);

   ENUM_TREND_DIRECTION h1 =
      TE_GetStructureDirection(
         symbol,
         PERIOD_H1);

   return h4 == TREND_DIRECTION_BEARISH &&
          h1 == TREND_DIRECTION_BEARISH;
}
//-------------------------------------------------------------------
// Determine trend state
//-------------------------------------------------------------------
ENUM_TREND_STATE TE_GetState(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   bool bullish =
      TE_BullishStructure(
         symbol,
         timeframe);

   bool bearish =
      TE_BearishStructure(
         symbol,
         timeframe);

   bool range =
      TE_IsRange(
         symbol,
         timeframe);

   if(bullish && !bearish)
      return TREND_BULLISH;

   if(bearish && !bullish)
      return TREND_BEARISH;

   if(range)
      return TREND_RANGING;

   if(bullish && bearish)
      return TREND_TRANSITION;

   return TREND_UNKNOWN;
}

//-------------------------------------------------------------------
// Determine trend phase
//-------------------------------------------------------------------
ENUM_TREND_PHASE TE_GetPhase(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   ENUM_TREND_STATE state =
      TE_GetState(
         symbol,
         timeframe);

   if(state == TREND_RANGING)
      return TREND_PHASE_RANGE;

   if(state == TREND_BULLISH)
   {
      if(TE_BullishExhaustion(
            symbol,
            timeframe))
      {
         return TREND_PHASE_EXHAUSTION;
      }

      if(TE_BullishPullback(
            symbol,
            timeframe))
      {
         return TREND_PHASE_PULLBACK;
      }

      if(TE_BullishContinuation(
            symbol,
            timeframe))
      {
         return TREND_PHASE_CONTINUATION;
      }

      if(TE_BullishMomentum(
            symbol,
            timeframe))
      {
         return TREND_PHASE_IMPULSE;
      }
   }

   if(state == TREND_BEARISH)
   {
      if(TE_BearishExhaustion(
            symbol,
            timeframe))
      {
         return TREND_PHASE_EXHAUSTION;
      }

      if(TE_BearishPullback(
            symbol,
            timeframe))
      {
         return TREND_PHASE_PULLBACK;
      }

      if(TE_BearishContinuation(
            symbol,
            timeframe))
      {
         return TREND_PHASE_CONTINUATION;
      }

      if(TE_BearishMomentum(
            symbol,
            timeframe))
      {
         return TREND_PHASE_IMPULSE;
      }
   }

   return TREND_PHASE_NONE;
}

//-------------------------------------------------------------------
// Calculate structural score
//-------------------------------------------------------------------
double TE_CalculateStructureScore(
   const TrendAnalysis &t)
{
   double score = 0.0;

   if(t.higherHigh)
      score += 20.0;

   if(t.higherLow)
      score += 20.0;

   if(t.lowerHigh)
      score += 20.0;

   if(t.lowerLow)
      score += 20.0;

   if(t.bullishContinuation)
      score += 10.0;

   if(t.bearishContinuation)
      score += 10.0;

   return MathMin(score,100.0);
}

//-------------------------------------------------------------------
// Calculate directional score
//-------------------------------------------------------------------
double TE_CalculateDirectionalScore(
   const TrendAnalysis &t)
{
   double bullishScore = 0.0;
   double bearishScore = 0.0;

   if(t.higherHigh)
      bullishScore += 20.0;

   if(t.higherLow)
      bullishScore += 20.0;

   if(t.lowerHigh)
      bearishScore += 20.0;

   if(t.lowerLow)
      bearishScore += 20.0;

   if(t.bullishContinuation)
      bullishScore += 15.0;

   if(t.bearishContinuation)
      bearishScore += 15.0;

   if(t.bullishMomentum)
      bullishScore += 10.0;

   if(t.bearishMomentum)
      bearishScore += 10.0;

   if(t.bullishPullback)
      bullishScore += 5.0;

   if(t.bearishPullback)
      bearishScore += 5.0;

   if(bullishScore > bearishScore)
      return bullishScore;

   return bearishScore;
}

//-------------------------------------------------------------------
// Determine final direction
//-------------------------------------------------------------------
ENUM_TREND_DIRECTION TE_FinalDirection(
   const TrendAnalysis &t)
{
   double bullishScore = 0.0;
   double bearishScore = 0.0;

   if(t.higherHigh)
      bullishScore += 20.0;

   if(t.higherLow)
      bullishScore += 20.0;

   if(t.bullishContinuation)
      bullishScore += 15.0;

   if(t.bullishMomentum)
      bullishScore += 10.0;

   if(t.bullishPullback)
      bullishScore += 5.0;

   if(t.lowerHigh)
      bearishScore += 20.0;

   if(t.lowerLow)
      bearishScore += 20.0;

   if(t.bearishContinuation)
      bearishScore += 15.0;

   if(t.bearishMomentum)
      bearishScore += 10.0;

   if(t.bearishPullback)
      bearishScore += 5.0;

   if(bullishScore > bearishScore &&
      bullishScore >= 40.0)
   {
      return TREND_DIRECTION_BULLISH;
   }

   if(bearishScore > bullishScore &&
      bearishScore >= 40.0)
   {
      return TREND_DIRECTION_BEARISH;
   }

   return TREND_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Build evidence string
//-------------------------------------------------------------------
void TE_BuildEvidence(
   TrendAnalysis &t)
{
   t.evidence = "";

   if(t.higherHigh)
      t.evidence += "HH; ";

   if(t.higherLow)
      t.evidence += "HL; ";

   if(t.lowerHigh)
      t.evidence += "LH; ";

   if(t.lowerLow)
      t.evidence += "LL; ";

   if(t.bullishContinuation)
      t.evidence += "Bullish continuation; ";

   if(t.bearishContinuation)
      t.evidence += "Bearish continuation; ";

   if(t.bullishPullback)
      t.evidence += "Bullish pullback; ";

   if(t.bearishPullback)
      t.evidence += "Bearish pullback; ";

   if(t.bullishMomentum)
      t.evidence += "Bullish momentum; ";

   if(t.bearishMomentum)
      t.evidence += "Bearish momentum; ";

   if(t.bullishExhaustion)
      t.evidence += "Bullish exhaustion; ";

   if(t.bearishExhaustion)
      t.evidence += "Bearish exhaustion; ";

   if(t.rangeDetected)
      t.evidence += "Range; ";
}

//-------------------------------------------------------------------
// Build reason
//-------------------------------------------------------------------
void TE_BuildReason(
   TrendAnalysis &t)
{
   t.reason =
      "State=" +
      TE_StateToString(t.state) +
      " | Phase=" +
      TE_PhaseToString(t.phase) +
      " | Direction=" +
      TE_DirectionToString(t.direction);
}

//-------------------------------------------------------------------
// Analyze one timeframe
//-------------------------------------------------------------------
bool TE_AnalyzeTimeframe(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   TrendAnalysis &out)
{
   ResetTrendAnalysis(out);

   if(!TE_IsGold(symbol))
   {
      out.reason = "Non-gold symbol rejected.";
      return false;
   }

   int bars =
      Bars(symbol,timeframe);

   if(bars < ICT_MIN_HISTORY_BARS)
   {
      out.reason = "Insufficient history.";
      return false;
   }

   out.goldSafe = true;

   out.higherHigh =
      TE_HigherHigh(
         symbol,
         timeframe);

   out.higherLow =
      TE_HigherLow(
         symbol,
         timeframe);

   out.lowerHigh =
      TE_LowerHigh(
         symbol,
         timeframe);

   out.lowerLow =
      TE_LowerLow(
         symbol,
         timeframe);

   out.bullishStructure =
      out.higherHigh &&
      out.higherLow;

   out.bearishStructure =
      out.lowerHigh &&
      out.lowerLow;

   out.bullishContinuation =
      TE_BullishContinuation(
         symbol,
         timeframe);

   out.bearishContinuation =
      TE_BearishContinuation(
         symbol,
         timeframe);

   out.bullishPullback =
      TE_BullishPullback(
         symbol,
         timeframe);

   out.bearishPullback =
      TE_BearishPullback(
         symbol,
         timeframe);

   out.bullishMomentum =
      TE_BullishMomentum(
         symbol,
         timeframe);

   out.bearishMomentum =
      TE_BearishMomentum(
         symbol,
         timeframe);

   out.bullishExhaustion =
      TE_BullishExhaustion(
         symbol,
         timeframe);

   out.bearishExhaustion =
      TE_BearishExhaustion(
         symbol,
         timeframe);

   out.rangeDetected =
      TE_IsRange(
         symbol,
         timeframe);

   out.recentHigh =
      TE_RecentHigh(
         symbol,
         timeframe);

   out.recentLow =
      TE_RecentLow(
         symbol,
         timeframe);

   out.state =
      TE_GetState(
         symbol,
         timeframe);

   out.phase =
      TE_GetPhase(
         symbol,
         timeframe);

   out.direction =
      TE_FinalDirection(out);

   out.score =
      TE_CalculateDirectionalScore(out);

   out.signalShift = 1;

   out.signalTime =
      TE_Time(
         symbol,
         timeframe,
         1);

   TE_BuildEvidence(out);
   TE_BuildReason(out);

   out.valid =
      out.state != TREND_UNKNOWN &&
      out.direction != TREND_DIRECTION_NONE;

   return out.valid;
}
//-------------------------------------------------------------------
// Full multi-timeframe trend analysis
//-------------------------------------------------------------------
bool TE_AnalyzeGold(
   const string symbol,
   TrendAnalysis &h4,
   TrendAnalysis &h1,
   TrendAnalysis &m15)
{
   ResetTrendAnalysis(h4);
   ResetTrendAnalysis(h1);
   ResetTrendAnalysis(m15);

   if(!TE_IsGold(symbol))
      return false;

   bool h4Valid =
      TE_AnalyzeTimeframe(
         symbol,
         PERIOD_H4,
         h4);

   bool h1Valid =
      TE_AnalyzeTimeframe(
         symbol,
         PERIOD_H1,
         h1);

   bool m15Valid =
      TE_AnalyzeTimeframe(
         symbol,
         PERIOD_M15,
         m15);

   return h4Valid ||
          h1Valid ||
          m15Valid;
}

//-------------------------------------------------------------------
// H4 directional permission
//-------------------------------------------------------------------
bool TE_H4Bullish(
   const TrendAnalysis &h4)
{
   return h4.valid &&
          h4.direction ==
          TREND_DIRECTION_BULLISH;
}

//-------------------------------------------------------------------
bool TE_H4Bearish(
   const TrendAnalysis &h4)
{
   return h4.valid &&
          h4.direction ==
          TREND_DIRECTION_BEARISH;
}

//-------------------------------------------------------------------
// H1 alignment with H4
//-------------------------------------------------------------------
bool TE_H1BullishAligned(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1)
{
   return TE_H4Bullish(h4) &&
          h1.valid &&
          h1.direction ==
          TREND_DIRECTION_BULLISH;
}

//-------------------------------------------------------------------
bool TE_H1BearishAligned(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1)
{
   return TE_H4Bearish(h4) &&
          h1.valid &&
          h1.direction ==
          TREND_DIRECTION_BEARISH;
}

//-------------------------------------------------------------------
// M15 confirmation of higher-timeframe trend
//-------------------------------------------------------------------
bool TE_M15BullishAligned(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   return TE_H1BullishAligned(h4,h1) &&
          m15.valid &&
          m15.direction ==
          TREND_DIRECTION_BULLISH;
}

//-------------------------------------------------------------------
bool TE_M15BearishAligned(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   return TE_H1BearishAligned(h4,h1) &&
          m15.valid &&
          m15.direction ==
          TREND_DIRECTION_BEARISH;
}

//-------------------------------------------------------------------
// Strong bullish alignment
//-------------------------------------------------------------------
bool TE_StrongBullishAlignment(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!TE_M15BullishAligned(h4,h1,m15))
      return false;

   if(h4.phase == TREND_PHASE_EXHAUSTION)
      return false;

   if(h1.phase == TREND_PHASE_EXHAUSTION)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Strong bearish alignment
//-------------------------------------------------------------------
bool TE_StrongBearishAlignment(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!TE_M15BearishAligned(h4,h1,m15))
      return false;

   if(h4.phase == TREND_PHASE_EXHAUSTION)
      return false;

   if(h1.phase == TREND_PHASE_EXHAUSTION)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Pullback permission
//-------------------------------------------------------------------
bool TE_BullishPullbackPermission(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!TE_H4Bullish(h4))
      return false;

   if(!TE_H1BullishAligned(h4,h1))
      return false;

   return
      h1.bullishPullback ||
      m15.bullishPullback ||
      m15.state == TREND_BULLISH;
}

//-------------------------------------------------------------------
bool TE_BearishPullbackPermission(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!TE_H4Bearish(h4))
      return false;

   if(!TE_H1BearishAligned(h4,h1))
      return false;

   return
      h1.bearishPullback ||
      m15.bearishPullback ||
      m15.state == TREND_BEARISH;
}

//-------------------------------------------------------------------
// Continuation permission
//-------------------------------------------------------------------
bool TE_BullishContinuationPermission(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!TE_StrongBullishAlignment(
         h4,
         h1,
         m15))
   {
      return false;
   }

   return
      h4.bullishContinuation ||
      h1.bullishContinuation ||
      m15.bullishContinuation;
}

//-------------------------------------------------------------------
bool TE_BearishContinuationPermission(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!TE_StrongBearishAlignment(
         h4,
         h1,
         m15))
   {
      return false;
   }

   return
      h4.bearishContinuation ||
      h1.bearishContinuation ||
      m15.bearishContinuation;
}

//-------------------------------------------------------------------
// Calculate multi-timeframe score
//-------------------------------------------------------------------
double TE_MultiTimeframeScore(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
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
// Determine dominant direction
//-------------------------------------------------------------------
ENUM_TREND_DIRECTION TE_DominantDirection(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(TE_StrongBullishAlignment(
         h4,h1,m15))
   {
      return TREND_DIRECTION_BULLISH;
   }

   if(TE_StrongBearishAlignment(
         h4,h1,m15))
   {
      return TREND_DIRECTION_BEARISH;
   }

   if(TE_H4Bullish(h4) &&
      TE_H1BullishAligned(h4,h1))
   {
      return TREND_DIRECTION_BULLISH;
   }

   if(TE_H4Bearish(h4) &&
      TE_H1BearishAligned(h4,h1))
   {
      return TREND_DIRECTION_BEARISH;
   }

   return TREND_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Check whether trend is safe for continuation strategies
//-------------------------------------------------------------------
bool TE_ContinuationAllowed(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15,
   const ENUM_TREND_DIRECTION direction)
{
   if(direction == TREND_DIRECTION_BULLISH)
   {
      return TE_BullishContinuationPermission(
         h4,h1,m15);
   }

   if(direction == TREND_DIRECTION_BEARISH)
   {
      return TE_BearishContinuationPermission(
         h4,h1,m15);
   }

   return false;
}

//-------------------------------------------------------------------
// Check whether trend is safe for pullback strategies
//-------------------------------------------------------------------
bool TE_PullbackAllowed(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15,
   const ENUM_TREND_DIRECTION direction)
{
   if(direction == TREND_DIRECTION_BULLISH)
   {
      return TE_BullishPullbackPermission(
         h4,h1,m15);
   }

   if(direction == TREND_DIRECTION_BEARISH)
   {
      return TE_BearishPullbackPermission(
         h4,h1,m15);
   }

   return false;
}

//-------------------------------------------------------------------
// Trend description
//-------------------------------------------------------------------
string TE_Description(
   const TrendAnalysis &t)
{
   string text =
      "Trend=" +
      TE_StateToString(t.state) +
      " | Phase=" +
      TE_PhaseToString(t.phase) +
      " | Direction=" +
      TE_DirectionToString(t.direction) +
      " | Score=" +
      DoubleToString(t.score,1);

   if(t.evidence != "")
      text += " | " + t.evidence;

   return text;
}

//-------------------------------------------------------------------
// Print one trend analysis
//-------------------------------------------------------------------
void TE_PrintAnalysis(
   const string label,
   const TrendAnalysis &t)
{
   Print(
      "[TrendEngine] ",
      label,
      " | ",
      TE_Description(t)
   );
}

//-------------------------------------------------------------------
// Print complete multi-timeframe trend state
//-------------------------------------------------------------------
void TE_PrintMultiTimeframe(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   TE_PrintAnalysis(
      "H4",
      h4);

   TE_PrintAnalysis(
      "H1",
      h1);

   TE_PrintAnalysis(
      "M15",
      m15);

   ENUM_TREND_DIRECTION dominant =
      TE_DominantDirection(
         h4,
         h1,
         m15);

   double score =
      TE_MultiTimeframeScore(
         h4,
         h1,
         m15);

   Print(
      "[TrendEngine] Multi-Timeframe | Direction=",
      TE_DirectionToString(dominant),
      " | Score=",
      DoubleToString(score,1)
   );
}

//-------------------------------------------------------------------
// Engine status
//-------------------------------------------------------------------
string TE_Status(
   const string symbol)
{
   if(!TE_IsGold(symbol))
      return "TrendEngine: non-gold symbol rejected.";

   TrendAnalysis h4;
   TrendAnalysis h1;
   TrendAnalysis m15;

   if(!TE_AnalyzeGold(
         symbol,
         h4,
         h1,
         m15))
   {
      return "TrendEngine: insufficient trend data.";
   }

   ENUM_TREND_DIRECTION direction =
      TE_DominantDirection(
         h4,
         h1,
         m15);

   double score =
      TE_MultiTimeframeScore(
         h4,
         h1,
         m15);

   return
      "TrendEngine: " +
      TE_DirectionToString(direction) +
      " | MTF score=" +
      DoubleToString(score,1);
}

//-------------------------------------------------------------------
// Ready for confluence
//-------------------------------------------------------------------
bool TE_ReadyForConfluence(
   const TrendAnalysis &h4,
   const TrendAnalysis &h1,
   const TrendAnalysis &m15)
{
   if(!h4.valid ||
      !h1.valid ||
      !m15.valid)
   {
      return false;
   }

   ENUM_TREND_DIRECTION direction =
      TE_DominantDirection(
         h4,
         h1,
         m15);

   if(direction == TREND_DIRECTION_NONE)
      return false;

   double score =
      TE_MultiTimeframeScore(
         h4,
         h1,
         m15);

   return score >= 60.0;
}

//-------------------------------------------------------------------
// TrendEngine development safety state
//-------------------------------------------------------------------
bool TE_DevelopmentSafe()
{
   return ICT_DEVELOPMENT_MODE;
}

#endif


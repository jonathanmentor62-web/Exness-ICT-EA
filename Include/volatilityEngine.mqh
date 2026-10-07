//+------------------------------------------------------------------+
//| VolatilityEngine.mqh                                             |
//| Gold Multi-Strategy EA - Volatility Analysis                     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_VOLATILITY_ENGINE_MQH__
#define __EXNESS_GOLD_VOLATILITY_ENGINE_MQH__

#include "Config.mqh"
#include "RiskEngine.mqh"

//-------------------------------------------------------------------
// Volatility state
//-------------------------------------------------------------------
enum ENUM_VOLATILITY_STATE
{
   VOLATILITY_UNKNOWN = 0,
   VOLATILITY_LOW,
   VOLATILITY_NORMAL,
   VOLATILITY_HIGH,
   VOLATILITY_EXTREME
};

//-------------------------------------------------------------------
// Volatility direction
//-------------------------------------------------------------------
enum ENUM_VOLATILITY_DIRECTION
{
   VOL_DIRECTION_NONE = 0,
   VOL_DIRECTION_EXPANDING,
   VOL_DIRECTION_CONTRACTING
};

//-------------------------------------------------------------------
// Complete volatility analysis
//-------------------------------------------------------------------
struct VolatilityAnalysis
{
   bool valid;

   ENUM_VOLATILITY_STATE state;
   ENUM_VOLATILITY_DIRECTION direction;

   double atr;
   double previousATR;
   double averageATR;

   double currentRange;
   double previousRange;
   double averageRange;

   double rangeRatio;
   double atrRatio;

   double bodySize;
   double bodyRatio;

   bool atrAvailable;
   bool expansion;
   bool contraction;
   bool abnormalCandle;
   bool largeCandle;
   bool smallCandle;

   bool volatilityFilterPassed;
   bool goldSafe;

   double score;

   datetime signalTime;
   int signalShift;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset volatility analysis
//-------------------------------------------------------------------
void ResetVolatilityAnalysis(
   VolatilityAnalysis &v)
{
   v.valid = false;

   v.state = VOLATILITY_UNKNOWN;
   v.direction = VOL_DIRECTION_NONE;

   v.atr = 0.0;
   v.previousATR = 0.0;
   v.averageATR = 0.0;

   v.currentRange = 0.0;
   v.previousRange = 0.0;
   v.averageRange = 0.0;

   v.rangeRatio = 0.0;
   v.atrRatio = 0.0;

   v.bodySize = 0.0;
   v.bodyRatio = 0.0;

   v.atrAvailable = false;
   v.expansion = false;
   v.contraction = false;
   v.abnormalCandle = false;
   v.largeCandle = false;
   v.smallCandle = false;

   v.volatilityFilterPassed = false;
   v.goldSafe = false;

   v.score = 0.0;

   v.signalTime = 0;
   v.signalShift = -1;

   v.reason = "";
   v.evidence = "";
}

//-------------------------------------------------------------------
// Gold symbol validation
//-------------------------------------------------------------------
bool VE_IsGold(
   const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//-------------------------------------------------------------------
// Candle high
//-------------------------------------------------------------------
double VE_High(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iHigh(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Candle low
//-------------------------------------------------------------------
double VE_Low(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iLow(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Candle open
//-------------------------------------------------------------------
double VE_Open(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iOpen(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Candle close
//-------------------------------------------------------------------
double VE_Close(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iClose(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Candle time
//-------------------------------------------------------------------
datetime VE_Time(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iTime(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Candle range
//-------------------------------------------------------------------
double VE_CandleRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high = VE_High(symbol,timeframe,shift);
   double low  = VE_Low(symbol,timeframe,shift);

   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;

   return high - low;
}

//-------------------------------------------------------------------
// Candle body
//-------------------------------------------------------------------
double VE_CandleBody(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = VE_Open(symbol,timeframe,shift);
   double close = VE_Close(symbol,timeframe,shift);

   if(open <= 0.0 || close <= 0.0)
      return 0.0;

   return MathAbs(close - open);
}

//-------------------------------------------------------------------
// Candle body ratio
//-------------------------------------------------------------------
double VE_BodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range = VE_CandleRange(
      symbol,
      timeframe,
      shift);

   if(range <= 0.0)
      return 0.0;

   double body = VE_CandleBody(
      symbol,
      timeframe,
      shift);

   return body / range;
}

//-------------------------------------------------------------------
// True Range
//-------------------------------------------------------------------
double VE_TrueRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high = VE_High(symbol,timeframe,shift);
   double low  = VE_Low(symbol,timeframe,shift);

   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;

   double previousClose =
      VE_Close(symbol,timeframe,shift + 1);

   if(previousClose <= 0.0)
      return high - low;

   double range1 = high - low;
   double range2 = MathAbs(high - previousClose);
   double range3 = MathAbs(low - previousClose);

   return MathMax(
      range1,
      MathMax(range2,range3));
}

//-------------------------------------------------------------------
// Average true range calculated internally
//-------------------------------------------------------------------
double VE_CalculateATR(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int period,
   const int shift)
{
   if(period <= 0)
      return 0.0;

   double total = 0.0;
   int counted = 0;

   for(int i = shift;
       i < shift + period;
       i++)
   {
      double tr =
         VE_TrueRange(
            symbol,
            timeframe,
            i);

      if(tr <= 0.0)
         continue;

      total += tr;
      counted++;
   }

   if(counted <= 0)
      return 0.0;

   return total / counted;
}

//-------------------------------------------------------------------
// Average candle range
//-------------------------------------------------------------------
double VE_AverageRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int period,
   const int shift)
{
   if(period <= 0)
      return 0.0;

   double total = 0.0;
   int counted = 0;

   for(int i = shift;
       i < shift + period;
       i++)
   {
      double range =
         VE_CandleRange(
            symbol,
            timeframe,
            i);

      if(range <= 0.0)
         continue;

      total += range;
      counted++;
   }

   if(counted <= 0)
      return 0.0;

   return total / counted;
}
//-------------------------------------------------------------------
// Volatility state from ATR ratio
//-------------------------------------------------------------------
ENUM_VOLATILITY_STATE VE_GetStateFromRatio(
   const double atrRatio)
{
   if(atrRatio <= 0.0)
      return VOLATILITY_UNKNOWN;

   if(atrRatio < ICT_MIN_VOLATILITY_MULT)
      return VOLATILITY_LOW;

   if(atrRatio > ICT_MAX_VOLATILITY_MULT)
      return VOLATILITY_EXTREME;

   if(atrRatio >= 2.0)
      return VOLATILITY_HIGH;

   return VOLATILITY_NORMAL;
}

//-------------------------------------------------------------------
// Volatility state string
//-------------------------------------------------------------------
string VE_StateToString(
   const ENUM_VOLATILITY_STATE state)
{
   switch(state)
   {
      case VOLATILITY_LOW:
         return "LOW";

      case VOLATILITY_NORMAL:
         return "NORMAL";

      case VOLATILITY_HIGH:
         return "HIGH";

      case VOLATILITY_EXTREME:
         return "EXTREME";

      default:
         return "UNKNOWN";
   }
}

//-------------------------------------------------------------------
// Volatility direction string
//-------------------------------------------------------------------
string VE_DirectionToString(
   const ENUM_VOLATILITY_DIRECTION direction)
{
   switch(direction)
   {
      case VOL_DIRECTION_EXPANDING:
         return "EXPANDING";

      case VOL_DIRECTION_CONTRACTING:
         return "CONTRACTING";

      default:
         return "NONE";
   }
}

//-------------------------------------------------------------------
// Detect volatility expansion
//-------------------------------------------------------------------
bool VE_IsExpansion(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double currentATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift);

   double previousATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   if(currentATR <= 0.0 || previousATR <= 0.0)
      return false;

   return currentATR > previousATR;
}

//-------------------------------------------------------------------
// Detect volatility contraction
//-------------------------------------------------------------------
bool VE_IsContraction(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double currentATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift);

   double previousATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   if(currentATR <= 0.0 || previousATR <= 0.0)
      return false;

   return currentATR < previousATR;
}

//-------------------------------------------------------------------
// Detect unusually large candle
//-------------------------------------------------------------------
bool VE_IsLargeCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range =
      VE_CandleRange(
         symbol,
         timeframe,
         shift);

   double atr =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   if(range <= 0.0 || atr <= 0.0)
      return false;

   return range >= atr * ICT_MAX_VOLATILITY_MULT;
}

//-------------------------------------------------------------------
// Detect unusually small candle
//-------------------------------------------------------------------
bool VE_IsSmallCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range =
      VE_CandleRange(
         symbol,
         timeframe,
         shift);

   double atr =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   if(range <= 0.0 || atr <= 0.0)
      return false;

   return range <= atr * ICT_MIN_VOLATILITY_MULT;
}

//-------------------------------------------------------------------
// Detect abnormal candle
//-------------------------------------------------------------------
bool VE_IsAbnormalCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return VE_IsLargeCandle(
             symbol,
             timeframe,
             shift)
          ||
          VE_IsSmallCandle(
             symbol,
             timeframe,
             shift);
}

//-------------------------------------------------------------------
// Check volatility filter
//-------------------------------------------------------------------
bool VE_VolatilityFilterPassed(
   const double atrRatio)
{
   if(!ICT_ENABLE_VOLATILITY_FILTER)
      return true;

   if(atrRatio <= 0.0)
      return false;

   return atrRatio >= ICT_MIN_VOLATILITY_MULT &&
          atrRatio <= ICT_MAX_VOLATILITY_MULT;
}

//-------------------------------------------------------------------
// Calculate volatility score
//-------------------------------------------------------------------
double VE_CalculateScore(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return 0.0;

   double score = 0.0;

   // Normal volatility is preferred.
   if(v.state == VOLATILITY_NORMAL)
      score += 5.0;

   // High volatility can provide useful expansion,
   // but should not receive full confidence.
   if(v.state == VOLATILITY_HIGH)
      score += 3.0;

   // Expansion is useful when supported by structure.
   if(v.expansion)
      score += 3.0;

   // Contraction can precede a breakout.
   if(v.contraction)
      score += 2.0;

   // Abnormal candles reduce quality.
   if(v.abnormalCandle)
      score -= 5.0;

   // Extreme volatility is dangerous for execution.
   if(v.state == VOLATILITY_EXTREME)
      score -= 10.0;

   if(score < 0.0)
      score = 0.0;

   return score;
}

//-------------------------------------------------------------------
// Determine volatility direction
//-------------------------------------------------------------------
ENUM_VOLATILITY_DIRECTION VE_GetDirection(
   const double currentATR,
   const double previousATR)
{
   if(currentATR <= 0.0 ||
      previousATR <= 0.0)
   {
      return VOL_DIRECTION_NONE;
   }

   if(currentATR > previousATR)
      return VOL_DIRECTION_EXPANDING;

   if(currentATR < previousATR)
      return VOL_DIRECTION_CONTRACTING;

   return VOL_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Volatility safety check
//-------------------------------------------------------------------
bool VE_IsSafeForAnalysis(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return false;

   if(!v.goldSafe)
      return false;

   if(ICT_ENABLE_VOLATILITY_FILTER &&
      !v.volatilityFilterPassed)
   {
      return false;
   }

   // Never allow an extreme volatility state
   // to become an automatic trade trigger.
   if(v.state == VOLATILITY_EXTREME)
      return false;

   return true;
}
//-------------------------------------------------------------------
// Complete volatility analysis
//-------------------------------------------------------------------
bool VE_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   VolatilityAnalysis &out)
{
   ResetVolatilityAnalysis(out);

   if(!VE_IsGold(symbol))
      return false;

   if(shift < 1)
      return false;

   int requiredBars =
      ICT_ATR_PERIOD + shift + 5;

   if(Bars(symbol,timeframe) < requiredBars)
      return false;

   out.goldSafe = true;

   out.signalShift = shift;

   out.signalTime =
      VE_Time(
         symbol,
         timeframe,
         shift);

   if(out.signalTime <= 0)
      return false;

   // ---------------------------------------------------------------
   // ATR measurements
   // ---------------------------------------------------------------
   out.atr =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift);

   out.previousATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   out.averageATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 2);

   if(out.atr <= 0.0)
      return false;

   out.atrAvailable = true;

   // ---------------------------------------------------------------
   // Candle measurements
   // ---------------------------------------------------------------
   out.currentRange =
      VE_CandleRange(
         symbol,
         timeframe,
         shift);

   out.previousRange =
      VE_CandleRange(
         symbol,
         timeframe,
         shift + 1);

   out.averageRange =
      VE_AverageRange(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   out.bodySize =
      VE_CandleBody(
         symbol,
         timeframe,
         shift);

   out.bodyRatio =
      VE_BodyRatio(
         symbol,
         timeframe,
         shift);

   if(out.currentRange <= 0.0 ||
      out.averageRange <= 0.0)
   {
      return false;
   }

   // ---------------------------------------------------------------
   // Ratios
   // ---------------------------------------------------------------
   out.rangeRatio =
      out.currentRange /
      out.averageRange;

   if(out.previousATR > 0.0)
   {
      out.atrRatio =
         out.atr /
         out.previousATR;
   }
   else
   {
      out.atrRatio = 0.0;
   }

   // ---------------------------------------------------------------
   // State
   // ---------------------------------------------------------------
   out.state =
      VE_GetStateFromRatio(
         out.atrRatio);

   out.direction =
      VE_GetDirection(
         out.atr,
         out.previousATR);

   // ---------------------------------------------------------------
   // Event detection
   // ---------------------------------------------------------------
   out.expansion =
      VE_IsExpansion(
         symbol,
         timeframe,
         shift);

   out.contraction =
      VE_IsContraction(
         symbol,
         timeframe,
         shift);

   out.largeCandle =
      VE_IsLargeCandle(
         symbol,
         timeframe,
         shift);

   out.smallCandle =
      VE_IsSmallCandle(
         symbol,
         timeframe,
         shift);

   out.abnormalCandle =
      out.largeCandle ||
      out.smallCandle;

   // ---------------------------------------------------------------
   // Filter
   // ---------------------------------------------------------------
   out.volatilityFilterPassed =
      VE_VolatilityFilterPassed(
         out.rangeRatio);

   // ---------------------------------------------------------------
   // Score
   // ---------------------------------------------------------------
   out.valid = true;

   out.score =
      VE_CalculateScore(out);

   // ---------------------------------------------------------------
   // Explanation
   // ---------------------------------------------------------------
   out.reason =
      "Gold volatility analysis completed.";

   out.evidence =
      "ATR=" +
      DoubleToString(out.atr,_Digits);

   out.evidence +=
      " | ATR ratio=" +
      DoubleToString(out.atrRatio,2);

   out.evidence +=
      " | range ratio=" +
      DoubleToString(out.rangeRatio,2);

   out.evidence +=
      " | state=" +
      VE_StateToString(out.state);

   out.evidence +=
      " | direction=" +
      VE_DirectionToString(out.direction);

   if(out.expansion)
      out.evidence +=
         " | expansion";

   if(out.contraction)
      out.evidence +=
         " | contraction";

   if(out.largeCandle)
      out.evidence +=
         " | large candle";

   if(out.smallCandle)
      out.evidence +=
         " | small candle";

   if(out.volatilityFilterPassed)
      out.evidence +=
         " | filter passed";
   else
      out.evidence +=
         " | filter rejected";

   return true;
}

//-------------------------------------------------------------------
// Current volatility analysis
//-------------------------------------------------------------------
bool VE_AnalyzeCurrent(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   VolatilityAnalysis &out)
{
   return VE_Analyze(
      symbol,
      timeframe,
      1,
      out);
}

//-------------------------------------------------------------------
// Get ATR
//-------------------------------------------------------------------
double VE_GetATR(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   return VE_CalculateATR(
      symbol,
      timeframe,
      ICT_ATR_PERIOD,
      shift);
}

//-------------------------------------------------------------------
// Get volatility ratio
//-------------------------------------------------------------------
double VE_GetVolatilityRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   double currentATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift);

   double previousATR =
      VE_CalculateATR(
         symbol,
         timeframe,
         ICT_ATR_PERIOD,
         shift + 1);

   if(currentATR <= 0.0 ||
      previousATR <= 0.0)
   {
      return 0.0;
   }

   return currentATR / previousATR;
}

//-------------------------------------------------------------------
// Large candle protection
//-------------------------------------------------------------------
bool VE_LargeCandleProtection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   if(!VE_IsGold(symbol))
      return true;

   return VE_IsLargeCandle(
      symbol,
      timeframe,
      shift);
}

//-------------------------------------------------------------------
// Volatility filter for strategy analysis
//-------------------------------------------------------------------
bool VE_StrategyFilter(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   VolatilityAnalysis analysis;

   if(!VE_Analyze(
         symbol,
         timeframe,
         shift,
         analysis))
   {
      return false;
   }

   return VE_IsSafeForAnalysis(
      analysis);
}
//-------------------------------------------------------------------
// Volatility state helpers
//-------------------------------------------------------------------
bool VE_IsLow(
   const VolatilityAnalysis &v)
{
   return v.valid &&
          v.state == VOLATILITY_LOW;
}

//-------------------------------------------------------------------
bool VE_IsNormal(
   const VolatilityAnalysis &v)
{
   return v.valid &&
          v.state == VOLATILITY_NORMAL;
}

//-------------------------------------------------------------------
bool VE_IsHigh(
   const VolatilityAnalysis &v)
{
   return v.valid &&
          v.state == VOLATILITY_HIGH;
}

//-------------------------------------------------------------------
bool VE_IsExtreme(
   const VolatilityAnalysis &v)
{
   return v.valid &&
          v.state == VOLATILITY_EXTREME;
}

//-------------------------------------------------------------------
bool VE_IsExpanding(
   const VolatilityAnalysis &v)
{
   return v.valid &&
          v.direction == VOL_DIRECTION_EXPANDING;
}

//-------------------------------------------------------------------
bool VE_IsContracting(
   const VolatilityAnalysis &v)
{
   return v.valid &&
          v.direction == VOL_DIRECTION_CONTRACTING;
}

//-------------------------------------------------------------------
// Check whether current volatility supports a breakout
//-------------------------------------------------------------------
bool VE_SupportsBreakout(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return false;

   if(v.state == VOLATILITY_EXTREME)
      return false;

   if(v.abnormalCandle)
      return false;

   return v.expansion ||
          v.state == VOLATILITY_HIGH ||
          v.state == VOLATILITY_NORMAL;
}

//-------------------------------------------------------------------
// Check whether volatility supports a pullback/retest
//-------------------------------------------------------------------
bool VE_SupportsRetest(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return false;

   if(v.state == VOLATILITY_EXTREME)
      return false;

   if(v.abnormalCandle)
      return false;

   return v.state == VOLATILITY_LOW ||
          v.state == VOLATILITY_NORMAL ||
          v.contraction;
}

//-------------------------------------------------------------------
// Check whether volatility supports reversal analysis
//-------------------------------------------------------------------
bool VE_SupportsReversal(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return false;

   if(v.state == VOLATILITY_EXTREME)
      return false;

   // Reversals can occur after expansion,
   // but an abnormal candle should not be
   // treated as a standalone reversal signal.
   if(v.abnormalCandle)
      return false;

   return v.state == VOLATILITY_NORMAL ||
          v.state == VOLATILITY_HIGH ||
          v.contraction;
}

//-------------------------------------------------------------------
// Get volatility score safely
//-------------------------------------------------------------------
double VE_Score(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return 0.0;

   if(v.score < 0.0)
      return 0.0;

   return v.score;
}

//-------------------------------------------------------------------
// Volatility description
//-------------------------------------------------------------------
string VE_Description(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
      return "No valid volatility analysis.";

   string text =
      "State=" +
      VE_StateToString(v.state);

   text +=
      " | Direction=" +
      VE_DirectionToString(v.direction);

   text +=
      " | ATR=" +
      DoubleToString(v.atr,_Digits);

   text +=
      " | ATR ratio=" +
      DoubleToString(v.atrRatio,2);

   text +=
      " | Range ratio=" +
      DoubleToString(v.rangeRatio,2);

   text +=
      " | Score=" +
      DoubleToString(v.score,1);

   return text;
}

//-------------------------------------------------------------------
// Print volatility analysis
//-------------------------------------------------------------------
void VE_Print(
   const VolatilityAnalysis &v)
{
   if(!v.valid)
   {
      Print(
         "VolatilityEngine: no valid analysis."
      );

      return;
   }

   Print(
      "VolatilityEngine: ",
      VE_StateToString(v.state),
      " | direction=",
      VE_DirectionToString(v.direction),
      " | ATR=",
      DoubleToString(v.atr,_Digits),
      " | ATR ratio=",
      DoubleToString(v.atrRatio,2),
      " | range ratio=",
      DoubleToString(v.rangeRatio,2),
      " | score=",
      DoubleToString(v.score,1)
   );

   Print(
      "VolatilityEngine evidence: ",
      v.evidence
   );
}

//-------------------------------------------------------------------
// Simple status function
//-------------------------------------------------------------------
string VE_Status(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!VE_IsGold(symbol))
      return "NON-GOLD SYMBOL";

   VolatilityAnalysis v;

   if(!VE_AnalyzeCurrent(
         symbol,
         timeframe,
         v))
   {
      return "NO VOLATILITY DATA";
   }

   if(v.state == VOLATILITY_EXTREME)
      return "EXTREME VOLATILITY";

   if(v.state == VOLATILITY_HIGH)
      return "HIGH VOLATILITY";

   if(v.state == VOLATILITY_NORMAL)
      return "NORMAL VOLATILITY";

   if(v.state == VOLATILITY_LOW)
      return "LOW VOLATILITY";

   return "UNKNOWN VOLATILITY";
}

//-------------------------------------------------------------------
// Final readiness check
//-------------------------------------------------------------------
bool VE_ReadyForConfluence(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   if(!VE_IsGold(symbol))
      return false;

   VolatilityAnalysis v;

   if(!VE_Analyze(
         symbol,
         timeframe,
         shift,
         v))
   {
      return false;
   }

   if(!v.valid)
      return false;

   if(!v.goldSafe)
      return false;

   if(ICT_ENABLE_VOLATILITY_FILTER &&
      !v.volatilityFilterPassed)
   {
      return false;
   }

   if(v.state == VOLATILITY_EXTREME)
      return false;

   return true;
}
#endif
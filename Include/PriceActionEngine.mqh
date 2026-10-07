//+------------------------------------------------------------------+
//| PriceActionEngine.mqh                                            |
//| Gold Multi-Strategy EA - Objective Price Action Analysis         |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_PRICE_ACTION_ENGINE_MQH__
#define __EXNESS_GOLD_PRICE_ACTION_ENGINE_MQH__

#include "Config.mqh"
#include "RiskEngine.mqh"

//-------------------------------------------------------------------
// Price-action pattern
//-------------------------------------------------------------------
enum ENUM_PRICE_ACTION_PATTERN
{
   PA_PATTERN_NONE = 0,
   PA_PATTERN_BULLISH_ENGULFING,
   PA_PATTERN_BEARISH_ENGULFING,
   PA_PATTERN_BULLISH_PIN_BAR,
   PA_PATTERN_BEARISH_PIN_BAR,
   PA_PATTERN_BULLISH_REJECTION,
   PA_PATTERN_BEARISH_REJECTION,
   PA_PATTERN_BULLISH_MOMENTUM,
   PA_PATTERN_BEARISH_MOMENTUM,
   PA_PATTERN_BULLISH_INSIDE_BREAK,
   PA_PATTERN_BEARISH_INSIDE_BREAK
};

//-------------------------------------------------------------------
// Price-action direction
//-------------------------------------------------------------------
enum ENUM_PRICE_ACTION_DIRECTION
{
   PA_DIRECTION_NONE = 0,
   PA_DIRECTION_BULLISH,
   PA_DIRECTION_BEARISH
};

//-------------------------------------------------------------------
// Complete price-action analysis
//-------------------------------------------------------------------
struct PriceActionAnalysis
{
   bool valid;

   ENUM_PRICE_ACTION_DIRECTION direction;
   ENUM_PRICE_ACTION_PATTERN primaryPattern;

   bool bullishEngulfing;
   bool bearishEngulfing;

   bool bullishPinBar;
   bool bearishPinBar;

   bool bullishRejection;
   bool bearishRejection;

   bool bullishMomentum;
   bool bearishMomentum;

   bool bullishInsideBreak;
   bool bearishInsideBreak;

   bool strongBullishBody;
   bool strongBearishBody;

   double open;
   double high;
   double low;
   double close;

   double range;
   double body;
   double bodyRatio;

   double upperWick;
   double lowerWick;

   double score;

   datetime signalTime;
   int signalShift;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset
//-------------------------------------------------------------------
void ResetPriceActionAnalysis(
   PriceActionAnalysis &p)
{
   p.valid = false;

   p.direction = PA_DIRECTION_NONE;
   p.primaryPattern = PA_PATTERN_NONE;

   p.bullishEngulfing = false;
   p.bearishEngulfing = false;

   p.bullishPinBar = false;
   p.bearishPinBar = false;

   p.bullishRejection = false;
   p.bearishRejection = false;

   p.bullishMomentum = false;
   p.bearishMomentum = false;

   p.bullishInsideBreak = false;
   p.bearishInsideBreak = false;

   p.strongBullishBody = false;
   p.strongBearishBody = false;

   p.open = 0.0;
   p.high = 0.0;
   p.low = 0.0;
   p.close = 0.0;

   p.range = 0.0;
   p.body = 0.0;
   p.bodyRatio = 0.0;

   p.upperWick = 0.0;
   p.lowerWick = 0.0;

   p.score = 0.0;

   p.signalTime = 0;
   p.signalShift = -1;

   p.reason = "";
   p.evidence = "";
}

//-------------------------------------------------------------------
// Gold validation
//-------------------------------------------------------------------
bool PA_IsGold(
   const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//-------------------------------------------------------------------
// Candle access
//-------------------------------------------------------------------
double PA_Open(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iOpen(symbol,timeframe,shift);
}

double PA_High(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iHigh(symbol,timeframe,shift);
}

double PA_Low(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iLow(symbol,timeframe,shift);
}

double PA_Close(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iClose(symbol,timeframe,shift);
}

datetime PA_Time(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return iTime(symbol,timeframe,shift);
}

//-------------------------------------------------------------------
// Candle range
//-------------------------------------------------------------------
double PA_Range(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double high = PA_High(symbol,timeframe,shift);
   double low  = PA_Low(symbol,timeframe,shift);

   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;

   return high - low;
}

//-------------------------------------------------------------------
// Candle body
//-------------------------------------------------------------------
double PA_Body(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = PA_Open(symbol,timeframe,shift);
   double close = PA_Close(symbol,timeframe,shift);

   if(open <= 0.0 || close <= 0.0)
      return 0.0;

   return MathAbs(close - open);
}

//-------------------------------------------------------------------
// Body ratio
//-------------------------------------------------------------------
double PA_BodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double range =
      PA_Range(
         symbol,
         timeframe,
         shift);

   if(range <= 0.0)
      return 0.0;

   return PA_Body(
             symbol,
             timeframe,
             shift)
          / range;
}

//-------------------------------------------------------------------
// Upper wick
//-------------------------------------------------------------------
double PA_UpperWick(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = PA_Open(symbol,timeframe,shift);
   double close = PA_Close(symbol,timeframe,shift);
   double high  = PA_High(symbol,timeframe,shift);

   if(high <= 0.0)
      return 0.0;

   return high - MathMax(open,close);
}

//-------------------------------------------------------------------
// Lower wick
//-------------------------------------------------------------------
double PA_LowerWick(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = PA_Open(symbol,timeframe,shift);
   double close = PA_Close(symbol,timeframe,shift);
   double low   = PA_Low(symbol,timeframe,shift);

   if(low <= 0.0)
      return 0.0;

   return MathMin(open,close) - low;
}

//-------------------------------------------------------------------
// Candle direction
//-------------------------------------------------------------------
ENUM_PRICE_ACTION_DIRECTION PA_CandleDirection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   double open  = PA_Open(symbol,timeframe,shift);
   double close = PA_Close(symbol,timeframe,shift);

   if(open <= 0.0 || close <= 0.0)
      return PA_DIRECTION_NONE;

   if(close > open)
      return PA_DIRECTION_BULLISH;

   if(close < open)
      return PA_DIRECTION_BEARISH;

   return PA_DIRECTION_NONE;
}

//-------------------------------------------------------------------
// Pattern string
//-------------------------------------------------------------------
string PA_PatternToString(
   const ENUM_PRICE_ACTION_PATTERN pattern)
{
   switch(pattern)
   {
      case PA_PATTERN_BULLISH_ENGULFING:
         return "BULLISH ENGULFING";

      case PA_PATTERN_BEARISH_ENGULFING:
         return "BEARISH ENGULFING";

      case PA_PATTERN_BULLISH_PIN_BAR:
         return "BULLISH PIN BAR";

      case PA_PATTERN_BEARISH_PIN_BAR:
         return "BEARISH PIN BAR";

      case PA_PATTERN_BULLISH_REJECTION:
         return "BULLISH REJECTION";

      case PA_PATTERN_BEARISH_REJECTION:
         return "BEARISH REJECTION";

      case PA_PATTERN_BULLISH_MOMENTUM:
         return "BULLISH MOMENTUM";

      case PA_PATTERN_BEARISH_MOMENTUM:
         return "BEARISH MOMENTUM";

      case PA_PATTERN_BULLISH_INSIDE_BREAK:
         return "BULLISH INSIDE BREAK";

      case PA_PATTERN_BEARISH_INSIDE_BREAK:
         return "BEARISH INSIDE BREAK";

      default:
         return "NONE";
   }
}

//-------------------------------------------------------------------
// Direction string
//-------------------------------------------------------------------
string PA_DirectionToString(
   const ENUM_PRICE_ACTION_DIRECTION direction)
{
   if(direction == PA_DIRECTION_BULLISH)
      return "BULLISH";

   if(direction == PA_DIRECTION_BEARISH)
      return "BEARISH";

   return "NONE";
}
//-------------------------------------------------------------------
// Bullish engulfing
//-------------------------------------------------------------------
bool PA_BullishEngulfing(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_ENGULFING)
      return false;

   if(shift < 1)
      return false;

   double open1  = PA_Open(symbol,timeframe,shift);
   double close1 = PA_Close(symbol,timeframe,shift);

   double open2  = PA_Open(symbol,timeframe,shift + 1);
   double close2 = PA_Close(symbol,timeframe,shift + 1);

   if(open1 <= 0.0 ||
      close1 <= 0.0 ||
      open2 <= 0.0 ||
      close2 <= 0.0)
   {
      return false;
   }

   // Current candle must be bullish.
   if(close1 <= open1)
      return false;

   // Previous candle must be bearish.
   if(close2 >= open2)
      return false;

   return open1 <= close2 &&
          close1 >= open2;
}

//-------------------------------------------------------------------
// Bearish engulfing
//-------------------------------------------------------------------
bool PA_BearishEngulfing(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_ENGULFING)
      return false;

   if(shift < 1)
      return false;

   double open1  = PA_Open(symbol,timeframe,shift);
   double close1 = PA_Close(symbol,timeframe,shift);

   double open2  = PA_Open(symbol,timeframe,shift + 1);
   double close2 = PA_Close(symbol,timeframe,shift + 1);

   if(open1 <= 0.0 ||
      close1 <= 0.0 ||
      open2 <= 0.0 ||
      close2 <= 0.0)
   {
      return false;
   }

   // Current candle must be bearish.
   if(close1 >= open1)
      return false;

   // Previous candle must be bullish.
   if(close2 <= open2)
      return false;

   return open1 >= close2 &&
          close1 <= open2;
}

//-------------------------------------------------------------------
// Bullish pin bar
//-------------------------------------------------------------------
bool PA_BullishPinBar(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_PIN_BAR)
      return false;

   double range =
      PA_Range(symbol,timeframe,shift);

   double body =
      PA_Body(symbol,timeframe,shift);

   double lowerWick =
      PA_LowerWick(symbol,timeframe,shift);

   double upperWick =
      PA_UpperWick(symbol,timeframe,shift);

   if(range <= 0.0)
      return false;

   if(body <= 0.0)
      return false;

   // Strong lower rejection.
   if(lowerWick < body * 2.0)
      return false;

   if(lowerWick < upperWick * 1.5)
      return false;

   // Close must be in the upper portion.
   double low  = PA_Low(symbol,timeframe,shift);
   double close = PA_Close(symbol,timeframe,shift);

   if(low <= 0.0 || close <= 0.0)
      return false;

   double closePosition =
      (close - low) / range;

   return closePosition >= 0.65;
}

//-------------------------------------------------------------------
// Bearish pin bar
//-------------------------------------------------------------------
bool PA_BearishPinBar(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_PIN_BAR)
      return false;

   double range =
      PA_Range(symbol,timeframe,shift);

   double body =
      PA_Body(symbol,timeframe,shift);

   double lowerWick =
      PA_LowerWick(symbol,timeframe,shift);

   double upperWick =
      PA_UpperWick(symbol,timeframe,shift);

   if(range <= 0.0)
      return false;

   if(body <= 0.0)
      return false;

   // Strong upper rejection.
   if(upperWick < body * 2.0)
      return false;

   if(upperWick < lowerWick * 1.5)
      return false;

   // Close must be in the lower portion.
   double high  = PA_High(symbol,timeframe,shift);
   double close = PA_Close(symbol,timeframe,shift);

   if(high <= 0.0 || close <= 0.0)
      return false;

   double closePosition =
      (high - close) / range;

   return closePosition >= 0.65;
}

//-------------------------------------------------------------------
// Bullish rejection candle
//-------------------------------------------------------------------
bool PA_BullishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_REJECTION_CANDLE)
      return false;

   double range =
      PA_Range(symbol,timeframe,shift);

   double lowerWick =
      PA_LowerWick(symbol,timeframe,shift);

   double body =
      PA_Body(symbol,timeframe,shift);

   if(range <= 0.0 ||
      lowerWick <= 0.0)
   {
      return false;
   }

   // Lower wick must represent meaningful rejection.
   if(lowerWick < range * 0.35)
      return false;

   // Rejection should not be an almost directionless doji.
   if(body > 0.0 &&
      lowerWick < body)
   {
      return false;
   }

   return true;
}

//-------------------------------------------------------------------
// Bearish rejection candle
//-------------------------------------------------------------------
bool PA_BearishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_REJECTION_CANDLE)
      return false;

   double range =
      PA_Range(symbol,timeframe,shift);

   double upperWick =
      PA_UpperWick(symbol,timeframe,shift);

   double body =
      PA_Body(symbol,timeframe,shift);

   if(range <= 0.0 ||
      upperWick <= 0.0)
   {
      return false;
   }

   if(upperWick < range * 0.35)
      return false;

   if(body > 0.0 &&
      upperWick < body)
   {
      return false;
   }

   return true;
}

//-------------------------------------------------------------------
// Strong bullish momentum candle
//-------------------------------------------------------------------
bool PA_BullishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_MOMENTUM_CANDLE)
      return false;

   double open =
      PA_Open(symbol,timeframe,shift);

   double close =
      PA_Close(symbol,timeframe,shift);

   double ratio =
      PA_BodyRatio(symbol,timeframe,shift);

   if(open <= 0.0 ||
      close <= 0.0)
   {
      return false;
   }

   if(close <= open)
      return false;

   return ratio >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Strong bearish momentum candle
//-------------------------------------------------------------------
bool PA_BearishMomentum(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_MOMENTUM_CANDLE)
      return false;

   double open =
      PA_Open(symbol,timeframe,shift);

   double close =
      PA_Close(symbol,timeframe,shift);

   double ratio =
      PA_BodyRatio(symbol,timeframe,shift);

   if(open <= 0.0 ||
      close <= 0.0)
   {
      return false;
   }

   if(close >= open)
      return false;

   return ratio >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Strong bullish body
//-------------------------------------------------------------------
bool PA_StrongBullishBody(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return PA_CandleDirection(
             symbol,
             timeframe,
             shift) == PA_DIRECTION_BULLISH
          &&
          PA_BodyRatio(
             symbol,
             timeframe,
             shift) >= ICT_MIN_BODY_RATIO;
}

//-------------------------------------------------------------------
// Strong bearish body
//-------------------------------------------------------------------
bool PA_StrongBearishBody(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   return PA_CandleDirection(
             symbol,
             timeframe,
             shift) == PA_DIRECTION_BEARISH
          &&
          PA_BodyRatio(
             symbol,
             timeframe,
             shift) >= ICT_MIN_BODY_RATIO;
}
//-------------------------------------------------------------------
// Bullish inside-bar breakout
//-------------------------------------------------------------------
bool PA_BullishInsideBreak(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_INSIDE_BAR)
      return false;

   if(shift < 1)
      return false;

   double currentHigh =
      PA_High(symbol,timeframe,shift);

   double currentClose =
      PA_Close(symbol,timeframe,shift);

   double motherHigh =
      PA_High(symbol,timeframe,shift + 1);

   double motherLow =
      PA_Low(symbol,timeframe,shift + 1);

   if(currentHigh <= 0.0 ||
      currentClose <= 0.0 ||
      motherHigh <= 0.0 ||
      motherLow <= 0.0)
   {
      return false;
   }

   // Previous candle must form the mother range.
   double insideHigh =
      PA_High(symbol,timeframe,shift + 1);

   double insideLow =
      PA_Low(symbol,timeframe,shift + 1);

   double olderHigh =
      PA_High(symbol,timeframe,shift + 2);

   double olderLow =
      PA_Low(symbol,timeframe,shift + 2);

   if(olderHigh <= 0.0 ||
      olderLow <= 0.0)
   {
      return false;
   }

   // The candle immediately before the breakout
   // must be inside the older candle.
   if(insideHigh > olderHigh ||
      insideLow < olderLow)
   {
      return false;
   }

   // Break above the mother candle.
   return currentClose > olderHigh;
}

//-------------------------------------------------------------------
// Bearish inside-bar breakout
//-------------------------------------------------------------------
bool PA_BearishInsideBreak(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift)
{
   if(!ICT_ENABLE_INSIDE_BAR)
      return false;

   if(shift < 1)
      return false;

   double currentLow =
      PA_Low(symbol,timeframe,shift);

   double currentClose =
      PA_Close(symbol,timeframe,shift);

   double insideHigh =
      PA_High(symbol,timeframe,shift + 1);

   double insideLow =
      PA_Low(symbol,timeframe,shift + 1);

   double olderHigh =
      PA_High(symbol,timeframe,shift + 2);

   double olderLow =
      PA_Low(symbol,timeframe,shift + 2);

   if(currentLow <= 0.0 ||
      currentClose <= 0.0 ||
      insideHigh <= 0.0 ||
      insideLow <= 0.0 ||
      olderHigh <= 0.0 ||
      olderLow <= 0.0)
   {
      return false;
   }

   if(insideHigh > olderHigh ||
      insideLow < olderLow)
   {
      return false;
   }

   // Break below the mother candle.
   return currentClose < olderLow;
}

//-------------------------------------------------------------------
// Find strongest bullish pattern
//-------------------------------------------------------------------
ENUM_PRICE_ACTION_PATTERN PA_FindBullishPattern(
   const PriceActionAnalysis &p)
{
   if(p.bullishEngulfing)
      return PA_PATTERN_BULLISH_ENGULFING;

   if(p.bullishPinBar)
      return PA_PATTERN_BULLISH_PIN_BAR;

   if(p.bullishRejection)
      return PA_PATTERN_BULLISH_REJECTION;

   if(p.bullishMomentum)
      return PA_PATTERN_BULLISH_MOMENTUM;

   if(p.bullishInsideBreak)
      return PA_PATTERN_BULLISH_INSIDE_BREAK;

   return PA_PATTERN_NONE;
}

//-------------------------------------------------------------------
// Find strongest bearish pattern
//-------------------------------------------------------------------
ENUM_PRICE_ACTION_PATTERN PA_FindBearishPattern(
   const PriceActionAnalysis &p)
{
   if(p.bearishEngulfing)
      return PA_PATTERN_BEARISH_ENGULFING;

   if(p.bearishPinBar)
      return PA_PATTERN_BEARISH_PIN_BAR;

   if(p.bearishRejection)
      return PA_PATTERN_BEARISH_REJECTION;

   if(p.bearishMomentum)
      return PA_PATTERN_BEARISH_MOMENTUM;

   if(p.bearishInsideBreak)
      return PA_PATTERN_BEARISH_INSIDE_BREAK;

   return PA_PATTERN_NONE;
}

//-------------------------------------------------------------------
// Calculate price-action score
//-------------------------------------------------------------------
double PA_CalculateScore(
   const PriceActionAnalysis &p)
{
   if(!p.valid)
      return 0.0;

   double bullishScore = 0.0;
   double bearishScore = 0.0;

   if(p.bullishEngulfing)
      bullishScore += 20.0;

   if(p.bearishEngulfing)
      bearishScore += 20.0;

   if(p.bullishPinBar)
      bullishScore += 15.0;

   if(p.bearishPinBar)
      bearishScore += 15.0;

   if(p.bullishRejection)
      bullishScore += 10.0;

   if(p.bearishRejection)
      bearishScore += 10.0;

   if(p.bullishMomentum)
      bullishScore += 15.0;

   if(p.bearishMomentum)
      bearishScore += 15.0;

   if(p.bullishInsideBreak)
      bullishScore += 15.0;

   if(p.bearishInsideBreak)
      bearishScore += 15.0;

   if(p.strongBullishBody)
      bullishScore += 5.0;

   if(p.strongBearishBody)
      bearishScore += 5.0;

   if(p.direction == PA_DIRECTION_BULLISH)
      return bullishScore;

   if(p.direction == PA_DIRECTION_BEARISH)
      return bearishScore;

   return MathMax(
      bullishScore,
      bearishScore);
}

//-------------------------------------------------------------------
// Analyze price action
//-------------------------------------------------------------------
bool PA_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   PriceActionAnalysis &out)
{
   ResetPriceActionAnalysis(out);

   if(!PA_IsGold(symbol))
      return false;

   if(shift < 1)
      return false;

   if(Bars(symbol,timeframe) < shift + 5)
      return false;

   out.signalShift = shift;

   out.signalTime =
      PA_Time(
         symbol,
         timeframe,
         shift);

   if(out.signalTime <= 0)
      return false;

   // ---------------------------------------------------------------
   // Candle measurements
   // ---------------------------------------------------------------
   out.open =
      PA_Open(symbol,timeframe,shift);

   out.high =
      PA_High(symbol,timeframe,shift);

   out.low =
      PA_Low(symbol,timeframe,shift);

   out.close =
      PA_Close(symbol,timeframe,shift);

   out.range =
      PA_Range(symbol,timeframe,shift);

   out.body =
      PA_Body(symbol,timeframe,shift);

   out.bodyRatio =
      PA_BodyRatio(symbol,timeframe,shift);

   out.upperWick =
      PA_UpperWick(symbol,timeframe,shift);

   out.lowerWick =
      PA_LowerWick(symbol,timeframe,shift);

   if(out.range <= 0.0)
      return false;

   // ---------------------------------------------------------------
   // Pattern detection
   // ---------------------------------------------------------------
   out.bullishEngulfing =
      PA_BullishEngulfing(
         symbol,
         timeframe,
         shift);

   out.bearishEngulfing =
      PA_BearishEngulfing(
         symbol,
         timeframe,
         shift);

   out.bullishPinBar =
      PA_BullishPinBar(
         symbol,
         timeframe,
         shift);

   out.bearishPinBar =
      PA_BearishPinBar(
         symbol,
         timeframe,
         shift);

   out.bullishRejection =
      PA_BullishRejection(
         symbol,
         timeframe,
         shift);

   out.bearishRejection =
      PA_BearishRejection(
         symbol,
         timeframe,
         shift);

   out.bullishMomentum =
      PA_BullishMomentum(
         symbol,
         timeframe,
         shift);

   out.bearishMomentum =
      PA_BearishMomentum(
         symbol,
         timeframe,
         shift);

   out.bullishInsideBreak =
      PA_BullishInsideBreak(
         symbol,
         timeframe,
         shift);

   out.bearishInsideBreak =
      PA_BearishInsideBreak(
         symbol,
         timeframe,
         shift);

   out.strongBullishBody =
      PA_StrongBullishBody(
         symbol,
         timeframe,
         shift);

   out.strongBearishBody =
      PA_StrongBearishBody(
         symbol,
         timeframe,
         shift);

   // ---------------------------------------------------------------
   // Determine direction
   // ---------------------------------------------------------------
   double bullishScore = 0.0;
   double bearishScore = 0.0;

   if(out.bullishEngulfing)
      bullishScore += 20.0;

   if(out.bullishPinBar)
      bullishScore += 15.0;

   if(out.bullishRejection)
      bullishScore += 10.0;

   if(out.bullishMomentum)
      bullishScore += 15.0;

   if(out.bullishInsideBreak)
      bullishScore += 15.0;

   if(out.strongBullishBody)
      bullishScore += 5.0;

   if(out.bearishEngulfing)
      bearishScore += 20.0;

   if(out.bearishPinBar)
      bearishScore += 15.0;

   if(out.bearishRejection)
      bearishScore += 10.0;

   if(out.bearishMomentum)
      bearishScore += 15.0;

   if(out.bearishInsideBreak)
      bearishScore += 15.0;

   if(out.strongBearishBody)
      bearishScore += 5.0;

   if(bullishScore > bearishScore &&
      bullishScore > 0.0)
   {
      out.direction =
         PA_DIRECTION_BULLISH;

      out.primaryPattern =
         PA_FindBullishPattern(out);
   }
   else if(bearishScore > bullishScore &&
           bearishScore > 0.0)
   {
      out.direction =
         PA_DIRECTION_BEARISH;

      out.primaryPattern =
         PA_FindBearishPattern(out);
   }
   else
   {
      out.direction =
         PA_DIRECTION_NONE;

      out.primaryPattern =
         PA_PATTERN_NONE;
   }

   out.valid = true;

   out.score =
      PA_CalculateScore(out);

   out.reason =
      "Gold price-action analysis completed.";

   out.evidence =
      "Pattern=" +
      PA_PatternToString(
         out.primaryPattern);

   out.evidence +=
      " | direction=" +
      PA_DirectionToString(
         out.direction);

   out.evidence +=
      " | body ratio=" +
      DoubleToString(
         out.bodyRatio,
         2);

   out.evidence +=
      " | score=" +
      DoubleToString(
         out.score,
         1);

   return true;
}
//-------------------------------------------------------------------
// Current price-action analysis
//-------------------------------------------------------------------
bool PA_AnalyzeCurrent(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   PriceActionAnalysis &out)
{
   return PA_Analyze(
      symbol,
      timeframe,
      1,
      out);
}

//-------------------------------------------------------------------
// Pattern helpers
//-------------------------------------------------------------------
bool PA_IsBullish(
   const PriceActionAnalysis &p)
{
   return p.valid &&
          p.direction == PA_DIRECTION_BULLISH;
}

//-------------------------------------------------------------------
bool PA_IsBearish(
   const PriceActionAnalysis &p)
{
   return p.valid &&
          p.direction == PA_DIRECTION_BEARISH;
}

//-------------------------------------------------------------------
bool PA_HasEngulfing(
   const PriceActionAnalysis &p)
{
   return p.valid &&
          (p.bullishEngulfing ||
           p.bearishEngulfing);
}

//-------------------------------------------------------------------
bool PA_HasRejection(
   const PriceActionAnalysis &p)
{
   return p.valid &&
          (p.bullishRejection ||
           p.bearishRejection ||
           p.bullishPinBar ||
           p.bearishPinBar);
}

//-------------------------------------------------------------------
bool PA_HasMomentum(
   const PriceActionAnalysis &p)
{
   return p.valid &&
          (p.bullishMomentum ||
           p.bearishMomentum ||
           p.strongBullishBody ||
           p.strongBearishBody);
}

//-------------------------------------------------------------------
bool PA_HasInsideBreak(
   const PriceActionAnalysis &p)
{
   return p.valid &&
          (p.bullishInsideBreak ||
           p.bearishInsideBreak);
}

//-------------------------------------------------------------------
// Directional pattern consistency
//-------------------------------------------------------------------
bool PA_IsDirectionallyConsistent(
   const PriceActionAnalysis &p)
{
   if(!p.valid)
      return false;

   if(p.direction == PA_DIRECTION_BULLISH)
   {
      if(p.bearishEngulfing ||
         p.bearishPinBar ||
         p.bearishRejection ||
         p.bearishMomentum ||
         p.bearishInsideBreak)
      {
         return false;
      }

      return true;
   }

   if(p.direction == PA_DIRECTION_BEARISH)
   {
      if(p.bullishEngulfing ||
         p.bullishPinBar ||
         p.bullishRejection ||
         p.bullishMomentum ||
         p.bullishInsideBreak)
      {
         return false;
      }

      return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Actionability
//-------------------------------------------------------------------
bool PA_IsActionable(
   const PriceActionAnalysis &p)
{
   if(!p.valid)
      return false;

   if(!PA_IsDirectionallyConsistent(p))
      return false;

   // Price action must have at least one meaningful
   // directional pattern.
   int confirmations = 0;

   if(p.bullishEngulfing ||
      p.bearishEngulfing)
   {
      confirmations++;
   }

   if(p.bullishPinBar ||
      p.bearishPinBar)
   {
      confirmations++;
   }

   if(p.bullishRejection ||
      p.bearishRejection)
   {
      confirmations++;
   }

   if(p.bullishMomentum ||
      p.bearishMomentum)
   {
      confirmations++;
   }

   if(p.bullishInsideBreak ||
      p.bearishInsideBreak)
   {
      confirmations++;
   }

   return confirmations >= 1;
}

//-------------------------------------------------------------------
// Price-action score
//-------------------------------------------------------------------
double PA_Score(
   const PriceActionAnalysis &p)
{
   if(!p.valid)
      return 0.0;

   return p.score;
}

//-------------------------------------------------------------------
// Description
//-------------------------------------------------------------------
string PA_Description(
   const PriceActionAnalysis &p)
{
   if(!p.valid)
      return "No valid price-action analysis.";

   string description =
      "Direction=" +
      PA_DirectionToString(
         p.direction);

   description +=
      " | Primary=" +
      PA_PatternToString(
         p.primaryPattern);

   description +=
      " | Score=" +
      DoubleToString(
         p.score,
         1);

   return description;
}

//-------------------------------------------------------------------
// Print analysis
//-------------------------------------------------------------------
void PA_Print(
   const PriceActionAnalysis &p)
{
   if(!p.valid)
   {
      Print(
         "PriceActionEngine: no valid analysis."
      );

      return;
   }

   Print(
      "PriceActionEngine: ",
      PA_DirectionToString(p.direction),
      " | pattern=",
      PA_PatternToString(p.primaryPattern),
      " | score=",
      DoubleToString(p.score,1),
      " | bodyRatio=",
      DoubleToString(p.bodyRatio,2),
      " | actionable=",
      PA_IsActionable(p) ? "YES" : "NO"
   );

   Print(
      "PriceActionEngine evidence: ",
      p.evidence
   );
}

//-------------------------------------------------------------------
// Status
//-------------------------------------------------------------------
string PA_Status(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   if(!PA_IsGold(symbol))
      return "NON-GOLD SYMBOL";

   PriceActionAnalysis p;

   if(!PA_AnalyzeCurrent(
         symbol,
         timeframe,
         p))
   {
      return "NO PRICE-ACTION DATA";
   }

   if(!p.valid)
      return "INVALID";

   if(PA_IsBullish(p))
      return "BULLISH PRICE ACTION";

   if(PA_IsBearish(p))
      return "BEARISH PRICE ACTION";

   return "NEUTRAL PRICE ACTION";
}

//-------------------------------------------------------------------
// Ready for confluence
//-------------------------------------------------------------------
bool PA_ReadyForConfluence(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   if(!PA_IsGold(symbol))
      return false;

   PriceActionAnalysis p;

   if(!PA_Analyze(
         symbol,
         timeframe,
         shift,
         p))
   {
      return false;
   }

   return PA_IsActionable(p);
}

//-------------------------------------------------------------------
// Direction-specific readiness
//-------------------------------------------------------------------
bool PA_ReadyBullish(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   PriceActionAnalysis p;

   if(!PA_Analyze(
         symbol,
         timeframe,
         shift,
         p))
   {
      return false;
   }

   return PA_IsActionable(p) &&
          PA_IsBullish(p);
}

//-------------------------------------------------------------------
bool PA_ReadyBearish(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift = 1)
{
   PriceActionAnalysis p;

   if(!PA_Analyze(
         symbol,
         timeframe,
         shift,
         p))
   {
      return false;
   }

   return PA_IsActionable(p) &&
          PA_IsBearish(p);
}

#endif
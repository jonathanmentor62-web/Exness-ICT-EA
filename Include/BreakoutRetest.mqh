//+------------------------------------------------------------------+
//| BreakoutRetest.mqh                                               |
//| Gold Multi-Strategy EA - Breakout / Retest Engine                |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_BREAKOUT_RETEST_MQH__
#define __EXNESS_GOLD_BREAKOUT_RETEST_MQH__

#include "Config.mqh"

//====================================================================
// BREAKOUT DIRECTION
//====================================================================

enum ENUM_BREAKOUT_DIRECTION
{
   BREAKOUT_NONE = 0,
   BREAKOUT_BULLISH,
   BREAKOUT_BEARISH
};

//====================================================================
// BREAKOUT RESULT
//====================================================================

struct BreakoutRetestSignal
{
   bool valid;

   ENUM_BREAKOUT_DIRECTION direction;

   bool breakoutConfirmed;
   bool strongBreakout;

   bool retestDetected;
   bool retestConfirmed;

   bool failedBreakout;
   bool rangeBreakout;

   bool supportResistanceRetest;
   bool previousLevelRetest;

   bool liquidityGrab;

   double breakoutLevel;
   double retestLevel;

   double rangeHigh;
   double rangeLow;

   double entryZoneHigh;
   double entryZoneLow;

   double score;

   datetime breakoutTime;
   datetime retestTime;

   int breakoutShift;
   int retestShift;

   string reason;
   string evidence;
};

//====================================================================
// RESET
//====================================================================

void BR_Reset(
   BreakoutRetestSignal &signal
)
{
   signal.valid = false;

   signal.direction =
      BREAKOUT_NONE;

   signal.breakoutConfirmed = false;
   signal.strongBreakout = false;

   signal.retestDetected = false;
   signal.retestConfirmed = false;

   signal.failedBreakout = false;
   signal.rangeBreakout = false;

   signal.supportResistanceRetest = false;
   signal.previousLevelRetest = false;

   signal.liquidityGrab = false;

   signal.breakoutLevel = 0.0;
   signal.retestLevel = 0.0;

   signal.rangeHigh = 0.0;
   signal.rangeLow = 0.0;

   signal.entryZoneHigh = 0.0;
   signal.entryZoneLow = 0.0;

   signal.score = 0.0;

   signal.breakoutTime = 0;
   signal.retestTime = 0;

   signal.breakoutShift = -1;
   signal.retestShift = -1;

   signal.reason = "";
   signal.evidence = "";
}

//====================================================================
// GOLD CHECK
//====================================================================

bool BR_IsGold(
   const string symbol
)
{
   string upper = symbol;

   StringToUpper(
      upper
   );

   return StringFind(
      upper,
      ICT_GOLD_SYMBOL_PREFIX
   ) == 0;
}

//====================================================================
// ADD SCORE
//====================================================================

void BR_AddScore(
   BreakoutRetestSignal &signal,
   const double points,
   const string evidence
)
{
   if(points > 0.0)
      signal.score += points;

   if(signal.score > 100.0)
      signal.score = 100.0;

   if(evidence != "")
   {
      if(signal.evidence == "")
         signal.evidence = evidence;
      else
         signal.evidence +=
            " | " + evidence;
   }
}

//====================================================================
// CANDLE RANGE
//====================================================================

double BR_Range(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
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

   if(
      high <= 0.0 ||
      low <= 0.0 ||
      high < low
   )
      return 0.0;

   return high - low;
}

//====================================================================
// CANDLE BODY
//====================================================================

double BR_Body(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
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

   if(
      open <= 0.0 ||
      close <= 0.0
   )
      return 0.0;

   return MathAbs(
      close - open
   );
}

//====================================================================
// BODY RATIO
//====================================================================

double BR_BodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double range =
      BR_Range(
         symbol,
         timeframe,
         shift
      );

   if(range <= 0.0)
      return 0.0;

   return
      BR_Body(
         symbol,
         timeframe,
         shift
      ) / range;
}

//====================================================================
// BULLISH CANDLE
//====================================================================

bool BR_IsBullish(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   return
      iClose(
         symbol,
         timeframe,
         shift
      ) >
      iOpen(
         symbol,
         timeframe,
         shift
      );
}

//====================================================================
// BEARISH CANDLE
//====================================================================

bool BR_IsBearish(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   return
      iClose(
         symbol,
         timeframe,
         shift
      ) <
      iOpen(
         symbol,
         timeframe,
         shift
      );
}

//====================================================================
// HIGHEST HIGH
//====================================================================

double BR_Highest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int startShift,
   const int count
)
{
   if(count <= 0)
      return 0.0;

   double highest = 0.0;

   for(
      int shift = startShift;
      shift < startShift + count;
      shift++
   )
   {
      double high =
         iHigh(
            symbol,
            timeframe,
            shift
         );

      if(high > highest)
         highest = high;
   }

   return highest;
}

//====================================================================
// LOWEST LOW
//====================================================================

double BR_Lowest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int startShift,
   const int count
)
{
   if(count <= 0)
      return 0.0;

   double lowest = 0.0;

   for(
      int shift = startShift;
      shift < startShift + count;
      shift++
   )
   {
      double low =
         iLow(
            symbol,
            timeframe,
            shift
         );

      if(low <= 0.0)
         continue;

      if(
         lowest <= 0.0 ||
         low < lowest
      )
      {
         lowest = low;
      }
   }

   return lowest;
}

//====================================================================
// RANGE DETECTION
//====================================================================

bool BR_FindRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   double &rangeHigh,
   double &rangeLow
)
{
   rangeHigh = 0.0;
   rangeLow = 0.0;

   if(lookback < 3)
      return false;

   rangeHigh =
      BR_Highest(
         symbol,
         timeframe,
         2,
         lookback
      );

   rangeLow =
      BR_Lowest(
         symbol,
         timeframe,
         2,
         lookback
      );

   if(
      rangeHigh <= 0.0 ||
      rangeLow <= 0.0 ||
      rangeHigh <= rangeLow
   )
      return false;

   return true;
}
//====================================================================
// BULLISH BREAKOUT
//====================================================================

bool BR_DetectBullishBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   if(!BR_IsGold(symbol))
      return false;

   double rangeHigh = 0.0;
   double rangeLow  = 0.0;

   if(!BR_FindRange(
      symbol,
      timeframe,
      lookback,
      rangeHigh,
      rangeLow
   ))
      return false;

   double close =
      iClose(
         symbol,
         timeframe,
         1
      );

   double high =
      iHigh(
         symbol,
         timeframe,
         1
      );

   if(
      close <= 0.0 ||
      high <= 0.0
   )
      return false;

   //-----------------------------------------------------------------
   // CLOSE ABOVE RANGE HIGH
   //-----------------------------------------------------------------

   if(close <= rangeHigh)
      return false;

   signal.direction =
      BREAKOUT_BULLISH;

   signal.breakoutConfirmed = true;
   signal.rangeBreakout = true;

   signal.breakoutLevel =
      rangeHigh;

   signal.rangeHigh =
      rangeHigh;

   signal.rangeLow =
      rangeLow;

   signal.breakoutShift = 1;

   signal.breakoutTime =
      iTime(
         symbol,
         timeframe,
         1
      );

   //-----------------------------------------------------------------
   // BREAKOUT STRENGTH
   //-----------------------------------------------------------------

   double bodyRatio =
      BR_BodyRatio(
         symbol,
         timeframe,
         1
      );

   if(bodyRatio >= ICT_RETEST_MIN_BODY_RATIO)
   {
      signal.strongBreakout = true;

      BR_AddScore(
         signal,
         20.0,
         "Strong bullish breakout"
      );
   }
   else
   {
      BR_AddScore(
         signal,
         10.0,
         "Bullish breakout"
      );
   }

   signal.valid = true;

   return true;
}

//====================================================================
// BEARISH BREAKOUT
//====================================================================

bool BR_DetectBearishBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   if(!BR_IsGold(symbol))
      return false;

   double rangeHigh = 0.0;
   double rangeLow  = 0.0;

   if(!BR_FindRange(
      symbol,
      timeframe,
      lookback,
      rangeHigh,
      rangeLow
   ))
      return false;

   double close =
      iClose(
         symbol,
         timeframe,
         1
      );

   double low =
      iLow(
         symbol,
         timeframe,
         1
      );

   if(
      close <= 0.0 ||
      low <= 0.0
   )
      return false;

   //-----------------------------------------------------------------
   // CLOSE BELOW RANGE LOW
   //-----------------------------------------------------------------

   if(close >= rangeLow)
      return false;

   signal.direction =
      BREAKOUT_BEARISH;

   signal.breakoutConfirmed = true;
   signal.rangeBreakout = true;

   signal.breakoutLevel =
      rangeLow;

   signal.rangeHigh =
      rangeHigh;

   signal.rangeLow =
      rangeLow;

   signal.breakoutShift = 1;

   signal.breakoutTime =
      iTime(
         symbol,
         timeframe,
         1
      );

   //-----------------------------------------------------------------
   // BREAKOUT STRENGTH
   //-----------------------------------------------------------------

   double bodyRatio =
      BR_BodyRatio(
         symbol,
         timeframe,
         1
      );

   if(bodyRatio >= ICT_RETEST_MIN_BODY_RATIO)
   {
      signal.strongBreakout = true;

      BR_AddScore(
         signal,
         20.0,
         "Strong bearish breakout"
      );
   }
   else
   {
      BR_AddScore(
         signal,
         10.0,
         "Bearish breakout"
      );
   }

   signal.valid = true;

   return true;
}

//====================================================================
// GENERIC BREAKOUT DETECTION
//====================================================================

bool BR_DetectBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   BR_Reset(signal);

   if(!ICT_ENABLE_BREAKOUT)
      return false;

   //-----------------------------------------------------------------
   // BULLISH FIRST
   //-----------------------------------------------------------------

   if(BR_DetectBullishBreakout(
      symbol,
      timeframe,
      lookback,
      signal
   ))
   {
      return true;
   }

   //-----------------------------------------------------------------
   // RESET BEFORE BEARISH TEST
   //-----------------------------------------------------------------

   BR_Reset(signal);

   //-----------------------------------------------------------------
   // BEARISH
   //-----------------------------------------------------------------

   if(BR_DetectBearishBreakout(
      symbol,
      timeframe,
      lookback,
      signal
   ))
   {
      return true;
   }

   return false;
}

//====================================================================
// BREAKOUT LEVEL VALIDATION
//====================================================================

bool BR_IsAboveBreakoutLevel(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const double level
)
{
   double close =
      iClose(
         symbol,
         timeframe,
         shift
      );

   return
      close > 0.0 &&
      level > 0.0 &&
      close > level;
}

//====================================================================
// BREAKOUT LEVEL VALIDATION
//====================================================================

bool BR_IsBelowBreakoutLevel(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift,
   const double level
)
{
   double close =
      iClose(
         symbol,
         timeframe,
         shift
      );

   return
      close > 0.0 &&
      level > 0.0 &&
      close < level;
}
//====================================================================
// BULLISH RETEST
//====================================================================

bool BR_DetectBullishRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   BreakoutRetestSignal &signal
)
{
   if(
      !signal.valid ||
      signal.direction != BREAKOUT_BULLISH ||
      !signal.breakoutConfirmed
   )
      return false;

   if(!ICT_ENABLE_RETEST)
      return false;

   double level =
      signal.breakoutLevel;

   if(level <= 0.0)
      return false;

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   if(point <= 0.0)
      return false;

   //-----------------------------------------------------------------
   // SEARCH RECENT CANDLES AFTER BREAKOUT
   //-----------------------------------------------------------------

   for(
      int shift = 1;
      shift <= ICT_RETEST_MAX_BARS;
      shift++
   )
   {
      datetime candleTime =
         iTime(
            symbol,
            timeframe,
            shift
         );

      if(candleTime <= 0)
         continue;

      if(
         signal.breakoutTime > 0 &&
         candleTime <= signal.breakoutTime
      )
         continue;

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

      double close =
         iClose(
            symbol,
            timeframe,
            shift
         );

      if(
         high <= 0.0 ||
         low <= 0.0 ||
         close <= 0.0
      )
         continue;

      //----------------------------------------------------------------
      // PRICE MUST TOUCH THE OLD RESISTANCE
      //----------------------------------------------------------------

      bool touched =
         low <= level;

      if(!touched)
         continue;

      //----------------------------------------------------------------
      // PRICE MUST CLOSE BACK ABOVE THE LEVEL
      //----------------------------------------------------------------

      bool held =
         close > level;

      if(!held)
         continue;

      signal.retestDetected = true;
      signal.retestConfirmed = true;

      signal.supportResistanceRetest = true;
      signal.previousLevelRetest = true;

      signal.retestLevel = level;

      signal.retestShift = shift;
      signal.retestTime = candleTime;

      signal.entryZoneLow =
         MathMin(
            low,
            level
         );

      signal.entryZoneHigh =
         MathMax(
            high,
            level
         );

      BR_AddScore(
         signal,
         20.0,
         "Bullish breakout retest"
      );

      signal.valid = true;

      return true;
   }

   return false;
}

//====================================================================
// BEARISH RETEST
//====================================================================

bool BR_DetectBearishRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   BreakoutRetestSignal &signal
)
{
   if(
      !signal.valid ||
      signal.direction != BREAKOUT_BEARISH ||
      !signal.breakoutConfirmed
   )
      return false;

   if(!ICT_ENABLE_RETEST)
      return false;

   double level =
      signal.breakoutLevel;

   if(level <= 0.0)
      return false;

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   if(point <= 0.0)
      return false;

   //-----------------------------------------------------------------
   // SEARCH RECENT CANDLES AFTER BREAKOUT
   //-----------------------------------------------------------------

   for(
      int shift = 1;
      shift <= ICT_RETEST_MAX_BARS;
      shift++
   )
   {
      datetime candleTime =
         iTime(
            symbol,
            timeframe,
            shift
         );

      if(candleTime <= 0)
         continue;

      if(
         signal.breakoutTime > 0 &&
         candleTime <= signal.breakoutTime
      )
         continue;

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

      double close =
         iClose(
            symbol,
            timeframe,
            shift
         );

      if(
         high <= 0.0 ||
         low <= 0.0 ||
         close <= 0.0
      )
         continue;

      //----------------------------------------------------------------
      // PRICE MUST TOUCH THE OLD SUPPORT
      //----------------------------------------------------------------

      bool touched =
         high >= level;

      if(!touched)
         continue;

      //----------------------------------------------------------------
      // PRICE MUST CLOSE BACK BELOW THE LEVEL
      //----------------------------------------------------------------

      bool held =
         close < level;

      if(!held)
         continue;

      signal.retestDetected = true;
      signal.retestConfirmed = true;

      signal.supportResistanceRetest = true;
      signal.previousLevelRetest = true;

      signal.retestLevel = level;

      signal.retestShift = shift;
      signal.retestTime = candleTime;

      signal.entryZoneLow =
         MathMin(
            low,
            level
         );

      signal.entryZoneHigh =
         MathMax(
            high,
            level
         );

      BR_AddScore(
         signal,
         20.0,
         "Bearish breakout retest"
      );

      signal.valid = true;

      return true;
   }

   return false;
}

//====================================================================
// GENERIC RETEST DETECTION
//====================================================================

bool BR_DetectRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   BreakoutRetestSignal &signal
)
{
   if(
      !signal.valid ||
      !signal.breakoutConfirmed
   )
      return false;

   if(
      signal.direction ==
      BREAKOUT_BULLISH
   )
   {
      return BR_DetectBullishRetest(
         symbol,
         timeframe,
         signal
      );
   }

   if(
      signal.direction ==
      BREAKOUT_BEARISH
   )
   {
      return BR_DetectBearishRetest(
         symbol,
         timeframe,
         signal
      );
   }

   return false;
}
//====================================================================
// FAILED BULLISH BREAKOUT
//====================================================================

bool BR_DetectFailedBullishBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   if(!BR_IsGold(symbol))
      return false;

   double rangeHigh = 0.0;
   double rangeLow  = 0.0;

   if(!BR_FindRange(
      symbol,
      timeframe,
      lookback,
      rangeHigh,
      rangeLow
   ))
      return false;

   //-----------------------------------------------------------------
   // PREVIOUS CLOSED CANDLE
   //-----------------------------------------------------------------

   double high =
      iHigh(
         symbol,
         timeframe,
         1
      );

   double close =
      iClose(
         symbol,
         timeframe,
         1
      );

   if(
      high <= 0.0 ||
      close <= 0.0
   )
      return false;

   //-----------------------------------------------------------------
   // PRICE TOOK THE HIGH BUT CLOSED BACK BELOW IT
   //-----------------------------------------------------------------

   if(
      high <= rangeHigh ||
      close >= rangeHigh
   )
      return false;

   signal.valid = true;

   signal.direction =
      BREAKOUT_BEARISH;

   signal.breakoutConfirmed = true;

   signal.failedBreakout = true;
   signal.liquidityGrab = true;

   signal.breakoutLevel =
      rangeHigh;

   signal.rangeHigh =
      rangeHigh;

   signal.rangeLow =
      rangeLow;

   signal.breakoutShift = 1;

   signal.breakoutTime =
      iTime(
         symbol,
         timeframe,
         1
      );

   signal.entryZoneLow =
      MathMin(
         close,
         rangeHigh
      );

   signal.entryZoneHigh =
      MathMax(
         high,
         rangeHigh
      );

   BR_AddScore(
      signal,
      20.0,
      "Failed bullish breakout"
   );

   BR_AddScore(
      signal,
      10.0,
      "Buy-side liquidity grab"
   );

   signal.reason =
      "Bullish breakout failed; bearish reversal candidate.";

   return true;
}

//====================================================================
// FAILED BEARISH BREAKOUT
//====================================================================

bool BR_DetectFailedBearishBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   if(!BR_IsGold(symbol))
      return false;

   double rangeHigh = 0.0;
   double rangeLow  = 0.0;

   if(!BR_FindRange(
      symbol,
      timeframe,
      lookback,
      rangeHigh,
      rangeLow
   ))
      return false;

   //-----------------------------------------------------------------
   // PREVIOUS CLOSED CANDLE
   //-----------------------------------------------------------------

   double low =
      iLow(
         symbol,
         timeframe,
         1
      );

   double close =
      iClose(
         symbol,
         timeframe,
         1
      );

   if(
      low <= 0.0 ||
      close <= 0.0
   )
      return false;

   //-----------------------------------------------------------------
   // PRICE TOOK THE LOW BUT CLOSED BACK ABOVE IT
   //-----------------------------------------------------------------

   if(
      low >= rangeLow ||
      close <= rangeLow
   )
      return false;

   signal.valid = true;

   signal.direction =
      BREAKOUT_BULLISH;

   signal.breakoutConfirmed = true;

   signal.failedBreakout = true;
   signal.liquidityGrab = true;

   signal.breakoutLevel =
      rangeLow;

   signal.rangeHigh =
      rangeHigh;

   signal.rangeLow =
      rangeLow;

   signal.breakoutShift = 1;

   signal.breakoutTime =
      iTime(
         symbol,
         timeframe,
         1
      );

   signal.entryZoneLow =
      MathMin(
         low,
         rangeLow
      );

   signal.entryZoneHigh =
      MathMax(
         close,
         rangeLow
      );

   BR_AddScore(
      signal,
      20.0,
      "Failed bearish breakout"
   );

   BR_AddScore(
      signal,
      10.0,
      "Sell-side liquidity grab"
   );

   signal.reason =
      "Bearish breakout failed; bullish reversal candidate.";

   return true;
}

//====================================================================
// GENERIC FAILED BREAKOUT
//====================================================================

bool BR_DetectFailedBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   BR_Reset(signal);

   if(!ICT_ENABLE_FAILED_BREAKOUT)
      return false;

   //-----------------------------------------------------------------
   // FAILED BULLISH BREAKOUT
   //-----------------------------------------------------------------

   if(BR_DetectFailedBullishBreakout(
      symbol,
      timeframe,
      lookback,
      signal
   ))
   {
      return true;
   }

   //-----------------------------------------------------------------
   // RESET
   //-----------------------------------------------------------------

   BR_Reset(signal);

   //-----------------------------------------------------------------
   // FAILED BEARISH BREAKOUT
   //-----------------------------------------------------------------

   if(BR_DetectFailedBearishBreakout(
      symbol,
      timeframe,
      lookback,
      signal
   ))
   {
      return true;
   }

   return false;
}

//====================================================================
// VALIDATE FAILED BREAKOUT
//====================================================================

bool BR_IsFailedBreakoutReversal(
   const BreakoutRetestSignal &signal
)
{
   return
      signal.valid &&
      signal.failedBreakout &&
      signal.liquidityGrab &&
      (
         signal.direction ==
         BREAKOUT_BULLISH
         ||
         signal.direction ==
         BREAKOUT_BEARISH
      );
}
//====================================================================
// ANALYZE BREAKOUT + RETEST
//====================================================================

bool BR_AnalyzeBreakoutRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   BreakoutRetestSignal &signal
)
{
   BR_Reset(signal);

   if(!BR_IsGold(symbol))
   {
      signal.reason =
         "Rejected: non-Gold symbol.";

      return false;
   }

   if(
      !ICT_ENABLE_BREAKOUT &&
      !ICT_ENABLE_RETEST &&
      !ICT_ENABLE_FAILED_BREAKOUT
   )
   {
      signal.reason =
         "Breakout strategies disabled.";

      return false;
   }

   //-----------------------------------------------------------------
   // FAILED BREAKOUT HAS PRIORITY
   //-----------------------------------------------------------------

   BreakoutRetestSignal failed;

   BR_Reset(failed);

   if(
      ICT_ENABLE_FAILED_BREAKOUT &&
      BR_DetectFailedBreakout(
         symbol,
         timeframe,
         lookback,
         failed
      )
   )
   {
      signal = failed;

      signal.reason =
         "Failed breakout / liquidity-grab reversal detected.";

      return true;
   }

   //-----------------------------------------------------------------
   // NORMAL BREAKOUT
   //-----------------------------------------------------------------

   BreakoutRetestSignal breakout;

   BR_Reset(breakout);

   if(
      !BR_DetectBreakout(
         symbol,
         timeframe,
         lookback,
         breakout
      )
   )
   {
      signal.reason =
         "No valid breakout detected.";

      return false;
   }

   //-----------------------------------------------------------------
   // RETEST
   //-----------------------------------------------------------------

   if(
      ICT_ENABLE_RETEST &&
      BR_DetectRetest(
         symbol,
         timeframe,
         breakout
      )
   )
   {
      breakout.retestConfirmed = true;

      BR_AddScore(
         breakout,
         10.0,
         "Confirmed breakout + retest"
      );

      breakout.reason =
         "Breakout followed by confirmed retest.";
   }
   else
   {
      breakout.reason =
         "Breakout detected; retest not yet confirmed.";
   }

   //-----------------------------------------------------------------
   // FINAL VALIDATION
   //-----------------------------------------------------------------

   if(
      breakout.score <
      20.0
   )
   {
      breakout.valid = false;

      return false;
   }

   breakout.valid = true;

   signal = breakout;

   return true;
}

//====================================================================
// BREAKOUT SIGNAL QUALITY
//====================================================================

string BR_Quality(
   const BreakoutRetestSignal &signal
)
{
   if(!signal.valid)
      return "INVALID";

   if(signal.score >= 70.0)
      return "HIGH";

   if(signal.score >= 50.0)
      return "STRONG";

   if(signal.score >= 30.0)
      return "MODERATE";

   return "WEAK";
}

//====================================================================
// BREAKOUT DIRECTION TO STRING
//====================================================================

string BR_DirectionToString(
   const ENUM_BREAKOUT_DIRECTION direction
)
{
   switch(direction)
   {
      case BREAKOUT_BULLISH:
         return "BUY";

      case BREAKOUT_BEARISH:
         return "SELL";

      default:
         return "NONE";
   }
}

//====================================================================
// BREAKOUT DESCRIPTION
//====================================================================

string BR_Description(
   const BreakoutRetestSignal &signal
)
{
   string text =
      BR_DirectionToString(
         signal.direction
      );

   text +=
      " | Score=" +
      DoubleToString(
         signal.score,
         1
      );

   text +=
      " | Quality=" +
      BR_Quality(
         signal
      );

   if(signal.breakoutConfirmed)
      text += " | Breakout";

   if(signal.retestConfirmed)
      text += " | Retest";

   if(signal.failedBreakout)
      text += " | Failed Breakout";

   if(signal.liquidityGrab)
      text += " | Liquidity Grab";

   return text;
}

//====================================================================
// PRINT BREAKOUT RESULT
//====================================================================

void BR_PrintResult(
   const BreakoutRetestSignal &signal
)
{
   Print(
      "[BREAKOUT] ",
      BR_Description(signal)
   );

   Print(
      "[BREAKOUT] Level=",
      DoubleToString(
         signal.breakoutLevel,
         _Digits
      ),
      " | Retest=",
      DoubleToString(
         signal.retestLevel,
         _Digits
      )
   );

   Print(
      "[BREAKOUT] Zone=",
      DoubleToString(
         signal.entryZoneLow,
         _Digits
      ),
      " - ",
      DoubleToString(
         signal.entryZoneHigh,
         _Digits
      )
   );

   if(signal.reason != "")
   {
      Print(
         "[BREAKOUT] Reason=",
         signal.reason
      );
   }

   if(signal.evidence != "")
   {
      Print(
         "[BREAKOUT] Evidence=",
         signal.evidence
      );
   }
}

//====================================================================
// STRATEGY DIRECTION CONVERSION
//====================================================================

ENUM_STRATEGY_DIRECTION BR_ToStrategyDirection(
   const ENUM_BREAKOUT_DIRECTION direction
)
{
   if(direction == BREAKOUT_BULLISH)
      return STRATEGY_DIRECTION_BUY;

   if(direction == BREAKOUT_BEARISH)
      return STRATEGY_DIRECTION_SELL;

   return STRATEGY_DIRECTION_NONE;
}

//====================================================================
// FINAL ACTIONABILITY CHECK
//====================================================================

bool BR_IsActionable(
   const BreakoutRetestSignal &signal
)
{
   if(!signal.valid)
      return false;

   if(
      signal.direction ==
      BREAKOUT_NONE
   )
      return false;

   //-----------------------------------------------------------------
   // NORMAL BREAKOUT
   //-----------------------------------------------------------------

   if(
      signal.breakoutConfirmed &&
      signal.retestConfirmed
   )
   {
      return true;
   }

   //-----------------------------------------------------------------
   // FAILED BREAKOUT REVERSAL
   //-----------------------------------------------------------------

   if(
      signal.failedBreakout &&
      signal.liquidityGrab
   )
   {
      return true;
   }

   return false;
}

//====================================================================
// ENGINE STATUS
//====================================================================

string BR_Status()
{
   return
      "Breakout/Retest Engine | "
      "Range Breakout | "
      "Breakout Retest | "
      "Failed Breakout | "
      "Liquidity Grab Reversal";
}

#endif
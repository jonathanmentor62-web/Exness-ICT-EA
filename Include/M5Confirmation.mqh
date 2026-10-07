//+------------------------------------------------------------------+
//| M5Confirmation.mqh                                               |
//| Gold Multi-Strategy EA - Final M5 Entry Confirmation             |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_M5_CONFIRMATION_MQH__
#define __EXNESS_GOLD_M5_CONFIRMATION_MQH__

#include "StructureSignal.mqh"
#include "FVG.mqh"

//====================================================================
// M5 CONFIRMATION STRUCTURE
//====================================================================

struct M5Confirmation
{
   bool valid;

   bool bullish;
   bool bearish;

   bool displacement;
   bool mss;
   bool bos;

   bool fvgPresent;
   bool fvgRetest;

   bool retest;
   bool rejection;
   bool engulfing;
   bool momentum;

   bool structureBreak;

   double brokenLevel;
   double entryZoneLow;
   double entryZoneHigh;

   datetime signalTime;
   int signalShift;

   string reason;
};

//====================================================================
// RESET
//====================================================================

void ResetM5Confirmation(M5Confirmation &c)
{
   c.valid = false;

   c.bullish = false;
   c.bearish = false;

   c.displacement = false;
   c.mss = false;
   c.bos = false;

   c.fvgPresent = false;
   c.fvgRetest = false;

   c.retest = false;
   c.rejection = false;
   c.engulfing = false;
   c.momentum = false;

   c.structureBreak = false;

   c.brokenLevel = 0.0;
   c.entryZoneLow = 0.0;
   c.entryZoneHigh = 0.0;

   c.signalTime = 0;
   c.signalShift = -1;

   c.reason = "";
}

//====================================================================
// CANDLE HELPERS
//====================================================================

bool M5_IsBullishCandle(
   const string symbol,
   const int shift
)
{
   return iClose(symbol, ICT_ENTRY_TF, shift) >
          iOpen(symbol, ICT_ENTRY_TF, shift);
}

bool M5_IsBearishCandle(
   const string symbol,
   const int shift
)
{
   return iClose(symbol, ICT_ENTRY_TF, shift) <
          iOpen(symbol, ICT_ENTRY_TF, shift);
}

double M5_CandleRange(
   const string symbol,
   const int shift
)
{
   return iHigh(symbol, ICT_ENTRY_TF, shift) -
          iLow(symbol, ICT_ENTRY_TF, shift);
}

double M5_CandleBody(
   const string symbol,
   const int shift
)
{
   return MathAbs(
      iClose(symbol, ICT_ENTRY_TF, shift) -
      iOpen(symbol, ICT_ENTRY_TF, shift)
   );
}

double M5_BodyRatio(
   const string symbol,
   const int shift
)
{
   double range = M5_CandleRange(symbol, shift);

   if(range <= 0.0)
      return 0.0;

   return M5_CandleBody(symbol, shift) / range;
}

//====================================================================
// MOMENTUM CANDLE
//====================================================================

bool M5_IsMomentumCandle(
   const string symbol,
   const int shift,
   const ENUM_STRUCTURE_DIRECTION direction
)
{
   double ratio = M5_BodyRatio(symbol, shift);

   if(ratio < ICT_MIN_BODY_RATIO)
      return false;

   if(direction == STRUCTURE_BULLISH)
      return M5_IsBullishCandle(symbol, shift);

   if(direction == STRUCTURE_BEARISH)
      return M5_IsBearishCandle(symbol, shift);

   return false;
}

//====================================================================
// ENGULFING
//====================================================================

bool M5_IsBullishEngulfing(
   const string symbol,
   const int shift
)
{
   if(shift < 1)
      return false;

   if(!M5_IsBullishCandle(symbol, shift))
      return false;

   if(!M5_IsBearishCandle(symbol, shift + 1))
      return false;

   double currentOpen  = iOpen(symbol, ICT_ENTRY_TF, shift);
   double currentClose = iClose(symbol, ICT_ENTRY_TF, shift);

   double previousOpen  = iOpen(symbol, ICT_ENTRY_TF, shift + 1);
   double previousClose = iClose(symbol, ICT_ENTRY_TF, shift + 1);

   return currentOpen <= previousClose &&
          currentClose >= previousOpen;
}

bool M5_IsBearishEngulfing(
   const string symbol,
   const int shift
)
{
   if(shift < 1)
      return false;

   if(!M5_IsBearishCandle(symbol, shift))
      return false;

   if(!M5_IsBullishCandle(symbol, shift + 1))
      return false;

   double currentOpen  = iOpen(symbol, ICT_ENTRY_TF, shift);
   double currentClose = iClose(symbol, ICT_ENTRY_TF, shift);

   double previousOpen  = iOpen(symbol, ICT_ENTRY_TF, shift + 1);
   double previousClose = iClose(symbol, ICT_ENTRY_TF, shift + 1);

   return currentOpen >= previousClose &&
          currentClose <= previousOpen;
}

//====================================================================
// REJECTION CANDLE
//====================================================================

bool M5_IsBullishRejection(
   const string symbol,
   const int shift
)
{
   double high  = iHigh(symbol, ICT_ENTRY_TF, shift);
   double low   = iLow(symbol, ICT_ENTRY_TF, shift);
   double open  = iOpen(symbol, ICT_ENTRY_TF, shift);
   double close = iClose(symbol, ICT_ENTRY_TF, shift);

   double range = high - low;

   if(range <= 0.0)
      return false;

   double body = MathAbs(close - open);
   double lowerWick = MathMin(open, close) - low;

   if(lowerWick <= 0.0)
      return false;

   if(close < open)
      return false;

   return lowerWick >= body &&
          lowerWick >= range * 0.30;
}

bool M5_IsBearishRejection(
   const string symbol,
   const int shift
)
{
   double high  = iHigh(symbol, ICT_ENTRY_TF, shift);
   double low   = iLow(symbol, ICT_ENTRY_TF, shift);
   double open  = iOpen(symbol, ICT_ENTRY_TF, shift);
   double close = iClose(symbol, ICT_ENTRY_TF, shift);

   double range = high - low;

   if(range <= 0.0)
      return false;

   double body = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);

   if(upperWick <= 0.0)
      return false;

   if(close > open)
      return false;

   return upperWick >= body &&
          upperWick >= range * 0.30;
}

//====================================================================
// RETEST OF BROKEN STRUCTURE
//====================================================================

bool M5_IsBullishRetest(
   const string symbol,
   const int shift,
   const double brokenLevel
)
{
   if(brokenLevel <= 0.0)
      return false;

   double high  = iHigh(symbol, ICT_ENTRY_TF, shift);
   double low   = iLow(symbol, ICT_ENTRY_TF, shift);
   double close = iClose(symbol, ICT_ENTRY_TF, shift);

   bool touched = low <= brokenLevel &&
                  high >= brokenLevel;

   if(!touched)
      return false;

   return close > brokenLevel;
}

bool M5_IsBearishRetest(
   const string symbol,
   const int shift,
   const double brokenLevel
)
{
   if(brokenLevel <= 0.0)
      return false;

   double high  = iHigh(symbol, ICT_ENTRY_TF, shift);
   double low   = iLow(symbol, ICT_ENTRY_TF, shift);
   double close = iClose(symbol, ICT_ENTRY_TF, shift);

   bool touched = high >= brokenLevel &&
                  low <= brokenLevel;

   if(!touched)
      return false;

   return close < brokenLevel;
}

//====================================================================
// FVG ENTRY-ZONE CHECK
//====================================================================

bool M5_CheckFVG(
   const string symbol,
   const int shift,
   const ENUM_STRUCTURE_DIRECTION direction,
   M5Confirmation &c
)
{
   FVGZone fvg;

   ResetFVG(fvg);

   if(!DetectFVG(
      symbol,
      ICT_ENTRY_TF,
      shift,
      fvg
   ))
   {
      return false;
   }

   if(direction == STRUCTURE_BULLISH &&
      fvg.direction != FVG_BULLISH)
   {
      return false;
   }

   if(direction == STRUCTURE_BEARISH &&
      fvg.direction != FVG_BEARISH)
   {
      return false;
   }

   c.fvgPresent = true;

   c.entryZoneLow  = fvg.lower;
   c.entryZoneHigh = fvg.upper;

   if(ICT_FVG_ALLOW_RETEST)
   {
      if(IsFVGRetest(
         symbol,
         ICT_ENTRY_TF,
         fvg,
         shift
      ))
      {
         c.fvgRetest = true;
      }
   }

   return true;
}

//====================================================================
// FIND STRUCTURE CONFIRMATION
//====================================================================

bool M5_FindStructureConfirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection,
   const int lookback,
   M5Confirmation &c
)
{
   int maxBars = MathMin(
      lookback,
      ICT_M5_CONFIRM_MAX_BARS
   );

   if(maxBars < 1)
      maxBars = 1;

   for(int shift = 1; shift <= maxBars; shift++)
   {
      StructureSignal s =
         AnalyzeStructureSignal(
            symbol,
            ICT_ENTRY_TF,
            shift,
            lookback,
            ICT_SWING_LEFT,
            ICT_SWING_RIGHT
         );

      if(!s.valid)
         continue;

      ENUM_STRUCTURE_DIRECTION direction =
         GetSignalDirection(s);

      if(direction != expectedDirection)
         continue;

      c.displacement =
         expectedDirection == STRUCTURE_BULLISH
         ? s.bullishDisplacement
         : s.bearishDisplacement;

      c.mss =
         expectedDirection == STRUCTURE_BULLISH
         ? s.bullishMSS
         : s.bearishMSS;

      c.bos =
         expectedDirection == STRUCTURE_BULLISH
         ? s.bullishBOS
         : s.bearishBOS;

      c.structureBreak =
         c.mss || c.bos;

      c.brokenLevel = s.brokenLevel;
      c.signalTime = s.signalTime;
      c.signalShift = shift;

      return true;
   }

   return false;
}

//====================================================================
// ANALYZE M5 CONFIRMATION
//====================================================================

bool AnalyzeM5Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection,
   const int lookback,
   M5Confirmation &c
)
{
   ResetM5Confirmation(c);

   if(symbol == "")
   {
      c.reason = "Empty symbol.";
      return false;
   }

   if(expectedDirection == STRUCTURE_UNKNOWN)
   {
      c.reason = "Higher-timeframe direction unknown.";
      return false;
   }

   if(Bars(
      symbol,
      ICT_ENTRY_TF
   ) < ICT_MIN_HISTORY_BARS)
   {
      c.reason = "Insufficient M5 history.";
      return false;
   }

   //===============================================================
   // FIND RECENT M5 STRUCTURE EVENT
   //===============================================================

   if(!M5_FindStructureConfirmation(
      symbol,
      expectedDirection,
      lookback,
      c
   ))
   {
      c.reason = "No directional M5 MSS/BOS confirmation.";
      return false;
   }

   if(!c.structureBreak)
   {
      c.reason = "M5 structure break missing.";
      return false;
   }

   //===============================================================
   // DIRECTION
   //===============================================================

   c.bullish =
      expectedDirection == STRUCTURE_BULLISH;

   c.bearish =
      expectedDirection == STRUCTURE_BEARISH;

   //===============================================================
   // MOMENTUM
   //===============================================================

   c.momentum =
      M5_IsMomentumCandle(
         symbol,
         1,
         expectedDirection
      );

   //===============================================================
   // ENGULFING
   //===============================================================

   if(expectedDirection == STRUCTURE_BULLISH)
   {
      c.engulfing =
         M5_IsBullishEngulfing(symbol, 1);
   }
   else
   {
      c.engulfing =
         M5_IsBearishEngulfing(symbol, 1);
   }

   //===============================================================
   // REJECTION
   //===============================================================

   if(expectedDirection == STRUCTURE_BULLISH)
   {
      c.rejection =
         M5_IsBullishRejection(symbol, 1);
   }
   else
   {
      c.rejection =
         M5_IsBearishRejection(symbol, 1);
   }

   //===============================================================
   // STRUCTURE RETEST
   //===============================================================

   if(c.brokenLevel > 0.0)
   {
      if(expectedDirection == STRUCTURE_BULLISH)
      {
         c.retest =
            M5_IsBullishRetest(
               symbol,
               1,
               c.brokenLevel
            );
      }
      else
      {
         c.retest =
            M5_IsBearishRetest(
               symbol,
               1,
               c.brokenLevel
            );
      }
   }

   //===============================================================
   // FVG
   //===============================================================

   M5_CheckFVG(
      symbol,
      1,
      expectedDirection,
      c
   );

   //===============================================================
   // CONFIRMATION LOGIC
   //===============================================================

   int confirmationScore = 0;

   if(c.displacement)
      confirmationScore += 25;

   if(c.mss)
      confirmationScore += 25;

   if(c.bos)
      confirmationScore += 15;

   if(c.retest)
      confirmationScore += 20;

   if(c.fvgPresent)
      confirmationScore += 10;

   if(c.fvgRetest)
      confirmationScore += 15;

   if(c.engulfing)
      confirmationScore += 10;

   if(c.rejection)
      confirmationScore += 10;

   if(c.momentum)
      confirmationScore += 10;

   //===============================================================
   // MINIMUM FINAL GATE
   //===============================================================

   // A structure event plus at least one meaningful
   // confirmation factor is required.
   bool secondaryConfirmation =
      c.retest ||
      c.fvgPresent ||
      c.fvgRetest ||
      c.engulfing ||
      c.rejection ||
      c.momentum;

   if(!secondaryConfirmation)
   {
      c.reason =
         "M5 structure confirmed, but entry confirmation is weak.";

      return false;
   }

   // Required FVG is respected when enabled.
   if(ICT_REQUIRE_FVG &&
      !c.fvgPresent)
   {
      c.reason =
         "Required directional M5 FVG missing.";

      return false;
   }

   //===============================================================
   // FINAL VALIDATION
   //===============================================================

   if(confirmationScore < 40)
   {
      c.reason =
         "M5 confirmation score too weak.";

      return false;
   }

   c.valid = true;

   c.reason =
      StringFormat(
         "M5 confirmed | Score=%d | MSS=%s | BOS=%s | Retest=%s | FVG=%s | PA=%s",
         confirmationScore,
         c.mss ? "YES" : "NO",
         c.bos ? "YES" : "NO",
         c.retest ? "YES" : "NO",
         c.fvgPresent ? "YES" : "NO",
         (
            c.engulfing ||
            c.rejection ||
            c.momentum
         ) ? "YES" : "NO"
      );

   return true;
}

//====================================================================
// DIRECTION HELPERS
//====================================================================

bool IsM5BullishConfirmation(
   M5Confirmation &c
)
{
   return c.valid && c.bullish;
}

bool IsM5BearishConfirmation(
   M5Confirmation &c
)
{
   return c.valid && c.bearish;
}

bool M5HasRetest(
   M5Confirmation &c
)
{
   return c.valid && c.retest;
}

bool M5HasFVGConfirmation(
   M5Confirmation &c
)
{
   return c.valid &&
          (c.fvgPresent || c.fvgRetest);
}

string M5ConfirmationDescription(
   M5Confirmation &c
)
{
   if(!c.valid)
      return "INVALID M5 CONFIRMATION";

   return StringFormat(
      "%s | Structure=%s | Displacement=%s | MSS=%s | BOS=%s | Retest=%s | FVG=%s | FVG Retest=%s | Engulfing=%s | Rejection=%s | Momentum=%s",
      c.bullish ? "BULLISH" : "BEARISH",
      c.structureBreak ? "YES" : "NO",
      c.displacement ? "YES" : "NO",
      c.mss ? "YES" : "NO",
      c.bos ? "YES" : "NO",
      c.retest ? "YES" : "NO",
      c.fvgPresent ? "YES" : "NO",
      c.fvgRetest ? "YES" : "NO",
      c.engulfing ? "YES" : "NO",
      c.rejection ? "YES" : "NO",
      c.momentum ? "YES" : "NO"
   );
}

#endif
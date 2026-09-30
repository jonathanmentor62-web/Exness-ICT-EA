//+------------------------------------------------------------------+
//| M5Confirmation.mqh                                               |
//| Final lower-timeframe confirmation gate                          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_M5_CONFIRMATION_MQH__
#define __EXNESS_ICT_M5_CONFIRMATION_MQH__

#include "StructureSignal.mqh"
#include "FVG.mqh"

struct M5Confirmation
{
   bool valid;

   bool bullish;
   bool bearish;

   bool displacement;
   bool mss;
   bool bos;

   bool fvgPresent;

   double brokenLevel;

   datetime signalTime;
   int signalShift;

   string reason;
};

//====================================================================
// RESET
//====================================================================

void ResetM5Confirmation(
   M5Confirmation &c
)
{
   c.valid = false;

   c.bullish = false;
   c.bearish = false;

   c.displacement = false;
   c.mss = false;
   c.bos = false;

   c.fvgPresent = false;

   c.brokenLevel = 0.0;

   c.signalTime = 0;
   c.signalShift = -1;

   c.reason = "";
}

//====================================================================
// ANALYZE M5
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

   if(expectedDirection ==
      STRUCTURE_UNKNOWN)
   {
      c.reason =
         "Higher-timeframe direction unknown.";
      return false;
   }

   if(Bars(
      symbol,
      ICT_ENTRY_TF
   ) < ICT_MIN_HISTORY_BARS)
   {
      c.reason =
         "Insufficient M5 history.";
      return false;
   }

   // Only use the latest CLOSED candle.
   const int shift = 1;

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
   {
      c.reason =
         "No M5 MSS/BOS.";
      return false;
   }

   ENUM_STRUCTURE_DIRECTION direction =
      GetSignalDirection(s);

   if(direction != expectedDirection)
   {
      c.reason =
         "M5 direction disagrees with H4.";
      return false;
   }

   bool directional =
      (
         expectedDirection == STRUCTURE_BULLISH
         ? s.bullishDisplacement
         : s.bearishDisplacement
      );

   if(!directional)
   {
      c.reason =
         "Directional M5 displacement missing.";
      return false;
   }

   c.bullish =
      s.bullishDisplacement;

   c.bearish =
      s.bearishDisplacement;

   c.displacement =
      directional;

   c.mss =
      s.bullishMSS ||
      s.bearishMSS;

   c.bos =
      s.bullishBOS ||
      s.bearishBOS;

   c.brokenLevel =
      s.brokenLevel;

   c.signalTime =
      s.signalTime;

   c.signalShift =
      s.signalShift;

   if(c.signalTime <= 0)
   {
      c.reason =
         "Invalid M5 signal time.";
      return false;
   }

   //===============================================================
   // M5 FVG
   //===============================================================

   FVGZone fvg;

   ResetFVG(fvg);

   if(DetectFVG(
      symbol,
      ICT_ENTRY_TF,
      shift,
      fvg
   ))
   {
      if(
         expectedDirection == STRUCTURE_BULLISH &&
         fvg.direction == FVG_BULLISH
      )
      {
         c.fvgPresent = true;
      }

      if(
         expectedDirection == STRUCTURE_BEARISH &&
         fvg.direction == FVG_BEARISH
      )
      {
         c.fvgPresent = true;
      }
   }

   if(ICT_REQUIRE_FVG &&
      !c.fvgPresent)
   {
      c.reason =
         "Required directional M5 FVG missing.";
      return false;
   }

   //===============================================================
   // FINAL CONFIRMATION
   //===============================================================

   if(!c.mss && !c.bos)
   {
      c.reason =
         "M5 structure break missing.";
      return false;
   }

   c.valid = true;

   c.reason =
      "M5 displacement + structure + FVG confirmed.";

   return true;
}

#endif
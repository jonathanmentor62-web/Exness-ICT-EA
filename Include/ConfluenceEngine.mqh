//+------------------------------------------------------------------+
//| ConfluenceEngine.mqh                                             |
//| Gold Multi-Strategy EA - Multi-Timeframe Confluence              |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_CONFLUENCE_ENGINE_MQH__
#define __EXNESS_GOLD_CONFLUENCE_ENGINE_MQH__

#include "Config.mqh"
#include "StrategySignal.mqh"
#include "StrategyEngine.mqh"
#include "MarketStructure.mqh"
#include "StructureSignal.mqh"
#include "Liquidity.mqh"
#include "FVG.mqh"
#include "OrderBlock.mqh"
#include "M5Confirmation.mqh"

//====================================================================
// CONFLUENCE RESULT
//====================================================================

struct ConfluenceResult
{
   bool valid;
   bool actionable;

   ENUM_STRATEGY_DIRECTION direction;

   double score;
   double confidence;

   // Higher-timeframe confirmation
   bool h4Confirmed;
   bool h1Confirmed;
   bool m15Confirmed;
   bool m5Confirmed;

   // ICT / SMC confirmation
   bool liquidityConfirmed;
   bool structureConfirmed;
   bool displacementConfirmed;
   bool mssConfirmed;
   bool bosConfirmed;

   bool fvgConfirmed;
   bool fvgRetestConfirmed;

   bool orderBlockConfirmed;
   bool orderBlockRetestConfirmed;

   // Retest / breakout confirmation
   bool breakoutConfirmed;
   bool retestConfirmed;
   bool failedBreakoutConfirmed;

   // Price action
   bool engulfingConfirmed;
   bool rejectionConfirmed;
   bool momentumConfirmed;

   // Context
   bool premiumDiscountConfirmed;
   bool sessionConfirmed;
   bool volatilityConfirmed;

   // Price levels
   double entry;
   double structuralHigh;
   double structuralLow;

   double zoneHigh;
   double zoneLow;

   // Source strategy
   StrategySignal sourceSignal;

   // Diagnostic information
   string reason;
   string evidence;
};

//====================================================================
// RESET
//====================================================================

void CE_ResetResult(
   ConfluenceResult &result
)
{
   result.valid = false;
   result.actionable = false;

   result.direction =
      STRATEGY_DIRECTION_NONE;

   result.score = 0.0;
   result.confidence = 0.0;

   result.h4Confirmed = false;
   result.h1Confirmed = false;
   result.m15Confirmed = false;
   result.m5Confirmed = false;

   result.liquidityConfirmed = false;
   result.structureConfirmed = false;
   result.displacementConfirmed = false;
   result.mssConfirmed = false;
   result.bosConfirmed = false;

   result.fvgConfirmed = false;
   result.fvgRetestConfirmed = false;

   result.orderBlockConfirmed = false;
   result.orderBlockRetestConfirmed = false;

   result.breakoutConfirmed = false;
   result.retestConfirmed = false;
   result.failedBreakoutConfirmed = false;

   result.engulfingConfirmed = false;
   result.rejectionConfirmed = false;
   result.momentumConfirmed = false;

   result.premiumDiscountConfirmed = false;
   result.sessionConfirmed = false;
   result.volatilityConfirmed = false;

   result.entry = 0.0;

   result.structuralHigh = 0.0;
   result.structuralLow = 0.0;

   result.zoneHigh = 0.0;
   result.zoneLow = 0.0;

   ResetStrategySignal(
      result.sourceSignal
   );

   result.reason = "";
   result.evidence = "";
}

//====================================================================
// DIRECTION HELPERS
//====================================================================

bool CE_IsBuy(
   const ConfluenceResult &result
)
{
   return result.direction ==
      STRATEGY_DIRECTION_BUY;
}

//====================================================================

bool CE_IsSell(
   const ConfluenceResult &result
)
{
   return result.direction ==
      STRATEGY_DIRECTION_SELL;
}

//====================================================================

bool CE_IsDirectional(
   const ConfluenceResult &result
)
{
   return result.direction !=
      STRATEGY_DIRECTION_NONE;
}

//====================================================================
// ADD SCORE
//====================================================================

void CE_AddScore(
   ConfluenceResult &result,
   const double points,
   const string evidence
)
{
   if(points > 0.0)
      result.score += points;

   if(result.score > 100.0)
      result.score = 100.0;

   result.confidence =
      result.score;

   if(evidence != "")
   {
      if(result.evidence == "")
         result.evidence = evidence;
      else
         result.evidence +=
            " | " + evidence;
   }
}

//====================================================================
// CONFLUENCE QUALITY
//====================================================================

string CE_Quality(
   const double score
)
{
   if(score >= 85.0)
      return "VERY HIGH";

   if(score >= 70.0)
      return "HIGH";

   if(score >= 55.0)
      return "MODERATE";

   if(score >= 40.0)
      return "WEAK";

   return "INSUFFICIENT";
}

//====================================================================
// BASIC GOLD CHECK
//====================================================================

bool CE_IsGold(
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
// TIMEFRAME HISTORY CHECK
//====================================================================

bool CE_HasHistory(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int minimumBars
)
{
   if(minimumBars <= 0)
      return false;

   return Bars(
      symbol,
      timeframe
   ) >= minimumBars;
}
//====================================================================
// H4 STRUCTURE CONFIRMATION
//====================================================================

bool CE_CheckH4Structure(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   MarketStructureState state;

   if(!MS_GetState(
      symbol,
      ICT_PRIMARY_TF,
      ICT_STRUCTURE_LOOKBACK,
      state
   ))
      return false;

   if(!state.valid)
      return false;

   //-----------------------------------------------------------------
   // BULLISH H4
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_BUY &&
      state.bias >= 1
   )
   {
      result.h4Confirmed = true;
      result.structureConfirmed = true;

      CE_AddScore(
         result,
         15.0,
         "H4 bullish structure"
      );

      return true;
   }

   //-----------------------------------------------------------------
   // BEARISH H4
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_SELL &&
      state.bias <= -1
   )
   {
      result.h4Confirmed = true;
      result.structureConfirmed = true;

      CE_AddScore(
         result,
         15.0,
         "H4 bearish structure"
      );

      return true;
   }

   return false;
}

//====================================================================
// H1 STRUCTURE CONFIRMATION
//====================================================================

bool CE_CheckH1Structure(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   MarketStructureState state;

   if(!MS_GetState(
      symbol,
      PERIOD_H1,
      ICT_STRUCTURE_LOOKBACK,
      state
   ))
      return false;

   if(!state.valid)
      return false;

   //-----------------------------------------------------------------
   // BULLISH H1
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_BUY &&
      state.bias >= 1
   )
   {
      result.h1Confirmed = true;

      CE_AddScore(
         result,
         10.0,
         "H1 bullish structure"
      );

      return true;
   }

   //-----------------------------------------------------------------
   // BEARISH H1
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_SELL &&
      state.bias <= -1
   )
   {
      result.h1Confirmed = true;

      CE_AddScore(
         result,
         10.0,
         "H1 bearish structure"
      );

      return true;
   }

   return false;
}

//====================================================================
// H1 STRUCTURE BREAK CONFIRMATION
//====================================================================

bool CE_CheckH1Break(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   StructureSignal signal;

   ResetStructureSignal(
      signal
   );

   if(!AnalyzeStructureSignal(
      symbol,
      PERIOD_H1,
      ICT_STRUCTURE_LOOKBACK,
      signal
   ))
      return false;

   if(!signal.valid)
      return false;

   //-----------------------------------------------------------------
   // BULLISH H1 MSS / BOS
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_BUY &&
      (
         signal.bullishMSS ||
         signal.bullishBOS
      )
   )
   {
      if(signal.bullishMSS)
      {
         result.mssConfirmed = true;

         CE_AddScore(
            result,
            10.0,
            "H1 bullish MSS"
         );
      }

      if(signal.bullishBOS)
      {
         result.bosConfirmed = true;

         CE_AddScore(
            result,
            8.0,
            "H1 bullish BOS"
         );
      }

      return true;
   }

   //-----------------------------------------------------------------
   // BEARISH H1 MSS / BOS
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_SELL &&
      (
         signal.bearishMSS ||
         signal.bearishBOS
      )
   )
   {
      if(signal.bearishMSS)
      {
         result.mssConfirmed = true;

         CE_AddScore(
            result,
            10.0,
            "H1 bearish MSS"
         );
      }

      if(signal.bearishBOS)
      {
         result.bosConfirmed = true;

         CE_AddScore(
            result,
            8.0,
            "H1 bearish BOS"
         );
      }

      return true;
   }

   return false;
}

//====================================================================
// APPLY SOURCE STRATEGY
//====================================================================

void CE_ApplySourceSignal(
   const StrategySignal &source,
   ConfluenceResult &result
)
{
   result.sourceSignal =
      source;

   result.direction =
      source.direction;

   result.entry =
      source.entry;

   result.structuralHigh =
      source.structuralHigh;

   result.structuralLow =
      source.structuralLow;

   result.zoneHigh =
      source.zoneHigh;

   result.zoneLow =
      source.zoneLow;

   if(source.liquidityConfirmed)
   {
      result.liquidityConfirmed = true;

      CE_AddScore(
         result,
         10.0,
         "Liquidity confirmed"
      );
   }

   if(source.displacementConfirmed)
   {
      result.displacementConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "Displacement confirmed"
      );
   }

   if(source.mssConfirmed)
   {
      result.mssConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "MSS confirmed"
      );
   }

   if(source.bosConfirmed)
   {
      result.bosConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "BOS confirmed"
      );
   }

   if(source.fvgPresent)
   {
      result.fvgConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "FVG confirmed"
      );
   }

   if(source.fvgRetestConfirmed)
   {
      result.fvgRetestConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "FVG retest confirmed"
      );
   }

   if(source.orderBlockPresent)
   {
      result.orderBlockConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "Order block confirmed"
      );
   }

   if(source.orderBlockRetestConfirmed)
   {
      result.orderBlockRetestConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "Order-block retest confirmed"
      );
   }

   if(source.retestConfirmed)
   {
      result.retestConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "Retest confirmed"
      );
   }

   if(source.engulfingConfirmed)
   {
      result.engulfingConfirmed = true;

      CE_AddScore(
         result,
         3.0,
         "Engulfing confirmed"
      );
   }

   if(source.rejectionConfirmed)
   {
      result.rejectionConfirmed = true;

      CE_AddScore(
         result,
         3.0,
         "Rejection confirmed"
      );
   }

   if(source.momentumConfirmed)
   {
      result.momentumConfirmed = true;

      CE_AddScore(
         result,
         3.0,
         "Momentum confirmed"
      );
   }

   if(source.premiumDiscountConfirmed)
   {
      result.premiumDiscountConfirmed = true;

      CE_AddScore(
         result,
         3.0,
         "Premium/discount confirmed"
      );
   }

   if(source.sessionConfirmed)
   {
      result.sessionConfirmed = true;
   }

   if(source.volatilityConfirmed)
   {
      result.volatilityConfirmed = true;
   }
}
//====================================================================
// M15 DIRECTIONAL CONFIRMATION
//====================================================================

bool CE_CheckM15Confirmation(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   StructureSignal signal;

   ResetStructureSignal(signal);

   if(!AnalyzeStructureSignal(
      symbol,
      ICT_CONFIRM_TF,
      ICT_STRUCTURE_LOOKBACK,
      signal
   ))
      return false;

   if(!signal.valid)
      return false;

   //-----------------------------------------------------------------
   // BULLISH M15
   //-----------------------------------------------------------------

   if(direction == STRATEGY_DIRECTION_BUY)
   {
      if(
         signal.bullishMSS ||
         signal.bullishBOS ||
         signal.bullishDisplacement
      )
      {
         result.m15Confirmed = true;

         if(signal.bullishMSS)
         {
            result.mssConfirmed = true;

            CE_AddScore(
               result,
               10.0,
               "M15 bullish MSS"
            );
         }

         if(signal.bullishBOS)
         {
            result.bosConfirmed = true;

            CE_AddScore(
               result,
               7.0,
               "M15 bullish BOS"
            );
         }

         if(signal.bullishDisplacement)
         {
            result.displacementConfirmed = true;

            CE_AddScore(
               result,
               5.0,
               "M15 bullish displacement"
            );
         }

         return true;
      }
   }

   //-----------------------------------------------------------------
   // BEARISH M15
   //-----------------------------------------------------------------

   if(direction == STRATEGY_DIRECTION_SELL)
   {
      if(
         signal.bearishMSS ||
         signal.bearishBOS ||
         signal.bearishDisplacement
      )
      {
         result.m15Confirmed = true;

         if(signal.bearishMSS)
         {
            result.mssConfirmed = true;

            CE_AddScore(
               result,
               10.0,
               "M15 bearish MSS"
            );
         }

         if(signal.bearishBOS)
         {
            result.bosConfirmed = true;

            CE_AddScore(
               result,
               7.0,
               "M15 bearish BOS"
            );
         }

         if(signal.bearishDisplacement)
         {
            result.displacementConfirmed = true;

            CE_AddScore(
               result,
               5.0,
               "M15 bearish displacement"
            );
         }

         return true;
      }
   }

   return false;
}

//====================================================================
// M15 LIQUIDITY CONFIRMATION
//====================================================================

bool CE_CheckM15Liquidity(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   LiquiditySweep sweep;

   ResetLiquiditySweep(sweep);

   bool bullish =
      direction == STRATEGY_DIRECTION_BUY;

   bool found =
      DetectLiquiditySweep(
         symbol,
         ICT_CONFIRM_TF,
         bullish,
         ICT_M15_CONFIRM_MAX_BARS,
         sweep
      );

   if(!found || !sweep.valid)
      return false;

   result.liquidityConfirmed = true;

   CE_AddScore(
      result,
      8.0,
      "M15 liquidity sweep"
   );

   return true;
}

//====================================================================
// M15 FVG CONFIRMATION
//====================================================================

bool CE_CheckM15FVG(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   FVGZone fvg;

   ResetFVG(fvg);

   bool bullish =
      direction == STRATEGY_DIRECTION_BUY;

   bool found =
      FindDirectionalFVG(
         symbol,
         ICT_CONFIRM_TF,
         bullish,
         ICT_M15_CONFIRM_MAX_BARS,
         fvg
      );

   if(!found || !fvg.valid)
      return false;

   result.fvgConfirmed = true;

   CE_AddScore(
      result,
      5.0,
      "M15 FVG"
   );

   //-----------------------------------------------------------------
   // CURRENT PRICE INSIDE FVG
   //-----------------------------------------------------------------

   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick
   ))
      return true;

   double price =
      bullish
      ? tick.ask
      : tick.bid;

   if(IsPriceInsideFVG(
      fvg,
      price
   ))
   {
      result.fvgRetestConfirmed = true;

      result.retestConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M15 FVG retest"
      );
   }

   return true;
}

//====================================================================
// M15 ORDER-BLOCK CONFIRMATION
//====================================================================

bool CE_CheckM15OrderBlock(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   if(!ICT_ENABLE_ORDER_BLOCK)
      return false;

   OrderBlock ob;

   ResetOrderBlock(ob);

   bool bullish =
      direction == STRATEGY_DIRECTION_BUY;

   bool found =
      FindDirectionalOrderBlock(
         symbol,
         ICT_CONFIRM_TF,
         bullish,
         ICT_OB_LOOKBACK,
         ob
      );

   if(!found || !ob.valid)
      return false;

   result.orderBlockConfirmed = true;

   CE_AddScore(
      result,
      5.0,
      "M15 order block"
   );

   //-----------------------------------------------------------------
   // CURRENT PRICE INSIDE ORDER BLOCK
   //-----------------------------------------------------------------

   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick
   ))
      return true;

   double price =
      bullish
      ? tick.ask
      : tick.bid;

   if(IsPriceInsideOrderBlock(
      ob,
      price
   ))
   {
      result.orderBlockRetestConfirmed = true;

      result.retestConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M15 order-block retest"
      );
   }

   return true;
}
//====================================================================
// M5 ENTRY CONFIRMATION
//====================================================================

bool CE_CheckM5Confirmation(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   M5Confirmation confirmation;

   ResetM5Confirmation(
      confirmation
   );

   if(!AnalyzeM5Confirmation(
      symbol,
      direction == STRATEGY_DIRECTION_BUY,
      ICT_M5_CONFIRM_MAX_BARS,
      confirmation
   ))
      return false;

   if(!confirmation.valid)
      return false;

   //-----------------------------------------------------------------
   // DIRECTION CHECK
   //-----------------------------------------------------------------

   if(
      direction == STRATEGY_DIRECTION_BUY &&
      !confirmation.bullish
   )
      return false;

   if(
      direction == STRATEGY_DIRECTION_SELL &&
      !confirmation.bearish
   )
      return false;

   result.m5Confirmed = true;

   //-----------------------------------------------------------------
   // M5 STRUCTURE
   //-----------------------------------------------------------------

   if(confirmation.mss)
   {
      result.mssConfirmed = true;

      CE_AddScore(
         result,
         10.0,
         "M5 MSS"
      );
   }

   if(confirmation.bos)
   {
      result.bosConfirmed = true;

      CE_AddScore(
         result,
         7.0,
         "M5 BOS"
      );
   }

   if(confirmation.displacement)
   {
      result.displacementConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 displacement"
      );
   }

   //-----------------------------------------------------------------
   // M5 RETEST
   //-----------------------------------------------------------------

   if(confirmation.retest)
   {
      result.retestConfirmed = true;

      CE_AddScore(
         result,
         10.0,
         "M5 retest"
      );
   }

   //-----------------------------------------------------------------
   // M5 FVG
   //-----------------------------------------------------------------

   if(confirmation.fvgPresent)
   {
      result.fvgConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 FVG"
      );
   }

   if(confirmation.fvgRetest)
   {
      result.fvgRetestConfirmed = true;
      result.retestConfirmed = true;

      CE_AddScore(
         result,
         7.0,
         "M5 FVG retest"
      );
   }

   //-----------------------------------------------------------------
   // M5 PRICE ACTION
   //-----------------------------------------------------------------

   if(confirmation.engulfing)
   {
      result.engulfingConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 engulfing"
      );
   }

   if(confirmation.rejection)
   {
      result.rejectionConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 rejection"
      );
   }

   if(confirmation.momentum)
   {
      result.momentumConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 momentum"
      );
   }

   //-----------------------------------------------------------------
   // ENTRY ZONE
   //-----------------------------------------------------------------

   if(
      confirmation.entryZoneHigh > 0.0 &&
      confirmation.entryZoneLow > 0.0 &&
      confirmation.entryZoneHigh >=
      confirmation.entryZoneLow
   )
   {
      result.zoneHigh =
         confirmation.entryZoneHigh;

      result.zoneLow =
         confirmation.entryZoneLow;
   }

   return true;
}

//====================================================================
// M5 ENTRY PRICE
//====================================================================

double CE_GetM5EntryPrice(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction
)
{
   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick
   ))
      return 0.0;

   if(direction == STRATEGY_DIRECTION_BUY)
      return tick.ask;

   if(direction == STRATEGY_DIRECTION_SELL)
      return tick.bid;

   return 0.0;
}

//====================================================================
// UPDATE ENTRY PRICE
//====================================================================

void CE_UpdateEntryPrice(
   const string symbol,
   ConfluenceResult &result
)
{
   double price =
      CE_GetM5EntryPrice(
         symbol,
         result.direction
      );

   if(price > 0.0)
      result.entry = price;
}

//====================================================================
// FINAL ENTRY CONFIRMATION
//====================================================================

bool CE_FinalEntryConfirmation(
   const ConfluenceResult &result
)
{
   if(!result.valid)
      return false;

   if(!result.actionable)
      return false;

   if(!CE_IsDirectional(result))
      return false;

   if(!result.h4Confirmed)
      return false;

   if(!result.h1Confirmed)
      return false;

   if(!result.m15Confirmed)
      return false;

   if(!result.m5Confirmed)
      return false;

   //-----------------------------------------------------------------
   // A REAL ENTRY SHOULD HAVE STRUCTURE
   //-----------------------------------------------------------------

   if(
      !result.mssConfirmed &&
      !result.bosConfirmed
   )
      return false;

   //-----------------------------------------------------------------
   // A REAL ENTRY SHOULD HAVE AT LEAST ONE LOCATION
   //-----------------------------------------------------------------

   if(
      !result.fvgConfirmed &&
      !result.orderBlockConfirmed &&
      !result.retestConfirmed
   )
      return false;

   //-----------------------------------------------------------------
   // CONFLUENCE THRESHOLD
   //-----------------------------------------------------------------

   if(
      result.score <
      ICT_MIN_CONFLUENCE_SCORE
   )
      return false;

   return true;
}
//====================================================================
// FINALIZE CONFLUENCE
//====================================================================

void CE_Finalize(
   ConfluenceResult &result
)
{
   result.confidence =
      result.score;

   //-----------------------------------------------------------------
   // BASIC DIRECTION CHECK
   //-----------------------------------------------------------------

   if(!CE_IsDirectional(result))
   {
      result.valid = false;
      result.actionable = false;

      result.reason =
         "No directional confluence.";

      return;
   }

   //-----------------------------------------------------------------
   // HIGHER-TIMEFRAME ALIGNMENT
   //-----------------------------------------------------------------

   if(
      !result.h4Confirmed ||
      !result.h1Confirmed
   )
   {
      result.valid = false;
      result.actionable = false;

      result.reason =
         "H4/H1 direction not aligned.";

      return;
   }

   //-----------------------------------------------------------------
   // M15 CONFIRMATION
   //-----------------------------------------------------------------

   if(!result.m15Confirmed)
   {
      result.valid = false;
      result.actionable = false;

      result.reason =
         "M15 confirmation missing.";

      return;
   }

   //-----------------------------------------------------------------
   // M5 ENTRY CONFIRMATION
   //-----------------------------------------------------------------

   if(!result.m5Confirmed)
   {
      result.valid = false;
      result.actionable = false;

      result.reason =
         "M5 entry confirmation missing.";

      return;
   }

   //-----------------------------------------------------------------
   // STRUCTURE
   //-----------------------------------------------------------------

   if(
      !result.structureConfirmed &&
      !result.mssConfirmed &&
      !result.bosConfirmed
   )
   {
      result.valid = false;
      result.actionable = false;

      result.reason =
         "No valid market structure confirmation.";

      return;
   }

   //-----------------------------------------------------------------
   // ENTRY LOCATION
   //-----------------------------------------------------------------

   if(
      !result.fvgConfirmed &&
      !result.orderBlockConfirmed &&
      !result.retestConfirmed
   )
   {
      result.valid = false;
      result.actionable = false;

      result.reason =
         "No valid entry location.";

      return;
   }

   //-----------------------------------------------------------------
   // CONFLUENCE SCORE
   //-----------------------------------------------------------------

   if(
      result.score <
      ICT_MIN_CONFLUENCE_SCORE
   )
   {
      result.valid = true;
      result.actionable = false;

      result.reason =
         "Setup detected but confluence score is too low.";

      return;
   }

   //-----------------------------------------------------------------
   // FINAL VALID SETUP
   //-----------------------------------------------------------------

   result.valid = true;
   result.actionable = true;

   result.reason =
      "High-confluence Gold setup confirmed.";
}

//====================================================================
// ANALYZE ONE DIRECTION
//====================================================================

bool CE_AnalyzeDirection(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   const StrategySignal &source,
   ConfluenceResult &result
)
{
   CE_ResetResult(result);

   if(!CE_IsGold(symbol))
   {
      result.reason =
         "Rejected: non-Gold symbol.";

      return false;
   }

   if(
      direction != STRATEGY_DIRECTION_BUY &&
      direction != STRATEGY_DIRECTION_SELL
   )
   {
      result.reason =
         "Invalid direction.";

      return false;
   }

   //-----------------------------------------------------------------
   // SOURCE STRATEGY
   //-----------------------------------------------------------------

   CE_ApplySourceSignal(
      source,
      result
   );

   //-----------------------------------------------------------------
   // H4
   //-----------------------------------------------------------------

   CE_CheckH4Structure(
      symbol,
      direction,
      result
   );

   //-----------------------------------------------------------------
   // H1
   //-----------------------------------------------------------------

   CE_CheckH1Structure(
      symbol,
      direction,
      result
   );

   CE_CheckH1Break(
      symbol,
      direction,
      result
   );

   //-----------------------------------------------------------------
   // M15
   //-----------------------------------------------------------------

   CE_CheckM15Confirmation(
      symbol,
      direction,
      result
   );

   CE_CheckM15Liquidity(
      symbol,
      direction,
      result
   );

   CE_CheckM15FVG(
      symbol,
      direction,
      result
   );

   CE_CheckM15OrderBlock(
      symbol,
      direction,
      result
   );

   //-----------------------------------------------------------------
   // M5
   //-----------------------------------------------------------------

   CE_CheckM5Confirmation(
      symbol,
      direction,
      result
   );

   //-----------------------------------------------------------------
   // UPDATE LIVE ENTRY
   //-----------------------------------------------------------------

   CE_UpdateEntryPrice(
      symbol,
      result
   );

   //-----------------------------------------------------------------
   // FINAL DECISION
   //-----------------------------------------------------------------

   CE_Finalize(
      result
   );

   return result.valid;
}

//====================================================================
// ANALYZE GOLD CONFLUENCE
//====================================================================

bool CE_AnalyzeGold(
   const string symbol,
   ConfluenceResult &result
)
{
   CE_ResetResult(result);

   if(!CE_IsGold(symbol))
   {
      result.reason =
         "Only XAUUSD is permitted.";

      return false;
   }

   //-----------------------------------------------------------------
   // HISTORY
   //-----------------------------------------------------------------

   if(!CE_HasHistory(
      symbol,
      ICT_PRIMARY_TF,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.reason =
         "Insufficient H4 history.";

      return false;
   }

   if(!CE_HasHistory(
      symbol,
      PERIOD_H1,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.reason =
         "Insufficient H1 history.";

      return false;
   }

   if(!CE_HasHistory(
      symbol,
      ICT_CONFIRM_TF,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.reason =
         "Insufficient M15 history.";

      return false;
   }

   if(!CE_HasHistory(
      symbol,
      ICT_ENTRY_TF,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.reason =
         "Insufficient M5 history.";

      return false;
   }

   //-----------------------------------------------------------------
   // GET STRATEGY ENGINE RESULT
   //-----------------------------------------------------------------

   StrategyEngineResult strategyResult;

   SE_ResetResult(
      strategyResult
   );

   if(!SE_AnalyzeGold(
      symbol,
      strategyResult
   ))
   {
      result.reason =
         strategyResult.summary;

      return false;
   }

   //-----------------------------------------------------------------
   // ANALYZE SELECTED DIRECTION
   //-----------------------------------------------------------------

   ConfluenceResult analyzed;

   CE_ResetResult(
      analyzed
   );

   if(!CE_AnalyzeDirection(
      symbol,
      strategyResult.bestSignal.direction,
      strategyResult.bestSignal,
      analyzed
   ))
   {
      result = analyzed;

      return false;
   }

   result = analyzed;

   return result.valid;
}

//====================================================================
// CONFLUENCE DESCRIPTION
//====================================================================

string CE_Description(
   const ConfluenceResult &result
)
{
   string direction =
      "NONE";

   if(
      result.direction ==
      STRATEGY_DIRECTION_BUY
   )
      direction = "BUY";

   if(
      result.direction ==
      STRATEGY_DIRECTION_SELL
   )
      direction = "SELL";

   string text =
      direction +
      " | Score=" +
      DoubleToString(
         result.score,
         1
      );

   text +=
      " | Quality=" +
      CE_Quality(
         result.score
      );

   text +=
      " | H4=" +
      (result.h4Confirmed ? "YES" : "NO");

   text +=
      " | H1=" +
      (result.h1Confirmed ? "YES" : "NO");

   text +=
      " | M15=" +
      (result.m15Confirmed ? "YES" : "NO");

   text +=
      " | M5=" +
      (result.m5Confirmed ? "YES" : "NO");

   return text;
}

//====================================================================
// PRINT CONFLUENCE RESULT
//====================================================================

void CE_PrintResult(
   const ConfluenceResult &result
)
{
   Print(
      "[CONFLUENCE] ",
      CE_Description(result)
   );

   Print(
      "[CONFLUENCE] Actionable=",
      result.actionable ? "YES" : "NO",
      " | Reason=",
      result.reason
   );

   if(result.evidence != "")
   {
      Print(
         "[CONFLUENCE EVIDENCE] ",
         result.evidence
      );
   }

   Print(
      "[CONFLUENCE] Entry=",
      DoubleToString(
         result.entry,
         _Digits
      ),
      " | Zone=",
      DoubleToString(
         result.zoneLow,
         _Digits
      ),
      " - ",
      DoubleToString(
         result.zoneHigh,
         _Digits
      )
   );
}

//====================================================================
// ENGINE STATUS
//====================================================================

string CE_Status()
{
   return
      "Gold Confluence Engine | "
      "H4 -> H1 -> M15 -> M5 | "
      "ICT/SMC + Retest + Price Action | "
      "M1 scalping removed";
}

#endif
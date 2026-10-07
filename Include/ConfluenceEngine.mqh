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
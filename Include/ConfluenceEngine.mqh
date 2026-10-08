//+------------------------------------------------------------------+
//| ConfluenceEngine.mqh                                             |
//| Gold Multi-Strategy EA - Unified Confluence Engine               |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_CONFLUENCE_ENGINE_MQH__
#define __EXNESS_GOLD_CONFLUENCE_ENGINE_MQH__

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "StrategySignal.mqh"
#include "StrategyEngine.mqh"
#include "MarketStructure.mqh"
#include "StructureSignal.mqh"
#include "Liquidity.mqh"
#include "FVG.mqh"
#include "OrderBlock.mqh"
#include "M5Confirmation.mqh"
#include "BreakoutRetest.mqh"
#include "AdvancedBlocks.mqh"
#include "SessionEngine.mqh"
#include "VolatilityEngine.mqh"
#include "PriceActionEngine.mqh"
#include "TrendEngine.mqh"
#include "ReversalEngine.mqh"
#include "TradePlanEngine.mqh"

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

   // Multi-timeframe confirmation
   bool h4Confirmed;
   bool h1Confirmed;
   bool m15Confirmed;
   bool m5Confirmed;

   // ICT / SMC
   bool liquidityConfirmed;
   bool structureConfirmed;
   bool displacementConfirmed;
   bool mssConfirmed;
   bool bosConfirmed;
   bool chochConfirmed;

   // Institutional zones
   bool fvgConfirmed;
   bool fvgRetestConfirmed;

   bool orderBlockConfirmed;
   bool orderBlockRetestConfirmed;

   bool breakerConfirmed;
   bool mitigationBlockConfirmed;

   // Breakout / retest
   bool breakoutConfirmed;
   bool retestConfirmed;
   bool failedBreakoutConfirmed;

   // Trend
   bool trendConfirmed;
   bool pullbackConfirmed;
   bool continuationConfirmed;

   // Reversal
   bool reversalConfirmed;
   bool liquidityReversalConfirmed;
   bool exhaustionConfirmed;

   // Price action
   bool engulfingConfirmed;
   bool rejectionConfirmed;
   bool momentumConfirmed;
   bool insideBarConfirmed;

   // Context
   bool premiumDiscountConfirmed;
   bool sessionConfirmed;
   bool volatilityConfirmed;

   // Trade planning
   bool tradePlanConfirmed;
   bool riskRewardConfirmed;

   double entry;
   double structuralHigh;
   double structuralLow;

   double zoneHigh;
   double zoneLow;

   double stopLoss;
   double takeProfit;
   double rewardRisk;

   double planScore;

   // Source strategy
   StrategySignal sourceSignal;

   // Final trade plan
   TradePlan tradePlan;

   // Diagnostics
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
   result.chochConfirmed = false;

   result.fvgConfirmed = false;
   result.fvgRetestConfirmed = false;

   result.orderBlockConfirmed = false;
   result.orderBlockRetestConfirmed = false;

   result.breakerConfirmed = false;
   result.mitigationBlockConfirmed = false;

   result.breakoutConfirmed = false;
   result.retestConfirmed = false;
   result.failedBreakoutConfirmed = false;

   result.trendConfirmed = false;
   result.pullbackConfirmed = false;
   result.continuationConfirmed = false;

   result.reversalConfirmed = false;
   result.liquidityReversalConfirmed = false;
   result.exhaustionConfirmed = false;

   result.engulfingConfirmed = false;
   result.rejectionConfirmed = false;
   result.momentumConfirmed = false;
   result.insideBarConfirmed = false;

   result.premiumDiscountConfirmed = false;
   result.sessionConfirmed = false;
   result.volatilityConfirmed = false;

   result.tradePlanConfirmed = false;
   result.riskRewardConfirmed = false;

   result.entry = 0.0;

   result.structuralHigh = 0.0;
   result.structuralLow = 0.0;

   result.zoneHigh = 0.0;
   result.zoneLow = 0.0;

   result.stopLoss = 0.0;
   result.takeProfit = 0.0;
   result.rewardRisk = 0.0;
   result.planScore = 0.0;

   ResetStrategySignal(
      result.sourceSignal
   );

   ResetTradePlan(
      result.tradePlan
   );

   result.reason = "";
   result.evidence = "";
}

//====================================================================
// GOLD CHECK
//====================================================================

bool CE_IsGold(
   const string symbol
)
{
   return RE_IsGoldSymbol(
      symbol
   );
}

//====================================================================
// HISTORY CHECK
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
      {
         result.evidence =
            evidence;
      }
      else
      {
         result.evidence +=
            " | " + evidence;
      }
   }
}

//====================================================================
// QUALITY
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
// DIRECTION VALIDATION
//====================================================================

bool CE_DirectionMatches(
   const ENUM_STRATEGY_DIRECTION direction,
   const bool bullish
)
{
   if(bullish)
      return direction ==
         STRATEGY_DIRECTION_BUY;

   return direction ==
      STRATEGY_DIRECTION_SELL;
}

//====================================================================
// CURRENT MARKET PRICE
//====================================================================

double CE_CurrentPrice(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction
)
{
   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick))
   {
      return 0.0;
   }

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      return tick.ask;
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      return tick.bid;
   }

   return (tick.bid + tick.ask) * 0.5;
}

//====================================================================
// SOURCE STRATEGY
//====================================================================

void CE_ApplySourceSignal(
   const StrategySignal &source,
   ConfluenceResult &result
)
{
   result.sourceSignal =
      source;

   if(source.direction !=
      STRATEGY_DIRECTION_NONE)
   {
      result.direction =
         source.direction;
   }

   if(source.entry > 0.0)
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
      result.liquidityConfirmed =
         true;

      CE_AddScore(
         result,
         8.0,
         "Source liquidity confirmed");
   }

   if(source.displacementConfirmed)
   {
      result.displacementConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source displacement confirmed");
   }

   if(source.mssConfirmed)
   {
      result.mssConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source MSS confirmed");
   }

   if(source.bosConfirmed)
   {
      result.bosConfirmed =
         true;

      CE_AddScore(
         result,
         4.0,
         "Source BOS confirmed");
   }

   if(source.fvgPresent)
   {
      result.fvgConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source FVG confirmed");
   }

   if(source.fvgRetestConfirmed)
   {
      result.fvgRetestConfirmed =
         true;

      result.retestConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source FVG retest confirmed");
   }

   if(source.orderBlockPresent)
   {
      result.orderBlockConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source order block confirmed");
   }

   if(source.orderBlockRetestConfirmed)
   {
      result.orderBlockRetestConfirmed =
         true;

      result.retestConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source order-block retest confirmed");
   }

   if(source.retestConfirmed)
   {
      result.retestConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Source retest confirmed");
   }

   if(source.engulfingConfirmed)
   {
      result.engulfingConfirmed =
         true;

      CE_AddScore(
         result,
         3.0,
         "Source engulfing confirmed");
   }

   if(source.rejectionConfirmed)
   {
      result.rejectionConfirmed =
         true;

      CE_AddScore(
         result,
         3.0,
         "Source rejection confirmed");
   }

   if(source.momentumConfirmed)
   {
      result.momentumConfirmed =
         true;

      CE_AddScore(
         result,
         3.0,
         "Source momentum confirmed");
   }

   if(source.premiumDiscountConfirmed)
   {
      result.premiumDiscountConfirmed =
         true;

      CE_AddScore(
         result,
         3.0,
         "Premium/discount confirmed");
   }

   if(source.sessionConfirmed)
      result.sessionConfirmed = true;

   if(source.volatilityConfirmed)
      result.volatilityConfirmed = true;
}

//====================================================================
// BASIC DIRECTIONAL STRUCTURE
//====================================================================

bool CE_CheckStructure(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   const ENUM_TIMEFRAMES timeframe,
   const double points,
   ConfluenceResult &result
)
{
   MarketStructureState state;

   if(!MS_GetState(
      symbol,
      timeframe,
      ICT_STRUCTURE_LOOKBACK,
      state))
   {
      return false;
   }

   if(!state.valid)
      return false;

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      if(state.bias >= 1)
      {
         result.structureConfirmed =
            true;

         CE_AddScore(
            result,
            points,
            "Bullish " +
            EnumToString(timeframe) +
            " structure");

         return true;
      }
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      if(state.bias <= -1)
      {
         result.structureConfirmed =
            true;

         CE_AddScore(
            result,
            points,
            "Bearish " +
            EnumToString(timeframe) +
            " structure");

         return true;
      }
   }

   return false;
}

//====================================================================
// H4 CONFIRMATION
//====================================================================

bool CE_CheckH4(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   if(!CE_CheckStructure(
      symbol,
      direction,
      PERIOD_H4,
      15.0,
      result))
   {
      return false;
   }

   result.h4Confirmed =
      true;

   CE_AddScore(
      result,
      0.0,
      "H4 directional confirmation");

   return true;
}

//====================================================================
// H1 CONFIRMATION
//====================================================================

bool CE_CheckH1(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   if(!CE_CheckStructure(
      symbol,
      direction,
      PERIOD_H1,
      10.0,
      result))
   {
      return false;
   }

   result.h1Confirmed =
      true;

   CE_AddScore(
      result,
      0.0,
      "H1 directional confirmation");

   return true;
}
//====================================================================
// H1 STRUCTURE BREAK
//====================================================================

bool CE_CheckH1Break(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   StructureSignal signal;

   ResetStructureSignal(signal);

   if(!AnalyzeStructureSignal(
      symbol,
      PERIOD_H1,
      ICT_STRUCTURE_LOOKBACK,
      signal))
   {
      return false;
   }

   if(!signal.valid)
      return false;

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      if(signal.bullishMSS)
      {
         result.mssConfirmed = true;

         CE_AddScore(
            result,
            10.0,
            "H1 bullish MSS");
      }

      if(signal.bullishBOS)
      {
         result.bosConfirmed = true;

         CE_AddScore(
            result,
            7.0,
            "H1 bullish BOS");
      }

      if(signal.bullishDisplacement)
      {
         result.displacementConfirmed = true;

         CE_AddScore(
            result,
            5.0,
            "H1 bullish displacement");
      }

      return
         signal.bullishMSS ||
         signal.bullishBOS ||
         signal.bullishDisplacement;
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      if(signal.bearishMSS)
      {
         result.mssConfirmed = true;

         CE_AddScore(
            result,
            10.0,
            "H1 bearish MSS");
      }

      if(signal.bearishBOS)
      {
         result.bosConfirmed = true;

         CE_AddScore(
            result,
            7.0,
            "H1 bearish BOS");
      }

      if(signal.bearishDisplacement)
      {
         result.displacementConfirmed = true;

         CE_AddScore(
            result,
            5.0,
            "H1 bearish displacement");
      }

      return
         signal.bearishMSS ||
         signal.bearishBOS ||
         signal.bearishDisplacement;
   }

   return false;
}

//====================================================================
// M15 STRUCTURE CONFIRMATION
//====================================================================

bool CE_CheckM15(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   StructureSignal signal;

   ResetStructureSignal(signal);

   if(!AnalyzeStructureSignal(
      symbol,
      PERIOD_M15,
      ICT_STRUCTURE_LOOKBACK,
      signal))
   {
      return false;
   }

   if(!signal.valid)
      return false;

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      if(signal.bullishMSS)
      {
         result.mssConfirmed = true;

         CE_AddScore(
            result,
            10.0,
            "M15 bullish MSS");
      }

      if(signal.bullishBOS)
      {
         result.bosConfirmed = true;

         CE_AddScore(
            result,
            7.0,
            "M15 bullish BOS");
      }

      if(signal.bullishDisplacement)
      {
         result.displacementConfirmed = true;

         CE_AddScore(
            result,
            5.0,
            "M15 bullish displacement");
      }

      if(
         signal.bullishMSS ||
         signal.bullishBOS ||
         signal.bullishDisplacement
      )
      {
         result.m15Confirmed = true;
         return true;
      }
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      if(signal.bearishMSS)
      {
         result.mssConfirmed = true;

         CE_AddScore(
            result,
            10.0,
            "M15 bearish MSS");
      }

      if(signal.bearishBOS)
      {
         result.bosConfirmed = true;

         CE_AddScore(
            result,
            7.0,
            "M15 bearish BOS");
      }

      if(signal.bearishDisplacement)
      {
         result.displacementConfirmed = true;

         CE_AddScore(
            result,
            5.0,
            "M15 bearish displacement");
      }

      if(
         signal.bearishMSS ||
         signal.bearishBOS ||
         signal.bearishDisplacement
      )
      {
         result.m15Confirmed = true;
         return true;
      }
   }

   return false;
}

//====================================================================
// M15 LIQUIDITY
//====================================================================

bool CE_CheckLiquidity(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   LiquiditySweep sweep;

   ResetLiquiditySweep(
      sweep);

   bool bullish =
      direction ==
      STRATEGY_DIRECTION_BUY;

   if(!DetectLiquiditySweep(
      symbol,
      PERIOD_M15,
      bullish,
      ICT_M15_CONFIRM_MAX_BARS,
      sweep))
   {
      return false;
   }

   if(!sweep.valid)
      return false;

   result.liquidityConfirmed =
      true;

   CE_AddScore(
      result,
      10.0,
      bullish
      ? "Bullish M15 liquidity sweep"
      : "Bearish M15 liquidity sweep");

   return true;
}

//====================================================================
// FVG CONFIRMATION
//====================================================================

bool CE_CheckFVG(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   FVGZone fvg;

   ResetFVG(fvg);

   bool bullish =
      direction ==
      STRATEGY_DIRECTION_BUY;

   if(!FindDirectionalFVG(
      symbol,
      PERIOD_M15,
      bullish,
      ICT_FVG_LOOKBACK,
      fvg))
   {
      return false;
   }

   if(!fvg.valid)
      return false;

   result.fvgConfirmed =
      true;

   CE_AddScore(
      result,
      7.0,
      bullish
      ? "Bullish M15 FVG"
      : "Bearish M15 FVG");

   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick))
   {
      return true;
   }

   double price =
      bullish
      ? tick.ask
      : tick.bid;

   if(IsPriceInsideFVG(
      fvg,
      price))
   {
      result.fvgRetestConfirmed =
         true;

      result.retestConfirmed =
         true;

      result.zoneHigh =
         fvg.upper;

      result.zoneLow =
         fvg.lower;

      CE_AddScore(
         result,
         8.0,
         "FVG retest at entry zone");
   }

   return true;
}

//====================================================================
// ORDER BLOCK CONFIRMATION
//====================================================================

bool CE_CheckOrderBlock(
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
      direction ==
      STRATEGY_DIRECTION_BUY;

   if(!FindDirectionalOrderBlock(
      symbol,
      PERIOD_M15,
      bullish,
      ICT_OB_LOOKBACK,
      ob))
   {
      return false;
   }

   if(!ob.valid)
      return false;

   result.orderBlockConfirmed =
      true;

   CE_AddScore(
      result,
      7.0,
      bullish
      ? "Bullish M15 order block"
      : "Bearish M15 order block");

   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick))
   {
      return true;
   }

   double price =
      bullish
      ? tick.ask
      : tick.bid;

   if(IsPriceInsideOrderBlock(
      ob,
      price))
   {
      result.orderBlockRetestConfirmed =
         true;

      result.retestConfirmed =
         true;

      result.zoneHigh =
         ob.upper;

      result.zoneLow =
         ob.lower;

      CE_AddScore(
         result,
         8.0,
         "Order-block retest at entry zone");
   }

   return true;
}

//====================================================================
// M5 CONFIRMATION
//====================================================================

bool CE_CheckM5(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   M5Confirmation confirmation;

   ResetM5Confirmation(
      confirmation);

   if(!AnalyzeM5Confirmation(
      symbol,
      direction,
      confirmation))
   {
      return false;
   }

   if(!confirmation.valid)
      return false;

   result.m5Confirmed =
      true;

   if(confirmation.mss)
   {
      result.mssConfirmed = true;

      CE_AddScore(
         result,
         8.0,
         "M5 MSS confirmation");
   }

   if(confirmation.bos)
   {
      result.bosConfirmed = true;

      CE_AddScore(
         result,
         6.0,
         "M5 BOS confirmation");
   }

   if(confirmation.displacement)
   {
      result.displacementConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 displacement");
   }

   if(confirmation.retest)
   {
      result.retestConfirmed = true;

      CE_AddScore(
         result,
         8.0,
         "M5 retest confirmation");
   }

   if(confirmation.fvgPresent)
   {
      result.fvgConfirmed = true;

      CE_AddScore(
         result,
         4.0,
         "M5 FVG confirmation");
   }

   if(confirmation.fvgRetest)
   {
      result.fvgRetestConfirmed = true;

      CE_AddScore(
         result,
         5.0,
         "M5 FVG retest");
   }

   if(confirmation.engulfing)
   {
      result.engulfingConfirmed = true;

      CE_AddScore(
         result,
         4.0,
         "M5 engulfing");
   }

   if(confirmation.rejection)
   {
      result.rejectionConfirmed = true;

      CE_AddScore(
         result,
         4.0,
         "M5 rejection");
   }

   if(confirmation.momentum)
   {
      result.momentumConfirmed = true;

      CE_AddScore(
         result,
         4.0,
         "M5 momentum");
   }

   result.zoneHigh =
      confirmation.entryZoneHigh;

   result.zoneLow =
      confirmation.entryZoneLow;

   return true;
}

//====================================================================
// PREMIUM / DISCOUNT
//====================================================================

bool CE_CheckPremiumDiscount(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   double high =
      GetRecentSwingHighPrice(
         symbol,
         PERIOD_H4);

   double low =
      GetRecentSwingLowPrice(
         symbol,
         PERIOD_H4);

   if(high <= 0.0 ||
      low <= 0.0 ||
      high <= low)
   {
      return false;
   }

   double midpoint =
      (high + low) * 0.5;

   double price =
      CE_CurrentPrice(
         symbol,
         direction);

   if(price <= 0.0)
      return false;

   if(
      direction ==
      STRATEGY_DIRECTION_BUY &&
      price <= midpoint
   )
   {
      result.premiumDiscountConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "BUY in discount");
      
      return true;
   }

   if(
      direction ==
      STRATEGY_DIRECTION_SELL &&
      price >= midpoint
   )
   {
      result.premiumDiscountConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "SELL in premium");

      return true;
   }

   return false;
}
//====================================================================
// BREAKOUT / RETEST CONFIRMATION
//====================================================================

bool CE_CheckBreakoutRetest(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   if(!ICT_ENABLE_BREAKOUT)
      return false;

   BreakoutRetestSignal signal;

   ResetBreakoutRetestSignal(
      signal);

   if(!BR_Analyze(
      symbol,
      PERIOD_M15,
      direction,
      ICT_RETEST_LOOKBACK,
      signal))
   {
      return false;
   }

   if(!signal.valid)
      return false;

   if(signal.breakoutConfirmed)
   {
      result.breakoutConfirmed =
         true;

      CE_AddScore(
         result,
         8.0,
         "M15 breakout confirmed");
   }

   if(signal.retestConfirmed)
   {
      result.retestConfirmed =
         true;

      CE_AddScore(
         result,
         10.0,
         "M15 breakout retest confirmed");
   }

   if(signal.failedBreakout)
   {
      result.failedBreakoutConfirmed =
         true;

      CE_AddScore(
         result,
         10.0,
         "M15 failed breakout");
   }

   if(signal.entryZoneHigh > 0.0)
      result.zoneHigh =
         signal.entryZoneHigh;

   if(signal.entryZoneLow > 0.0)
      result.zoneLow =
         signal.entryZoneLow;

   return true;
}

//====================================================================
// ADVANCED BLOCK CONFIRMATION
//====================================================================

bool CE_CheckAdvancedBlocks(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   AdvancedBlockAnalysis analysis;

   ResetAdvancedBlockAnalysis(
      analysis);

   if(!AB_Analyze(
      symbol,
      PERIOD_M15,
      direction,
      analysis))
   {
      return false;
   }

   if(!analysis.valid)
      return false;

   if(analysis.breakerConfirmed)
   {
      result.breakerConfirmed =
         true;

      CE_AddScore(
         result,
         7.0,
         "Breaker block confirmed");
   }

   if(analysis.mitigationConfirmed)
   {
      result.mitigationBlockConfirmed =
         true;

      CE_AddScore(
         result,
         7.0,
         "Mitigation block confirmed");
   }

   if(analysis.displacementOriginConfirmed)
   {
      result.displacementConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Displacement origin confirmed");
   }

   return true;
}

//====================================================================
// SESSION CONFIRMATION
//====================================================================

bool CE_CheckSession(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   if(!ICT_ENABLE_SESSION_FILTER)
      return false;

   SessionAnalysis analysis;

   ResetSessionAnalysis(
      analysis);

   if(!SE_Analyze(
      symbol,
      PERIOD_M15,
      direction,
      analysis))
   {
      return false;
   }

   if(!analysis.valid)
      return false;

   if(analysis.direction !=
      direction)
   {
      return false;
   }

   result.sessionConfirmed =
      true;

   CE_AddScore(
      result,
      5.0,
      "Trading session supports direction");

   if(analysis.liquiditySweep)
   {
      result.liquidityConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Session liquidity sweep");
   }

   if(analysis.retestConfirmed)
   {
      result.retestConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Session retest");
   }

   return true;
}

//====================================================================
// VOLATILITY CONFIRMATION
//====================================================================

bool CE_CheckVolatility(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   if(!ICT_ENABLE_VOLATILITY_FILTER)
      return false;

   VolatilityAnalysis analysis;

   ResetVolatilityAnalysis(
      analysis);

   if(!VE_Analyze(
      symbol,
      PERIOD_M15,
      analysis))
   {
      return false;
   }

   if(!analysis.valid)
      return false;

   if(!VE_IsSafe(
      analysis))
   {
      return false;
   }

   result.volatilityConfirmed =
      true;

   CE_AddScore(
      result,
      5.0,
      "Gold volatility is tradable");

   if(analysis.expansion)
   {
      CE_AddScore(
         result,
         3.0,
         "Volatility expansion");
   }

   return true;
}

//====================================================================
// PRICE ACTION CONFIRMATION
//====================================================================

bool CE_CheckPriceAction(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   PriceActionAnalysis analysis;

   ResetPriceActionAnalysis(
      analysis);

   if(!PA_Analyze(
      symbol,
      PERIOD_M5,
      direction,
      analysis))
   {
      return false;
   }

   if(!analysis.valid)
      return false;

   if(analysis.engulfing)
   {
      result.engulfingConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "M5 engulfing pattern");
   }

   if(analysis.rejection)
   {
      result.rejectionConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "M5 rejection pattern");
   }

   if(analysis.momentum)
   {
      result.momentumConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "M5 momentum candle");
   }

   if(analysis.insideBarBreakout)
   {
      result.insideBarConfirmed =
         true;

      CE_AddScore(
         result,
         4.0,
         "M5 inside-bar breakout");
   }

   return true;
}

//====================================================================
// TREND CONFIRMATION
//====================================================================

bool CE_CheckTrend(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   TrendAnalysis analysis;

   ResetTrendAnalysis(
      analysis);

   if(!TE_AnalyzeGold(
      symbol,
      analysis))
   {
      return false;
   }

   if(!analysis.valid)
      return false;

   if(TE_DominantDirection(
      analysis) !=
      direction)
   {
      return false;
   }

   result.trendConfirmed =
      true;

   CE_AddScore(
      result,
      10.0,
      "Multi-timeframe trend alignment");

   if(analysis.continuation)
   {
      result.continuationConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Trend continuation");
   }

   if(analysis.pullback)
   {
      result.pullbackConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Trend pullback");
   }

   return true;
}

//====================================================================
// REVERSAL CONFIRMATION
//====================================================================

bool CE_CheckReversal(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   ReversalAnalysis analysis;

   ResetReversalAnalysis(
      analysis);

   if(!RV_AnalyzeGold(
      symbol,
      analysis))
   {
      return false;
   }

   if(!analysis.valid)
      return false;

   if(RV_DominantDirection(
      analysis) !=
      direction)
   {
      return false;
   }

   result.reversalConfirmed =
      true;

   CE_AddScore(
      result,
      10.0,
      "Reversal engine confirms direction");

   if(analysis.liquiditySweep)
   {
      result.liquidityReversalConfirmed =
         true;

      result.liquidityConfirmed =
         true;

      CE_AddScore(
         result,
         8.0,
         "Liquidity reversal");
   }

   if(analysis.exhaustion)
   {
      result.exhaustionConfirmed =
         true;

      CE_AddScore(
         result,
         5.0,
         "Exhaustion confirmation");
   }

   if(analysis.failedBreakout)
   {
      result.failedBreakoutConfirmed =
         true;

      CE_AddScore(
         result,
         7.0,
         "Failed-breakout reversal");
   }

   return true;
}

//====================================================================
// STRUCTURAL LEVELS
//====================================================================

void CE_UpdateStructuralLevels(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   result.structuralHigh =
      GetRecentSwingHighPrice(
         symbol,
         PERIOD_H4);

   result.structuralLow =
      GetRecentSwingLowPrice(
         symbol,
         PERIOD_H4);

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      if(result.structuralLow > 0.0)
      {
         result.zoneLow =
            result.structuralLow;
      }
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      if(result.structuralHigh > 0.0)
      {
         result.zoneHigh =
            result.structuralHigh;
      }
   }
}
//====================================================================
// TRADE PLAN GENERATION
//====================================================================

bool CE_BuildTradePlan(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   TradePlan plan;

   ResetTradePlan(plan);

   if(!TP_BuildPlan(
      symbol,
      direction,
      result.entry,
      result.structuralHigh,
      result.structuralLow,
      result.zoneHigh,
      result.zoneLow,
      plan))
   {
      return false;
   }

   if(!plan.valid)
      return false;

   result.tradePlan =
      plan;

   result.entry =
      plan.entry;

   result.stopLoss =
      plan.stopLoss;

   result.takeProfit =
      plan.takeProfit;

   result.rewardRisk =
      plan.rewardRisk;

   result.planScore =
      plan.score;

   result.tradePlanConfirmed =
      true;

   if(plan.rewardRisk >=
      ICT_MIN_REWARD_RR)
   {
      result.riskRewardConfirmed =
         true;

      CE_AddScore(
         result,
         10.0,
         "Trade plan meets minimum reward/risk");
   }

   CE_AddScore(
      result,
      plan.score * 0.10,
      "Trade plan quality");

   return true;
}

//====================================================================
// FALLBACK STRUCTURAL TRADE PLAN
//====================================================================

bool CE_BuildFallbackPlan(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick))
   {
      return false;
   }

   double entry =
      direction ==
      STRATEGY_DIRECTION_BUY
      ? tick.ask
      : tick.bid;

   if(entry <= 0.0)
      return false;

   double high =
      result.structuralHigh;

   double low =
      result.structuralLow;

   if(high <= 0.0 ||
      low <= 0.0 ||
      high <= low)
   {
      return false;
   }

   double range =
      high - low;

   if(range <= 0.0)
      return false;

   double stopLoss = 0.0;
   double takeProfit = 0.0;

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      stopLoss =
         MathMin(
            low,
            result.zoneLow > 0.0
            ? result.zoneLow
            : low);

      takeProfit =
         entry +
         MathAbs(entry - stopLoss)
         * ICT_MIN_REWARD_RR;
   }
   else if(direction ==
           STRATEGY_DIRECTION_SELL)
   {
      stopLoss =
         MathMax(
            high,
            result.zoneHigh > 0.0
            ? result.zoneHigh
            : high);

      takeProfit =
         entry -
         MathAbs(entry - stopLoss)
         * ICT_MIN_REWARD_RR;
   }
   else
   {
      return false;
   }

   if(stopLoss <= 0.0 ||
      takeProfit <= 0.0)
   {
      return false;
   }

   double risk =
      MathAbs(entry - stopLoss);

   if(risk <= 0.0)
      return false;

   double reward =
      MathAbs(takeProfit - entry);

   double rr =
      reward / risk;

   if(rr < ICT_MIN_REWARD_RR)
      return false;

   result.entry =
      entry;

   result.stopLoss =
      stopLoss;

   result.takeProfit =
      takeProfit;

   result.rewardRisk =
      rr;

   result.tradePlanConfirmed =
      true;

   result.riskRewardConfirmed =
      true;

   CE_AddScore(
      result,
      5.0,
      "Structural fallback trade plan");

   return true;
}

//====================================================================
// FINAL CONFLUENCE REQUIREMENTS
//====================================================================

bool CE_CoreRequirementsMet(
   const ConfluenceResult &result
)
{
   if(!result.valid)
      return false;

   if(result.direction ==
      STRATEGY_DIRECTION_NONE)
      return false;

   /*
      Core requirement:

      1. H4 directional context
      2. At least one meaningful structural confirmation
      3. At least one liquidity/zone/retest component
      4. M15 confirmation
      5. M5 confirmation
   */

   if(!result.h4Confirmed)
      return false;

   if(!result.structureConfirmed)
      return false;

   bool zoneEvidence =
      result.liquidityConfirmed ||
      result.fvgConfirmed ||
      result.orderBlockConfirmed ||
      result.breakoutConfirmed ||
      result.retestConfirmed ||
      result.reversalConfirmed;

   if(!zoneEvidence)
      return false;

   if(!result.m15Confirmed)
      return false;

   if(!result.m5Confirmed)
      return false;

   return true;
}

//====================================================================
// FINAL SCORE
//====================================================================

double CE_FinalScore(
   ConfluenceResult &result
)
{
   double score =
      result.score;

   /*
      Reward/risk is mandatory quality,
      but it should not overpower market evidence.
   */

   if(result.riskRewardConfirmed)
      score += 5.0;

   if(result.tradePlanConfirmed)
      score += 3.0;

   /*
      Multi-timeframe alignment bonus.
   */

   if(result.h4Confirmed &&
      result.h1Confirmed &&
      result.m15Confirmed &&
      result.m5Confirmed)
   {
      score += 5.0;

      if(result.evidence == "")
         result.evidence =
            "Full H4/H1/M15/M5 alignment";
      else
         result.evidence +=
            " | Full H4/H1/M15/M5 alignment";
   }

   /*
      Liquidity + displacement + structure
      is one of the strongest ICT combinations.
   */

   if(result.liquidityConfirmed &&
      result.displacementConfirmed &&
      result.structureConfirmed)
   {
      score += 5.0;

      result.evidence +=
         " | Liquidity + displacement + structure";
   }

   /*
      Retest confirmation strengthens entries.
   */

   if(result.retestConfirmed &&
      result.m5Confirmed)
   {
      score += 5.0;

      result.evidence +=
         " | M5 retest alignment";
   }

   if(score > 100.0)
      score = 100.0;

   result.score =
      score;

   result.confidence =
      score;

   return score;
}

//====================================================================
// ACTIONABILITY
//====================================================================

bool CE_IsActionable(
   ConfluenceResult &result
)
{
   if(!CE_CoreRequirementsMet(
      result))
   {
      result.actionable =
         false;

      return false;
   }

   CE_FinalScore(
      result);

   if(result.score <
      ICT_MIN_CONFLUENCE_SCORE)
   {
      result.actionable =
         false;

      return false;
   }

   if(!result.tradePlanConfirmed)
   {
      result.actionable =
         false;

      return false;
   }

   if(!result.riskRewardConfirmed)
   {
      result.actionable =
         false;

      return false;
   }

   if(result.rewardRisk <
      ICT_MIN_REWARD_RR)
   {
      result.actionable =
         false;

      return false;
   }

   result.actionable =
      true;

   return true;
}
//====================================================================
// DIRECTION ANALYSIS
//====================================================================

bool CE_AnalyzeDirection(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction,
   ConfluenceResult &result
)
{
   CE_ResetResult(result);

   if(!CE_IsGold(symbol))
   {
      result.reason =
         "Gold-only protection rejected symbol.";
      return false;
   }

   if(!CE_HasHistory(
      symbol,
      PERIOD_H4,
      ICT_MIN_HISTORY_BARS))
   {
      result.reason =
         "Insufficient H4 history.";
      return false;
   }

   if(!CE_HasHistory(
      symbol,
      PERIOD_H1,
      ICT_MIN_HISTORY_BARS))
   {
      result.reason =
         "Insufficient H1 history.";
      return false;
   }

   if(!CE_HasHistory(
      symbol,
      PERIOD_M15,
      ICT_MIN_HISTORY_BARS))
   {
      result.reason =
         "Insufficient M15 history.";
      return false;
   }

   if(!CE_HasHistory(
      symbol,
      PERIOD_M5,
      ICT_MIN_HISTORY_BARS))
   {
      result.reason =
         "Insufficient M5 history.";
      return false;
   }

   if(direction ==
      STRATEGY_DIRECTION_NONE)
   {
      result.reason =
         "No trading direction supplied.";
      return false;
   }

   result.valid =
      true;

   result.direction =
      direction;

   //==============================================================
   // PRIMARY STRUCTURE
   //==============================================================

   CE_CheckH4(
      symbol,
      direction,
      result);

   //==============================================================
   // INTERMEDIATE STRUCTURE
   //==============================================================

   CE_CheckH1(
      symbol,
      direction,
      result);

   CE_CheckH1Break(
      symbol,
      direction,
      result);

   //==============================================================
   // M15 CONFIRMATION
   //==============================================================

   CE_CheckM15(
      symbol,
      direction,
      result);

   //==============================================================
   // LIQUIDITY
   //==============================================================

   CE_CheckLiquidity(
      symbol,
      direction,
      result);

   //==============================================================
   // ICT IMBALANCE / BLOCKS
   //==============================================================

   CE_CheckFVG(
      symbol,
      direction,
      result);

   CE_CheckOrderBlock(
      symbol,
      direction,
      result);

   CE_CheckAdvancedBlocks(
      symbol,
      direction,
      result);

   //==============================================================
   // BREAKOUT / RETEST
   //==============================================================

   CE_CheckBreakoutRetest(
      symbol,
      direction,
      result);

   //==============================================================
   // PREMIUM / DISCOUNT
   //==============================================================

   CE_CheckPremiumDiscount(
      symbol,
      direction,
      result);

   //==============================================================
   // SESSION
   //==============================================================

   CE_CheckSession(
      symbol,
      direction,
      result);

   //==============================================================
   // VOLATILITY
   //==============================================================

   CE_CheckVolatility(
      symbol,
      direction,
      result);

   //==============================================================
   // TREND / CONTINUATION
   //==============================================================

   CE_CheckTrend(
      symbol,
      direction,
      result);

   //==============================================================
   // REVERSAL
   //==============================================================

   CE_CheckReversal(
      symbol,
      direction,
      result);

   //==============================================================
   // PRICE ACTION
   //==============================================================

   CE_CheckPriceAction(
      symbol,
      direction,
      result);

   //==============================================================
   // FINAL M5 ENTRY CONFIRMATION
   //==============================================================

   CE_CheckM5(
      symbol,
      direction,
      result);

   //==============================================================
   // STRUCTURAL LEVELS
   //==============================================================

   CE_UpdateStructuralLevels(
      symbol,
      direction,
      result);

   //==============================================================
   // TRADE PLAN
   //==============================================================

   if(!CE_BuildTradePlan(
      symbol,
      direction,
      result))
   {
      /*
         The fallback is only used when the
         primary TradePlanEngine cannot build
         a plan from the detected zones.
      */

      CE_BuildFallbackPlan(
         symbol,
         direction,
         result);
   }

   //==============================================================
   // FINAL ACTIONABILITY
   //==============================================================

   CE_FinalScore(
      result);

   CE_IsActionable(
      result);

   if(result.actionable)
   {
      result.reason =
         "High-confluence gold setup confirmed.";
   }
   else
   {
      result.reason =
         "Gold setup detected but confluence requirements "
         "are not fully satisfied.";
   }

   return true;
}

//====================================================================
// FULL GOLD ANALYSIS
//====================================================================

bool CE_AnalyzeGold(
   const string symbol,
   ConfluenceResult &buyResult,
   ConfluenceResult &sellResult,
   ConfluenceResult &bestResult
)
{
   CE_ResetResult(
      buyResult);

   CE_ResetResult(
      sellResult);

   CE_ResetResult(
      bestResult);

   if(!CE_IsGold(symbol))
   {
      buyResult.reason =
         "Symbol is not XAUUSD.";

      sellResult.reason =
         "Symbol is not XAUUSD.";

      bestResult.reason =
         "Gold-only protection rejected symbol.";

      return false;
   }

   /*
      Analyze both directions independently.
      This prevents the EA from assuming direction
      before the evidence has been evaluated.
   */

   CE_AnalyzeDirection(
      symbol,
      STRATEGY_DIRECTION_BUY,
      buyResult);

   CE_AnalyzeDirection(
      symbol,
      STRATEGY_DIRECTION_SELL,
      sellResult);

   //==============================================================
   // SELECT BEST ACTIONABLE DIRECTION
   //==============================================================

   if(buyResult.actionable &&
      sellResult.actionable)
   {
      if(buyResult.score >=
         sellResult.score)
      {
         bestResult =
            buyResult;
      }
      else
      {
         bestResult =
            sellResult;
      }

      /*
         Never allow simultaneous opposite
         gold signals through the confluence layer.
      */

      return true;
   }

   if(buyResult.actionable)
   {
      bestResult =
         buyResult;

      return true;
   }

   if(sellResult.actionable)
   {
      bestResult =
         sellResult;

      return true;
   }

   /*
      No actionable setup.
      Return the stronger candidate for diagnostics,
      even though it cannot be traded.
   */

   if(buyResult.score >=
      sellResult.score)
   {
      bestResult =
         buyResult;
   }
   else
   {
      bestResult =
         sellResult;
   }

   return true;
}

//====================================================================
// RESULT DESCRIPTION
//====================================================================

string CE_ResultDescription(
   const ConfluenceResult &result
)
{
   string text =
      "Direction: ";

   if(result.direction ==
      STRATEGY_DIRECTION_BUY)
   {
      text += "BUY";
   }
   else if(result.direction ==
           STRATEGY_DIRECTION_SELL)
   {
      text += "SELL";
   }
   else
   {
      text += "NONE";
   }

   text +=
      " | Score: " +
      DoubleToString(
         result.score,
         1);

   text +=
      " | Confidence: " +
      DoubleToString(
         result.confidence,
         1);

   text +=
      " | Quality: " +
      CE_Quality(
         result.score);

   text +=
      " | RR: " +
      DoubleToString(
         result.rewardRisk,
         2);

   text +=
      " | Actionable: " +
      (result.actionable
       ? "YES"
       : "NO");

   if(result.reason != "")
   {
      text +=
         " | " +
         result.reason;
   }

   return text;
}

//====================================================================
// DIAGNOSTIC PRINT
//====================================================================

void CE_PrintResult(
   const string label,
   const ConfluenceResult &result
)
{
   Print(
      "========== ",
      label,
      " =========="
   );

   Print(
      CE_ResultDescription(
         result)
   );

   Print(
      "H4=",
      result.h4Confirmed,
      " H1=",
      result.h1Confirmed,
      " M15=",
      result.m15Confirmed,
      " M5=",
      result.m5Confirmed
   );

   Print(
      "Liquidity=",
      result.liquidityConfirmed,
      " Structure=",
      result.structureConfirmed,
      " MSS=",
      result.mssConfirmed,
      " BOS=",
      result.bosConfirmed
   );

   Print(
      "FVG=",
      result.fvgConfirmed,
      " FVGRetest=",
      result.fvgRetestConfirmed,
      " OB=",
      result.orderBlockConfirmed,
      " OBRetest=",
      result.orderBlockRetestConfirmed
   );

   Print(
      "Breaker=",
      result.breakerConfirmed,
      " Mitigation=",
      result.mitigationBlockConfirmed
   );

   Print(
      "Breakout=",
      result.breakoutConfirmed,
      " Retest=",
      result.retestConfirmed,
      " FailedBreakout=",
      result.failedBreakoutConfirmed
   );

   Print(
      "Trend=",
      result.trendConfirmed,
      " Pullback=",
      result.pullbackConfirmed,
      " Continuation=",
      result.continuationConfirmed,
      " Reversal=",
      result.reversalConfirmed
   );

   Print(
      "Engulfing=",
      result.engulfingConfirmed,
      " Rejection=",
      result.rejectionConfirmed,
      " Momentum=",
      result.momentumConfirmed,
      " InsideBar=",
      result.insideBarConfirmed
   );

   Print(
      "Session=",
      result.sessionConfirmed,
      " Volatility=",
      result.volatilityConfirmed,
      " PremiumDiscount=",
      result.premiumDiscountConfirmed
   );

   Print(
      "Entry=",
      DoubleToString(
         result.entry,
         _Digits),
      " SL=",
      DoubleToString(
         result.stopLoss,
         _Digits),
      " TP=",
      DoubleToString(
         result.takeProfit,
         _Digits)
   );

   Print(
      "Evidence: ",
      result.evidence
   );
}

//====================================================================
// STATUS
//====================================================================

string CE_Status()
{
   if(ICT_DEVELOPMENT_MODE)
      return "Confluence engine active; execution blocked by development mode.";

   return "Confluence engine active.";
}

//====================================================================
// END OF CONFLUENCE ENGINE
//====================================================================

#endif
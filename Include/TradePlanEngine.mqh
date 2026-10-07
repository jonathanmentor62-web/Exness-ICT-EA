//+------------------------------------------------------------------+
//| TradePlanEngine.mqh                                              |
//| Gold Multi-Strategy EA - Trade Planning                          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_TRADE_PLAN_ENGINE_MQH__
#define __EXNESS_GOLD_TRADE_PLAN_ENGINE_MQH__

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "StrategySignal.mqh"
#include "MarketStructure.mqh"
#include "Liquidity.mqh"
#include "FVG.mqh"
#include "OrderBlock.mqh"
#include "TrendEngine.mqh"
#include "ReversalEngine.mqh"

//-------------------------------------------------------------------
// Trade plan direction
//-------------------------------------------------------------------
enum ENUM_TRADE_PLAN_DIRECTION
{
   TRADE_PLAN_NONE = 0,
   TRADE_PLAN_BUY,
   TRADE_PLAN_SELL
};

//-------------------------------------------------------------------
// Trade plan type
//-------------------------------------------------------------------
enum ENUM_TRADE_PLAN_TYPE
{
   TRADE_PLAN_TYPE_NONE = 0,
   TRADE_PLAN_TREND_CONTINUATION,
   TRADE_PLAN_PULLBACK,
   TRADE_PLAN_BREAKOUT_RETEST,
   TRADE_PLAN_LIQUIDITY_REVERSAL,
   TRADE_PLAN_FAILED_BREAKOUT,
   TRADE_PLAN_FVG_RETEST,
   TRADE_PLAN_ORDER_BLOCK_RETEST
};

//-------------------------------------------------------------------
// Trade plan
//-------------------------------------------------------------------
struct TradePlan
{
   bool valid;
   bool goldSafe;

   ENUM_TRADE_PLAN_DIRECTION direction;
   ENUM_TRADE_PLAN_TYPE type;

   double entry;
   double entryZoneLow;
   double entryZoneHigh;

   double stopLoss;
   double takeProfit;

   double riskDistance;
   double rewardDistance;
   double rewardRisk;

   double structuralHigh;
   double structuralLow;

   double liquidityTarget;
   double structuralTarget;

   bool liquidityTargetFound;
   bool structuralTargetFound;

   bool trendConfirmed;
   bool reversalConfirmed;

   bool liquidityConfirmed;
   bool structureConfirmed;
   bool zoneConfirmed;
   bool targetConfirmed;

   double score;

   datetime signalTime;
   int signalShift;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset trade plan
//-------------------------------------------------------------------
void ResetTradePlan(
   TradePlan &p)
{
   p.valid = false;
   p.goldSafe = false;

   p.direction = TRADE_PLAN_NONE;
   p.type = TRADE_PLAN_TYPE_NONE;

   p.entry = 0.0;
   p.entryZoneLow = 0.0;
   p.entryZoneHigh = 0.0;

   p.stopLoss = 0.0;
   p.takeProfit = 0.0;

   p.riskDistance = 0.0;
   p.rewardDistance = 0.0;
   p.rewardRisk = 0.0;

   p.structuralHigh = 0.0;
   p.structuralLow = 0.0;

   p.liquidityTarget = 0.0;
   p.structuralTarget = 0.0;

   p.liquidityTargetFound = false;
   p.structuralTargetFound = false;

   p.trendConfirmed = false;
   p.reversalConfirmed = false;

   p.liquidityConfirmed = false;
   p.structureConfirmed = false;
   p.zoneConfirmed = false;
   p.targetConfirmed = false;

   p.score = 0.0;

   p.signalTime = 0;
   p.signalShift = -1;

   p.reason = "";
   p.evidence = "";
}

//-------------------------------------------------------------------
// Gold validation
//-------------------------------------------------------------------
bool TP_IsGold(
   const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//-------------------------------------------------------------------
// Direction string
//-------------------------------------------------------------------
string TP_DirectionToString(
   const ENUM_TRADE_PLAN_DIRECTION direction)
{
   if(direction == TRADE_PLAN_BUY)
      return "BUY";

   if(direction == TRADE_PLAN_SELL)
      return "SELL";

   return "NONE";
}

//-------------------------------------------------------------------
// Plan type string
//-------------------------------------------------------------------
string TP_TypeToString(
   const ENUM_TRADE_PLAN_TYPE type)
{
   switch(type)
   {
      case TRADE_PLAN_TREND_CONTINUATION:
         return "TREND CONTINUATION";

      case TRADE_PLAN_PULLBACK:
         return "PULLBACK";

      case TRADE_PLAN_BREAKOUT_RETEST:
         return "BREAKOUT RETEST";

      case TRADE_PLAN_LIQUIDITY_REVERSAL:
         return "LIQUIDITY REVERSAL";

      case TRADE_PLAN_FAILED_BREAKOUT:
         return "FAILED BREAKOUT";

      case TRADE_PLAN_FVG_RETEST:
         return "FVG RETEST";

      case TRADE_PLAN_ORDER_BLOCK_RETEST:
         return "ORDER BLOCK RETEST";

      default:
         return "NONE";
   }
}

//-------------------------------------------------------------------
// Current market price
//-------------------------------------------------------------------
double TP_CurrentPrice(
   const string symbol)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   if(tick.bid <= 0.0 ||
      tick.ask <= 0.0)
   {
      return 0.0;
   }

   return (tick.bid + tick.ask) * 0.5;
}

//-------------------------------------------------------------------
// Entry price from current market
//-------------------------------------------------------------------
double TP_MarketEntry(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   if(direction == TRADE_PLAN_BUY)
      return tick.ask;

   if(direction == TRADE_PLAN_SELL)
      return tick.bid;

   return 0.0;
}

//-------------------------------------------------------------------
// Structural high
//-------------------------------------------------------------------
double TP_StructuralHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return GetRecentSwingHighPrice(
      symbol,
      timeframe);
}

//-------------------------------------------------------------------
// Structural low
//-------------------------------------------------------------------
double TP_StructuralLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return GetRecentSwingLowPrice(
      symbol,
      timeframe);
}

//-------------------------------------------------------------------
// Buy-side liquidity target
//-------------------------------------------------------------------
double TP_BuyLiquidityTarget(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return GetNearestBuySideLiquidityPrice(
      symbol,
      timeframe);
}

//-------------------------------------------------------------------
// Sell-side liquidity target
//-------------------------------------------------------------------
double TP_SellLiquidityTarget(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe)
{
   return GetNearestSellSideLiquidityPrice(
      symbol,
      timeframe);
}

//-------------------------------------------------------------------
// Calculate risk distance
//-------------------------------------------------------------------
double TP_RiskDistance(
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double stopLoss)
{
   if(entry <= 0.0 ||
      stopLoss <= 0.0)
   {
      return 0.0;
   }

   if(direction == TRADE_PLAN_BUY)
   {
      if(stopLoss >= entry)
         return 0.0;

      return entry - stopLoss;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      if(stopLoss <= entry)
         return 0.0;

      return stopLoss - entry;
   }

   return 0.0;
}

//-------------------------------------------------------------------
// Calculate reward distance
//-------------------------------------------------------------------
double TP_RewardDistance(
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double takeProfit)
{
   if(entry <= 0.0 ||
      takeProfit <= 0.0)
   {
      return 0.0;
   }

   if(direction == TRADE_PLAN_BUY)
   {
      if(takeProfit <= entry)
         return 0.0;

      return takeProfit - entry;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      if(takeProfit >= entry)
         return 0.0;

      return entry - takeProfit;
   }

   return 0.0;
}

//-------------------------------------------------------------------
// Calculate RR
//-------------------------------------------------------------------
double TP_CalculateRR(
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double stopLoss,
   const double takeProfit)
{
   double risk =
      TP_RiskDistance(
         direction,
         entry,
         stopLoss);

   double reward =
      TP_RewardDistance(
         direction,
         entry,
         takeProfit);

   if(risk <= 0.0 ||
      reward <= 0.0)
   {
      return 0.0;
   }

   return reward / risk;
}
//-------------------------------------------------------------------
// Build structural stop for BUY
//-------------------------------------------------------------------
double TP_BuildBuyStop(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double entry)
{
   double swingLow =
      TP_StructuralLow(
         symbol,
         timeframe);

   if(swingLow <= 0.0 ||
      swingLow >= entry)
   {
      return 0.0;
   }

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT);

   if(point <= 0.0)
      return 0.0;

   // Small structural buffer below the swing.
   double buffer =
      MathMax(
         (double)ICT_MIN_STOP_DISTANCE_PTS,
         5.0) * point;

   return swingLow - buffer;
}

//-------------------------------------------------------------------
// Build structural stop for SELL
//-------------------------------------------------------------------
double TP_BuildSellStop(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double entry)
{
   double swingHigh =
      TP_StructuralHigh(
         symbol,
         timeframe);

   if(swingHigh <= 0.0 ||
      swingHigh <= entry)
   {
      return 0.0;
   }

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT);

   if(point <= 0.0)
      return 0.0;

   double buffer =
      MathMax(
         (double)ICT_MIN_STOP_DISTANCE_PTS,
         5.0) * point;

   return swingHigh + buffer;
}

//-------------------------------------------------------------------
// Select structural stop using H4 and H1
//-------------------------------------------------------------------
double TP_SelectStop(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry)
{
   if(direction == TRADE_PLAN_BUY)
   {
      double h4Stop =
         TP_BuildBuyStop(
            symbol,
            PERIOD_H4,
            entry);

      double h1Stop =
         TP_BuildBuyStop(
            symbol,
            PERIOD_H1,
            entry);

      if(h4Stop > 0.0 &&
         h1Stop > 0.0)
      {
         // Use the deeper structural stop.
         return MathMin(
            h4Stop,
            h1Stop);
      }

      if(h4Stop > 0.0)
         return h4Stop;

      return h1Stop;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      double h4Stop =
         TP_BuildSellStop(
            symbol,
            PERIOD_H4,
            entry);

      double h1Stop =
         TP_BuildSellStop(
            symbol,
            PERIOD_H1,
            entry);

      if(h4Stop > 0.0 &&
         h1Stop > 0.0)
      {
         // Use the deeper structural stop.
         return MathMax(
            h4Stop,
            h1Stop);
      }

      if(h4Stop > 0.0)
         return h4Stop;

      return h1Stop;
   }

   return 0.0;
}

//-------------------------------------------------------------------
// Select structural target for BUY
//-------------------------------------------------------------------
double TP_SelectBuyTarget(
   const string symbol,
   const double entry)
{
   double target =
      TP_BuyLiquidityTarget(
         symbol,
         PERIOD_H4);

   if(target > entry)
      return target;

   target =
      TP_StructuralHigh(
         symbol,
         PERIOD_H4);

   if(target > entry)
      return target;

   target =
      TP_BuyLiquidityTarget(
         symbol,
         PERIOD_H1);

   if(target > entry)
      return target;

   return 0.0;
}

//-------------------------------------------------------------------
// Select structural target for SELL
//-------------------------------------------------------------------
double TP_SelectSellTarget(
   const string symbol,
   const double entry)
{
   double target =
      TP_SellLiquidityTarget(
         symbol,
         PERIOD_H4);

   if(target > 0.0 &&
      target < entry)
   {
      return target;
   }

   target =
      TP_StructuralLow(
         symbol,
         PERIOD_H4);

   if(target > 0.0 &&
      target < entry)
   {
      return target;
   }

   target =
      TP_SellLiquidityTarget(
         symbol,
         PERIOD_H1);

   if(target > 0.0 &&
      target < entry)
   {
      return target;
   }

   return 0.0;
}

//-------------------------------------------------------------------
// Calculate minimum RR target
//-------------------------------------------------------------------
double TP_MinimumRRTarget(
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double stopLoss)
{
   double risk =
      TP_RiskDistance(
         direction,
         entry,
         stopLoss);

   if(risk <= 0.0)
      return 0.0;

   if(direction == TRADE_PLAN_BUY)
   {
      return entry +
             risk *
             ICT_MIN_REWARD_RR;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      return entry -
             risk *
             ICT_MIN_REWARD_RR;
   }

   return 0.0;
}

//-------------------------------------------------------------------
// Improve target using minimum RR
//-------------------------------------------------------------------
double TP_ValidateTarget(
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double stopLoss,
   const double proposedTarget)
{
   double minimumTarget =
      TP_MinimumRRTarget(
         direction,
         entry,
         stopLoss);

   if(minimumTarget <= 0.0)
      return 0.0;

   if(direction == TRADE_PLAN_BUY)
   {
      if(proposedTarget >=
         minimumTarget)
      {
         return proposedTarget;
      }

      return minimumTarget;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      if(proposedTarget <=
         minimumTarget)
      {
         return proposedTarget;
      }

      return minimumTarget;
   }

   return 0.0;
}

//-------------------------------------------------------------------
// Build BUY plan
//-------------------------------------------------------------------
bool TP_BuildBuyPlan(
   const string symbol,
   TradePlan &out)
{
   double entry =
      TP_MarketEntry(
         symbol,
         TRADE_PLAN_BUY);

   if(entry <= 0.0)
      return false;

   double stopLoss =
      TP_SelectStop(
         symbol,
         TRADE_PLAN_BUY,
         entry);

   if(stopLoss <= 0.0)
      return false;

   double target =
      TP_SelectBuyTarget(
         symbol,
         entry);

   target =
      TP_ValidateTarget(
         TRADE_PLAN_BUY,
         entry,
         stopLoss,
         target);

   if(target <= 0.0)
      return false;

   out.direction =
      TRADE_PLAN_BUY;

   out.entry = entry;
   out.stopLoss = stopLoss;
   out.takeProfit = target;

   out.riskDistance =
      TP_RiskDistance(
         TRADE_PLAN_BUY,
         entry,
         stopLoss);

   out.rewardDistance =
      TP_RewardDistance(
         TRADE_PLAN_BUY,
         entry,
         target);

   out.rewardRisk =
      TP_CalculateRR(
         TRADE_PLAN_BUY,
         entry,
         stopLoss,
         target);

   return out.rewardRisk >=
          ICT_MIN_REWARD_RR;
}

//-------------------------------------------------------------------
// Build SELL plan
//-------------------------------------------------------------------
bool TP_BuildSellPlan(
   const string symbol,
   TradePlan &out)
{
   double entry =
      TP_MarketEntry(
         symbol,
         TRADE_PLAN_SELL);

   if(entry <= 0.0)
      return false;

   double stopLoss =
      TP_SelectStop(
         symbol,
         TRADE_PLAN_SELL,
         entry);

   if(stopLoss <= 0.0)
      return false;

   double target =
      TP_SelectSellTarget(
         symbol,
         entry);

   target =
      TP_ValidateTarget(
         TRADE_PLAN_SELL,
         entry,
         stopLoss,
         target);

   if(target <= 0.0)
      return false;

   out.direction =
      TRADE_PLAN_SELL;

   out.entry = entry;
   out.stopLoss = stopLoss;
   out.takeProfit = target;

   out.riskDistance =
      TP_RiskDistance(
         TRADE_PLAN_SELL,
         entry,
         stopLoss);

   out.rewardDistance =
      TP_RewardDistance(
         TRADE_PLAN_SELL,
         entry,
         target);

   out.rewardRisk =
      TP_CalculateRR(
         TRADE_PLAN_SELL,
         entry,
         stopLoss,
         target);

   return out.rewardRisk >=
          ICT_MIN_REWARD_RR;
}
//-------------------------------------------------------------------
// Determine whether a plan has a valid directional structure
//-------------------------------------------------------------------
bool TP_StructureSupportsDirection(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction)
{
   MarketStructureState h4;
   MarketStructureState h1;

   MS_ResetState(h4);
   MS_ResetState(h1);

   if(!MS_GetState(
      symbol,
      PERIOD_H4,
      ICT_STRUCTURE_LOOKBACK,
      h4))
   {
      return false;
   }

   if(!MS_GetState(
      symbol,
      PERIOD_H1,
      ICT_STRUCTURE_LOOKBACK,
      h1))
   {
      return false;
   }

   if(direction == TRADE_PLAN_BUY)
   {
      bool h4Bullish =
         h4.bullishHH ||
         h4.bullishHL ||
         h4.bullishBreak ||
         h4.bullishMSS;

      bool h1Bullish =
         h1.bullishHH ||
         h1.bullishHL ||
         h1.bullishBreak ||
         h1.bullishMSS;

      return h4Bullish || h1Bullish;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      bool h4Bearish =
         h4.bearishLH ||
         h4.bearishLL ||
         h4.bearishBreak ||
         h4.bearishMSS;

      bool h1Bearish =
         h1.bearishLH ||
         h1.bearishLL ||
         h1.bearishBreak ||
         h1.bearishMSS;

      return h4Bearish || h1Bearish;
   }

   return false;
}

//-------------------------------------------------------------------
// Determine whether liquidity supports the direction
//-------------------------------------------------------------------
bool TP_LiquiditySupportsDirection(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction)
{
   if(direction == TRADE_PLAN_BUY)
   {
      double target =
         TP_BuyLiquidityTarget(
            symbol,
            PERIOD_H4);

      double entry =
         TP_MarketEntry(
            symbol,
            TRADE_PLAN_BUY);

      return target > entry;
   }

   if(direction == TRADE_PLAN_SELL)
   {
      double target =
         TP_SellLiquidityTarget(
            symbol,
            PERIOD_H4);

      double entry =
         TP_MarketEntry(
            symbol,
            TRADE_PLAN_SELL);

      return target > 0.0 &&
             target < entry;
   }

   return false;
}

//-------------------------------------------------------------------
// Determine whether the structural stop is safe
//-------------------------------------------------------------------
bool TP_StopIsValid(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double stopLoss)
{
   if(entry <= 0.0 ||
      stopLoss <= 0.0)
   {
      return false;
   }

   if(direction == TRADE_PLAN_BUY)
   {
      if(stopLoss >= entry)
         return false;
   }
   else if(direction == TRADE_PLAN_SELL)
   {
      if(stopLoss <= entry)
         return false;
   }
   else
   {
      return false;
   }

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT);

   if(point <= 0.0)
      return false;

   long stopsLevel = 0;
   long freezeLevel = 0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_STOPS_LEVEL,
      stopsLevel))
   {
      return false;
   }

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_FREEZE_LEVEL,
      freezeLevel))
   {
      return false;
   }

   double minimumPoints =
      MathMax(
         (double)ICT_MIN_STOP_DISTANCE_PTS,
         MathMax(
            (double)stopsLevel,
            (double)freezeLevel));

   double distance =
      MathAbs(entry - stopLoss);

   return distance >=
          minimumPoints * point;
}

//-------------------------------------------------------------------
// Determine whether TP is valid
//-------------------------------------------------------------------
bool TP_TargetIsValid(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double entry,
   const double takeProfit)
{
   if(entry <= 0.0 ||
      takeProfit <= 0.0)
   {
      return false;
   }

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT);

   if(point <= 0.0)
      return false;

   if(direction == TRADE_PLAN_BUY &&
      takeProfit <= entry)
   {
      return false;
   }

   if(direction == TRADE_PLAN_SELL &&
      takeProfit >= entry)
   {
      return false;
   }

   long stopsLevel = 0;
   long freezeLevel = 0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_STOPS_LEVEL,
      stopsLevel))
   {
      return false;
   }

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_FREEZE_LEVEL,
      freezeLevel))
   {
      return false;
   }

   double minimumPoints =
      MathMax(
         (double)ICT_MIN_STOP_DISTANCE_PTS,
         MathMax(
            (double)stopsLevel,
            (double)freezeLevel));

   double distance =
      MathAbs(
         takeProfit - entry);

   return distance >=
          minimumPoints * point;
}

//-------------------------------------------------------------------
// Score a trade plan
//-------------------------------------------------------------------
double TP_ScorePlan(
   const string symbol,
   const ENUM_TRADE_PLAN_DIRECTION direction,
   const double rewardRisk)
{
   double score = 0.0;

   if(!TP_IsGold(symbol))
      return 0.0;

   if(TP_StructureSupportsDirection(
      symbol,
      direction))
   {
      score += 25.0;
   }

   if(TP_LiquiditySupportsDirection(
      symbol,
      direction))
   {
      score += 20.0;
   }

   if(rewardRisk >= ICT_MIN_REWARD_RR)
      score += 20.0;

   if(rewardRisk >= 3.0)
      score += 10.0;

   if(rewardRisk >= 4.0)
      score += 10.0;

   if(direction == TRADE_PLAN_BUY ||
      direction == TRADE_PLAN_SELL)
   {
      score += 15.0;
   }

   return MathMin(
      score,
      100.0);
}

//-------------------------------------------------------------------
// Validate complete trade plan
//-------------------------------------------------------------------
bool TP_ValidatePlan(
   const string symbol,
   TradePlan &plan)
{
   if(!TP_IsGold(symbol))
   {
      plan.reason =
         "Gold-only protection rejected symbol.";
      return false;
   }

   if(plan.direction ==
      TRADE_PLAN_NONE)
   {
      plan.reason =
         "No trade direction.";
      return false;
   }

   if(plan.entry <= 0.0 ||
      plan.stopLoss <= 0.0 ||
      plan.takeProfit <= 0.0)
   {
      plan.reason =
         "Incomplete trade levels.";
      return false;
   }

   if(!TP_StopIsValid(
      symbol,
      plan.direction,
      plan.entry,
      plan.stopLoss))
   {
      plan.reason =
         "Structural stop is invalid.";
      return false;
   }

   if(!TP_TargetIsValid(
      symbol,
      plan.direction,
      plan.entry,
      plan.takeProfit))
   {
      plan.reason =
         "Take-profit is invalid.";
      return false;
   }

   plan.riskDistance =
      TP_RiskDistance(
         plan.direction,
         plan.entry,
         plan.stopLoss);

   plan.rewardDistance =
      TP_RewardDistance(
         plan.direction,
         plan.entry,
         plan.takeProfit);

   plan.rewardRisk =
      TP_CalculateRR(
         plan.direction,
         plan.entry,
         plan.stopLoss,
         plan.takeProfit);

   if(plan.riskDistance <= 0.0)
   {
      plan.reason =
         "Risk distance is invalid.";
      return false;
   }

   if(plan.rewardDistance <= 0.0)
   {
      plan.reason =
         "Reward distance is invalid.";
      return false;
   }

   if(plan.rewardRisk <
      ICT_MIN_REWARD_RR)
   {
      plan.reason =
         "Minimum reward-to-risk requirement failed.";
      return false;
   }

   plan.score =
      TP_ScorePlan(
         symbol,
         plan.direction,
         plan.rewardRisk);

   plan.goldSafe = true;

   plan.reason =
      "Trade plan passed structural validation.";

   return true;
}

//-------------------------------------------------------------------
// Add readable evidence
//-------------------------------------------------------------------
void TP_AddEvidence(
   TradePlan &plan,
   const string text)
{
   if(text == "")
      return;

   if(plan.evidence == "")
      plan.evidence = text;
   else
      plan.evidence += " | " + text;
}

//-------------------------------------------------------------------
// Prepare BUY plan
//-------------------------------------------------------------------
bool TP_PrepareBuyPlan(
   const string symbol,
   TradePlan &out)
{
   ResetTradePlan(out);

   if(!TP_IsGold(symbol))
   {
      out.reason =
         "Symbol is not gold.";
      return false;
   }

   if(!TP_BuildBuyPlan(
      symbol,
      out))
   {
      out.reason =
         "Unable to construct BUY plan.";
      return false;
   }

   out.type =
      TRADE_PLAN_TREND_CONTINUATION;

   out.structuralHigh =
      TP_StructuralHigh(
         symbol,
         PERIOD_H4);

   out.structuralLow =
      TP_StructuralLow(
         symbol,
         PERIOD_H4);

   out.liquidityTarget =
      TP_BuyLiquidityTarget(
         symbol,
         PERIOD_H4);

   out.liquidityTargetFound =
      out.liquidityTarget >
      out.entry;

   out.structuralTarget =
      out.structuralHigh;

   out.structuralTargetFound =
      out.structuralTarget >
      out.entry;

   out.structureConfirmed =
      TP_StructureSupportsDirection(
         symbol,
         TRADE_PLAN_BUY);

   out.liquidityConfirmed =
      TP_LiquiditySupportsDirection(
         symbol,
         TRADE_PLAN_BUY);

   out.targetConfirmed =
      out.liquidityTargetFound ||
      out.structuralTargetFound;

   out.trendConfirmed =
      out.structureConfirmed;

   TP_AddEvidence(
      out,
      "BUY structural plan");

   if(out.structureConfirmed)
      TP_AddEvidence(
         out,
         "H4/H1 bullish structure");

   if(out.liquidityConfirmed)
      TP_AddEvidence(
         out,
         "Upside liquidity available");

   if(out.rewardRisk >= 3.0)
      TP_AddEvidence(
         out,
         "RR >= 3");

   return TP_ValidatePlan(
      symbol,
      out);
}

//-------------------------------------------------------------------
// Prepare SELL plan
//-------------------------------------------------------------------
bool TP_PrepareSellPlan(
   const string symbol,
   TradePlan &out)
{
   ResetTradePlan(out);

   if(!TP_IsGold(symbol))
   {
      out.reason =
         "Symbol is not gold.";
      return false;
   }

   if(!TP_BuildSellPlan(
      symbol,
      out))
   {
      out.reason =
         "Unable to construct SELL plan.";
      return false;
   }

   out.type =
      TRADE_PLAN_TREND_CONTINUATION;

   out.structuralHigh =
      TP_StructuralHigh(
         symbol,
         PERIOD_H4);

   out.structuralLow =
      TP_StructuralLow(
         symbol,
         PERIOD_H4);

   out.liquidityTarget =
      TP_SellLiquidityTarget(
         symbol,
         PERIOD_H4);

   out.liquidityTargetFound =
      out.liquidityTarget > 0.0 &&
      out.liquidityTarget <
      out.entry;

   out.structuralTarget =
      out.structuralLow;

   out.structuralTargetFound =
      out.structuralTarget > 0.0 &&
      out.structuralTarget <
      out.entry;

   out.structureConfirmed =
      TP_StructureSupportsDirection(
         symbol,
         TRADE_PLAN_SELL);

   out.liquidityConfirmed =
      TP_LiquiditySupportsDirection(
         symbol,
         TRADE_PLAN_SELL);

   out.targetConfirmed =
      out.liquidityTargetFound ||
      out.structuralTargetFound;

   out.trendConfirmed =
      out.structureConfirmed;

   TP_AddEvidence(
      out,
      "SELL structural plan");

   if(out.structureConfirmed)
      TP_AddEvidence(
         out,
         "H4/H1 bearish structure");

   if(out.liquidityConfirmed)
      TP_AddEvidence(
         out,
         "Downside liquidity available");

   if(out.rewardRisk >= 3.0)
      TP_AddEvidence(
         out,
         "RR >= 3");

   return TP_ValidatePlan(
      symbol,
      out);
}
//-------------------------------------------------------------------
// Choose the stronger of BUY and SELL plans
//-------------------------------------------------------------------
bool TP_SelectBestPlan(
   const TradePlan &buyPlan,
   const TradePlan &sellPlan,
   TradePlan &bestPlan)
{
   ResetTradePlan(bestPlan);

   bool buyValid =
      buyPlan.valid &&
      buyPlan.goldSafe;

   bool sellValid =
      sellPlan.valid &&
      sellPlan.goldSafe;

   if(!buyValid && !sellValid)
      return false;

   if(buyValid && !sellValid)
   {
      bestPlan = buyPlan;
      return true;
   }

   if(sellValid && !buyValid)
   {
      bestPlan = sellPlan;
      return true;
   }

   if(buyPlan.score > sellPlan.score)
   {
      bestPlan = buyPlan;
      return true;
   }

   if(sellPlan.score > buyPlan.score)
   {
      bestPlan = sellPlan;
      return true;
   }

   // If scores are equal, prefer the plan
   // with the better reward-to-risk ratio.
   if(buyPlan.rewardRisk >=
      sellPlan.rewardRisk)
   {
      bestPlan = buyPlan;
   }
   else
   {
      bestPlan = sellPlan;
   }

   return true;
}

//-------------------------------------------------------------------
// Analyze complete gold trade plan
//-------------------------------------------------------------------
bool TP_AnalyzeGold(
   const string symbol,
   TradePlan &bestPlan)
{
   ResetTradePlan(bestPlan);

   if(!TP_IsGold(symbol))
   {
      bestPlan.reason =
         "Trade planner accepts gold only.";
      return false;
   }

   if(!SymbolSelect(symbol,true))
   {
      bestPlan.reason =
         "Gold symbol could not be selected.";
      return false;
   }

   if(Bars(
      symbol,
      PERIOD_H4) <
      ICT_MIN_HISTORY_BARS)
   {
      bestPlan.reason =
         "Insufficient H4 history.";
      return false;
   }

   TradePlan buyPlan;
   TradePlan sellPlan;

   ResetTradePlan(buyPlan);
   ResetTradePlan(sellPlan);

   bool buyReady =
      TP_PrepareBuyPlan(
         symbol,
         buyPlan);

   bool sellReady =
      TP_PrepareSellPlan(
         symbol,
         sellPlan);

   if(buyReady)
      buyPlan.valid = true;

   if(sellReady)
      sellPlan.valid = true;

   if(!TP_SelectBestPlan(
      buyPlan,
      sellPlan,
      bestPlan))
   {
      bestPlan.reason =
         "No valid gold trade plan.";
      return false;
   }

   bestPlan.signalTime =
      iTime(
         symbol,
         PERIOD_H4,
         1);

   bestPlan.signalShift = 1;

   if(bestPlan.direction ==
      TRADE_PLAN_BUY)
   {
      bestPlan.reason =
         "Best BUY gold trade plan selected.";
   }
   else if(bestPlan.direction ==
           TRADE_PLAN_SELL)
   {
      bestPlan.reason =
         "Best SELL gold trade plan selected.";
   }

   bestPlan.valid = true;

   return true;
}

//-------------------------------------------------------------------
// Determine whether plan is strong enough for confluence
//-------------------------------------------------------------------
bool TP_IsActionable(
   const TradePlan &plan)
{
   if(!plan.valid)
      return false;

   if(!plan.goldSafe)
      return false;

   if(plan.direction ==
      TRADE_PLAN_NONE)
   {
      return false;
   }

   if(plan.entry <= 0.0 ||
      plan.stopLoss <= 0.0 ||
      plan.takeProfit <= 0.0)
   {
      return false;
   }

   if(plan.rewardRisk <
      ICT_MIN_REWARD_RR)
   {
      return false;
   }

   if(plan.score <
      ICT_MIN_CONFLUENCE_SCORE)
   {
      return false;
   }

   if(!plan.structureConfirmed)
      return false;

   if(!plan.targetConfirmed)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Human-readable plan description
//-------------------------------------------------------------------
string TP_Describe(
   const TradePlan &plan)
{
   string text = "";

   text +=
      "Direction=" +
      TP_DirectionToString(
         plan.direction);

   text +=
      " | Type=" +
      TP_TypeToString(
         plan.type);

   text +=
      " | Entry=" +
      DoubleToString(
         plan.entry,
         _Digits);

   text +=
      " | SL=" +
      DoubleToString(
         plan.stopLoss,
         _Digits);

   text +=
      " | TP=" +
      DoubleToString(
         plan.takeProfit,
         _Digits);

   text +=
      " | RR=" +
      DoubleToString(
         plan.rewardRisk,
         2);

   text +=
      " | Score=" +
      DoubleToString(
         plan.score,
         1);

   return text;
}

//-------------------------------------------------------------------
// Print trade plan
//-------------------------------------------------------------------
void TP_PrintPlan(
   const TradePlan &plan)
{
   Print(
      "========== GOLD TRADE PLAN ==========");

   Print(
      "Valid: ",
      plan.valid ? "YES" : "NO");

   Print(
      "Gold Safe: ",
      plan.goldSafe ? "YES" : "NO");

   Print(
      "Direction: ",
      TP_DirectionToString(
         plan.direction));

   Print(
      "Type: ",
      TP_TypeToString(
         plan.type));

   Print(
      "Entry: ",
      DoubleToString(
         plan.entry,
         _Digits));

   Print(
      "SL: ",
      DoubleToString(
         plan.stopLoss,
         _Digits));

   Print(
      "TP: ",
      DoubleToString(
         plan.takeProfit,
         _Digits));

   Print(
      "Risk Distance: ",
      DoubleToString(
         plan.riskDistance,
         _Digits));

   Print(
      "Reward Distance: ",
      DoubleToString(
         plan.rewardDistance,
         _Digits));

   Print(
      "RR: ",
      DoubleToString(
         plan.rewardRisk,
         2));

   Print(
      "Score: ",
      DoubleToString(
         plan.score,
         1));

   Print(
      "Structure Confirmed: ",
      plan.structureConfirmed ?
      "YES" : "NO");

   Print(
      "Liquidity Confirmed: ",
      plan.liquidityConfirmed ?
      "YES" : "NO");

   Print(
      "Target Confirmed: ",
      plan.targetConfirmed ?
      "YES" : "NO");

   Print(
      "Actionable: ",
      TP_IsActionable(plan) ?
      "YES" : "NO");

   Print(
      "Reason: ",
      plan.reason);

   Print(
      "Evidence: ",
      plan.evidence);

   Print(
      "=====================================");
}

//-------------------------------------------------------------------
// Planner status
//-------------------------------------------------------------------
string TP_Status(
   const string symbol)
{
   if(!TP_IsGold(symbol))
      return "TRADE PLAN: GOLD ONLY";

   TradePlan plan;

   if(!TP_AnalyzeGold(
      symbol,
      plan))
   {
      return
         "TRADE PLAN: NO VALID PLAN";
   }

   string status =
      "TRADE PLAN: " +
      TP_DirectionToString(
         plan.direction);

   status +=
      " | Score=" +
      DoubleToString(
         plan.score,
         1);

   status +=
      " | RR=" +
      DoubleToString(
         plan.rewardRisk,
         2);

   status +=
      " | Actionable=" +
      string(
         TP_IsActionable(plan) ?
         "YES" : "NO");

   return status;
}

//-------------------------------------------------------------------
// Validate plan before handing it to execution layer
//-------------------------------------------------------------------
bool TP_ReadyForExecution(
   const string symbol,
   const TradePlan &plan)
{
   if(ICT_DEVELOPMENT_MODE)
      return false;

   if(!ICT_TRADING_DEFAULT_ENABLED)
      return false;

   if(!TP_IsGold(symbol))
      return false;

   if(!TP_IsActionable(plan))
      return false;

   if(!TP_StopIsValid(
      symbol,
      plan.direction,
      plan.entry,
      plan.stopLoss))
   {
      return false;
   }

   if(!TP_TargetIsValid(
      symbol,
      plan.direction,
      plan.entry,
      plan.takeProfit))
   {
      return false;
   }

   return true;
}

//-------------------------------------------------------------------
// Final file closure
//-------------------------------------------------------------------
#endif
//+------------------------------------------------------------------+
//| StrategySignal.mqh                                               |
//| Gold Multi-Strategy EA - Unified Strategy Signal                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_STRATEGY_SIGNAL_MQH__
#define __EXNESS_GOLD_STRATEGY_SIGNAL_MQH__

#include "Config.mqh"

//====================================================================
// STRATEGY FAMILY
//====================================================================

enum ENUM_STRATEGY_FAMILY
{
   STRATEGY_NONE = 0,

   // ICT / Smart Money Concepts
   STRATEGY_LIQUIDITY_SWEEP,
   STRATEGY_MSS,
   STRATEGY_BOS,
   STRATEGY_CHOCH,
   STRATEGY_DISPLACEMENT,
   STRATEGY_FVG_RETEST,
   STRATEGY_ORDER_BLOCK,
   STRATEGY_BREAKER_BLOCK,
   STRATEGY_MITIGATION_BLOCK,
   STRATEGY_PREMIUM_DISCOUNT,

   // Breakout / Retest
   STRATEGY_BREAKOUT,
   STRATEGY_BREAKOUT_RETEST,
   STRATEGY_FAILED_BREAKOUT,
   STRATEGY_SUPPORT_RESISTANCE_RETEST,
   STRATEGY_RANGE_BREAKOUT,
   STRATEGY_LIQUIDITY_GRAB_REVERSAL,

   // Trend / continuation
   STRATEGY_TREND_CONTINUATION,
   STRATEGY_PULLBACK_CONTINUATION,
   STRATEGY_MOMENTUM_CONTINUATION,

   // Reversal
   STRATEGY_LIQUIDITY_REVERSAL,
   STRATEGY_EXHAUSTION_REVERSAL,
   STRATEGY_REJECTION_REVERSAL,
   STRATEGY_DIVERGENCE_REVERSAL,

   // Price action
   STRATEGY_ENGULFING,
   STRATEGY_PIN_BAR,
   STRATEGY_REJECTION_CANDLE,
   STRATEGY_INSIDE_BAR,
   STRATEGY_MOMENTUM_CANDLE,

   // Session / volatility
   STRATEGY_SESSION_SETUP,
   STRATEGY_VOLATILITY_EXPANSION,
   STRATEGY_VOLATILITY_CONTRACTION
};

//====================================================================
// SIGNAL DIRECTION
//====================================================================

enum ENUM_STRATEGY_DIRECTION
{
   STRATEGY_DIRECTION_NONE = 0,
   STRATEGY_DIRECTION_BUY,
   STRATEGY_DIRECTION_SELL
};

//====================================================================
// SIGNAL QUALITY
//====================================================================

enum ENUM_SIGNAL_QUALITY
{
   SIGNAL_QUALITY_NONE = 0,
   SIGNAL_QUALITY_WEAK,
   SIGNAL_QUALITY_MODERATE,
   SIGNAL_QUALITY_STRONG,
   SIGNAL_QUALITY_HIGH_CONFLUENCE
};

//====================================================================
// STRATEGY SIGNAL
//====================================================================
//
// Every strategy must eventually speak through this structure.
//
// The strategy itself proposes a trade.
// The confluence engine decides whether enough independent evidence
// exists.
// The risk engine remains the final authority.
//
//====================================================================

struct StrategySignal
{
   // Basic state
   bool valid;
   bool actionable;

   ENUM_STRATEGY_FAMILY family;
   ENUM_STRATEGY_DIRECTION direction;
   ENUM_SIGNAL_QUALITY quality;

   // Identification
   string strategyName;
   string reason;

   // Timeframes
   ENUM_TIMEFRAMES primaryTF;
   ENUM_TIMEFRAMES confirmationTF;
   ENUM_TIMEFRAMES entryTF;

   // Price structure
   double entry;
   double stopLoss;
   double takeProfit;

   double structuralHigh;
   double structuralLow;

   // Strategy zone
   double zoneHigh;
   double zoneLow;
   double zoneMid;

   // Risk / reward
   double riskDistance;
   double rewardDistance;
   double rewardRiskRatio;

   // Strategy score
   double strategyScore;
   double confidence;

   // Evidence flags
   bool structureConfirmed;
   bool liquidityConfirmed;
   bool displacementConfirmed;
   bool mssConfirmed;
   bool bosConfirmed;
   bool chochConfirmed;

   bool fvgPresent;
   bool fvgRetestConfirmed;

   bool orderBlockPresent;
   bool orderBlockRetestConfirmed;

   bool breakerBlockPresent;
   bool mitigationBlockPresent;

   bool breakoutConfirmed;
   bool retestConfirmed;
   bool failedBreakoutConfirmed;

   bool trendConfirmed;
   bool pullbackConfirmed;

   bool engulfingConfirmed;
   bool pinBarConfirmed;
   bool rejectionConfirmed;
   bool insideBarConfirmed;
   bool momentumConfirmed;

   bool sessionConfirmed;
   bool volatilityConfirmed;

   bool premiumDiscountConfirmed;

   // Liquidity information
   double liquidityLevel;
   double liquidityDistance;
   bool liquiditySwept;

   // Signal timing
   datetime signalTime;
   int signalShift;

   // Diagnostic text
   string evidence;
};

//====================================================================
// RESET
//====================================================================

void ResetStrategySignal(StrategySignal &s)
{
   s.valid = false;
   s.actionable = false;

   s.family = STRATEGY_NONE;
   s.direction = STRATEGY_DIRECTION_NONE;
   s.quality = SIGNAL_QUALITY_NONE;

   s.strategyName = "";
   s.reason = "";

   s.primaryTF = PERIOD_H4;
   s.confirmationTF = PERIOD_M15;
   s.entryTF = PERIOD_M5;

   s.entry = 0.0;
   s.stopLoss = 0.0;
   s.takeProfit = 0.0;

   s.structuralHigh = 0.0;
   s.structuralLow = 0.0;

   s.zoneHigh = 0.0;
   s.zoneLow = 0.0;
   s.zoneMid = 0.0;

   s.riskDistance = 0.0;
   s.rewardDistance = 0.0;
   s.rewardRiskRatio = 0.0;

   s.strategyScore = 0.0;
   s.confidence = 0.0;

   s.structureConfirmed = false;
   s.liquidityConfirmed = false;
   s.displacementConfirmed = false;
   s.mssConfirmed = false;
   s.bosConfirmed = false;
   s.chochConfirmed = false;

   s.fvgPresent = false;
   s.fvgRetestConfirmed = false;

   s.orderBlockPresent = false;
   s.orderBlockRetestConfirmed = false;

   s.breakerBlockPresent = false;
   s.mitigationBlockPresent = false;

   s.breakoutConfirmed = false;
   s.retestConfirmed = false;
   s.failedBreakoutConfirmed = false;

   s.trendConfirmed = false;
   s.pullbackConfirmed = false;

   s.engulfingConfirmed = false;
   s.pinBarConfirmed = false;
   s.rejectionConfirmed = false;
   s.insideBarConfirmed = false;
   s.momentumConfirmed = false;

   s.sessionConfirmed = false;
   s.volatilityConfirmed = false;

   s.premiumDiscountConfirmed = false;

   s.liquidityLevel = 0.0;
   s.liquidityDistance = 0.0;
   s.liquiditySwept = false;

   s.signalTime = 0;
   s.signalShift = -1;

   s.evidence = "";
}

//====================================================================
// DIRECTION HELPERS
//====================================================================

bool IsStrategyBuy(const StrategySignal &s)
{
   return s.direction == STRATEGY_DIRECTION_BUY;
}

bool IsStrategySell(const StrategySignal &s)
{
   return s.direction == STRATEGY_DIRECTION_SELL;
}

bool IsStrategyDirectional(const StrategySignal &s)
{
   return s.direction != STRATEGY_DIRECTION_NONE;
}

//====================================================================
// QUALITY
//====================================================================

ENUM_SIGNAL_QUALITY GetSignalQuality(const double score)
{
   if(score < 40.0)
      return SIGNAL_QUALITY_WEAK;

   if(score < 60.0)
      return SIGNAL_QUALITY_MODERATE;

   if(score < 80.0)
      return SIGNAL_QUALITY_STRONG;

   return SIGNAL_QUALITY_HIGH_CONFLUENCE;
}

//====================================================================
// REWARD / RISK
//====================================================================

double CalculateSignalRR(
   const ENUM_STRATEGY_DIRECTION direction,
   const double entry,
   const double stopLoss,
   const double takeProfit
)
{
   if(entry <= 0.0 ||
      stopLoss <= 0.0 ||
      takeProfit <= 0.0)
      return 0.0;

   double risk = 0.0;
   double reward = 0.0;

   if(direction == STRATEGY_DIRECTION_BUY)
   {
      risk = entry - stopLoss;
      reward = takeProfit - entry;
   }
   else if(direction == STRATEGY_DIRECTION_SELL)
   {
      risk = stopLoss - entry;
      reward = entry - takeProfit;
   }
   else
   {
      return 0.0;
   }

   if(risk <= 0.0 || reward <= 0.0)
      return 0.0;

   return reward / risk;
}

//====================================================================
// FINALIZE PRICE INFORMATION
//====================================================================

void FinalizeStrategySignal(StrategySignal &s)
{
   s.riskDistance = 0.0;
   s.rewardDistance = 0.0;
   s.rewardRiskRatio = 0.0;

   if(s.entry <= 0.0 ||
      s.stopLoss <= 0.0 ||
      s.takeProfit <= 0.0)
      return;

   if(s.direction == STRATEGY_DIRECTION_BUY)
   {
      s.riskDistance = s.entry - s.stopLoss;
      s.rewardDistance = s.takeProfit - s.entry;
   }
   else if(s.direction == STRATEGY_DIRECTION_SELL)
   {
      s.riskDistance = s.stopLoss - s.entry;
      s.rewardDistance = s.entry - s.takeProfit;
   }

   if(s.riskDistance > 0.0 &&
      s.rewardDistance > 0.0)
   {
      s.rewardRiskRatio =
         s.rewardDistance / s.riskDistance;
   }

   s.zoneMid = 0.0;

   if(s.zoneHigh > 0.0 &&
      s.zoneLow > 0.0 &&
      s.zoneHigh >= s.zoneLow)
   {
      s.zoneMid =
         (s.zoneHigh + s.zoneLow) * 0.5;
   }

   s.quality =
      GetSignalQuality(s.strategyScore);
}

//====================================================================
// BASIC VALIDATION
//====================================================================

bool IsStrategySignalStructurallyValid(
   const StrategySignal &s
)
{
   if(!s.valid)
      return false;

   if(!IsStrategyDirectional(s))
      return false;

   if(s.entry <= 0.0 ||
      s.stopLoss <= 0.0 ||
      s.takeProfit <= 0.0)
      return false;

   if(s.direction == STRATEGY_DIRECTION_BUY)
   {
      if(s.stopLoss >= s.entry)
         return false;

      if(s.takeProfit <= s.entry)
         return false;
   }

   if(s.direction == STRATEGY_DIRECTION_SELL)
   {
      if(s.stopLoss <= s.entry)
         return false;

      if(s.takeProfit >= s.entry)
         return false;
   }

   if(s.rewardRiskRatio < ICT_MIN_REWARD_RR)
      return false;

   return true;
}

//====================================================================
// FAMILY NAME
//====================================================================

string StrategyFamilyToString(
   const ENUM_STRATEGY_FAMILY family
)
{
   switch(family)
   {
      case STRATEGY_LIQUIDITY_SWEEP:
         return "Liquidity Sweep";

      case STRATEGY_MSS:
         return "MSS";

      case STRATEGY_BOS:
         return "BOS";

      case STRATEGY_CHOCH:
         return "CHoCH";

      case STRATEGY_DISPLACEMENT:
         return "Displacement";

      case STRATEGY_FVG_RETEST:
         return "FVG Retest";

      case STRATEGY_ORDER_BLOCK:
         return "Order Block";

      case STRATEGY_BREAKER_BLOCK:
         return "Breaker Block";

      case STRATEGY_MITIGATION_BLOCK:
         return "Mitigation Block";

      case STRATEGY_PREMIUM_DISCOUNT:
         return "Premium/Discount";

      case STRATEGY_BREAKOUT:
         return "Breakout";

      case STRATEGY_BREAKOUT_RETEST:
         return "Breakout + Retest";

      case STRATEGY_FAILED_BREAKOUT:
         return "Failed Breakout";

      case STRATEGY_SUPPORT_RESISTANCE_RETEST:
         return "Support/Resistance Retest";

      case STRATEGY_RANGE_BREAKOUT:
         return "Range Breakout";

      case STRATEGY_LIQUIDITY_GRAB_REVERSAL:
         return "Liquidity Grab Reversal";

      case STRATEGY_TREND_CONTINUATION:
         return "Trend Continuation";

      case STRATEGY_PULLBACK_CONTINUATION:
         return "Pullback Continuation";

      case STRATEGY_MOMENTUM_CONTINUATION:
         return "Momentum Continuation";

      case STRATEGY_LIQUIDITY_REVERSAL:
         return "Liquidity Reversal";

      case STRATEGY_EXHAUSTION_REVERSAL:
         return "Exhaustion Reversal";

      case STRATEGY_REJECTION_REVERSAL:
         return "Rejection Reversal";

      case STRATEGY_DIVERGENCE_REVERSAL:
         return "Divergence Reversal";

      case STRATEGY_ENGULFING:
         return "Engulfing";

      case STRATEGY_PIN_BAR:
         return "Pin Bar";

      case STRATEGY_REJECTION_CANDLE:
         return "Rejection Candle";

      case STRATEGY_INSIDE_BAR:
         return "Inside Bar";

      case STRATEGY_MOMENTUM_CANDLE:
         return "Momentum Candle";

      case STRATEGY_SESSION_SETUP:
         return "Session Setup";

      case STRATEGY_VOLATILITY_EXPANSION:
         return "Volatility Expansion";

      case STRATEGY_VOLATILITY_CONTRACTION:
         return "Volatility Contraction";

      default:
         return "None";
   }
}

//====================================================================
// DIRECTION NAME
//====================================================================

string StrategyDirectionToString(
   const ENUM_STRATEGY_DIRECTION direction
)
{
   switch(direction)
   {
      case STRATEGY_DIRECTION_BUY:
         return "BUY";

      case STRATEGY_DIRECTION_SELL:
         return "SELL";

      default:
         return "NONE";
   }
}

//====================================================================
// QUALITY NAME
//====================================================================

string SignalQualityToString(
   const ENUM_SIGNAL_QUALITY quality
)
{
   switch(quality)
   {
      case SIGNAL_QUALITY_WEAK:
         return "WEAK";

      case SIGNAL_QUALITY_MODERATE:
         return "MODERATE";

      case SIGNAL_QUALITY_STRONG:
         return "STRONG";

      case SIGNAL_QUALITY_HIGH_CONFLUENCE:
         return "HIGH CONFLUENCE";

      default:
         return "NONE";
   }
}

//====================================================================
// BUILD STRATEGY NAME
//====================================================================

void SetStrategyIdentity(
   StrategySignal &s,
   const ENUM_STRATEGY_FAMILY family,
   const ENUM_STRATEGY_DIRECTION direction
)
{
   s.family = family;
   s.direction = direction;
   s.strategyName = StrategyFamilyToString(family);
}

//====================================================================
// APPEND EVIDENCE
//====================================================================

void AddStrategyEvidence(
   StrategySignal &s,
   const string text
)
{
   if(text == "")
      return;

   if(s.evidence == "")
      s.evidence = text;
   else
      s.evidence += " | " + text;
}

//====================================================================
// SCORE HELPERS
//====================================================================

void AddStrategyScore(
   StrategySignal &s,
   const double points,
   const string evidenceText = ""
)
{
   if(points > 0.0)
      s.strategyScore += points;

   if(evidenceText != "")
      AddStrategyEvidence(s, evidenceText);

   if(s.strategyScore > 100.0)
      s.strategyScore = 100.0;

   s.confidence = s.strategyScore;
   s.quality = GetSignalQuality(s.strategyScore);
}

//====================================================================
// FINAL SIGNAL PREPARATION
//====================================================================

void PrepareStrategySignal(StrategySignal &s)
{
   FinalizeStrategySignal(s);

   if(!s.valid)
      s.actionable = false;

   if(!IsStrategyDirectional(s))
      s.actionable = false;

   if(s.rewardRiskRatio < ICT_MIN_REWARD_RR)
      s.actionable = false;

   if(s.strategyScore < ICT_MIN_CONFLUENCE_SCORE)
      s.actionable = false;

   if(s.signalTime <= 0)
      s.actionable = false;
}

//====================================================================
// DESCRIPTION
//====================================================================

string StrategySignalDescription(
   const StrategySignal &s
)
{
   string text =
      StrategyDirectionToString(s.direction) +
      " " +
      StrategyFamilyToString(s.family);

   text +=
      " | Score=" +
      DoubleToString(s.strategyScore, 1);

   text +=
      " | RR=" +
      DoubleToString(s.rewardRiskRatio, 2);

   text +=
      " | Quality=" +
      SignalQualityToString(s.quality);

   if(s.evidence != "")
      text += " | " + s.evidence;

   return text;
}

#endif
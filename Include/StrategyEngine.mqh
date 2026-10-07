//+------------------------------------------------------------------+
//| StrategyEngine.mqh                                               |
//| Gold Multi-Strategy EA - Strategy Analysis Engine                |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_STRATEGY_ENGINE_MQH__
#define __EXNESS_GOLD_STRATEGY_ENGINE_MQH__

#include "Config.mqh"
#include "StrategySignal.mqh"
#include "MarketStructure.mqh"
#include "StructureSignal.mqh"
#include "Liquidity.mqh"
#include "FVG.mqh"
#include "OrderBlock.mqh"

//====================================================================
// STRATEGY ENGINE RESULT
//====================================================================

struct StrategyEngineResult
{
   bool valid;
   bool buyFound;
   bool sellFound;

   StrategySignal bestBuy;
   StrategySignal bestSell;

   StrategySignal bestSignal;

   double buyScore;
   double sellScore;

   int strategiesDetected;

   string summary;
};

//====================================================================
// RESET
//====================================================================

void SE_ResetResult(StrategyEngineResult &result)
{
   result.valid = false;
   result.buyFound = false;
   result.sellFound = false;

   ResetStrategySignal(result.bestBuy);
   ResetStrategySignal(result.bestSell);
   ResetStrategySignal(result.bestSignal);

   result.buyScore = 0.0;
   result.sellScore = 0.0;

   result.strategiesDetected = 0;
   result.summary = "";
}

//====================================================================
// GOLD SYMBOL CHECK
//====================================================================

bool SE_IsGold(const string symbol)
{
   string upper = symbol;

   StringToUpper(upper);

   return StringFind(
      upper,
      ICT_GOLD_SYMBOL_PREFIX
   ) == 0;
}

//====================================================================
// HISTORY CHECK
//====================================================================

bool SE_HasEnoughHistory(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int requiredBars
)
{
   if(requiredBars <= 0)
      return false;

   int bars =
      Bars(
         symbol,
         timeframe
      );

   return bars >= requiredBars;
}

//====================================================================
// NEW PRIMARY BAR
//====================================================================

bool SE_IsNewPrimaryBar(
   const string symbol,
   datetime &lastBarTime
)
{
   datetime currentBar =
      iTime(
         symbol,
         ICT_PRIMARY_TF,
         0
      );

   if(currentBar <= 0)
      return false;

   if(currentBar == lastBarTime)
      return false;

   lastBarTime = currentBar;

   return true;
}

//====================================================================
// CURRENT PRICE
//====================================================================

double SE_CurrentPrice(
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
// ATR
//====================================================================

double SE_GetATR(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int period,
   const int shift
)
{
   if(period <= 0)
      return 0.0;

   int handle =
      iATR(
         symbol,
         timeframe,
         period
      );

   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];

   ArraySetAsSeries(
      buffer,
      true
   );

   double value = 0.0;

   if(CopyBuffer(
      handle,
      0,
      shift,
      1,
      buffer
   ) == 1)
   {
      value = buffer[0];
   }

   IndicatorRelease(handle);

   return value;
}

//====================================================================
// CANDLE RANGE
//====================================================================

double SE_CandleRange(
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

double SE_CandleBody(
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
// CANDLE BODY RATIO
//====================================================================

double SE_CandleBodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double range =
      SE_CandleRange(
         symbol,
         timeframe,
         shift
      );

   double body =
      SE_CandleBody(
         symbol,
         timeframe,
         shift
      );

   if(range <= 0.0)
      return 0.0;

   return body / range;
}

//====================================================================
// BULLISH CANDLE
//====================================================================

bool SE_IsBullishCandle(
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

   return close > open;
}

//====================================================================
// BEARISH CANDLE
//====================================================================

bool SE_IsBearishCandle(
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

   return close < open;
}

//====================================================================
// PREMIUM / DISCOUNT
//====================================================================

bool SE_IsPremium(
   const double price,
   const double high,
   const double low
)
{
   if(high <= low)
      return false;

   double midpoint =
      (high + low) * 0.5;

   return price > midpoint;
}

bool SE_IsDiscount(
   const double price,
   const double high,
   const double low
)
{
   if(high <= low)
      return false;

   double midpoint =
      (high + low) * 0.5;

   return price < midpoint;
}
//====================================================================
// LIQUIDITY SCORE
//====================================================================

double SE_LiquidityScore(
   const string symbol,
   const ENUM_STRATEGY_DIRECTION direction
)
{
   LiquiditySweep sweep;

   ResetLiquiditySweep(sweep);

   bool bullishContext =
      direction == STRATEGY_DIRECTION_BUY;

   bool detected =
      DetectLiquiditySweep(
         symbol,
         ICT_PRIMARY_TF,
         bullishContext,
         ICT_STRUCTURE_LOOKBACK,
         sweep
      );

   if(!detected || !sweep.valid)
      return 0.0;

   return ICT_SCORE_LIQUIDITY;
}

//====================================================================
// STRUCTURE SIGNAL
//====================================================================

bool SE_GetStructureSignal(
   const string symbol,
   StructureSignal &signal
)
{
   ResetStructureSignal(signal);

   return AnalyzeStructureSignal(
      symbol,
      ICT_PRIMARY_TF,
      ICT_STRUCTURE_LOOKBACK,
      signal
   );
}

//====================================================================
// BUILD BASE STRATEGY SIGNAL
//====================================================================

void SE_BuildBaseSignal(
   StrategySignal &signal,
   const ENUM_STRATEGY_FAMILY family,
   const ENUM_STRATEGY_DIRECTION direction,
   const string symbol
)
{
   ResetStrategySignal(signal);

   signal.valid = true;

   SetStrategyIdentity(
      signal,
      family,
      direction
   );

   signal.primaryTF =
      ICT_PRIMARY_TF;

   signal.confirmationTF =
      ICT_CONFIRM_TF;

   signal.entryTF =
      ICT_ENTRY_TF;

   signal.entry =
      SE_CurrentPrice(
         symbol,
         direction
      );

   signal.signalTime =
      iTime(
         symbol,
         ICT_PRIMARY_TF,
         1
      );

   signal.signalShift = 1;
}

//====================================================================
// APPLY MARKET STRUCTURE
//====================================================================

void SE_ApplyStructure(
   StrategySignal &signal,
   const StructureSignal &structure
)
{
   if(!structure.valid)
      return;

   signal.structureConfirmed = true;

   //-----------------------------------------------------------------
   // DISPLACEMENT
   //-----------------------------------------------------------------

   if(
      structure.bullishDisplacement ||
      structure.bearishDisplacement
   )
   {
      signal.displacementConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_DISPLACEMENT,
         "Displacement"
      );
   }

   //-----------------------------------------------------------------
   // BULLISH MSS
   //-----------------------------------------------------------------

   if(
      structure.bullishMSS &&
      signal.direction == STRATEGY_DIRECTION_BUY
   )
   {
      signal.mssConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_STRUCTURE,
         "Bullish MSS"
      );
   }

   //-----------------------------------------------------------------
   // BEARISH MSS
   //-----------------------------------------------------------------

   if(
      structure.bearishMSS &&
      signal.direction == STRATEGY_DIRECTION_SELL
   )
   {
      signal.mssConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_STRUCTURE,
         "Bearish MSS"
      );
   }

   //-----------------------------------------------------------------
   // BULLISH BOS
   //-----------------------------------------------------------------

   if(
      structure.bullishBOS &&
      signal.direction == STRATEGY_DIRECTION_BUY
   )
   {
      signal.bosConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_STRUCTURE,
         "Bullish BOS"
      );
   }

   //-----------------------------------------------------------------
   // BEARISH BOS
   //-----------------------------------------------------------------

   if(
      structure.bearishBOS &&
      signal.direction == STRATEGY_DIRECTION_SELL
   )
   {
      signal.bosConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_STRUCTURE,
         "Bearish BOS"
      );
   }

   //-----------------------------------------------------------------
   // SIGNAL TIME
   //-----------------------------------------------------------------

   if(structure.signalTime > 0)
      signal.signalTime =
         structure.signalTime;

   if(structure.signalShift >= 0)
      signal.signalShift =
         structure.signalShift;
}

//====================================================================
// APPLY LIQUIDITY
//====================================================================

void SE_ApplyLiquidity(
   StrategySignal &signal,
   const string symbol
)
{
   double score =
      SE_LiquidityScore(
         symbol,
         signal.direction
      );

   if(score <= 0.0)
      return;

   signal.liquidityConfirmed = true;
   signal.liquiditySwept = true;

   AddStrategyScore(
      signal,
      score,
      "Liquidity sweep"
   );
}

//====================================================================
// APPLY PREMIUM / DISCOUNT
//====================================================================

void SE_ApplyPremiumDiscount(
   StrategySignal &signal,
   const string symbol
)
{
   MarketStructureState state;

   if(!MS_GetState(
      symbol,
      ICT_PRIMARY_TF,
      ICT_STRUCTURE_LOOKBACK,
      state
   ))
      return;

   if(!state.valid)
      return;

   double price =
      signal.entry;

   //-----------------------------------------------------------------
   // BUY = PREFER DISCOUNT
   //-----------------------------------------------------------------

   if(
      signal.direction == STRATEGY_DIRECTION_BUY &&
      SE_IsDiscount(
         price,
         state.recentHigh,
         state.recentLow
      )
   )
   {
      signal.premiumDiscountConfirmed = true;

      AddStrategyScore(
         signal,
         5.0,
         "Discount"
      );
   }

   //-----------------------------------------------------------------
   // SELL = PREFER PREMIUM
   //-----------------------------------------------------------------

   if(
      signal.direction == STRATEGY_DIRECTION_SELL &&
      SE_IsPremium(
         price,
         state.recentHigh,
         state.recentLow
      )
   )
   {
      signal.premiumDiscountConfirmed = true;

      AddStrategyScore(
         signal,
         5.0,
         "Premium"
      );
   }
}

//====================================================================
// STRATEGY SIGNAL PRICE ZONE
//====================================================================

void SE_SetSignalZone(
   StrategySignal &signal,
   const double high,
   const double low
)
{
   if(high <= 0.0 || low <= 0.0)
      return;

   if(high < low)
      return;

   signal.zoneHigh = high;
   signal.zoneLow = low;
   signal.zoneMid = (high + low) * 0.5;
}

//====================================================================
// STRUCTURAL LEVELS
//====================================================================

void SE_SetStructuralLevels(
   StrategySignal &signal,
   const MarketStructureState &state
)
{
   if(!state.valid)
      return;

   signal.structuralHigh =
      state.recentHigh;

   signal.structuralLow =
      state.recentLow;
}
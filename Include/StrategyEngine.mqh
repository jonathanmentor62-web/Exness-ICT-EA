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
//====================================================================
// APPLY FAIR VALUE GAP
//====================================================================

void SE_ApplyFVG(
   StrategySignal &signal,
   const string symbol
)
{
   FVGZone fvg;

   ResetFVG(fvg);

   bool bullish =
      signal.direction == STRATEGY_DIRECTION_BUY;

   bool found =
      FindDirectionalFVG(
         symbol,
         ICT_PRIMARY_TF,
         bullish,
         ICT_FVG_LOOKBACK,
         fvg
      );

   if(!found || !fvg.valid)
      return;

   signal.fvgPresent = true;

   SE_SetSignalZone(
      signal,
      fvg.upper,
      fvg.lower
   );

   AddStrategyScore(
      signal,
      ICT_SCORE_FVG,
      "FVG present"
   );

   //-----------------------------------------------------------------
   // FVG RETEST
   //-----------------------------------------------------------------

   if(!ICT_FVG_ALLOW_RETEST)
      return;

   MqlTick tick;

   if(!SymbolInfoTick(symbol, tick))
      return;

   double price =
      bullish
      ? tick.ask
      : tick.bid;

   if(IsPriceInsideFVG(
      fvg,
      price
   ))
   {
      signal.fvgRetestConfirmed = true;

      signal.retestConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_RETEST,
         "FVG retest"
      );
   }
}

//====================================================================
// APPLY ORDER BLOCK
//====================================================================

void SE_ApplyOrderBlock(
   StrategySignal &signal,
   const string symbol
)
{
   if(!ICT_ENABLE_ORDER_BLOCK)
      return;

   OrderBlock ob;

   ResetOrderBlock(ob);

   bool bullish =
      signal.direction == STRATEGY_DIRECTION_BUY;

   bool found =
      FindDirectionalOrderBlock(
         symbol,
         ICT_PRIMARY_TF,
         bullish,
         ICT_OB_LOOKBACK,
         ob
      );

   if(!found || !ob.valid)
      return;

   signal.orderBlockPresent = true;

   //-----------------------------------------------------------------
   // STORE ORDER-BLOCK ZONE
   //-----------------------------------------------------------------

   SE_SetSignalZone(
      signal,
      ob.upper,
      ob.lower
   );

   AddStrategyScore(
      signal,
      ICT_SCORE_ORDER_BLOCK,
      "Order block"
   );

   //-----------------------------------------------------------------
   // ORDER-BLOCK RETEST
   //-----------------------------------------------------------------

   if(!ICT_OB_ALLOW_RETEST)
      return;

   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick
   ))
      return;

   double price =
      bullish
      ? tick.ask
      : tick.bid;

   if(IsPriceInsideOrderBlock(
      ob,
      price
   ))
   {
      signal.orderBlockRetestConfirmed = true;

      signal.retestConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_RETEST,
         "Order-block retest"
      );
   }
}

//====================================================================
// PRICE-ACTION ENGULFING
//====================================================================

bool SE_IsBullishEngulfing(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double open1 =
      iOpen(
         symbol,
         timeframe,
         shift
      );

   double close1 =
      iClose(
         symbol,
         timeframe,
         shift
      );

   double open2 =
      iOpen(
         symbol,
         timeframe,
         shift + 1
      );

   double close2 =
      iClose(
         symbol,
         timeframe,
         shift + 1
      );

   if(
      open1 <= 0.0 ||
      close1 <= 0.0 ||
      open2 <= 0.0 ||
      close2 <= 0.0
   )
      return false;

   return
      close1 > open1 &&
      close2 < open2 &&
      open1 <= close2 &&
      close1 >= open2;
}

//====================================================================
// PRICE-ACTION BEARISH ENGULFING
//====================================================================

bool SE_IsBearishEngulfing(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double open1 =
      iOpen(
         symbol,
         timeframe,
         shift
      );

   double close1 =
      iClose(
         symbol,
         timeframe,
         shift
      );

   double open2 =
      iOpen(
         symbol,
         timeframe,
         shift + 1
      );

   double close2 =
      iClose(
         symbol,
         timeframe,
         shift + 1
      );

   if(
      open1 <= 0.0 ||
      close1 <= 0.0 ||
      open2 <= 0.0 ||
      close2 <= 0.0
   )
      return false;

   return
      close1 < open1 &&
      close2 > open2 &&
      open1 >= close2 &&
      close1 <= open2;
}

//====================================================================
// BULLISH REJECTION
//====================================================================

bool SE_IsBullishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double open =
      iOpen(symbol,timeframe,shift);

   double close =
      iClose(symbol,timeframe,shift);

   double high =
      iHigh(symbol,timeframe,shift);

   double low =
      iLow(symbol,timeframe,shift);

   if(
      open <= 0.0 ||
      close <= 0.0 ||
      high <= 0.0 ||
      low <= 0.0
   )
      return false;

   double body =
      MathAbs(close-open);

   double lowerWick =
      MathMin(open,close)-low;

   if(body <= 0.0)
      body = SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   return
      close > open &&
      lowerWick >= body * 1.5;
}

//====================================================================
// BEARISH REJECTION
//====================================================================

bool SE_IsBearishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double open =
      iOpen(symbol,timeframe,shift);

   double close =
      iClose(symbol,timeframe,shift);

   double high =
      iHigh(symbol,timeframe,shift);

   double low =
      iLow(symbol,timeframe,shift);

   if(
      open <= 0.0 ||
      close <= 0.0 ||
      high <= 0.0 ||
      low <= 0.0
   )
      return false;

   double body =
      MathAbs(close-open);

   double upperWick =
      high-MathMax(open,close);

   if(body <= 0.0)
      body = SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   return
      close < open &&
      upperWick >= body * 1.5;
}

//====================================================================
// APPLY M5 PRICE ACTION
//====================================================================

void SE_ApplyPriceAction(
   StrategySignal &signal,
   const string symbol
)
{
   ENUM_TIMEFRAMES timeframe =
      ICT_ENTRY_TF;

   int shift = 1;

   //-----------------------------------------------------------------
   // MOMENTUM
   //-----------------------------------------------------------------

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

   if(
      range > 0.0 &&
      body / range >= ICT_MIN_BODY_RATIO
   )
   {
      bool correctDirection =
         (
            signal.direction ==
            STRATEGY_DIRECTION_BUY &&
            SE_IsBullishCandle(
               symbol,
               timeframe,
               shift
            )
         )
         ||
         (
            signal.direction ==
            STRATEGY_DIRECTION_SELL &&
            SE_IsBearishCandle(
               symbol,
               timeframe,
               shift
            )
         );

      if(correctDirection)
      {
         signal.momentumConfirmed = true;

         AddStrategyScore(
            signal,
            ICT_SCORE_PRICE_ACTION,
            "M5 momentum"
         );
      }
   }

   //-----------------------------------------------------------------
   // ENGULFING
   //-----------------------------------------------------------------

   if(
      signal.direction ==
      STRATEGY_DIRECTION_BUY &&
      SE_IsBullishEngulfing(
         symbol,
         timeframe,
         shift
      )
   )
   {
      signal.engulfingConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_PRICE_ACTION,
         "M5 bullish engulfing"
      );
   }

   if(
      signal.direction ==
      STRATEGY_DIRECTION_SELL &&
      SE_IsBearishEngulfing(
         symbol,
         timeframe,
         shift
      )
   )
   {
      signal.engulfingConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_PRICE_ACTION,
         "M5 bearish engulfing"
      );
   }

   //-----------------------------------------------------------------
   // REJECTION
   //-----------------------------------------------------------------

   if(
      signal.direction ==
      STRATEGY_DIRECTION_BUY &&
      SE_IsBullishRejection(
         symbol,
         timeframe,
         shift
      )
   )
   {
      signal.rejectionConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_PRICE_ACTION,
         "M5 bullish rejection"
      );
   }

   if(
      signal.direction ==
      STRATEGY_DIRECTION_SELL &&
      SE_IsBearishRejection(
         symbol,
         timeframe,
         shift
      )
   )
   {
      signal.rejectionConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_PRICE_ACTION,
         "M5 bearish rejection"
      );
   }
}
//====================================================================
// APPLY VOLATILITY
//====================================================================

void SE_ApplyVolatility(
   StrategySignal &signal,
   const string symbol
)
{
   if(!ICT_ENABLE_ATR_FILTER)
      return;

   double atr =
      SE_GetATR(
         symbol,
         ICT_ENTRY_TF,
         ICT_ATR_PERIOD,
         1
      );

   double range =
      SE_CandleRange(
         symbol,
         ICT_ENTRY_TF,
         1
      );

   if(
      atr <= 0.0 ||
      range <= 0.0
   )
      return;

   double multiplier =
      range / atr;

   if(
      multiplier >= ICT_MIN_VOLATILITY_MULT &&
      multiplier <= ICT_MAX_VOLATILITY_MULT
   )
   {
      signal.volatilityConfirmed = true;

      AddStrategyScore(
         signal,
         ICT_SCORE_VOLATILITY,
         "Gold volatility acceptable"
      );
   }
}

//====================================================================
// APPLY SESSION
//====================================================================

void SE_ApplySession(
   StrategySignal &signal
)
{
   if(!ICT_ENABLE_SESSION_FILTER)
      return;

   MqlDateTime dt;

   TimeToStruct(
      TimeCurrent(),
      dt
   );

   bool london =
      dt.hour >= ICT_LONDON_START_HOUR &&
      dt.hour < ICT_LONDON_END_HOUR;

   bool newYork =
      dt.hour >= ICT_NEW_YORK_START_HOUR &&
      dt.hour < ICT_NEW_YORK_END_HOUR;

   if(!london && !newYork)
      return;

   signal.sessionConfirmed = true;

   if(london)
   {
      AddStrategyScore(
         signal,
         ICT_SCORE_SESSION,
         "London session"
      );
   }
   else
   {
      AddStrategyScore(
         signal,
         ICT_SCORE_SESSION,
         "New York session"
      );
   }
}

//====================================================================
// BUILD BUY SIGNAL
//====================================================================

bool SE_BuildBuySignal(
   const string symbol,
   StrategySignal &signal
)
{
   SE_BuildBaseSignal(
      signal,
      STRATEGY_LIQUIDITY_SWEEP,
      STRATEGY_DIRECTION_BUY,
      symbol
   );

   //-----------------------------------------------------------------
   // MARKET STRUCTURE
   //-----------------------------------------------------------------

   StructureSignal structure;

   if(!SE_GetStructureSignal(
      symbol,
      structure
   ))
   {
      signal.valid = false;
      return false;
   }

   SE_ApplyStructure(
      signal,
      structure
   );

   //-----------------------------------------------------------------
   // BUY REQUIRES DIRECTIONAL STRUCTURE
   //-----------------------------------------------------------------

   if(
      !signal.mssConfirmed &&
      !signal.bosConfirmed
   )
   {
      signal.valid = false;
      return false;
   }

   //-----------------------------------------------------------------
   // LIQUIDITY
   //-----------------------------------------------------------------

   SE_ApplyLiquidity(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // FVG
   //-----------------------------------------------------------------

   SE_ApplyFVG(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // ORDER BLOCK
   //-----------------------------------------------------------------

   SE_ApplyOrderBlock(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // PREMIUM / DISCOUNT
   //-----------------------------------------------------------------

   SE_ApplyPremiumDiscount(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // M5 PRICE ACTION
   //-----------------------------------------------------------------

   SE_ApplyPriceAction(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // VOLATILITY
   //-----------------------------------------------------------------

   SE_ApplyVolatility(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // SESSION
   //-----------------------------------------------------------------

   SE_ApplySession(
      signal
   );

   signal.reason =
      "Multi-strategy bullish Gold analysis";

   //-----------------------------------------------------------------
   // FINALIZE
   //-----------------------------------------------------------------

   PrepareStrategySignal(
      signal
   );

   return signal.valid;
}

//====================================================================
// BUILD SELL SIGNAL
//====================================================================

bool SE_BuildSellSignal(
   const string symbol,
   StrategySignal &signal
)
{
   SE_BuildBaseSignal(
      signal,
      STRATEGY_LIQUIDITY_SWEEP,
      STRATEGY_DIRECTION_SELL,
      symbol
   );

   //-----------------------------------------------------------------
   // MARKET STRUCTURE
   //-----------------------------------------------------------------

   StructureSignal structure;

   if(!SE_GetStructureSignal(
      symbol,
      structure
   ))
   {
      signal.valid = false;
      return false;
   }

   SE_ApplyStructure(
      signal,
      structure
   );

   //-----------------------------------------------------------------
   // SELL REQUIRES DIRECTIONAL STRUCTURE
   //-----------------------------------------------------------------

   if(
      !signal.mssConfirmed &&
      !signal.bosConfirmed
   )
   {
      signal.valid = false;
      return false;
   }

   //-----------------------------------------------------------------
   // LIQUIDITY
   //-----------------------------------------------------------------

   SE_ApplyLiquidity(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // FVG
   //-----------------------------------------------------------------

   SE_ApplyFVG(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // ORDER BLOCK
   //-----------------------------------------------------------------

   SE_ApplyOrderBlock(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // PREMIUM / DISCOUNT
   //-----------------------------------------------------------------

   SE_ApplyPremiumDiscount(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // M5 PRICE ACTION
   //-----------------------------------------------------------------

   SE_ApplyPriceAction(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // VOLATILITY
   //-----------------------------------------------------------------

   SE_ApplyVolatility(
      signal,
      symbol
   );

   //-----------------------------------------------------------------
   // SESSION
   //-----------------------------------------------------------------

   SE_ApplySession(
      signal
   );

   signal.reason =
      "Multi-strategy bearish Gold analysis";

   //-----------------------------------------------------------------
   // FINALIZE
   //-----------------------------------------------------------------

   PrepareStrategySignal(
      signal
   );

   return signal.valid;
}
//====================================================================
// SELECT BEST SIGNAL
//====================================================================

void SE_SelectBestSignal(
   StrategyEngineResult &result
)
{
   result.valid = false;

   //-----------------------------------------------------------------
   // NO SIGNAL
   //-----------------------------------------------------------------

   if(
      !result.buyFound &&
      !result.sellFound
   )
   {
      result.summary =
         "No valid Gold strategy signal.";

      return;
   }

   //-----------------------------------------------------------------
   // BUY ONLY
   //-----------------------------------------------------------------

   if(
      result.buyFound &&
      !result.sellFound
   )
   {
      result.bestSignal =
         result.bestBuy;

      result.valid = true;

      result.summary =
         "BUY signal selected.";

      return;
   }

   //-----------------------------------------------------------------
   // SELL ONLY
   //-----------------------------------------------------------------

   if(
      result.sellFound &&
      !result.buyFound
   )
   {
      result.bestSignal =
         result.bestSell;

      result.valid = true;

      result.summary =
         "SELL signal selected.";

      return;
   }

   //-----------------------------------------------------------------
   // BOTH DIRECTIONS EXIST
   //-----------------------------------------------------------------
   //
   // Never choose randomly.
   // If the two directions are too close, stand aside.
   //-----------------------------------------------------------------

   double difference =
      MathAbs(
         result.buyScore -
         result.sellScore
      );

   if(difference < 10.0)
   {
      result.valid = false;

      result.summary =
         "Conflicting Gold signals; no trade direction.";

      return;
   }

   //-----------------------------------------------------------------
   // BUY WINS
   //-----------------------------------------------------------------

   if(result.buyScore > result.sellScore)
   {
      result.bestSignal =
         result.bestBuy;

      result.valid = true;

      result.summary =
         "BUY has stronger confluence.";
   }
   //-----------------------------------------------------------------
   // SELL WINS
   //-----------------------------------------------------------------
   else
   {
      result.bestSignal =
         result.bestSell;

      result.valid = true;

      result.summary =
         "SELL has stronger confluence.";
   }
}

//====================================================================
// ANALYZE GOLD
//====================================================================

bool SE_AnalyzeGold(
   const string symbol,
   StrategyEngineResult &result
)
{
   //-----------------------------------------------------------------
   // RESET
   //-----------------------------------------------------------------

   SE_ResetResult(result);

   //-----------------------------------------------------------------
   // GOLD-ONLY PROTECTION
   //-----------------------------------------------------------------

   if(!SE_IsGold(symbol))
   {
      result.summary =
         "Rejected: symbol is not XAUUSD.";

      return false;
   }

   //-----------------------------------------------------------------
   // H4 HISTORY
   //-----------------------------------------------------------------

   if(!SE_HasEnoughHistory(
      symbol,
      ICT_PRIMARY_TF,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.summary =
         "Insufficient H4 history.";

      return false;
   }

   //-----------------------------------------------------------------
   // M15 HISTORY
   //-----------------------------------------------------------------

   if(!SE_HasEnoughHistory(
      symbol,
      ICT_CONFIRM_TF,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.summary =
         "Insufficient M15 history.";

      return false;
   }

   //-----------------------------------------------------------------
   // M5 HISTORY
   //-----------------------------------------------------------------

   if(!SE_HasEnoughHistory(
      symbol,
      ICT_ENTRY_TF,
      ICT_MIN_HISTORY_BARS
   ))
   {
      result.summary =
         "Insufficient M5 history.";

      return false;
   }

   //-----------------------------------------------------------------
   // BUILD BUY
   //-----------------------------------------------------------------

   StrategySignal buySignal;

   ResetStrategySignal(
      buySignal
   );

   bool buyFound =
      SE_BuildBuySignal(
         symbol,
         buySignal
      );

   //-----------------------------------------------------------------
   // BUILD SELL
   //-----------------------------------------------------------------

   StrategySignal sellSignal;

   ResetStrategySignal(
      sellSignal
   );

   bool sellFound =
      SE_BuildSellSignal(
         symbol,
         sellSignal
      );

   //-----------------------------------------------------------------
   // STORE BUY
   //-----------------------------------------------------------------

   if(buyFound)
   {
      result.buyFound = true;

      result.buyScore =
         buySignal.strategyScore;

      result.bestBuy =
         buySignal;

      result.strategiesDetected++;
   }

   //-----------------------------------------------------------------
   // STORE SELL
   //-----------------------------------------------------------------

   if(sellFound)
   {
      result.sellFound = true;

      result.sellScore =
         sellSignal.strategyScore;

      result.bestSell =
         sellSignal;

      result.strategiesDetected++;
   }

   //-----------------------------------------------------------------
   // SELECT BEST
   //-----------------------------------------------------------------

   SE_SelectBestSignal(
      result
   );

   //-----------------------------------------------------------------
   // FINAL SUMMARY
   //-----------------------------------------------------------------

   if(result.summary == "")
   {
      result.summary =
         "Gold strategy analysis complete.";
   }

   return result.valid;
}

//====================================================================
// PRINT STRATEGY RESULT
//====================================================================

void SE_PrintResult(
   const StrategyEngineResult &result
)
{
   Print(
      "[STRATEGY] ",
      result.summary,
      " | BUY=",
      DoubleToString(
         result.buyScore,
         1
      ),
      " | SELL=",
      DoubleToString(
         result.sellScore,
         1
      ),
      " | Signals=",
      IntegerToString(
         result.strategiesDetected
      )
   );

   //-----------------------------------------------------------------
   // BUY DETAILS
   //-----------------------------------------------------------------

   if(result.buyFound)
   {
      Print(
         "[STRATEGY BUY] ",
         StrategySignalDescription(
            result.bestBuy
         )
      );
   }

   //-----------------------------------------------------------------
   // SELL DETAILS
   //-----------------------------------------------------------------

   if(result.sellFound)
   {
      Print(
         "[STRATEGY SELL] ",
         StrategySignalDescription(
            result.bestSell
         )
      );
   }

   //-----------------------------------------------------------------
   // BEST SIGNAL
   //-----------------------------------------------------------------

   if(result.valid)
   {
      Print(
         "[STRATEGY BEST] ",
         StrategySignalDescription(
            result.bestSignal
         )
      );
   }
}

//====================================================================
// ENGINE STATUS
//====================================================================

string SE_Status()
{
   return
      "Gold Multi-Strategy Engine | "
      "H4 primary | "
      "M15 confirmation | "
      "M5 entry confirmation | "
      "M1 scalping removed";
}

#endif
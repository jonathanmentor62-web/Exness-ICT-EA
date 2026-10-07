//+------------------------------------------------------------------+
//| ExecutionEngine.mqh                                              |
//| Gold Multi-Strategy EA - Controlled Execution                    |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_EXECUTION_ENGINE_MQH__
#define __EXNESS_GOLD_EXECUTION_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include "Config.mqh"
#include "RiskEngine.mqh"

//====================================================================
// EXECUTION RESULT
//====================================================================

struct ExecutionResult
{
   bool attempted;
   bool executed;

   ulong ticket;

   double volume;
   double riskMoney;

   string reason;
};

//====================================================================
// RESET RESULT
//====================================================================

void ResetExecutionResult(ExecutionResult &r)
{
   r.attempted = false;
   r.executed = false;
   r.ticket = 0;
   r.volume = 0.0;
   r.riskMoney = 0.0;
   r.reason = "";
}

//====================================================================
// SPREAD CHECK
//====================================================================

bool EX_SpreadOK(
   const string symbol,
   const int maxSpreadPts
)
{
   if(!RE_IsGoldSymbol(symbol) || maxSpreadPts <= 0)
      return false;

   MqlTick tick;

   if(!SymbolInfoTick(symbol, tick))
      return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(point <= 0.0 || tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;

   double spread = (tick.ask - tick.bid) / point;

   return spread >= 0.0 && spread <= maxSpreadPts;
}

//====================================================================
// STOP DISTANCE CHECK
//====================================================================

bool EX_StopDistanceOK(
   const string symbol,
   const ENUM_ORDER_TYPE type,
   const double entry,
   const double sl
)
{
   if(!RE_IsGoldSymbol(symbol))
      return false;

   if(!RE_IsValidStop(symbol, type, entry, sl))
      return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long stopsLevel = 0;
   long freezeLevel = 0;

   if(point <= 0.0)
      return false;

   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel))
      return false;

   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL, freezeLevel))
      return false;

   double minimumPoints = MathMax(
      (double)ICT_MIN_STOP_DISTANCE_PTS,
      MathMax((double)stopsLevel, (double)freezeLevel)
   );

   return MathAbs(entry - sl) >= minimumPoints * point;
}

//====================================================================
// TAKE PROFIT CHECK
//====================================================================

bool EX_TakeProfitOK(
   const string symbol,
   const ENUM_ORDER_TYPE type,
   const double entry,
   const double tp
)
{
   if(!RE_IsGoldSymbol(symbol) || entry <= 0.0 || tp <= 0.0)
      return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long stopsLevel = 0;
   long freezeLevel = 0;

   if(point <= 0.0)
      return false;

   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel))
      return false;

   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL, freezeLevel))
      return false;

   double minimumDistance = MathMax(
      (double)ICT_MIN_STOP_DISTANCE_PTS,
      MathMax((double)stopsLevel, (double)freezeLevel)
   ) * point;

   if(type == ORDER_TYPE_BUY)
      return tp > entry && tp - entry >= minimumDistance;

   if(type == ORDER_TYPE_SELL)
      return tp < entry && entry - tp >= minimumDistance;

   return false;
}

//====================================================================
// COUNT EA POSITIONS
//====================================================================

int EX_CountOurPositions(
   const ulong magic,
   const string symbol = ""
)
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      string positionSymbol =
         PositionGetString(POSITION_SYMBOL);

      if(symbol != "" && positionSymbol != symbol)
         continue;

      count++;
   }

   return count;
}

//====================================================================
// OPPOSITE POSITION CHECK
//====================================================================

bool EX_HasOppositePosition(
   const ulong magic,
   const string symbol,
   const ENUM_ORDER_TYPE orderType
)
{
   if(orderType != ORDER_TYPE_BUY && orderType != ORDER_TYPE_SELL)
      return true;

   ENUM_POSITION_TYPE wanted =
      orderType == ORDER_TYPE_BUY
      ? POSITION_TYPE_SELL
      : POSITION_TYPE_BUY;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == wanted)
         return true;
   }

   return false;
}

//====================================================================
// DUPLICATE SYMBOL POSITION CHECK
//====================================================================

bool EX_HasSymbolPosition(
   const ulong magic,
   const string symbol
)
{
   return EX_CountOurPositions(magic, symbol) > 0;
}

//====================================================================
// TRADE RESULT CHECK
//====================================================================

bool EX_TradeRequestSucceeded(CTrade &trade)
{
   uint code = trade.ResultRetcode();

   return code == TRADE_RETCODE_DONE ||
          code == TRADE_RETCODE_DONE_PARTIAL ||
          code == TRADE_RETCODE_PLACED;
}

//====================================================================
// VALIDATE AN EXECUTION CANDIDATE
//====================================================================
//
// This function does not send an order. It validates a proposed
// gold trade and returns a reason when it is rejected.
//
//====================================================================

bool EX_ValidateCandidate(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double takeProfit,
   const double riskPercent,
   const double maxTotalRiskPercent,
   const ulong magic,
   const int maxPositions,
   const int maxSymbolPositions,
   const int maxSpreadPts,
   const bool tradingEnabled,
   ExecutionResult &result
)
{
   ResetExecutionResult(result);
   result.attempted = true;

   if(!tradingEnabled)
   {
      result.reason = "Trading disabled by EA input.";
      return false;
   }

   if(ICT_DEVELOPMENT_MODE)
   {
      result.reason = "Development mode blocks execution.";
      return false;
   }

   if(!RE_IsGoldSymbol(symbol))
   {
      result.reason = "Gold-only protection rejected symbol.";
      return false;
   }

   if(!SymbolSelect(symbol, true))
   {
      result.reason = "Symbol could not be selected.";
      return false;
   }

   long tradeMode = 0;

   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeMode) ||
      tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   {
      result.reason = "Symbol trading is disabled.";
      return false;
   }

   if(orderType != ORDER_TYPE_BUY && orderType != ORDER_TYPE_SELL)
   {
      result.reason = "Unsupported order type.";
      return false;
   }

   if(!EX_SpreadOK(symbol, maxSpreadPts))
   {
      result.reason = "Spread too high or quote unavailable.";
      return false;
   }

   if(maxPositions <= 0 || maxSymbolPositions <= 0)
   {
      result.reason = "Invalid position limit.";
      return false;
   }

   if(EX_CountOurPositions(magic) >= maxPositions)
   {
      result.reason = "Maximum EA positions reached.";
      return false;
   }

   if(EX_CountOurPositions(magic, symbol) >= maxSymbolPositions)
   {
      result.reason = "Maximum gold positions reached.";
      return false;
   }

   if(ICT_BLOCK_DUPLICATE_SYMBOL &&
      EX_HasSymbolPosition(magic, symbol))
   {
      result.reason = "Duplicate gold position blocked.";
      return false;
   }

   if(ICT_BLOCK_OPPOSITE_SYMBOL &&
      EX_HasOppositePosition(magic, symbol, orderType))
   {
      result.reason = "Opposite gold position exists.";
      return false;
   }

   if(!EX_StopDistanceOK(symbol, orderType, entry, stopLoss))
   {
      result.reason = "Invalid or too-close structural stop loss.";
      return false;
   }

   if(!EX_TakeProfitOK(symbol, orderType, entry, takeProfit))
   {
      result.reason = "Invalid or too-close take profit.";
      return false;
   }

   double volume = RE_CalculateCompoundingLots(
      symbol,
      orderType,
      entry,
      stopLoss,
      riskPercent
   );

   if(volume <= 0.0)
   {
      result.reason = "No broker-valid volume fits the risk limit.";
      return false;
   }

   if(!RE_ValidateNewTrade(
      symbol,
      orderType,
      entry,
      stopLoss,
      volume,
      riskPercent,
      maxTotalRiskPercent
   ))
   {
      result.reason = "Risk engine rejected the candidate.";
      return false;
   }

   result.volume = volume;
   result.riskMoney = RE_PositionRiskMoney(
      symbol,
      orderType,
      volume,
      entry,
      stopLoss
   );

   result.reason = "Candidate passed preliminary validation; no order sent.";
   return true;
}

//====================================================================
// SAFE EXECUTION PLACEHOLDER
//====================================================================
//
// Order submission will be added only after the strategy and
// confluence signal structures are finalized.
//
//====================================================================

bool EX_ExecutionReady()
{
   return !ICT_DEVELOPMENT_MODE &&
          ICT_TRADING_DEFAULT_ENABLED;
}

#endif
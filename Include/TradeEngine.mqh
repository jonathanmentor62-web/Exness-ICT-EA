#ifndef __EXNESS_ICT_TRADE_ENGINE_MQH__
#define __EXNESS_ICT_TRADE_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include "Config.mqh"
#include "RiskEngine.mqh"
#include "M1Scalper.mqh"
#include "ExecutionEngine.mqh"

// ============================================================
// TRADE ENGINE
// Adapter layer for the Exness ICT EA.
//
// ExecutionEngine.mqh contains the actual order execution logic.
// This file provides a clean TradeEngine interface around it.
//
// IMPORTANT:
// - No martingale
// - No forced lot doubling
// - RiskEngine remains the authority for lot sizing
// - Trading is blocked when tradingEnabled == false
// - ExecutionEngine performs the final broker/risk checks
// ============================================================


// ------------------------------------------------------------
// TradeEngine result
// ------------------------------------------------------------
struct TradeEngineResult
{
   bool     success;
   bool     attempted;
   string   message;
   ulong    ticket;
   double   volume;
   double   entry;
   double   stopLoss;
   double   takeProfit;
   int      retcode;

   void Reset()
   {
      success    = false;
      attempted  = false;
      message    = "";
      ticket     = 0;
      volume     = 0.0;
      entry      = 0.0;
      stopLoss   = 0.0;
      takeProfit = 0.0;
      retcode    = 0;
   }
};


// ------------------------------------------------------------
// Initialize result
// ------------------------------------------------------------
void TE_ResetResult(TradeEngineResult &result)
{
   result.Reset();
}


// ------------------------------------------------------------
// Count EA positions
// ------------------------------------------------------------
int TE_CountOurPositions(const ulong magic)
{
   return EX_CountOurPositions(magic);
}


// ------------------------------------------------------------
// Count EA positions on one symbol
// ------------------------------------------------------------
int TE_CountSymbolPositions(const string symbol,
                            const ulong magic)
{
   return EX_CountSymbolPositions(symbol, magic);
}


// ------------------------------------------------------------
// Check whether a symbol already has an opposite position
// ------------------------------------------------------------
bool TE_HasOppositePosition(const string symbol,
                            const ENUM_ORDER_TYPE orderType,
                            const ulong magic)
{
   return EX_HasOppositePosition(symbol, orderType, magic);
}


// ------------------------------------------------------------
// Open M1 scalp
//
// The actual execution is delegated to ExecutionEngine.
// ------------------------------------------------------------
bool TE_OpenScalp(CTrade &trade,
                  const string symbol,
                  const M1ScalpSignal &signal,
                  const double riskPercent,
                  const double maxTotalRiskPercent,
                  const ulong magic,
                  const int maxPositions,
                  const int maxSymbolPositions,
                  const int maxSpreadPts,
                  const bool tradingEnabled,
                  TradeEngineResult &result)
{
   result.Reset();

   if(!tradingEnabled)
   {
      result.message = "Trading disabled";
      return false;
   }

   if(symbol == "")
   {
      result.message = "Empty symbol";
      return false;
   }

   if(!signal.valid)
   {
      result.message = "Invalid scalp signal";
      return false;
   }

   ExecutionResult execution;
   execution.success = false;
   execution.attempted = false;
   execution.message = "";
   execution.ticket = 0;
   execution.volume = 0.0;
   execution.entry = 0.0;
   execution.stopLoss = 0.0;
   execution.takeProfit = 0.0;
   execution.retcode = 0;

   bool ok = EX_OpenScalp(
      trade,
      symbol,
      signal,
      riskPercent,
      maxTotalRiskPercent,
      magic,
      maxPositions,
      maxSymbolPositions,
      maxSpreadPts,
      tradingEnabled,
      execution
   );

   result.success    = execution.success;
   result.attempted  = execution.attempted;
   result.message    = execution.message;
   result.ticket     = execution.ticket;
   result.volume     = execution.volume;
   result.entry      = execution.entry;
   result.stopLoss   = execution.stopLoss;
   result.takeProfit = execution.takeProfit;
   result.retcode    = execution.retcode;

   return ok;
}


// ------------------------------------------------------------
// Manage existing scalp positions
//
// IMPORTANT:
// ExecutionEngine signature is:
//
// EX_ManageScalps(
//    CTrade &trade,
//    ulong magic,
//    int maxHoldSeconds
// );
//
// Do NOT pass a symbol here.
// ------------------------------------------------------------
void TE_ManageScalps(CTrade &trade,
                     const ulong magic,
                     const int maxHoldSeconds)
{
   EX_ManageScalps(
      trade,
      magic,
      maxHoldSeconds
   );
}


// ------------------------------------------------------------
// Close one EA position
// ------------------------------------------------------------
bool TE_ClosePosition(CTrade &trade,
                      const ulong ticket)
{
   if(ticket == 0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   return trade.PositionClose(ticket);
}


// ------------------------------------------------------------
// Close all positions belonging to this EA
// ------------------------------------------------------------
int TE_CloseAllPositions(CTrade &trade,
                         const ulong magic)
{
   int closed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      ulong positionMagic =
         (ulong)PositionGetInteger(POSITION_MAGIC);

      if(positionMagic != magic)
         continue;

      if(trade.PositionClose(ticket))
         closed++;
   }

   return closed;
}


// ------------------------------------------------------------
// Close all positions for one symbol
// ------------------------------------------------------------
int TE_CloseSymbolPositions(CTrade &trade,
                            const string symbol,
                            const ulong magic)
{
   int closed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string positionSymbol =
         PositionGetString(POSITION_SYMBOL);

      if(positionSymbol != symbol)
         continue;

      ulong positionMagic =
         (ulong)PositionGetInteger(POSITION_MAGIC);

      if(positionMagic != magic)
         continue;

      if(trade.PositionClose(ticket))
         closed++;
   }

   return closed;
}


// ------------------------------------------------------------
// Get current position volume for a symbol
// ------------------------------------------------------------
double TE_GetSymbolVolume(const string symbol,
                          const ulong magic)
{
   double volume = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      ulong positionMagic =
         (ulong)PositionGetInteger(POSITION_MAGIC);

      if(positionMagic != magic)
         continue;

      volume += PositionGetDouble(POSITION_VOLUME);
   }

   return volume;
}


// ------------------------------------------------------------
// Get floating profit for EA
// ------------------------------------------------------------
double TE_GetFloatingProfit(const ulong magic)
{
   double profit = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      ulong positionMagic =
         (ulong)PositionGetInteger(POSITION_MAGIC);

      if(positionMagic != magic)
         continue;

      profit += PositionGetDouble(POSITION_PROFIT);
      profit += PositionGetDouble(POSITION_SWAP);
   }

   return profit;
}


// ------------------------------------------------------------
// Check whether trading is allowed for the engine
// ------------------------------------------------------------
bool TE_IsTradingAllowed(const bool tradingEnabled)
{
   if(!tradingEnabled)
      return false;

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;

   return true;
}


// ------------------------------------------------------------
// Get account equity
// ------------------------------------------------------------
double TE_GetEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}


// ------------------------------------------------------------
// Get account balance
// ------------------------------------------------------------
double TE_GetBalance()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}


// ------------------------------------------------------------
// Print TradeEngine status
// ------------------------------------------------------------
void TE_PrintStatus(const ulong magic)
{
   double balance = TE_GetBalance();
   double equity  = TE_GetEquity();
   double profit  = TE_GetFloatingProfit(magic);
   int positions  = TE_CountOurPositions(magic);

   Print(
      "TradeEngine | ",
      "Balance=", DoubleToString(balance, 2),
      " | Equity=", DoubleToString(equity, 2),
      " | Floating=", DoubleToString(profit, 2),
      " | Positions=", IntegerToString(positions)
   );
}

#endif
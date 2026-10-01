#ifndef __EXNESS_ICT_TRADE_ENGINE_MQH__
#define __EXNESS_ICT_TRADE_ENGINE_MQH__

#include <Trade/Trade.mqh>

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "M1Scalper.mqh"
#include "ExecutionEngine.mqh"


// ============================================================
// TRADE ENGINE
// Thin adapter around ExecutionEngine.mqh.
//
// ExecutionEngine remains responsible for:
// - broker execution
// - spread checks
// - stop/TP validation
// - risk validation
// - equity-based lot sizing
// - duplicate/opposite-position protection
//
// This file only provides a clean interface for the EA.
// ============================================================


// ------------------------------------------------------------
// TradeEngine result
// ------------------------------------------------------------
struct TradeEngineResult
{
   bool     success;
   bool     attempted;

   ulong    ticket;
   double   volume;
   double   riskMoney;

   string   message;

   void Reset()
   {
      success   = false;
      attempted = false;
      ticket    = 0;
      volume    = 0.0;
      riskMoney = 0.0;
      message   = "";
   }
};


// ------------------------------------------------------------
// Reset result
// ------------------------------------------------------------
void TE_ResetResult(TradeEngineResult &result)
{
   result.Reset();
}


// ------------------------------------------------------------
// Count all EA positions
// ------------------------------------------------------------
int TE_CountOurPositions(const ulong magic)
{
   return EX_CountOurPositions(magic);
}


// ------------------------------------------------------------
// Count EA positions on a specific symbol
// ------------------------------------------------------------
int TE_CountSymbolPositions(const ulong magic,
                            const string symbol)
{
   return EX_CountOurPositions(
      magic,
      symbol
   );
}


// ------------------------------------------------------------
// Check for an opposite position
//
// IMPORTANT:
// ExecutionEngine signature is:
//
// EX_HasOppositePosition(
//    const ulong magic,
//    const string symbol,
//    const ENUM_ORDER_TYPE orderType
// );
// ------------------------------------------------------------
bool TE_HasOppositePosition(const ulong magic,
                            const string symbol,
                            const ENUM_ORDER_TYPE orderType)
{
   return EX_HasOppositePosition(
      magic,
      symbol,
      orderType
   );
}


// ------------------------------------------------------------
// Open M1 scalp
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


   // ---------------------------------------------------------
   // Actual ExecutionEngine result structure
   //
   // bool attempted;
   // bool executed;
   // ulong ticket;
   // double volume;
   // double riskMoney;
   // string reason;
   // ---------------------------------------------------------
   ExecutionResult execution;

   execution.attempted = false;
   execution.executed  = false;
   execution.ticket    = 0;
   execution.volume    = 0.0;
   execution.riskMoney = 0.0;
   execution.reason   = "";


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


   // ---------------------------------------------------------
   // Translate ExecutionResult into TradeEngineResult
   // ---------------------------------------------------------
   result.success   = execution.executed;
   result.attempted = execution.attempted;
   result.ticket    = execution.ticket;
   result.volume    = execution.volume;
   result.riskMoney = execution.riskMoney;
   result.message   = execution.reason;

   return ok;
}


// ------------------------------------------------------------
// Manage existing scalp positions
//
// EXACT ExecutionEngine signature:
//
// EX_ManageScalps(
//    CTrade &trade,
//    const ulong magic,
//    const int maxHoldSeconds
// );
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
// Check whether trading is permitted
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
// Close one position by ticket
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
// Close all EA positions for one symbol
// ------------------------------------------------------------
int TE_CloseSymbolPositions(CTrade &trade,
                            const ulong magic,
                            const string symbol)
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
// Get total volume for one symbol
// ------------------------------------------------------------
double TE_GetSymbolVolume(const ulong magic,
                          const string symbol)
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
// Get floating profit for this EA
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
// Account equity
// ------------------------------------------------------------
double TE_GetEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}


// ------------------------------------------------------------
// Account balance
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
   double floating = TE_GetFloatingProfit(magic);
   int positions = TE_CountOurPositions(magic);

   Print(
      "TradeEngine | ",
      "Balance=", DoubleToString(balance, 2),
      " | Equity=", DoubleToString(equity, 2),
      " | Floating=", DoubleToString(floating, 2),
      " | Positions=", IntegerToString(positions)
   );
}


#endif
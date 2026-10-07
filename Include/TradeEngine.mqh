//+------------------------------------------------------------------+
//| TradeEngine.mqh - Gold EA compatibility layer                    |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_TRADE_ENGINE_MQH__
#define __EXNESS_GOLD_TRADE_ENGINE_MQH__

#include <Trade/Trade.mqh>

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "ExecutionEngine.mqh"

//==================================================================
// TRADE ENGINE RESULT
//==================================================================

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


//==================================================================
// RESET
//==================================================================

void TE_ResetResult(
   TradeEngineResult &result
)
{
   result.Reset();
}


//==================================================================
// POSITION COUNT
//==================================================================

int TE_CountOurPositions(
   const ulong magic
)
{
   return EX_CountOurPositions(magic);
}


int TE_CountSymbolPositions(
   const ulong magic,
   const string symbol
)
{
   return EX_CountOurPositions(
      magic,
      symbol
   );
}


//==================================================================
// OPPOSITE POSITION CHECK
//==================================================================

bool TE_HasOppositePosition(
   const ulong magic,
   const string symbol,
   const ENUM_ORDER_TYPE orderType
)
{
   return EX_HasOppositePosition(
      magic,
      symbol,
      orderType
   );
}


//==================================================================
// SCALPER ENTRY - DISABLED
//==================================================================
//
// The old M1 scalp execution path has been removed.
// This function remains only as a compatibility barrier.
//
// It can NEVER open a trade.
//==================================================================

bool TE_OpenScalp(
   CTrade &trade,
   const string symbol,
   const M1ScalpSignal &signal,
   const double riskPercent,
   const double maxTotalRiskPercent,
   const ulong magic,
   const int maxPositions,
   const int maxSymbolPositions,
   const int maxSpreadPts,
   const bool tradingEnabled,
   TradeEngineResult &result
)
{
   result.Reset();

   result.message =
      "M1 scalping has been removed.";

   return false;
}


//==================================================================
// SCALPER POSITION MANAGEMENT - DISABLED
//==================================================================

void TE_ManageScalps(
   CTrade &trade,
   const ulong magic,
   const int maxHoldSeconds
)
{
   // Intentionally empty.
   // The new EA does not use M1 scalper management.
   return;
}


//==================================================================
// TRADING PERMISSION
//==================================================================

bool TE_IsTradingAllowed(
   const bool tradingEnabled
)
{
   if(!tradingEnabled)
      return false;

   if(ICT_DEVELOPMENT_MODE)
      return false;

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;

   return true;
}


//==================================================================
// CLOSE ONE POSITION
//==================================================================

bool TE_ClosePosition(
   CTrade &trade,
   const ulong ticket
)
{
   if(ticket==0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   return trade.PositionClose(ticket);
}


//==================================================================
// CLOSE ALL EA POSITIONS
//==================================================================

int TE_CloseAllPositions(
   CTrade &trade,
   const ulong magic
)
{
   int closed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      ulong positionMagic=
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         );

      if(positionMagic!=magic)
         continue;

      if(trade.PositionClose(ticket))
         closed++;
   }

   return closed;
}


//==================================================================
// CLOSE EA POSITIONS FOR ONE SYMBOL
//==================================================================

int TE_CloseSymbolPositions(
   CTrade &trade,
   const ulong magic,
   const string symbol
)
{
   int closed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string positionSymbol=
         PositionGetString(
            POSITION_SYMBOL
         );

      if(positionSymbol!=symbol)
         continue;

      ulong positionMagic=
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         );

      if(positionMagic!=magic)
         continue;

      if(trade.PositionClose(ticket))
         closed++;
   }

   return closed;
}


//==================================================================
// SYMBOL VOLUME
//==================================================================

double TE_GetSymbolVolume(
   const ulong magic,
   const string symbol
)
{
   double volume=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(
         PositionGetString(
            POSITION_SYMBOL
         )!=symbol
      )
      {
         continue;
      }

      ulong positionMagic=
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         );

      if(positionMagic!=magic)
         continue;

      volume+=
         PositionGetDouble(
            POSITION_VOLUME
         );
   }

   return volume;
}


//==================================================================
// FLOATING PROFIT
//==================================================================

double TE_GetFloatingProfit(
   const ulong magic
)
{
   double profit=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      ulong positionMagic=
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         );

      if(positionMagic!=magic)
         continue;

      profit+=
         PositionGetDouble(
            POSITION_PROFIT
         );

      profit+=
         PositionGetDouble(
            POSITION_SWAP
         );
   }

   return profit;
}


//==================================================================
// ACCOUNT EQUITY
//==================================================================

double TE_GetEquity()
{
   return AccountInfoDouble(
      ACCOUNT_EQUITY
   );
}


//==================================================================
// ACCOUNT BALANCE
//==================================================================

double TE_GetBalance()
{
   return AccountInfoDouble(
      ACCOUNT_BALANCE
   );
}


//==================================================================
// STATUS
//==================================================================

void TE_PrintStatus(
   const ulong magic
)
{
   double balance=
      TE_GetBalance();

   double equity=
      TE_GetEquity();

   double floating=
      TE_GetFloatingProfit(
         magic
      );

   int positions=
      TE_CountOurPositions(
         magic
      );

   Print(
      "TradeEngine | ",
      "Balance=",
      DoubleToString(
         balance,
         2
      ),
      " | Equity=",
      DoubleToString(
         equity,
         2
      ),
      " | Floating=",
      DoubleToString(
         floating,
         2
      ),
      " | Positions=",
      IntegerToString(
         positions
      )
   );
}

#endif
//+------------------------------------------------------------------+
//| TradeEngine.mqh                                                  |
//| Central trade-management coordinator                             |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_TRADE_ENGINE_MQH__
#define __EXNESS_ICT_TRADE_ENGINE_MQH__

#include <Trade/Trade.mqh>

#include "Config.mqh"
#include "RiskEngine.mqh"
#include "ExecutionEngine.mqh"
#include "M1Scalper.mqh"


//==================================================================
// TRADING MODES
//==================================================================

enum TRADE_ENGINE_MODE
{
   TRADE_MODE_NORMAL = 0,
   TRADE_MODE_SCALPING = 1,
   TRADE_MODE_AUTO = 2
};


//==================================================================
// TRADE ENGINE STATE
//==================================================================

struct TradeEngineState
{
   bool initialized;

   bool tradingEnabled;

   TRADE_ENGINE_MODE mode;

   datetime lastScalpBar;

   datetime lastScalpTradeTime;

   int lastScalpDirection;

   int signalsDetected;

   int tradesAttempted;

   int tradesOpened;

   int tradesRejected;
};


//==================================================================
// RESET STATE
//==================================================================

void TE_ResetState(
   TradeEngineState &state
)
{
   state.initialized=false;

   state.tradingEnabled=false;

   state.mode=
      TRADE_MODE_NORMAL;

   state.lastScalpBar=0;

   state.lastScalpTradeTime=0;

   state.lastScalpDirection=0;

   state.signalsDetected=0;

   state.tradesAttempted=0;

   state.tradesOpened=0;

   state.tradesRejected=0;
}


//==================================================================
// INITIALIZE
//==================================================================

bool TE_Initialize(
   TradeEngineState &state,
   const TRADE_ENGINE_MODE mode,
   const bool tradingEnabled
)
{
   TE_ResetState(
      state
   );


   state.mode=
      mode;

   state.tradingEnabled=
      tradingEnabled;

   state.initialized=true;


   return(true);
}


//==================================================================
// TRADING ENABLE CHECK
//==================================================================

bool TE_CanTrade(
   const TradeEngineState &state
)
{
   if(!state.initialized)
      return(false);


   if(!state.tradingEnabled)
      return(false);


   return(true);
}


//==================================================================
// MODE CHECKS
//==================================================================

bool TE_NormalEnabled(
   const TradeEngineState &state
)
{
   if(
      state.mode==
      TRADE_MODE_NORMAL
   )
   {
      return(true);
   }


   if(
      state.mode==
      TRADE_MODE_AUTO
   )
   {
      return(true);
   }


   return(false);
}


//------------------------------------------------------------------

bool TE_ScalpingEnabled(
   const TradeEngineState &state
)
{
   if(
      state.mode==
      TRADE_MODE_SCALPING
   )
   {
      return(true);
   }


   if(
      state.mode==
      TRADE_MODE_AUTO
   )
   {
      return(true);
   }


   return(false);
}


//==================================================================
// POSITION COUNT
//==================================================================

int TE_CountPositions(
   const ulong magic
)
{
   int count=0;


   int total=
      PositionsTotal();


   for(
      int i=0;
      i<total;
      i++
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(ticket==0)
         continue;


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }


      long positionMagic=
         PositionGetInteger(
            POSITION_MAGIC
         );


      if(
         (ulong)positionMagic==
         magic
      )
      {
         count++;
      }
   }


   return(count);
}


//==================================================================
// SYMBOL POSITION COUNT
//==================================================================

int TE_CountSymbolPositions(
   const string symbol,
   const ulong magic
)
{
   if(symbol=="")
      return(0);


   int count=0;


   int total=
      PositionsTotal();


   for(
      int i=0;
      i<total;
      i++
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(ticket==0)
         continue;


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }


      string positionSymbol=
         PositionGetString(
            POSITION_SYMBOL
         );


      if(
         positionSymbol!=
         symbol
      )
      {
         continue;
      }


      long positionMagic=
         PositionGetInteger(
            POSITION_MAGIC
         );


      if(
         (ulong)positionMagic==
         magic
      )
      {
         count++;
      }
   }


   return(count);
}


//==================================================================
// DUPLICATE POSITION CHECK
//==================================================================

bool TE_HasSameDirectionPosition(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const ulong magic
)
{
   int total=
      PositionsTotal();


   for(
      int i=0;
      i<total;
      i++
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(ticket==0)
         continue;


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }


      if(
         PositionGetString(
            POSITION_SYMBOL
         )!=
         symbol
      )
      {
         continue;
      }


      long positionMagic=
         PositionGetInteger(
            POSITION_MAGIC
         );


      if(
         (ulong)positionMagic!=
         magic
      )
      {
         continue;
      }


      long positionType=
         PositionGetInteger(
            POSITION_TYPE
         );


      if(
         orderType==
         ORDER_TYPE_BUY &&
         positionType==
         POSITION_TYPE_BUY
      )
      {
         return(true);
      }


      if(
         orderType==
         ORDER_TYPE_SELL &&
         positionType==
         POSITION_TYPE_SELL
      )
      {
         return(true);
      }
   }


   return(false);
}


//==================================================================
// OPPOSITE POSITION CHECK
//==================================================================

bool TE_HasOppositePosition(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const ulong magic
)
{
   int total=
      PositionsTotal();


   for(
      int i=0;
      i<total;
      i++
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(ticket==0)
         continue;


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }


      if(
         PositionGetString(
            POSITION_SYMBOL
         )!=
         symbol
      )
      {
         continue;
      }


      long positionMagic=
         PositionGetInteger(
            POSITION_MAGIC
         );


      if(
         (ulong)positionMagic!=
         magic
      )
      {
         continue;
      }


      long positionType=
         PositionGetInteger(
            POSITION_TYPE
         );


      if(
         orderType==
         ORDER_TYPE_BUY &&
         positionType==
         POSITION_TYPE_SELL
      )
      {
         return(true);
      }


      if(
         orderType==
         ORDER_TYPE_SELL &&
         positionType==
         POSITION_TYPE_BUY
      )
      {
         return(true);
      }
   }


   return(false);
}


//==================================================================
// COOLDOWN CHECK
//==================================================================

bool TE_ScalpCooldownOK(
   const TradeEngineState &state
)
{
   if(
      state.lastScalpTradeTime<=0
   )
   {
      return(true);
   }


   datetime now=
      TimeCurrent();


   long elapsed=
      (long)(
         now-
         state.lastScalpTradeTime
      );


   if(
      elapsed<
      ICT_SCALP_COOLDOWN_SECONDS
   )
   {
      return(false);
   }


   return(true);
}


//==================================================================
// SCALP POSITION LIMIT
//==================================================================

bool TE_ScalpPositionLimitsOK(
   const string symbol
)
{
   int totalPositions=
      TE_CountPositions(
         ICT_MAGIC_NUMBER
      );


   if(
      totalPositions>=
      ICT_SCALP_MAX_POSITIONS
   )
   {
      return(false);
   }


   int symbolPositions=
      TE_CountSymbolPositions(
         symbol,
         ICT_MAGIC_NUMBER
      );


   if(
      symbolPositions>=
      ICT_SCALP_MAX_SYMBOL_POSITIONS
   )
   {
      return(false);
   }


   return(true);
}


//==================================================================
// BUILD AND EXECUTE M1 SCALP
//==================================================================

bool TE_ProcessScalp(
   CTrade &trade,
   TradeEngineState &state,
   const string symbol
)
{
   if(symbol=="")
      return(false);


   if(!TE_CanTrade(state))
      return(false);


   if(!TE_ScalpingEnabled(state))
      return(false);


   //---------------------------------------------------------------
   // Cooldown
   //---------------------------------------------------------------

   if(
      !TE_ScalpCooldownOK(
         state
      )
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Position limits
   //---------------------------------------------------------------

   if(
      !TE_ScalpPositionLimitsOK(
         symbol
      )
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Build signal
   //---------------------------------------------------------------

   M1ScalpSignal signal;


   ResetM1ScalpSignal(
      signal
   );


   if(
      !M1_BuildSignal(
         symbol,
         signal
      )
   )
   {
      return(false);
   }


   if(!signal.valid)
      return(false);


   state.signalsDetected++;


   //---------------------------------------------------------------
   // Prevent duplicate direction
   //---------------------------------------------------------------

   if(
      TE_HasSameDirectionPosition(
         symbol,
         signal.orderType,
         ICT_MAGIC_NUMBER
      )
   )
   {
      if(
         !ICT_SCALP_ALLOW_STACKING
      )
      {
         return(false);
      }
   }


   //---------------------------------------------------------------
   // Prevent opposite position
   //---------------------------------------------------------------

   if(
      ICT_BLOCK_OPPOSITE_SYMBOL &&
      TE_HasOppositePosition(
         symbol,
         signal.orderType,
         ICT_MAGIC_NUMBER
      )
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Execution
   //---------------------------------------------------------------

   state.tradesAttempted++;


   ExecutionResult result;


   ResetExecutionResult(
      result
   );


   bool opened=
      EX_OpenScalp(
         trade,
         symbol,
         signal,
         ICT_RISK_PERCENT,
         ICT_MAX_TOTAL_RISK_PERCENT,
         ICT_MAGIC_NUMBER,
         ICT_SCALP_MAX_POSITIONS,
         ICT_SCALP_MAX_SYMBOL_POSITIONS,
         ICT_SCALP_MAX_SPREAD_POINTS,
         state.tradingEnabled,
         result
      );


   if(opened)
   {
      state.tradesOpened++;

      state.lastScalpTradeTime=
         TimeCurrent();

      state.lastScalpBar=
         signal.barTime;


      if(
         signal.orderType==
         ORDER_TYPE_BUY
      )
      {
         state.lastScalpDirection=1;
      }
      else
      {
         state.lastScalpDirection=-1;
      }


      Print(
         "TradeEngine | SCALP OPENED | ",
         symbol,
         " | Score=",
         DoubleToString(
            signal.score,
            1
         ),
         " | Reason=",
         signal.reason
      );


      return(true);
   }


   state.tradesRejected++;


   Print(
      "TradeEngine | SCALP REJECTED | ",
      symbol,
      " | Reason=",
      result.message
   );


   return(false);
}


//==================================================================
// MANAGE EXISTING SCALPS
//==================================================================

void TE_ManageScalps(
   CTrade &trade,
   TradeEngineState &state
)
{
   if(!state.initialized)
      return;


   if(!state.tradingEnabled)
      return;


   if(!TE_ScalpingEnabled(state))
      return;


   //---------------------------------------------------------------
   // Central M1 exit management
   //---------------------------------------------------------------

   EX_ManageScalps(
      trade,
      ICT_MAGIC_NUMBER,
      ICT_SCALP_MAX_HOLD_SECONDS,
      ICT_SCALP_EXIT_PRESSURE,
      ICT_SCALP_MAX_SPREAD_POINTS
   );
}


//==================================================================
// SCALP SYMBOL SCANNER
//==================================================================

void TE_ScanSymbol(
   CTrade &trade,
   TradeEngineState &state,
   const string symbol
)
{
   if(symbol=="")
      return;


   if(!state.initialized)
      return;


   //---------------------------------------------------------------
   // Normal mode is handled by the ICT structural engine.
   //
   // This function specifically handles the M1 reactive
   // scalping engine.
   //---------------------------------------------------------------

   if(
      TE_ScalpingEnabled(state)
   )
   {
      TE_ProcessScalp(
         trade,
         state,
         symbol
      );
   }
}


//==================================================================
// RISK SUMMARY
//==================================================================

void TE_PrintRiskState()
{
   RE_PrintSummary();
}


//==================================================================
// ENGINE STATUS
//==================================================================

void TE_PrintStatus(
   const TradeEngineState &state
)
{
   string modeText=
      "NORMAL";


   if(
      state.mode==
      TRADE_MODE_SCALPING
   )
   {
      modeText=
         "SCALPING";
   }


   if(
      state.mode==
      TRADE_MODE_AUTO
   )
   {
      modeText=
         "AUTO";
   }


   Print(
      "TradeEngine | Mode=",
      modeText,
      " | Trading=",
      (
         state.tradingEnabled
         ?
         "ON"
         :
         "OFF"
      ),
      " | Signals=",
      state.signalsDetected,
      " | Attempts=",
      state.tradesAttempted,
      " | Opened=",
      state.tradesOpened,
      " | Rejected=",
      state.tradesRejected
   );
}


//==================================================================
// ENGINE TICK
//
// Central entry point for the scalping side.
//
// Normal ICT processing remains separate because it requires
// the H4 -> M15 -> M5 structural pipeline.
//==================================================================

void TE_OnTick(
   CTrade &trade,
   TradeEngineState &state,
   const string symbol
)
{
   if(!state.initialized)
      return;


   //---------------------------------------------------------------
   // Always manage existing scalp positions first.
   //---------------------------------------------------------------

   TE_ManageScalps(
      trade,
      state
   );


   //---------------------------------------------------------------
   // If trading is disabled, analysis stops here.
   //---------------------------------------------------------------

   if(!state.tradingEnabled)
      return;


   //---------------------------------------------------------------
   // Scalping scanner
   //---------------------------------------------------------------

   if(
      TE_ScalpingEnabled(state)
   )
   {
      TE_ScanSymbol(
         trade,
         state,
         symbol
      );
   }
}


#endif
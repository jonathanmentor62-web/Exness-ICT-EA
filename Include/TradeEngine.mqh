//+------------------------------------------------------------------+
//| TradeEngine.mqh                                                  |
//| Central trading-mode coordinator                                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_TRADE_ENGINE_MQH__
#define __EXNESS_ICT_TRADE_ENGINE_MQH__

#include <Trade/Trade.mqh>

#include "Config.mqh"
#include "M1Scalper.mqh"
#include "ExecutionEngine.mqh"

//+------------------------------------------------------------------+
//| Trading modes                                                    |
//+------------------------------------------------------------------+

enum TRADE_ENGINE_MODE
{
   TE_MODE_NORMAL=0,
   TE_MODE_SCALPING=1,
   TE_MODE_AUTO=2
};

//+------------------------------------------------------------------+
//| State                                                             |
//+------------------------------------------------------------------+

struct TradeEngineState
{
   bool initialized;

   ulong magic;

   TRADE_ENGINE_MODE mode;

   bool normalEnabled;
   bool scalpingEnabled;

   datetime lastScalpEntryTime;

   int totalScalpEntries;
};

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+

void TE_Init(
   TradeEngineState &state,
   const ulong magic,
   const bool normalEnabled,
   const bool scalpingEnabled,
   const bool autoMode)
{
   state.initialized=true;

   state.magic=magic;

   if(autoMode)
   {
      state.mode=TE_MODE_AUTO;

      state.normalEnabled=true;
      state.scalpingEnabled=true;
   }
   else
   {
      if(scalpingEnabled)
      {
         state.mode=TE_MODE_SCALPING;

         state.normalEnabled=false;
         state.scalpingEnabled=true;
      }
      else
      {
         state.mode=TE_MODE_NORMAL;

         state.normalEnabled=normalEnabled;
         state.scalpingEnabled=false;
      }
   }

   state.lastScalpEntryTime=0;
   state.totalScalpEntries=0;
}

//+------------------------------------------------------------------+
//| Can trade                                                        |
//+------------------------------------------------------------------+

bool TE_CanTrade(
   const TradeEngineState &state,
   const bool tradingEnabled)
{
   if(!state.initialized)
      return(false);

   if(!tradingEnabled)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Count EA positions                                               |
//+------------------------------------------------------------------+

int TE_CountPositions(
   const ulong magic)
{
   int count=0;

   int total=
      PositionsTotal();

   for(int i=0;i<total;i++)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      long positionMagic=
         PositionGetInteger(
            POSITION_MAGIC
         );

      if((ulong)positionMagic!=magic)
         continue;

      count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
//| Count positions on symbol                                        |
//+------------------------------------------------------------------+

int TE_CountSymbolPositions(
   const string symbol,
   const ulong magic)
{
   int count=0;

   int total=
      PositionsTotal();

   for(int i=0;i<total;i++)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(
         POSITION_SYMBOL
      )!=symbol)
         continue;

      long positionMagic=
         PositionGetInteger(
            POSITION_MAGIC
         );

      if((ulong)positionMagic!=magic)
         continue;

      count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
//| Check same-direction position                                   |
//+------------------------------------------------------------------+

bool TE_HasSameDirection(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const ulong magic)
{
   ENUM_POSITION_TYPE wanted;

   if(orderType==ORDER_TYPE_BUY)
      wanted=POSITION_TYPE_BUY;
   else if(orderType==ORDER_TYPE_SELL)
      wanted=POSITION_TYPE_SELL;
   else
      return(false);

   int total=
      PositionsTotal();

   for(int i=0;i<total;i++)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(
         POSITION_SYMBOL
      )!=symbol)
         continue;

      if((ulong)PositionGetInteger(
         POSITION_MAGIC
      )!=magic)
         continue;

      if((ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         )==wanted)
      {
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Check opposite position                                          |
//+------------------------------------------------------------------+

bool TE_HasOppositeDirection(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const ulong magic)
{
   ENUM_POSITION_TYPE opposite;

   if(orderType==ORDER_TYPE_BUY)
      opposite=POSITION_TYPE_SELL;
   else if(orderType==ORDER_TYPE_SELL)
      opposite=POSITION_TYPE_BUY;
   else
      return(false);

   int total=
      PositionsTotal();

   for(int i=0;i<total;i++)
   {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(
         POSITION_SYMBOL
      )!=symbol)
         continue;

      if((ulong)PositionGetInteger(
         POSITION_MAGIC
      )!=magic)
         continue;

      if((ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         )==opposite)
      {
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Check scalp cooldown                                             |
//+------------------------------------------------------------------+

bool TE_CooldownComplete(
   const TradeEngineState &state,
   const int cooldownSeconds)
{
   if(state.lastScalpEntryTime<=0)
      return(true);

   long elapsed=
      (long)(TimeCurrent()-
             state.lastScalpEntryTime);

   return(
      elapsed>=cooldownSeconds
   );
}

//+------------------------------------------------------------------+
//| Process one scalp signal                                         |
//+------------------------------------------------------------------+

bool TE_ProcessScalp(
   TradeEngineState &state,
   CTrade &trade,
   const string symbol,
   const double riskPercent,
   const double maxTotalRiskPercent,
   const ulong magic,
   const double minScore,
   const int maxHoldSeconds,
   const int cooldownSeconds,
   const int maxPositions,
   const int maxSymbolPositions,
   const int maxSpreadPts,
   const bool tradingEnabled)
{
   if(!state.initialized)
      return(false);

   if(!state.scalpingEnabled)
      return(false);

   if(!TE_CanTrade(
      state,
      tradingEnabled))
      return(false);

   if(!TE_CooldownComplete(
      state,
      cooldownSeconds))
      return(false);

   //-----------------------------------------------------------------
   // Global position limit
   //-----------------------------------------------------------------

   if(TE_CountPositions(magic)>=
      maxPositions)
   {
      return(false);
   }

   //-----------------------------------------------------------------
   // Symbol position limit
   //-----------------------------------------------------------------

   if(TE_CountSymbolPositions(
      symbol,
      magic)>=
      maxSymbolPositions)
   {
      return(false);
   }

   //-----------------------------------------------------------------
   // Spread
   //-----------------------------------------------------------------

   long spread=0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_SPREAD,
      spread))
      return(false);

   if(spread>maxSpreadPts)
      return(false);

   //-----------------------------------------------------------------
   // Build M1 signal
   //-----------------------------------------------------------------

   M1ScalpSignal signal;

   if(!M1_BuildSignal(
      symbol,
      signal))
   {
      return(false);
   }

   if(!signal.valid)
      return(false);

   if(signal.score<minScore)
      return(false);

   //-----------------------------------------------------------------
   // Do not create opposite exposure.
   //-----------------------------------------------------------------

   if(TE_HasOppositeDirection(
      symbol,
      signal.orderType,
      magic))
   {
      return(false);
   }

   //-----------------------------------------------------------------
   // Stacking protection
   //-----------------------------------------------------------------

   if(!ICT_SCALP_ALLOW_STACKING &&
      TE_HasSameDirection(
         symbol,
         signal.orderType,
         magic))
   {
      return(false);
   }

   //-----------------------------------------------------------------
   // Execute
   //-----------------------------------------------------------------

   ExecutionResult result;

   bool opened=
      EX_OpenScalp(
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
         result
      );

   if(!opened)
      return(false);

   state.lastScalpEntryTime=
      TimeCurrent();

   state.totalScalpEntries++;

   Print(
      "[SCALPER] Entry opened: ",
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

//+------------------------------------------------------------------+
//| Manage scalper positions                                         |
//+------------------------------------------------------------------+

void TE_ManageScalps(
   TradeEngineState &state,
   CTrade &trade,
   const string symbol,
   const int maxHoldSeconds,
   const int cooldownSeconds,
   const ulong magic)
{
   if(!state.initialized)
      return;

   if(!state.scalpingEnabled)
      return;

   //-----------------------------------------------------------------
   // ExecutionEngine handles the actual position-management logic.
   //-----------------------------------------------------------------

   EX_ManageScalps(
      trade,
      symbol,
      magic,
      maxHoldSeconds
   );
}

//+------------------------------------------------------------------+
//| Process normal mode placeholder                                  |
//+------------------------------------------------------------------+

bool TE_ProcessNormal(
   TradeEngineState &state,
   const bool tradingEnabled)
{
   if(!state.initialized)
      return(false);

   if(!state.normalEnabled)
      return(false);

   if(!tradingEnabled)
      return(false);

   // Normal ICT analysis/execution is kept in the main EA's
   // structural pipeline and supporting modules.

   return(true);
}

//+------------------------------------------------------------------+
//| Reset runtime state                                              |
//+------------------------------------------------------------------+

void TE_Reset(
   TradeEngineState &state)
{
   state.lastScalpEntryTime=0;
   state.totalScalpEntries=0;
}

//+------------------------------------------------------------------+
//| Status                                                            |
//+------------------------------------------------------------------+

void TE_PrintStatus(
   const TradeEngineState &state)
{
   if(!state.initialized)
   {
      Print(
         "[TRADE ENGINE] Not initialized."
      );

      return;
   }

   Print(
      "[TRADE ENGINE] Mode=",
      EnumToString(state.mode),
      " | Normal=",
      state.normalEnabled,
      " | Scalping=",
      state.scalpingEnabled,
      " | ScalpEntries=",
      state.totalScalpEntries
   );
}

#endif
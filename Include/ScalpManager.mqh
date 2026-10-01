//+------------------------------------------------------------------+
//| ScalpManager.mqh - M1 rapid position management                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_SCALP_MANAGER_MQH__
#define __EXNESS_ICT_SCALP_MANAGER_MQH__

#include "Config.mqh"
#include "M1Scalper.mqh"
#include "ExecutionEngine.mqh"

//==================================================================
// STATE
//==================================================================

datetime SM_LastEntryTime = 0;
datetime SM_LastClosedBar = 0;


//==================================================================
// COOLDOWN
//==================================================================

bool SM_CooldownComplete()
{
   if(SM_LastEntryTime<=0)
      return(true);

   return(
      (TimeCurrent()-SM_LastEntryTime)
      >=ICT_SCALP_COOLDOWN_SECONDS
   );
}


void SM_RecordEntry()
{
   SM_LastEntryTime=TimeCurrent();
}


//==================================================================
// POSITION AGE
//==================================================================

int SM_PositionAgeSeconds(
   const ulong ticket
)
{
   if(ticket==0)
      return(-1);

   if(!PositionSelectByTicket(ticket))
      return(-1);

   datetime openTime=
      (datetime)PositionGetInteger(
         POSITION_TIME
      );

   if(openTime<=0)
      return(-1);

   return(
      (int)(TimeCurrent()-openTime)
   );
}


//==================================================================
// PROFIT / LOSS
//==================================================================

double SM_PositionProfit(
   const ulong ticket
)
{
   if(ticket==0)
      return(0.0);

   if(!PositionSelectByTicket(ticket))
      return(0.0);

   return(
      PositionGetDouble(
         POSITION_PROFIT
      )
   );
}


//==================================================================
// MOMENTUM REVERSAL
//==================================================================

bool SM_ShouldCloseForReversal(
   const string symbol,
   const ENUM_POSITION_TYPE positionType
)
{
   M1ScalpSignal signal;

   if(!M1_BuildSignal(symbol,signal))
      return(false);

   if(!signal.valid)
      return(false);

   if(positionType==POSITION_TYPE_BUY)
   {
      if(signal.orderType==ORDER_TYPE_SELL)
         return(true);
   }

   if(positionType==POSITION_TYPE_SELL)
   {
      if(signal.orderType==ORDER_TYPE_BUY)
         return(true);
   }

   return(false);
}


//==================================================================
// MAX HOLD TIME
//==================================================================

bool SM_ShouldCloseForAge(
   const ulong ticket
)
{
   int age=
      SM_PositionAgeSeconds(ticket);

   if(age<0)
      return(false);

   return(
      age>=ICT_SCALP_MAX_HOLD_SECONDS
   );
}


//==================================================================
// PROFIT TARGET CHECK
//==================================================================

bool SM_ShouldTakeProfit(
   const ulong ticket
)
{
   if(!PositionSelectByTicket(ticket))
      return(false);

   double profit=
      PositionGetDouble(
         POSITION_PROFIT
      );

   if(profit<=0.0)
      return(false);

   string symbol=
      PositionGetString(
         POSITION_SYMBOL
      );

   double entry=
      PositionGetDouble(
         POSITION_PRICE_OPEN
      );

   double tp=
      PositionGetDouble(
         POSITION_TP
      );

   if(entry<=0.0 || tp<=0.0)
      return(false);

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return(false);

   ENUM_POSITION_TYPE type=
      (ENUM_POSITION_TYPE)
      PositionGetInteger(
         POSITION_TYPE
      );

   double current;

   if(type==POSITION_TYPE_BUY)
      current=tick.bid;
   else
      current=tick.ask;

   if(type==POSITION_TYPE_BUY)
   {
      if(current>=tp)
         return(true);
   }
   else
   {
      if(current<=tp)
         return(true);
   }

   return(false);
}


//==================================================================
// MANAGE ONE POSITION
//==================================================================

bool SM_ManagePosition(
   const ulong ticket
)
{
   if(ticket==0)
      return(false);

   if(!PositionSelectByTicket(ticket))
      return(false);

   if(PositionGetInteger(POSITION_MAGIC)!=
      ICT_MAGIC_NUMBER)
   {
      return(false);
   }

   string symbol=
      PositionGetString(
         POSITION_SYMBOL
      );

   ENUM_POSITION_TYPE type=
      (ENUM_POSITION_TYPE)
      PositionGetInteger(
         POSITION_TYPE
      );

   // ---------------------------------------------------------------
   // 1. Hard maximum holding time
   // ---------------------------------------------------------------

   if(SM_ShouldCloseForAge(ticket))
   {
      return(
         EE_ClosePosition(
            ticket,
            "M1 maximum hold time reached"
         )
      );
   }

   // ---------------------------------------------------------------
   // 2. Take profit
   // ---------------------------------------------------------------

   if(SM_ShouldTakeProfit(ticket))
   {
      return(
         EE_ClosePosition(
            ticket,
            "M1 target reached"
         )
      );
   }

   // ---------------------------------------------------------------
   // 3. Momentum reversal
   // ---------------------------------------------------------------

   if(SM_ShouldCloseForReversal(symbol,type))
   {
      return(
         EE_ClosePosition(
            ticket,
            "M1 momentum reversal"
         )
      );
   }

   return(false);
}


//==================================================================
// MANAGE ALL SCALP POSITIONS
//==================================================================

int SM_ManageAll()
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

      if(PositionGetInteger(POSITION_MAGIC)!=
         ICT_MAGIC_NUMBER)
      {
         continue;
      }

      string comment=
         PositionGetString(
            POSITION_COMMENT
         );

      // Only manage positions opened by the M1 scalper.
      if(StringFind(
            comment,
            "ICT-M1-Scalp"
         )<0)
      {
         continue;
      }

      if(SM_ManagePosition(ticket))
         closed++;
   }

   return(closed);
}


//==================================================================
// NEW M1 BAR
//==================================================================

bool SM_IsNewM1Bar(
   const string symbol
)
{
   datetime currentBar=
      iTime(
         symbol,
         PERIOD_M1,
         0
      );

   if(currentBar<=0)
      return(false);

   if(currentBar==SM_LastClosedBar)
      return(false);

   SM_LastClosedBar=currentBar;

   return(true);
}


//==================================================================
// SCALP ENTRY
//==================================================================

bool SM_TryEntry(
   const string symbol
)
{
   if(!SM_CooldownComplete())
      return(false);

   if(!EE_IsSpreadSafe(symbol,true))
      return(false);

   M1ScalpSignal signal;

   if(!M1_BuildSignal(symbol,signal))
      return(false);

   if(!signal.valid)
      return(false);

   if(!ICT_SCALP_ALLOW_STACKING)
   {
      if(
         EE_CountMagicSymbolPositions(symbol)>0
      )
      {
         return(false);
      }
   }

   bool opened=
      EE_OpenScalp(
         symbol,
         signal
      );

   if(opened)
      SM_RecordEntry();

   return(opened);
}


//==================================================================
// COMPLETE SCALPER TICK
//==================================================================

void SM_ProcessSymbol(
   const string symbol
)
{
   if(symbol=="")
      return;

   // Always manage existing positions.
   SM_ManageAll();

   // Only search for a new entry once per new M1 candle.
   if(!SM_IsNewM1Bar(symbol))
      return;

   SM_TryEntry(symbol);
}

#endif
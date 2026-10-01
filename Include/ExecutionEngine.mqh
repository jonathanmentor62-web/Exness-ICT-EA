//+------------------------------------------------------------------+
//| ExecutionEngine.mqh - controlled execution for M1 scalping      |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_EXECUTION_ENGINE_MQH__
#define __EXNESS_ICT_EXECUTION_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include "Config.mqh"
#include "RiskEngine.mqh"
#include "M1Scalper.mqh"


//==================================================================
// EXECUTION RESULT
//==================================================================

struct ExecutionResult
{
   bool attempted;
   bool executed;

   ulong ticket;

   double volume;
   double riskMoney;

   string reason;
};


//==================================================================
// RESET RESULT
//==================================================================

void ResetExecutionResult(
   ExecutionResult &r
)
{
   r.attempted=false;
   r.executed=false;

   r.ticket=0;

   r.volume=0.0;
   r.riskMoney=0.0;

   r.reason="";
}


//==================================================================
// COUNT EA POSITIONS
//==================================================================

int EX_CountOurPositions(
   const ulong magic,
   const string symbol=""
)
{
   int count=0;


   for(
      int i=PositionsTotal()-1;
      i>=0;
      i--
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(
         ticket==0 ||
         !PositionSelectByTicket(ticket)
      )
         continue;


      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         )!=magic
      )
         continue;


      if(
         symbol!="" &&
         PositionGetString(
            POSITION_SYMBOL
         )!=symbol
      )
         continue;


      count++;
   }


   return(count);
}


//==================================================================
// CHECK OPPOSITE POSITION
//==================================================================

bool EX_HasOppositePosition(
   const ulong magic,
   const string symbol,
   const ENUM_ORDER_TYPE orderType
)
{
   long wanted=
      (
         orderType==ORDER_TYPE_BUY
         ? POSITION_TYPE_SELL
         : POSITION_TYPE_BUY
      );


   for(
      int i=PositionsTotal()-1;
      i>=0;
      i--
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(
         ticket==0 ||
         !PositionSelectByTicket(ticket)
      )
         continue;


      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         )!=magic
      )
         continue;


      if(
         PositionGetString(
            POSITION_SYMBOL
         )!=symbol
      )
         continue;


      if(
         PositionGetInteger(
            POSITION_TYPE
         )==wanted
      )
      {
         return(true);
      }
   }


   return(false);
}


//==================================================================
// SPREAD CHECK
//==================================================================

bool EX_SpreadOK(
   const string symbol,
   const int maxSpreadPts
)
{
   MqlTick tick;


   if(
      !SymbolInfoTick(
         symbol,
         tick
      )
   )
      return(false);


   double point=
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   if(
      point<=0.0 ||
      tick.bid<=0.0 ||
      tick.ask<=0.0
   )
      return(false);


   double spread=
      (
         tick.ask-
         tick.bid
      )/point;


   return(
      spread<=maxSpreadPts
   );
}


//==================================================================
// STOP DISTANCE CHECK
//==================================================================

bool EX_StopDistanceOK(
   const string symbol,
   const ENUM_ORDER_TYPE type,
   const double entry,
   const double sl
)
{
   if(
      entry<=0.0 ||
      sl<=0.0
   )
      return(false);


   double point=
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   if(point<=0.0)
      return(false);


   long stopsLevel=0;


   if(
      !SymbolInfoInteger(
         symbol,
         SYMBOL_TRADE_STOPS_LEVEL,
         stopsLevel
      )
   )
      return(false);


   double required=
      MathMax(
         (double)ICT_MIN_STOP_DISTANCE_PTS,
         (double)stopsLevel
      )*point;


   if(type==ORDER_TYPE_BUY)
   {
      if(
         sl>=entry ||
         (entry-sl)<required
      )
         return(false);
   }
   else if(type==ORDER_TYPE_SELL)
   {
      if(
         sl<=entry ||
         (sl-entry)<required
      )
         return(false);
   }
   else
   {
      return(false);
   }


   return(true);
}


//==================================================================
// TAKE PROFIT CHECK
//==================================================================

bool EX_TakeProfitOK(
   const string symbol,
   const ENUM_ORDER_TYPE type,
   const double entry,
   const double tp
)
{
   if(
      entry<=0.0 ||
      tp<=0.0
   )
      return(false);


   double point=
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   if(point<=0.0)
      return(false);


   long stopsLevel=0;


   SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_STOPS_LEVEL,
      stopsLevel
   );


   double required=
      MathMax(
         (double)ICT_MIN_STOP_DISTANCE_PTS,
         (double)stopsLevel
      )*point;


   if(type==ORDER_TYPE_BUY)
   {
      return(
         tp>entry &&
         (tp-entry)>=required
      );
   }


   if(type==ORDER_TYPE_SELL)
   {
      return(
         tp<entry &&
         (entry-tp)>=required
      );
   }


   return(false);
}


//==================================================================
// CHECK MT5 TRADE RESULT
//==================================================================

bool EX_TradeRequestSucceeded(
   CTrade &trade
)
{
   uint code=
      trade.ResultRetcode();


   return(
      code==TRADE_RETCODE_DONE ||
      code==TRADE_RETCODE_DONE_PARTIAL ||
      code==TRADE_RETCODE_PLACED
   );
}


//==================================================================
// OPEN SCALP
//==================================================================

bool EX_OpenScalp(
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
   ExecutionResult &result
)
{
   ResetExecutionResult(result);

   result.attempted=true;


   //---------------------------------------------------------------
   // Trading switch
   //---------------------------------------------------------------

   if(!tradingEnabled)
   {
      result.reason=
         "Trading disabled by EA input.";

      return(false);
   }


   //---------------------------------------------------------------
   // Signal validation
   //---------------------------------------------------------------

   if(!signal.valid)
   {
      result.reason=
         "Invalid scalper signal.";

      return(false);
   }


   //---------------------------------------------------------------
   // Symbol
   //---------------------------------------------------------------

   if(
      !SymbolSelect(
         symbol,
         true
      )
   )
   {
      result.reason=
         "Symbol could not be selected.";

      return(false);
   }


   long tradeMode=0;


   if(
      !SymbolInfoInteger(
         symbol,
         SYMBOL_TRADE_MODE,
         tradeMode
      ) ||
      tradeMode==
      SYMBOL_TRADE_MODE_DISABLED
   )
   {
      result.reason=
         "Symbol trading is disabled.";

      return(false);
   }


   //---------------------------------------------------------------
   // Spread
   //---------------------------------------------------------------

   if(
      !EX_SpreadOK(
         symbol,
         maxSpreadPts
      )
   )
   {
      result.reason=
         "Spread too high.";

      return(false);
   }


   //---------------------------------------------------------------
   // Global position limit
   //---------------------------------------------------------------

   if(
      EX_CountOurPositions(
         magic
      )>=maxPositions
   )
   {
      result.reason=
         "Maximum EA positions reached.";

      return(false);
   }


   //---------------------------------------------------------------
   // Symbol position limit
   //---------------------------------------------------------------

   if(
      EX_CountOurPositions(
         magic,
         symbol
      )>=maxSymbolPositions
   )
   {
      result.reason=
         "Maximum symbol positions reached.";

      return(false);
   }


   //---------------------------------------------------------------
   // Opposite position protection
   //---------------------------------------------------------------

   if(
      ICT_BLOCK_OPPOSITE_SYMBOL &&
      EX_HasOppositePosition(
         magic,
         symbol,
         signal.orderType
      )
   )
   {
      result.reason=
         "Opposite symbol position exists.";

      return(false);
   }


   //---------------------------------------------------------------
   // Current executable price
   //---------------------------------------------------------------

   MqlTick tick;


   if(
      !SymbolInfoTick(
         symbol,
         tick
      )
   )
   {
      result.reason=
         "No current tick.";

      return(false);
   }


   double entry=
      (
         signal.orderType==
         ORDER_TYPE_BUY
         ? tick.ask
         : tick.bid
      );


   if(entry<=0.0)
   {
      result.reason=
         "Invalid current entry price.";

      return(false);
   }


   //---------------------------------------------------------------
   // Preserve signal distances
   //---------------------------------------------------------------

   double slDistance=
      MathAbs(
         signal.entry-
         signal.stopLoss
      );


   double tpDistance=
      MathAbs(
         signal.takeProfit-
         signal.entry
      );


   if(
      slDistance<=0.0 ||
      tpDistance<=0.0
   )
   {
      result.reason=
         "Invalid signal distances.";

      return(false);
   }


   //---------------------------------------------------------------
   // Re-anchor SL and TP to current executable price
   //---------------------------------------------------------------

   double stopLoss=
      (
         signal.orderType==
         ORDER_TYPE_BUY
         ?
         entry-slDistance
         :
         entry+slDistance
      );


   double takeProfit=
      (
         signal.orderType==
         ORDER_TYPE_BUY
         ?
         entry+tpDistance
         :
         entry-tpDistance
      );


   int digits=
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );


   stopLoss=
      NormalizeDouble(
         stopLoss,
         digits
      );


   takeProfit=
      NormalizeDouble(
         takeProfit,
         digits
      );


   //---------------------------------------------------------------
   // Stop-loss validation
   //---------------------------------------------------------------

   if(
      !EX_StopDistanceOK(
         symbol,
         signal.orderType,
         entry,
         stopLoss
      )
   )
   {
      result.reason=
         "Invalid/too-close stop loss.";

      return(false);
   }


   //---------------------------------------------------------------
   // Take-profit validation
   //---------------------------------------------------------------

   if(
      !EX_TakeProfitOK(
         symbol,
         signal.orderType,
         entry,
         takeProfit
      )
   )
   {
      result.reason=
         "Invalid/too-close take profit.";

      return(false);
   }


   //---------------------------------------------------------------
   // Risk-based lot calculation
   //---------------------------------------------------------------

   double volume=
      RE_CalculateCompoundingLots(
         symbol,
         signal.orderType,
         entry,
         stopLoss,
         riskPercent
      );


   if(volume<=0.0)
   {
      result.reason=
         "No broker-valid lot fits configured risk.";

      return(false);
   }


   //---------------------------------------------------------------
   // Total risk validation
   //---------------------------------------------------------------

   if(
      !RE_ValidateNewTrade(
         symbol,
         signal.orderType,
         entry,
         stopLoss,
         volume,
         riskPercent,
         maxTotalRiskPercent
      )
   )
   {
      result.reason=
         "Risk engine rejected trade.";

      return(false);
   }


   //---------------------------------------------------------------
   // Configure trade
   //---------------------------------------------------------------

   trade.SetExpertMagicNumber(
      magic
   );


   trade.SetDeviationInPoints(
      ICT_MAX_SLIPPAGE_PTS
   );


   trade.SetTypeFillingBySymbol(
      symbol
   );


   //---------------------------------------------------------------
   // Order comment
   //---------------------------------------------------------------

   string comment=
      (
         signal.orderType==
         ORDER_TYPE_BUY
         ?
         "ICT-M1-SCALP-BUY"
         :
         "ICT-M1-SCALP-SELL"
      );


   //---------------------------------------------------------------
   // Send order
   //---------------------------------------------------------------

   bool requestAccepted=
      trade.PositionOpen(
         symbol,
         signal.orderType,
         volume,
         entry,
         stopLoss,
         takeProfit,
         comment
      );


   //---------------------------------------------------------------
   // Verify actual MT5 result
   //---------------------------------------------------------------

   if(
      !requestAccepted ||
      !EX_TradeRequestSucceeded(
         trade
      )
   )
   {
      result.reason=
         "MT5 order rejected: "+
         trade.ResultRetcodeDescription();

      return(false);
   }


   //---------------------------------------------------------------
   // Success
   //---------------------------------------------------------------

   result.executed=true;


   result.ticket=
      trade.ResultDeal();


   if(result.ticket==0)
   {
      result.ticket=
         trade.ResultOrder();
   }


   result.volume=
      volume;


   result.riskMoney=
      RE_PositionRiskMoney(
         symbol,
         signal.orderType,
         volume,
         entry,
         stopLoss
      );


   result.reason=
      "Scalp order executed.";


   Print(
      "[SCALP ENTRY] ",
      symbol,
      " | ",
      EnumToString(
         signal.orderType
      ),
      " | lots=",
      DoubleToString(
         volume,
         2
      ),
      " | score=",
      DoubleToString(
         signal.score,
         1
      ),
      " | risk=",
      DoubleToString(
         result.riskMoney,
         2
      ),
      " | reason=",
      signal.reason
   );


   return(true);
}


//==================================================================
// CLOSE POSITION
//==================================================================

bool EX_ClosePosition(
   CTrade &trade,
   const ulong ticket,
   const string reason
)
{
   if(
      ticket==0 ||
      !PositionSelectByTicket(
         ticket
      )
   )
      return(false);


   ulong magic=
      (ulong)PositionGetInteger(
         POSITION_MAGIC
      );


   if(
      magic!=
      ICT_MAGIC_NUMBER
   )
      return(false);


   string symbol=
      PositionGetString(
         POSITION_SYMBOL
      );


   bool requestAccepted=
      trade.PositionClose(
         ticket,
         ICT_MAX_SLIPPAGE_PTS
      );


   if(
      !requestAccepted ||
      !EX_TradeRequestSucceeded(
         trade
      )
   )
   {
      Print(
         "[SCALP EXIT FAILED] ",
         symbol,
         " | ticket=",
         ticket,
         " | ",
         trade.ResultRetcodeDescription()
      );

      return(false);
   }


   Print(
      "[SCALP EXIT] ",
      symbol,
      " | ticket=",
      ticket,
      " | reason=",
      reason
   );


   return(true);
}


//==================================================================
// MANAGE EXISTING SCALPS
//==================================================================

void EX_ManageScalps(
   CTrade &trade,
   const ulong magic,
   const int maxHoldSeconds
)
{
   datetime now=
      TimeCurrent();


   for(
      int i=PositionsTotal()-1;
      i>=0;
      i--
   )
   {
      ulong ticket=
         PositionGetTicket(i);


      if(
         ticket==0 ||
         !PositionSelectByTicket(
            ticket
         )
      )
         continue;


      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         )!=magic
      )
         continue;


      //------------------------------------------------------------
      // Only manage our M1 scalper positions
      //------------------------------------------------------------

      string comment=
         PositionGetString(
            POSITION_COMMENT
         );


      if(
         StringFind(
            comment,
            "ICT-M1-SCALP-"
         )<0
      )
         continue;


      string symbol=
         PositionGetString(
            POSITION_SYMBOL
         );


      long type=
         PositionGetInteger(
            POSITION_TYPE
         );


      datetime openTime=
         (datetime)PositionGetInteger(
            POSITION_TIME
         );


      //------------------------------------------------------------
      // Maximum holding time
      //------------------------------------------------------------

      if(
         maxHoldSeconds>0 &&
         openTime>0 &&
         now-openTime>=
         maxHoldSeconds
      )
      {
         EX_ClosePosition(
            trade,
            ticket,
            "maximum hold time reached"
         );

         continue;
      }


      //------------------------------------------------------------
      // Opposite M1 signal
      //------------------------------------------------------------

      M1ScalpSignal signal;


      if(
         M1_BuildSignal(
            symbol,
            signal
         ) &&
         signal.valid
      )
      {
         bool opposite=
            (
               type==
               POSITION_TYPE_BUY &&
               signal.orderType==
               ORDER_TYPE_SELL
            )
            ||
            (
               type==
               POSITION_TYPE_SELL &&
               signal.orderType==
               ORDER_TYPE_BUY
            );


         if(opposite)
         {
            EX_ClosePosition(
               trade,
               ticket,
               "opposite M1 momentum/reversal signal"
            );
         }
      }
   }
}


#endif
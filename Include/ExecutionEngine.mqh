//+------------------------------------------------------------------+
//| ExecutionEngine.mqh - centralized MT5 execution and risk gates  |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_EXECUTION_ENGINE_MQH__
#define __EXNESS_ICT_EXECUTION_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include "Config.mqh"
#include "RiskEngine.mqh"
#include "M1Scalper.mqh"

CTrade EE_Trade;


//==================================================================
// BASIC HELPERS
//==================================================================

double EE_Point(const string symbol)
{
   double point=0.0;

   if(!SymbolInfoDouble(symbol,SYMBOL_POINT,point))
      return(0.0);

   return(point);
}


int EE_Digits(const string symbol)
{
   return((int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
}


double EE_NormalizePrice(
   const string symbol,
   const double price
)
{
   return(
      NormalizeDouble(
         price,
         EE_Digits(symbol)
      )
   );
}


bool EE_GetTick(
   const string symbol,
   MqlTick &tick
)
{
   if(symbol=="")
      return(false);

   return(SymbolInfoTick(symbol,tick));
}


//==================================================================
// SPREAD
//==================================================================

double EE_SpreadPoints(const string symbol)
{
   MqlTick tick;

   if(!EE_GetTick(symbol,tick))
      return(DBL_MAX);

   double point=EE_Point(symbol);

   if(point<=0.0)
      return(DBL_MAX);

   if(tick.ask<=0.0 || tick.bid<=0.0)
      return(DBL_MAX);

   return((tick.ask-tick.bid)/point);
}


bool EE_IsSpreadSafe(
   const string symbol,
   const bool scalper
)
{
   double spread=EE_SpreadPoints(symbol);

   if(spread==DBL_MAX)
      return(false);

   double limit=
      scalper
      ? ICT_SCALP_MAX_SPREAD_POINTS
      : ICT_MAX_SPREAD_PTS;

   return(spread<=limit);
}


//==================================================================
// POSITION COUNTS
//==================================================================

int EE_CountAllMagicPositions()
{
   int count=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      long magic=
         PositionGetInteger(POSITION_MAGIC);

      if(magic!=ICT_MAGIC_NUMBER)
         continue;

      count++;
   }

   return(count);
}


int EE_CountMagicSymbolPositions(
   const string symbol
)
{
   int count=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)!=ICT_MAGIC_NUMBER)
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      count++;
   }

   return(count);
}


int EE_CountMagicSymbolDirection(
   const string symbol,
   const ENUM_POSITION_TYPE direction
)
{
   int count=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)!=ICT_MAGIC_NUMBER)
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      if((ENUM_POSITION_TYPE)
         PositionGetInteger(POSITION_TYPE)==direction)
      {
         count++;
      }
   }

   return(count);
}


//==================================================================
// OPPOSITE POSITION CHECK
//==================================================================

bool EE_HasOppositePosition(
   const string symbol,
   const ENUM_ORDER_TYPE orderType
)
{
   ENUM_POSITION_TYPE opposite;

   if(orderType==ORDER_TYPE_BUY)
      opposite=POSITION_TYPE_SELL;
   else
      opposite=POSITION_TYPE_BUY;

   return(
      EE_CountMagicSymbolDirection(
         symbol,
         opposite
      )>0
   );
}


//==================================================================
// STOP VALIDATION
//==================================================================

bool EE_ValidateStops(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double sl,
   const double tp
)
{
   if(entry<=0.0 || sl<=0.0 || tp<=0.0)
      return(false);

   double point=EE_Point(symbol);

   if(point<=0.0)
      return(false);

   long stopsLevel=
      SymbolInfoInteger(
         symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   double minimumDistance=
      (double)stopsLevel*point;

   if(minimumDistance<point*ICT_MIN_STOP_DISTANCE_PTS)
      minimumDistance=
         point*ICT_MIN_STOP_DISTANCE_PTS;

   if(orderType==ORDER_TYPE_BUY)
   {
      if(sl>=entry)
         return(false);

      if(tp<=entry)
         return(false);

      if((entry-sl)<minimumDistance)
         return(false);

      if((tp-entry)<minimumDistance)
         return(false);
   }
   else if(orderType==ORDER_TYPE_SELL)
   {
      if(sl<=entry)
         return(false);

      if(tp>=entry)
         return(false);

      if((sl-entry)<minimumDistance)
         return(false);

      if((entry-tp)<minimumDistance)
         return(false);
   }
   else
   {
      return(false);
   }

   return(true);
}


//==================================================================
// RISK CHECK
//==================================================================

bool EE_RiskAllowsTrade(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double lots,
   const double entry,
   const double sl
)
{
   if(lots<=0.0)
      return(false);

   if(entry<=0.0 || sl<=0.0)
      return(false);

   double equity=
      AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity<=0.0)
      return(false);

   double riskPerLot=
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entry,
         sl
      );

   if(riskPerLot<=0.0)
      return(false);

   double newTradeRisk=
      riskPerLot*lots;

   double maxSingleRisk=
      equity*
      ICT_MAX_RISK_PERCENT/
      100.0;

   if(newTradeRisk>maxSingleRisk)
      return(false);

   double openRisk=
      RE_GetOpenRiskMoney();

   if(openRisk>=1.0e100)
      return(false);

   double maxTotalRisk=
      equity*
      ICT_MAX_TOTAL_RISK_PERCENT/
      100.0;

   if(openRisk+newTradeRisk>maxTotalRisk)
      return(false);

   return(true);
}


//==================================================================
// LOT CALCULATION
//==================================================================

double EE_CalculateLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double sl
)
{
   return(
      RE_CalculateLots(
         symbol,
         orderType,
         entry,
         sl
      )
   );
}


//==================================================================
// GENERIC ORDER OPEN
//==================================================================

bool EE_OpenOrder(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double requestedSL,
   const double requestedTP,
   const bool scalper,
   string comment
)
{
   if(symbol=="")
      return(false);

   if(!SymbolSelect(symbol,true))
      return(false);

   // Safety: execution must be explicitly enabled by the EA.
   if(!ICT_TRADING_DEFAULT_ENABLED)
   {
      Print(
         "[EXECUTION BLOCKED] Trading default is disabled."
      );

      return(false);
   }

   // Spread protection.
   if(!EE_IsSpreadSafe(symbol,scalper))
   {
      Print(
         "[EXECUTION BLOCKED] Spread too high on ",
         symbol
      );

      return(false);
   }

   // Global position limits.
   int totalPositions=
      EE_CountAllMagicPositions();

   if(totalPositions>=ICT_MAX_TOTAL_POSITIONS)
   {
      Print(
         "[EXECUTION BLOCKED] Maximum EA positions reached."
      );

      return(false);
   }

   if(totalPositions>=ICT_MAX_OPEN_TRADES)
   {
      Print(
         "[EXECUTION BLOCKED] Maximum open trades reached."
      );

      return(false);
   }

   // Symbol exposure.
   int symbolPositions=
      EE_CountMagicSymbolPositions(symbol);

   int symbolLimit=
      scalper
      ? ICT_SCALP_MAX_POSITIONS
      : ICT_MAX_SYMBOL_POSITIONS;

   if(symbolPositions>=symbolLimit)
   {
      Print(
         "[EXECUTION BLOCKED] Symbol position limit reached: ",
         symbol
      );

      return(false);
   }

   // Optional opposite-position protection.
   if(ICT_BLOCK_OPPOSITE_SYMBOL &&
      EE_HasOppositePosition(symbol,orderType))
   {
      Print(
         "[EXECUTION BLOCKED] Opposite position exists on ",
         symbol
      );

      return(false);
   }

   MqlTick tick;

   if(!EE_GetTick(symbol,tick))
      return(false);

   double entry;

   if(orderType==ORDER_TYPE_BUY)
      entry=tick.ask;
   else if(orderType==ORDER_TYPE_SELL)
      entry=tick.bid;
   else
      return(false);

   if(entry<=0.0)
      return(false);

   double sl=
      EE_NormalizePrice(
         symbol,
         requestedSL
      );

   double tp=
      EE_NormalizePrice(
         symbol,
         requestedTP
      );

   if(!EE_ValidateStops(
      symbol,
      orderType,
      entry,
      sl,
      tp
   ))
   {
      Print(
         "[EXECUTION BLOCKED] Invalid SL/TP: ",
         symbol
      );

      return(false);
   }

   // Equity-based dynamic position sizing.
   double lots=
      EE_CalculateLots(
         symbol,
         orderType,
         entry,
         sl
      );

   if(lots<=0.0)
   {
      Print(
         "[EXECUTION BLOCKED] Calculated lot size is zero."
      );

      return(false);
   }

   // Final risk gate.
   if(!EE_RiskAllowsTrade(
      symbol,
      orderType,
      lots,
      entry,
      sl
   ))
   {
      Print(
         "[EXECUTION BLOCKED] Risk limit rejected trade."
      );

      return(false);
   }

   EE_Trade.SetExpertMagicNumber(
      ICT_MAGIC_NUMBER
   );

   EE_Trade.SetDeviationInPoints(
      ICT_MAX_SLIPPAGE_PTS
   );

   bool result=
      EE_Trade.PositionOpen(
         symbol,
         orderType,
         lots,
         entry,
         sl,
         tp,
         comment
      );

   if(!result)
   {
      Print(
         "[ORDER FAILED] ",
         symbol,
         " retcode=",
         EE_Trade.ResultRetcode(),
         " ",
         EE_Trade.ResultRetcodeDescription()
      );

      return(false);
   }

   Print(
      "[ORDER OPENED] ",
      symbol,
      " type=",
      EnumToString(orderType),
      " lots=",
      DoubleToString(lots,2),
      " entry=",
      DoubleToString(entry,EE_Digits(symbol)),
      " SL=",
      DoubleToString(sl,EE_Digits(symbol)),
      " TP=",
      DoubleToString(tp,EE_Digits(symbol))
   );

   return(true);
}


//==================================================================
// M1 SCALPER ENTRY
//==================================================================

bool EE_OpenScalp(
   const string symbol,
   const M1ScalpSignal &signal
)
{
   if(!signal.valid)
      return(false);

   string comment=
      "ICT-M1-Scalp";

   return(
      EE_OpenOrder(
         symbol,
         signal.orderType,
         signal.stopLoss,
         signal.takeProfit,
         true,
         comment
      )
   );
}


//==================================================================
// CLOSE POSITION
//==================================================================

bool EE_ClosePosition(
   const ulong ticket,
   const string reason
)
{
   if(ticket==0)
      return(false);

   if(!PositionSelectByTicket(ticket))
      return(false);

   if(PositionGetInteger(POSITION_MAGIC)!=ICT_MAGIC_NUMBER)
      return(false);

   string symbol=
      PositionGetString(POSITION_SYMBOL);

   EE_Trade.SetExpertMagicNumber(
      ICT_MAGIC_NUMBER
   );

   EE_Trade.SetDeviationInPoints(
      ICT_MAX_SLIPPAGE_PTS
   );

   bool result=
      EE_Trade.PositionClose(
         ticket,
         ICT_MAX_SLIPPAGE_PTS
      );

   if(result)
   {
      Print(
         "[POSITION CLOSED] ",
         symbol,
         " ticket=",
         ticket,
         " reason=",
         reason
      );
   }
   else
   {
      Print(
         "[CLOSE FAILED] ",
         symbol,
         " ticket=",
         ticket,
         " retcode=",
         EE_Trade.ResultRetcode(),
         " ",
         EE_Trade.ResultRetcodeDescription()
      );
   }

   return(result);
}


//==================================================================
// CLOSE ALL EA POSITIONS FOR SYMBOL
//==================================================================

int EE_CloseSymbolPositions(
   const string symbol,
   const string reason
)
{
   int closed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)!=ICT_MAGIC_NUMBER)
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      if(EE_ClosePosition(ticket,reason))
         closed++;
   }

   return(closed);
}


//==================================================================
// DIAGNOSTICS
//==================================================================

void EE_PrintStatus(const string symbol)
{
   Print(
      "[EXECUTION STATUS] ",
      symbol,
      " positions=",
      EE_CountMagicSymbolPositions(symbol),
      " total=",
      EE_CountAllMagicPositions(),
      " spread=",
      DoubleToString(
         EE_SpreadPoints(symbol),
         1
      ),
      " openRisk=",
      DoubleToString(
         RE_GetOpenRiskMoney(),
         2
      )
   );
}

#endif
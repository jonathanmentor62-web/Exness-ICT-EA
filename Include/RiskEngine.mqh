//+------------------------------------------------------------------+
//| RiskEngine.mqh                                                   |
//| Gold Multi-Strategy EA - Final Risk Authority                   |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_RISK_ENGINE_MQH__
#define __EXNESS_GOLD_RISK_ENGINE_MQH__

#include "Config.mqh"

//====================================================================
// ACCOUNT EQUITY
//====================================================================

double RE_GetEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

double RE_GetBalance()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

double RE_GetFreeMargin()
{
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

//====================================================================
// GOLD SYMBOL VALIDATION
//====================================================================

bool RE_IsGoldSymbol(const string symbol)
{
   if(symbol == "")
      return false;

   string upperSymbol = symbol;
   StringToUpper(upperSymbol);

   string prefix = ICT_GOLD_SYMBOL_PREFIX;
   StringToUpper(prefix);

   return StringFind(upperSymbol, prefix) == 0;
}

//====================================================================
// EFFECTIVE RISK PERCENT
//====================================================================

double RE_GetRiskPercent(
   const double configuredRiskPercent
)
{
   double riskPercent = configuredRiskPercent;

   if(riskPercent < 0.0)
      riskPercent = 0.0;

   if(riskPercent > ICT_MAX_RISK_PERCENT)
      riskPercent = ICT_MAX_RISK_PERCENT;

   return riskPercent;
}

//====================================================================
// RISK MONEY
//====================================================================

double RE_GetRiskMoney(
   const double configuredRiskPercent
)
{
   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   double riskPercent =
      RE_GetRiskPercent(configuredRiskPercent);

   if(riskPercent <= 0.0)
      return 0.0;

   return equity * riskPercent / 100.0;
}

//====================================================================
// STRUCTURAL STOP VALIDATION
//====================================================================

bool RE_IsValidStop(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss
)
{
   if(symbol == "")
      return false;

   if(entry <= 0.0 || stopLoss <= 0.0)
      return false;

   if(orderType == ORDER_TYPE_BUY)
   {
      if(stopLoss >= entry)
         return false;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(stopLoss <= entry)
         return false;
   }
   else
   {
      return false;
   }

   double point =
      SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(point <= 0.0)
      return false;

   double distance =
      MathAbs(entry - stopLoss) / point;

   if(distance < ICT_MIN_STOP_DISTANCE_PTS)
      return false;

   return true;
}

//====================================================================
// RISK PER LOT
//====================================================================

double RE_CalculateRiskPerLot(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss
)
{
   if(!RE_IsValidStop(
      symbol,
      orderType,
      entry,
      stopLoss
   ))
   {
      return 0.0;
   }

   double profit = 0.0;

   if(!OrderCalcProfit(
      orderType,
      symbol,
      1.0,
      entry,
      stopLoss,
      profit
   ))
   {
      return 0.0;
   }

   return MathAbs(profit);
}

//====================================================================
// VOLUME DIGITS
//====================================================================

int RE_VolumeDigits(
   const string symbol
)
{
   double step =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );

   if(step <= 0.0)
      return 0;

   int digits = 0;

   while(
      digits < 8 &&
      MathAbs(
         step - MathRound(step)
      ) > 1e-9
   )
   {
      step *= 10.0;
      digits++;
   }

   return digits;
}

//====================================================================
// NORMALIZE LOTS DOWNWARD
//====================================================================

double RE_NormalizeLots(
   const string symbol,
   const double requestedLots
)
{
   if(symbol == "")
      return 0.0;

   if(requestedLots <= 0.0)
      return 0.0;

   double minLot =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN
      );

   double maxLot =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX
      );

   double step =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );

   if(
      minLot <= 0.0 ||
      maxLot <= 0.0 ||
      step <= 0.0
   )
   {
      return 0.0;
   }

   double lots = requestedLots;

   if(lots > maxLot)
      lots = maxLot;

   // Always round DOWN.
   lots =
      MathFloor(
         (lots + 1e-12) / step
      ) * step;

   if(lots < minLot)
      return 0.0;

   int digits =
      RE_VolumeDigits(symbol);

   lots =
      NormalizeDouble(
         lots,
         digits
      );

   if(lots < minLot)
      return 0.0;

   if(lots > maxLot)
      lots = maxLot;

   return lots;
}

//====================================================================
// RAW RISK-BASED LOT SIZE
//====================================================================

double RE_CalculateRawLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double riskPercent
)
{
   if(!RE_IsGoldSymbol(symbol))
      return 0.0;

   if(!RE_IsValidStop(
      symbol,
      orderType,
      entry,
      stopLoss
   ))
   {
      return 0.0;
   }

   double riskMoney =
      RE_GetRiskMoney(riskPercent);

   if(riskMoney <= 0.0)
      return 0.0;

   double riskPerLot =
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entry,
         stopLoss
      );

   if(riskPerLot <= 0.0)
      return 0.0;

   return riskMoney / riskPerLot;
}

//====================================================================
// RISK-BASED LOT SIZE
//====================================================================

double RE_CalculateLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double riskPercent
)
{
   double rawLots =
      RE_CalculateRawLots(
         symbol,
         orderType,
         entry,
         stopLoss,
         riskPercent
      );

   if(rawLots <= 0.0)
      return 0.0;

   return RE_NormalizeLots(
      symbol,
      rawLots
   );
}

//====================================================================
// COMPOUNDING LOT CEILING
//====================================================================
//
// This is an optional growth objective.
//
// It NEVER overrides risk-based sizing.
//
//====================================================================

double RE_CalculateCompoundingLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double riskPercent
)
{
   double riskLots =
      RE_CalculateLots(
         symbol,
         orderType,
         entry,
         stopLoss,
         riskPercent
      );

   if(riskLots <= 0.0)
      return 0.0;

   double equity =
      RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   if(
      ICT_TARGET_EQUITY_FOR_LOT <= 0.0 ||
      ICT_TARGET_LOTS_AT_EQUITY <= 0.0
   )
   {
      return riskLots;
   }

   double desiredLots =
      ICT_TARGET_LOTS_AT_EQUITY *
      (
         equity /
         ICT_TARGET_EQUITY_FOR_LOT
      );

   if(desiredLots <= 0.0)
      return 0.0;

   return RE_NormalizeLots(
      symbol,
      MathMin(
         riskLots,
         desiredLots
      )
   );
}

//====================================================================
// POSITION RISK
//====================================================================

double RE_PositionRiskMoney(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double volume,
   const double entry,
   const double stopLoss
)
{
   if(volume <= 0.0)
      return 0.0;

   double riskPerLot =
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entry,
         stopLoss
      );

   if(riskPerLot <= 0.0)
      return 0.0;

   return riskPerLot * volume;
}

//====================================================================
// OPEN POSITION COUNT
//====================================================================

int RE_GetOpenPositionCount()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if((ulong)magic !=
         (ulong)ICT_MAGIC_NUMBER)
      {
         continue;
      }

      count++;
   }

   return count;
}

//====================================================================
// OPEN GOLD POSITION COUNT
//====================================================================

int RE_GetOpenGoldPositionCount()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if((ulong)magic !=
         (ulong)ICT_MAGIC_NUMBER)
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(RE_IsGoldSymbol(symbol))
         count++;
   }

   return count;
}

//====================================================================
// OPEN RISK MONEY
//====================================================================

double RE_GetOpenRiskMoney()
{
   double totalRisk = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if((ulong)magic !=
         (ulong)ICT_MAGIC_NUMBER)
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(!RE_IsGoldSymbol(symbol))
         continue;

      double volume =
         PositionGetDouble(
            POSITION_VOLUME
         );

      double entry =
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );

      double stopLoss =
         PositionGetDouble(
            POSITION_SL
         );

      if(stopLoss <= 0.0)
         continue;

      ENUM_POSITION_TYPE positionType =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         );

      ENUM_ORDER_TYPE orderType;

      if(positionType ==
         POSITION_TYPE_BUY)
      {
         orderType = ORDER_TYPE_BUY;
      }
      else if(positionType ==
              POSITION_TYPE_SELL)
      {
         orderType = ORDER_TYPE_SELL;
      }
      else
      {
         continue;
      }

      double risk =
         RE_PositionRiskMoney(
            symbol,
            orderType,
            volume,
            entry,
            stopLoss
         );

      if(risk > 0.0)
         totalRisk += risk;
   }

   return totalRisk;
}

//====================================================================
// OPEN RISK PERCENT
//====================================================================

double RE_GetOpenRiskPercent()
{
   double equity =
      RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   double risk =
      RE_GetOpenRiskMoney();

   if(risk <= 0.0)
      return 0.0;

   return risk / equity * 100.0;
}

//====================================================================
// DAILY LOSS
//====================================================================
//
// Uses today's closed deals belonging to this EA.
//
//====================================================================

double RE_GetTodayClosedProfit()
{
   datetime dayStart =
      StringToTime(
         TimeToString(
            TimeCurrent(),
            TIME_DATE
         )
      );

   if(!HistorySelect(
      dayStart,
      TimeCurrent()
   ))
   {
      return 0.0;
   }

   double profit = 0.0;

   int total =
      HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket =
         HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      long magic =
         HistoryDealGetInteger(
            ticket,
            DEAL_MAGIC
         );

      if((ulong)magic !=
         (ulong)ICT_MAGIC_NUMBER)
      {
         continue;
      }

      string symbol =
         HistoryDealGetString(
            ticket,
            DEAL_SYMBOL
         );

      if(!RE_IsGoldSymbol(symbol))
         continue;

      long entry =
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );

      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY
      )
      {
         continue;
      }

      profit +=
         HistoryDealGetDouble(
            ticket,
            DEAL_PROFIT
         );

      profit +=
         HistoryDealGetDouble(
            ticket,
            DEAL_SWAP
         );

      profit +=
         HistoryDealGetDouble(
            ticket,
            DEAL_COMMISSION
         );
   }

   return profit;
}

//====================================================================
// DAILY LOSS LIMIT
//====================================================================

bool RE_DailyLossLimitReached()
{
   if(ICT_MAX_DAILY_LOSS_PERCENT <= 0.0)
      return false;

   double equity =
      RE_GetEquity();

   if(equity <= 0.0)
      return true;

   double todayProfit =
      RE_GetTodayClosedProfit();

   if(todayProfit >= 0.0)
      return false;

   double lossPercent =
      MathAbs(todayProfit) /
      equity *
      100.0;

   return lossPercent >=
          ICT_MAX_DAILY_LOSS_PERCENT;
}

//====================================================================
// FREE-MARGIN SAFETY
//====================================================================

bool RE_HasMarginForTrade(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double volume,
   const double price
)
{
   if(volume <= 0.0)
      return false;

   double requiredMargin = 0.0;

   if(!OrderCalcMargin(
      orderType,
      symbol,
      volume,
      price,
      requiredMargin
   ))
   {
      return false;
   }

   if(requiredMargin <= 0.0)
      return false;

   double freeMargin =
      RE_GetFreeMargin();

   if(freeMargin <= 0.0)
      return false;

   // Keep a safety reserve rather than consuming all free margin.
   return requiredMargin <=
          freeMargin * 0.50;
}

//====================================================================
// COMPLETE NEW-TRADE VALIDATION
//====================================================================

bool RE_ValidateNewTrade(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double volume,
   const double riskPercent,
   const double maxTotalRiskPercent
)
{
   //---------------------------------------------------------------
   // Gold only
   //---------------------------------------------------------------

   if(!RE_IsGoldSymbol(symbol))
      return false;

   //---------------------------------------------------------------
   // Development mode
   //---------------------------------------------------------------

   if(ICT_DEVELOPMENT_MODE)
      return false;

   //---------------------------------------------------------------
   // Basic values
   //---------------------------------------------------------------

   if(volume <= 0.0)
      return false;

   if(entry <= 0.0 || stopLoss <= 0.0)
      return false;

   //---------------------------------------------------------------
   // Structural stop
   //---------------------------------------------------------------

   if(!RE_IsValidStop(
      symbol,
      orderType,
      entry,
      stopLoss
   ))
   {
      return false;
   }

   //---------------------------------------------------------------
   // Effective risk
   //---------------------------------------------------------------

   double effectiveRiskPercent =
      RE_GetRiskPercent(
         riskPercent
      );

   if(effectiveRiskPercent <= 0.0)
      return false;

   //---------------------------------------------------------------
   // Equity
   //---------------------------------------------------------------

   double equity =
      RE_GetEquity();

   if(equity <= 0.0)
      return false;

   //---------------------------------------------------------------
   // Daily loss protection
   //---------------------------------------------------------------

   if(RE_DailyLossLimitReached())
      return false;

   //---------------------------------------------------------------
   // Position limits
   //---------------------------------------------------------------

   if(
      RE_GetOpenPositionCount() >=
      ICT_MAX_TOTAL_POSITIONS
   )
   {
      return false;
   }

   if(
      RE_GetOpenGoldPositionCount() >=
      ICT_MAX_SYMBOL_POSITIONS
   )
   {
      return false;
   }

   //---------------------------------------------------------------
   // Calculate actual position risk
   //---------------------------------------------------------------

   double newTradeRisk =
      RE_PositionRiskMoney(
         symbol,
         orderType,
         volume,
         entry,
         stopLoss
      );

   if(newTradeRisk <= 0.0)
      return false;

   //---------------------------------------------------------------
   // Per-trade risk limit
   //---------------------------------------------------------------

   double maxTradeRiskMoney =
      equity *
      effectiveRiskPercent /
      100.0;

   if(
      newTradeRisk >
      maxTradeRiskMoney + 1e-8
   )
   {
      return false;
   }

   //---------------------------------------------------------------
   // Total portfolio risk
   //---------------------------------------------------------------

   double totalRiskLimit =
      maxTotalRiskPercent;

   if(totalRiskLimit <= 0.0)
      return false;

   if(
      totalRiskLimit <
      effectiveRiskPercent
   )
   {
      return false;
   }

   double existingRisk =
      RE_GetOpenRiskMoney();

   double maxTotalRiskMoney =
      equity *
      totalRiskLimit /
      100.0;

   double combinedRisk =
      existingRisk +
      newTradeRisk;

   if(
      combinedRisk >
      maxTotalRiskMoney + 1e-8
   )
   {
      return false;
   }

   //---------------------------------------------------------------
   // Margin safety
   //---------------------------------------------------------------

   if(!RE_HasMarginForTrade(
      symbol,
      orderType,
      volume,
      entry
   ))
   {
      return false;
   }

   return true;
}

//====================================================================
// RISK SUMMARY
//====================================================================

void RE_PrintSummary()
{
   double equity =
      RE_GetEquity();

   double balance =
      RE_GetBalance();

   double freeMargin =
      RE_GetFreeMargin();

   double openRiskMoney =
      RE_GetOpenRiskMoney();

   double openRiskPercent =
      RE_GetOpenRiskPercent();

   double todayProfit =
     RE_GetTodayClosedProfit();
             
   Print(
      "RiskEngine | Equity=",
      DoubleToString(equity, 2),
      " | Balance=",
      DoubleToString(balance, 2),
      " | FreeMargin=",
      DoubleToString(freeMargin, 2),
      " | OpenRisk=",
      DoubleToString(openRiskMoney, 2),
      " | OpenRisk%=",
      DoubleToString(openRiskPercent, 2),
      "% | TodayClosed=",
      DoubleToString(todayProfit, 2)
   );
}

//+------------------------------------------------------------------+
//| RiskEngine.mqh                                                   |
//| Equity-based position sizing and portfolio risk                  |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_RISK_ENGINE_MQH__
#define __EXNESS_ICT_RISK_ENGINE_MQH__

#include "Config.mqh"

//====================================================================
// EQUITY
//====================================================================

double RE_GetEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

//====================================================================
// RISK PERCENT
//====================================================================

double RE_GetRiskPercent(
   const double configuredRiskPercent = ICT_RISK_PERCENT
)
{
   double p = configuredRiskPercent;

   if(p < 0.0)
      p = 0.0;

   if(p > ICT_MAX_RISK_PERCENT)
      p = ICT_MAX_RISK_PERCENT;

   return p;
}

//====================================================================
// MONEY RISK
//====================================================================

double RE_GetRiskMoney(
   const double configuredRiskPercent = ICT_RISK_PERCENT
)
{
   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   return equity *
          RE_GetRiskPercent(configuredRiskPercent) /
          100.0;
}

//====================================================================
// RISK PER LOT
//====================================================================

double RE_CalculateRiskPerLot(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entryPrice,
   const double stopLossPrice
)
{
   if(symbol == "")
      return 0.0;

   if(entryPrice <= 0.0 || stopLossPrice <= 0.0)
      return 0.0;

   if(orderType != ORDER_TYPE_BUY &&
      orderType != ORDER_TYPE_SELL)
      return 0.0;

   double profit = 0.0;

   if(!OrderCalcProfit(
      orderType,
      symbol,
      1.0,
      entryPrice,
      stopLossPrice,
      profit
   ))
      return 0.0;

   return MathAbs(profit);
}

//====================================================================
// LOT NORMALIZATION
//====================================================================

double RE_NormalizeLots(
   const string symbol,
   const double rawLots
)
{
   if(symbol == "" || rawLots <= 0.0)
      return 0.0;

   double minLot =
      SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);

   double maxLot =
      SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);

   double step =
      SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0 ||
      maxLot <= 0.0 ||
      step <= 0.0)
      return 0.0;

   double lots = MathMin(rawLots,maxLot);

   lots = MathFloor(lots / step) * step;

   // Never round upward to broker minimum.
   // That could exceed intended risk.
   if(lots < minLot)
      return 0.0;

   int digits = 0;

   if(step < 1.0)
      digits = (int)MathCeil(-MathLog10(step));

   if(digits < 0)
      digits = 0;

   if(digits > 8)
      digits = 8;

   return NormalizeDouble(lots,digits);
}

//====================================================================
// RAW LOT SIZE
//====================================================================

double RE_CalculateRawLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entryPrice,
   const double stopLossPrice,
   const double configuredRiskPercent = ICT_RISK_PERCENT
)
{
   double riskMoney =
      RE_GetRiskMoney(configuredRiskPercent);

   double riskPerLot =
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entryPrice,
         stopLossPrice
      );

   if(riskMoney <= 0.0 ||
      riskPerLot <= 0.0)
      return 0.0;

   return riskMoney / riskPerLot;
}

//====================================================================
// FINAL LOT SIZE
//====================================================================

double RE_CalculateLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entryPrice,
   const double stopLossPrice,
   const double configuredRiskPercent = ICT_RISK_PERCENT
)
{
   return RE_NormalizeLots(
      symbol,
      RE_CalculateRawLots(
         symbol,
         orderType,
         entryPrice,
         stopLossPrice,
         configuredRiskPercent
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
   const double entryPrice,
   const double stopLossPrice
)
{
   if(volume <= 0.0)
      return 0.0;

   double perLot =
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entryPrice,
         stopLossPrice
      );

   if(perLot <= 0.0)
      return 0.0;

   return perLot * volume;
}

//====================================================================
// OPEN RISK
//====================================================================

double RE_GetOpenRiskMoney()
{
   double total = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC)
         != ICT_MAGIC_NUMBER)
         continue;

      string symbol =
         PositionGetString(POSITION_SYMBOL);

      long type =
         PositionGetInteger(POSITION_TYPE);

      ENUM_ORDER_TYPE orderType =
         (type == POSITION_TYPE_BUY)
         ? ORDER_TYPE_BUY
         : ORDER_TYPE_SELL;

      double volume =
         PositionGetDouble(POSITION_VOLUME);

      double entry =
         PositionGetDouble(POSITION_PRICE_OPEN);

      double sl =
         PositionGetDouble(POSITION_SL);

      // An EA position without an SL is unmanaged risk.
      // Do not count it as zero risk.
      if(sl <= 0.0)
      {
         Print(
            "[RISK WARNING] EA position has no stop loss. "
            "Risk validation will block new entries."
         );

         return DBL_MAX;
      }

      total +=
         RE_PositionRiskMoney(
            symbol,
            orderType,
            volume,
            entry,
            sl
         );
   }

   return total;
}

//====================================================================
// OPEN RISK PERCENT
//====================================================================

double RE_GetOpenRiskPercent()
{
   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   double risk = RE_GetOpenRiskMoney();

   if(risk == DBL_MAX)
      return 100.0;

   return (risk / equity) * 100.0;
}

//====================================================================
// NEW TRADE VALIDATION
//====================================================================

bool RE_ValidateNewTrade(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entryPrice,
   const double stopLossPrice,
   const double volume,
   const double configuredRiskPercent = ICT_RISK_PERCENT,
   const double maxTotalRiskPercent = ICT_MAX_TOTAL_RISK_PERCENT
)
{
   if(symbol == "")
      return false;

   if(volume <= 0.0)
      return false;

   if(entryPrice <= 0.0 ||
      stopLossPrice <= 0.0)
      return false;

   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return false;

   double tradeRisk =
      RE_PositionRiskMoney(
         symbol,
         orderType,
         volume,
         entryPrice,
         stopLossPrice
      );

   if(tradeRisk <= 0.0)
      return false;

   double tradeRiskPercent =
      (tradeRisk / equity) * 100.0;

   double hardPerTrade =
      RE_GetRiskPercent(configuredRiskPercent);

   if(tradeRiskPercent >
      hardPerTrade + 0.000001)
      return false;

   double currentRisk =
      RE_GetOpenRiskMoney();

   if(currentRisk == DBL_MAX)
      return false;

   double hardTotal = maxTotalRiskPercent;

   if(hardTotal < 0.0)
      hardTotal = 0.0;

   if(hardTotal > ICT_MAX_TOTAL_RISK_PERCENT)
      hardTotal = ICT_MAX_TOTAL_RISK_PERCENT;

   double maxTotal =
      equity * hardTotal / 100.0;

   if((currentRisk + tradeRisk) >
      maxTotal + 0.000001)
      return false;

   return true;
}

//====================================================================
// DEBUG
//====================================================================

void RE_PrintSummary(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entryPrice,
   const double stopLossPrice,
   const double volume
)
{
   double equity = RE_GetEquity();

   double risk =
      RE_PositionRiskMoney(
         symbol,
         orderType,
         volume,
         entryPrice,
         stopLossPrice
      );

   double pct =
      (equity > 0.0)
      ? risk / equity * 100.0
      : 0.0;

   double openRisk =
      RE_GetOpenRiskMoney();

   Print(
      "[RISK] Equity=",
      DoubleToString(equity,2),
      " | TradeRisk=",
      DoubleToString(risk,2),
      " (",
      DoubleToString(pct,2),
      "%)",
      " | Lots=",
      DoubleToString(volume,2),
      " | OpenRisk=",
      DoubleToString(openRisk,2),
      " | OpenRisk%=",
      DoubleToString(
         RE_GetOpenRiskPercent(),
         2
      )
   );
}

#endif
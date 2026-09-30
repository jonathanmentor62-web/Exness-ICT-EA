//+------------------------------------------------------------------+
//| RiskEngine.mqh                                                   |
//| Equity-based position sizing for Exness ICT EA                   |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_RISK_ENGINE_MQH__
#define __EXNESS_ICT_RISK_ENGINE_MQH__

#include "Config.mqh"

//====================================================================
// BASIC ACCOUNT FUNCTIONS
//====================================================================

// Return current account equity.
double RE_GetEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

// Return current account balance.
double RE_GetBalance()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//====================================================================
// RISK MONEY
//====================================================================

// Calculate the maximum money allowed to be risked on one trade.
double RE_CalculateRiskMoney()
{
   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   double riskPercent = ICT_RISK_PERCENT;

   // Hard safety clamp.
   if(riskPercent < 0.0)
      riskPercent = 0.0;

   if(riskPercent > ICT_MAX_RISK_PERCENT)
      riskPercent = ICT_MAX_RISK_PERCENT;

   return equity * (riskPercent / 100.0);
}

//====================================================================
// MONEY RISK FOR ONE LOT
//====================================================================

// Calculate approximate money lost for one lot if SL is hit.
double RE_CalculateMoneyRiskPerLot(
   string symbol,
   double entryPrice,
   double stopLossPrice
)
{
   if(symbol == "")
      return 0.0;

   if(entryPrice <= 0.0 || stopLossPrice <= 0.0)
      return 0.0;

   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   double priceDistance = MathAbs(entryPrice - stopLossPrice);

   if(priceDistance <= 0.0)
      return 0.0;

   double numberOfTicks = priceDistance / tickSize;

   return numberOfTicks * tickValue;
}

//====================================================================
// RAW LOT CALCULATION
//====================================================================

// Calculate lot size from:
// equity -> risk percentage -> SL distance.
double RE_CalculateRawLotSize(
   string symbol,
   double entryPrice,
   double stopLossPrice
)
{
   double riskMoney = RE_CalculateRiskMoney();

   if(riskMoney <= 0.0)
      return 0.0;

   double riskPerLot = RE_CalculateMoneyRiskPerLot(
      symbol,
      entryPrice,
      stopLossPrice
   );

   if(riskPerLot <= 0.0)
      return 0.0;

   return riskMoney / riskPerLot;
}

//====================================================================
// LOT NORMALIZATION
//====================================================================

double RE_NormalizeLotSize(
   string symbol,
   double rawLots
)
{
   if(symbol == "" || rawLots <= 0.0)
      return 0.0;

   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0 || maxLot <= 0.0 || lotStep <= 0.0)
      return 0.0;

   // Never exceed broker maximum.
   double lots = MathMin(rawLots, maxLot);

   // Normalize DOWN to the broker's volume step.
   lots = MathFloor(lots / lotStep) * lotStep;

   // If the calculated amount is below the broker minimum,
   // do NOT increase it automatically because that would increase risk.
   if(lots < minLot)
      return 0.0;

   int volumeDigits = 2;

   if(lotStep >= 1.0)
      volumeDigits = 0;
   else if(lotStep >= 0.1)
      volumeDigits = 1;
   else if(lotStep >= 0.01)
      volumeDigits = 2;
   else
      volumeDigits = 3;

   return NormalizeDouble(lots, volumeDigits);
}

//====================================================================
// FINAL LOT CALCULATION
//====================================================================

double RE_CalculateLotSize(
   string symbol,
   double entryPrice,
   double stopLossPrice
)
{
   double rawLots = RE_CalculateRawLotSize(
      symbol,
      entryPrice,
      stopLossPrice
   );

   if(rawLots <= 0.0)
      return 0.0;

   return RE_NormalizeLotSize(
      symbol,
      rawLots
   );
}

//====================================================================
// CALCULATED RISK FOR A POSITION
//====================================================================

double RE_CalculatePositionRiskMoney(
   string symbol,
   double volume,
   double entryPrice,
   double stopLossPrice
)
{
   if(volume <= 0.0)
      return 0.0;

   double riskPerLot = RE_CalculateMoneyRiskPerLot(
      symbol,
      entryPrice,
      stopLossPrice
   );

   if(riskPerLot <= 0.0)
      return 0.0;

   return riskPerLot * volume;
}

//====================================================================
// TOTAL OPEN RISK
//====================================================================

// Calculate the risk represented by currently open EA positions.
//
// Important:
// Only positions belonging to this EA's magic number are counted.
double RE_GetTotalOpenRiskMoney()
{
   double totalRisk = 0.0;

   int totalPositions = PositionsTotal();

   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      long magic = PositionGetInteger(POSITION_MAGIC);

      if(magic != ICT_MAGIC_NUMBER)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);

      double volume = PositionGetDouble(POSITION_VOLUME);
      double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl     = PositionGetDouble(POSITION_SL);

      // A position without an SL cannot be treated as safely
      // risk-controlled by this engine.
      if(sl <= 0.0)
         continue;

      totalRisk += RE_CalculatePositionRiskMoney(
         symbol,
         volume,
         entry,
         sl
      );
   }

   return totalRisk;
}

//====================================================================
// TOTAL OPEN RISK PERCENT
//====================================================================

double RE_GetTotalOpenRiskPercent()
{
   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return 0.0;

   double totalRiskMoney = RE_GetTotalOpenRiskMoney();

   return (totalRiskMoney / equity) * 100.0;
}

//====================================================================
// NEW TRADE RISK VALIDATION
//====================================================================

bool RE_CanAcceptNewRisk(
   string symbol,
   double entryPrice,
   double stopLossPrice,
   double lots
)
{
   if(symbol == "")
      return false;

   if(entryPrice <= 0.0 || stopLossPrice <= 0.0)
      return false;

   if(lots <= 0.0)
      return false;

   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return false;

   double newTradeRisk = RE_CalculatePositionRiskMoney(
      symbol,
      lots,
      entryPrice,
      stopLossPrice
   );

   if(newTradeRisk <= 0.0)
      return false;

   double currentRisk = RE_GetTotalOpenRiskMoney();

   double maximumTotalRisk =
      equity * (ICT_MAX_TOTAL_RISK_PERCENT / 100.0);

   if((currentRisk + newTradeRisk) > maximumTotalRisk)
      return false;

   return true;
}

//====================================================================
// COMPLETE RISK CHECK
//====================================================================

bool RE_ValidateTradeRisk(
   string symbol,
   double entryPrice,
   double stopLossPrice,
   double lots
)
{
   if(symbol == "")
      return false;

   if(entryPrice <= 0.0)
      return false;

   if(stopLossPrice <= 0.0)
      return false;

   if(lots <= 0.0)
      return false;

   double equity = RE_GetEquity();

   if(equity <= 0.0)
      return false;

   // Calculate actual risk.
   double tradeRiskMoney =
      RE_CalculatePositionRiskMoney(
         symbol,
         lots,
         entryPrice,
         stopLossPrice
      );

   if(tradeRiskMoney <= 0.0)
      return false;

   double tradeRiskPercent =
      (tradeRiskMoney / equity) * 100.0;

   // Per-trade hard limit.
   if(tradeRiskPercent > ICT_MAX_RISK_PERCENT)
      return false;

   // Portfolio limit.
   if(!RE_CanAcceptNewRisk(
      symbol,
      entryPrice,
      stopLossPrice,
      lots
   ))
      return false;

   return true;
}

//====================================================================
// DEBUG / INFORMATION
//====================================================================

void RE_PrintRiskSummary(
   string symbol,
   double entryPrice,
   double stopLossPrice,
   double lots
)
{
   double equity = RE_GetEquity();

   double riskMoney =
      RE_CalculatePositionRiskMoney(
         symbol,
         lots,
         entryPrice,
         stopLossPrice
      );

   double riskPercent = 0.0;

   if(equity > 0.0)
      riskPercent = (riskMoney / equity) * 100.0;

   double totalRiskMoney =
      RE_GetTotalOpenRiskMoney();

   double totalRiskPercent =
      RE_GetTotalOpenRiskPercent();

   Print(
      "[RISK] Equity=",
      DoubleToString(equity, 2),
      " | TradeRisk=",
      DoubleToString(riskMoney, 2),
      " (",
      DoubleToString(riskPercent, 2),
      "%)",
      " | Lots=",
      DoubleToString(lots, 2),
      " | TotalOpenRisk=",
      DoubleToString(totalRiskMoney, 2),
      " (",
      DoubleToString(totalRiskPercent, 2),
      "%)"
   );
}

#endif
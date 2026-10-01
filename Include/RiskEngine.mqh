//+------------------------------------------------------------------+
//| RiskEngine.mqh                                                   |
//| Dynamic equity-based risk and position sizing                    |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_RISK_ENGINE_MQH__
#define __EXNESS_ICT_RISK_ENGINE_MQH__

#include "Config.mqh"


//==================================================================
// ACCOUNT EQUITY
//==================================================================

double RE_GetEquity()
{
   return AccountInfoDouble(
      ACCOUNT_EQUITY
   );
}


//==================================================================
// EFFECTIVE RISK PERCENT
//==================================================================
//
// The configured risk is limited by the EA's hard maximum.
// A zero or negative value disables new risk.
//
//==================================================================

double RE_GetRiskPercent(
   const double configuredRiskPercent
)
{
   double riskPercent=
      configuredRiskPercent;


   if(riskPercent<0.0)
      riskPercent=0.0;


   if(
      riskPercent>
      ICT_MAX_RISK_PERCENT
   )
   {
      riskPercent=
         ICT_MAX_RISK_PERCENT;
   }


   return riskPercent;
}


//==================================================================
// RISK MONEY
//==================================================================
//
// Converts percentage risk into account-currency money.
//
// Example:
// Equity = $100
// Risk   = 1%
// Risk money = $1
//
//==================================================================

double RE_GetRiskMoney(
   const double configuredRiskPercent
)
{
   double equity=
      RE_GetEquity();


   if(equity<=0.0)
      return 0.0;


   double riskPercent=
      RE_GetRiskPercent(
         configuredRiskPercent
      );


   if(riskPercent<=0.0)
      return 0.0;


   return(
      equity*
      riskPercent/
      100.0
   );
}


//==================================================================
// RISK PER LOT
//==================================================================
//
// Calculates how much one full lot would lose if price travels
// from entry to structural stop-loss.
//
// OrderCalcProfit() automatically accounts for the symbol's
// contract specification, tick value and tick size.
//
//==================================================================

double RE_CalculateRiskPerLot(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss
)
{
   if(symbol=="")
      return 0.0;


   if(entry<=0.0)
      return 0.0;


   if(stopLoss<=0.0)
      return 0.0;


   if(
      orderType!=ORDER_TYPE_BUY &&
      orderType!=ORDER_TYPE_SELL
   )
   {
      return 0.0;
   }


   double profit=0.0;


   if(
      !OrderCalcProfit(
         orderType,
         symbol,
         1.0,
         entry,
         stopLoss,
         profit
      )
   )
   {
      return 0.0;
   }


   double risk=
      MathAbs(
         profit
      );


   return risk;
}


//==================================================================
// NORMALIZE LOTS
//==================================================================
//
// Normalizes volume to the broker's allowed minimum, maximum and
// volume step.
//
// IMPORTANT:
// This function never increases volume above the requested risk
// when reducing to a broker volume step is necessary.
//
//==================================================================

double RE_NormalizeLots(
   const string symbol,
   const double requestedLots
)
{
   if(symbol=="")
      return 0.0;


   if(requestedLots<=0.0)
      return 0.0;


   double minLot=
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN
      );


   double maxLot=
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX
      );


   double step=
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );


   if(
      minLot<=0.0 ||
      maxLot<=0.0 ||
      step<=0.0
   )
   {
      return 0.0;
   }


   double lots=
      requestedLots;


   //---------------------------------------------------------------
   // Broker maximum
   //---------------------------------------------------------------

   if(lots>maxLot)
      lots=maxLot;


   //---------------------------------------------------------------
   // Normalize DOWN to volume step.
   //
   // This is important for risk protection. Rounding upward could
   // increase the calculated risk above the intended amount.
   //---------------------------------------------------------------

   lots=
      MathFloor(
         (
            lots+
            1e-12
         )/
         step
      )*
      step;


   //---------------------------------------------------------------
   // Broker minimum
   //---------------------------------------------------------------

   if(lots<minLot)
      return 0.0;


   //---------------------------------------------------------------
   // Determine volume precision from the step
   //---------------------------------------------------------------

   int volumeDigits=0;

   double tempStep=
      step;


   while(
      volumeDigits<8 &&
      MathAbs(
         tempStep-
         MathRound(tempStep)
      )>
      1e-9
   )
   {
      tempStep*=10.0;
      volumeDigits++;
   }


   lots=
      NormalizeDouble(
         lots,
         volumeDigits
      );


   //---------------------------------------------------------------
   // Final broker-bound checks
   //---------------------------------------------------------------

   if(lots<minLot)
      return 0.0;


   if(lots>maxLot)
      lots=maxLot;


   return lots;
}


//==================================================================
// RAW RISK-BASED LOT SIZE
//==================================================================
//
// Formula:
//
//     Risk Money
// ----------------------
// Risk Money Per 1 Lot
//
// The stop-loss distance is therefore structural rather than a
// fixed dollar stop.
//
//==================================================================

double RE_CalculateRawLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double riskPercent
)
{
   double riskMoney=
      RE_GetRiskMoney(
         riskPercent
      );


   if(riskMoney<=0.0)
      return 0.0;


   double riskPerLot=
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entry,
         stopLoss
      );


   if(riskPerLot<=0.0)
      return 0.0;


   double rawLots=
      riskMoney/
      riskPerLot;


   if(rawLots<=0.0)
      return 0.0;


   return rawLots;
}


//==================================================================
// RISK-BASED LOT SIZE
//==================================================================

double RE_CalculateLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double riskPercent
)
{
   double rawLots=
      RE_CalculateRawLots(
         symbol,
         orderType,
         entry,
         stopLoss,
         riskPercent
      );


   if(rawLots<=0.0)
      return 0.0;


   return RE_NormalizeLots(
      symbol,
      rawLots
   );
}


//==================================================================
// COMPOUNDING LOT SIZE
//==================================================================
//
// The EA has a desired equity-to-lot relationship:
//
//     $5 equity -> target 0.03 lots
//
// BUT 0.03 is NOT forced.
//
// The actual lot is limited by:
//
// 1. Account equity
// 2. Configured percentage risk
// 3. Structural stop-loss distance
// 4. Broker minimum
// 5. Broker maximum
// 6. Broker volume step
//
// Therefore the risk engine always has final authority over the
// requested compounding lot.
//
//==================================================================

double RE_CalculateCompoundingLots(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entry,
   const double stopLoss,
   const double riskPercent
)
{
   //---------------------------------------------------------------
   // Risk-safe lot
   //---------------------------------------------------------------

   double riskLots=
      RE_CalculateLots(
         symbol,
         orderType,
         entry,
         stopLoss,
         riskPercent
      );


   if(riskLots<=0.0)
      return 0.0;


   //---------------------------------------------------------------
   // Current equity
   //---------------------------------------------------------------

   double equity=
      RE_GetEquity();


   if(equity<=0.0)
      return 0.0;


   //---------------------------------------------------------------
   // Target compounding relationship
   //---------------------------------------------------------------

   if(
      ICT_TARGET_EQUITY_FOR_LOT<=0.0 ||
      ICT_TARGET_LOTS_AT_EQUITY<=0.0
   )
   {
      return riskLots;
   }


   double desiredLots=
      ICT_TARGET_LOTS_AT_EQUITY*
      (
         equity/
         ICT_TARGET_EQUITY_FOR_LOT
      );


   if(desiredLots<=0.0)
      return 0.0;


   //---------------------------------------------------------------
   // Never allow the desired compounding target to exceed the
   // independently calculated risk-safe lot.
   //---------------------------------------------------------------

   double finalLots=
      MathMin(
         riskLots,
         desiredLots
      );


   //---------------------------------------------------------------
   // Normalize again after the compounding cap.
   //---------------------------------------------------------------

   finalLots=
      RE_NormalizeLots(
         symbol,
         finalLots
      );


   return finalLots;
}


//==================================================================
// POSITION RISK MONEY
//==================================================================
//
// Calculates current monetary risk for an existing position using
// its current SL.
//
// If the position has no SL, risk cannot be calculated reliably,
// therefore this function returns 0.
//
//==================================================================

double RE_PositionRiskMoney(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double volume,
   const double entry,
   const double stopLoss
)
{
   if(symbol=="")
      return 0.0;


   if(volume<=0.0)
      return 0.0;


   if(entry<=0.0)
      return 0.0;


   if(stopLoss<=0.0)
      return 0.0;


   double riskPerLot=
      RE_CalculateRiskPerLot(
         symbol,
         orderType,
         entry,
         stopLoss
      );


   if(riskPerLot<=0.0)
      return 0.0;


   return(
      riskPerLot*
      volume
   );
}


//==================================================================
// OPEN POSITION RISK
//==================================================================
//
// Calculates the combined known SL risk of all EA positions.
//
// Positions belonging to other EAs/manual trades are ignored by
// magic number.
//
//==================================================================

double RE_GetOpenRiskMoney()
{
   double totalRisk=0.0;


   int totalPositions=
      PositionsTotal();


   for(
      int i=0;
      i<totalPositions;
      i++
   )
   {
      ulong ticket=
         PositionGetTicket(
            i
         );


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


      //-------------------------------------------------------------
      // Only this EA's positions
      //-------------------------------------------------------------

      long magic=
         PositionGetInteger(
            POSITION_MAGIC
         );


      if(
         (ulong)magic!=
         (ulong)ICT_MAGIC_NUMBER
      )
      {
         continue;
      }


      //-------------------------------------------------------------
      // Position data
      //-------------------------------------------------------------

      string symbol=
         PositionGetString(
            POSITION_SYMBOL
         );


      ENUM_POSITION_TYPE positionType=
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         );


      double volume=
         PositionGetDouble(
            POSITION_VOLUME
         );


      double entry=
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );


      double stopLoss=
         PositionGetDouble(
            POSITION_SL
         );


      //-------------------------------------------------------------
      // A position without an SL has no safely measurable
      // structural risk here.
      //
      // The execution layer should normally reject such trades.
      //-------------------------------------------------------------

      if(stopLoss<=0.0)
         continue;


      ENUM_ORDER_TYPE orderType;


      if(
         positionType==
         POSITION_TYPE_BUY
      )
      {
         orderType=
            ORDER_TYPE_BUY;
      }
      else if(
         positionType==
         POSITION_TYPE_SELL
      )
      {
         orderType=
            ORDER_TYPE_SELL;
      }
      else
      {
         continue;
      }


      double positionRisk=
         RE_PositionRiskMoney(
            symbol,
            orderType,
            volume,
            entry,
            stopLoss
         );


      if(positionRisk>0.0)
      {
         totalRisk+=
            positionRisk;
      }
   }


   return totalRisk;
}


//==================================================================
// OPEN RISK PERCENT
//==================================================================

double RE_GetOpenRiskPercent()
{
   double equity=
      RE_GetEquity();


   if(equity<=0.0)
      return 0.0;


   double openRisk=
      RE_GetOpenRiskMoney();


   if(openRisk<=0.0)
      return 0.0;


   return(
      openRisk/
      equity*
      100.0
   );
}


//==================================================================
// VALIDATE NEW TRADE
//==================================================================
//
// Performs two independent risk checks:
//
// 1. New trade must stay within the configured per-trade risk.
// 2. New trade plus existing open risk must stay within the
//    combined portfolio risk limit.
//
//==================================================================

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
   if(symbol=="")
      return false;


   if(volume<=0.0)
      return false;


   if(entry<=0.0)
      return false;


   if(stopLoss<=0.0)
      return false;


   //---------------------------------------------------------------
   // Effective per-trade risk
   //---------------------------------------------------------------

   double effectiveRiskPercent=
      RE_GetRiskPercent(
         riskPercent
      );


   if(effectiveRiskPercent<=0.0)
      return false;


   //---------------------------------------------------------------
   // Maximum combined risk
   //---------------------------------------------------------------

   double totalRiskLimitPercent=
      maxTotalRiskPercent;


   if(totalRiskLimitPercent<=0.0)
      return false;


   if(
      totalRiskLimitPercent<
      effectiveRiskPercent
   )
   {
      // The total-risk limit can never be below the risk of the
      // individual trade being requested.
      return false;
   }


   //---------------------------------------------------------------
   // Account equity
   //---------------------------------------------------------------

   double equity=
      RE_GetEquity();


   if(equity<=0.0)
      return false;


   //---------------------------------------------------------------
   // Risk of requested position
   //---------------------------------------------------------------

   double newTradeRisk=
      RE_PositionRiskMoney(
         symbol,
         orderType,
         volume,
         entry,
         stopLoss
      );


   if(newTradeRisk<=0.0)
      return false;


   //---------------------------------------------------------------
   // Per-trade risk limit
   //---------------------------------------------------------------

   double maxTradeRiskMoney=
      equity*
      effectiveRiskPercent/
      100.0;


   if(
      newTradeRisk>
      maxTradeRiskMoney+
      1e-8
   )
   {
      return false;
   }


   //---------------------------------------------------------------
   // Existing open risk
   //---------------------------------------------------------------

   double existingRisk=
      RE_GetOpenRiskMoney();


   //---------------------------------------------------------------
   // Maximum total risk
   //---------------------------------------------------------------

   double maxTotalRiskMoney=
      equity*
      totalRiskLimitPercent/
      100.0;


   double combinedRisk=
      existingRisk+
      newTradeRisk;


   if(
      combinedRisk>
      maxTotalRiskMoney+
      1e-8
   )
   {
      return false;
   }


   return true;
}


//==================================================================
// RISK SUMMARY
//==================================================================

void RE_PrintSummary()
{
   double equity=
      RE_GetEquity();


   double openRiskMoney=
      RE_GetOpenRiskMoney();


   double openRiskPercent=
      RE_GetOpenRiskPercent();


   Print(
      "RiskEngine | Equity=",
      DoubleToString(
         equity,
         2
      ),
      " | OpenRisk=",
      DoubleToString(
         openRiskMoney,
         2
      ),
      " | OpenRisk%=",
      DoubleToString(
         openRiskPercent,
         2
      ),
      "%"
   );
}


#endif
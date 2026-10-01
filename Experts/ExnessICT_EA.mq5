//+------------------------------------------------------------------+
//| ExnessICT_EA.mq5                                                 |
//| Exness ICT EA - Main Controller                                  |
//|                                                                  |
//| NORMAL:  H4 -> M15 -> M5 ICT pipeline                            |
//| SCALPER: M1 reactive momentum engine                             |
//| AUTO:    H4 -> M15 -> M5 + M1 scalper                           |
//|                                                                  |
//| Trading is DISABLED by default during development.               |
//+------------------------------------------------------------------+
#property strict
#property version   "0.90"

#property description "Exness ICT EA"
#property description "H4 -> M15 -> M5 ICT structure pipeline"
#property description "Reactive M1 momentum scalper"
#property description "Dynamic equity-based risk engine"
#property description "Trading disabled by default during development"


//==================================================================
// STANDARD MT5
//==================================================================

#include <Trade/Trade.mqh>


//==================================================================
// PROJECT MODULES
//==================================================================

#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/StructureSignal.mqh"
#include "../Include/Liquidity.mqh"
#include "../Include/FVG.mqh"
#include "../Include/OrderBlock.mqh"
#include "../Include/M5Confirmation.mqh"
#include "../Include/RiskEngine.mqh"
#include "../Include/M1Scalper.mqh"
#include "../Include/ExecutionEngine.mqh"
#include "../Include/TradeEngine.mqh"


//==================================================================
// GLOBAL TRADE OBJECT
//==================================================================

CTrade Trade;


//==================================================================
// USER INPUTS
//==================================================================

//------------------------------------------------------------------
// Timeframes
//------------------------------------------------------------------

input ENUM_TIMEFRAMES InpPrimaryTF =
   ICT_PRIMARY_TF;

input ENUM_TIMEFRAMES InpConfirmTF =
   ICT_CONFIRM_TF;

input ENUM_TIMEFRAMES InpEntryTF =
   ICT_ENTRY_TF;


//------------------------------------------------------------------
// Risk
//------------------------------------------------------------------

input double InpRiskPercent =
   ICT_RISK_PERCENT;

input double InpMaxTotalRiskPct =
   ICT_MAX_TOTAL_RISK_PERCENT;


//------------------------------------------------------------------
// Execution
//------------------------------------------------------------------

input ulong InpMagicNumber =
   ICT_MAGIC_NUMBER;

input int InpMaxSpreadPts =
   ICT_MAX_SPREAD_PTS;

input int InpDeviationPts =
   ICT_MAX_SLIPPAGE_PTS;


//------------------------------------------------------------------
// MASTER TRADING SWITCH
//
// IMPORTANT:
// Keep false during development/testing.
//------------------------------------------------------------------

input bool InpEnableTrading =
   false;


//==================================================================
// TRADING MODE
//==================================================================

enum ENUM_EA_TRADING_MODE
{
   EA_MODE_NORMAL = 0,
   EA_MODE_SCALPER = 1,
   EA_MODE_AUTO = 2
};


input ENUM_EA_TRADING_MODE InpTradingMode =
   EA_MODE_SCALPER;


//==================================================================
// MARKET SCANNING
//==================================================================

input bool InpScanMarketWatchSymbols =
   true;


//==================================================================
// SCALPER INPUTS
//==================================================================

input double InpScalpMinScore =
   ICT_SCALP_MIN_SCORE;

input int InpScalpMaxHoldSeconds =
   ICT_SCALP_MAX_HOLD_SECONDS;

input int InpScalpCooldownSeconds =
   ICT_SCALP_COOLDOWN_SECONDS;

input int InpScalpMaxPositions =
   ICT_SCALP_MAX_POSITIONS;

input int InpScalpMaxSymbolPositions =
   ICT_SCALP_MAX_SYMBOL_POSITIONS;


//==================================================================
// DAILY PROTECTION
//==================================================================

input double InpDailyLossLimitPct =
   3.0;

input double InpDailyProfitTargetMoney =
   0.0;


//==================================================================
// STRUCTURE INPUTS
//==================================================================

input int InpStructureLookback =
   ICT_STRUCTURE_LOOKBACK;

input int InpFVGScanLookback =
   20;

input int InpOBScanLookback =
   ICT_OB_LOOKBACK;


//==================================================================
// MAIN STATE
//==================================================================

datetime g_lastPrimaryBar = 0;

datetime g_lastConfirmBar = 0;

datetime g_lastEntryBar = 0;


//------------------------------------------------------------------
// H4 setup state
//------------------------------------------------------------------

bool g_h4SetupActive =
   false;

ENUM_STRUCTURE_DIRECTION g_h4SetupDirection =
   STRUCTURE_UNKNOWN;

datetime g_h4SetupTime =
   0;

int g_h4SetupShift =
   -1;


//==================================================================
// DAILY STATE
//==================================================================

datetime g_dayStart =
   0;

double g_dayStartEquity =
   0.0;

bool g_dailyLocked =
   false;


//==================================================================
// TRADE ENGINE STATE
//==================================================================

TradeEngineState g_tradeEngine;


//==================================================================
// M15 CONFIRMATION STATE
//==================================================================

enum ENUM_CONFIRMATION_STATE
{
   CONFIRMATION_NONE = 0,
   CONFIRMATION_WAITING,
   CONFIRMATION_CONFIRMED,
   CONFIRMATION_INVALID
};


struct M15Confirmation
{
   bool confirmed;

   bool valid;

   ENUM_CONFIRMATION_STATE state;

   ENUM_STRUCTURE_DIRECTION direction;

   bool displacement;

   bool mss;

   bool bos;

   bool fvgPresent;

   bool orderBlockPresent;

   double brokenLevel;

   datetime confirmationTime;

   int confirmationShift;

   string reason;
};


M15Confirmation g_m15Confirmation;

M5Confirmation g_m5Confirmation;


//==================================================================
// RESET M15 CONFIRMATION
//==================================================================

void ResetM15Confirmation(
   M15Confirmation &c
)
{
   c.confirmed =
      false;

   c.valid =
      false;

   c.state =
      CONFIRMATION_NONE;

   c.direction =
      STRUCTURE_UNKNOWN;

   c.displacement =
      false;

   c.mss =
      false;

   c.bos =
      false;

   c.fvgPresent =
      false;

   c.orderBlockPresent =
      false;

   c.brokenLevel =
      0.0;

   c.confirmationTime =
      0;

   c.confirmationShift =
      -1;

   c.reason =
      "";
}


//==================================================================
// SYMBOL TRADABILITY
//==================================================================

bool IsSymbolTradable(
   const string symbol
)
{
   if(symbol=="")
      return(false);


   if(
      !SymbolSelect(
         symbol,
         true
      )
   )
   {
      return(false);
   }


   long mode=0;


   if(
      !SymbolInfoInteger(
         symbol,
         SYMBOL_TRADE_MODE,
         mode
      )
   )
   {
      return(false);
   }


   return(
      mode!=
      SYMBOL_TRADE_MODE_DISABLED
   );
}


//==================================================================
// SPREAD FILTER
//==================================================================

bool IsSpreadAcceptable(
   const string symbol
)
{
   long spread=0;


   if(
      !SymbolInfoInteger(
         symbol,
         SYMBOL_SPREAD,
         spread
      )
   )
   {
      return(false);
   }


   return(
      spread<=
      InpMaxSpreadPts
   );
}


//==================================================================
// DAY START
//==================================================================

datetime GetDayStart()
{
   MqlDateTime dt;


   TimeToStruct(
      TimeCurrent(),
      dt
   );


   dt.hour=0;

   dt.min=0;

   dt.sec=0;


   return(
      StructToTime(
         dt
      )
   );
}


//==================================================================
// DAILY STATE
//==================================================================

void UpdateDailyState()
{
   datetime today=
      GetDayStart();


   //---------------------------------------------------------------
   // New broker/server day
   //---------------------------------------------------------------

   if(
      g_dayStart!=
      today
   )
   {
      g_dayStart=
         today;

      g_dayStartEquity=
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );

      g_dailyLocked=
         false;


      Print(
         "[DAILY] New trading day | Start equity=",
         DoubleToString(
            g_dayStartEquity,
            2
         )
      );
   }


   //---------------------------------------------------------------
   // Safety initialization
   //---------------------------------------------------------------

   if(
      g_dayStartEquity<=0.0
   )
   {
      g_dayStartEquity=
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );
   }


   double equity=
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );


   if(equity<=0.0)
      return;


   //---------------------------------------------------------------
   // Daily change
   //---------------------------------------------------------------

   double dailyChangeMoney=
      equity-
      g_dayStartEquity;


   double dailyLossPct=
      0.0;


   if(
      g_dayStartEquity>0.0 &&
      dailyChangeMoney<0.0
   )
   {
      dailyLossPct=
         (
            -dailyChangeMoney/
            g_dayStartEquity
         )*
         100.0;
   }


   //---------------------------------------------------------------
   // Daily loss protection
   //---------------------------------------------------------------

   if(
      InpDailyLossLimitPct>0.0 &&
      dailyLossPct>=
      InpDailyLossLimitPct
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] Loss limit reached. ",
            "New entries locked."
         );
      }


      g_dailyLocked=
         true;
   }


   //---------------------------------------------------------------
   // Daily profit target
   //---------------------------------------------------------------

   if(
      InpDailyProfitTargetMoney>0.0 &&
      dailyChangeMoney>=
      InpDailyProfitTargetMoney
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] Profit target reached. ",
            "New entries locked."
         );
      }


      g_dailyLocked=
         true;
   }
}


//==================================================================
// DAILY ENTRY PERMISSION
//==================================================================

bool IsDailyTradingAllowed()
{
   UpdateDailyState();


   return(
      !g_dailyLocked
   );
}


//==================================================================
// DIRECTION AGREEMENT
//==================================================================

bool IsConfirmationDirectionValid(
   const ENUM_STRUCTURE_DIRECTION h4Direction,
   const ENUM_STRUCTURE_DIRECTION lowerDirection
)
{
   return(
      h4Direction!=
      STRUCTURE_UNKNOWN &&
      lowerDirection==
      h4Direction
   );
}


//==================================================================
// VALIDATE M15 CONFIRMATION
//==================================================================

bool ValidateM15Confirmation(
   const M15Confirmation &c,
   const ENUM_STRUCTURE_DIRECTION expectedDirection
)
{
   if(
      !c.valid ||
      !c.confirmed
   )
   {
      return(false);
   }


   if(
      !IsConfirmationDirectionValid(
         expectedDirection,
         c.direction
      )
   )
   {
      return(false);
   }


   if(!c.displacement)
      return(false);


   if(
      !c.mss &&
      !c.bos
   )
   {
      return(false);
   }


   if(
      ICT_REQUIRE_FVG &&
      !c.fvgPresent
   )
   {
      return(false);
   }


   if(
      c.confirmationTime<=0 ||
      c.confirmationShift<1
   )
   {
      return(false);
   }


   if(c.brokenLevel<=0.0)
      return(false);


   return(true);
}
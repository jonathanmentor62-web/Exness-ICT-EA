//+------------------------------------------------------------------+
//| ExnessICT_EA.mq5                                                 |
//| Exness ICT EA - development / analysis build                    |
//+------------------------------------------------------------------+
#property strict
#property version   "0.60"
#property description "H4 ICT framework with M15 and M5 confirmation."
#property description "Equity-based risk engine and daily protection."
#property description "Trading disabled during development."

#include <Trade/Trade.mqh>

#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/StructureSignal.mqh"
#include "../Include/Liquidity.mqh"
#include "../Include/FVG.mqh"
#include "../Include/OrderBlock.mqh"
#include "../Include/M5Confirmation.mqh"
#include "../Include/RiskEngine.mqh"

CTrade Trade;

//====================================================================
// INPUTS
//====================================================================

input ENUM_TIMEFRAMES InpPrimaryTF =
   ICT_PRIMARY_TF;

input ENUM_TIMEFRAMES InpConfirmTF =
   ICT_CONFIRM_TF;

input ENUM_TIMEFRAMES InpEntryTF =
   ICT_ENTRY_TF;

//--------------------------------------------------------------------
// Risk
//--------------------------------------------------------------------

input double InpRiskPercent =
   ICT_RISK_PERCENT;

input double InpMaxTotalRiskPct =
   ICT_MAX_TOTAL_RISK_PERCENT;

//--------------------------------------------------------------------
// Execution
//--------------------------------------------------------------------

input ulong InpMagicNumber =
   ICT_MAGIC_NUMBER;

input int InpMaxSpreadPts =
   ICT_MAX_SPREAD_PTS;

input int InpDeviationPts =
   ICT_MAX_SLIPPAGE_PTS;

//--------------------------------------------------------------------
// Trading
//--------------------------------------------------------------------

input bool InpEnableTrading = false;

//--------------------------------------------------------------------
// Daily protection
//--------------------------------------------------------------------

input double InpDailyLossLimitPct = 3.0;

// Set to 0 to disable daily profit lock.
input double InpDailyProfitTargetMoney = 0.0;

//--------------------------------------------------------------------
// Analysis
//--------------------------------------------------------------------

input int InpStructureLookback =
   ICT_STRUCTURE_LOOKBACK;

input int InpFVGScanLookback = 20;

input int InpOBScanLookback =
   ICT_OB_LOOKBACK;

//====================================================================
// GLOBAL STATE
//====================================================================

datetime g_lastPrimaryBar = 0;
datetime g_lastConfirmBar = 0;
datetime g_lastEntryBar = 0;

bool g_h4SetupActive = false;

ENUM_STRUCTURE_DIRECTION
   g_h4SetupDirection =
   STRUCTURE_UNKNOWN;

datetime g_h4SetupTime = 0;

int g_h4SetupShift = -1;

//====================================================================
// DAILY STATE
//====================================================================

datetime g_dayStart = 0;

double g_dayStartEquity = 0.0;

bool g_dailyLocked = false;

//====================================================================
// CONFIRMATION STATE
//====================================================================

enum ENUM_CONFIRMATION_STATE
{
   CONFIRMATION_NONE = 0,
   CONFIRMATION_WAITING,
   CONFIRMATION_CONFIRMED,
   CONFIRMATION_INVALID
};

//====================================================================
// M15 STRUCT
//====================================================================

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

//====================================================================
// GLOBAL CONFIRMATIONS
//====================================================================

M15Confirmation g_m15Confirmation;

M5Confirmation g_m5Confirmation;

//====================================================================
// RESET M15
//====================================================================

void ResetM15Confirmation(
   M15Confirmation &c
)
{
   c.confirmed = false;
   c.valid = false;

   c.state =
      CONFIRMATION_NONE;

   c.direction =
      STRUCTURE_UNKNOWN;

   c.displacement = false;
   c.mss = false;
   c.bos = false;

   c.fvgPresent = false;
   c.orderBlockPresent = false;

   c.brokenLevel = 0.0;

   c.confirmationTime = 0;

   c.confirmationShift = -1;

   c.reason = "";
}

//====================================================================
// SYMBOL CHECK
//====================================================================

bool IsSymbolTradable(
   const string symbol
)
{
   if(symbol == "")
      return false;

   if(!SymbolSelect(
      symbol,
      true
   ))
      return false;

   long mode = 0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_MODE,
      mode
   ))
      return false;

   return(
      mode != SYMBOL_TRADE_MODE_DISABLED
   );
}

//====================================================================
// SPREAD CHECK
//====================================================================

bool IsSpreadAcceptable(
   const string symbol
)
{
   long spread = 0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_SPREAD,
      spread
   ))
      return false;

   return(
      spread <= InpMaxSpreadPts
   );
}

//====================================================================
// DAY START
//====================================================================

datetime GetDayStart()
{
   MqlDateTime dt;

   TimeToStruct(
      TimeCurrent(),
      dt
   );

   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   return StructToTime(dt);
}

//====================================================================
// DAILY STATE
//====================================================================

void UpdateDailyState()
{
   datetime today =
      GetDayStart();

   if(g_dayStart != today)
   {
      g_dayStart = today;

      g_dayStartEquity =
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );

      g_dailyLocked = false;

      Print(
         "[DAILY] New trading day. "
         "Start equity=",
         DoubleToString(
            g_dayStartEquity,
            2
         )
      );
   }

   if(g_dayStartEquity <= 0.0)
   {
      g_dayStartEquity =
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );
   }

   double equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   if(equity <= 0.0)
      return;

   double dailyChangeMoney =
      equity - g_dayStartEquity;

   double dailyLossPct = 0.0;

   if(
      g_dayStartEquity > 0.0 &&
      dailyChangeMoney < 0.0
   )
   {
      dailyLossPct =
         (
            -dailyChangeMoney /
            g_dayStartEquity
         ) * 100.0;
   }

   //---------------------------------------------------------------
   // DAILY LOSS LOCK
   //---------------------------------------------------------------

   if(
      InpDailyLossLimitPct > 0.0 &&
      dailyLossPct >=
      InpDailyLossLimitPct
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] "
            "Daily loss limit reached. "
            "New entries locked."
         );
      }

      g_dailyLocked = true;
   }

   //---------------------------------------------------------------
   // DAILY PROFIT LOCK
   //---------------------------------------------------------------

   if(
      InpDailyProfitTargetMoney > 0.0 &&
      dailyChangeMoney >=
      InpDailyProfitTargetMoney
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] "
            "Daily profit target reached. "
            "New entries locked."
         );
      }

      g_dailyLocked = true;
   }
}

//====================================================================
// DAILY PERMISSION
//====================================================================

bool IsDailyTradingAllowed()
{
   UpdateDailyState();

   return(!g_dailyLocked);
}

//====================================================================
// DIRECTION AGREEMENT
//====================================================================

bool IsConfirmationDirectionValid(
   const ENUM_STRUCTURE_DIRECTION h4Direction,
   const ENUM_STRUCTURE_DIRECTION lowerDirection
)
{
   if(
      h4Direction ==
      STRUCTURE_UNKNOWN
   )
      return false;

   return(
      lowerDirection ==
      h4Direction
   );
}

//====================================================================
// VALIDATE M15
//====================================================================

bool ValidateM15Confirmation(
   const M15Confirmation &c,
   const ENUM_STRUCTURE_DIRECTION expectedDirection
)
{
   if(!c.valid)
      return false;

   if(!c.confirmed)
      return false;

   if(
      !IsConfirmationDirectionValid(
         expectedDirection,
         c.direction
      )
   )
      return false;

   if(!c.displacement)
      return false;

   if(!c.mss && !c.bos)
      return false;

   if(
      ICT_REQUIRE_FVG &&
      !c.fvgPresent
   )
      return false;

   if(c.confirmationTime <= 0)
      return false;

   if(c.confirmationShift < 1)
      return false;

   if(c.brokenLevel <= 0.0)
      return false;

   return true;
}

//====================================================================
// ANALYZE M15
//====================================================================

M15Confirmation AnalyzeM15Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection
)
{
   M15Confirmation c;

   ResetM15Confirmation(c);

   if(!IsSymbolTradable(symbol))
   {
      c.state =
         CONFIRMATION_INVALID;

      c.reason =
         "Symbol is not tradable.";

      return c;
   }

   if(
      expectedDirection ==
      STRUCTURE_UNKNOWN
   )
   {
      c.state =
         CONFIRMATION_INVALID;

      c.reason =
         "H4 direction is unknown.";

      return c;
   }

   if(
      Bars(
         symbol,
         InpConfirmTF
      ) < ICT_MIN_HISTORY_BARS
   )
   {
      c.state =
         CONFIRMATION_INVALID;

      c.reason =
         "Insufficient M15 history.";

      return c;
   }

   const int signalShift = 1;

   c.confirmationShift =
      signalShift;

   c.confirmationTime =
      iTime(
         symbol,
         InpConfirmTF,
         signalShift
      );

   if(c.confirmationTime <= 0)
   {
      c.state =
         CONFIRMATION_INVALID;

      c.reason =
         "Invalid M15 candle time.";

      return c;
   }

   //---------------------------------------------------------------
   // STRUCTURE
   //---------------------------------------------------------------

   StructureSignal signal =
      AnalyzeStructureSignal(
         symbol,
         InpConfirmTF,
         signalShift,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   if(!signal.valid)
   {
      c.state =
         CONFIRMATION_WAITING;

      c.reason =
         "No M15 MSS/BOS detected.";

      return c;
   }

   c.direction =
      GetSignalDirection(signal);

   c.displacement =
      signal.bullishDisplacement ||
      signal.bearishDisplacement;

   c.mss =
      signal.bullishMSS ||
      signal.bearishMSS;

   c.bos =
      signal.bullishBOS ||
      signal.bearishBOS;

   c.brokenLevel =
      signal.brokenLevel;

   //---------------------------------------------------------------
   // DIRECTION
   //---------------------------------------------------------------

   if(
      c.direction !=
      expectedDirection
   )
   {
      c.state =
         CONFIRMATION_WAITING;

      c.reason =
         "M15 direction disagrees with H4.";

      return c;
   }

   //---------------------------------------------------------------
   // DIRECTIONAL DISPLACEMENT
   //---------------------------------------------------------------

   if(
      expectedDirection ==
      STRUCTURE_BULLISH &&
      !signal.bullishDisplacement
   )
   {
      c.state =
         CONFIRMATION_WAITING;

      c.reason =
         "M15 bullish displacement missing.";

      return c;
   }

   if(
      expectedDirection ==
      STRUCTURE_BEARISH &&
      !signal.bearishDisplacement
   )
   {
      c.state =
         CONFIRMATION_WAITING;

      c.reason =
         "M15 bearish displacement missing.";

      return c;
   }

   //---------------------------------------------------------------
   // FVG
   //---------------------------------------------------------------

   FVGZone fvg;

   ResetFVG(fvg);

   if(
      DetectFVG(
         symbol,
         InpConfirmTF,
         signalShift,
         fvg
      )
   )
   {
      if(
         expectedDirection ==
         STRUCTURE_BULLISH &&
         fvg.direction ==
         FVG_BULLISH
      )
      {
         c.fvgPresent = true;
      }

      if(
         expectedDirection ==
         STRUCTURE_BEARISH &&
         fvg.direction ==
         FVG_BEARISH
      )
      {
         c.fvgPresent = true;
      }
   }

   //---------------------------------------------------------------
   // ORDER BLOCK
   //---------------------------------------------------------------

   OrderBlock ob;

   ResetOrderBlock(ob);

   if(ICT_ENABLE_ORDER_BLOCK)
   {
      if(
         expectedDirection ==
         STRUCTURE_BULLISH
      )
      {
         c.orderBlockPresent =
            FindBullishOrderBlock(
               symbol,
               InpConfirmTF,
               signalShift,
               InpOBScanLookback,
               ob
            );
      }
      else if(
         expectedDirection ==
         STRUCTURE_BEARISH
      )
      {
         c.orderBlockPresent =
            FindBearishOrderBlock(
               symbol,
               InpConfirmTF,
               signalShift,
               InpOBScanLookback,
               ob
            );
      }
   }

   //---------------------------------------------------------------
   // REQUIRED FVG
   //---------------------------------------------------------------

   if(
      ICT_REQUIRE_FVG &&
      !c.fvgPresent
   )
   {
      c.state =
         CONFIRMATION_WAITING;

      c.reason =
         "Required directional M15 FVG missing.";

      return c;
   }

   //---------------------------------------------------------------
   // CONFIRMED
   //---------------------------------------------------------------

   c.confirmed = true;

   c.valid = true;

   c.state =
      CONFIRMATION_CONFIRMED;

   c.reason =
      "M15 displacement + structure + FVG confirmed.";

   return c;
}

//====================================================================
// PRINT M15
//====================================================================

void PrintM15Confirmation(
   const string symbol,
   const M15Confirmation &c
)
{
   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   Print(
      "[M15] state=",
      c.state,
      " | confirmed=",
      c.confirmed,
      " | direction=",
      StructureDirectionToString(
         c.direction
      ),
      " | displacement=",
      c.displacement,
      " | MSS=",
      c.mss,
      " | BOS=",
      c.bos,
      " | FVG=",
      c.fvgPresent,
      " | OB=",
      c.orderBlockPresent,
      " | broken=",
      DoubleToString(
         c.brokenLevel,
         digits
      ),
      " | reason=",
      c.reason
   );
}

//====================================================================
// PROCESS M15
//====================================================================

void ProcessM15Confirmation(
   const string symbol
)
{
   if(!g_h4SetupActive)
      return;

   datetime currentBar =
      iTime(
         symbol,
         InpConfirmTF,
         0
      );

   if(currentBar <= 0)
      return;

   if(
      currentBar ==
      g_lastConfirmBar
   )
      return;

   g_lastConfirmBar =
      currentBar;

   //---------------------------------------------------------------
   // H4 EXPIRATION
   //---------------------------------------------------------------

   int elapsedH4Bars =
      iBarShift(
         symbol,
         InpPrimaryTF,
         g_h4SetupTime,
         false
      );

   if(
      elapsedH4Bars < 0 ||
      elapsedH4Bars >
      ICT_SETUP_MAX_BARS
   )
   {
      g_h4SetupActive = false;

      g_h4SetupDirection =
         STRUCTURE_UNKNOWN;

      g_h4SetupTime = 0;

      g_h4SetupShift = -1;

      ResetM15Confirmation(
         g_m15Confirmation
      );

      ResetM5Confirmation(
         g_m5Confirmation
      );

      Print(
         "[H4 SETUP] "
         "Expired before M15 confirmation."
      );

      return;
   }

   //---------------------------------------------------------------
   // M15 EXPIRATION
   //---------------------------------------------------------------

   int elapsedM15Bars =
      iBarShift(
         symbol,
         InpConfirmTF,
         g_h4SetupTime,
         false
      );

   if(
      elapsedM15Bars < 0 ||
      elapsedM15Bars >
      ICT_M15_CONFIRM_MAX_BARS
   )
   {
      ResetM15Confirmation(
         g_m15Confirmation
      );

      ResetM5Confirmation(
         g_m5Confirmation
      );

      g_m15Confirmation.state =
         CONFIRMATION_INVALID;

      g_m15Confirmation.reason =
         "M15 confirmation window expired.";

      return;
   }

   //---------------------------------------------------------------
   // ANALYZE
   //---------------------------------------------------------------

   g_m15Confirmation =
      AnalyzeM15Confirmation(
         symbol,
         g_h4SetupDirection
      );

   PrintM15Confirmation(
      symbol,
      g_m15Confirmation
   );

   if(
      ValidateM15Confirmation(
         g_m15Confirmation,
         g_h4SetupDirection
      )
   )
   {
      Print(
         "[M15] CONFIRMED. "
         "Waiting for M5 entry confirmation."
      );
   }
}

//====================================================================
// PROCESS M5
//====================================================================

void ProcessM5Confirmation(
   const string symbol
)
{
   //---------------------------------------------------------------
   // M15 MUST BE CONFIRMED FIRST
   //---------------------------------------------------------------

   if(
      !ValidateM15Confirmation(
         g_m15Confirmation,
         g_h4SetupDirection
      )
   )
      return;

   datetime currentBar =
      iTime(
         symbol,
         InpEntryTF,
         0
      );

   if(currentBar <= 0)
      return;

   if(
      currentBar ==
      g_lastEntryBar
   )
      return;

   g_lastEntryBar =
      currentBar;

   //---------------------------------------------------------------
   // M5 WINDOW
   //---------------------------------------------------------------

   int elapsedM5Bars =
      iBarShift(
         symbol,
         InpEntryTF,
         g_m15Confirmation.confirmationTime,
         false
      );

   if(
      elapsedM5Bars < 0 ||
      elapsedM5Bars >
      ICT_M5_CONFIRM_MAX_BARS
   )
   {
      ResetM5Confirmation(
         g_m5Confirmation
      );

      return;
   }

   //---------------------------------------------------------------
   // ANALYZE M5
   //---------------------------------------------------------------

   bool result =
      AnalyzeM5Confirmation(
         symbol,
         g_h4SetupDirection,
         InpStructureLookback,
         g_m5Confirmation
      );

   g_m5Confirmation.valid =
      result;

   Print(
      "[M5] valid=",
      g_m5Confirmation.valid,
      " | direction=",
      StructureDirectionToString(
         g_h4SetupDirection
      ),
      " | displacement=",
  
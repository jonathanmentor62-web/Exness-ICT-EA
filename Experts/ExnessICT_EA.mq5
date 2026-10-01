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
//==================================================================
// H4 PRIMARY STRUCTURE ANALYSIS
//==================================================================
//
// This is the first stage of the NORMAL ICT pipeline:
//
// H4 structure
//     |
//     +--> direction
//     +--> displacement
//     +--> MSS/BOS
//     +--> setup activation
//
// No trade is opened here.
// This stage only establishes the higher-timeframe context.
//==================================================================

bool AnalyzeH4PrimaryStructure(
   const string symbol,
   ENUM_STRUCTURE_DIRECTION &direction,
   datetime &signalTime
)
{
   direction =
      STRUCTURE_UNKNOWN;

   signalTime =
      0;


   //---------------------------------------------------------------
   // Basic history check
   //---------------------------------------------------------------

   if(
      Bars(
         symbol,
         InpPrimaryTF
      ) <
      ICT_MIN_HISTORY_BARS
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Analyze the primary structure
   //---------------------------------------------------------------

   StructureSignal signal;


   AnalyzeStructureSignal(
      symbol,
      InpPrimaryTF,
      InpStructureLookback,
      signal
   );


   if(!signal.valid)
      return(false);


   direction=
      GetSignalDirection(
         signal
      );


   if(
      direction==
      STRUCTURE_UNKNOWN
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // A structural signal must also have displacement.
   //---------------------------------------------------------------

   if(!signal.displacement)
   {
      return(false);
   }


   signalTime=
      signal.signalTime;


   //---------------------------------------------------------------
   // Diagnostic information
   //---------------------------------------------------------------

   Print(
      "[H4 STRUCTURE] ",
      symbol,
      " | Direction=",
      StructureDirectionToString(
         direction
      ),
      " | Event=",
      StructureEventToString(
         signal.event
      ),
      " | Displacement=",
      (
         signal.displacement
         ?
         "YES"
         :
         "NO"
      )
   );


   return(true);
}


//==================================================================
// H4 LIQUIDITY ANALYSIS
//==================================================================
//
// Liquidity is treated as context/target information.
// A liquidity level alone does NOT trigger an entry.
//
// The intended sequence remains:
//
// liquidity -> sweep/reaction -> displacement -> structure
//==================================================================

bool AnalyzeH4Liquidity(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION direction
)
{
   if(
      direction==
      STRUCTURE_UNKNOWN
   )
   {
      return(false);
   }


   LiquidityLevel buySide;

   LiquidityLevel sellSide;


   bool haveBuySide=
      GetBuySideLiquidity(
         symbol,
         InpPrimaryTF,
         InpStructureLookback,
         buySide
      );


   bool haveSellSide=
      GetSellSideLiquidity(
         symbol,
         InpPrimaryTF,
         InpStructureLookback,
         sellSide
      );


   if(
      !haveBuySide &&
      !haveSellSide
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Bullish structure normally seeks/uses sell-side liquidity
   // before the bullish displacement.
   //---------------------------------------------------------------

   if(
      direction==
      STRUCTURE_BULLISH
   )
   {
      if(haveSellSide)
      {
         Print(
            "[H4 LIQUIDITY] ",
            symbol,
            " | Bullish context | Sell-side liquidity=",
            DoubleToString(
               sellSide.price,
               (int)SymbolInfoInteger(
                  symbol,
                  SYMBOL_DIGITS
               )
            )
         );


         return(true);
      }
   }


   //---------------------------------------------------------------
   // Bearish structure normally seeks/uses buy-side liquidity
   // before the bearish displacement.
   //---------------------------------------------------------------

   if(
      direction==
      STRUCTURE_BEARISH
   )
   {
      if(haveBuySide)
      {
         Print(
            "[H4 LIQUIDITY] ",
            symbol,
            " | Bearish context | Buy-side liquidity=",
            DoubleToString(
               buySide.price,
               (int)SymbolInfoInteger(
                  symbol,
                  SYMBOL_DIGITS
               )
            )
         );


         return(true);
      }
   }


   return(false);
}


//==================================================================
// H4 FVG ANALYSIS
//==================================================================

bool AnalyzeH4FVG(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION direction,
   FVGZone &zone
)
{
   ResetFVG(
      zone
   );


   if(
      direction==
      STRUCTURE_UNKNOWN
   )
   {
      return(false);
   }


   bool found=
      DetectFVG(
         symbol,
         InpPrimaryTF,
         InpFVGScanLookback,
         zone
      );


   if(!found)
   {
      Print(
         "[H4 FVG] ",
         symbol,
         " | No FVG detected."
      );


      return(false);
   }


   //---------------------------------------------------------------
   // Direction must agree with the H4 structure.
   //---------------------------------------------------------------

   if(
      direction==
      STRUCTURE_BULLISH &&
      zone.direction!=
      FVG_BULLISH
   )
   {
      return(false);
   }


   if(
      direction==
      STRUCTURE_BEARISH &&
      zone.direction!=
      FVG_BEARISH
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Optional minimum FVG size filter
   //---------------------------------------------------------------

   double point=
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   if(point<=0.0)
      return(false);


   double sizePoints=
      MathAbs(
         zone.high-
         zone.low
      )/
      point;


   if(
      sizePoints<
      ICT_MIN_FVG_SIZE_PTS
   )
   {
      return(false);
   }


   Print(
      "[H4 FVG] ",
      symbol,
      " | Direction=",
      FVGDirectionToString(
         zone.direction
      ),
      " | Low=",
      DoubleToString(
         zone.low,
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         )
      ),
      " | High=",
      DoubleToString(
         zone.high,
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         )
      ),
      " | SizePts=",
      DoubleToString(
         sizePoints,
         1
      )
   );


   return(true);
}


//==================================================================
// H4 ORDER BLOCK ANALYSIS
//==================================================================

bool AnalyzeH4OrderBlock(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION direction,
   OrderBlock &block
)
{
   ResetOrderBlock(
      block
   );


   if(!ICT_ENABLE_ORDER_BLOCK)
      return(true);


   if(
      direction==
      STRUCTURE_UNKNOWN
   )
   {
      return(false);
   }


   bool found=
      false;


   //---------------------------------------------------------------
   // Bullish order block
   //---------------------------------------------------------------

   if(
      direction==
      STRUCTURE_BULLISH
   )
   {
      found=
         FindBullishOrderBlock(
            symbol,
            InpPrimaryTF,
            InpOBScanLookback,
            block
         );
   }


   //---------------------------------------------------------------
   // Bearish order block
   //---------------------------------------------------------------

   if(
      direction==
      STRUCTURE_BEARISH
   )
   {
      found=
         FindBearishOrderBlock(
            symbol,
            InpPrimaryTF,
            InpOBScanLookback,
            block
         );
   }


   if(!found)
   {
      Print(
         "[H4 OB] ",
         symbol,
         " | No matching order block found."
      );


      return(false);
   }


   Print(
      "[H4 OB] ",
      symbol,
      " | Direction=",
      OrderBlockDirectionToString(
         block.direction
      ),
      " | Status=",
      OrderBlockStatusToString(
         block.status
      ),
      " | Low=",
      DoubleToString(
         block.low,
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         )
      ),
      " | High=",
      DoubleToString(
         block.high,
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         )
      )
   );


   return(true);
}


//==================================================================
// CREATE H4 SETUP
//==================================================================
//
// H4 is the context layer.
// It does NOT directly execute a trade.
//
// The setup remains active only long enough for M15/M5 confirmation.
//==================================================================

bool BuildH4Setup(
   const string symbol
)
{
   ENUM_STRUCTURE_DIRECTION direction;

   datetime signalTime;


   if(
      !AnalyzeH4PrimaryStructure(
         symbol,
         direction,
         signalTime
      )
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Liquidity context
   //---------------------------------------------------------------

   AnalyzeH4Liquidity(
      symbol,
      direction
   );


   //---------------------------------------------------------------
   // FVG context
   //---------------------------------------------------------------

   FVGZone fvg;

   bool haveFVG=
      AnalyzeH4FVG(
         symbol,
         direction,
         fvg
      );


   //---------------------------------------------------------------
   // Order block context
   //---------------------------------------------------------------

   OrderBlock block;

   bool haveOB=
      AnalyzeH4OrderBlock(
         symbol,
         direction,
         block
      );


   //---------------------------------------------------------------
   // ICT setup requires FVG when configured.
   //---------------------------------------------------------------

   if(
      ICT_REQUIRE_FVG &&
      !haveFVG
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Activate setup
   //---------------------------------------------------------------

   g_h4SetupActive=
      true;

   g_h4SetupDirection=
      direction;

   g_h4SetupTime=
      signalTime;

   g_h4SetupShift=
      1;


   Print(
      "[H4 SETUP] ACTIVE | ",
      symbol,
      " | Direction=",
      StructureDirectionToString(
         direction
      ),
      " | FVG=",
      (
         haveFVG
         ?
         "YES"
         :
         "NO"
      ),
      " | OB=",
      (
         haveOB
         ?
         "YES"
         :
         "NO"
      )
   );


   return(true);
}


//==================================================================
// M15 CONFIRMATION ANALYSIS
//==================================================================
//
// M15 is the primary confirmation timeframe for H4.
//
// Required confirmation:
//
// H4 direction
//      |
//      v
// M15 displacement
//      |
//      v
// M15 MSS/BOS
//      |
//      v
// M15 FVG
//      |
//      v
// M5 execution confirmation
//==================================================================

bool AnalyzeM15Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection,
   M15Confirmation &confirmation
)
{
   ResetM15Confirmation(
      confirmation
   );


   if(
      expectedDirection==
      STRUCTURE_UNKNOWN
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // History
   //---------------------------------------------------------------

   if(
      Bars(
         symbol,
         InpConfirmTF
      )<
      ICT_MIN_HISTORY_BARS
   )
   {
      return(false);
   }


   //---------------------------------------------------------------
   // Structure
   //---------------------------------------------------------------

   StructureSignal signal;


   AnalyzeStructureSignal(
      symbol,
      InpConfirmTF,
      InpStructureLookback,
      signal
   );


   if(!signal.valid)
   {
      confirmation.state=
         CONFIRMATION_WAITING;

      confirmation.reason=
         "No valid M15 structure signal.";

      return(false);
   }


   ENUM_STRUCTURE_DIRECTION direction=
      GetSignalDirection(
         signal
      );


   confirmation.direction=
      direction;

   confirmation.displacement=
      signal.displacement;

   confirmation.mss=
      signal.mss;

   confirmation.bos=
      signal.bos;

   confirmation.brokenLevel=
      signal.brokenLevel;

   confirmation.confirmationTime=
      signal.signalTime;

   confirmation.confirmationShift=
      signal.signalShift;


   //---------------------------------------------------------------
   // Direction agreement
   //---------------------------------------------------------------

   if(
      direction!=
      expectedDirection
   )
   {
      confirmation.state=
         CONFIRMATION_INVALID;

      confirmation.reason=
         "M15 direction disagrees with H4.";

      return(false);
   }


   //---------------------------------------------------------------
   // Displacement
   //---------------------------------------------------------------

   if(!signal.displacement)
   {
      confirmation.state=
         CONFIRMATION_WAITING;

      confirmation.reason=
         "M15 displacement not confirmed.";

      return(false);
   }


   //---------------------------------------------------------------
   // MSS/BOS
   //---------------------------------------------------------------

   if(
      !signal.mss &&
      !signal.bos
   )
   {
      confirmation.state=
         CONFIRMATION_WAITING;

      confirmation.reason=
         "M15 MSS/BOS not confirmed.";

      return(false);
   }


   //---------------------------------------------------------------
   // FVG
   //---------------------------------------------------------------

   FVGZone fvg;


   bool haveFVG=
      AnalyzeH4FVG(
         symbol,
         expectedDirection,
         fvg
      );


   confirmation.fvgPresent=
      haveFVG;


   if(
      ICT_REQUIRE_FVG &&
      !haveFVG
   )
   {
      confirmation.state=
         CONFIRMATION_WAITING;

      confirmation.reason=
         "Required FVG not present.";

      return(false);
   }


   //---------------------------------------------------------------
   // Order block
   //---------------------------------------------------------------

   if(ICT_ENABLE_ORDER_BLOCK)
   {
      OrderBlock block;


      bool haveOB=
         AnalyzeH4OrderBlock(
            symbol,
            expectedDirection,
            block
         );


      confirmation.orderBlockPresent=
         haveOB;
   }
   else
   {
      confirmation.orderBlockPresent=
         false;
   }


   //---------------------------------------------------------------
   // Final validation
   //---------------------------------------------------------------

   confirmation.valid=
      true;

   confirmation.confirmed=
      true;

   confirmation.state=
      CONFIRMATION_CONFIRMED;

   confirmation.reason=
      "M15 ICT confirmation valid.";


   Print(
      "[M15 CONFIRMATION] ",
      symbol,
      " | Direction=",
      StructureDirectionToString(
         confirmation.direction
      ),
      " | MSS=",
      (
         confirmation.mss
         ?
         "YES"
         :
         "NO"
      ),
      " | BOS=",
      (
         confirmation.bos
         ?
         "YES"
         :
         "NO"
      ),
      " | Displacement=",
      (
         confirmation.displacement
         ?
         "YES"
         :
         "NO"
      ),
      " | FVG=",
      (
         confirmation.fvgPresent
         ?
         "YES"
         :
         "NO"
      )
   );


   return(
      ValidateM15Confirmation(
         confirmation,
         expectedDirection
      )
   );
}


//==================================================================
// M5 EXECUTION CONFIRMATION
//==================================================================
//
// M5 is the final confirmation before a NORMAL-mode entry.
//
// The M5 module is deliberately kept separate so the execution
// logic can later be tightened without changing the H4/M15 engine.
//==================================================================

bool AnalyzeM5ExecutionConfirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection
)
{
   ResetM5Confirmation(
      g_m5Confirmation
   );


   if(
      expectedDirection==
      STRUCTURE_UNKNOWN
   )
   {
      return(false);
   }


   bool confirmed=
      AnalyzeM5Confirmation(
         symbol,
         expectedDirection,
         g_m5Confirmation
      );


   if(!confirmed)
   {
      return(false);
   }


   if(
      !g_m5Confirmation.valid
   )
   {
      return(false);
   }


   if(
      g_m5Confirmation.direction!=
      expectedDirection
   )
   {
      return(false);
   }


   Print(
      "[M5 CONFIRMATION] ",
      symbol,
      " | Direction=",
      StructureDirectionToString(
         g_m5Confirmation.direction
      ),
      " | CONFIRMED"
   );


   return(true);
}
//+------------------------------------------------------------------+
//|                                             ExnessICT_EA.mq5     |
//|                     Exness ICT Automated Trading System          |
//+------------------------------------------------------------------+
#property strict
#property version   "0.40"
#property description "H4 ICT framework with M15 confirmation."
#property description "Trading remains disabled during development."

//====================================================================
// STANDARD MT5 TRADE LIBRARY
//====================================================================
#include <Trade/Trade.mqh>

//====================================================================
// EA MODULES
//====================================================================
#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/StructureSignal.mqh"
#include "../Include/Liquidity.mqh"
#include "../Include/FVG.mqh"
#include "../Include/OrderBlock.mqh"

CTrade Trade;

//====================================================================
// USER CONFIGURATION
//====================================================================
input ENUM_TIMEFRAMES InpPrimaryTF     = ICT_PRIMARY_TF;
input ENUM_TIMEFRAMES InpConfirmTF     = ICT_CONFIRM_TF;
input double          InpMaxRiskMoney  = ICT_MAX_RISK_MONEY;

input ulong           InpMagicNumber   = ICT_MAGIC_NUMBER;
input int             InpMaxSpreadPts  = ICT_MAX_SPREAD_PTS;
input int             InpDeviationPts  = ICT_MAX_SLIPPAGE_PTS;

//====================================================================
// SAFETY SWITCH
//====================================================================
// MUST REMAIN FALSE DURING DEVELOPMENT.
input bool InpEnableTrading = false;

//====================================================================
// SCANNING
//====================================================================
input int InpStructureLookback = ICT_STRUCTURE_LOOKBACK;
input int InpFVGScanLookback   = 20;
input int InpOBScanLookback    = ICT_OB_LOOKBACK;

//====================================================================
// PROCESS CONTROL
//====================================================================
datetime g_lastPrimaryBar = 0;
datetime g_lastConfirmBar = 0;

//====================================================================
// H4 SETUP STATE
//====================================================================
bool g_h4SetupActive = false;

ENUM_STRUCTURE_DIRECTION g_h4SetupDirection =
   STRUCTURE_UNKNOWN;

datetime g_h4SetupTime = 0;

//====================================================================
// M15 CONFIRMATION
//====================================================================
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

//+------------------------------------------------------------------+
//| Reset M15 confirmation                                           |
//+------------------------------------------------------------------+
void ResetM15Confirmation(
   M15Confirmation &confirmation
)
{
   confirmation.confirmed = false;
   confirmation.valid = false;

   confirmation.state =
      CONFIRMATION_NONE;

   confirmation.direction =
      STRUCTURE_UNKNOWN;

   confirmation.displacement = false;
   confirmation.mss = false;
   confirmation.bos = false;

   confirmation.fvgPresent = false;
   confirmation.orderBlockPresent = false;

   confirmation.brokenLevel = 0.0;

   confirmation.confirmationTime = 0;
   confirmation.confirmationShift = -1;

   confirmation.reason = "";
}

//+------------------------------------------------------------------+
//| Validate M15 direction against H4 direction                      |
//+------------------------------------------------------------------+
bool IsConfirmationDirectionValid(
   const ENUM_STRUCTURE_DIRECTION h4Direction,
   const ENUM_STRUCTURE_DIRECTION m15Direction
)
{
   if(h4Direction == STRUCTURE_UNKNOWN)
      return(false);

   if(m15Direction == STRUCTURE_UNKNOWN)
      return(false);

   return(h4Direction == m15Direction);
}

//+------------------------------------------------------------------+
//| Validate M15 confirmation                                        |
//+------------------------------------------------------------------+
bool ValidateM15Confirmation(
   const M15Confirmation &confirmation,
   const ENUM_STRUCTURE_DIRECTION expectedDirection
)
{
   if(!confirmation.valid)
      return(false);

   if(!confirmation.confirmed)
      return(false);

   if(
      !IsConfirmationDirectionValid(
         expectedDirection,
         confirmation.direction
      )
   )
   {
      return(false);
   }

   if(!confirmation.displacement)
      return(false);

   if(
      !confirmation.mss &&
      !confirmation.bos
   )
   {
      return(false);
   }

   if(confirmation.confirmationTime <= 0)
      return(false);

   if(confirmation.confirmationShift < 1)
      return(false);

   if(confirmation.brokenLevel <= 0.0)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Analyze M15 confirmation                                         |
//+------------------------------------------------------------------+
M15Confirmation AnalyzeM15Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection
)
{
   M15Confirmation confirmation;

   ResetM15Confirmation(confirmation);

   //===============================================================
   // BASIC VALIDATION
   //===============================================================
   if(!IsSymbolTradable(symbol))
   {
      confirmation.state =
         CONFIRMATION_INVALID;

      confirmation.reason =
         "Symbol is not tradable.";

      return(confirmation);
   }

   if(expectedDirection == STRUCTURE_UNKNOWN)
   {
      confirmation.state =
         CONFIRMATION_INVALID;

      confirmation.reason =
         "H4 direction is unknown.";

      return(confirmation);
   }

   int barsAvailable =
      Bars(symbol, InpConfirmTF);

   if(barsAvailable < ICT_MIN_HISTORY_BARS)
   {
      confirmation.state =
         CONFIRMATION_INVALID;

      confirmation.reason =
         "Insufficient M15 history.";

      return(confirmation);
   }

   //===============================================================
   // CLOSED M15 CANDLE ONLY
   //===============================================================
   const int signalShift = 1;

   datetime signalTime =
      iTime(
         symbol,
         InpConfirmTF,
         signalShift
      );

   if(signalTime <= 0)
   {
      confirmation.state =
         CONFIRMATION_INVALID;

      confirmation.reason =
         "Invalid M15 candle time.";

      return(confirmation);
   }

   confirmation.confirmationShift =
      signalShift;

   confirmation.confirmationTime =
      signalTime;

   //===============================================================
   // M15 STRUCTURE
   //===============================================================
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
      confirmation.state =
         CONFIRMATION_WAITING;

      confirmation.reason =
         "No M15 MSS/BOS detected.";

      return(confirmation);
   }

   confirmation.direction =
      GetSignalDirection(signal);

   confirmation.displacement =
      (
         signal.bullishDisplacement ||
         signal.bearishDisplacement
      );

   confirmation.mss =
      IsMSSSignal(signal);

   confirmation.bos =
      IsBOSSignal(signal);

   confirmation.brokenLevel =
      signal.brokenLevel;

   //===============================================================
   // DIRECTION AGREEMENT
   //===============================================================
   if(
      !IsConfirmationDirectionValid(
         expectedDirection,
         confirmation.direction
      )
   )
   {
      confirmation.state =
         CONFIRMATION_WAITING;

      confirmation.reason =
         "M15 direction does not agree with H4.";

      return(confirmation);
   }

   //===============================================================
   // DISPLACEMENT
   //===============================================================
   if(!confirmation.displacement)
   {
      confirmation.state =
         CONFIRMATION_WAITING;

      confirmation.reason =
         "M15 structure event lacks displacement.";

      return(confirmation);
   }

   //===============================================================
   // M15 FVG
   //===============================================================
   FVGZone fvg;

   if(
      DetectFVG(
         symbol,
         InpConfirmTF,
         signalShift,
         fvg
      )
   )
   {
      ENUM_STRUCTURE_DIRECTION fvgDirection =
         STRUCTURE_UNKNOWN;

      if(fvg.direction == FVG_BULLISH)
         fvgDirection = STRUCTURE_BULLISH;

      if(fvg.direction == FVG_BEARISH)
         fvgDirection = STRUCTURE_BEARISH;

      if(
         IsConfirmationDirectionValid(
            expectedDirection,
            fvgDirection
         )
      )
      {
         confirmation.fvgPresent = true;
      }
   }

   //===============================================================
   // M15 ORDER BLOCK
   //===============================================================
   OrderBlock ob;

   ResetOrderBlock(ob);

   bool obFound = false;

   if(
      expectedDirection ==
      STRUCTURE_BULLISH
   )
   {
      obFound =
         FindBullishOrderBlock(
            symbol,
            InpConfirmTF,
            signalShift,
            InpOBScanLookback,
            ob
         );
   }
   else
   if(
      expectedDirection ==
      STRUCTURE_BEARISH
   )
   {
      obFound =
         FindBearishOrderBlock(
            symbol,
            InpConfirmTF,
            signalShift,
            InpOBScanLookback,
            ob
         );
   }

   confirmation.orderBlockPresent =
      obFound;

   //===============================================================
   // FINAL M15 CONFIRMATION
   //===============================================================
   if(
      confirmation.direction ==
      expectedDirection &&
      confirmation.displacement &&
      (
         confirmation.mss ||
         confirmation.bos
      )
   )
   {
      confirmation.confirmed = true;
      confirmation.valid = true;

      confirmation.state =
         CONFIRMATION_CONFIRMED;

      confirmation.reason =
         "M15 structure confirmed H4 direction.";

      return(confirmation);
   }

   confirmation.state =
      CONFIRMATION_WAITING;

   confirmation.reason =
      "M15 conditions incomplete.";

   return(confirmation);
}

//+------------------------------------------------------------------+
//| Print M15 confirmation                                           |
//+------------------------------------------------------------------+
void PrintM15Confirmation(
   const string symbol,
   const M15Confirmation &confirmation
)
{
   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   Print(
      "[M15 CONFIRMATION] ",
      symbol,
      " | state=",
      (int)confirmation.state,
      " | confirmed=",
      confirmation.confirmed,
      " | valid=",
      confirmation.valid,
      " | direction=",
      StructureDirectionToString(
         confirmation.direction
      ),
      " | displacement=",
      confirmation.displacement,
      " | MSS=",
      confirmation.mss,
      " | BOS=",
      confirmation.bos,
      " | FVG=",
      confirmation.fvgPresent,
      " | OB=",
      confirmation.orderBlockPresent,
      " | broken=",
      DoubleToString(
         confirmation.brokenLevel,
         digits
      ),
      " | reason=",
      confirmation.reason
   );
}

//+------------------------------------------------------------------+
//| Process M15 confirmation                                         |
//+------------------------------------------------------------------+
void ProcessM15Confirmation(
   const string symbol
)
{
   if(!g_h4SetupActive)
      return;

   datetime confirmBar =
      iTime(
         symbol,
         InpConfirmTF,
         0
      );

   if(confirmBar <= 0)
      return;

   if(confirmBar == g_lastConfirmBar)
      return;

   g_lastConfirmBar = confirmBar;

   Print(
      "[M15] New confirmation candle: ",
      TimeToString(
         confirmBar,
         TIME_DATE | TIME_MINUTES
      )
   );

   g_m15Confirmation =
      AnalyzeM15Confirmation(
         symbol,
         g_h4SetupDirection
      );

   PrintM15Confirmation(
      symbol,
      g_m15Confirmation
   );

   //===============================================================
   // FUTURE ENTRY INTEGRATION POINT
   //===============================================================
   //
   // M15 confirmation
   //       ↓
   // Entry-zone validation
   //       ↓
   // Structural SL
   //       ↓
   // Position sizing
   //       ↓
   // Liquidity target
   //       ↓
   // Risk / exposure checks
   //       ↓
   // Execution
   //
   // NOTHING EXECUTES HERE YET.
   //===============================================================

   if(!g_m15Confirmation.confirmed)
      return;

   Print(
      "[M15] CONFIRMATION READY — execution remains disabled."
   );
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetDeviationInPoints(InpDeviationPts);

   ResetM15Confirmation(
      g_m15Confirmation
   );

   Print("==================================================");
   Print("Exness ICT EA v0.40 initialized");
   Print("Symbol: ", _Symbol);
   Print(
      "Primary timeframe: ",
      EnumToString(InpPrimaryTF)
   );
   Print(
      "Confirmation timeframe: ",
      EnumToString(InpConfirmTF)
   );
   Print(
      "Maximum planned risk: $",
      DoubleToString(
         InpMaxRiskMoney,
         2
      )
   );
   Print(
      "Maximum spread: ",
      InpMaxSpreadPts,
      " points"
   );
   Print(
      "Trading enabled: ",
      InpEnableTrading
   );
   Print("==================================================");

   if(!InpEnableTrading)
      Print(
         "[SAFETY] Trading is DISABLED."
      );

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(
   const int reason
)
{
   Print(
      "Exness ICT EA stopped. Reason: ",
      reason
   );
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //===============================================================
   // H4 PROCESSING
   //===============================================================
   datetime primaryBar =
      iTime(
         _Symbol,
         InpPrimaryTF,
         0
      );

   if(primaryBar <= 0)
      return;

   //--- Process new H4 candle once.
   if(primaryBar != g_lastPrimaryBar)
   {
      g_lastPrimaryBar = primaryBar;

      Print("--------------------------------------------------");
      Print(
         "[NEW H4 BAR] ",
         _Symbol,
         " | ",
         TimeToString(
            primaryBar,
            TIME_DATE | TIME_MINUTES
         )
      );

      AnalyzePrimaryStructure(
         _Symbol
      );

      AnalyzePrimarySignal(
         _Symbol
      );

      AnalyzePrimaryZones(
         _Symbol
      );
   }

   //===============================================================
   // M15 CONFIRMATION
   //===============================================================
   ProcessM15Confirmation(
      _Symbol
   );

   //===============================================================
   // HARD SAFETY STOP
   //===============================================================
   if(!InpEnableTrading)
      return;

   //===============================================================
   // FUTURE EXECUTION ENGINE
   //===============================================================
   //
   // No order execution is implemented yet.
   //
   // Future:
   //
   // M15 confirmation
   //       ↓
   // liquidity / FVG / OB entry zone
   //       ↓
   // structural SL
   //       ↓
   // <= $2 risk sizing
   //       ↓
   // liquidity target
   //       ↓
   // exposure checks
   //       ↓
   // spread checks
   //       ↓
   // order execution
   //===============================================================
}

//+------------------------------------------------------------------+
//| Analyze H4 structure                                             |
//+------------------------------------------------------------------+
void AnalyzePrimaryStructure(
   const string symbol
)
{
   if(!IsSymbolTradable(symbol))
   {
      Print(
         "[STRUCTURE] Symbol not tradable: ",
         symbol
      );

      return;
   }

   int barsAvailable =
      Bars(
         symbol,
         InpPrimaryTF
      );

   if(
      barsAvailable <
      ICT_MIN_HISTORY_BARS
   )
   {
      Print(
         "[STRUCTURE] Not enough history for ",
         symbol,
         " | bars=",
         barsAvailable
      );

      return;
   }

   int swingHighShift =
      FindRecentSwingHigh(
         symbol,
         InpPrimaryTF,
         ICT_SWING_RIGHT + 1,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   int swingLowShift =
      FindRecentSwingLow(
         symbol,
         InpPrimaryTF,
         ICT_SWING_RIGHT + 1,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   double swingHigh = 0.0;
   double swingLow  = 0.0;

   if(swingHighShift >= 0)
   {
      swingHigh =
         iHigh(
            symbol,
            InpPrimaryTF,
            swingHighShift
         );
   }

   if(swingLowShift >= 0)
   {
      swingLow =
         iLow(
            symbol,
            InpPrimaryTF,
            swingLowShift
         );
   }

   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   Print(
      "[STRUCTURE] ",
      symbol,
      " | ",
      EnumToString(InpPrimaryTF),
      " | swing high=",
      DoubleToString(
         swingHigh,
         digits
      ),
      " | swing low=",
      DoubleToString(
         swingLow,
         digits
      )
   );

   //===============================================================
   // BUY-SIDE LIQUIDITY
   //===============================================================
   LiquidityLevel buySide =
      GetBuySideLiquidity(
         symbol,
         InpPrimaryTF,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   if(buySide.valid)
   {
      Print(
         "[LIQUIDITY] Buy-side=",
         DoubleToString(
            buySide.price,
            digits
         ),
         " | shift=",
         buySide.shift
      );
   }
   else
   {
      Print(
         "[LIQUIDITY] No valid buy-

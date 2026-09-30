//+------------------------------------------------------------------+
//| ExnessICT_EA.mq5                                                 |
//| Exness ICT EA - development / analysis build                     |
//+------------------------------------------------------------------+
#property strict
#property version   "0.50"
#property description "H4 ICT framework with M15 confirmation."
#property description "Trading disabled during development."

#include <Trade/Trade.mqh>

#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/StructureSignal.mqh"
#include "../Include/Liquidity.mqh"
#include "../Include/FVG.mqh"
#include "../Include/OrderBlock.mqh"

CTrade Trade;

input ENUM_TIMEFRAMES InpPrimaryTF      = ICT_PRIMARY_TF;
input ENUM_TIMEFRAMES InpConfirmTF      = ICT_CONFIRM_TF;
input double          InpMaxRiskMoney   = ICT_MAX_RISK_MONEY;

input ulong           InpMagicNumber    = ICT_MAGIC_NUMBER;
input int             InpMaxSpreadPts  = ICT_MAX_SPREAD_PTS;
input int             InpDeviationPts  = ICT_MAX_SLIPPAGE_PTS;

input bool InpEnableTrading = false;

input int InpStructureLookback = ICT_STRUCTURE_LOOKBACK;
input int InpFVGScanLookback   = 20;
input int InpOBScanLookback    = ICT_OB_LOOKBACK;

datetime g_lastPrimaryBar = 0;
datetime g_lastConfirmBar = 0;

bool g_h4SetupActive = false;
ENUM_STRUCTURE_DIRECTION g_h4SetupDirection = STRUCTURE_UNKNOWN;
datetime g_h4SetupTime = 0;
int g_h4SetupShift = -1;

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
//| Reset confirmation                                               |
//+------------------------------------------------------------------+
void ResetM15Confirmation(M15Confirmation &c)
{
   c.confirmed = false;
   c.valid = false;
   c.state = CONFIRMATION_NONE;

   c.direction = STRUCTURE_UNKNOWN;

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

//+------------------------------------------------------------------+
//| Symbol tradability                                               |
//+------------------------------------------------------------------+
bool IsSymbolTradable(const string symbol)
{
   if(!SymbolSelect(symbol,true))
      return(false);

   long mode = 0;

   if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE,mode))
      return(false);

   return(mode != SYMBOL_TRADE_MODE_DISABLED);
}

//+------------------------------------------------------------------+
//| Spread filter                                                    |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable(const string symbol)
{
   long spread = 0;

   if(!SymbolInfoInteger(symbol,SYMBOL_SPREAD,spread))
      return(false);

   return(spread <= InpMaxSpreadPts);
}

//+------------------------------------------------------------------+
//| Maximum planned risk                                             |
//+------------------------------------------------------------------+
double GetMaxRiskMoney()
{
   return(InpMaxRiskMoney);
}

//+------------------------------------------------------------------+
//| Direction agreement                                              |
//+------------------------------------------------------------------+
bool IsConfirmationDirectionValid(
   const ENUM_STRUCTURE_DIRECTION h4Direction,
   const ENUM_STRUCTURE_DIRECTION m15Direction)
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
   const M15Confirmation &c,
   const ENUM_STRUCTURE_DIRECTION expectedDirection)
{
   if(!c.valid)
      return(false);

   if(!c.confirmed)
      return(false);

   if(!IsConfirmationDirectionValid(expectedDirection,c.direction))
      return(false);

   if(!c.displacement)
      return(false);

   if(!c.mss && !c.bos)
      return(false);

   if(ICT_REQUIRE_FVG && !c.fvgPresent)
      return(false);

   if(c.confirmationTime <= 0)
      return(false);

   if(c.confirmationShift < 1)
      return(false);

   if(c.brokenLevel <= 0.0)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Analyze M15 confirmation                                         |
//+------------------------------------------------------------------+
M15Confirmation AnalyzeM15Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection)
{
   M15Confirmation c;

   ResetM15Confirmation(c);

   if(!IsSymbolTradable(symbol))
   {
      c.state = CONFIRMATION_INVALID;
      c.reason = "Symbol is not tradable.";
      return(c);
   }

   if(expectedDirection == STRUCTURE_UNKNOWN)
   {
      c.state = CONFIRMATION_INVALID;
      c.reason = "H4 direction is unknown.";
      return(c);
   }

   if(Bars(symbol,InpConfirmTF) < ICT_MIN_HISTORY_BARS)
   {
      c.state = CONFIRMATION_INVALID;
      c.reason = "Insufficient M15 history.";
      return(c);
   }

   const int signalShift = 1;

   c.confirmationShift = signalShift;

   c.confirmationTime =
      iTime(symbol,InpConfirmTF,signalShift);

   if(c.confirmationTime <= 0)
   {
      c.state = CONFIRMATION_INVALID;
      c.reason = "Invalid M15 candle time.";
      return(c);
   }

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
      c.state = CONFIRMATION_WAITING;
      c.reason = "No M15 MSS/BOS detected.";
      return(c);
   }

   c.direction = GetSignalDirection(signal);

   c.displacement =
      signal.bullishDisplacement ||
      signal.bearishDisplacement;

   c.mss =
      signal.bullishMSS ||
      signal.bearishMSS;

   c.bos =
      signal.bullishBOS ||
      signal.bearishBOS;

   c.brokenLevel = signal.brokenLevel;

   if(c.direction != expectedDirection)
   {
      c.state = CONFIRMATION_WAITING;
      c.reason = "M15 direction disagrees with H4.";
      return(c);
   }

   if(expectedDirection == STRUCTURE_BULLISH &&
      !signal.bullishDisplacement)
   {
      c.state = CONFIRMATION_WAITING;
      c.reason = "M15 bullish displacement missing.";
      return(c);
   }

   if(expectedDirection == STRUCTURE_BEARISH &&
      !signal.bearishDisplacement)
   {
      c.state = CONFIRMATION_WAITING;
      c.reason = "M15 bearish displacement missing.";
      return(c);
   }

   //==============================================================
   // FVG
   //==============================================================

   FVGZone fvg;

   ResetFVG(fvg);

   if(DetectFVG(
      symbol,
      InpConfirmTF,
      signalShift,
      fvg))
   {
      ENUM_STRUCTURE_DIRECTION fvgDirection =
         STRUCTURE_UNKNOWN;

      if(fvg.direction == FVG_BULLISH)
         fvgDirection = STRUCTURE_BULLISH;

      if(fvg.direction == FVG_BEARISH)
         fvgDirection = STRUCTURE_BEARISH;

      if(fvgDirection == expectedDirection)
         c.fvgPresent = true;
   }

   //==============================================================
   // ORDER BLOCK
   //==============================================================

   OrderBlock ob;

   ResetOrderBlock(ob);

   if(ICT_ENABLE_ORDER_BLOCK)
   {
      if(expectedDirection == STRUCTURE_BULLISH)
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
      else if(expectedDirection == STRUCTURE_BEARISH)
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

   //==============================================================
   // Required FVG filter
   //==============================================================

   if(ICT_REQUIRE_FVG && !c.fvgPresent)
   {
      c.state = CONFIRMATION_WAITING;
      c.reason = "Required directional M15 FVG missing.";
      return(c);
   }

   //==============================================================
   // Confirmation complete
   //==============================================================

   c.confirmed = true;
   c.valid = true;
   c.state = CONFIRMATION_CONFIRMED;

   c.reason =
      "M15 displacement + structure + required confluence confirmed.";

   return(c);
}

//+------------------------------------------------------------------+
//| Print M15 confirmation                                           |
//+------------------------------------------------------------------+
void PrintM15Confirmation(
   const string symbol,
   const M15Confirmation &c)
{
   int digits =
      (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   Print(
      "[M15 CONFIRMATION] ",
      symbol,
      " | state=",c.state,
      " | confirmed=",c.confirmed,
      " | direction=",
      StructureDirectionToString(c.direction),
      " | displacement=",c.displacement,
      " | MSS=",c.mss,
      " | BOS=",c.bos,
      " | FVG=",c.fvgPresent,
      " | OB=",c.orderBlockPresent,
      " | broken=",
      DoubleToString(c.brokenLevel,digits),
      " | reason=",c.reason
   );
}

//+------------------------------------------------------------------+
//| Process M15 confirmation                                         |
//+------------------------------------------------------------------+
void ProcessM15Confirmation(const string symbol)
{
   if(!g_h4SetupActive)
      return;

   datetime currentBar =
      iTime(symbol,InpConfirmTF,0);

   if(currentBar <= 0)
      return;

   if(currentBar == g_lastConfirmBar)
      return;

   g_lastConfirmBar = currentBar;

   //==============================================================
   // H4 setup lifetime
   //==============================================================

   int elapsedH4Bars =
      iBarShift(
         symbol,
         InpPrimaryTF,
         g_h4SetupTime,
         false
      );

   if(elapsedH4Bars < 0 ||
      elapsedH4Bars > ICT_SETUP_MAX_BARS)
   {
      g_h4SetupActive = false;
      g_h4SetupDirection = STRUCTURE_UNKNOWN;
      g_h4SetupTime = 0;
      g_h4SetupShift = -1;

      ResetM15Confirmation(g_m15Confirmation);

      g_m15Confirmation.state =
         CONFIRMATION_INVALID;

      g_m15Confirmation.reason =
         "H4 setup expired.";

      Print("[H4 SETUP] Expired before M15 confirmation.");

      return;
   }

   //==============================================================
   // M15 confirmation lifetime
   //==============================================================

   int elapsedM15Bars =
      iBarShift(
         symbol,
         InpConfirmTF,
         g_h4SetupTime,
         false
      );

   if(elapsedM15Bars < 0 ||
      elapsedM15Bars > ICT_M15_CONFIRM_MAX_BARS)
   {
      ResetM15Confirmation(g_m15Confirmation);

      g_m15Confirmation.state =
         CONFIRMATION_INVALID;

      g_m15Confirmation.reason =
         "M15 confirmation window expired.";

      return;
   }

   Print(
      "[M15] New confirmation candle: ",
      TimeToString(
         currentBar,
         TIME_DATE|TIME_MINUTES
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

   if(ValidateM15Confirmation(
      g_m15Confirmation,
      g_h4SetupDirection))
   {
      Print(
         "[M15] CONFIRMATION READY — execution remains disabled."
      );
   }
}

//+------------------------------------------------------------------+
//| Analyze H4 structure                                             |
//+------------------------------------------------------------------+
void AnalyzePrimaryStructure(const string symbol)
{
   if(!IsSymbolTradable(symbol))
      return;

   if(Bars(symbol,InpPrimaryTF) < ICT_MIN_HISTORY_BARS)
      return;

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

   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   double swingHigh = 0.0;
   double swingLow = 0.0;

   if(swingHighShift >= 0)
      swingHigh =
         iHigh(
            symbol,
            InpPrimaryTF,
            swingHighShift
         );

   if(swingLowShift >= 0)
      swingLow =
         iLow(
            symbol,
            InpPrimaryTF,
            swingLowShift
         );

   Print(
      "[STRUCTURE] ",
      symbol,
      " | ",
      EnumToString(InpPrimaryTF),
      " | swing high=",
      DoubleToString(swingHigh,digits),
      " | swing low=",
      DoubleToString(swingLow,digits)
   );

   LiquidityLevel buySide =
      GetBuySideLiquidity(
         symbol,
         InpPrimaryTF,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   LiquidityLevel sellSide =
      GetSellSideLiquidity(
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
         DoubleToString(buySide.price,digits),
         " | shift=",
         buySide.shift
      );
   }
   else
   {
      Print("[LIQUIDITY] No valid buy-side level.");
   }

   if(sellSide.valid)
   {
      Print(
         "[LIQUIDITY] Sell-side=",
         DoubleToString(sellSide.price,digits),
         " | shift=",
         sellSide.shift
      );
   }
   else
   {
      Print("[LIQUIDITY] No valid sell-side level.");
   }
}

//+------------------------------------------------------------------+
//| Analyze H4 signal                                                |
//+------------------------------------------------------------------+
void AnalyzePrimarySignal(const string symbol)
{
   g_h4SetupActive = false;
   g_h4SetupDirection = STRUCTURE_UNKNOWN;
   g_h4SetupTime = 0;
   g_h4SetupShift = -1;

   StructureSignal signal =
      AnalyzeStructureSignal(
         symbol,
         InpPrimaryTF,
         1,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   if(!signal.valid)
   {
      Print(
         "[H4 SIGNAL] No MSS/BOS on latest closed H4 candle."
      );

      return;
   }

   ENUM_STRUCTURE_DIRECTION direction =
      GetSignalDirection(signal);

   bool directionalDisplacement =
      (
         direction == STRUCTURE_BULLISH &&
         signal.bullishDisplacement
      )
      ||
      (
         direction == STRUCTURE_BEARISH &&
         signal.bearishDisplacement
      );

   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   Print(
      "[H4 SIGNAL] ",
      symbol,
      " | event=",
      StructureEventToString(signal.event),
      " | previous=",
      StructureDirectionToString(
         signal.previousStructure
      ),
      " | broken=",
      DoubleToString(
         signal.brokenLevel,
         digits
      ),
      " | displacement=",
      directionalDisplacement
   );

   if(direction == STRUCTURE_UNKNOWN ||
      !directionalDisplacement)
   {
      Print(
         "[H4 SETUP] Rejected: directional displacement missing."
      );

      return;
   }

   g_h4SetupActive = true;
   g_h4SetupDirection = direction;
   g_h4SetupTime = signal.signalTime;
   g_h4SetupShift = 1;

   Print(
      "[H4 SETUP] Active | direction=",
      StructureDirectionToString(direction),
      " | time=",
      TimeToString(
         g_h4SetupTime,
         TIME_DATE|TIME_MINUTES
      )
   );
}

//+------------------------------------------------------------------+
//| Analyze H4 FVG / OB zones                                        |
//+------------------------------------------------------------------+
void AnalyzePrimaryZones(const string symbol)
{
   const int signalShift = 1;

   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   //==============================================================
   // FVG
   //==============================================================

   FVGZone fvg;

   ResetFVG(fvg);

   if(DetectFVG(
      symbol,
      InpPrimaryTF,
      signalShift,
      fvg))
   {
      Print(
         "[FVG] ",
         symbol,
         " | direction=",
         FVGDirectionToString(fvg.direction),
         " | status=",
         FVGStatusToString(fvg.status),
         " | upper=",
         DoubleToString(fvg.upper,digits),
         " | lower=",
         DoubleToString(fvg.lower,digits),
         " | midpoint=",
         DoubleToString(fvg.midpoint,digits),
         " | size=",
         DoubleToString(fvg.size,digits)
      );
   }
   else
   {
      Print(
         "[FVG] No valid FVG on latest closed H4 candle."
      );
   }

   //==============================================================
   // Order Block
   //==============================================================

   StructureSignal signal =
      AnalyzeStructureSignal(
         symbol,
         InpPrimaryTF,
         signalShift,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   OrderBlock ob;

   ResetOrderBlock(ob);

   bool found = false;

   if(ICT_ENABLE_ORDER_BLOCK && signal.valid)
   {
      if(signal.bullishDisplacement)
      {
         found =
            FindBullishOrderBlock(
               symbol,
               InpPrimaryTF,
               signalShift,
               InpOBScanLookback,
               ob
            );
      }
      else if(signal.bearishDisplacement)
      {
         found =
            FindBearishOrderBlock(
               symbol,
               InpPrimaryTF,
               signalShift,
               InpOBScanLookback,
               ob
            );
      }
   }

   if(found)
   {
      Print(
         "[ORDER BLOCK] ",
         symbol,
         " | direction=",
         OrderBlockDirectionToString(ob.direction),
         " | status=",
         OrderBlockStatusToString(ob.status),
         " | upper=",
         DoubleToString(ob.upper,digits),
         " | lower=",
         DoubleToString(ob.lower,digits),
         " | midpoint=",
         DoubleToString(ob.midpoint,digits),
         " | formation shift=",
         ob.formationShift
      );
   }
   else
   {
      Print(
         "[ORDER BLOCK] No matching order block detected."
      );
   }
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit(

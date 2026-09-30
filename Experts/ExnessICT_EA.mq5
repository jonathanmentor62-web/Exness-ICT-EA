//+------------------------------------------------------------------+
//|                                             ExnessICT_EA.mq5     |
//|                     Exness ICT Automated Trading System          |
//+------------------------------------------------------------------+
#property strict
#property version   "0.30"
#property description "H4 ICT framework with M15 confirmation."
#property description "Trading remains disabled during development."

//====================================================================
// STANDARD MT5 TRADE LIBRARY
//====================================================================
#include <Trade/Trade.mqh>

//====================================================================
// EA MODULES
// IMPORTANT: include order matters.
// StructureSignal provides displacement functions used by
// OrderBlock.mqh.
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
// MUST REMAIN FALSE UNTIL FULL TESTING IS COMPLETE.
input bool InpEnableTrading = false;

//====================================================================
// STRUCTURE / ZONE SCANNING
//====================================================================
input int InpStructureLookback = ICT_STRUCTURE_LOOKBACK;
input int InpFVGScanLookback   = 20;
input int InpOBScanLookback    = ICT_OB_LOOKBACK;

//====================================================================
// PROCESS CONTROL
//====================================================================
datetime g_lastPrimaryBar = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetDeviationInPoints(InpDeviationPts);

   Print("==================================================");
   Print("Exness ICT EA v0.30 initialized");
   Print("Symbol: ", _Symbol);
   Print("Primary timeframe: ", EnumToString(InpPrimaryTF));
   Print("Confirmation timeframe: ", EnumToString(InpConfirmTF));
   Print(
      "Maximum planned risk: $",
      DoubleToString(InpMaxRiskMoney, 2)
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

   //--- Safety enforcement.
   if(!InpEnableTrading)
      Print("[SAFETY] Trading is DISABLED.");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
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
   // DEVELOPMENT MODE
   //===============================================================
   // We process once per new H4 candle.
   //
   // This is intentional at this stage. We are validating the
   // analytical modules before implementing live entry execution.
   //===============================================================

   datetime primaryBar =
      iTime(_Symbol, InpPrimaryTF, 0);

   if(primaryBar <= 0)
      return;

   //--- Only process each new primary candle once.
   if(primaryBar == g_lastPrimaryBar)
      return;

   g_lastPrimaryBar = primaryBar;

   Print("--------------------------------------------------");
   Print(
      "[NEW PRIMARY BAR] ",
      _Symbol,
      " | ",
      EnumToString(InpPrimaryTF),
      " | ",
      TimeToString(
         primaryBar,
         TIME_DATE | TIME_MINUTES
      )
   );

   //===============================================================
   // H4 ANALYSIS
   //===============================================================
   AnalyzePrimaryStructure(_Symbol);

   AnalyzePrimarySignal(_Symbol);

   AnalyzePrimaryZones(_Symbol);

   //===============================================================
   // M15 DEVELOPMENT ANALYSIS
   //===============================================================
   AnalyzeConfirmationStructure(_Symbol);

   //===============================================================
   // SAFETY STOP
   //===============================================================
   // NO TRADE EXECUTION IS PERMITTED IN THIS VERSION.
   //===============================================================
   if(!InpEnableTrading)
      return;

   //===============================================================
   // FUTURE LIVE PIPELINE
   //===============================================================
   //
   // 1. H4 directional context
   // 2. H4 liquidity target
   // 3. H4 liquidity sweep
   // 4. H4 displacement
   // 5. H4 MSS / BOS
   // 6. H4 FVG / Order Block
   // 7. M15 directional confirmation
   // 8. M15 liquidity event
   // 9. M15 displacement
   // 10. M15 MSS / BOS
   // 11. M15 FVG / Order Block entry zone
   // 12. Structural stop loss
   // 13. Position sizing <= $2 planned risk
   // 14. Logical liquidity target
   // 15. Reward/risk validation
   // 16. Spread validation
   // 17. Exposure validation
   // 18. Trade execution
   // 19. Position management
   //
   // NONE OF THIS EXECUTES YET.
   //===============================================================
}

//+------------------------------------------------------------------+
//| Analyze H4 structure                                             |
//+------------------------------------------------------------------+
void AnalyzePrimaryStructure(const string symbol)
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
      Bars(symbol, InpPrimaryTF);

   if(barsAvailable < ICT_MIN_HISTORY_BARS)
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
      DoubleToString(swingHigh, digits),
      " | swing low=",
      DoubleToString(swingLow, digits)
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
      Print("[LIQUIDITY] No valid buy-side level.");
   }

   //===============================================================
   // SELL-SIDE LIQUIDITY
   //===============================================================
   LiquidityLevel sellSide =
      GetSellSideLiquidity(
         symbol,
         InpPrimaryTF,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   if(sellSide.valid)
   {
      Print(
         "[LIQUIDITY] Sell-side=",
         DoubleToString(
            sellSide.price,
            digits
         ),
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
//| Analyze H4 displacement / MSS / BOS                              |
//+------------------------------------------------------------------+
void AnalyzePrimarySignal(const string symbol)
{
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
         "[H4 SIGNAL] No valid structure event on ",
         symbol
      );
      return;
   }

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
      " | previous structure=",
      StructureDirectionToString(
         signal.previousStructure
      ),
      " | broken level=",
      DoubleToString(
         signal.brokenLevel,
         digits
      )
   );

   Print(
      "[H4 DISPLACEMENT] bullish=",
      signal.bullishDisplacement,
      " | bearish=",
      signal.bearishDisplacement
   );
}

//+------------------------------------------------------------------+
//| Analyze H4 FVG and Order Block                                   |
//+------------------------------------------------------------------+
void AnalyzePrimaryZones(const string symbol)
{
   const int signalShift = 1;

   //===============================================================
   // FVG
   //===============================================================
   FVGZone fvg;

   if(DetectFVG(
      symbol,
      InpPrimaryTF,
      signalShift,
      fvg
   ))
   {
      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );

      Print(
         "[FVG] ",
         symbol,
         " | direction=",
         FVGDirectionToString(fvg.direction),
         " | status=",
         FVGStatusToString(fvg.status),
         " | upper=",
         DoubleToString(fvg.upper, digits),
         " | lower=",
         DoubleToString(fvg.lower, digits),
         " | midpoint=",
         DoubleToString(fvg.midpoint, digits),
         " | size=",
         DoubleToString(fvg.size, digits)
      );
   }
   else
   {
      Print(
         "[FVG] No valid FVG detected on latest closed ",
         EnumToString(InpPrimaryTF),
         " candle."
      );
   }

   //===============================================================
   // ORDER BLOCK
   //===============================================================
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

   bool obFound = false;

   if(signal.bullishDisplacement)
   {
      obFound =
         FindBullishOrderBlock(
            symbol,
            InpPrimaryTF,
            signalShift,
            InpOBScanLookback,
            ob
         );
   }
   else
   if(signal.bearishDisplacement)
   {
      obFound =
         FindBearishOrderBlock(
            symbol,
            InpPrimaryTF,
            signalShift,
            InpOBScanLookback,
            ob
         );
   }

   if(obFound)
   {
      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );

      Print(
         "[ORDER BLOCK] ",
         symbol,
         " | direction=",
         OrderBlockDirectionToString(
            ob.direction
         ),
         " | status=",
         OrderBlockStatusToString(
            ob.status
         ),
         " | upper=",
         DoubleToString(ob.upper, digits),
         " | lower=",
         DoubleToString(ob.lower, digits),
         " | midpoint=",
         DoubleToString(ob.midpoint, digits),
         " | size=",
         DoubleToString(ob.size, digits),
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
//| Analyze M15 confirmation structure                               |
//+------------------------------------------------------------------+
void AnalyzeConfirmationStructure(
   const string symbol
)
{
   if(!IsSymbolTradable(symbol))
      return;

   int barsAvailable =
      Bars(symbol, InpConfirmTF);

   if(barsAvailable < ICT_MIN_HISTORY_BARS)
   {
      Print(
         "[M15] Not enough confirmation history. bars=",
         barsAvailable
      );
      return;
   }

   StructureSignal signal =
      AnalyzeStructureSignal(
         symbol,
         InpConfirmTF,
         1,
         InpStructureLookback,
         ICT_SWING_LEFT,
         ICT_SWING_RIGHT
      );

   if(!signal.valid)
   {
      Print(
         "[M15] No confirmed structure event on latest closed ",
         EnumToString(InpConfirmTF),
         " candle."
      );
      return;
   }

   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   Print(
      "[M15] event=",
      StructureEventToString(signal.event),
      " | previous structure=",
      StructureDirectionToString(
         signal.previousStructure
      ),
      " | broken level=",
      DoubleToString(
         signal.brokenLevel,
         digits
      ),
      " | bullish displacement=",
      signal.bullishDisplacement,
      " | bearish displacement=",
      signal.bearishDisplacement
   );
}

//+------------------------------------------------------------------+
//| Check whether spread is acceptable                               |
//+------------------------------------------------------------------+
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
      return(false);

   return(
      spread <= InpMaxSpreadPts
   );
}

//+------------------------------------------------------------------+
//| Maximum permitted planned risk                                   |
//+------------------------------------------------------------------+
double GetMaxRiskMoney()
{
   return(InpMaxRiskMoney);
}

//+------------------------------------------------------------------+
//| Check whether symbol is available for trading                    |
//+------------------------------------------------------------------+
bool IsSymbolTradable(
   const string symbol
)
{
   if(!SymbolSelect(symbol,true))
      return(false);

   long tradeMode = 0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_MODE,
      tradeMode
   ))
      return(false);

   return(
      tradeMode != SYMBOL_TRADE_MODE_DISABLED
   );
}
//+------------------------------------------------------------------+

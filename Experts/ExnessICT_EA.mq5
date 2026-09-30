//+------------------------------------------------------------------+
//|                                             ExnessICT_EA.mq5     |
//|                     Exness ICT Automated Trading System          |
//+------------------------------------------------------------------+
#property strict
#property version   "0.20"
#property description "H4 ICT framework with M15 confirmation."
#property description "Trading remains disabled during development."

#include <Trade/Trade.mqh>
#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"

CTrade Trade;

//--- User configuration
input ENUM_TIMEFRAMES InpPrimaryTF     = ICT_PRIMARY_TF;
input ENUM_TIMEFRAMES InpConfirmTF     = ICT_CONFIRM_TF;
input double          InpMaxRiskMoney  = ICT_MAX_RISK_MONEY;

input ulong           InpMagicNumber   = ICT_MAGIC_NUMBER;
input int             InpMaxSpreadPts = ICT_MAX_SPREAD_PTS;
input int             InpDeviationPts  = ICT_MAX_SLIPPAGE_PTS;

//--- Safety switch
input bool            InpEnableTrading = false;

//--- Structure scan
input int             InpStructureLookback = 100;

//--- Prevent repeated processing of the same H4 candle
datetime g_lastPrimaryBar = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetDeviationInPoints(InpDeviationPts);

   Print("==========================================");
   Print("Exness ICT EA v0.20 initialized");
   Print("Symbol: ", _Symbol);
   Print("Primary timeframe: ", EnumToString(InpPrimaryTF));
   Print("Confirmation timeframe: ", EnumToString(InpConfirmTF));
   Print("Maximum planned risk: ", DoubleToString(InpMaxRiskMoney, 2));
   Print("Trading enabled: ", InpEnableTrading);
   Print("==========================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Exness ICT EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Only process a newly closed/formed primary candle once.
   datetime primaryBar = iTime(_Symbol, InpPrimaryTF, 0);

   if(primaryBar <= 0)
      return;

   if(primaryBar == g_lastPrimaryBar)
      return;

   g_lastPrimaryBar = primaryBar;

   //--- Development diagnostics.
   AnalyzePrimaryStructure(_Symbol);

   //--- Trading is intentionally disabled.
   if(!InpEnableTrading)
      return;

   //================================================================
   // FUTURE LIVE PIPELINE
   //
   // 1. H4 bias
   // 2. H4 liquidity
   // 3. Liquidity sweep
   // 4. Displacement
   // 5. H4/M15 MSS
   // 6. FVG / Order Block
   // 7. M15 confirmation
   // 8. Structural SL
   // 9. <= $2 risk sizing
   // 10. Liquidity TP
   // 11. Safety gates
   // 12. Execution
   // 13. Position management
   //================================================================
}

//+------------------------------------------------------------------+
//| Analyze current H4 structure                                     |
//+------------------------------------------------------------------+
void AnalyzePrimaryStructure(const string symbol)
{
   if(!IsSymbolTradable(symbol))
   {
      Print("[STRUCTURE] Symbol not tradable: ", symbol);
      return;
   }

   int swingHighShift = FindRecentSwingHigh(
      symbol,
      InpPrimaryTF,
      ICT_SWING_RIGHT + 1,
      InpStructureLookback,
      ICT_SWING_LEFT,
      ICT_SWING_RIGHT
   );

   int swingLowShift = FindRecentSwingLow(
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
      swingHigh = iHigh(symbol, InpPrimaryTF, swingHighShift);

   if(swingLowShift >= 0)
      swingLow = iLow(symbol, InpPrimaryTF, swingLowShift);

   Print(
      "[STRUCTURE] ",
      symbol,
      " | H4 swing high=",
      DoubleToString(swingHigh, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
      " | H4 swing low=",
      DoubleToString(swingLow, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS))
   );
}

//+------------------------------------------------------------------+
//| Check whether spread is acceptable                               |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable(const string symbol)
{
   long spread = 0;

   if(!SymbolInfoInteger(symbol, SYMBOL_SPREAD, spread))
      return(false);

   return(spread <= InpMaxSpreadPts);
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
bool IsSymbolTradable(const string symbol)
{
   if(!SymbolSelect(symbol, true))
      return(false);

   long tradeMode = 0;

   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeMode))
      return(false);

   return(tradeMode != SYMBOL_TRADE_MODE_DISABLED);
}
//+------------------------------------------------------------------+

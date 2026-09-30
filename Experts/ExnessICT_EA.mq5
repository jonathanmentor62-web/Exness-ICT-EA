//+------------------------------------------------------------------+
//|                                             ExnessICT_EA.mq5     |
//|                     Exness ICT Automated Trading System          |
//+------------------------------------------------------------------+
#property strict
#property version   "0.21"
#property description "H4 ICT framework with M15 confirmation."
#property description "Trading remains disabled during development."

#include <Trade/Trade.mqh>
#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/Liquidity.mqh"

CTrade Trade;

//--- User configuration
input ENUM_TIMEFRAMES InpPrimaryTF     = ICT_PRIMARY_TF;
input ENUM_TIMEFRAMES InpConfirmTF     = ICT_CONFIRM_TF;
input double          InpMaxRiskMoney  = ICT_MAX_RISK_MONEY;

input ulong           InpMagicNumber   = ICT_MAGIC_NUMBER;
input int             InpMaxSpreadPts  = ICT_MAX_SPREAD_PTS;
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
   Print("Exness ICT EA v0.21 initialized");
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
   datetime primaryBar = iTime(_Symbol, InpPrimaryTF, 0);

   if(primaryBar <= 0)
      return;

   //--- Only process each new primary candle once.
   if(primaryBar == g_lastPrimaryBar)
      return;

   g_lastPrimaryBar = primaryBar;

   //--- Development diagnostics.
   AnalyzePrimaryStructure(_Symbol);

   //--- Trading remains disabled during development.
   if(!InpEnableTrading)
      return;

   //================================================================
   // FUTURE LIVE PIPELINE
   //
   // 1. H4 directional context
   // 2. H4 liquidity
   // 3. Liquidity sweep
   // 4. Displacement
   // 5. MSS / BOS
   // 6. FVG / Order Block
   // 7. M15 confirmation
   // 8. Structural stop loss
   // 9. Position sizing <= $2 planned risk
   // 10. Logical liquidity target
   // 11. Risk / spread / exposure safety
   // 12. Trade execution
   // 13. Position management
   //================================================================
}

//+------------------------------------------------------------------+
//| Analyze current primary timeframe structure                      |
//+------------------------------------------------------------------+
void AnalyzePrimaryStructure(const string symbol)
{
   if(!IsSymbolTradable(symbol))
   {
      Print("[STRUCTURE] Symbol not tradable: ", symbol);
      return;
   }

   int barsAvailable = Bars(symbol, InpPrimaryTF);

   if(barsAvailable <= ICT_SWING_RIGHT + ICT_SWING_LEFT + 5)
   {
      Print("[STRUCTURE] Not enough history for ", symbol);
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

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   Print(
      "[STRUCTURE] ",
      symbol,
      " | ",
      EnumToString(InpPrimaryTF),
      " swing high=",
      DoubleToString(swingHigh, digits),
      " | swing low=",
      DoubleToString(swingLow, digits)
   );

   //--- Development liquidity diagnostics.
   LiquidityLevel buySide = GetBuySideLiquidity(
      symbol,
      InpPrimaryTF,
      InpStructureLookback,
      ICT_SWING_LEFT,
      ICT_SWING_RIGHT
   );

   LiquidityLevel sellSide = GetSellSideLiquidity(
      symbol,
      InpPrimaryTF,
      InpStructureLookback,
      ICT_SWING_LEFT,
      ICT_SWING_RIGHT
   );

   if(buySide.valid)
   {
      Print(
         "[LIQUIDITY] Buy-side liquidity=",
         DoubleToString(buySide.price, digits),
         " | shift=",
         buySide.shift
      );
   }

   if(sellSide.valid)
   {
      Print(
         "[LIQUIDITY] Sell-side liquidity=",
         DoubleToString(sellSide.price, digits),
         " | shift=",
         sellSide.shift
      );
   }
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

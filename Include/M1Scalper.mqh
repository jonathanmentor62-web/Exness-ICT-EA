//+------------------------------------------------------------------+
//| M1Scalper.mqh - Scalping removed                                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_M1_SCALPER_MQH__
#define __EXNESS_GOLD_M1_SCALPER_MQH__

#include "Config.mqh"

//==================================================================
// LEGACY M1 SCALPER SIGNAL
//==================================================================
//
// The original M1 reactive scalper has been removed.
//
// The new Gold Multi-Strategy EA does NOT use:
// - M1 entries
// - M1 momentum scalping
// - tick-pressure scalping
// - rapid reversal trades
// - M1 ATR-based scalp targets
// - M1 stacking
//
// M5 is now the lowest trading-analysis timeframe and is used only
// for entry confirmation/retest after the higher-timeframe analysis.
//==================================================================

struct M1ScalpSignal
{
   bool valid;

   ENUM_ORDER_TYPE orderType;

   double score;

   double atr;

   double entry;

   double stopLoss;

   double takeProfit;

   datetime barTime;

   string reason;
};


//==================================================================
// RESET
//==================================================================

void ResetM1ScalpSignal(
   M1ScalpSignal &s
)
{
   s.valid=false;

   s.orderType=ORDER_TYPE_BUY;

   s.score=0.0;

   s.atr=0.0;

   s.entry=0.0;

   s.stopLoss=0.0;

   s.takeProfit=0.0;

   s.barTime=0;

   s.reason="";
}


//==================================================================
// LEGACY SIGNAL FUNCTION
//==================================================================
//
// Always returns false.
//
// This prevents any remaining legacy reference from generating an
// M1 trade while the main EA is being rebuilt.
//==================================================================

bool M1_BuildSignal(
   const string symbol,
   M1ScalpSignal &out
)
{
   ResetM1ScalpSignal(out);

   // M1 scalping has been permanently disabled.
   return(false);
}

#endif
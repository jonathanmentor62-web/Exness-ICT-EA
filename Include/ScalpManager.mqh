//+------------------------------------------------------------------+
//| ScalpManager.mqh                                                 |
//| Gold Multi-Strategy EA - Scalping Removed                       |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_SCALP_MANAGER_MQH__
#define __EXNESS_GOLD_SCALP_MANAGER_MQH__

#include "Config.mqh"

//====================================================================
// SCALPING STATUS
//====================================================================
//
// The previous M1 scalping system has been removed.
//
// This compatibility layer intentionally contains NO:
// - M1 entries
// - M1 signals
// - rapid stacking
// - scalper cooldown
// - scalper exits
// - scalper position management
//
// The new EA will use H4/H1/M15/M5 confirmation instead.
//====================================================================

bool SM_IsEnabled()
{
   return false;
}

//====================================================================
// LEGACY PROCESS FUNCTION
//====================================================================
//
// Kept temporarily so an old reference cannot accidentally create
// scalping behaviour.
//
//====================================================================

void SM_ProcessSymbol(
   const string symbol
)
{
   // Intentionally disabled.
   return;
}

//====================================================================
// LEGACY ENTRY FUNCTION
//====================================================================

bool SM_TryEntry(
   const string symbol
)
{
   // Scalping has been permanently removed.
   return false;
}

//====================================================================
// LEGACY MANAGEMENT FUNCTION
//====================================================================

int SM_ManageAll()
{
   // No scalper positions are managed.
   return 0;
}

//====================================================================
// LEGACY BAR FUNCTION
//====================================================================

bool SM_IsNewM1Bar(
   const string symbol
)
{
   // M1 is no longer used by the trading architecture.
   return false;
}

#endif
#ifndef __EXNESS_ICT_M5_CONFIRMATION_MQH__
#define __EXNESS_ICT_M5_CONFIRMATION_MQH__

#include "StructureSignal.mqh"

struct M5Confirmation
{
   bool valid;
   bool bullish;
   bool bearish;
   bool displacement;
   bool structureBreak;
   bool mss;
   bool bos;

   double brokenLevel;
   datetime signalTime;
   int signalShift;
};

void ResetM5Confirmation(M5Confirmation &c)
{
   c.valid          = false;
   c.bullish        = false;
   c.bearish        = false;
   c.displacement   = false;
   c.structureBreak = false;
   c.mss            = false;
   c.bos            = false;
   c.brokenLevel    = 0.0;
   c.signalTime     = 0;
   c.signalShift    = -1;
}

bool AnalyzeM5Confirmation(
   string symbol,
   int higherTimeframeDirection,
   M5Confirmation &confirmation
)
{
   ResetM5Confirmation(confirmation);

   if(symbol == "")
      return false;

   // Only closed M5 candles.
   const int signalShift = 1;

   StructureSignal signal;

   if(!AnalyzeStructureSignal(
      symbol,
      PERIOD_M5,
      signalShift,
      signal
   ))
      return false;

   if(!signal.valid)
      return false;

   int direction = GetSignalDirection(signal);

   // M5 must agree with the higher-timeframe setup.
   if(higherTimeframeDirection != 0 &&
      direction != higherTimeframeDirection)
      return false;

   confirmation.valid          = true;
   confirmation.bullish        = signal.bullishDisplacement;
   confirmation.bearish        = signal.bearishDisplacement;
   confirmation.displacement   =
      signal.bullishDisplacement ||
      signal.bearishDisplacement;

   confirmation.structureBreak =
      signal.bullishMSS ||
      signal.bearishMSS ||
      signal.bullishBOS ||
      signal.bearishBOS;

   confirmation.mss =
      signal.bullishMSS ||
      signal.bearishMSS;

   confirmation.bos =
      signal.bullishBOS ||
      signal.bearishBOS;

   confirmation.brokenLevel =
      signal.brokenLevel;

   confirmation.signalTime =
      signal.signalTime;

   confirmation.signalShift =
      signal.signalShift;

   return true;
}

#endif
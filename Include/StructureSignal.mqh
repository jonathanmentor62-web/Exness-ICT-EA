//+------------------------------------------------------------------+
//| StructureSignal.mqh                                              |
//| ICT market-structure and displacement signal detection          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__
#define __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__

#include "MarketStructure.mqh"

//====================================================================
// STRUCTURE EVENT
//====================================================================

enum ENUM_STRUCTURE_EVENT
{
   STRUCTURE_EVENT_NONE = 0,
   STRUCTURE_EVENT_BULLISH_MSS,
   STRUCTURE_EVENT_BEARISH_MSS,
   STRUCTURE_EVENT_BULLISH_BOS,
   STRUCTURE_EVENT_BEARISH_BOS
};


//====================================================================
// STRUCTURE SIGNAL
//====================================================================

struct StructureSignal
{
   bool     valid;

   // Directional displacement.
   bool     bullishDisplacement;
   bool     bearishDisplacement;

   // Market Structure Shift.
   bool     bullishMSS;
   bool     bearishMSS;

   // Break of Structure.
   bool     bullishBOS;
   bool     bearishBOS;

   // Detected event.
   ENUM_STRUCTURE_EVENT event;

   // Structure before the break.
   int      previousStructure;

   // Price level that was broken.
   double   brokenLevel;

   // Time of the signal candle.
   datetime signalTime;

   // Shift of the signal candle.
   int      signalShift;
};


//====================================================================
// SIGNAL RESET
//====================================================================

void ResetStructureSignal(StructureSignal &signal)
{
   signal.valid = false;

   signal.bullishDisplacement = false;
   signal.bearishDisplacement = false;

   signal.bullishMSS = false;
   signal.bearishMSS = false;

   signal.bullishBOS = false;
   signal.bearishBOS = false;

   signal.event = STRUCTURE_EVENT_NONE;

   signal.previousStructure = 0;

   signal.brokenLevel = 0.0;

   signal.signalTime = 0;

   signal.signalShift = -1;
}


//====================================================================
// CANDLE HELPERS
//====================================================================

// Candle range.
double SS_CandleRange(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double high = iHigh(symbol, timeframe, shift);
   double low  = iLow(symbol, timeframe, shift);

   return high - low;
}


// Candle body.
double SS_CandleBody(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);

   return MathAbs(close - open);
}


// Candle direction.
//
//  1 = bullish
// -1 = bearish
//  0 = neutral/doji
int SS_CandleDirection(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);

   if(close > open)
      return 1;

   if(close < open)
      return -1;

   return 0;
}


//====================================================================
// DISPLACEMENT
//====================================================================

// Generic displacement check.
//
// A displacement candle must have:
// - valid range
// - sufficiently large body relative to range
// - directional candle
bool IsDisplacementCandle(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumBodyRatio
)
{
   double range = SS_CandleRange(
      symbol,
      timeframe,
      shift
   );

   if(range <= 0.0)
      return false;

   double body = SS_CandleBody(
      symbol,
      timeframe,
      shift
   );

   if(body <= 0.0)
      return false;

   double ratio = body / range;

   if(ratio < minimumBodyRatio)
      return false;

   return true;
}


// Bullish displacement.
bool IsBullishDisplacement(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumBodyRatio
)
{
   if(!IsDisplacementCandle(
      symbol,
      timeframe,
      shift,
      minimumBodyRatio
   ))
   {
      return false;
   }

   return SS_CandleDirection(
      symbol,
      timeframe,
      shift
   ) > 0;
}


// Bearish displacement.
bool IsBearishDisplacement(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double minimumBodyRatio
)
{
   if(!IsDisplacementCandle(
      symbol,
      timeframe,
      shift,
      minimumBodyRatio
   ))
   {
      return false;
   }

   return SS_CandleDirection(
      symbol,
      timeframe,
      shift
   ) < 0;
}


//====================================================================
// PRE-SIGNAL STRUCTURE
//====================================================================

// Determine the market structure immediately before the signal.
//
//  1 = bullish
// -1 = bearish
//  0 = neutral
//
// This is intentionally based on the confirmed swing structure
// BEFORE the signal candle, not on the signal candle itself.
int GetPreSignalStructure(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint recentHigh;
   SwingPoint previousHigh;
   SwingPoint recentLow;
   SwingPoint previousLow;

   bool haveHighs =
      FindRecentSwingHigh(
         symbol,
         timeframe,
         lookback,
         leftBars,
         rightBars,
         recentHigh
      )
      &&
      FindPreviousSwingHigh(
         symbol,
         timeframe,
         recentHigh.shift,
         lookback,
         leftBars,
         rightBars,
         previousHigh
      );

   bool haveLows =
      FindRecentSwingLow(
         symbol,
         timeframe,
         lookback,
         leftBars,
         rightBars,
         recentLow
      )
      &&
      FindPreviousSwingLow(
         symbol,
         timeframe,
         recentLow.shift,
         lookback,
         leftBars,
         rightBars,
         previousLow
      );

   bool bullishStructure = false;
   bool bearishStructure = false;

   if(haveHighs && haveLows)
   {
      bullishStructure =
         recentHigh.price > previousHigh.price &&
         recentLow.price  > previousLow.price;

      bearishStructure =
         recentHigh.price < previousHigh.price &&
         recentLow.price  < previousLow.price;
   }

   if(bullishStructure)
      return 1;

   if(bearishStructure)
      return -1;

   return 0;
}


//====================================================================
// BULLISH STRUCTURE BREAK
//====================================================================

// Detect a bullish break of the latest confirmed swing high.
//
// A bullish close above the swing high is required.
bool DetectBullishStructureBreak(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars,
   double &brokenLevel
)
{
   brokenLevel = 0.0;

   SwingPoint swingHigh;

   if(!FindRecentSwingHigh(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swingHigh
   ))
   {
      return false;
   }

   // Do not allow the signal candle itself to be used as the
   // swing candle.
   if(swingHigh.shift <= signalShift)
      return false;

   double closePrice =
      iClose(symbol, timeframe, signalShift);

   if(closePrice <= 0.0)
      return false;

   if(closePrice <= swingHigh.price)
      return false;

   brokenLevel = swingHigh.price;

   return true;
}


//====================================================================
// BEARISH STRUCTURE BREAK
//====================================================================

// Detect a bearish break of the latest confirmed swing low.
bool DetectBearishStructureBreak(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars,
   double &brokenLevel
)
{
   brokenLevel = 0.0;

   SwingPoint swingLow;

   if(!FindRecentSwingLow(
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swingLow
   ))
   {
      return false;
   }

   // Do not allow the signal candle itself to be used as the
   // swing candle.
   if(swingLow.shift <= signalShift)
      return false;

   double closePrice =
      iClose(symbol, timeframe, signalShift);

   if(closePrice <= 0.0)
      return false;

   if(closePrice >= swingLow.price)
      return false;

   brokenLevel = swingLow.price;

   return true;
}


//====================================================================
// MAIN STRUCTURE ANALYSIS
//====================================================================

bool AnalyzeStructureSignal(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int signalShift,
   int lookback,
   int leftBars,
   int rightBars,
   double minimumBodyRatio,
   StructureSignal &signal
)
{
   ResetStructureSignal(signal);

   if(signalShift < 1)
      return false;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(signalShift >= bars)
      return false;

   // ---------------------------------------------------------------
   // Step 1: Detect displacement.
   // ---------------------------------------------------------------

   signal.bullishDisplacement =
      IsBullishDisplacement(
         symbol,
         timeframe,
         signalShift,
         minimumBodyRatio
      );

   signal.bearishDisplacement =
      IsBearishDisplacement(
         symbol,
         timeframe,
         signalShift,
         minimumBodyRatio
      );

   // No displacement = no ICT structure signal.
   if(
      !signal.bullishDisplacement &&
      !signal.bearishDisplacement
   )
   {
      return false;
   }


   // ---------------------------------------------------------------
   // Step 2: Determine structure before the break.
   // ---------------------------------------------------------------

   signal.previousStructure =
      GetPreSignalStructure(
         symbol,
         timeframe,
         signalShift,
         lookback,
         leftBars,
         rightBars
      );


   // ---------------------------------------------------------------
   // Step 3: Detect bullish break.
   // ---------------------------------------------------------------

   double bullishBrokenLevel = 0.0;

   bool bullishBreak =
      DetectBullishStructureBreak(
         symbol,
         timeframe,
         signalShift,
         lookback,
         leftBars,
         rightBars,
         bullishBrokenLevel
      );


   // ---------------------------------------------------------------
   // Step 4: Detect bearish break.
   // ---------------------------------------------------------------

   double bearishBrokenLevel = 0.0;

   bool bearishBreak =
      DetectBearishStructureBreak(
         symbol,
         timeframe,
         signalShift,
         lookback,
         leftBars,
         rightBars,
         bearishBrokenLevel
      );


   // ---------------------------------------------------------------
   // Step 5: Require directional agreement.
   //
   // Bullish displacement must break upward.
   // Bearish displacement must break downward.
   // ---------------------------------------------------------------

   bool bullishSignal =
      signal.bullishDisplacement &&
      bullishBreak;

   bool bearishSignal =
      signal.bearishDisplacement &&
      bearishBreak;


   // ---------------------------------------------------------------
   // Step 6: Classify MSS vs BOS.
   //
   // MSS:
   //   break against the existing structure.
   //
   // BOS:
   //   break in the direction of the existing structure.
   //
   // If structure is neutral/unclear, classify the directional
   // structure break as BOS rather than inventing an MSS.
   // ---------------------------------------------------------------

   if(bullishSignal)
   {
      signal.brokenLevel = bullishBrokenLevel;

      if(signal.previousStructure < 0)
      {
         signal.bullishMSS = true;
         signal.event = STRUCTURE_EVENT_BULLISH_MSS;
      }
      else
      {
         signal.bullishBOS = true;
         signal.event = STRUCTURE_EVENT_BULLISH_BOS;
      }
   }
   else if(bearishSignal)
   {
      signal.brokenLevel = bearishBrokenLevel;

      if(signal.previousStructure > 0)
      {
         signal.bearishMSS = true;
         signal.event = STRUCTURE_EVENT_BEARISH_MSS;
      }
      else
      {
         signal.bearishBOS = true;
         signal.event = STRUCTURE_EVENT_BEARISH_BOS;
      }
   }
   else
   {
      return false;
   }


   // ---------------------------------------------------------------
   // Step 7: Store signal metadata.
   // ---------------------------------------------------------------

   signal.signalShift = signalShift;

   signal.signalTime =
      iTime(
         symbol,
         timeframe,
         signalShift
      );

   signal.valid = true;

   return true;
}


//====================================================================
// SIGNAL DIRECTION
//====================================================================

// Returns:
//
//  1 = bullish
// -1 = bearish
//  0 = no direction
int GetSignalDirection(
   StructureSignal &signal
)
{
   if(signal.bullishMSS || signal.bullishBOS)
      return 1;

   if(signal.bearishMSS || signal.bearishBOS)
      return -1;

   return 0;
}


//====================================================================
// SIGNAL TYPE HELPERS
//====================================================================

bool IsMSSSignal(
   StructureSignal &signal
)
{
   return
      signal.bullishMSS ||
      signal.bearishMSS;
}


bool IsBOSSignal(
   StructureSignal &signal
)
{
   return
      signal.bullishBOS ||
      signal.bearishBOS;
}


//====================================================================
// DIRECTIONAL VALIDATION
//====================================================================

// Confirm that a signal contains bullish displacement AND
// bullish structure.
bool HasBullishDisplacementAndStructure(
   StructureSignal &signal
)
{
   return
      signal.valid &&
      signal.bullishDisplacement &&
      (
         signal.bullishMSS ||
         signal.bullishBOS
      );
}


// Confirm that a signal contains bearish displacement AND
// bearish structure.
bool HasBearishDisplacementAndStructure(
   StructureSignal &signal
)
{
   return
      signal.valid &&
      signal.bearishDisplacement &&
      (
         signal.bearishMSS ||
         signal.bearishBOS
      );
}


//====================================================================
// EVENT TO STRING
//====================================================================

string StructureEventToString(
   ENUM_STRUCTURE_EVENT event
)
{
   switch(event)
   {
      case STRUCTURE_EVENT_BULLISH_MSS:
         return "BULLISH MSS";

      case STRUCTURE_EVENT_BEARISH_MSS:
         return "BEARISH MSS";

      case STRUCTURE_EVENT_BULLISH_BOS:
         return "BULLISH BOS";

      case STRUCTURE_EVENT_BEARISH_BOS:
         return "BEARISH BOS";

      default:
         return "NONE";
   }
}


//====================================================================
// DEBUG DESCRIPTION
//====================================================================

string StructureSignalDescription(
   StructureSignal &signal
)
{
   if(!signal.valid)
      return "INVALID STRUCTURE SIGNAL";

   string direction = "NONE";

   if(GetSignalDirection(signal) > 0)
      direction = "BULLISH";
   else if(GetSignalDirection(signal) < 0)
      direction = "BEARISH";

   string eventText =
      StructureEventToString(signal.event);

   string structureText =
      MarketStructureBiasToString(
         signal.previousStructure
      );

   return StringFormat(
      "%s | Direction=%s | PreviousStructure=%s | BrokenLevel=%f | Shift=%d",
      eventText,
      direction,
      structureText,
      signal.brokenLevel,
      signal.signalShift
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
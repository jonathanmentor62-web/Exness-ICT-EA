//+------------------------------------------------------------------+
//| StructureSignal.mqh                                              |
//| Gold Multi-Strategy EA - Structure, MSS, BOS & Displacement     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_STRUCTURE_SIGNAL_MQH__
#define __EXNESS_GOLD_STRUCTURE_SIGNAL_MQH__

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
   bool valid;

   // Direction.
   int direction;

   // Candle characteristics.
   bool bullishDisplacement;
   bool bearishDisplacement;

   // Structure events.
   bool bullishMSS;
   bool bearishMSS;

   bool bullishBOS;
   bool bearishBOS;

   ENUM_STRUCTURE_EVENT event;

   // Structure before the signal.
   int previousStructure;

   // Broken structure level.
   double brokenLevel;

   // Signal candle.
   datetime signalTime;
   int signalShift;

   // Strength measurements.
   double candleRange;
   double candleBody;
   double bodyRatio;
};


//====================================================================
// RESET
//====================================================================

void ResetStructureSignal(StructureSignal &signal)
{
   signal.valid = false;

   signal.direction = 0;

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

   signal.candleRange = 0.0;
   signal.candleBody = 0.0;
   signal.bodyRatio = 0.0;
}


//====================================================================
// CANDLE DATA
//====================================================================

double SS_CandleRange(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double high = iHigh(symbol, timeframe, shift);
   double low  = iLow(symbol, timeframe, shift);

   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;

   return high - low;
}


double SS_CandleBody(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);

   if(open <= 0.0 || close <= 0.0)
      return 0.0;

   return MathAbs(close - open);
}


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

   return ratio >= minimumBodyRatio;
}


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

   if(!haveHighs || !haveLows)
      return 0;

   bool bullish =
      recentHigh.price > previousHigh.price &&
      recentLow.price  > previousLow.price;

   bool bearish =
      recentHigh.price < previousHigh.price &&
      recentLow.price  < previousLow.price;

   if(bullish)
      return 1;

   if(bearish)
      return -1;

   return 0;
}


//====================================================================
// BULLISH BREAK
//====================================================================

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

   // The swing must be older than the signal candle.
   if(swingHigh.shift <= signalShift)
      return false;

   double closePrice =
      iClose(symbol, timeframe, signalShift);

   if(closePrice <= swingHigh.price)
      return false;

   brokenLevel = swingHigh.price;

   return true;
}


//====================================================================
// BEARISH BREAK
//====================================================================

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

   if(swingLow.shift <= signalShift)
      return false;

   double closePrice =
      iClose(symbol, timeframe, signalShift);

   if(closePrice >= swingLow.price)
      return false;

   brokenLevel = swingLow.price;

   return true;
}


//====================================================================
// MAIN ANALYSIS
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

   if(bars <= signalShift)
      return false;


   // ---------------------------------------------------------------
   // Candle measurements
   // ---------------------------------------------------------------

   signal.candleRange =
      SS_CandleRange(
         symbol,
         timeframe,
         signalShift
      );

   signal.candleBody =
      SS_CandleBody(
         symbol,
         timeframe,
         signalShift
      );

   if(signal.candleRange <= 0.0)
      return false;

   signal.bodyRatio =
      signal.candleBody /
      signal.candleRange;


   // ---------------------------------------------------------------
   // Displacement
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


   // ---------------------------------------------------------------
   // Structure before signal
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
   // Structure breaks
   // ---------------------------------------------------------------

   double bullishBrokenLevel = 0.0;
   double bearishBrokenLevel = 0.0;

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
   // Bullish signal
   // ---------------------------------------------------------------

   if(
      signal.bullishDisplacement &&
      bullishBreak
   )
   {
      signal.direction = 1;
      signal.brokenLevel = bullishBrokenLevel;

      // Break against bearish structure = MSS.
      if(signal.previousStructure < 0)
      {
         signal.bullishMSS = true;
         signal.event =
            STRUCTURE_EVENT_BULLISH_MSS;
      }
      else
      {
         signal.bullishBOS = true;
         signal.event =
            STRUCTURE_EVENT_BULLISH_BOS;
      }
   }


   // ---------------------------------------------------------------
   // Bearish signal
   // ---------------------------------------------------------------

   else if(
      signal.bearishDisplacement &&
      bearishBreak
   )
   {
      signal.direction = -1;
      signal.brokenLevel = bearishBrokenLevel;

      // Break against bullish structure = MSS.
      if(signal.previousStructure > 0)
      {
         signal.bearishMSS = true;
         signal.event =
            STRUCTURE_EVENT_BEARISH_MSS;
      }
      else
      {
         signal.bearishBOS = true;
         signal.event =
            STRUCTURE_EVENT_BEARISH_BOS;
      }
   }

   else
   {
      return false;
   }


   // ---------------------------------------------------------------
   // Metadata
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
// DIRECTION
//====================================================================

int GetSignalDirection(
   StructureSignal &signal
)
{
   if(!signal.valid)
      return 0;

   return signal.direction;
}


//====================================================================
// EVENT HELPERS
//====================================================================

bool IsMSSSignal(
   StructureSignal &signal
)
{
   return
      signal.valid &&
      (
         signal.bullishMSS ||
         signal.bearishMSS
      );
}


bool IsBOSSignal(
   StructureSignal &signal
)
{
   return
      signal.valid &&
      (
         signal.bullishBOS ||
         signal.bearishBOS
      );
}


//====================================================================
// DIRECTIONAL VALIDATION
//====================================================================

bool HasBullishDisplacementAndStructure(
   StructureSignal &signal
)
{
   return
      signal.valid &&
      signal.direction > 0 &&
      signal.bullishDisplacement &&
      (
         signal.bullishMSS ||
         signal.bullishBOS
      );
}


bool HasBearishDisplacementAndStructure(
   StructureSignal &signal
)
{
   return
      signal.valid &&
      signal.direction < 0 &&
      signal.bearishDisplacement &&
      (
         signal.bearishMSS ||
         signal.bearishBOS
      );
}


//====================================================================
// EVENT STRING
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
// DESCRIPTION
//====================================================================

string StructureSignalDescription(
   StructureSignal &signal
)
{
   if(!signal.valid)
      return "INVALID STRUCTURE SIGNAL";

   string direction = "NONE";

   if(signal.direction > 0)
      direction = "BULLISH";
   else if(signal.direction < 0)
      direction = "BEARISH";

   return StringFormat(
      "%s | Direction=%s | Structure=%d | Broken=%f | BodyRatio=%.2f | Shift=%d",
      StructureEventToString(signal.event),
      direction,
      signal.previousStructure,
      signal.brokenLevel,
      signal.bodyRatio,
      signal.signalShift
   );
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
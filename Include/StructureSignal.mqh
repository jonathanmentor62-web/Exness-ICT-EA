//+------------------------------------------------------------------+
//| StructureSignal.mqh                                              |
//| Displacement + MSS + BOS detection for Exness ICT EA             |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__
#define __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__

//====================================================================
// STRUCTURE EVENT TYPES
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
   //--- Candle displacement
   bool     bullishDisplacement;
   bool     bearishDisplacement;

   //--- Market Structure Shift
   bool     bullishMSS;
   bool     bearishMSS;

   //--- Break Of Structure
   bool     bullishBOS;
   bool     bearishBOS;

   //--- Main event
   ENUM_STRUCTURE_EVENT event;

   //--- Structure direction BEFORE the signal candle
   ENUM_STRUCTURE_DIRECTION previousStructure;

   //--- Level that was broken
   double   brokenLevel;

   //--- Signal candle information
   datetime signalTime;
   int      signalShift;

   //--- Valid signal flag
   bool     valid;
};

//====================================================================
// RESET
//====================================================================

void ResetStructureSignal(
   StructureSignal &signal
)
{
   signal.bullishDisplacement = false;
   signal.bearishDisplacement = false;

   signal.bullishMSS = false;
   signal.bearishMSS = false;

   signal.bullishBOS = false;
   signal.bearishBOS = false;

   signal.event = STRUCTURE_EVENT_NONE;

   signal.previousStructure = STRUCTURE_UNKNOWN;

   signal.brokenLevel = 0.0;

   signal.signalTime = 0;
   signal.signalShift = -1;

   signal.valid = false;
}

//====================================================================
// BASIC CANDLE FUNCTIONS
//====================================================================

double GetCandleRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 0)
      return(0.0);

   double high = iHigh(
      symbol,
      timeframe,
      shift
   );

   double low = iLow(
      symbol,
      timeframe,
      shift
   );

   if(high <= 0.0 || low <= 0.0)
      return(0.0);

   double range = high - low;

   if(range <= 0.0)
      return(0.0);

   return(range);
}

//+------------------------------------------------------------------+

double GetCandleBody(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 0)
      return(0.0);

   double open = iOpen(
      symbol,
      timeframe,
      shift
   );

   double close = iClose(
      symbol,
      timeframe,
      shift
   );

   if(open <= 0.0 || close <= 0.0)
      return(0.0);

   return(MathAbs(close - open));
}

//+------------------------------------------------------------------+

double GetBodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   double range = GetCandleRange(
      symbol,
      timeframe,
      shift
   );

   if(range <= 0.0)
      return(0.0);

   double body = GetCandleBody(
      symbol,
      timeframe,
      shift
   );

   if(body <= 0.0)
      return(0.0);

   return(body / range);
}

//====================================================================
// CANDLE DIRECTION
//====================================================================

bool IsBullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 0)
      return(false);

   double open = iOpen(
      symbol,
      timeframe,
      shift
   );

   double close = iClose(
      symbol,
      timeframe,
      shift
   );

   if(open <= 0.0 || close <= 0.0)
      return(false);

   return(close > open);
}

//+------------------------------------------------------------------+

bool IsBearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 0)
      return(false);

   double open = iOpen(
      symbol,
      timeframe,
      shift
   );

   double close = iClose(
      symbol,
      timeframe,
      shift
   );

   if(open <= 0.0 || close <= 0.0)
      return(false);

   return(close < open);
}

//====================================================================
// DISPLACEMENT
//====================================================================

//+------------------------------------------------------------------+
//| Bullish displacement                                             |
//|                                                                  |
//| A closed bullish candle with a sufficiently large body relative  |
//| to its total range.                                              |
//+------------------------------------------------------------------+

bool IsBullishDisplacement(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 1)
      return(false);

   if(!IsBullishCandle(
      symbol,
      timeframe,
      shift
   ))
   {
      return(false);
   }

   double bodyRatio = GetBodyRatio(
      symbol,
      timeframe,
      shift
   );

   return(bodyRatio >= ICT_MIN_BODY_RATIO);
}

//+------------------------------------------------------------------+
//| Bearish displacement                                             |
//+------------------------------------------------------------------+

bool IsBearishDisplacement(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 1)
      return(false);

   if(!IsBearishCandle(
      symbol,
      timeframe,
      shift
   ))
   {
      return(false);
   }

   double bodyRatio = GetBodyRatio(
      symbol,
      timeframe,
      shift
   );

   return(bodyRatio >= ICT_MIN_BODY_RATIO);
}

//====================================================================
// STRUCTURE REFERENCE HELPERS
//====================================================================

//+------------------------------------------------------------------+
//| Get the most recent confirmed swing high BEFORE signal candle    |
//+------------------------------------------------------------------+

int GetSignalReferenceSwingHigh(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int signalShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(signalShift < 1)
      return(-1);

   /*
      A swing needs rightBars candles to confirm it.

      Therefore we start far enough back that the signal candle
      cannot itself participate in confirming the swing.
   */

   int startShift =
      signalShift + rightBars + 1;

   return(
      FindRecentSwingHigh(
         symbol,
         timeframe,
         startShift,
         lookback,
         leftBars,
         rightBars
      )
   );
}

//+------------------------------------------------------------------+
//| Get the most recent confirmed swing low BEFORE signal candle     |
//+------------------------------------------------------------------+

int GetSignalReferenceSwingLow(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int signalShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(signalShift < 1)
      return(-1);

   int startShift =
      signalShift + rightBars + 1;

   return(
      FindRecentSwingLow(
         symbol,
         timeframe,
         startShift,
         lookback,
         leftBars,
         rightBars
      )
   );
}

//====================================================================
// PREVIOUS ESTABLISHED STRUCTURE
//====================================================================

//+------------------------------------------------------------------+
//| Determine structure before signal candle                         |
//|                                                                  |
//| Bullish = Higher High + Higher Low                               |
//| Bearish = Lower High + Lower Low                                 |
//|                                                                  |
//| Unknown = mixed/insufficient structure                           |
//+------------------------------------------------------------------+

ENUM_STRUCTURE_DIRECTION GetPreSignalStructure(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int signalShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   if(signalShift < 1)
      return(STRUCTURE_UNKNOWN);

   int recentHigh = GetSignalReferenceSwingHigh(
      symbol,
      timeframe,
      signalShift,
      lookback,
      leftBars,
      rightBars
   );

   int recentLow = GetSignalReferenceSwingLow(
      symbol,
      timeframe,
      signalShift,
      lookback,
      leftBars,
      rightBars
   );

   if(recentHigh < 0 || recentLow < 0)
      return(STRUCTURE_UNKNOWN);

   int previousHigh =
      FindPreviousSwingHigh(
         symbol,
         timeframe,
         recentHigh,
         lookback,
         leftBars,
         rightBars
      );

   int previousLow =
      FindPreviousSwingLow(
         symbol,
         timeframe,
         recentLow,
         lookback,
         leftBars,
         rightBars
      );

   if(previousHigh < 0 || previousLow < 0)
      return(STRUCTURE_UNKNOWN);

   double recentHighPrice =
      iHigh(
         symbol,
         timeframe,
         recentHigh
      );

   double previousHighPrice =
      iHigh(
         symbol,
         timeframe,
         previousHigh
      );

   double recentLowPrice =
      iLow(
         symbol,
         timeframe,
         recentLow
      );

   double previousLowPrice =
      iLow(
         symbol,
         timeframe,
         previousLow
      );

   if(
      recentHighPrice <= 0.0 ||
      previousHighPrice <= 0.0 ||
      recentLowPrice <= 0.0 ||
      previousLowPrice <= 0.0
   )
   {
      return(STRUCTURE_UNKNOWN);
   }

   bool higherHigh =
      recentHighPrice > previousHighPrice;

   bool higherLow =
      recentLowPrice > previousLowPrice;

   bool lowerHigh =
      recentHighPrice < previousHighPrice;

   bool lowerLow =
      recentLowPrice < previousLowPrice;

   if(higherHigh && higherLow)
      return(STRUCTURE_BULLISH);

   if(lowerHigh && lowerLow)
      return(STRUCTURE_BEARISH);

   return(STRUCTURE_UNKNOWN);
}

//====================================================================
// BULLISH MSS
//====================================================================

//+------------------------------------------------------------------+
//| Bullish Market Structure Shift                                   |
//|                                                                  |
//| Definition used by this EA:                                     |
//|                                                                  |
//| 1. Previous structure is bearish.                               |
//| 2. Signal candle closes above the most recent confirmed swing   |
//|    high.                                                         |
//|                                                                  |
//| This represents a break AGAINST the previous bearish structure. |
//+------------------------------------------------------------------+

bool DetectBullishMSS(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars,
   double &brokenLevel
)
{
   brokenLevel = 0.0;

   if(candleShift < 1)
      return(false);

   ENUM_STRUCTURE_DIRECTION previousStructure =
      GetPreSignalStructure(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(previousStructure != STRUCTURE_BEARISH)
      return(false);

   int swingHighShift =
      GetSignalReferenceSwingHigh(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(swingHighShift < 0)
      return(false);

   double swingHigh =
      iHigh(
         symbol,
         timeframe,
         swingHighShift
      );

   double close =
      iClose(
         symbol,
         timeframe,
         candleShift
      );

   if(swingHigh <= 0.0 || close <= 0.0)
      return(false);

   if(close <= swingHigh)
      return(false);

   brokenLevel = swingHigh;

   return(true);
}

//====================================================================
// BEARISH MSS
//====================================================================

//+------------------------------------------------------------------+
//| Bearish Market Structure Shift                                   |
//|                                                                  |
//| 1. Previous structure is bullish.                               |
//| 2. Signal candle closes below the most recent confirmed swing   |
//|    low.                                                         |
//+------------------------------------------------------------------+

bool DetectBearishMSS(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars,
   double &brokenLevel
)
{
   brokenLevel = 0.0;

   if(candleShift < 1)
      return(false);

   ENUM_STRUCTURE_DIRECTION previousStructure =
      GetPreSignalStructure(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(previousStructure != STRUCTURE_BULLISH)
      return(false);

   int swingLowShift =
      GetSignalReferenceSwingLow(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(swingLowShift < 0)
      return(false);

   double swingLow =
      iLow(
         symbol,
         timeframe,
         swingLowShift
      );

   double close =
      iClose(
         symbol,
         timeframe,
         candleShift
      );

   if(swingLow <= 0.0 || close <= 0.0)
      return(false);

   if(close >= swingLow)
      return(false);

   brokenLevel = swingLow;

   return(true);
}

//====================================================================
// BULLISH BOS
//====================================================================

//+------------------------------------------------------------------+
//| Bullish Break Of Structure                                      |
//|                                                                  |
//| Definition used by this EA:                                     |
//|                                                                  |
//| 1. Previous structure is already bullish.                       |
//| 2. Signal candle closes above the latest confirmed swing high.  |
//|                                                                  |
//| This is continuation, NOT a market-structure shift.             |
//+------------------------------------------------------------------+

bool DetectBullishBOS(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars,
   double &brokenLevel
)
{
   brokenLevel = 0.0;

   if(candleShift < 1)
      return(false);

   ENUM_STRUCTURE_DIRECTION previousStructure =
      GetPreSignalStructure(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(previousStructure != STRUCTURE_BULLISH)
      return(false);

   int swingHighShift =
      GetSignalReferenceSwingHigh(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(swingHighShift < 0)
      return(false);

   double swingHigh =
      iHigh(
         symbol,
         timeframe,
         swingHighShift
      );

   double close =
      iClose(
         symbol,
         timeframe,
         candleShift
      );

   if(swingHigh <= 0.0 || close <= 0.0)
      return(false);

   if(close <= swingHigh)
      return(false);

   brokenLevel = swingHigh;

   return(true);
}

//====================================================================
// BEARISH BOS
//====================================================================

//+------------------------------------------------------------------+
//| Bearish Break Of Structure                                      |
//|                                                                  |
//| 1. Previous structure is already bearish.                       |
//| 2. Signal candle closes below the latest confirmed swing low.   |
//+------------------------------------------------------------------+

bool DetectBearishBOS(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars,
   double &brokenLevel
)
{
   brokenLevel = 0.0;

   if(candleShift < 1)
      return(false);

   ENUM_STRUCTURE_DIRECTION previousStructure =
      GetPreSignalStructure(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(previousStructure != STRUCTURE_BEARISH)
      return(false);

   int swingLowShift =
      GetSignalReferenceSwingLow(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars
      );

   if(swingLowShift < 0)
      return(false);

   double swingLow =
      iLow(
         symbol,
         timeframe,
         swingLowShift
      );

   double close =
      iClose(
         symbol,
         timeframe,
         candleShift
      );

   if(swingLow <= 0.0 || close <= 0.0)
      return(false);

   if(close >= swingLow)
      return(false);

   brokenLevel = swingLow;

   return(true);
}

//====================================================================
// MAIN STRUCTURE ANALYZER
//====================================================================

//+------------------------------------------------------------------+
//| Analyze a closed candle                                          |
//|                                                                  |
//| Signal priority:                                                 |
//|                                                                  |
//| 1. MSS                                                            |
//| 2. BOS                                                            |
//|                                                                  |
//| Displacement is reported independently.                         |
//+------------------------------------------------------------------+

StructureSignal AnalyzeStructureSignal(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars
)
{
   StructureSignal signal;

   ResetStructureSignal(signal);

   //--- Only closed candles are allowed.
   if(candleShift < 1)
      return(signal);

   signal.signalShift = candleShift;

   signal.signalTime =
      iTime(
         symbol,
         timeframe,
         candleShift
      );

   if(signal.signalTime <= 0)
      return(signal);

   //================================================================
   // DISPLACEMENT
   //================================================================

   signal.bullishDisplacement =
      IsBullishDisplacement(
  
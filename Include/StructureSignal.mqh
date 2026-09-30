//+------------------------------------------------------------------+
//| StructureSignal.mqh                                              |
//| Displacement + MSS/BOS detection for Exness ICT EA              |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__
#define __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__

struct StructureSignal
{
   bool     bullishDisplacement;
   bool     bearishDisplacement;

   bool     bullishMSS;
   bool     bearishMSS;

   bool     bullishBOS;
   bool     bearishBOS;

   double   brokenLevel;
   datetime signalTime;

   bool     valid;
};

//+------------------------------------------------------------------+
//| Reset signal                                                     |
//+------------------------------------------------------------------+
void ResetStructureSignal(StructureSignal &signal)
{
   signal.bullishDisplacement = false;
   signal.bearishDisplacement = false;

   signal.bullishMSS = false;
   signal.bearishMSS = false;

   signal.bullishBOS = false;
   signal.bearishBOS = false;

   signal.brokenLevel = 0.0;
   signal.signalTime = 0;

   signal.valid = false;
}

//+------------------------------------------------------------------+
//| Candle body/range ratio                                          |
//+------------------------------------------------------------------+
double GetBodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 1)
      return(0.0);

   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);
   double high  = iHigh(symbol, timeframe, shift);
   double low   = iLow(symbol, timeframe, shift);

   if(open <= 0.0 ||
      close <= 0.0 ||
      high <= 0.0 ||
      low <= 0.0)
   {
      return(0.0);
   }

   double range = high - low;

   if(range <= 0.0)
      return(0.0);

   return(MathAbs(close - open) / range);
}

//+------------------------------------------------------------------+
//| Bullish candle                                                   |
//+------------------------------------------------------------------+
bool IsBullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 1)
      return(false);

   return(
      iClose(symbol, timeframe, shift) >
      iOpen(symbol, timeframe, shift)
   );
}

//+------------------------------------------------------------------+
//| Bearish candle                                                   |
//+------------------------------------------------------------------+
bool IsBearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 1)
      return(false);

   return(
      iClose(symbol, timeframe, shift) <
      iOpen(symbol, timeframe, shift)
   );
}

//+------------------------------------------------------------------+
//| Bullish displacement                                             |
//+------------------------------------------------------------------+
bool IsBullishDisplacement(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(!IsBullishCandle(symbol, timeframe, shift))
      return(false);

   return(
      GetBodyRatio(symbol, timeframe, shift) >=
      ICT_MIN_BODY_RATIO
   );
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
   if(!IsBearishCandle(symbol, timeframe, shift))
      return(false);

   return(
      GetBodyRatio(symbol, timeframe, shift) >=
      ICT_MIN_BODY_RATIO
   );
}

//+------------------------------------------------------------------+
//| Detect bullish structural break                                  |
//+------------------------------------------------------------------+
bool DetectBullishStructureBreak(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars,
   double &brokenLevel,
   ENUM_STRUCTURE_DIRECTION &previousStructure
)
{
   brokenLevel = 0.0;
   previousStructure = STRUCTURE_UNKNOWN;

   if(candleShift < 1)
      return(false);

   int swingShift = FindRecentSwingHigh(
      symbol,
      timeframe,
      candleShift + rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(swingShift < 0)
      return(false);

   double swingHigh = iHigh(
      symbol,
      timeframe,
      swingShift
   );

   double candleClose = iClose(
      symbol,
      timeframe,
      candleShift
   );

   if(swingHigh <= 0.0 || candleClose <= 0.0)
      return(false);

   if(candleClose <= swingHigh)
      return(false);

   previousStructure = GetStructureDirection(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars
   );

   brokenLevel = swingHigh;

   return(true);
}

//+------------------------------------------------------------------+
//| Detect bearish structural break                                  |
//+------------------------------------------------------------------+
bool DetectBearishStructureBreak(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const int lookback,
   const int leftBars,
   const int rightBars,
   double &brokenLevel,
   ENUM_STRUCTURE_DIRECTION &previousStructure
)
{
   brokenLevel = 0.0;
   previousStructure = STRUCTURE_UNKNOWN;

   if(candleShift < 1)
      return(false);

   int swingShift = FindRecentSwingLow(
      symbol,
      timeframe,
      candleShift + rightBars + 1,
      lookback,
      leftBars,
      rightBars
   );

   if(swingShift < 0)
      return(false);

   double swingLow = iLow(
      symbol,
      timeframe,
      swingShift
   );

   double candleClose = iClose(
      symbol,
      timeframe,
      candleShift
   );

   if(swingLow <= 0.0 || candleClose <= 0.0)
      return(false);

   if(candleClose >= swingLow)
      return(false);

   previousStructure = GetStructureDirection(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars
   );

   brokenLevel = swingLow;

   return(true);
}

//+------------------------------------------------------------------+
//| Bullish MSS                                                      |
//| Bearish structure -> break of swing high                        |
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
   ENUM_STRUCTURE_DIRECTION previousStructure;

   if(!DetectBullishStructureBreak(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars,
      brokenLevel,
      previousStructure
   ))
   {
      return(false);
   }

   return(previousStructure == STRUCTURE_BEARISH);
}

//+------------------------------------------------------------------+
//| Bearish MSS                                                      |
//| Bullish structure -> break of swing low                         |
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
   ENUM_STRUCTURE_DIRECTION previousStructure;

   if(!DetectBearishStructureBreak(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars,
      brokenLevel,
      previousStructure
   ))
   {
      return(false);
   }

   return(previousStructure == STRUCTURE_BULLISH);
}

//+------------------------------------------------------------------+
//| Bullish BOS                                                      |
//| Bullish structure -> break of swing high                        |
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
   ENUM_STRUCTURE_DIRECTION previousStructure;

   if(!DetectBullishStructureBreak(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars,
      brokenLevel,
      previousStructure
   ))
   {
      return(false);
   }

   return(previousStructure == STRUCTURE_BULLISH);
}

//+------------------------------------------------------------------+
//| Bearish BOS                                                      |
//| Bearish structure -> break of swing low                         |
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
   ENUM_STRUCTURE_DIRECTION previousStructure;

   if(!DetectBearishStructureBreak(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars,
      brokenLevel,
      previousStructure
   ))
   {
      return(false);
   }

   return(previousStructure == STRUCTURE_BEARISH);
}

//+------------------------------------------------------------------+
//| Analyze complete structure signal                                |
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

   if(candleShift < 1)
      return(signal);

   signal.signalTime = iTime(
      symbol,
      timeframe,
      candleShift
   );

   signal.bullishDisplacement =
      IsBullishDisplacement(
         symbol,
         timeframe,
         candleShift
      );

   signal.bearishDisplacement =
      IsBearishDisplacement(
         symbol,
         timeframe,
         candleShift
      );

   double bullishMSSLevel = 0.0;
   double bearishMSSLevel = 0.0;

   double bullishBOSLevel = 0.0;
   double bearishBOSLevel = 0.0;

   signal.bullishMSS =
      DetectBullishMSS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bullishMSSLevel
      );

   signal.bearishMSS =
      DetectBearishMSS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bearishMSSLevel
      );

   signal.bullishBOS =
      DetectBullishBOS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bullishBOSLevel
      );

   signal.bearishBOS =
      DetectBearishBOS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bearishBOSLevel
      );

   //--- Select the structural event.
   if(signal.bullishMSS)
   {
      signal.brokenLevel = bullishMSSLevel;
      signal.valid = true;
   }
   else if(signal.bearishMSS)
   {
      signal.brokenLevel = bearishMSSLevel;
      signal.valid = true;
   }
   else if(signal.bullishBOS)
   {
      signal.brokenLevel = bullishBOSLevel;
      signal.valid = true;
   }
   else if(signal.bearishBOS)
   {
      signal.brokenLevel = bearishBOSLevel;
      signal.valid = true;
   }

   return(signal);
}

#endif
//+------------------------------------------------------------------+
//| StructureSignal.mqh                                              |
//| Displacement + MSS/BOS detection for Exness ICT EA              |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__
#define __EXNESS_ICT_STRUCTURE_SIGNAL_MQH__

//+------------------------------------------------------------------+
//| Signal information                                               |
//+------------------------------------------------------------------+
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
//| Initialize signal structure                                     |
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
//| Candle body ratio                                                |
//| Body / total candle range                                        |
//+------------------------------------------------------------------+
double GetBodyRatio(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(shift < 0)
      return(0.0);

   double open  = iOpen(symbol, timeframe, shift);
   double close = iClose(symbol, timeframe, shift);
   double high  = iHigh(symbol, timeframe, shift);
   double low   = iLow(symbol, timeframe, shift);

   if(open <= 0.0 || close <= 0.0 || high <= 0.0 || low <= 0.0)
      return(0.0);

   double range = high - low;

   if(range <= 0.0)
      return(0.0);

   return(MathAbs(close - open) / range);
}

//+------------------------------------------------------------------+
//| Check bullish candle                                             |
//+------------------------------------------------------------------+
bool IsBullishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   return(iClose(symbol, timeframe, shift) >
          iOpen(symbol, timeframe, shift));
}

//+------------------------------------------------------------------+
//| Check bearish candle                                             |
//+------------------------------------------------------------------+
bool IsBearishCandle(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   return(iClose(symbol, timeframe, shift) <
          iOpen(symbol, timeframe, shift));
}

//+------------------------------------------------------------------+
//| Check bullish displacement                                      |
//+------------------------------------------------------------------+
bool IsBullishDisplacement(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(!IsBullishCandle(symbol, timeframe, shift))
      return(false);

   double bodyRatio = GetBodyRatio(
      symbol,
      timeframe,
      shift
   );

   return(bodyRatio >= ICT_MIN_BODY_RATIO);
}

//+------------------------------------------------------------------+
//| Check bearish displacement                                      |
//+------------------------------------------------------------------+
bool IsBearishDisplacement(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int shift
)
{
   if(!IsBearishCandle(symbol, timeframe, shift))
      return(false);

   double bodyRatio = GetBodyRatio(
      symbol,
      timeframe,
      shift
   );

   return(bodyRatio >= ICT_MIN_BODY_RATIO);
}

//+------------------------------------------------------------------+
//| Detect bullish MSS                                              |
//| Closed candle must break the most recent confirmed swing high.  |
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

   brokenLevel = swingHigh;

   return(true);
}

//+------------------------------------------------------------------+
//| Detect bearish MSS                                               |
//| Closed candle must break the most recent confirmed swing low.   |
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

   brokenLevel = swingLow;

   return(true);
}

//+------------------------------------------------------------------+
//| Detect bullish BOS                                               |
//| Structural bullish continuation through a confirmed swing high. |
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
   return(DetectBullishMSS(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars,
      brokenLevel
   ));
}

//+------------------------------------------------------------------+
//| Detect bearish BOS                                               |
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
   return(DetectBearishMSS(
      symbol,
      timeframe,
      candleShift,
      lookback,
      leftBars,
      rightBars,
      brokenLevel
   ));
}

//+------------------------------------------------------------------+
//| Analyze displacement + structure                                 |
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

   double bullishLevel = 0.0;
   double bearishLevel = 0.0;

   signal.bullishMSS =
      DetectBullishMSS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bullishLevel
      );

   signal.bearishMSS =
      DetectBearishMSS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bearishLevel
      );

   signal.bullishBOS =
      DetectBullishBOS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bullishLevel
      );

   signal.bearishBOS =
      DetectBearishBOS(
         symbol,
         timeframe,
         candleShift,
         lookback,
         leftBars,
         rightBars,
         bearishLevel
      );

   if(signal.bullishMSS || signal.bullishBOS)
   {
      signal.brokenLevel = bullishLevel;
      signal.valid = true;
   }

   if(signal.bearishMSS || signal.bearishBOS)
   {
      signal.brokenLevel = bearishLevel;
      signal.valid = true;
   }

   return(signal);
}

#endif

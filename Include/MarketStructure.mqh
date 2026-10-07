//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Gold Multi-Strategy EA - Market Structure Engine                |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_MARKET_STRUCTURE_MQH__
#define __EXNESS_GOLD_MARKET_STRUCTURE_MQH__

//==================================================================
// STRUCTURES
//==================================================================

struct SwingPoint
{
   bool     valid;
   bool     isHigh;
   int      shift;
   datetime time;
   double   price;
};

struct MarketStructureState
{
   bool valid;

   int bias;

   bool higherHigh;
   bool higherLow;
   bool lowerHigh;
   bool lowerLow;

   bool bullishBreak;
   bool bearishBreak;

   bool bullishMSS;
   bool bearishMSS;

   double recentHigh;
   double previousHigh;
   double recentLow;
   double previousLow;

   datetime signalTime;
};


//==================================================================
// BASIC CANDLE ACCESS
//==================================================================

double MS_High(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return iHigh(symbol, timeframe, shift);
}


double MS_Low(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return iLow(symbol, timeframe, shift);
}


double MS_Open(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return iOpen(symbol, timeframe, shift);
}


double MS_Close(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return iClose(symbol, timeframe, shift);
}


datetime MS_Time(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return iTime(symbol, timeframe, shift);
}


//==================================================================
// CANDLE DIRECTION
//==================================================================

bool MS_IsBullishCandle(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double openPrice  = MS_Open(symbol,timeframe,shift);
   double closePrice = MS_Close(symbol,timeframe,shift);

   if(openPrice <= 0.0 || closePrice <= 0.0)
      return false;

   return closePrice > openPrice;
}


bool MS_IsBearishCandle(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   double openPrice  = MS_Open(symbol,timeframe,shift);
   double closePrice = MS_Close(symbol,timeframe,shift);

   if(openPrice <= 0.0 || closePrice <= 0.0)
      return false;

   return closePrice < openPrice;
}


//==================================================================
// SWING HIGH
//==================================================================

bool IsSwingHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   int leftBars,
   int rightBars
)
{
   int bars = Bars(symbol,timeframe);

   if(bars <= 0)
      return false;

   if(shift < rightBars)
      return false;

   if(shift + leftBars >= bars)
      return false;

   double candidate = MS_High(symbol,timeframe,shift);

   if(candidate <= 0.0)
      return false;

   // More recent candles.
   for(int i=1; i<=rightBars; i++)
   {
      double value = MS_High(symbol,timeframe,shift-i);

      if(value >= candidate)
         return false;
   }

   // Older candles.
   for(int i=1; i<=leftBars; i++)
   {
      double value = MS_High(symbol,timeframe,shift+i);

      if(value >= candidate)
         return false;
   }

   return true;
}


//==================================================================
// SWING LOW
//==================================================================

bool IsSwingLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   int leftBars,
   int rightBars
)
{
   int bars = Bars(symbol,timeframe);

   if(bars <= 0)
      return false;

   if(shift < rightBars)
      return false;

   if(shift + leftBars >= bars)
      return false;

   double candidate = MS_Low(symbol,timeframe,shift);

   if(candidate <= 0.0)
      return false;

   // More recent candles.
   for(int i=1; i<=rightBars; i++)
   {
      double value = MS_Low(symbol,timeframe,shift-i);

      if(value <= candidate)
         return false;
   }

   // Older candles.
   for(int i=1; i<=leftBars; i++)
   {
      double value = MS_Low(symbol,timeframe,shift+i);

      if(value <= candidate)
         return false;
   }

   return true;
}


//==================================================================
// FIND RECENT SWING HIGH
//==================================================================

bool FindRecentSwingHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   SwingPoint &result
)
{
   result.valid  = false;
   result.isHigh = true;
   result.shift  = -1;
   result.time   = 0;
   result.price  = 0.0;

   int bars = Bars(symbol,timeframe);

   if(bars <= 0 || lookback <= 0)
      return false;

   int startShift = rightBars + 1;
   int maxShift   = MathMin(
      lookback,
      bars-leftBars-1
   );

   if(startShift > maxShift)
      return false;

   for(int shift=startShift; shift<=maxShift; shift++)
   {
      if(IsSwingHigh(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid  = true;
         result.isHigh = true;
         result.shift  = shift;
         result.time   = MS_Time(
            symbol,
            timeframe,
            shift
         );
         result.price = MS_High(
            symbol,
            timeframe,
            shift
         );

         return true;
      }
   }

   return false;
}


//==================================================================
// FIND RECENT SWING LOW
//==================================================================

bool FindRecentSwingLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   SwingPoint &result
)
{
   result.valid  = false;
   result.isHigh = false;
   result.shift  = -1;
   result.time   = 0;
   result.price  = 0.0;

   int bars = Bars(symbol,timeframe);

   if(bars <= 0 || lookback <= 0)
      return false;

   int startShift = rightBars + 1;
   int maxShift   = MathMin(
      lookback,
      bars-leftBars-1
   );

   if(startShift > maxShift)
      return false;

   for(int shift=startShift; shift<=maxShift; shift++)
   {
      if(IsSwingLow(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid  = true;
         result.isHigh = false;
         result.shift  = shift;
         result.time   = MS_Time(
            symbol,
            timeframe,
            shift
         );
         result.price = MS_Low(
            symbol,
            timeframe,
            shift
         );

         return true;
      }
   }

   return false;
}


//==================================================================
// FIND PREVIOUS SWING HIGH
//==================================================================

bool FindPreviousSwingHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int recentSwingShift,
   int lookback,
   int leftBars,
   int rightBars,
   SwingPoint &result
)
{
   result.valid  = false;
   result.isHigh = true;
   result.shift  = -1;
   result.time   = 0;
   result.price  = 0.0;

   int bars = Bars(symbol,timeframe);

   if(bars <= 0 || recentSwingShift < 0)
      return false;

   int startShift = recentSwingShift+1;

   int maxShift = MathMin(
      lookback,
      bars-leftBars-1
   );

   if(startShift > maxShift)
      return false;

   for(int shift=startShift; shift<=maxShift; shift++)
   {
      if(IsSwingHigh(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid  = true;
         result.isHigh = true;
         result.shift  = shift;
         result.time   = MS_Time(
            symbol,
            timeframe,
            shift
         );
         result.price = MS_High(
            symbol,
            timeframe,
            shift
         );

         return true;
      }
   }

   return false;
}


//==================================================================
// FIND PREVIOUS SWING LOW
//==================================================================

bool FindPreviousSwingLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int recentSwingShift,
   int lookback,
   int leftBars,
   int rightBars,
   SwingPoint &result
)
{
   result.valid  = false;
   result.isHigh = false;
   result.shift  = -1;
   result.time   = 0;
   result.price  = 0.0;

   int bars = Bars(symbol,timeframe);

   if(bars <= 0 || recentSwingShift < 0)
      return false;

   int startShift = recentSwingShift+1;

   int maxShift = MathMin(
      lookback,
      bars-leftBars-1
   );

   if(startShift > maxShift)
      return false;

   for(int shift=startShift; shift<=maxShift; shift++)
   {
      if(IsSwingLow(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid  = true;
         result.isHigh = false;
         result.shift  = shift;
         result.time   = MS_Time(
            symbol,
            timeframe,
            shift
         );
         result.price = MS_Low(
            symbol,
            timeframe,
            shift
         );

         return true;
      }
   }

   return false;
}


//==================================================================
// STRUCTURE COMPARISON
//==================================================================

bool IsHigherHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint recent;
   SwingPoint previous;

   if(!FindRecentSwingHigh(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      recent
   ))
      return false;

   if(!FindPreviousSwingHigh(
      symbol,timeframe,
      recent.shift,
      lookback,leftBars,rightBars,
      previous
   ))
      return false;

   return recent.price > previous.price;
}


bool IsLowerHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint recent;
   SwingPoint previous;

   if(!FindRecentSwingHigh(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      recent
   ))
      return false;

   if(!FindPreviousSwingHigh(
      symbol,timeframe,
      recent.shift,
      lookback,leftBars,rightBars,
      previous
   ))
      return false;

   return recent.price < previous.price;
}


bool IsHigherLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint recent;
   SwingPoint previous;

   if(!FindRecentSwingLow(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      recent
   ))
      return false;

   if(!FindPreviousSwingLow(
      symbol,timeframe,
      recent.shift,
      lookback,leftBars,rightBars,
      previous
   ))
      return false;

   return recent.price > previous.price;
}


bool IsLowerLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint recent;
   SwingPoint previous;

   if(!FindRecentSwingLow(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      recent
   ))
      return false;

   if(!FindPreviousSwingLow(
      symbol,timeframe,
      recent.shift,
      lookback,leftBars,rightBars,
      previous
   ))
      return false;

   return recent.price < previous.price;
}


//==================================================================
// MARKET STRUCTURE BIAS
//==================================================================

int GetMarketStructureBias(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   bool bullish =
      IsHigherHigh(
         symbol,timeframe,
         lookback,leftBars,rightBars
      )
      &&
      IsHigherLow(
         symbol,timeframe,
         lookback,leftBars,rightBars
      );

   if(bullish)
      return 1;

   bool bearish =
      IsLowerHigh(
         symbol,timeframe,
         lookback,leftBars,rightBars
      )
      &&
      IsLowerLow(
         symbol,timeframe,
         lookback,leftBars,rightBars
      );

   if(bearish)
      return -1;

   return 0;
}


//==================================================================
// STRUCTURE BREAK
//==================================================================

bool BrokeRecentSwingHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint swing;

   if(!FindRecentSwingHigh(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      swing
   ))
      return false;

   double closePrice = MS_Close(
      symbol,timeframe,1
   );

   if(closePrice <= 0.0)
      return false;

   return closePrice > swing.price;
}


bool BrokeRecentSwingLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint swing;

   if(!FindRecentSwingLow(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      swing
   ))
      return false;

   double closePrice = MS_Close(
      symbol,timeframe,1
   );

   if(closePrice <= 0.0)
      return false;

   return closePrice < swing.price;
}


//==================================================================
// MARKET STRUCTURE STATE
//==================================================================

bool MS_GetState(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   MarketStructureState &state
)
{
   state.valid = false;

   state.bias = 0;

   state.higherHigh = false;
   state.higherLow  = false;
   state.lowerHigh  = false;
   state.lowerLow   = false;

   state.bullishBreak = false;
   state.bearishBreak = false;

   state.bullishMSS = false;
   state.bearishMSS = false;

   state.recentHigh = 0.0;
   state.previousHigh = 0.0;
   state.recentLow = 0.0;
   state.previousLow = 0.0;

   state.signalTime = 0;

   SwingPoint recentHigh;
   SwingPoint previousHigh;
   SwingPoint recentLow;
   SwingPoint previousLow;

   if(!FindRecentSwingHigh(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      recentHigh
   ))
      return false;

   if(!FindPreviousSwingHigh(
      symbol,timeframe,
      recentHigh.shift,
      lookback,leftBars,rightBars,
      previousHigh
   ))
      return false;

   if(!FindRecentSwingLow(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      recentLow
   ))
      return false;

   if(!FindPreviousSwingLow(
      symbol,timeframe,
      recentLow.shift,
      lookback,leftBars,rightBars,
      previousLow
   ))
      return false;

   state.recentHigh   = recentHigh.price;
   state.previousHigh = previousHigh.price;

   state.recentLow    = recentLow.price;
   state.previousLow  = previousLow.price;

   state.higherHigh =
      recentHigh.price > previousHigh.price;

   state.lowerHigh =
      recentHigh.price < previousHigh.price;

   state.higherLow =
      recentLow.price > previousLow.price;

   state.lowerLow =
      recentLow.price < previousLow.price;

   state.bullishBreak =
      BrokeRecentSwingHigh(
         symbol,timeframe,
         lookback,leftBars,rightBars
      );

   state.bearishBreak =
      BrokeRecentSwingLow(
         symbol,timeframe,
         lookback,leftBars,rightBars
      );

   if(state.higherHigh && state.higherLow)
      state.bias = 1;
   else
   if(state.lowerHigh && state.lowerLow)
      state.bias = -1;
   else
      state.bias = 0;

   // MSS is treated as a structure break against the
   // previous structural condition.
   state.bullishMSS =
      state.bullishBreak &&
      (state.lowerHigh || state.lowerLow);

   state.bearishMSS =
      state.bearishBreak &&
      (state.higherHigh || state.higherLow);

   state.signalTime =
      MS_Time(symbol,timeframe,1);

   state.valid = true;

   return true;
}


//==================================================================
// STRUCTURE LEVEL ACCESS
//==================================================================

double GetRecentSwingHighPrice(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint swing;

   if(!FindRecentSwingHigh(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      swing
   ))
      return 0.0;

   return swing.price;
}


double GetRecentSwingLowPrice(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars
)
{
   SwingPoint swing;

   if(!FindRecentSwingLow(
      symbol,timeframe,
      lookback,leftBars,rightBars,
      swing
   ))
      return 0.0;

   return swing.price;
}


//==================================================================
// BIAS TEXT
//==================================================================

string MarketStructureBiasToString(int bias)
{
   if(bias > 0)
      return "BULLISH";

   if(bias < 0)
      return "BEARISH";

   return "NEUTRAL";
}


//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
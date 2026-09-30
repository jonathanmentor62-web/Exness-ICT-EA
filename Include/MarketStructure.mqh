//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Market structure detection for Exness ICT EA                    |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_MARKET_STRUCTURE_MQH__
#define __EXNESS_ICT_MARKET_STRUCTURE_MQH__

//====================================================================
// STRUCTURES
//====================================================================

struct SwingPoint
{
   bool     valid;
   bool     isHigh;
   int      shift;
   datetime time;
   double   price;
};


//====================================================================
// BASIC CANDLE ACCESS
//====================================================================

// Return candle high.
double MS_High(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   return iHigh(symbol, timeframe, shift);
}

// Return candle low.
double MS_Low(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   return iLow(symbol, timeframe, shift);
}

// Return candle open.
double MS_Open(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   return iOpen(symbol, timeframe, shift);
}

// Return candle close.
double MS_Close(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   return iClose(symbol, timeframe, shift);
}

// Return candle time.
datetime MS_Time(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   return iTime(symbol, timeframe, shift);
}


//====================================================================
// SWING DETECTION
//====================================================================

// Determine whether the candle at "shift" is a swing high.
//
// Example with left/right = 2:
//
//             HIGH
//               X
//       X       |       X
//   X           |           X
//
// The candidate must be higher than candles on both sides.
bool IsSwingHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   int leftBars,
   int rightBars
)
{
   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(shift < rightBars)
      return false;

   if(shift + leftBars >= bars)
      return false;

   double candidate = MS_High(symbol, timeframe, shift);

   if(candidate <= 0.0)
      return false;

   // More recent candles.
   for(int i = 1; i <= rightBars; i++)
   {
      double value = MS_High(symbol, timeframe, shift - i);

      if(value >= candidate)
         return false;
   }

   // Older candles.
   for(int i = 1; i <= leftBars; i++)
   {
      double value = MS_High(symbol, timeframe, shift + i);

      if(value >= candidate)
         return false;
   }

   return true;
}


// Determine whether the candle at "shift" is a swing low.
bool IsSwingLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   int leftBars,
   int rightBars
)
{
   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(shift < rightBars)
      return false;

   if(shift + leftBars >= bars)
      return false;

   double candidate = MS_Low(symbol, timeframe, shift);

   if(candidate <= 0.0)
      return false;

   // More recent candles.
   for(int i = 1; i <= rightBars; i++)
   {
      double value = MS_Low(symbol, timeframe, shift - i);

      if(value <= candidate)
         return false;
   }

   // Older candles.
   for(int i = 1; i <= leftBars; i++)
   {
      double value = MS_Low(symbol, timeframe, shift + i);

      if(value <= candidate)
         return false;
   }

   return true;
}


//====================================================================
// FIND MOST RECENT SWING
//====================================================================

// Find the most recent confirmed swing high.
//
// IMPORTANT:
// A swing at "shift" requires rightBars candles to its right.
// Therefore the search begins at rightBars + 1.
bool FindRecentSwingHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   SwingPoint &result
)
{
   result.valid = false;
   result.isHigh = true;
   result.shift = -1;
   result.time = 0;
   result.price = 0.0;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(lookback <= 0)
      return false;

   int startShift = rightBars + 1;
   int maxShift = MathMin(lookback, bars - leftBars - 1);

   if(startShift > maxShift)
      return false;

   for(int shift = startShift; shift <= maxShift; shift++)
   {
      if(IsSwingHigh(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid = true;
         result.isHigh = true;
         result.shift = shift;
         result.time = MS_Time(symbol, timeframe, shift);
         result.price = MS_High(symbol, timeframe, shift);

         return true;
      }
   }

   return false;
}


// Find the most recent confirmed swing low.
bool FindRecentSwingLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   int leftBars,
   int rightBars,
   SwingPoint &result
)
{
   result.valid = false;
   result.isHigh = false;
   result.shift = -1;
   result.time = 0;
   result.price = 0.0;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(lookback <= 0)
      return false;

   int startShift = rightBars + 1;
   int maxShift = MathMin(lookback, bars - leftBars - 1);

   if(startShift > maxShift)
      return false;

   for(int shift = startShift; shift <= maxShift; shift++)
   {
      if(IsSwingLow(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid = true;
         result.isHigh = false;
         result.shift = shift;
         result.time = MS_Time(symbol, timeframe, shift);
         result.price = MS_Low(symbol, timeframe, shift);

         return true;
      }
   }

   return false;
}


//====================================================================
// FIND PREVIOUS SWING
//====================================================================

// Find the swing high before a known recent swing high.
//
// The search starts at recentSwingShift + 1.
//
// This is important:
// recentSwingShift + rightBars + 1 would skip valid swings.
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
   result.valid = false;
   result.isHigh = true;
   result.shift = -1;
   result.time = 0;
   result.price = 0.0;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(recentSwingShift < 0)
      return false;

   int startShift = recentSwingShift + 1;
   int maxShift = MathMin(lookback, bars - leftBars - 1);

   if(startShift > maxShift)
      return false;

   for(int shift = startShift; shift <= maxShift; shift++)
   {
      if(IsSwingHigh(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid = true;
         result.isHigh = true;
         result.shift = shift;
         result.time = MS_Time(symbol, timeframe, shift);
         result.price = MS_High(symbol, timeframe, shift);

         return true;
      }
   }

   return false;
}


// Find the swing low before a known recent swing low.
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
   result.valid = false;
   result.isHigh = false;
   result.shift = -1;
   result.time = 0;
   result.price = 0.0;

   int bars = Bars(symbol, timeframe);

   if(bars <= 0)
      return false;

   if(recentSwingShift < 0)
      return false;

   int startShift = recentSwingShift + 1;
   int maxShift = MathMin(lookback, bars - leftBars - 1);

   if(startShift > maxShift)
      return false;

   for(int shift = startShift; shift <= maxShift; shift++)
   {
      if(IsSwingLow(
         symbol,
         timeframe,
         shift,
         leftBars,
         rightBars
      ))
      {
         result.valid = true;
         result.isHigh = false;
         result.shift = shift;
         result.time = MS_Time(symbol, timeframe, shift);
         result.price = MS_Low(symbol, timeframe, shift);

         return true;
      }
   }

   return false;
}


//====================================================================
// STRUCTURE LEVELS
//====================================================================

// Get the latest confirmed swing high.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swing
   ))
   {
      return 0.0;
   }

   return swing.price;
}


// Get the latest confirmed swing low.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swing
   ))
   {
      return 0.0;
   }

   return swing.price;
}


//====================================================================
// STRUCTURE CLASSIFICATION
//====================================================================

// Determine whether recent swing highs are making higher highs.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      recent
   ))
   {
      return false;
   }

   if(!FindPreviousSwingHigh(
      symbol,
      timeframe,
      recent.shift,
      lookback,
      leftBars,
      rightBars,
      previous
   ))
   {
      return false;
   }

   return recent.price > previous.price;
}


// Determine whether recent swing highs are making lower highs.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      recent
   ))
   {
      return false;
   }

   if(!FindPreviousSwingHigh(
      symbol,
      timeframe,
      recent.shift,
      lookback,
      leftBars,
      rightBars,
      previous
   ))
   {
      return false;
   }

   return recent.price < previous.price;
}


// Determine whether recent swing lows are making higher lows.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      recent
   ))
   {
      return false;
   }

   if(!FindPreviousSwingLow(
      symbol,
      timeframe,
      recent.shift,
      lookback,
      leftBars,
      rightBars,
      previous
   ))
   {
      return false;
   }

   return recent.price > previous.price;
}


// Determine whether recent swing lows are making lower lows.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      recent
   ))
   {
      return false;
   }

   if(!FindPreviousSwingLow(
      symbol,
      timeframe,
      recent.shift,
      lookback,
      leftBars,
      rightBars,
      previous
   ))
   {
      return false;
   }

   return recent.price < previous.price;
}


//====================================================================
// MARKET STRUCTURE BIAS
//====================================================================

// Returns:
//
//  1  = bullish structure
// -1  = bearish structure
//  0  = neutral / unclear
//
// Bullish structure requires:
//   Higher High + Higher Low
//
// Bearish structure requires:
//   Lower High + Lower Low
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
         symbol,
         timeframe,
         lookback,
         leftBars,
         rightBars
      )
      &&
      IsHigherLow(
         symbol,
         timeframe,
         lookback,
         leftBars,
         rightBars
      );

   if(bullish)
      return 1;

   bool bearish =
      IsLowerHigh(
         symbol,
         timeframe,
         lookback,
         leftBars,
         rightBars
      )
      &&
      IsLowerLow(
         symbol,
         timeframe,
         lookback,
         leftBars,
         rightBars
      );

   if(bearish)
      return -1;

   return 0;
}


//====================================================================
// STRUCTURE BREAK DETECTION
//====================================================================

// Determine whether the most recently closed candle broke above
// the latest confirmed swing high.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swing
   ))
   {
      return false;
   }

   double closePrice = MS_Close(symbol, timeframe, 1);

   if(closePrice <= 0.0)
      return false;

   return closePrice > swing.price;
}


// Determine whether the most recently closed candle broke below
// the latest confirmed swing low.
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
      symbol,
      timeframe,
      lookback,
      leftBars,
      rightBars,
      swing
   ))
   {
      return false;
   }

   double closePrice = MS_Close(symbol, timeframe, 1);

   if(closePrice <= 0.0)
      return false;

   return closePrice < swing.price;
}


//====================================================================
// STRUCTURE TEXT
//====================================================================

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

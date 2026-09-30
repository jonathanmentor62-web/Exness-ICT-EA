//+------------------------------------------------------------------+
//| FVG.mqh                                                          |
//| Fair Value Gap engine for Exness ICT EA                          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_FVG_MQH__
#define __EXNESS_ICT_FVG_MQH__

//====================================================================
// FVG TYPES
//====================================================================

enum ENUM_FVG_DIRECTION
{
   FVG_NONE = 0,
   FVG_BULLISH = 1,
   FVG_BEARISH = -1
};

//+------------------------------------------------------------------+

enum ENUM_FVG_STATUS
{
   FVG_STATUS_NONE = 0,
   FVG_STATUS_ACTIVE,
   FVG_STATUS_MITIGATED,
   FVG_STATUS_INVALIDATED
};

//====================================================================
// FVG STRUCTURE
//====================================================================

struct FVGZone
{
   ENUM_FVG_DIRECTION direction;
   ENUM_FVG_STATUS    status;

   double upper;
   double lower;
   double midpoint;

   double size;

   datetime formationTime;

   int firstShift;
   int middleShift;
   int thirdShift;

   bool valid;
   bool mitigated;
   bool invalidated;
};

//====================================================================
// RESET
//====================================================================

void ResetFVG(
   FVGZone &fvg
)
{
   fvg.direction = FVG_NONE;
   fvg.status    = FVG_STATUS_NONE;

   fvg.upper     = 0.0;
   fvg.lower     = 0.0;
   fvg.midpoint  = 0.0;
   fvg.size      = 0.0;

   fvg.formationTime = 0;

   fvg.firstShift  = -1;
   fvg.middleShift = -1;
   fvg.thirdShift  = -1;

   fvg.valid       = false;
   fvg.mitigated   = false;
   fvg.invalidated = false;
}

//====================================================================
// BASIC VALIDATION
//====================================================================

bool IsValidFVG(
   const FVGZone &fvg
)
{
   if(!fvg.valid)
      return(false);

   if(fvg.direction == FVG_NONE)
      return(false);

   if(fvg.upper <= 0.0)
      return(false);

   if(fvg.lower <= 0.0)
      return(false);

   if(fvg.upper <= fvg.lower)
      return(false);

   if(fvg.size <= 0.0)
      return(false);

   if(fvg.formationTime <= 0)
      return(false);

   return(true);
}

//====================================================================
// FVG SIZE
//====================================================================

double GetFVGSize(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const ENUM_FVG_DIRECTION direction
)
{
   if(candleShift < 1)
      return(0.0);

   if(direction == FVG_BULLISH)
   {
      /*
         Three-candle bullish FVG:

         Candle 1 high < Candle 3 low

         Gap:
         Candle 1 high -> Candle 3 low
      */

      double firstHigh =
         iHigh(
            symbol,
            timeframe,
            candleShift + 2
         );

      double thirdLow =
         iLow(
            symbol,
            timeframe,
            candleShift
         );

      if(firstHigh <= 0.0 || thirdLow <= 0.0)
         return(0.0);

      if(thirdLow <= firstHigh)
         return(0.0);

      return(thirdLow - firstHigh);
   }

   if(direction == FVG_BEARISH)
   {
      /*
         Three-candle bearish FVG:

         Candle 1 low > Candle 3 high

         Gap:
         Candle 3 high -> Candle 1 low
      */

      double firstLow =
         iLow(
            symbol,
            timeframe,
            candleShift + 2
         );

      double thirdHigh =
         iHigh(
            symbol,
            timeframe,
            candleShift
         );

      if(firstLow <= 0.0 || thirdHigh <= 0.0)
         return(0.0);

      if(firstLow <= thirdHigh)
         return(0.0);

      return(firstLow - thirdHigh);
   }

   return(0.0);
}

//====================================================================
// BULLISH FVG DETECTION
//====================================================================

//+------------------------------------------------------------------+
//| Detect bullish three-candle FVG                                  |
//|                                                                  |
//| Candle 1 high < Candle 3 low                                    |
//|                                                                  |
//| The resulting zone is:                                          |
//|                                                                  |
//| lower = Candle 1 high                                            |
//| upper = Candle 3 low                                             |
//+------------------------------------------------------------------+

bool DetectBullishFVG(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(candleShift < 1)
      return(false);

   int firstShift  = candleShift + 2;
   int middleShift = candleShift + 1;
   int thirdShift  = candleShift;

   double firstHigh =
      iHigh(
         symbol,
         timeframe,
         firstShift
      );

   double middleHigh =
      iHigh(
         symbol,
         timeframe,
         middleShift
      );

   double middleLow =
      iLow(
         symbol,
         timeframe,
         middleShift
      );

   double thirdLow =
      iLow(
         symbol,
         timeframe,
         thirdShift
      );

   if(
      firstHigh <= 0.0 ||
      middleHigh <= 0.0 ||
      middleLow <= 0.0 ||
      thirdLow <= 0.0
   )
   {
      return(false);
   }

   if(thirdLow <= firstHigh)
      return(false);

   double gapSize =
      thirdLow - firstHigh;

   if(gapSize <= 0.0)
      return(false);

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   if(point <= 0.0)
      return(false);

   double gapSizePoints =
      gapSize / point;

   if(gapSizePoints < ICT_MIN_FVG_SIZE_PTS)
      return(false);

   fvg.direction = FVG_BULLISH;
   fvg.status    = FVG_STATUS_ACTIVE;

   fvg.lower     = firstHigh;
   fvg.upper     = thirdLow;
   fvg.midpoint  = (firstHigh + thirdLow) / 2.0;
   fvg.size      = gapSize;

   fvg.formationTime =
      iTime(
         symbol,
         timeframe,
         thirdShift
      );

   fvg.firstShift  = firstShift;
   fvg.middleShift = middleShift;
   fvg.thirdShift  = thirdShift;

   fvg.valid       = true;
   fvg.mitigated   = false;
   fvg.invalidated = false;

   return(true);
}

//====================================================================
// BEARISH FVG DETECTION
//====================================================================

//+------------------------------------------------------------------+
//| Detect bearish three-candle FVG                                  |
//|                                                                  |
//| Candle 1 low > Candle 3 high                                    |
//|                                                                  |
//| Zone:                                                            |
//|                                                                  |
//| lower = Candle 3 high                                            |
//| upper = Candle 1 low                                             |
//+------------------------------------------------------------------+

bool DetectBearishFVG(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(candleShift < 1)
      return(false);

   int firstShift  = candleShift + 2;
   int middleShift = candleShift + 1;
   int thirdShift  = candleShift;

   double firstLow =
      iLow(
         symbol,
         timeframe,
         firstShift
      );

   double middleHigh =
      iHigh(
         symbol,
         timeframe,
         middleShift
      );

   double middleLow =
      iLow(
         symbol,
         timeframe,
         middleShift
      );

   double thirdHigh =
      iHigh(
         symbol,
         timeframe,
         thirdShift
      );

   if(
      firstLow <= 0.0 ||
      middleHigh <= 0.0 ||
      middleLow <= 0.0 ||
      thirdHigh <= 0.0
   )
   {
      return(false);
   }

   if(firstLow <= thirdHigh)
      return(false);

   double gapSize =
      firstLow - thirdHigh;

   if(gapSize <= 0.0)
      return(false);

   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   if(point <= 0.0)
      return(false);

   double gapSizePoints =
      gapSize / point;

   if(gapSizePoints < ICT_MIN_FVG_SIZE_PTS)
      return(false);

   fvg.direction = FVG_BEARISH;
   fvg.status    = FVG_STATUS_ACTIVE;

   fvg.lower     = thirdHigh;
   fvg.upper     = firstLow;
   fvg.midpoint  = (thirdHigh + firstLow) / 2.0;
   fvg.size      = gapSize;

   fvg.formationTime =
      iTime(
         symbol,
         timeframe,
         thirdShift
      );

   fvg.firstShift  = firstShift;
   fvg.middleShift = middleShift;
   fvg.thirdShift  = thirdShift;

   fvg.valid       = true;
   fvg.mitigated   = false;
   fvg.invalidated = false;

   return(true);
}

//====================================================================
// GENERIC FVG DETECTION
//====================================================================

bool DetectFVG(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const ENUM_FVG_DIRECTION direction,
   FVGZone &fvg
)
{
   ResetFVG(fvg);

   if(direction == FVG_BULLISH)
   {
      return(
         DetectBullishFVG(
            symbol,
            timeframe,
            candleShift,
            fvg
         )
      );
   }

   if(direction == FVG_BEARISH)
   {
      return(
         DetectBearishFVG(
            symbol,
            timeframe,
            candleShift,
            fvg
         )
      );
   }

   return(false);
}

//====================================================================
// PRICE INSIDE FVG
//====================================================================

bool IsPriceInsideFVG(
   const double price,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(price <= 0.0)
      return(false);

   return(
      price >= fvg.lower &&
      price <= fvg.upper
   );
}

//====================================================================
// PRICE TOUCHES FVG
//====================================================================

bool DidCandleTouchFVG(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(candleShift < 0)
      return(false);

   double high =
      iHigh(
         symbol,
         timeframe,
         candleShift
      );

   double low =
      iLow(
         symbol,
         timeframe,
         candleShift
      );

   if(high <= 0.0 || low <= 0.0)
      return(false);

   if(high < fvg.lower)
      return(false);

   if(low > fvg.upper)
      return(false);

   return(true);
}

//====================================================================
// FVG MITIGATION
//====================================================================

//+------------------------------------------------------------------+
//| Bullish FVG mitigation                                           |
//|                                                                  |
//| Price returns into the bullish gap.                              |
//+------------------------------------------------------------------+

bool IsBullishFVGMitigated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction != FVG_BULLISH)
      return(false);

   return(
      DidCandleTouchFVG(
         symbol,
         timeframe,
         candleShift,
         fvg
      )
   );
}

//+------------------------------------------------------------------+
//| Bearish FVG mitigation                                           |
//+------------------------------------------------------------------+

bool IsBearishFVGMitigated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction != FVG_BEARISH)
      return(false);

   return(
      DidCandleTouchFVG(
         symbol,
         timeframe,
         candleShift,
         fvg
      )
   );
}

//+------------------------------------------------------------------+
//| Generic mitigation                                               |
//+------------------------------------------------------------------+

bool IsFVGMitigated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   return(
      DidCandleTouchFVG(
         symbol,
         timeframe,
         candleShift,
         fvg
      )
   );
}

//====================================================================
// FVG INVALIDATION
//====================================================================

//+------------------------------------------------------------------+
//| Bullish FVG invalidation                                         |
//|                                                                  |
//| A bullish FVG becomes invalid when a CLOSED candle closes below  |
//| the lower boundary of the gap.                                   |
//+------------------------------------------------------------------+

bool IsBullishFVGInvalidated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction != FVG_BULLISH)
      return(false);

   if(candleShift < 1)
      return(false);

   double close =
      iClose(
         symbol,
         timeframe,
         candleShift
      );

   if(close <= 0.0)
      return(false);

   return(close < fvg.lower);
}

//+------------------------------------------------------------------+
//| Bearish FVG invalidation                                         |
//|                                                                  |
//| A bearish FVG becomes invalid when a CLOSED candle closes above  |
//| the upper boundary.                                              |
//+------------------------------------------------------------------+

bool IsBearishFVGInvalidated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction != FVG_BEARISH)
      return(false);

   if(candleShift < 1)
      return(false);

   double close =
      iClose(
         symbol,
         timeframe,
         candleShift
      );

   if(close <= 0.0)
      return(false);

   return(close > fvg.upper);
}

//+------------------------------------------------------------------+

bool IsFVGInvalidated(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction == FVG_BULLISH)
   {
      return(
         IsBullishFVGInvalidated(
            symbol,
            timeframe,
            candleShift,
            fvg
         )
      );
   }

   if(fvg.direction == FVG_BEARISH)
   {
      return(
         IsBearishFVGInvalidated(
            symbol,
            timeframe,
            candleShift,
            fvg
         )
      );
   }

   return(false);
}

//====================================================================
// FVG STATUS UPDATE
//====================================================================

//+------------------------------------------------------------------+
//| Update FVG status using a CLOSED candle                          |
//+------------------------------------------------------------------+

bool UpdateFVGStatus(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(candleShift < 1)
      return(false);

   //--- Once invalidated, it remains invalidated.
   if(fvg.invalidated)
   {
      fvg.status = FVG_STATUS_INVALIDATED;
      return(true);
   }

   //--- Check invalidation first.
   if(IsFVGInvalidated(
      symbol,
      timeframe,
      candleShift,
      fvg
   ))
   {
      fvg.invalidated = true;
      fvg.mitigated   = false;
      fvg.status      = FVG_STATUS_INVALIDATED;

      return(true);
   }

   //--- Detect mitigation.
   if(IsFVGMitigated(
      symbol,
      timeframe,
      candleShift,
      fvg
   ))
   {
      fvg.mitigated = true;
      fvg.status    = FVG_STATUS_MITIGATED;

      return(true);
   }

   //--- Still active.
   fvg.status = FVG_STATUS_ACTIVE;

   return(true);
}

//====================================================================
// ENTRY ZONE VALIDATION
//====================================================================

//+------------------------------------------------------------------+
//| Bullish entry-zone validation                                    |
//|                                                                  |
//| Price must be inside the bullish FVG.                            |
//|                                                                  |
//| For a bullish setup, price approaching from ABOVE and returning  |
//| into the gap is the expected retracement behavior.              |
//+------------------------------------------------------------------+

bool IsBullishFVGEntryZone(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction != FVG_BULLISH)
      return(false);

   if(fvg.invalidated)
      return(false);

   if(candleShift < 0)
      return(false);

   double high =
      iHigh(
         symbol,
         timeframe,
         candleShift
      );

   double low =
      iLow(
         symbol,
         timeframe,
         candleShift
      );

   if(high <= 0.0 || low <= 0.0)
      return(false);

   //--- Candle must actually enter the FVG.
   if(high < fvg.lower)
      return(false);

   if(low > fvg.upper)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Bearish entry-zone validation                                    |
//+------------------------------------------------------------------+

bool IsBearishFVGEntryZone(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction != FVG_BEARISH)
      return(false);

   if(fvg.invalidated)
      return(false);

   if(candleShift < 0)
      return(false);

   double high =
      iHigh(
         symbol,
         timeframe,
         candleShift
      );

   double low =
      iLow(
         symbol,
         timeframe,
         candleShift
      );

   if(high <= 0.0 || low <= 0.0)
      return(false);

   if(high < fvg.lower)
      return(false);

   if(low > fvg.upper)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Generic entry-zone validation                                    |
//+------------------------------------------------------------------+

bool IsFVGEntryZone(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int candleShift,
   const FVGZone &fvg
)
{
   if(!IsValidFVG(fvg))
      return(false);

   if(fvg.direction == FVG_BULLISH)
   {
      return(
         IsBullishFVGEntryZone(
            symbol,
            timeframe,
            candleShift,
            fvg
         )
      );
   }

   if(fvg.direction == FVG_BEAR

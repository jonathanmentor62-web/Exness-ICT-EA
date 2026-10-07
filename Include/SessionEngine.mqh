//+------------------------------------------------------------------+
//| SessionEngine.mqh                                                |
//| Gold Multi-Strategy EA - Session Analysis Engine                 |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_SESSION_ENGINE_MQH__
#define __EXNESS_GOLD_SESSION_ENGINE_MQH__

#include "Config.mqh"
#include "Liquidity.mqh"
#include "MarketStructure.mqh"

//-------------------------------------------------------------------
// Session types
//-------------------------------------------------------------------
enum ENUM_SESSION_TYPE
{
   SESSION_NONE = 0,
   SESSION_ASIA,
   SESSION_LONDON,
   SESSION_NEW_YORK
};

//-------------------------------------------------------------------
// Session direction
//-------------------------------------------------------------------
enum ENUM_SESSION_DIRECTION
{
   SESSION_DIRECTION_NONE = 0,
   SESSION_DIRECTION_BULLISH,
   SESSION_DIRECTION_BEARISH
};

//-------------------------------------------------------------------
// Session analysis structure
//-------------------------------------------------------------------
struct SessionAnalysis
{
   bool valid;

   ENUM_SESSION_TYPE session;
   ENUM_SESSION_DIRECTION direction;

   datetime sessionStart;
   datetime sessionEnd;

   double sessionHigh;
   double sessionLow;
   double sessionMidpoint;
   double sessionRange;

   bool highTaken;
   bool lowTaken;

   bool bullishSweep;
   bool bearishSweep;

   bool bullishBreakout;
   bool bearishBreakout;

   bool bullishRetest;
   bool bearishRetest;

   bool bullishReversal;
   bool bearishReversal;

   bool bullishContinuation;
   bool bearishContinuation;

   double score;

   int barsAnalyzed;

   string reason;
   string evidence;
};

//-------------------------------------------------------------------
// Reset session analysis
//-------------------------------------------------------------------
void ResetSessionAnalysis(SessionAnalysis &s)
{
   s.valid = false;

   s.session = SESSION_NONE;
   s.direction = SESSION_DIRECTION_NONE;

   s.sessionStart = 0;
   s.sessionEnd = 0;

   s.sessionHigh = 0.0;
   s.sessionLow = 0.0;
   s.sessionMidpoint = 0.0;
   s.sessionRange = 0.0;

   s.highTaken = false;
   s.lowTaken = false;

   s.bullishSweep = false;
   s.bearishSweep = false;

   s.bullishBreakout = false;
   s.bearishBreakout = false;

   s.bullishRetest = false;
   s.bearishRetest = false;

   s.bullishReversal = false;
   s.bearishReversal = false;

   s.bullishContinuation = false;
   s.bearishContinuation = false;

   s.score = 0.0;

   s.barsAnalyzed = 0;

   s.reason = "";
   s.evidence = "";
}

//-------------------------------------------------------------------
// Gold symbol check
//-------------------------------------------------------------------
bool SE_IsGold(const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//-------------------------------------------------------------------
// Session name
//-------------------------------------------------------------------
string SE_SessionToString(
   const ENUM_SESSION_TYPE session)
{
   if(session == SESSION_ASIA)
      return "ASIA";

   if(session == SESSION_LONDON)
      return "LONDON";

   if(session == SESSION_NEW_YORK)
      return "NEW YORK";

   return "NONE";
}

//-------------------------------------------------------------------
// Session direction string
//-------------------------------------------------------------------
string SE_DirectionToString(
   const ENUM_SESSION_DIRECTION direction)
{
   if(direction == SESSION_DIRECTION_BULLISH)
      return "BULLISH";

   if(direction == SESSION_DIRECTION_BEARISH)
      return "BEARISH";

   return "NONE";
}

//-------------------------------------------------------------------
// Hour extraction
//-------------------------------------------------------------------
int SE_Hour(const datetime timeValue)
{
   MqlDateTime dt;

   if(!TimeToStruct(timeValue,dt))
      return -1;

   return dt.hour;
}

//-------------------------------------------------------------------
// Determine whether hour is inside a normal session window
//-------------------------------------------------------------------
bool SE_HourInRange(
   const int hour,
   const int startHour,
   const int endHour)
{
   if(hour < 0)
      return false;

   if(startHour == endHour)
      return true;

   if(startHour < endHour)
      return hour >= startHour &&
             hour < endHour;

   // Handles sessions crossing midnight.
   return hour >= startHour ||
          hour < endHour;
}

//-------------------------------------------------------------------
// Determine current session
//-------------------------------------------------------------------
ENUM_SESSION_TYPE SE_GetCurrentSession(
   const datetime timeValue)
{
   int hour = SE_Hour(timeValue);

   if(hour < 0)
      return SESSION_NONE;

   if(SE_HourInRange(
         hour,
         ICT_LONDON_START_HOUR,
         ICT_LONDON_END_HOUR))
   {
      return SESSION_LONDON;
   }

   if(SE_HourInRange(
         hour,
         ICT_NEW_YORK_START_HOUR,
         ICT_NEW_YORK_END_HOUR))
   {
      return SESSION_NEW_YORK;
   }

   return SESSION_ASIA;
}

//-------------------------------------------------------------------
// Check whether current time is a configured trading session
//-------------------------------------------------------------------
bool SE_IsActiveTradingSession(
   const datetime timeValue)
{
   if(!ICT_ENABLE_SESSION_FILTER)
      return true;

   ENUM_SESSION_TYPE session =
      SE_GetCurrentSession(timeValue);

   return session == SESSION_LONDON ||
          session == SESSION_NEW_YORK;
}

//-------------------------------------------------------------------
// Session start hour
//-------------------------------------------------------------------
int SE_GetSessionStartHour(
   const ENUM_SESSION_TYPE session)
{
   if(session == SESSION_LONDON)
      return ICT_LONDON_START_HOUR;

   if(session == SESSION_NEW_YORK)
      return ICT_NEW_YORK_START_HOUR;

   // Asia is used as the background/pre-session range.
   return 0;
}

//-------------------------------------------------------------------
// Session end hour
//-------------------------------------------------------------------
int SE_GetSessionEndHour(
   const ENUM_SESSION_TYPE session)
{
   if(session == SESSION_LONDON)
      return ICT_LONDON_END_HOUR;

   if(session == SESSION_NEW_YORK)
      return ICT_NEW_YORK_END_HOUR;

   return ICT_LONDON_START_HOUR;
}

//-------------------------------------------------------------------
// Build today's session boundaries
//-------------------------------------------------------------------
bool SE_GetSessionBounds(
   const ENUM_SESSION_TYPE session,
   const datetime referenceTime,
   datetime &sessionStart,
   datetime &sessionEnd)
{
   sessionStart = 0;
   sessionEnd = 0;

   if(session == SESSION_NONE)
      return false;

   MqlDateTime dt;

   if(!TimeToStruct(referenceTime,dt))
      return false;

   dt.hour = SE_GetSessionStartHour(session);
   dt.min = 0;
   dt.sec = 0;

   sessionStart = StructToTime(dt);

   dt.hour = SE_GetSessionEndHour(session);
   dt.min = 0;
   dt.sec = 0;

   sessionEnd = StructToTime(dt);

   // Protect against midnight-crossing sessions.
   if(sessionEnd <= sessionStart)
      sessionEnd += 86400;

   return true;
}

//-------------------------------------------------------------------
// Check whether candle belongs to session
//-------------------------------------------------------------------
bool SE_TimeInSession(
   const datetime candleTime,
   const datetime sessionStart,
   const datetime sessionEnd)
{
   if(candleTime <= 0 ||
      sessionStart <= 0 ||
      sessionEnd <= 0)
   {
      return false;
   }

   return candleTime >= sessionStart &&
          candleTime < sessionEnd;
}

//-------------------------------------------------------------------
// Current session price
//-------------------------------------------------------------------
double SE_CurrentBid(const string symbol)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   return tick.bid;
}

double SE_CurrentAsk(const string symbol)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   return tick.ask;
}

double SE_CurrentPrice(const string symbol)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   if(tick.bid > 0.0 && tick.ask > 0.0)
      return (tick.bid + tick.ask) * 0.5;

   return tick.bid > 0.0 ? tick.bid : tick.ask;
}
//-------------------------------------------------------------------
// Find session range
//-------------------------------------------------------------------
bool SE_FindSessionRange(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const datetime sessionStart,
   const datetime sessionEnd,
   double &sessionHigh,
   double &sessionLow,
   int &barsAnalyzed)
{
   sessionHigh = 0.0;
   sessionLow = 0.0;
   barsAnalyzed = 0;

   if(!SE_IsGold(symbol))
      return false;

   if(sessionStart <= 0 ||
      sessionEnd <= sessionStart)
   {
      return false;
   }

   int bars = Bars(symbol,timeframe);

   if(bars <= 0)
      return false;

   bool found = false;

   for(int shift = 1; shift < bars; shift++)
   {
      datetime candleTime =
         iTime(symbol,timeframe,shift);

      if(candleTime <= 0)
         continue;

      if(candleTime < sessionStart)
         break;

      if(candleTime >= sessionEnd)
         continue;

      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      if(high <= 0.0 ||
         low <= 0.0 ||
         high <= low)
      {
         continue;
      }

      if(!found)
      {
         sessionHigh = high;
         sessionLow = low;
         found = true;
      }
      else
      {
         if(high > sessionHigh)
            sessionHigh = high;

         if(low < sessionLow)
            sessionLow = low;
      }

      barsAnalyzed++;
   }

   return found &&
          sessionHigh > sessionLow &&
          barsAnalyzed > 0;
}

//-------------------------------------------------------------------
// Calculate session midpoint
//-------------------------------------------------------------------
double SE_SessionMidpoint(
   const double sessionHigh,
   const double sessionLow)
{
   if(sessionHigh <= sessionLow)
      return 0.0;

   return (sessionHigh + sessionLow) * 0.5;
}

//-------------------------------------------------------------------
// Calculate session range
//-------------------------------------------------------------------
double SE_SessionRange(
   const double sessionHigh,
   const double sessionLow)
{
   if(sessionHigh <= sessionLow)
      return 0.0;

   return sessionHigh - sessionLow;
}

//-------------------------------------------------------------------
// Detect whether price has taken session high
//-------------------------------------------------------------------
bool SE_HighTaken(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double high =
         iHigh(symbol,timeframe,shift);

      if(high > sessionHigh)
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect whether price has taken session low
//-------------------------------------------------------------------
bool SE_LowTaken(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double low =
         iLow(symbol,timeframe,shift);

      if(low < sessionLow)
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bullish session breakout
//-------------------------------------------------------------------
bool SE_BullishBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double close =
         iClose(symbol,timeframe,shift);

      if(close > sessionHigh)
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bearish session breakout
//-------------------------------------------------------------------
bool SE_BearishBreakout(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double close =
         iClose(symbol,timeframe,shift);

      if(close < sessionLow)
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bullish session rejection
//-------------------------------------------------------------------
bool SE_BullishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double open =
         iOpen(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      if(open <= 0.0 ||
         close <= 0.0 ||
         high <= 0.0 ||
         low <= 0.0)
      {
         continue;
      }

      double range = high - low;

      if(range <= 0.0)
         continue;

      double lowerWick =
         MathMin(open,close) - low;

      double body =
         MathAbs(close - open);

      if(low < sessionLow &&
         close > sessionLow &&
         lowerWick > body)
      {
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bearish session rejection
//-------------------------------------------------------------------
bool SE_BearishRejection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double open =
         iOpen(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      if(open <= 0.0 ||
         close <= 0.0 ||
         high <= 0.0 ||
         low <= 0.0)
      {
         continue;
      }

      double range = high - low;

      if(range <= 0.0)
         continue;

      double upperWick =
         high - MathMax(open,close);

      double body =
         MathAbs(close - open);

      if(high > sessionHigh &&
         close < sessionHigh &&
         upperWick > body)
      {
         return true;
      }
   }

   return false;
}
//-------------------------------------------------------------------
// Detect bullish session liquidity sweep
//-------------------------------------------------------------------
bool SE_BullishSweep(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double low =
         iLow(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      if(low <= 0.0 || close <= 0.0)
         continue;

      // Price takes the session low but closes back above it.
      if(low < sessionLow &&
         close > sessionLow)
      {
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bearish session liquidity sweep
//-------------------------------------------------------------------
bool SE_BearishSweep(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 1)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double high =
         iHigh(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      if(high <= 0.0 || close <= 0.0)
         continue;

      // Price takes the session high but closes back below it.
      if(high > sessionHigh &&
         close < sessionHigh)
      {
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bullish session continuation
//-------------------------------------------------------------------
bool SE_BullishContinuation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 2)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double open =
         iOpen(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      if(open <= 0.0 ||
         close <= 0.0 ||
         high <= 0.0 ||
         low <= 0.0)
      {
         continue;
      }

      if(close <= open)
         continue;

      // Candle closes above the session high.
      if(close <= sessionHigh)
         continue;

      // Require the candle to have meaningful body strength.
      double range = high - low;

      if(range <= 0.0)
         continue;

      double bodyRatio =
         MathAbs(close - open) / range;

      if(bodyRatio >= ICT_RETEST_MIN_BODY_RATIO)
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bearish session continuation
//-------------------------------------------------------------------
bool SE_BearishContinuation(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 2)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   for(int shift = 1;
       shift <= maximum;
       shift++)
   {
      double open =
         iOpen(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      if(open <= 0.0 ||
         close <= 0.0 ||
         high <= 0.0 ||
         low <= 0.0)
      {
         continue;
      }

      if(close >= open)
         continue;

      // Candle closes below the session low.
      if(close >= sessionLow)
         continue;

      double range = high - low;

      if(range <= 0.0)
         continue;

      double bodyRatio =
         MathAbs(close - open) / range;

      if(bodyRatio >= ICT_RETEST_MIN_BODY_RATIO)
         return true;
   }

   return false;
}

//-------------------------------------------------------------------
// Detect bullish session reversal
//-------------------------------------------------------------------
bool SE_BullishReversal(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   bool sweep =
      SE_BullishSweep(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars
      );

   if(!sweep)
      return false;

   bool rejection =
      SE_BullishRejection(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars
      );

   if(!rejection)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Detect bearish session reversal
//-------------------------------------------------------------------
bool SE_BearishReversal(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   bool sweep =
      SE_BearishSweep(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars
      );

   if(!sweep)
      return false;

   bool rejection =
      SE_BearishRejection(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars
      );

   if(!rejection)
      return false;

   return true;
}

//-------------------------------------------------------------------
// Detect retest above session high
//-------------------------------------------------------------------
bool SE_BullishRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionHigh,
   const int lookbackBars)
{
   if(sessionHigh <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 2)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   bool breakoutSeen = false;

   for(int shift = maximum;
       shift >= 1;
       shift--)
   {
      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      if(high <= 0.0 ||
         low <= 0.0 ||
         close <= 0.0)
      {
         continue;
      }

      if(!breakoutSeen)
      {
         if(close > sessionHigh)
            breakoutSeen = true;

         continue;
      }

      // After breakout, price returns to the level
      // and closes back above it.
      if(low <= sessionHigh &&
         close > sessionHigh)
      {
         return true;
      }
   }

   return false;
}

//-------------------------------------------------------------------
// Detect retest below session low
//-------------------------------------------------------------------
bool SE_BearishRetest(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double sessionLow,
   const int lookbackBars)
{
   if(sessionLow <= 0.0)
      return false;

   int bars = Bars(symbol,timeframe);

   if(bars <= 2)
      return false;

   int maximum =
      MathMin(lookbackBars,bars - 1);

   bool breakoutSeen = false;

   for(int shift = maximum;
       shift >= 1;
       shift--)
   {
      double high =
         iHigh(symbol,timeframe,shift);

      double low =
         iLow(symbol,timeframe,shift);

      double close =
         iClose(symbol,timeframe,shift);

      if(high <= 0.0 ||
         low <= 0.0 ||
         close <= 0.0)
      {
         continue;
      }

      if(!breakoutSeen)
      {
         if(close < sessionLow)
            breakoutSeen = true;

         continue;
      }

      // After bearish breakout, price returns to the level
      // and closes back below it.
      if(high >= sessionLow &&
         close < sessionLow)
      {
         return true;
      }
   }

   return false;
}
//-------------------------------------------------------------------
// Analyze a complete session
//-------------------------------------------------------------------
bool SE_AnalyzeSession(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const ENUM_SESSION_TYPE session,
   const datetime referenceTime,
   const int lookbackBars,
   SessionAnalysis &out)
{
   ResetSessionAnalysis(out);

   if(!SE_IsGold(symbol))
      return false;

   if(session == SESSION_NONE)
      return false;

   datetime sessionStart = 0;
   datetime sessionEnd = 0;

   if(!SE_GetSessionBounds(
         session,
         referenceTime,
         sessionStart,
         sessionEnd))
   {
      return false;
   }

   double sessionHigh = 0.0;
   double sessionLow = 0.0;
   int barsAnalyzed = 0;

   if(!SE_FindSessionRange(
         symbol,
         timeframe,
         sessionStart,
         sessionEnd,
         sessionHigh,
         sessionLow,
         barsAnalyzed))
   {
      return false;
   }

   out.valid = true;

   out.session = session;
   out.sessionStart = sessionStart;
   out.sessionEnd = sessionEnd;

   out.sessionHigh = sessionHigh;
   out.sessionLow = sessionLow;

   out.sessionMidpoint =
      SE_SessionMidpoint(
         sessionHigh,
         sessionLow);

   out.sessionRange =
      SE_SessionRange(
         sessionHigh,
         sessionLow);

   out.barsAnalyzed = barsAnalyzed;

   // ---------------------------------------------------------------
   // Liquidity events
   // ---------------------------------------------------------------
   out.highTaken =
      SE_HighTaken(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars);

   out.lowTaken =
      SE_LowTaken(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars);

   out.bullishSweep =
      SE_BullishSweep(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars);

   out.bearishSweep =
      SE_BearishSweep(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars);

   // ---------------------------------------------------------------
   // Breakout events
   // ---------------------------------------------------------------
   out.bullishBreakout =
      SE_BullishBreakout(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars);

   out.bearishBreakout =
      SE_BearishBreakout(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars);

   // ---------------------------------------------------------------
   // Retests
   // ---------------------------------------------------------------
   out.bullishRetest =
      SE_BullishRetest(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars);

   out.bearishRetest =
      SE_BearishRetest(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars);

   // ---------------------------------------------------------------
   // Reversals
   // ---------------------------------------------------------------
   out.bullishReversal =
      SE_BullishReversal(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars);

   out.bearishReversal =
      SE_BearishReversal(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars);

   // ---------------------------------------------------------------
   // Continuations
   // ---------------------------------------------------------------
   out.bullishContinuation =
      SE_BullishContinuation(
         symbol,
         timeframe,
         sessionHigh,
         lookbackBars);

   out.bearishContinuation =
      SE_BearishContinuation(
         symbol,
         timeframe,
         sessionLow,
         lookbackBars);

   // ---------------------------------------------------------------
   // Confluence scoring
   // ---------------------------------------------------------------
   out.score = 0.0;
   out.direction = SESSION_DIRECTION_NONE;

   if(out.bullishSweep)
   {
      out.score += 15.0;
      out.direction = SESSION_DIRECTION_BULLISH;
   }

   if(out.bearishSweep)
   {
      out.score += 15.0;
      out.direction = SESSION_DIRECTION_BEARISH;
   }

   if(out.bullishReversal)
   {
      out.score += 15.0;
      out.direction = SESSION_DIRECTION_BULLISH;
   }

   if(out.bearishReversal)
   {
      out.score += 15.0;
      out.direction = SESSION_DIRECTION_BEARISH;
   }

   if(out.bullishBreakout)
   {
      out.score += 10.0;

      if(out.direction == SESSION_DIRECTION_NONE)
         out.direction = SESSION_DIRECTION_BULLISH;
   }

   if(out.bearishBreakout)
   {
      out.score += 10.0;

      if(out.direction == SESSION_DIRECTION_NONE)
         out.direction = SESSION_DIRECTION_BEARISH;
   }

   if(out.bullishRetest)
   {
      out.score += 15.0;
      out.direction = SESSION_DIRECTION_BULLISH;
   }

   if(out.bearishRetest)
   {
      out.score += 15.0;
      out.direction = SESSION_DIRECTION_BEARISH;
   }

   if(out.bullishContinuation)
   {
      out.score += 10.0;
      out.direction = SESSION_DIRECTION_BULLISH;
   }

   if(out.bearishContinuation)
   {
      out.score += 10.0;
      out.direction = SESSION_DIRECTION_BEARISH;
   }

   // ---------------------------------------------------------------
   // Session quality
   // ---------------------------------------------------------------
   if(out.sessionRange > 0.0)
   {
      double currentPrice =
         SE_CurrentPrice(symbol);

      if(currentPrice > 0.0)
      {
         if(currentPrice > out.sessionHigh)
         {
            out.score += 5.0;
         }
         else if(currentPrice < out.sessionLow)
         {
            out.score += 5.0;
         }
      }
   }

   // ---------------------------------------------------------------
   // Build explanation
   // ---------------------------------------------------------------
   out.reason =
      SE_SessionToString(session) +
      " session analysis completed.";

   out.evidence =
      "Range=" +
      DoubleToString(out.sessionRange,_Digits);

   if(out.bullishSweep)
      out.evidence += " | bullish sweep";

   if(out.bearishSweep)
      out.evidence += " | bearish sweep";

   if(out.bullishBreakout)
      out.evidence += " | bullish breakout";

   if(out.bearishBreakout)
      out.evidence += " | bearish breakout";

   if(out.bullishRetest)
      out.evidence += " | bullish retest";

   if(out.bearishRetest)
      out.evidence += " | bearish retest";

   if(out.bullishReversal)
      out.evidence += " | bullish reversal";

   if(out.bearishReversal)
      out.evidence += " | bearish reversal";

   if(out.bullishContinuation)
      out.evidence += " | bullish continuation";

   if(out.bearishContinuation)
      out.evidence += " | bearish continuation";

   return true;
}

//-------------------------------------------------------------------
// Analyze the currently active session
//-------------------------------------------------------------------
bool SE_AnalyzeCurrentSession(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const datetime referenceTime,
   const int lookbackBars,
   SessionAnalysis &out)
{
   ResetSessionAnalysis(out);

   ENUM_SESSION_TYPE session =
      SE_GetCurrentSession(referenceTime);

   if(session == SESSION_NONE)
      return false;

   return SE_AnalyzeSession(
      symbol,
      timeframe,
      session,
      referenceTime,
      lookbackBars,
      out);
}

//-------------------------------------------------------------------
// Session directional helpers
//-------------------------------------------------------------------
bool SE_IsBullish(
   const SessionAnalysis &s)
{
   return s.valid &&
          s.direction == SESSION_DIRECTION_BULLISH;
}

bool SE_IsBearish(
   const SessionAnalysis &s)
{
   return s.valid &&
          s.direction == SESSION_DIRECTION_BEARISH;
}

//-------------------------------------------------------------------
// Session actionability
//-------------------------------------------------------------------
bool SE_IsActionable(
   const SessionAnalysis &s)
{
   if(!s.valid)
      return false;

   // A session alone must never be enough to trigger a trade.
   // It only becomes a useful confluence component when a
   // meaningful event is present.
   int confirmations = 0;

   if(s.bullishSweep || s.bearishSweep)
      confirmations++;

   if(s.bullishBreakout || s.bearishBreakout)
      confirmations++;

   if(s.bullishRetest || s.bearishRetest)
      confirmations++;

   if(s.bullishReversal || s.bearishReversal)
      confirmations++;

   if(s.bullishContinuation || s.bearishContinuation)
      confirmations++;

   return confirmations >= 2;
}

//-------------------------------------------------------------------
// Session score
//-------------------------------------------------------------------
double SE_GetScore(
   const SessionAnalysis &s)
{
   if(!s.valid)
      return 0.0;

   return s.score;
}

//-------------------------------------------------------------------
// Print session analysis
//-------------------------------------------------------------------
void SE_Print(
   const SessionAnalysis &s)
{
   if(!s.valid)
   {
      Print("SessionEngine: no valid session analysis.");
      return;
   }

   Print(
      "SessionEngine: ",
      SE_SessionToString(s.session),
      " | direction=",
      SE_DirectionToString(s.direction),
      " | score=",
      DoubleToString(s.score,1),
      " | high=",
      DoubleToString(s.sessionHigh,_Digits),
      " | low=",
      DoubleToString(s.sessionLow,_Digits),
      " | range=",
      DoubleToString(s.sessionRange,_Digits),
      " | actionable=",
      SE_IsActionable(s) ? "YES" : "NO"
   );

   Print(
      "SessionEngine evidence: ",
      s.evidence
   );
}

//-------------------------------------------------------------------
// Session status
//-------------------------------------------------------------------
string SE_Status(
   const string symbol,
   const datetime referenceTime)
{
   if(!SE_IsGold(symbol))
      return "NON-GOLD SYMBOL";

   ENUM_SESSION_TYPE session =
      SE_GetCurrentSession(referenceTime);

   if(session == SESSION_LONDON)
      return "LONDON SESSION";

   if(session == SESSION_NEW_YORK)
      return "NEW YORK SESSION";

   return "ASIA/PRE-SESSION";
}
#endif
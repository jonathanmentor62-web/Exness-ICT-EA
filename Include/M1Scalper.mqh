//+------------------------------------------------------------------+
//| M1Scalper.mqh - reactive M1 momentum/reversal scalper           |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_M1_SCALPER_MQH__
#define __EXNESS_ICT_M1_SCALPER_MQH__

#include "Config.mqh"

struct M1ScalpSignal
{
   bool valid;
   ENUM_ORDER_TYPE orderType;
   double score;
   double atr;
   double entry;
   double stopLoss;
   double takeProfit;
   datetime barTime;
   string reason;
};

void ResetM1ScalpSignal(M1ScalpSignal &s)
{
   s.valid=false;
   s.orderType=ORDER_TYPE_BUY;
   s.score=0.0;
   s.atr=0.0;
   s.entry=0.0;
   s.stopLoss=0.0;
   s.takeProfit=0.0;
   s.barTime=0;
   s.reason="";
}

double M1_ATR(const string symbol,const int period=14)
{
   int handle=iATR(symbol,PERIOD_M1,period);
   if(handle==INVALID_HANDLE) return(0.0);

   double buffer[];
   ArraySetAsSeries(buffer,true);

   double value=0.0;

   if(CopyBuffer(handle,0,1,1,buffer)==1)
      value=buffer[0];

   IndicatorRelease(handle);
   return(value);
}

double M1_AverageRange(const string symbol,const int lookback=20)
{
   if(lookback<3) return(0.0);

   MqlRates rates[];
   ArraySetAsSeries(rates,true);

   int copied=CopyRates(symbol,PERIOD_M1,1,lookback,rates);

   if(copied<3) return(0.0);

   double sum=0.0;

   for(int i=0;i<copied;i++)
      sum+=(rates[i].high-rates[i].low);

   return(sum/copied);
}

double M1_TickPressure(const string symbol,const int seconds=8)
{
   MqlTick ticks[];

   datetime now=TimeCurrent();
   datetime from=now-seconds;

   ulong fromMsc=(ulong)from*1000;
   ulong toMsc=(ulong)now*1000;

   int copied=CopyTicksRange(
      symbol,
      ticks,
      COPY_TICKS_INFO,
      fromMsc,
      toMsc
   );

   if(copied<2)
      return(0.0);

   int up=0;
   int down=0;

   double previous=0.0;

   for(int i=0;i<copied;i++)
   {
      double mid=
         (ticks[i].bid>0.0 && ticks[i].ask>0.0)
         ? (ticks[i].bid+ticks[i].ask)*0.5
         : (ticks[i].last>0.0 ? ticks[i].last : 0.0);

      if(mid<=0.0)
         continue;

      if(previous>0.0)
      {
         if(mid>previous)
            up++;
         else if(mid<previous)
            down++;
      }

      previous=mid;
   }

   int total=up+down;

   if(total<=0)
      return(0.0);

   return((double)(up-down)/(double)total);
}

double M1_MomentumScore(
   const string symbol,
   const MqlRates &bar,
   const double avgRange,
   const double tickPressure
)
{
   double range=bar.high-bar.low;

   if(range<=0.0 || avgRange<=0.0)
      return(0.0);

   double body=MathAbs(bar.close-bar.open);
   double bodyRatio=body/range;

   double rangeExpansion=MathMin(range/avgRange,3.0);

   double expansionScore=
      MathMin(rangeExpansion/1.5,1.0)*35.0;

   double bodyScore=
      MathMin(bodyRatio/0.70,1.0)*25.0;

   double pressureScore=
      MathMin(MathAbs(tickPressure),1.0)*25.0;

   double directionAgreement=0.0;

   if(bar.close>bar.open && tickPressure>0.0)
      directionAgreement=15.0;

   if(bar.close<bar.open && tickPressure<0.0)
      directionAgreement=15.0;

   return(
      MathMin(
         expansionScore+
         bodyScore+
         pressureScore+
         directionAgreement,
         100.0
      )
   );
}

bool M1_BuildSignal(
   const string symbol,
   M1ScalpSignal &out
)
{
   ResetM1ScalpSignal(out);

   if(symbol=="")
      return(false);

   if(Bars(symbol,PERIOD_M1)<ICT_SCALP_MIN_HISTORY)
      return(false);

   MqlRates rates[];
   ArraySetAsSeries(rates,true);

   if(CopyRates(symbol,PERIOD_M1,1,4,rates)<4)
      return(false);

   MqlRates closed=rates[0];

   double range=closed.high-closed.low;

   if(range<=0.0)
      return(false);

   double avgRange=
      M1_AverageRange(
         symbol,
         ICT_SCALP_RANGE_LOOKBACK
      );

   double atr=
      M1_ATR(
         symbol,
         ICT_SCALP_ATR_PERIOD
      );

   if(avgRange<=0.0 || atr<=0.0)
      return(false);

   double pressure=
      M1_TickPressure(
         symbol,
         ICT_SCALP_TICK_WINDOW_SEC
      );

   double score=
      M1_MomentumScore(
         symbol,
         closed,
         avgRange,
         pressure
      );

   if(score<ICT_SCALP_MIN_SCORE)
      return(false);

   double upperWick=
      closed.high-
      MathMax(closed.open,closed.close);

   double lowerWick=
      MathMin(closed.open,closed.close)-
      closed.low;

   double body=
      MathAbs(closed.close-closed.open);

   bool bullishImpulse=
      (
         closed.close>closed.open &&
         range>=avgRange*ICT_SCALP_RANGE_MULT
      );

   bool bearishImpulse=
      (
         closed.close<closed.open &&
         range>=avgRange*ICT_SCALP_RANGE_MULT
      );

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return(false);

   double entryBuy=
      (tick.ask>0.0 ? tick.ask : closed.close);

   double entrySell=
      (tick.bid>0.0 ? tick.bid : closed.close);

   bool sellReversal=
      (
         bullishImpulse &&
         upperWick>=
            MathMax(
               body*ICT_SCALP_REJECTION_RATIO,
               atr*0.10
            ) &&
         pressure<=-ICT_SCALP_PRESSURE_THRESHOLD
      );

   bool buyReversal=
      (
         bearishImpulse &&
         lowerWick>=
            MathMax(
               body*ICT_SCALP_REJECTION_RATIO,
               atr*0.10
            ) &&
         pressure>=ICT_SCALP_PRESSURE_THRESHOLD
      );

   bool buyContinuation=
      (
         bullishImpulse &&
         pressure>=ICT_SCALP_PRESSURE_THRESHOLD
      );

   bool sellContinuation=
      (
         bearishImpulse &&
         pressure<=-ICT_SCALP_PRESSURE_THRESHOLD
      );

   ENUM_ORDER_TYPE type;
   double entry=0.0;
   string reason="";

   if(sellReversal)
   {
      type=ORDER_TYPE_SELL;
      entry=entrySell;

      reason=
         "M1 bullish impulse rejected; selling pressure returned.";
   }
   else if(buyReversal)
   {
      type=ORDER_TYPE_BUY;
      entry=entryBuy;

      reason=
         "M1 bearish impulse rejected; buying pressure returned.";
   }
   else if(buyContinuation)
   {
      type=ORDER_TYPE_BUY;
      entry=entryBuy;

      reason=
         "M1 bullish momentum continuation.";
   }
   else if(sellContinuation)
   {
      type=ORDER_TYPE_SELL;
      entry=entrySell;

      reason=
         "M1 bearish momentum continuation.";
   }
   else
   {
      return(false);
   }

   double slDistance=
      MathMax(
         atr*ICT_SCALP_SL_ATR_MULT,
         range*ICT_SCALP_SL_RANGE_MULT
      );

   double tpDistance=
      MathMax(
         atr*ICT_SCALP_TP_ATR_MULT,
         range*ICT_SCALP_TP_RANGE_MULT
      );

   if(type==ORDER_TYPE_BUY)
   {
      out.stopLoss=
         entry-slDistance;

      out.takeProfit=
         entry+tpDistance;
   }
   else
   {
      out.stopLoss=
         entry+slDistance;

      out.takeProfit=
         entry-tpDistance;
   }

   out.valid=true;
   out.orderType=type;
   out.score=score;
   out.atr=atr;
   out.entry=entry;
   out.barTime=closed.time;
   out.reason=reason;

   return(true);
}

#endif
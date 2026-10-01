//+------------------------------------------------------------------+
//| GrowthController.mqh                                             |
//| Dynamic 30-day account growth target                             |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_GROWTH_CONTROLLER_MQH__
#define __EXNESS_ICT_GROWTH_CONTROLLER_MQH__

//==================================================================
// GROWTH SETTINGS
//==================================================================

// Target multiplier.
// Example:
// $5   -> $10,000
// $20  -> $40,000
// $100 -> $200,000
#define GC_TARGET_MULTIPLIER       2000.0

// Growth cycle duration.
#define GC_TARGET_DAYS             30


//==================================================================
// GROWTH STATE
//==================================================================

struct GrowthController
{
   bool     initialized;

   datetime startTime;
   datetime targetTime;

   double   startingEquity;
   double   targetEquity;
   double   currentEquity;

   double   profitRequired;
   double   profitAchieved;

   double   progressPercent;

   int      daysElapsed;
   int      daysRemaining;

   bool     targetReached;
};


//==================================================================
// RESET
//==================================================================

void GC_Reset(GrowthController &gc)
{
   gc.initialized      = false;

   gc.startTime        = 0;
   gc.targetTime       = 0;

   gc.startingEquity   = 0.0;
   gc.targetEquity     = 0.0;
   gc.currentEquity    = 0.0;

   gc.profitRequired   = 0.0;
   gc.profitAchieved   = 0.0;

   gc.progressPercent  = 0.0;

   gc.daysElapsed      = 0;
   gc.daysRemaining    = GC_TARGET_DAYS;

   gc.targetReached    = false;
}


//==================================================================
// INITIALIZE
//==================================================================

bool GC_Initialize(
   GrowthController &gc,
   const double startingEquity
)
{
   GC_Reset(gc);

   if(startingEquity <= 0.0)
      return false;

   gc.initialized    = true;

   gc.startTime      = TimeCurrent();

   gc.targetTime     =
      gc.startTime + (GC_TARGET_DAYS * 86400);

   gc.startingEquity = startingEquity;

   // Dynamic target:
   //
   // Starting Equity × 2,000
   //
   // $5  -> $10,000
   // $20 -> $40,000
   // $100 -> $200,000

   gc.targetEquity =
      gc.startingEquity * GC_TARGET_MULTIPLIER;

   gc.currentEquity =
      startingEquity;

   gc.profitRequired =
      gc.targetEquity - gc.startingEquity;

   gc.profitAchieved =
      0.0;

   return true;
}


//==================================================================
// UPDATE
//==================================================================

bool GC_Update(
   GrowthController &gc,
   const double currentEquity
)
{
   if(!gc.initialized)
      return false;

   gc.currentEquity = currentEquity;

   gc.profitAchieved =
      gc.currentEquity - gc.startingEquity;

   gc.profitRequired =
      MathMax(
         0.0,
         gc.targetEquity - gc.startingEquity
      );


   //===============================================================
   // TARGET REACHED
   //===============================================================

   if(gc.currentEquity >= gc.targetEquity)
   {
      gc.targetReached = true;
      gc.progressPercent = 100.0;
   }
   else
   {
      gc.targetReached = false;

      if(gc.profitRequired > 0.0)
      {
         gc.progressPercent =
            (gc.profitAchieved / gc.profitRequired)
            * 100.0;

         gc.progressPercent =
            MathMax(
               0.0,
               MathMin(
                  100.0,
                  gc.progressPercent
               )
            );
      }
      else
      {
         gc.progressPercent = 0.0;
      }
   }


   //===============================================================
   // TIME PROGRESS
   //===============================================================

   datetime now = TimeCurrent();

   long elapsedSeconds =
      (long)(now - gc.startTime);

   long remainingSeconds =
      (long)(gc.targetTime - now);

   if(elapsedSeconds < 0)
      elapsedSeconds = 0;

   if(remainingSeconds < 0)
      remainingSeconds = 0;


   gc.daysElapsed =
      (int)(elapsedSeconds / 86400);

   gc.daysRemaining =
      GC_TARGET_DAYS - gc.daysElapsed;

   if(gc.daysElapsed > GC_TARGET_DAYS)
      gc.daysElapsed = GC_TARGET_DAYS;

   if(gc.daysRemaining < 0)
      gc.daysRemaining = 0;


   return true;
}


//==================================================================
// TARGET CHECK
//==================================================================

bool GC_TargetReached(
   const GrowthController &gc
)
{
   return gc.targetReached;
}


//==================================================================
// GET CURRENT PROGRESS
//==================================================================

double GC_GetProgressPercent(
   const GrowthController &gc
)
{
   return gc.progressPercent;
}


//==================================================================
// GET TARGET
//==================================================================

double GC_GetTargetEquity(
   const GrowthController &gc
)
{
   return gc.targetEquity;
}


//==================================================================
// GET STARTING EQUITY
//==================================================================

double GC_GetStartingEquity(
   const GrowthController &gc
)
{
   return gc.startingEquity;
}


//==================================================================
// GET CURRENT EQUITY
//==================================================================

double GC_GetCurrentEquity(
   const GrowthController &gc
)
{
   return gc.currentEquity;
}


//==================================================================
// GET REQUIRED PROFIT
//==================================================================

double GC_GetProfitRequired(
   const GrowthController &gc
)
{
   return gc.profitRequired;
}


//==================================================================
// GET ACHIEVED PROFIT
//==================================================================

double GC_GetProfitAchieved(
   const GrowthController &gc
)
{
   return gc.profitAchieved;
}


//==================================================================
// GET DAYS REMAINING
//==================================================================

int GC_GetDaysRemaining(
   const GrowthController &gc
)
{
   return gc.daysRemaining;
}


//==================================================================
// GET DAYS ELAPSED
//==================================================================

int GC_GetDaysElapsed(
   const GrowthController &gc
)
{
   return gc.daysElapsed;
}


//==================================================================
// GET REQUIRED DAILY GROWTH
//==================================================================
//
// This calculates the average compounded daily growth required
// from the CURRENT equity to reach the TARGET by the deadline.
//
// It is a planning metric only.
//
// It DOES NOT override the risk engine.
// It DOES NOT force trades.
// It DOES NOT increase risk automatically.
//

double GC_GetRequiredDailyGrowth(
   const GrowthController &gc
)
{
   if(!gc.initialized)
      return 0.0;

   if(gc.targetReached)
      return 0.0;

   if(gc.currentEquity <= 0.0)
      return 0.0;

   if(gc.daysRemaining <= 0)
      return 0.0;

   double ratio =
      gc.targetEquity / gc.currentEquity;

   if(ratio <= 1.0)
      return 0.0;

   double dailyGrowth =
      MathPow(
         ratio,
         1.0 / (double)gc.daysRemaining
      ) - 1.0;

   return dailyGrowth * 100.0;
}


//==================================================================
// PRINT STATUS
//==================================================================

void GC_PrintStatus(
   const GrowthController &gc
)
{
   if(!gc.initialized)
   {
      Print("[GROWTH] Controller not initialized.");
      return;
   }

   Print(
      "[GROWTH] Starting=$",
      DoubleToString(gc.startingEquity, 2),
      " | Target=$",
      DoubleToString(gc.targetEquity, 2),
      " | Current=$",
      DoubleToString(gc.currentEquity, 2),
      " | Progress=",
      DoubleToString(gc.progressPercent, 2),
      "%",
      " | Days remaining=",
      IntegerToString(gc.daysRemaining),
      " | Required daily growth=",
      DoubleToString(
         GC_GetRequiredDailyGrowth(gc),
         2
      ),
      "%"
   );
}


//==================================================================
// TARGET MULTIPLIER INFORMATION
//==================================================================

double GC_GetTargetMultiplier()
{
   return GC_TARGET_MULTIPLIER;
}


//==================================================================
// TARGET DURATION
//==================================================================

int GC_GetTargetDays()
{
   return GC_TARGET_DAYS;
}


#endif
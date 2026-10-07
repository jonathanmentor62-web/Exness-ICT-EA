//+------------------------------------------------------------------+
//| GrowthController.mqh                                             |
//| Gold EA - advisory account-growth controller                     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_GROWTH_CONTROLLER_MQH__
#define __EXNESS_GOLD_GROWTH_CONTROLLER_MQH__

//==================================================================
// GROWTH SETTINGS
//==================================================================
//
// IMPORTANT:
// This controller is an OBJECTIVE/TRACKING system only.
//
// It does NOT:
// - force trades
// - increase risk
// - override RiskEngine
// - override spread protection
// - override daily-loss protection
// - override broker limits
// - guarantee the target
//
//==================================================================

#define GC_TARGET_MULTIPLIER  2000.0
#define GC_TARGET_DAYS        30


//==================================================================
// GROWTH STATE
//==================================================================

struct GrowthController
{
   bool initialized;

   datetime startTime;
   datetime targetTime;

   double startingEquity;
   double targetEquity;
   double currentEquity;

   double profitRequired;
   double profitAchieved;

   double progressPercent;

   int daysElapsed;
   int daysRemaining;

   bool targetReached;
};


//==================================================================
// RESET
//==================================================================

void GC_Reset(
   GrowthController &gc
)
{
   gc.initialized=false;

   gc.startTime=0;
   gc.targetTime=0;

   gc.startingEquity=0.0;
   gc.targetEquity=0.0;
   gc.currentEquity=0.0;

   gc.profitRequired=0.0;
   gc.profitAchieved=0.0;

   gc.progressPercent=0.0;

   gc.daysElapsed=0;
   gc.daysRemaining=GC_TARGET_DAYS;

   gc.targetReached=false;
}


//==================================================================
// GLOBAL VARIABLE NAMES
//==================================================================

string GC_Key(
   const string suffix
)
{
   long login=
      AccountInfoInteger(
         ACCOUNT_LOGIN
      );

   return(
      "EXG_GC_" +
      IntegerToString(login) +
      "_" +
      suffix
   );
}


//==================================================================
// LOAD SAVED STATE
//==================================================================

bool GC_LoadState(
   GrowthController &gc
)
{
   string keyStart=
      GC_Key("START");

   string keyEquity=
      GC_Key("EQUITY");

   string keyTime=
      GC_Key("TIME");

   if(
      !GlobalVariableCheck(keyStart) ||
      !GlobalVariableCheck(keyEquity) ||
      !GlobalVariableCheck(keyTime)
   )
   {
      return false;
   }

   double startEquity=
      GlobalVariableGet(keyStart);

   double targetEquity=
      GlobalVariableGet(keyEquity);

   datetime startTime=
      (datetime)
      GlobalVariableGet(keyTime);

   if(
      startEquity<=0.0 ||
      targetEquity<=0.0 ||
      startTime<=0
   )
   {
      return false;
   }

   gc.startingEquity=startEquity;

   gc.targetEquity=targetEquity;

   gc.startTime=startTime;

   gc.targetTime=
      gc.startTime+
      (GC_TARGET_DAYS*86400);

   gc.initialized=true;

   return true;
}


//==================================================================
// SAVE STATE
//==================================================================

void GC_SaveState(
   const GrowthController &gc
)
{
   if(!gc.initialized)
      return;

   GlobalVariableSet(
      GC_Key("START"),
      gc.startingEquity
   );

   GlobalVariableSet(
      GC_Key("EQUITY"),
      gc.targetEquity
   );

   GlobalVariableSet(
      GC_Key("TIME"),
      (double)gc.startTime
   );
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

   if(startingEquity<=0.0)
      return false;


   // ---------------------------------------------------------------
   // Try to restore an existing 30-day cycle.
   // ---------------------------------------------------------------

   if(GC_LoadState(gc))
   {
      GC_Update(
         gc,
         startingEquity
      );

      return true;
   }


   // ---------------------------------------------------------------
   // Start a new cycle.
   // ---------------------------------------------------------------

   gc.initialized=true;

   gc.startTime=
      TimeCurrent();

   gc.targetTime=
      gc.startTime+
      (GC_TARGET_DAYS*86400);

   gc.startingEquity=
      startingEquity;

   gc.targetEquity=
      gc.startingEquity*
      GC_TARGET_MULTIPLIER;

   gc.currentEquity=
      startingEquity;

   gc.profitRequired=
      MathMax(
         0.0,
         gc.targetEquity-
         gc.startingEquity
      );

   gc.profitAchieved=0.0;

   gc.progressPercent=0.0;

   gc.daysElapsed=0;

   gc.daysRemaining=
      GC_TARGET_DAYS;

   gc.targetReached=false;

   GC_SaveState(gc);

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

   if(currentEquity<=0.0)
      return false;

   gc.currentEquity=
      currentEquity;

   gc.profitAchieved=
      gc.currentEquity-
      gc.startingEquity;

   gc.profitRequired=
      MathMax(
         0.0,
         gc.targetEquity-
         gc.startingEquity
      );


   // ---------------------------------------------------------------
   // Target
   // ---------------------------------------------------------------

   if(
      gc.currentEquity>=
      gc.targetEquity
   )
   {
      gc.targetReached=true;
      gc.progressPercent=100.0;
   }
   else
   {
      gc.targetReached=false;

      if(gc.profitRequired>0.0)
      {
         gc.progressPercent=
            (
               gc.profitAchieved/
               gc.profitRequired
            )*
            100.0;

         gc.progressPercent=
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
         gc.progressPercent=0.0;
      }
   }


   // ---------------------------------------------------------------
   // Time
   // ---------------------------------------------------------------

   datetime now=
      TimeCurrent();

   long elapsedSeconds=
      (long)(
         now-
         gc.startTime
      );

   long remainingSeconds=
      (long)(
         gc.targetTime-
         now
      );

   if(elapsedSeconds<0)
      elapsedSeconds=0;

   if(remainingSeconds<0)
      remainingSeconds=0;

   gc.daysElapsed=
      (int)(
         elapsedSeconds/
         86400
      );

   if(gc.daysElapsed>
      GC_TARGET_DAYS)
   {
      gc.daysElapsed=
         GC_TARGET_DAYS;
   }

   gc.daysRemaining=
      GC_TARGET_DAYS-
      gc.daysElapsed;

   if(gc.daysRemaining<0)
      gc.daysRemaining=0;

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
// PROGRESS
//==================================================================

double GC_GetProgressPercent(
   const GrowthController &gc
)
{
   return gc.progressPercent;
}


//==================================================================
// TARGET EQUITY
//==================================================================

double GC_GetTargetEquity(
   const GrowthController &gc
)
{
   return gc.targetEquity;
}


//==================================================================
// STARTING EQUITY
//==================================================================

double GC_GetStartingEquity(
   const GrowthController &gc
)
{
   return gc.startingEquity;
}


//==================================================================
// CURRENT EQUITY
//==================================================================

double GC_GetCurrentEquity(
   const GrowthController &gc
)
{
   return gc.currentEquity;
}


//==================================================================
// REQUIRED PROFIT
//==================================================================

double GC_GetProfitRequired(
   const GrowthController &gc
)
{
   return gc.profitRequired;
}


//==================================================================
// ACHIEVED PROFIT
//==================================================================

double GC_GetProfitAchieved(
   const GrowthController &gc
)
{
   return gc.profitAchieved;
}


//==================================================================
// DAYS REMAINING
//==================================================================

int GC_GetDaysRemaining(
   const GrowthController &gc
)
{
   return gc.daysRemaining;
}


//==================================================================
// DAYS ELAPSED
//==================================================================

int GC_GetDaysElapsed(
   const GrowthController &gc
)
{
   return gc.daysElapsed;
}


//==================================================================
// REQUIRED DAILY GROWTH
//==================================================================
//
// Advisory calculation only.
// It NEVER changes risk or trade frequency.
//==================================================================

double GC_GetRequiredDailyGrowth(
   const GrowthController &gc
)
{
   if(!gc.initialized)
      return 0.0;

   if(gc.targetReached)
      return 0.0;

   if(gc.currentEquity<=0.0)
      return 0.0;

   if(gc.daysRemaining<=0)
      return 0.0;

   double ratio=
      gc.targetEquity/
      gc.currentEquity;

   if(ratio<=1.0)
      return 0.0;

   double dailyGrowth=
      MathPow(
         ratio,
         1.0/
         (double)gc.daysRemaining
      )-
      1.0;

   return dailyGrowth*100.0;
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
      Print(
         "[GROWTH] Controller not initialized."
      );

      return;
   }

   Print(
      "[GROWTH] Starting=$",
      DoubleToString(
         gc.startingEquity,
         2
      ),
      " | Target=$",
      DoubleToString(
         gc.targetEquity,
         2
      ),
      " | Current=$",
      DoubleToString(
         gc.currentEquity,
         2
      ),
      " | Progress=",
      DoubleToString(
         gc.progressPercent,
         2
      ),
      "%",
      " | Days remaining=",
      IntegerToString(
         gc.daysRemaining
      ),
      " | Required daily growth=",
      DoubleToString(
         GC_GetRequiredDailyGrowth(gc),
         2
      ),
      "%"
   );
}


//==================================================================
// INFORMATION
//==================================================================

double GC_GetTargetMultiplier()
{
   return GC_TARGET_MULTIPLIER;
}


int GC_GetTargetDays()
{
   return GC_TARGET_DAYS;
}

#endif
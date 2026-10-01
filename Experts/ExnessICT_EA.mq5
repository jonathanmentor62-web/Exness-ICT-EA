//+------------------------------------------------------------------+
//| ExnessICT_EA.mq5                                                 |
//| Exness ICT EA - integrated development build                     |
//+------------------------------------------------------------------+
#property strict
#property version   "0.90"
#property description "H4/M15/M5 ICT analysis plus reactive M1 momentum scalper."
#property description "Equity-based risk engine, daily protection and growth controller."
#property description "Trading remains disabled by default during development/testing."

#include <Trade/Trade.mqh>

#include "../Include/Config.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/StructureSignal.mqh"
#include "../Include/Liquidity.mqh"
#include "../Include/FVG.mqh"
#include "../Include/OrderBlock.mqh"
#include "../Include/M5Confirmation.mqh"
#include "../Include/RiskEngine.mqh"
#include "../Include/M1Scalper.mqh"
#include "../Include/ExecutionEngine.mqh"
#include "../Include/GrowthController.mqh"

CTrade Trade;

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+

input ENUM_TIMEFRAMES InpPrimaryTF       = ICT_PRIMARY_TF;
input ENUM_TIMEFRAMES InpConfirmTF       = ICT_CONFIRM_TF;
input ENUM_TIMEFRAMES InpEntryTF         = ICT_ENTRY_TF;

input double          InpRiskPercent     = ICT_RISK_PERCENT;
input double          InpMaxTotalRiskPct = ICT_MAX_TOTAL_RISK_PERCENT;

input ulong           InpMagicNumber     = ICT_MAGIC_NUMBER;
input int             InpMaxSpreadPts    = ICT_MAX_SPREAD_PTS;
input int             InpDeviationPts    = ICT_MAX_SLIPPAGE_PTS;

// IMPORTANT: keep false during development/testing.
input bool            InpEnableTrading   = false;

//+------------------------------------------------------------------+
//| Trading modes                                                    |
//+------------------------------------------------------------------+

enum ENUM_EA_TRADING_MODE
{
   EA_MODE_NORMAL=0,
   EA_MODE_SCALPER=1,
   EA_MODE_AUTO=2
};

input ENUM_EA_TRADING_MODE InpTradingMode = EA_MODE_SCALPER;

//+------------------------------------------------------------------+
//| Symbol scanning                                                  |
//+------------------------------------------------------------------+

input bool InpScanMarketWatchSymbols = true;

//+------------------------------------------------------------------+
//| Scalper settings                                                 |
//+------------------------------------------------------------------+

input double InpScalpMinScore =
   ICT_SCALP_MIN_SCORE;

input int InpScalpMaxHoldSeconds =
   ICT_SCALP_MAX_HOLD_SECONDS;

input int InpScalpCooldownSeconds =
   ICT_SCALP_COOLDOWN_SECONDS;

input int InpScalpMaxPositions =
   ICT_SCALP_MAX_POSITIONS;

input int InpScalpMaxSymbolPositions =
   ICT_SCALP_MAX_SYMBOL_POSITIONS;

//+------------------------------------------------------------------+
//| Daily protection                                                 |
//+------------------------------------------------------------------+

input double InpDailyLossLimitPct = 3.0;

input double InpDailyProfitTargetMoney = 0.0;

//+------------------------------------------------------------------+
//| ICT analysis settings                                            |
//+------------------------------------------------------------------+

input int InpStructureLookback =
   ICT_STRUCTURE_LOOKBACK;

input int InpFVGScanLookback = 20;

input int InpOBScanLookback =
   ICT_OB_LOOKBACK;

//+------------------------------------------------------------------+
//| Global timing state                                              |
//+------------------------------------------------------------------+

datetime g_lastPrimaryBar=0;
datetime g_lastConfirmBar=0;
datetime g_lastEntryBar=0;
datetime g_lastScalpEntryTime=0;

//+------------------------------------------------------------------+
//| H4 setup state                                                   |
//+------------------------------------------------------------------+

bool g_h4SetupActive=false;

ENUM_STRUCTURE_DIRECTION
g_h4SetupDirection=STRUCTURE_UNKNOWN;

datetime g_h4SetupTime=0;

int g_h4SetupShift=-1;

//+------------------------------------------------------------------+
//| Daily account protection state                                   |
//+------------------------------------------------------------------+

datetime g_dayStart=0;

double g_dayStartEquity=0.0;

bool g_dailyLocked=false;

//+------------------------------------------------------------------+
//| Growth controller                                                |
//+------------------------------------------------------------------+

GrowthController g_growthController;

//+------------------------------------------------------------------+
//| Growth controller initialization                                 |
//+------------------------------------------------------------------+

bool InitializeGrowthController()
{
   GC_Reset(g_growthController);

   //-----------------------------------------------------------------
   // Try to recover an existing cycle.
   //-----------------------------------------------------------------

   if(GC_LoadState(
      g_growthController,
      InpMagicNumber))
   {
      if(GC_InitializeExisting(
         g_growthController,
         InpMagicNumber,
         g_growthController.startingEquity,
         g_growthController.startTime))
      {
         GC_Update(
            g_growthController,
            AccountInfoDouble(ACCOUNT_EQUITY)
         );

         Print("[GROWTH] Existing growth cycle restored.");

         GC_PrintStatus(g_growthController);

         return(true);
      }
   }

   //-----------------------------------------------------------------
   // No existing cycle: create one from current equity.
   //-----------------------------------------------------------------

   double equity=
      AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity<=0.0)
   {
      Print("[GROWTH] Cannot initialize: invalid account equity.");
      return(false);
   }

   if(!GC_InitializeNew(
      g_growthController,
      InpMagicNumber,
      equity))
   {
      Print("[GROWTH] Failed to create growth cycle.");
      return(false);
   }

   GC_Update(
      g_growthController,
      equity
   );

   Print("[GROWTH] New growth cycle initialized.");

   GC_PrintStatus(g_growthController);

   return(true);
}

//+------------------------------------------------------------------+
//| Update growth controller                                         |
//+------------------------------------------------------------------+

void UpdateGrowthController()
{
   if(!g_growthController.initialized)
      return;

   double equity=
      AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity<=0.0)
      return;

   GC_Update(
      g_growthController,
      equity
   );
}

//+------------------------------------------------------------------+
//| Growth trading permission                                        |
//+------------------------------------------------------------------+

bool IsGrowthTradingAllowed()
{
   UpdateGrowthController();

   if(!g_growthController.initialized)
      return(false);

   if(GC_TargetReached(g_growthController))
   {
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Confirmation states                                              |
//+------------------------------------------------------------------+

enum ENUM_CONFIRMATION_STATE
{
   CONFIRMATION_NONE=0,
   CONFIRMATION_WAITING,
   CONFIRMATION_CONFIRMED,
   CONFIRMATION_INVALID
};

struct M15Confirmation
{
   bool confirmed;
   bool valid;

   ENUM_CONFIRMATION_STATE state;

   ENUM_STRUCTURE_DIRECTION direction;

   bool displacement;
   bool mss;
   bool bos;
   bool fvgPresent;
   bool orderBlockPresent;

   double brokenLevel;

   datetime confirmationTime;

   int confirmationShift;

   string reason;
};

M15Confirmation g_m15Confirmation;

M5Confirmation g_m5Confirmation;

//+------------------------------------------------------------------+
//| Reset M15 confirmation                                           |
//+------------------------------------------------------------------+

void ResetM15Confirmation(
   M15Confirmation &c)
{
   c.confirmed=false;
   c.valid=false;

   c.state=
      CONFIRMATION_NONE;

   c.direction=
      STRUCTURE_UNKNOWN;

   c.displacement=false;
   c.mss=false;
   c.bos=false;

   c.fvgPresent=false;
   c.orderBlockPresent=false;

   c.brokenLevel=0.0;

   c.confirmationTime=0;

   c.confirmationShift=-1;

   c.reason="";
}

//+------------------------------------------------------------------+
//| Symbol tradability                                               |
//+------------------------------------------------------------------+

bool IsSymbolTradable(
   const string symbol)
{
   if(symbol=="")
      return(false);

   if(!SymbolSelect(symbol,true))
      return(false);

   long mode=0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_MODE,
      mode))
      return(false);

   return(
      mode!=SYMBOL_TRADE_MODE_DISABLED
   );
}

//+------------------------------------------------------------------+
//| Spread filter                                                    |
//+------------------------------------------------------------------+

bool IsSpreadAcceptable(
   const string symbol)
{
   long spread=0;

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_SPREAD,
      spread))
      return(false);

   return(
      spread<=InpMaxSpreadPts
   );
}

//+------------------------------------------------------------------+
//| Current broker/server day start                                  |
//+------------------------------------------------------------------+

datetime GetDayStart()
{
   MqlDateTime dt;

   TimeToStruct(
      TimeCurrent(),
      dt
   );

   dt.hour=0;
   dt.min=0;
   dt.sec=0;

   return(
      StructToTime(dt)
   );
}

//+------------------------------------------------------------------+
//| Daily protection state                                           |
//+------------------------------------------------------------------+

void UpdateDailyState()
{
   datetime today=
      GetDayStart();

   if(g_dayStart!=today)
   {
      g_dayStart=today;

      g_dayStartEquity=
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );

      g_dailyLocked=false;

      Print(
         "[DAILY] New trading day. Start equity=",
         DoubleToString(
            g_dayStartEquity,
            2
         )
      );
   }

   if(g_dayStartEquity<=0.0)
   {
      g_dayStartEquity=
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );
   }

   double equity=
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   if(equity<=0.0)
      return;

   double dailyChangeMoney=
      equity-g_dayStartEquity;

   double dailyLossPct=0.0;

   if(
      g_dayStartEquity>0.0 &&
      dailyChangeMoney<0.0
   )
   {
      dailyLossPct=
         (-dailyChangeMoney/
          g_dayStartEquity)*
         100.0;
   }

   if(
      InpDailyLossLimitPct>0.0 &&
      dailyLossPct>=InpDailyLossLimitPct
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] Daily loss limit reached. New entries locked."
         );
      }

      g_dailyLocked=true;
   }

   if(
      InpDailyProfitTargetMoney>0.0 &&
      dailyChangeMoney>=
      InpDailyProfitTargetMoney
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] Daily profit target reached. New entries locked."
         );
      }

      g_dailyLocked=true;
   }
}

//+------------------------------------------------------------------+
//| Daily entry permission                                           |
//+------------------------------------------------------------------+

bool IsDailyTradingAllowed()
{
   UpdateDailyState();

   return(!g_dailyLocked);
}

//+------------------------------------------------------------------+
//| Combined new-entry permission                                    |
//+------------------------------------------------------------------+

bool IsNewEntryAllowed()
{
   if(!InpEnableTrading)
      return(false);

   if(!IsDailyTradingAllowed())
      return(false);

   if(!IsGrowthTradingAllowed())
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Direction agreement                                              |
//+------------------------------------------------------------------+

bool IsConfirmationDirectionValid(
   const ENUM_STRUCTURE_DIRECTION h4Direction,
   const ENUM_STRUCTURE_DIRECTION lowerDirection)
{
   return(
      h4Direction!=STRUCTURE_UNKNOWN &&
      lowerDirection==h4Direction
   );
}

//+------------------------------------------------------------------+
//| Validate M15 confirmation                                        |
//+------------------------------------------------------------------+

bool ValidateM15Confirmation(
   const M15Confirmation &c,
   const ENUM_STRUCTURE_DIRECTION expectedDirection)
{
   if(!c.valid || !c.confirmed)
      return(false);

   if(!IsConfirmationDirectionValid(
      expectedDirection,
      c.direction))
      return(false);

   if(!c.displacement)
      return(false);

   if(!c.mss && !c.bos)
      return(false);

   if(
      ICT_REQUIRE_FVG &&
      !c.fvgPresent
   )
      return(false);

   if(
      c.confirmationTime<=0 ||
      c.confirmationShift<1
   )
      return(false);

   if(c.brokenLevel<=0.0)
      return(false);

   return(true);
}
//+------------------------------------------------------------------+
//| Analyze H4 market structure                                      |
//+------------------------------------------------------------------+

bool AnalyzeH4Structure(
   const string symbol,
   ENUM_STRUCTURE_DIRECTION &direction)
{
   direction=STRUCTURE_UNKNOWN;

   if(Bars(
      symbol,
      InpPrimaryTF
   )<ICT_MIN_HISTORY_BARS)
      return(false);

   StructureSignal signal;

   if(!SS_BuildStructureSignal(
      symbol,
      InpPrimaryTF,
      InpStructureLookback,
      signal))
   {
      return(false);
   }

   if(!signal.valid)
      return(false);

   direction=
      signal.direction;

   return(
      direction!=STRUCTURE_UNKNOWN
   );
}

//+------------------------------------------------------------------+
//| Analyze H4 liquidity                                             |
//+------------------------------------------------------------------+

bool AnalyzeH4Liquidity(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION direction)
{
   if(direction==STRUCTURE_UNKNOWN)
      return(false);

   LiquidityZone liquidity;

   if(!LQ_FindLiquidity(
      symbol,
      InpPrimaryTF,
      direction,
      InpStructureLookback,
      liquidity))
   {
      return(false);
   }

   return(liquidity.valid);
}

//+------------------------------------------------------------------+
//| Analyze H4 FVG                                                   |
//+------------------------------------------------------------------+

bool AnalyzeH4FVG(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION direction)
{
   if(!ICT_REQUIRE_FVG)
      return(true);

   if(direction==STRUCTURE_UNKNOWN)
      return(false);

   FVGZone fvg;

   if(!FVG_FindLatest(
      symbol,
      InpPrimaryTF,
      direction,
      InpFVGScanLookback,
      fvg))
   {
      return(false);
   }

   return(fvg.valid);
}

//+------------------------------------------------------------------+
//| Analyze H4 order block                                           |
//+------------------------------------------------------------------+

bool AnalyzeH4OrderBlock(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION direction)
{
   if(!ICT_ENABLE_ORDER_BLOCK)
      return(true);

   if(direction==STRUCTURE_UNKNOWN)
      return(false);

   OrderBlockZone ob;

   if(!OB_FindLatest(
      symbol,
      InpPrimaryTF,
      direction,
      InpOBScanLookback,
      ob))
   {
      return(false);
   }

   return(ob.valid);
}

//+------------------------------------------------------------------+
//| Build M15 confirmation                                           |
//+------------------------------------------------------------------+

bool BuildM15Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection)
{
   ResetM15Confirmation(
      g_m15Confirmation
   );

   if(expectedDirection==
      STRUCTURE_UNKNOWN)
      return(false);

   if(Bars(
      symbol,
      InpConfirmTF
   )<ICT_MIN_HISTORY_BARS)
      return(false);

   //-----------------------------------------------------------------
   // M15 structure
   //-----------------------------------------------------------------

   StructureSignal m15Structure;

   if(!SS_BuildStructureSignal(
      symbol,
      InpConfirmTF,
      InpStructureLookback,
      m15Structure))
   {
      return(false);
   }

   if(!m15Structure.valid)
      return(false);

   if(m15Structure.direction!=
      expectedDirection)
   {
      return(false);
   }

   g_m15Confirmation.direction=
      m15Structure.direction;

   //-----------------------------------------------------------------
   // Structure confirmation
   //-----------------------------------------------------------------

   g_m15Confirmation.mss=
      m15Structure.mss;

   g_m15Confirmation.bos=
      m15Structure.bos;

   g_m15Confirmation.displacement=
      m15Structure.displacement;

   g_m15Confirmation.brokenLevel=
      m15Structure.brokenLevel;

   //-----------------------------------------------------------------
   // FVG confirmation
   //-----------------------------------------------------------------

   FVGZone m15FVG;

   bool fvgFound=
      FVG_FindLatest(
         symbol,
         InpConfirmTF,
         expectedDirection,
         InpFVGScanLookback,
         m15FVG
      );

   g_m15Confirmation.fvgPresent=
      fvgFound &&
      m15FVG.valid;

   //-----------------------------------------------------------------
   // Order block confirmation
   //-----------------------------------------------------------------

   if(ICT_ENABLE_ORDER_BLOCK)
   {
      OrderBlockZone m15OB;

      bool obFound=
         OB_FindLatest(
            symbol,
            InpConfirmTF,
            expectedDirection,
            InpOBScanLookback,
            m15OB
         );

      g_m15Confirmation.orderBlockPresent=
         obFound &&
         m15OB.valid;
   }
   else
   {
      g_m15Confirmation.orderBlockPresent=
         true;
   }

   //-----------------------------------------------------------------
   // Final M15 state
   //-----------------------------------------------------------------

   g_m15Confirmation.confirmed=
      g_m15Confirmation.displacement &&
      (
         g_m15Confirmation.mss ||
         g_m15Confirmation.bos
      );

   if(
      ICT_REQUIRE_FVG &&
      !g_m15Confirmation.fvgPresent
   )
   {
      g_m15Confirmation.confirmed=false;
   }

   if(!g_m15Confirmation.confirmed)
   {
      g_m15Confirmation.valid=false;

      g_m15Confirmation.state=
         CONFIRMATION_WAITING;

      g_m15Confirmation.reason=
         "M15 confirmation incomplete";

      return(false);
   }

   g_m15Confirmation.valid=true;

   g_m15Confirmation.state=
      CONFIRMATION_CONFIRMED;

   g_m15Confirmation.confirmationTime=
      iTime(
         symbol,
         InpConfirmTF,
         1
      );

   g_m15Confirmation.confirmationShift=1;

   g_m15Confirmation.reason=
      "M15 displacement + structure confirmation";

   return(true);
}

//+------------------------------------------------------------------+
//| Build M5 confirmation                                            |
//+------------------------------------------------------------------+

bool BuildM5Confirmation(
   const string symbol,
   const ENUM_STRUCTURE_DIRECTION expectedDirection)
{
   if(expectedDirection==
      STRUCTURE_UNKNOWN)
      return(false);

   if(Bars(
      symbol,
      InpEntryTF
   )<ICT_MIN_HISTORY_BARS)
      return(false);

   M5Confirmation confirmation;

   if(!M5_BuildConfirmation(
      symbol,
      InpEntryTF,
      expectedDirection,
      ICT_M5_CONFIRM_MAX_BARS,
      confirmation))
   {
      return(false);
   }

   if(!confirmation.valid)
      return(false);

   g_m5Confirmation=
      confirmation;

   return(true);
}

//+------------------------------------------------------------------+
//| Scan normal ICT setup                                            |
//+------------------------------------------------------------------+

bool ScanNormalSetup(
   const string symbol)
{
   ENUM_STRUCTURE_DIRECTION h4Direction;

   if(!AnalyzeH4Structure(
      symbol,
      h4Direction))
   {
      g_h4SetupActive=false;
      return(false);
   }

   //-----------------------------------------------------------------
   // Liquidity must exist in the expected context.
   //-----------------------------------------------------------------

   if(!AnalyzeH4Liquidity(
      symbol,
      h4Direction))
   {
      g_h4SetupActive=false;
      return(false);
   }

   //-----------------------------------------------------------------
   // FVG context.
   //-----------------------------------------------------------------

   if(!AnalyzeH4FVG(
      symbol,
      h4Direction))
   {
      g_h4SetupActive=false;
      return(false);
   }

   //-----------------------------------------------------------------
   // Optional order block context.
   //-----------------------------------------------------------------

   if(!AnalyzeH4OrderBlock(
      symbol,
      h4Direction))
   {
      g_h4SetupActive=false;
      return(false);
   }

   //-----------------------------------------------------------------
   // Save H4 setup.
   //-----------------------------------------------------------------

   g_h4SetupActive=true;

   g_h4SetupDirection=
      h4Direction;

   g_h4SetupTime=
      iTime(
         symbol,
         InpPrimaryTF,
         1
      );

   g_h4SetupShift=1;

   //-----------------------------------------------------------------
   // M15 confirmation.
   //-----------------------------------------------------------------

   if(!BuildM15Confirmation(
      symbol,
      h4Direction))
   {
      return(false);
   }

   //-----------------------------------------------------------------
   // M5 confirmation.
   //-----------------------------------------------------------------

   if(!BuildM5Confirmation(
      symbol,
      h4Direction))
   {
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Print normal setup                                               |
//+------------------------------------------------------------------+

void PrintNormalSetup(
   const string symbol)
{
   if(!g_h4SetupActive)
      return;

   Print(
      "[ICT SETUP] ",
      symbol,
      " | Direction=",
      EnumToString(
         g_h4SetupDirection
      ),
      " | H4Time=",
      TimeToString(
         g_h4SetupTime
      ),
      " | M15=",
      g_m15Confirmation.confirmed,
      " | M5=",
      g_m5Confirmation.valid
   );
}

//+------------------------------------------------------------------+
//| Scan one symbol for normal mode                                  |
//+------------------------------------------------------------------+

void ProcessNormalSymbol(
   const string symbol)
{
   if(!IsSymbolTradable(symbol))
      return;

   if(!IsSpreadAcceptable(symbol))
      return;

   if(!ScanNormalSetup(symbol))
      return;

   PrintNormalSetup(symbol);

   //-----------------------------------------------------------------
   // The existing normal execution engine remains the authority for
   // actual order construction/execution.
   //
   // During this development build we do not force an order here.
   // This prevents accidental duplicate execution while the modules
   // are being validated.
   //-----------------------------------------------------------------

   if(!IsNewEntryAllowed())
      return;

   Print(
      "[ICT] Valid normal setup detected on ",
      symbol,
      ". Normal execution remains protected by TradeEngine/RiskEngine."
   );
}

//+------------------------------------------------------------------+
//| Process one scalper symbol                                       |
//+------------------------------------------------------------------+

void ProcessScalperSymbol(
   const string symbol)
{
   if(!IsSymbolTradable(symbol))
      return;

   if(!IsSpreadAcceptable(symbol))
      return;

   if(!IsNewEntryAllowed())
      return;

   //-----------------------------------------------------------------
   // TradeEngine handles the complete M1 signal/execution pipeline.
   //-----------------------------------------------------------------

   TE_ProcessScalp(
      g_tradeEngine,
      Trade,
      symbol,
      InpRiskPercent,
      InpMaxTotalRiskPct,
      InpMagicNumber,
      InpScalpMinScore,
      InpScalpMaxHoldSeconds,
      InpScalpCooldownSeconds,
      InpScalpMaxPositions,
      InpScalpMaxSymbolPositions,
      InpMaxSpreadPts,
      InpEnableTrading
   );
}

//+------------------------------------------------------------------+
//| Manage existing scalper trades                                   |
//+------------------------------------------------------------------+

void ManageScalperSymbol(
   const string symbol)
{
   TE_ManageScalps(
      g_tradeEngine,
      Trade,
      symbol,
      InpScalpMaxHoldSeconds,
      InpScalpCooldownSeconds,
      InpMagicNumber
   );
}

//+------------------------------------------------------------------+
//| Process one market symbol                                        |
//+------------------------------------------------------------------+

void ProcessSymbol(
   const string symbol)
{
   if(symbol=="")
      return;

   if(!IsSymbolTradable(symbol))
      return;

   //-----------------------------------------------------------------
   // Always manage existing scalper positions first.
   //-----------------------------------------------------------------

   if(
      InpTradingMode==
         EA_MODE_SCALPER ||
      InpTradingMode==
         EA_MODE_AUTO
   )
   {
      ManageScalperSymbol(symbol);
   }

   //-----------------------------------------------------------------
   // New entries require all safety permissions.
   //-----------------------------------------------------------------

   if(!IsNewEntryAllowed())
      return;

   //-----------------------------------------------------------------
   // Scalper
   //-----------------------------------------------------------------

   if(
      InpTradingMode==
         EA_MODE_SCALPER ||
      InpTradingMode==
         EA_MODE_AUTO
   )
   {
      ProcessScalperSymbol(symbol);
   }

   //-----------------------------------------------------------------
   // Normal ICT engine
   //-----------------------------------------------------------------

   if(
      InpTradingMode==
         EA_MODE_NORMAL ||
      InpTradingMode==
         EA_MODE_AUTO
   )
   {
      ProcessNormalSymbol(symbol);
   }
}

//+------------------------------------------------------------------+
//| Scan Market Watch                                                |
//+------------------------------------------------------------------+

void ScanMarketWatch()
{
   int total=
      SymbolsTotal(
         true
      );

   for(int i=0;i<total;i++)
   {
      string symbol=
         SymbolName(
            i,
            true
         );

      if(symbol=="")
         continue;

      ProcessSymbol(symbol);
   }
}

//+------------------------------------------------------------------+
//| Scan current chart symbol                                       |
//+------------------------------------------------------------------+

void ScanCurrentSymbol()
{
   string symbol=
      _Symbol;

   if(symbol=="")
      return;

   ProcessSymbol(symbol);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+

int OnInit()
{
   //-----------------------------------------------------------------
   // Trade object configuration
   //-----------------------------------------------------------------

   Trade.SetExpertMagicNumber(
      InpMagicNumber
   );

   Trade.SetDeviationInPoints(
      InpDeviationPts
   );

   //-----------------------------------------------------------------
   // State initialization
   //-----------------------------------------------------------------

   g_lastPrimaryBar=0;
   g_lastConfirmBar=0;
   g_lastEntryBar=0;
   g_lastScalpEntryTime=0;

   g_h4SetupActive=false;
   g_h4SetupDirection=
      STRUCTURE_UNKNOWN;

   g_h4SetupTime=0;
   g_h4SetupShift=-1;

   ResetM15Confirmation(
      g_m15Confirmation
   );

   //-----------------------------------------------------------------
   // Daily state
   //-----------------------------------------------------------------

   g_dayStart=
      GetDayStart();

   g_dayStartEquity=
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   g_dailyLocked=false;

   //-----------------------------------------------------------------
   // Trade engine
   //-----------------------------------------------------------------

   TE_Init(
      g_tradeEngine,
      InpMagicNumber,
      InpTradingMode==EA_MODE_NORMAL,
      InpTradingMode==EA_MODE_SCALPER,
      InpTradingMode==EA_MODE_AUTO
   );

   //-----------------------------------------------------------------
   // Growth controller
   //-----------------------------------------------------------------

   if(!InitializeGrowthController())
   {
      Print(
         "[GROWTH] Initialization failed."
      );

      return(INIT_FAILED);
   }

   //-----------------------------------------------------------------
   // Status
   //-----------------------------------------------------------------

   Print(
      "=================================================="
   );

   Print(
      "Exness ICT EA initialized"
   );

   Print(
      "Symbol: ",
      _Symbol
   );

   Print(
      "Mode: ",
      EnumToString(
         InpTradingMode
      )
   );

   Print(
      "Trading enabled: ",
      InpEnableTrading
   );

   Print(
      "Risk: ",
      DoubleToString(
         InpRiskPercent,
         2
      ),
      "%"
   );

   Print(
      "Max total risk: ",
      DoubleToString(
         InpMaxTotalRiskPct,
         2
      ),
      "%"
   );

   Print(
      "Daily loss limit: ",
      DoubleToString(
         InpDailyLossLimitPct,
         2
      ),
      "%"
   );

   Print(
      "=================================================="
   );

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+

void OnDeinit(
   const int reason)
{
   Print(
      "[EA] Deinitialized. Reason=",
      reason
   );
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //-----------------------------------------------------------------
   // Update protection systems on every tick.
   //-----------------------------------------------------------------

   UpdateDailyState();
   UpdateGrowthController();

   //-----------------------------------------------------------------
   // Manage existing scalper positions even when new entries are
   // disabled. This allows emergency/normal exit management to run.
   //-----------------------------------------------------------------

   if(
      InpTradingMode==EA_MODE_SCALPER ||
      InpTradingMode==EA_MODE_AUTO
   )
   {
      if(InpScanMarketWatchSymbols)
         ScanMarketWatch();
      else
         ManageScalperSymbol(_Symbol);
   }

   //-----------------------------------------------------------------
   // No new trades when trading is disabled.
   //-----------------------------------------------------------------

   if(!InpEnableTrading)
      return;

   //-----------------------------------------------------------------
   // Daily safety lock.
   //-----------------------------------------------------------------

   if(!IsDailyTradingAllowed())
      return;

   //-----------------------------------------------------------------
   // Growth target reached.
   //-----------------------------------------------------------------

   if(!IsGrowthTradingAllowed())
      return;

   //-----------------------------------------------------------------
   // Market scanning.
   //-----------------------------------------------------------------

   if(InpScanMarketWatchSymbols)
      ScanMarketWatch();
   else
      ScanCurrentSymbol();
}

//+------------------------------------------------------------------+
//| End of EA                                                        |
//+------------------------------------------------------------------+
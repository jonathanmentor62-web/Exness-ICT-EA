//+------------------------------------------------------------------+
//| ExnessICT_EA.mq5                                                 |
//| Gold Multi-Strategy Confluence EA                                |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Gold-only H4/H1/M15/M5 multi-strategy confluence EA."
#property description "ICT/SMC, liquidity, FVG, order blocks, retests, trend,"
#property description "reversal, breakout, price action and volatility analysis."
#property description "Trading remains disabled during development/testing."

#include <Trade/Trade.mqh>

#include "../Include/Config.mqh"
#include "../Include/RiskEngine.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/StructureSignal.mqh"
#include "../Include/Liquidity.mqh"
#include "../Include/FVG.mqh"
#include "../Include/OrderBlock.mqh"
#include "../Include/M5Confirmation.mqh"
#include "../Include/ExecutionEngine.mqh"
#include "../Include/GrowthController.mqh"
#include "../Include/StrategySignal.mqh"
#include "../Include/StrategyEngine.mqh"
#include "../Include/ConfluenceEngine.mqh"
#include "../Include/BreakoutRetest.mqh"
#include "../Include/AdvancedBlocks.mqh"
#include "../Include/SessionEngine.mqh"
#include "../Include/VolatilityEngine.mqh"
#include "../Include/PriceActionEngine.mqh"
#include "../Include/TrendEngine.mqh"
#include "../Include/ReversalEngine.mqh"
#include "../Include/TradePlanEngine.mqh"

CTrade Trade;

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+

input ENUM_TIMEFRAMES InpPrimaryTF =
   ICT_PRIMARY_TF;

input ENUM_TIMEFRAMES InpIntermediateTF =
   PERIOD_H1;

input ENUM_TIMEFRAMES InpConfirmTF =
   ICT_CONFIRM_TF;

input ENUM_TIMEFRAMES InpEntryTF =
   ICT_ENTRY_TF;

//-------------------------------------------------------------------
// Risk
//-------------------------------------------------------------------

input double InpRiskPercent =
   ICT_RISK_PERCENT;

input double InpMaxTotalRiskPct =
   ICT_MAX_TOTAL_RISK_PERCENT;

//-------------------------------------------------------------------
// Execution
//-------------------------------------------------------------------

input ulong InpMagicNumber =
   ICT_MAGIC_NUMBER;

input int InpMaxSpreadPts =
   ICT_MAX_SPREAD_PTS;

input int InpDeviationPts =
   ICT_MAX_SLIPPAGE_PTS;

// IMPORTANT:
// Keep false while development/testing is in progress.
input bool InpEnableTrading =
   ICT_TRADING_DEFAULT_ENABLED;

//-------------------------------------------------------------------
// Daily protection
//-------------------------------------------------------------------

input double InpDailyLossLimitPct =
   ICT_MAX_DAILY_LOSS_PERCENT;

input double InpDailyProfitTargetPct =
   ICT_DAILY_PROFIT_TARGET_PERCENT;

//-------------------------------------------------------------------
// Confluence
//-------------------------------------------------------------------

input double InpMinimumConfluenceScore =
   ICT_MIN_CONFLUENCE_SCORE;

input double InpMinimumRewardRisk =
   ICT_MIN_REWARD_RR;

//+------------------------------------------------------------------+
//| Global state                                                     |
//+------------------------------------------------------------------+

datetime g_lastH4Bar  = 0;
datetime g_lastH1Bar  = 0;
datetime g_lastM15Bar = 0;
datetime g_lastM5Bar  = 0;

datetime g_lastAnalysisTime = 0;

bool g_dailyLocked = false;

datetime g_dayStart = 0;

double g_dayStartEquity = 0.0;

//+------------------------------------------------------------------+
//| Growth controller                                                |
//+------------------------------------------------------------------+

GrowthController g_growthController;

//+------------------------------------------------------------------+
//| Confluence results                                               |
//+------------------------------------------------------------------+

ConfluenceResult g_buyResult;
ConfluenceResult g_sellResult;
ConfluenceResult g_bestResult;

//+------------------------------------------------------------------+
//| Gold symbol protection                                           |
//+------------------------------------------------------------------+

bool IsGoldSymbol(
   const string symbol)
{
   return RE_IsGoldSymbol(symbol);
}

//+------------------------------------------------------------------+
//| Symbol validation                                                |
//+------------------------------------------------------------------+

bool ValidateGoldSymbol()
{
   string symbol =
      _Symbol;

   if(!IsGoldSymbol(symbol))
   {
      Print(
         "[GOLD ONLY] EA rejected symbol: ",
         symbol
      );

      return false;
   }

   if(!SymbolSelect(
      symbol,
      true))
   {
      Print(
         "[GOLD ONLY] Could not select symbol: ",
         symbol
      );

      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| History validation                                               |
//+------------------------------------------------------------------+

bool HasRequiredHistory()
{
   string symbol =
      _Symbol;

   if(Bars(
      symbol,
      InpPrimaryTF) <
      ICT_MIN_HISTORY_BARS)
   {
      return false;
   }

   if(Bars(
      symbol,
      InpIntermediateTF) <
      ICT_MIN_HISTORY_BARS)
   {
      return false;
   }

   if(Bars(
      symbol,
      InpConfirmTF) <
      ICT_MIN_HISTORY_BARS)
   {
      return false;
   }

   if(Bars(
      symbol,
      InpEntryTF) <
      ICT_MIN_HISTORY_BARS)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Current day start                                                |
//+------------------------------------------------------------------+

datetime GetDayStart()
{
   MqlDateTime dt;

   TimeToStruct(
      TimeCurrent(),
      dt
   );

   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;

   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Update daily protection                                          |
//+------------------------------------------------------------------+

void UpdateDailyProtection()
{
   datetime today =
      GetDayStart();

   if(g_dayStart != today)
   {
      g_dayStart =
         today;

      g_dayStartEquity =
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );

      g_dailyLocked =
         false;

      Print(
         "[DAILY] New trading day. "
         "Starting equity=",
         DoubleToString(
            g_dayStartEquity,
            2
         )
      );
   }

   if(g_dayStartEquity <= 0.0)
   {
      g_dayStartEquity =
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );
   }

   double equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   if(equity <= 0.0 ||
      g_dayStartEquity <= 0.0)
   {
      return;
   }

   double change =
      equity -
      g_dayStartEquity;

   double lossPct = 0.0;

   if(change < 0.0)
   {
      lossPct =
         (-change /
          g_dayStartEquity) *
         100.0;
   }

   if(
      InpDailyLossLimitPct > 0.0 &&
      lossPct >=
      InpDailyLossLimitPct
   )
   {
      if(!g_dailyLocked)
      {
         Print(
            "[DAILY SAFETY] "
            "Daily loss limit reached."
         );
      }

      g_dailyLocked =
         true;
   }

   if(
      InpDailyProfitTargetPct > 0.0 &&
      change > 0.0
   )
   {
      double profitPct =
         (change /
          g_dayStartEquity) *
         100.0;

      if(
         profitPct >=
         InpDailyProfitTargetPct
      )
      {
         if(!g_dailyLocked)
         {
            Print(
               "[DAILY SAFETY] "
               "Daily profit target reached."
            );
         }

         g_dailyLocked =
            true;
      }
   }
}

//+------------------------------------------------------------------+
//| Daily permission                                                |
//+------------------------------------------------------------------+

bool IsDailyTradingAllowed()
{
   UpdateDailyProtection();

   return !g_dailyLocked;
}

//+------------------------------------------------------------------+
//| Growth controller initialization                                 |
//+------------------------------------------------------------------+

bool InitializeGrowth()
{
   GC_Reset(
      g_growthController
   );

   double equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   if(equity <= 0.0)
   {
      Print(
         "[GROWTH] Invalid starting equity."
      );

      return false;
   }

   /*
      GrowthController is advisory only.
      It must never override RiskEngine.
   */

   if(GC_LoadState(
      g_growthController,
      InpMagicNumber))
   {
      GC_Update(
         g_growthController,
         equity
      );

      Print(
         "[GROWTH] Existing growth cycle restored."
      );

      GC_PrintStatus(
         g_growthController
      );

      return true;
   }

   if(!GC_InitializeNew(
      g_growthController,
      InpMagicNumber,
      equity))
   {
      Print(
         "[GROWTH] Failed to initialize."
      );

      return false;
   }

   GC_Update(
      g_growthController,
      equity
   );

   Print(
      "[GROWTH] New growth cycle initialized."
   );

   GC_PrintStatus(
      g_growthController
   );

   return true;
}

//+------------------------------------------------------------------+
//| Update growth controller                                         |
//+------------------------------------------------------------------+

void UpdateGrowth()
{
   if(!g_growthController.initialized)
      return;

   double equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   if(equity <= 0.0)
      return;

   GC_Update(
      g_growthController,
      equity
   );
}

//+------------------------------------------------------------------+
//| Growth permission                                                |
//+------------------------------------------------------------------+

bool IsGrowthAllowed()
{
   UpdateGrowth();

   if(!g_growthController.initialized)
      return false;

   /*
      Reaching the growth objective does not
      force a trade. It only prevents new
      entries when the objective is reached.
   */

   if(GC_TargetReached(
      g_growthController))
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| New-entry permission                                             |
//+------------------------------------------------------------------+

bool IsNewEntryAllowed()
{
   if(!InpEnableTrading)
      return false;

   if(ICT_DEVELOPMENT_MODE)
      return false;

   if(!IsDailyTradingAllowed())
      return false;

   if(!IsGrowthAllowed())
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| New H4 bar                                                       |
//+------------------------------------------------------------------+

bool IsNewH4Bar()
{
   datetime currentBar =
      iTime(
         _Symbol,
         InpPrimaryTF,
         0
      );

   if(currentBar <= 0)
      return false;

   if(currentBar ==
      g_lastH4Bar)
   {
      return false;
   }

   g_lastH4Bar =
      currentBar;

   return true;
}

//+------------------------------------------------------------------+
//| New H1 bar                                                       |
//+------------------------------------------------------------------+

bool IsNewH1Bar()
{
   datetime currentBar =
      iTime(
         _Symbol,
         InpIntermediateTF,
         0
      );

   if(currentBar <= 0)
      return false;

   if(currentBar ==
      g_lastH1Bar)
   {
      return false;
   }

   g_lastH1Bar =
      currentBar;

   return true;
}

//+------------------------------------------------------------------+
//| New M15 bar                                                      |
//+------------------------------------------------------------------+

bool IsNewM15Bar()
{
   datetime currentBar =
      iTime(
         _Symbol,
         InpConfirmTF,
         0
      );

   if(currentBar <= 0)
      return false;

   if(currentBar ==
      g_lastM15Bar)
   {
      return false;
   }

   g_lastM15Bar =
      currentBar;

   return true;
}

//+------------------------------------------------------------------+
//| New M5 bar                                                       |
//+------------------------------------------------------------------+

bool IsNewM5Bar()
{
   datetime currentBar =
      iTime(
         _Symbol,
         InpEntryTF,
         0
      );

   if(currentBar <= 0)
      return false;

   if(currentBar ==
      g_lastM5Bar)
   {
      return false;
   }

   g_lastM5Bar =
      currentBar;

   return true;
}
//+------------------------------------------------------------------+
//| Spread validation                                                |
//+------------------------------------------------------------------+

bool IsSpreadAcceptable()
{
   MqlTick tick;

   if(!SymbolInfoTick(
      _Symbol,
      tick))
   {
      return false;
   }

   double point =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );

   if(point <= 0.0)
      return false;

   double spread =
      (tick.ask - tick.bid) /
      point;

   if(spread < 0.0)
      return false;

   return spread <=
          InpMaxSpreadPts;
}

//+------------------------------------------------------------------+
//| Broker trading mode validation                                   |
//+------------------------------------------------------------------+

bool IsBrokerTradingAllowed()
{
   long mode = 0;

   if(!SymbolInfoInteger(
      _Symbol,
      SYMBOL_TRADE_MODE,
      mode))
   {
      return false;
   }

   return mode !=
          SYMBOL_TRADE_MODE_DISABLED;
}

//+------------------------------------------------------------------+
//| Position count                                                   |
//+------------------------------------------------------------------+

int CountOurPositions()
{
   int count = 0;

   for(
      int i = PositionsTotal() - 1;
      i >= 0;
      i--
   )
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(
         ticket))
      {
         continue;
      }

      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         ) !=
         InpMagicNumber
      )
      {
         continue;
      }

      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Gold position count                                              |
//+------------------------------------------------------------------+

int CountGoldPositions()
{
   int count = 0;

   for(
      int i = PositionsTotal() - 1;
      i >= 0;
      i--
   )
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(
         ticket))
      {
         continue;
      }

      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         ) !=
         InpMagicNumber
      )
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(IsGoldSymbol(symbol))
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Existing gold position                                           |
//+------------------------------------------------------------------+

bool HasGoldPosition()
{
   return CountGoldPositions() > 0;
}

//+------------------------------------------------------------------+
//| Position direction                                               |
//+------------------------------------------------------------------+

ENUM_POSITION_TYPE GetGoldPositionType()
{
   for(
      int i = PositionsTotal() - 1;
      i >= 0;
      i--
   )
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(
         ticket))
      {
         continue;
      }

      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         ) !=
         InpMagicNumber
      )
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(!IsGoldSymbol(symbol))
         continue;

      return(
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         )
      );
   }

   return POSITION_TYPE_BUY;
}

//+------------------------------------------------------------------+
//| Opposite gold position check                                     |
//+------------------------------------------------------------------+

bool HasOppositeGoldPosition(
   const ENUM_ORDER_TYPE orderType)
{
   ENUM_POSITION_TYPE wanted;

   if(orderType ==
      ORDER_TYPE_BUY)
   {
      wanted =
         POSITION_TYPE_SELL;
   }
   else if(orderType ==
           ORDER_TYPE_SELL)
   {
      wanted =
         POSITION_TYPE_BUY;
   }
   else
   {
      return true;
   }

   for(
      int i = PositionsTotal() - 1;
      i >= 0;
      i--
   )
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(
         ticket))
      {
         continue;
      }

      if(
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         ) !=
         InpMagicNumber
      )
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(!IsGoldSymbol(symbol))
         continue;

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         );

      if(type == wanted)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Current gold entry price                                         |
//+------------------------------------------------------------------+

double GetEntryPrice(
   const ENUM_STRATEGY_DIRECTION direction)
{
   MqlTick tick;

   if(!SymbolInfoTick(
      _Symbol,
      tick))
   {
      return 0.0;
   }

   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      return tick.ask;
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      return tick.bid;
   }

   return 0.0;
}

//+------------------------------------------------------------------+
//| Validate candidate price levels                                  |
//+------------------------------------------------------------------+

bool ValidateTradeLevels(
   const ConfluenceResult &result)
{
   if(!result.actionable)
      return false;

   if(result.entry <= 0.0 ||
      result.stopLoss <= 0.0 ||
      result.takeProfit <= 0.0)
   {
      return false;
   }

   if(result.direction ==
      STRATEGY_DIRECTION_BUY)
   {
      if(result.stopLoss >=
         result.entry)
      {
         return false;
      }

      if(result.takeProfit <=
         result.entry)
      {
         return false;
      }
   }

   if(result.direction ==
      STRATEGY_DIRECTION_SELL)
   {
      if(result.stopLoss <=
         result.entry)
      {
         return false;
      }

      if(result.takeProfit >=
         result.entry)
      {
         return false;
      }
   }

   double risk =
      MathAbs(
         result.entry -
         result.stopLoss
      );

   double reward =
      MathAbs(
         result.takeProfit -
         result.entry
      );

   if(risk <= 0.0 ||
      reward <= 0.0)
   {
      return false;
   }

   double rr =
      reward / risk;

   if(rr <
      InpMinimumRewardRisk)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Synchronize entry to current market                              |
//+------------------------------------------------------------------+

bool SynchronizeEntryPrice(
   ConfluenceResult &result)
{
   double current =
      GetEntryPrice(
         result.direction
      );

   if(current <= 0.0)
      return false;

   result.entry =
      current;

   double risk =
      MathAbs(
         result.entry -
         result.stopLoss
      );

   if(risk <= 0.0)
      return false;

   /*
      Keep the structural stop.
      Recalculate TP from the same minimum
      reward/risk requirement if necessary.
   */

   if(result.direction ==
      STRATEGY_DIRECTION_BUY)
   {
      if(result.stopLoss >=
         result.entry)
      {
         return false;
      }

      double minimumTP =
         result.entry +
         risk *
         InpMinimumRewardRisk;

      if(result.takeProfit <
         minimumTP)
      {
         result.takeProfit =
            minimumTP;
      }
   }
   else if(result.direction ==
           STRATEGY_DIRECTION_SELL)
   {
      if(result.stopLoss <=
         result.entry)
      {
         return false;
      }

      double minimumTP =
         result.entry -
         risk *
         InpMinimumRewardRisk;

      if(result.takeProfit >
         minimumTP)
      {
         result.takeProfit =
            minimumTP;
      }
   }
   else
   {
      return false;
   }

   result.rewardRisk =
      MathAbs(
         result.takeProfit -
         result.entry
      ) /
      risk;

   return true;
}

//+------------------------------------------------------------------+
//| Prepare risk-engine candidate                                    |
//+------------------------------------------------------------------+

bool PrepareRiskCandidate(
   ConfluenceResult &result,
   ExecutionResult &execution)
{
   ResetExecutionResult(
      execution
   );

   if(!result.actionable)
   {
      execution.reason =
         "Confluence result is not actionable.";

      return false;
   }

   if(!ValidateTradeLevels(
      result))
   {
      execution.reason =
         "Trade levels failed validation.";

      return false;
   }

   ENUM_ORDER_TYPE orderType;

   if(result.direction ==
      STRATEGY_DIRECTION_BUY)
   {
      orderType =
         ORDER_TYPE_BUY;
   }
   else if(result.direction ==
           STRATEGY_DIRECTION_SELL)
   {
      orderType =
         ORDER_TYPE_SELL;
   }
   else
   {
      execution.reason =
         "No valid trade direction.";

      return false;
   }

   /*
      ExecutionEngine performs the final broker,
      risk, volume, duplicate-position and
      development-mode protection.
   */

   bool valid =
      EX_ValidateCandidate(
         _Symbol,
         orderType,
         result.entry,
         result.stopLoss,
         result.takeProfit,
         InpRiskPercent,
         InpMaxTotalRiskPct,
         InpMagicNumber,
         ICT_MAX_TOTAL_POSITIONS,
         ICT_MAX_SYMBOL_POSITIONS,
         InpMaxSpreadPts,
         InpEnableTrading,
         execution
      );

   if(!valid)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Print risk candidate                                             |
//+------------------------------------------------------------------+

void PrintRiskCandidate(
   const ConfluenceResult &result,
   const ExecutionResult &execution)
{
   string direction =
      "NONE";

   if(result.direction ==
      STRATEGY_DIRECTION_BUY)
   {
      direction =
         "BUY";
   }
   else if(result.direction ==
           STRATEGY_DIRECTION_SELL)
   {
      direction =
         "SELL";
   }

   Print(
      "[RISK CANDIDATE] ",
      direction,
      " Entry=",
      DoubleToString(
         result.entry,
         _Digits),
      " SL=",
      DoubleToString(
         result.stopLoss,
         _Digits),
      " TP=",
      DoubleToString(
         result.takeProfit,
         _Digits),
      " RR=",
      DoubleToString(
         result.rewardRisk,
         2),
      " Score=",
      DoubleToString(
         result.score,
         1),
      " Volume=",
      DoubleToString(
         execution.volume,
         2),
      " Risk=",
      DoubleToString(
         execution.riskMoney,
         2)
   );

   Print(
      "[RISK CANDIDATE] ",
      execution.reason
   );
}

//+------------------------------------------------------------------+
//| Analyze gold                                                     |
//+------------------------------------------------------------------+

bool AnalyzeGold()
{
   CE_ResetResult(
      g_buyResult
   );

   CE_ResetResult(
      g_sellResult
   );

   CE_ResetResult(
      g_bestResult
   );

   if(!ValidateGoldSymbol())
      return false;

   if(!HasRequiredHistory())
   {
      Print(
         "[ANALYSIS] Waiting for required history."
      );

      return false;
   }

   if(!IsSpreadAcceptable())
   {
      Print(
         "[ANALYSIS] Spread filter rejected current quote."
      );

      return false;
   }

   if(!CE_AnalyzeGold(
      _Symbol,
      g_buyResult,
      g_sellResult,
      g_bestResult))
   {
      return false;
   }

   g_lastAnalysisTime =
      TimeCurrent();

   return true;
}
//+------------------------------------------------------------------+
//| Print complete confluence analysis                               |
//+------------------------------------------------------------------+

void PrintConfluenceAnalysis()
{
   Print(
      "=================================================="
   );

   Print(
      "[CONFLUENCE] GOLD ANALYSIS"
   );

   Print(
      "Symbol: ",
      _Symbol
   );

   Print(
      "Minimum score: ",
      DoubleToString(
         InpMinimumConfluenceScore,
         1
      )
   );

   Print(
      "Minimum RR: ",
      DoubleToString(
         InpMinimumRewardRisk,
         2
      )
   );

   CE_PrintResult(
      "BUY CANDIDATE",
      g_buyResult
   );

   CE_PrintResult(
      "SELL CANDIDATE",
      g_sellResult
   );

   CE_PrintResult(
      "BEST CANDIDATE",
      g_bestResult
   );

   Print(
      "=================================================="
   );
}

//+------------------------------------------------------------------+
//| Validate final candidate                                        |
//+------------------------------------------------------------------+

bool ValidateFinalCandidate()
{
   if(!g_bestResult.valid)
   {
      Print(
         "[FINAL] No valid confluence result."
      );

      return false;
   }

   if(!g_bestResult.actionable)
   {
      Print(
         "[FINAL] Candidate is not actionable."
      );

      return false;
   }

   if(g_bestResult.score <
      InpMinimumConfluenceScore)
   {
      Print(
         "[FINAL] Confluence score too low: ",
         DoubleToString(
            g_bestResult.score,
            1
         )
      );

      return false;
   }

   if(g_bestResult.rewardRisk <
      InpMinimumRewardRisk)
   {
      Print(
         "[FINAL] Reward/risk too low: ",
         DoubleToString(
            g_bestResult.rewardRisk,
            2
         )
      );

      return false;
   }

   if(!ValidateTradeLevels(
      g_bestResult))
   {
      Print(
         "[FINAL] Trade levels invalid."
      );

      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Risk validation                                                  |
//+------------------------------------------------------------------+

bool ValidateRiskCandidate()
{
   ExecutionResult execution;

   if(!PrepareRiskCandidate(
      g_bestResult,
      execution))
   {
      Print(
         "[RISK] Candidate rejected: ",
         execution.reason
      );

      return false;
   }

   PrintRiskCandidate(
      g_bestResult,
      execution
   );

   return true;
}

//+------------------------------------------------------------------+
//| Diagnostic analysis cycle                                        |
//+------------------------------------------------------------------+

void RunAnalysisCycle()
{
   if(!ValidateGoldSymbol())
      return;

   if(!HasRequiredHistory())
   {
      Print(
         "[ANALYSIS] Insufficient history."
      );

      return;
   }

   if(!AnalyzeGold())
      return;

   PrintConfluenceAnalysis();

   if(!ValidateFinalCandidate())
   {
      Print(
         "[ANALYSIS] No final trade candidate."
      );

      return;
   }

   /*
      Risk validation is performed even while
      execution is disabled. This allows the EA
      to prove that its candidate would satisfy
      broker/risk constraints without placing
      an order.
   */

   ValidateRiskCandidate();
}

//+------------------------------------------------------------------+
//| Execution gate                                                   |
//+------------------------------------------------------------------+

bool ExecutionGate()
{
   if(!InpEnableTrading)
   {
      Print(
         "[EXECUTION] Trading disabled by input."
      );

      return false;
   }

   if(ICT_DEVELOPMENT_MODE)
   {
      Print(
         "[EXECUTION] Development mode blocks trading."
      );

      return false;
   }

   if(!IsNewEntryAllowed())
   {
      Print(
         "[EXECUTION] Entry permission denied."
      );

      return false;
   }

   if(!IsBrokerTradingAllowed())
   {
      Print(
         "[EXECUTION] Broker trading mode disabled."
      );

      return false;
   }

   if(!IsSpreadAcceptable())
   {
      Print(
         "[EXECUTION] Spread protection rejected entry."
      );

      return false;
   }

   if(CountOurPositions() >=
      ICT_MAX_TOTAL_POSITIONS)
   {
      Print(
         "[EXECUTION] Maximum EA positions reached."
      );

      return false;
   }

   if(CountGoldPositions() >=
      ICT_MAX_SYMBOL_POSITIONS)
   {
      Print(
         "[EXECUTION] Maximum gold positions reached."
      );

      return false;
   }

   if(ICT_BLOCK_DUPLICATE_SYMBOL &&
      HasGoldPosition())
   {
      Print(
         "[EXECUTION] Existing gold position blocks duplicate."
      );

      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Convert strategy direction                                      |
//+------------------------------------------------------------------+

ENUM_ORDER_TYPE DirectionToOrderType(
   const ENUM_STRATEGY_DIRECTION direction)
{
   if(direction ==
      STRATEGY_DIRECTION_BUY)
   {
      return ORDER_TYPE_BUY;
   }

   if(direction ==
      STRATEGY_DIRECTION_SELL)
   {
      return ORDER_TYPE_SELL;
   }

   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| Execute final trade candidate                                    |
//+------------------------------------------------------------------+

bool ExecuteCandidate()
{
   if(!ExecutionGate())
      return false;

   if(!ValidateFinalCandidate())
      return false;

   ENUM_ORDER_TYPE orderType =
      DirectionToOrderType(
         g_bestResult.direction
      );

   if(orderType ==
      WRONG_VALUE)
   {
      Print(
         "[EXECUTION] Invalid direction."
      );

      return false;
   }

   if(
      ICT_BLOCK_OPPOSITE_SYMBOL &&
      HasOppositeGoldPosition(
         orderType
      )
   )
   {
      Print(
         "[EXECUTION] Opposite gold position exists."
      );

      return false;
   }

   ExecutionResult execution;

   if(!PrepareRiskCandidate(
      g_bestResult,
      execution))
   {
      Print(
         "[EXECUTION] Risk validation failed: ",
         execution.reason
      );

      return false;
   }

   if(execution.volume <= 0.0)
   {
      Print(
         "[EXECUTION] Broker-valid volume is zero."
      );

      return false;
   }

   /*
      Final execution is deliberately isolated here.
      During development, this function cannot pass
      the development-mode gate.
   */

   Trade.SetExpertMagicNumber(
      InpMagicNumber
   );

   Trade.SetDeviationInPoints(
      InpDeviationPts
   );

   bool sent = false;

   if(orderType ==
      ORDER_TYPE_BUY)
   {
      sent =
         Trade.Buy(
            execution.volume,
            _Symbol,
            g_bestResult.entry,
            g_bestResult.stopLoss,
            g_bestResult.takeProfit,
            "Gold Confluence BUY"
         );
   }
   else if(orderType ==
           ORDER_TYPE_SELL)
   {
      sent =
         Trade.Sell(
            execution.volume,
            _Symbol,
            g_bestResult.entry,
            g_bestResult.stopLoss,
            g_bestResult.takeProfit,
            "Gold Confluence SELL"
         );
   }

   if(!sent)
   {
      Print(
         "[EXECUTION] Order failed. Retcode=",
         Trade.ResultRetcode(),
         " Description=",
         Trade.ResultRetcodeDescription()
      );

      return false;
   }

   execution.executed =
      true;

   execution.ticket =
      Trade.ResultOrder();

   Print(
      "[EXECUTION] GOLD TRADE OPENED. Ticket=",
      execution.ticket,
      " Volume=",
      DoubleToString(
         execution.volume,
         2
      )
   );

   return true;
}

//+------------------------------------------------------------------+
//| Process current market                                           |
//+------------------------------------------------------------------+

void ProcessMarket()
{
   /*
      Primary analysis is driven by H4.
      Lower timeframes confirm the setup.
   */

   if(!IsNewH4Bar())
      return;

   Print(
      "[ENGINE] New H4 bar detected."
   );

   RunAnalysisCycle();

   /*
      No order can be sent while:
      ICT_DEVELOPMENT_MODE == true
      or
      InpEnableTrading == false.
   */

   if(!g_bestResult.actionable)
      return;

   ExecuteCandidate();
}

//+------------------------------------------------------------------+
//| Informational heartbeat                                          |
//+------------------------------------------------------------------+

void PrintHeartbeat()
{
   static datetime lastHeartbeat = 0;

   datetime now =
      TimeCurrent();

   if(
      lastHeartbeat > 0 &&
      now - lastHeartbeat < 3600
   )
   {
      return;
   }

   lastHeartbeat =
      now;

   Print(
      "[HEARTBEAT] Gold EA active. "
      "Symbol=",
      _Symbol,
      " Trading=",
      InpEnableTrading
      ? "ON"
      : "OFF",
      " DevelopmentMode=",
      ICT_DEVELOPMENT_MODE
      ? "ON"
      : "OFF"
   );
}
//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+

int OnInit()
{
   Print(
      "=================================================="
   );

   Print(
      "Exness Gold Multi-Strategy EA v1.00"
   );

   Print(
      "=================================================="
   );

   //-----------------------------------------------------------------
   // Gold-only protection
   //-----------------------------------------------------------------

   if(!ValidateGoldSymbol())
   {
      Print(
         "[INIT] EA must be attached to XAUUSD."
      );

      return INIT_FAILED;
   }

   //-----------------------------------------------------------------
   // Trading symbol
   //-----------------------------------------------------------------

   Print(
      "[INIT] Gold symbol: ",
      _Symbol
   );

   //-----------------------------------------------------------------
   // Timeframes
   //-----------------------------------------------------------------

   Print(
      "[INIT] Primary TF: ",
      EnumToString(
         InpPrimaryTF
      )
   );

   Print(
      "[INIT] Intermediate TF: ",
      EnumToString(
         InpIntermediateTF
      )
   );

   Print(
      "[INIT] Confirmation TF: ",
      EnumToString(
         InpConfirmTF
      )
   );

   Print(
      "[INIT] Entry TF: ",
      EnumToString(
         InpEntryTF
      )
   );

   //-----------------------------------------------------------------
   // Risk configuration
   //-----------------------------------------------------------------

   Print(
      "[INIT] Risk percent: ",
      DoubleToString(
         InpRiskPercent,
         2
      )
   );

   Print(
      "[INIT] Maximum total risk: ",
      DoubleToString(
         InpMaxTotalRiskPct,
         2
      )
   );

   Print(
      "[INIT] Minimum confluence score: ",
      DoubleToString(
         InpMinimumConfluenceScore,
         1
      )
   );

   Print(
      "[INIT] Minimum reward/risk: ",
      DoubleToString(
         InpMinimumRewardRisk,
         2
      )
   );

   //-----------------------------------------------------------------
   // Position protection
   //-----------------------------------------------------------------

   Print(
      "[INIT] Maximum total positions: ",
      ICT_MAX_TOTAL_POSITIONS
   );

   Print(
      "[INIT] Maximum gold positions: ",
      ICT_MAX_SYMBOL_POSITIONS
   );

   //-----------------------------------------------------------------
   // Development protection
   //-----------------------------------------------------------------

   Print(
      "[INIT] Trading input: ",
      InpEnableTrading
      ? "ENABLED"
      : "DISABLED"
   );

   Print(
      "[INIT] Development mode: ",
      ICT_DEVELOPMENT_MODE
      ? "ACTIVE"
      : "INACTIVE"
   );

   if(ICT_DEVELOPMENT_MODE)
   {
      Print(
         "[INIT] SAFETY: execution is blocked."
      );
   }

   //-----------------------------------------------------------------
   // Growth controller
   //-----------------------------------------------------------------

   if(!InitializeGrowth())
   {
      Print(
         "[INIT] Growth controller initialization failed."
      );

      /*
         Growth control is advisory, but failure to
         initialize means the EA should remain safe.
      */

      if(InpEnableTrading)
      {
         Print(
            "[INIT] Trading requested but growth controller "
            "is unavailable. Initialization stopped."
         );

         return INIT_FAILED;
      }
   }

   //-----------------------------------------------------------------
   // Daily protection
   //-----------------------------------------------------------------

   g_dayStart =
      GetDayStart();

   g_dayStartEquity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   g_dailyLocked =
      false;

   //-----------------------------------------------------------------
   // Reset analysis state
   //-----------------------------------------------------------------

   CE_ResetResult(
      g_buyResult
   );

   CE_ResetResult(
      g_sellResult
   );

   CE_ResetResult(
      g_bestResult
   );

   //-----------------------------------------------------------------
   // Configure CTrade
   //-----------------------------------------------------------------

   Trade.SetExpertMagicNumber(
      InpMagicNumber
   );

   Trade.SetDeviationInPoints(
      InpDeviationPts
   );

   //-----------------------------------------------------------------
   // Initial history check
   //-----------------------------------------------------------------

   if(!HasRequiredHistory())
   {
      Print(
         "[INIT] Warning: required history is not "
         "fully available yet."
      );

      Print(
         "[INIT] EA will wait for history."
      );
   }

   //-----------------------------------------------------------------
   // Initial status
   //-----------------------------------------------------------------

   Print(
      "[INIT] Gold-only protection: ACTIVE"
   );

   Print(
      "[INIT] M1 scalper: REMOVED"
   );

   Print(
      "[INIT] Multi-strategy confluence: ACTIVE"
   );

   Print(
      "[INIT] H4/H1/M15/M5 framework: ACTIVE"
   );

   Print(
      "[INIT] Risk engine: ACTIVE"
   );

   Print(
      "[INIT] Growth controller: ADVISORY"
   );

   Print(
      "[INIT] Initialization complete."
   );

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+

void OnDeinit(
   const int reason)
{
   Print(
      "=================================================="
   );

   Print(
      "[DEINIT] Gold Multi-Strategy EA stopped."
   );

   Print(
      "[DEINIT] Reason=",
      reason
   );

   Print(
      "=================================================="
   );
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+

void OnTick()
{
   //-----------------------------------------------------------------
   // Basic symbol protection
   //-----------------------------------------------------------------

   if(!IsGoldSymbol(
      _Symbol))
   {
      return;
   }

   //-----------------------------------------------------------------
   // Update account protections
   //-----------------------------------------------------------------

   UpdateDailyProtection();

   UpdateGrowth();

   //-----------------------------------------------------------------
   // Heartbeat
   //-----------------------------------------------------------------

   PrintHeartbeat();

   //-----------------------------------------------------------------
   // Market processing
   //-----------------------------------------------------------------

   ProcessMarket();
}

//+------------------------------------------------------------------+
//| End of Expert Advisor                                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Final diagnostics and status functions                           |
//+------------------------------------------------------------------+

void PrintAccountStatus()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   double free    = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   Print("--------------------------------------------------");
   Print("[ACCOUNT]");
   Print("Balance: ", DoubleToString(balance,2));
   Print("Equity: ", DoubleToString(equity,2));
   Print("Margin: ", DoubleToString(margin,2));
   Print("Free margin: ", DoubleToString(free,2));
   Print("Our positions: ", CountOurPositions());
   Print("Gold positions: ", CountGoldPositions());
   Print("--------------------------------------------------");
}

void PrintSystemStatus()
{
   Print("==================================================");
   Print("[SYSTEM STATUS]");
   Print("Gold-only: ACTIVE");
   Print("M1 scalping: REMOVED");
   Print("H4 primary analysis: ACTIVE");
   Print("H1 intermediate structure: ACTIVE");
   Print("M15 confirmation: ACTIVE");
   Print("M5 entry confirmation: ACTIVE");
   Print("Multi-strategy engine: ACTIVE");
   Print("Confluence engine: ACTIVE");
   Print("Risk engine: ACTIVE");
   Print("Growth controller: ADVISORY");
   Print("Development mode: ",
         ICT_DEVELOPMENT_MODE ? "ON" : "OFF");
   Print("Trading: ",
         InpEnableTrading ? "ON" : "OFF");
   Print("Last analysis: ",
         g_lastAnalysisTime > 0
         ? TimeToString(g_lastAnalysisTime)
         : "NONE");
   Print("==================================================");
}

//+------------------------------------------------------------------+
//| Manual diagnostic trigger                                        |
//+------------------------------------------------------------------+

void RunDiagnostics()
{
   if(!ValidateGoldSymbol())
      return;

   PrintSystemStatus();
   PrintAccountStatus();

   if(!HasRequiredHistory())
   {
      Print(
         "[DIAGNOSTIC] Required history is not ready."
      );

      return;
   }

   if(!IsSpreadAcceptable())
   {
      Print(
         "[DIAGNOSTIC] Current spread is above the "
         "configured limit."
      );
   }
   else
   {
      Print(
         "[DIAGNOSTIC] Spread: ACCEPTABLE"
      );
   }

   //-----------------------------------------------------------------
   // Run the complete analytical stack
   //-----------------------------------------------------------------

   if(!AnalyzeGold())
   {
      Print(
         "[DIAGNOSTIC] Gold analysis did not produce "
         "a usable result."
      );

      return;
   }

   PrintConfluenceAnalysis();

   //-----------------------------------------------------------------
   // Final candidate
   //-----------------------------------------------------------------

   if(!g_bestResult.valid)
   {
      Print(
         "[DIAGNOSTIC] No valid candidate."
      );

      return;
   }

   Print(
      "[DIAGNOSTIC] Best candidate score=",
      DoubleToString(
         g_bestResult.score,
         1
      )
   );

   Print(
      "[DIAGNOSTIC] Best candidate RR=",
      DoubleToString(
         g_bestResult.rewardRisk,
         2
      )
   );

   //-----------------------------------------------------------------
   // Risk-only diagnostic
   //-----------------------------------------------------------------

   ExecutionResult execution;

   if(PrepareRiskCandidate(
      g_bestResult,
      execution))
   {
      Print(
         "[DIAGNOSTIC] Risk candidate accepted."
      );

      PrintRiskCandidate(
         g_bestResult,
         execution
      );
   }
   else
   {
      Print(
         "[DIAGNOSTIC] Risk candidate rejected: ",
         execution.reason
      );
   }
}

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+

void OnTimer()
{
   /*
      Timer is intentionally lightweight.

      Trading decisions remain driven by market ticks
      and the H4 analysis cycle.
   */

   UpdateDailyProtection();
   UpdateGrowth();
}

//+------------------------------------------------------------------+
//| Trade transaction event                                          |
//+------------------------------------------------------------------+

void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result)
{
   /*
      Development-safe transaction logger.

      No additional order is generated here.
      This prevents accidental trade loops.
   */

   if(trans.symbol != _Symbol)
      return;

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD &&
      trans.type != TRADE_TRANSACTION_ORDER_ADD &&
      trans.type != TRADE_TRANSACTION_ORDER_DELETE)
   {
      return;
   }

   Print(
      "[TRADE EVENT] Symbol=",
      trans.symbol,
      " Type=",
      IntegerToString((int)trans.type),
      " Order=",
      IntegerToString((long)trans.order),
      " Deal=",
      IntegerToString((long)trans.deal)
   );
}

//+------------------------------------------------------------------+
//| Final EA safety check                                            |
//+------------------------------------------------------------------+

bool FinalSafetyCheck()
{
   if(!IsGoldSymbol(_Symbol))
   {
      Print(
         "[SAFETY] Non-gold symbol rejected."
      );

      return false;
   }

   if(ICT_DEVELOPMENT_MODE)
   {
      return true;
   }

   if(!InpEnableTrading)
   {
      return true;
   }

   if(!IsDailyTradingAllowed())
   {
      Print(
         "[SAFETY] Daily protection is locked."
      );

      return false;
   }

   if(!IsGrowthAllowed())
   {
      Print(
         "[SAFETY] Growth controller has stopped "
         "new entries."
      );

      return false;
   }

   if(!IsBrokerTradingAllowed())
   {
      Print(
         "[SAFETY] Broker trading is unavailable."
      );

      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| End of file                                                      |
//+------------------------------------------------------------------+
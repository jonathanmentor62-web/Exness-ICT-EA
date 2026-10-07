//+------------------------------------------------------------------+
//| Config.mqh - Gold Multi-Strategy EA configuration                |
//+------------------------------------------------------------------+
#ifndef __EXNESS_GOLD_CONFIG_MQH__
#define __EXNESS_GOLD_CONFIG_MQH__

//==================================================================
// MARKET
//==================================================================

// Gold only.
// The EA will validate the actual broker symbol separately.
#define ICT_GOLD_SYMBOL_PREFIX       "XAUUSD"

// Main analysis timeframe
#define ICT_PRIMARY_TF               PERIOD_H4

// Intermediate confirmation
#define ICT_CONFIRM_TF               PERIOD_M15

// Entry confirmation
#define ICT_ENTRY_TF                 PERIOD_M5

//==================================================================
// RISK MANAGEMENT
//==================================================================

#define ICT_RISK_PERCENT             1.0
#define ICT_MAX_RISK_PERCENT         1.0
#define ICT_MAX_TOTAL_RISK_PERCENT   3.0

//==================================================================
// EA ID
//==================================================================

#define ICT_MAGIC_NUMBER             26093001

//==================================================================
// EXECUTION SAFETY
//==================================================================

#define ICT_MAX_SPREAD_PTS           50
#define ICT_MAX_SLIPPAGE_PTS         20
#define ICT_MIN_STOP_DISTANCE_PTS    10

//==================================================================
// POSITION LIMITS
//==================================================================

#define ICT_MAX_TOTAL_POSITIONS      3
#define ICT_MAX_SYMBOL_POSITIONS     1
#define ICT_MAX_OPEN_TRADES          3

//==================================================================
// MARKET STRUCTURE
//==================================================================

#define ICT_SWING_LEFT               2
#define ICT_SWING_RIGHT              2
#define ICT_STRUCTURE_LOOKBACK       150

#define ICT_MIN_BODY_RATIO           0.60
#define ICT_MIN_SWEEP_DISTANCE_PTS   0

//==================================================================
// SETUP VALIDITY
//==================================================================

#define ICT_SETUP_MAX_BARS           20
#define ICT_M15_CONFIRM_MAX_BARS     20
#define ICT_M5_CONFIRM_MAX_BARS      10

//==================================================================
// LIQUIDITY
//==================================================================

#define ICT_USE_PREVIOUS_DAY_LIQUIDITY   true
#define ICT_USE_PREVIOUS_WEEK_LIQUIDITY  true
#define ICT_USE_EQUAL_HIGHS_LOWS         true
#define ICT_USE_SESSION_LIQUIDITY        true

//==================================================================
// FAIR VALUE GAPS
//==================================================================

#define ICT_REQUIRE_FVG              false
#define ICT_MIN_FVG_SIZE_PTS         0
#define ICT_FVG_LOOKBACK             50
#define ICT_FVG_ALLOW_MITIGATION     true
#define ICT_FVG_ALLOW_RETEST         true

//==================================================================
// ORDER BLOCKS
//==================================================================

#define ICT_ENABLE_ORDER_BLOCK       true
#define ICT_OB_LOOKBACK              20
#define ICT_OB_ALLOW_MITIGATION      true
#define ICT_OB_ALLOW_RETEST          true

//==================================================================
// BREAKER / MITIGATION BLOCKS
//==================================================================

#define ICT_ENABLE_BREAKER_BLOCK     true
#define ICT_BREAKER_LOOKBACK         30

#define ICT_ENABLE_MITIGATION_BLOCK  true
#define ICT_MITIGATION_LOOKBACK      30

//==================================================================
// BREAKOUT / RETEST ENGINE
//==================================================================

#define ICT_ENABLE_BREAKOUT           true
#define ICT_ENABLE_RETEST             true

#define ICT_RETEST_LOOKBACK           20
#define ICT_RETEST_MAX_BARS           8

// Minimum confirmation required after a breakout/retest
#define ICT_RETEST_MIN_BODY_RATIO     0.55

//==================================================================
// REVERSAL ENGINE
//==================================================================

#define ICT_ENABLE_LIQUIDITY_REVERSAL true
#define ICT_ENABLE_FAILED_BREAKOUT    true
#define ICT_ENABLE_REJECTION_REVERSAL true

#define ICT_REVERSAL_LOOKBACK         20

//==================================================================
// TREND / CONTINUATION ENGINE
//==================================================================

#define ICT_ENABLE_TREND_CONTINUATION true
#define ICT_ENABLE_PULLBACK           true

#define ICT_TREND_LOOKBACK            50

//==================================================================
// PRICE ACTION ENGINE
//==================================================================

#define ICT_ENABLE_ENGULFING          true
#define ICT_ENABLE_PIN_BAR            true
#define ICT_ENABLE_REJECTION_CANDLE   true
#define ICT_ENABLE_MOMENTUM_CANDLE    true
#define ICT_ENABLE_INSIDE_BAR         true

//==================================================================
// VOLATILITY FILTER
//==================================================================

#define ICT_ENABLE_ATR_FILTER         true
#define ICT_ATR_PERIOD                14

#define ICT_ENABLE_VOLATILITY_FILTER  true
#define ICT_MIN_VOLATILITY_MULT       0.50
#define ICT_MAX_VOLATILITY_MULT       3.00

//==================================================================
// SESSION FILTER
//==================================================================

#define ICT_ENABLE_SESSION_FILTER     true

// Session times are broker-server-time placeholders.
// We will verify/adjust these later for your Exness server.
#define ICT_LONDON_START_HOUR         8
#define ICT_LONDON_END_HOUR           12

#define ICT_NEW_YORK_START_HOUR       13
#define ICT_NEW_YORK_END_HOUR         17

//==================================================================
// CONFLUENCE ENGINE
//==================================================================

// Minimum score required before a setup can proceed
#define ICT_MIN_CONFLUENCE_SCORE      70.0

// Individual scoring components
#define ICT_SCORE_STRUCTURE           20.0
#define ICT_SCORE_LIQUIDITY           15.0
#define ICT_SCORE_DISPLACEMENT        10.0
#define ICT_SCORE_FVG                 10.0
#define ICT_SCORE_ORDER_BLOCK         10.0
#define ICT_SCORE_RETEST              15.0
#define ICT_SCORE_PRICE_ACTION        10.0
#define ICT_SCORE_SESSION             5.0
#define ICT_SCORE_VOLATILITY          5.0

//==================================================================
// REWARD / TARGET
//==================================================================

#define ICT_MIN_REWARD_RR             2.0
#define ICT_MIN_REWARD_RISK           2.0

#define ICT_USE_LIQUIDITY_TARGET      true
#define ICT_USE_STRUCTURAL_TARGET     true

//==================================================================
// POSITION PROTECTION
//==================================================================

#define ICT_BLOCK_DUPLICATE_SYMBOL    true
#define ICT_BLOCK_OPPOSITE_SYMBOL     true

//==================================================================
// DAILY PROTECTION
//==================================================================

#define ICT_MAX_DAILY_LOSS_PERCENT    3.0

// 0 = disabled
#define ICT_DAILY_PROFIT_TARGET_PERCENT 0.0

//==================================================================
// GENERAL SAFETY
//==================================================================

#define ICT_TRADING_DEFAULT_ENABLED   false

#define ICT_MIN_HISTORY_BARS          150
#define ICT_PRICE_EPSILON_POINTS      1

//==================================================================
// GROWTH OBJECTIVE
//==================================================================

// These values are only a mathematical growth objective.
// They NEVER override the risk engine.

#define ICT_TARGET_EQUITY_FOR_LOT     5.0
#define ICT_TARGET_LOTS_AT_EQUITY     0.03

//==================================================================
// DEVELOPMENT
//==================================================================

// Trading remains OFF while we build and test the EA.
#define ICT_DEVELOPMENT_MODE          true

#endif
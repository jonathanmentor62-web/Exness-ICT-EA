//+------------------------------------------------------------------+
//| Config.mqh                                                       |
//| Central configuration for Exness ICT EA                          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_CONFIG_MQH__
#define __EXNESS_ICT_CONFIG_MQH__

#define ICT_PRIMARY_TF              PERIOD_H4
#define ICT_CONFIRM_TF              PERIOD_M15
#define ICT_ENTRY_TF                PERIOD_M5

//====================================================================
// RISK
//====================================================================

#define ICT_RISK_PERCENT            1.0
#define ICT_MAX_RISK_PERCENT        1.0
#define ICT_MAX_TOTAL_RISK_PERCENT  3.0

//====================================================================
// ACCOUNT / EA
//====================================================================

#define ICT_MAGIC_NUMBER            26093001

//====================================================================
// EXECUTION SAFETY
//====================================================================

#define ICT_MAX_SPREAD_PTS          50
#define ICT_MAX_SLIPPAGE_PTS        20
#define ICT_MIN_STOP_DISTANCE_PTS   10

//====================================================================
// POSITION LIMITS
//====================================================================

#define ICT_MAX_TOTAL_POSITIONS     3
#define ICT_MAX_SYMBOL_POSITIONS    1
#define ICT_MAX_OPEN_TRADES         3

//====================================================================
// MARKET STRUCTURE
//====================================================================

#define ICT_SWING_LEFT              2
#define ICT_SWING_RIGHT             2
#define ICT_STRUCTURE_LOOKBACK      100
#define ICT_MIN_BODY_RATIO          0.60

//====================================================================
// LIQUIDITY
//====================================================================

#define ICT_MIN_SWEEP_DISTANCE_PTS  0

//====================================================================
// SETUP EXPIRATION
//====================================================================

#define ICT_SETUP_MAX_BARS          12
#define ICT_M15_CONFIRM_MAX_BARS    16
#define ICT_M5_CONFIRM_MAX_BARS     8

//====================================================================
// FAIR VALUE GAP
//====================================================================

#define ICT_REQUIRE_FVG             true
#define ICT_MIN_FVG_SIZE_PTS        0

//====================================================================
// ORDER BLOCK
//====================================================================

#define ICT_ENABLE_ORDER_BLOCK      true
#define ICT_OB_LOOKBACK             10

//====================================================================
// TAKE PROFIT
//====================================================================

#define ICT_MIN_REWARD_RISK         2.0

//====================================================================
// DUPLICATE / OPPOSITE PROTECTION
//====================================================================

#define ICT_BLOCK_DUPLICATE_SYMBOL  true
#define ICT_BLOCK_OPPOSITE_SYMBOL   true

//====================================================================
// TRADING
//====================================================================

#define ICT_TRADING_DEFAULT_ENABLED false

//====================================================================
// DATA
//====================================================================

#define ICT_MIN_HISTORY_BARS        100
#define ICT_PRICE_EPSILON_POINTS    1

#endif
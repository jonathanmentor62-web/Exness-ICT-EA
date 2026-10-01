//+------------------------------------------------------------------+
//| Config.mqh - central configuration                               |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_CONFIG_MQH__
#define __EXNESS_ICT_CONFIG_MQH__

#define ICT_PRIMARY_TF              PERIOD_H4
#define ICT_CONFIRM_TF              PERIOD_M15
#define ICT_ENTRY_TF                PERIOD_M5

// Risk model
#define ICT_RISK_PERCENT            1.0
#define ICT_MAX_RISK_PERCENT        1.0
#define ICT_MAX_TOTAL_RISK_PERCENT  3.0

#define ICT_MAGIC_NUMBER            26093001

#define ICT_MAX_SPREAD_PTS          50
#define ICT_MAX_SLIPPAGE_PTS        20
#define ICT_MIN_STOP_DISTANCE_PTS   10

#define ICT_MAX_TOTAL_POSITIONS     3
#define ICT_MAX_SYMBOL_POSITIONS    1
#define ICT_MAX_OPEN_TRADES         3

#define ICT_SWING_LEFT              2
#define ICT_SWING_RIGHT             2
#define ICT_STRUCTURE_LOOKBACK      100
#define ICT_MIN_BODY_RATIO          0.60
#define ICT_MIN_SWEEP_DISTANCE_PTS  0

#define ICT_SETUP_MAX_BARS          12
#define ICT_M15_CONFIRM_MAX_BARS    16
#define ICT_M5_CONFIRM_MAX_BARS     8

#define ICT_REQUIRE_FVG             true
#define ICT_MIN_FVG_SIZE_PTS        0
#define ICT_ENABLE_ORDER_BLOCK      true
#define ICT_OB_LOOKBACK             10
#define ICT_MIN_REWARD_RR           2.0
#define ICT_MIN_REWARD_RISK         2.0

#define ICT_BLOCK_DUPLICATE_SYMBOL  true
#define ICT_BLOCK_OPPOSITE_SYMBOL   true
#define ICT_TRADING_DEFAULT_ENABLED false
#define ICT_MIN_HISTORY_BARS        100
#define ICT_PRICE_EPSILON_POINTS    1

//==================================================================
// M1 RAPID SCALPER SETTINGS
//==================================================================
#define ICT_SCALP_MIN_HISTORY          100
#define ICT_SCALP_RANGE_LOOKBACK       20
#define ICT_SCALP_ATR_PERIOD           14
#define ICT_SCALP_RANGE_MULT           1.20
#define ICT_SCALP_TICK_WINDOW_SEC      8
#define ICT_SCALP_PRESSURE_THRESHOLD   0.55
#define ICT_SCALP_MIN_SCORE            70.0
#define ICT_SCALP_REJECTION_RATIO      0.50
#define ICT_SCALP_SL_ATR_MULT          1.20
#define ICT_SCALP_SL_RANGE_MULT        0.80
#define ICT_SCALP_TP_ATR_MULT          0.80
#define ICT_SCALP_TP_RANGE_MULT        0.60
#define ICT_SCALP_MAX_HOLD_SECONDS     180
#define ICT_SCALP_COOLDOWN_SECONDS     5
#define ICT_SCALP_MAX_POSITIONS        3
#define ICT_SCALP_MAX_SYMBOL_POSITIONS 3
#define ICT_SCALP_ALLOW_STACKING       true
#define ICT_SCALP_MAX_SPREAD_POINTS    50
#define ICT_SCALP_EXIT_PRESSURE        0.55

// Requested equity/lot relationship is a ceiling, not a guarantee.
// Risk and broker volume rules always override this target.
#define ICT_TARGET_EQUITY_FOR_LOT      5.0
#define ICT_TARGET_LOTS_AT_EQUITY      0.03

#endif
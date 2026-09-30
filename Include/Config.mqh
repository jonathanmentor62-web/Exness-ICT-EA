//+------------------------------------------------------------------+
//| Config.mqh                                                       |
//| Central configuration for the Exness ICT EA                     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_CONFIG_MQH__
#define __EXNESS_ICT_CONFIG_MQH__

//====================================================================
// TIMEFRAMES
//====================================================================

//--- Primary market-structure timeframe
#define ICT_PRIMARY_TF              PERIOD_H4

//--- Confirmation / execution timeframe
#define ICT_CONFIRM_TF              PERIOD_M15


//====================================================================
// RISK MANAGEMENT
//====================================================================

//--- Maximum planned monetary risk per trade
//--- Position sizing must calculate volume from SL distance.
//--- If minimum broker volume exceeds this risk, trade is rejected.
#define ICT_MAX_RISK_MONEY          2.00

//--- Maximum number of EA positions allowed at the same time
#define ICT_MAX_TOTAL_POSITIONS     3

//--- Maximum number of positions allowed on one symbol
#define ICT_MAX_SYMBOL_POSITIONS    1


//====================================================================
// EA IDENTIFICATION
//====================================================================

//--- Unique magic number for this EA
#define ICT_MAGIC_NUMBER            26093001


//====================================================================
// EXECUTION SAFETY
//====================================================================

//--- Maximum allowed spread in broker points
#define ICT_MAX_SPREAD_PTS          50

//--- Maximum allowed execution deviation in broker points
#define ICT_MAX_SLIPPAGE_PTS        20

//--- Minimum distance from current price for protective levels
//--- Expressed in points and additionally checked against
//--- SYMBOL_TRADE_STOPS_LEVEL.
#define ICT_MIN_STOP_DISTANCE_PTS   10


//====================================================================
// MARKET STRUCTURE
//====================================================================

//--- Bars on each side used to confirm a swing
#define ICT_SWING_LEFT              2
#define ICT_SWING_RIGHT             2

//--- Default structural lookback
#define ICT_STRUCTURE_LOOKBACK      100


//====================================================================
// DISPLACEMENT
//====================================================================

//--- Minimum candle-body / total-range ratio
//
// Example:
//   0.60 = body must represent at least 60% of candle range.
//
// This is a filter, not a guarantee of institutional displacement.
// Later modules can add additional displacement requirements.
#define ICT_MIN_BODY_RATIO          0.60


//====================================================================
// LIQUIDITY
//====================================================================

//--- Minimum distance, in points, for considering a sweep meaningful.
//
// This prevents tiny one-point penetrations from automatically
// qualifying as meaningful liquidity sweeps on instruments where
// broker pricing makes such moves common.
#define ICT_MIN_SWEEP_DISTANCE_PTS  0


//====================================================================
// SETUP MANAGEMENT
//====================================================================

//--- Maximum number of H4 bars for an armed setup to remain valid
#define ICT_SETUP_MAX_BARS          12

//--- Maximum number of M15 bars allowed for confirmation after
//--- an H4 setup becomes armed.
//
// 16 M15 bars = 4 hours.
#define ICT_M15_CONFIRM_MAX_BARS    16


//====================================================================
// FVG
//====================================================================

//--- Require a valid three-candle imbalance structure
#define ICT_REQUIRE_FVG             true

//--- Minimum FVG size in points
//
// Set to zero initially so the detector is not artificially
// restrictive across EURUSD, XAUUSD and other symbols.
// Symbol-specific filtering can be added later.
#define ICT_MIN_FVG_SIZE_PTS        0


//====================================================================
// ORDER BLOCK
//====================================================================

//--- Enable Order Block detection in the confirmation pipeline
#define ICT_ENABLE_ORDER_BLOCK      true

//--- Maximum candles to search backward for the relevant
//--- Order Block before the displacement move.
#define ICT_OB_LOOKBACK             10


//====================================================================
// TARGET MANAGEMENT
//====================================================================

//--- Require the target to provide at least this theoretical
//--- reward/risk before an entry can be accepted.
//
// This is a validation threshold, not a promise of profitability.
#define ICT_MIN_REWARD_RISK         2.0


//====================================================================
// ACCOUNT / TRADE SAFETY
//====================================================================

//--- Do not open another position if an existing EA position
//--- already exists for the same symbol.
#define ICT_BLOCK_DUPLICATE_SYMBOL  true

//--- Prevent opposite-direction positions on the same symbol.
#define ICT_BLOCK_OPPOSITE_SYMBOL   true

//--- Maximum simultaneous EA positions.
#define ICT_MAX_OPEN_TRADES         3


//====================================================================
// DEVELOPMENT SAFETY
//====================================================================

//--- Trading is deliberately disabled during development.
//
// DO NOT change this to true until compilation, backtesting,
// forward testing and execution validation have been completed.
#define ICT_TRADING_DEFAULT_ENABLED false


//====================================================================
// DATA VALIDATION
//====================================================================

//--- Minimum bars required before structural analysis
#define ICT_MIN_HISTORY_BARS        100

//--- Number of digits used when comparing floating-point prices.
//--- Actual symbol digits are obtained dynamically from MT5.
#define ICT_PRICE_EPSILON_POINTS    1


#endif

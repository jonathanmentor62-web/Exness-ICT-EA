//+------------------------------------------------------------------+
//| Config.mqh                                                       |
//| Central configuration for Exness ICT EA                          |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_CONFIG_MQH__
#define __EXNESS_ICT_CONFIG_MQH__

//====================================================================
// PRIMARY TIMEFRAMES
//====================================================================

#define ICT_PRIMARY_TF              PERIOD_H4
#define ICT_CONFIRM_TF              PERIOD_M15


//====================================================================
// RISK MANAGEMENT
//====================================================================

// Maximum planned monetary risk per trade.
#define ICT_MAX_RISK_MONEY          2.00

// Maximum number of open positions across the EA.
#define ICT_MAX_TOTAL_POSITIONS     3

// Maximum positions allowed on one symbol.
#define ICT_MAX_SYMBOL_POSITIONS    1


//====================================================================
// EA IDENTIFICATION
//====================================================================

#define ICT_MAGIC_NUMBER            26093001


//====================================================================
// EXECUTION SAFETY
//====================================================================

// Maximum allowed spread in broker points.
#define ICT_MAX_SPREAD_PTS          50

// Maximum execution deviation/slippage in broker points.
#define ICT_MAX_SLIPPAGE_PTS        20

// Minimum stop distance in broker points.
#define ICT_MIN_STOP_DISTANCE_PTS   10


//====================================================================
// MARKET STRUCTURE
//====================================================================

// Number of candles on each side used to confirm a swing.
#define ICT_SWING_LEFT              2
#define ICT_SWING_RIGHT             2

// Maximum historical candles scanned for structure.
#define ICT_STRUCTURE_LOOKBACK      100


//====================================================================
// DISPLACEMENT
//====================================================================

// Minimum candle body/range ratio required for displacement.
//
// Example:
// 0.60 = candle body must be at least 60% of the entire candle range.
#define ICT_MIN_BODY_RATIO          0.60


//====================================================================
// LIQUIDITY
//====================================================================

// Minimum sweep distance in broker points.
//
// 0 means any penetration of the liquidity level is acceptable.
#define ICT_MIN_SWEEP_DISTANCE_PTS  0


//====================================================================
// H4 SETUP LIFETIME
//====================================================================

// Maximum number of H4 bars for an H4 setup to remain active.
#define ICT_SETUP_MAX_BARS          12


//====================================================================
// M15 CONFIRMATION LIFETIME
//====================================================================

// Maximum number of M15 bars allowed for confirmation after H4 setup.
#define ICT_M15_CONFIRM_MAX_BARS    16


//====================================================================
// FAIR VALUE GAP
//====================================================================

// M15 confirmation must contain a directional FVG.
#define ICT_REQUIRE_FVG             true

// Minimum FVG size in broker points.
//
// 0 means no additional minimum-size filter.
#define ICT_MIN_FVG_SIZE_PTS        0


//====================================================================
// ORDER BLOCK
//====================================================================

// Enable Order Block detection as confluence.
#define ICT_ENABLE_ORDER_BLOCK      true

// Number of candles searched when looking for an Order Block.
#define ICT_OB_LOOKBACK             10


//====================================================================
// REWARD / RISK
//====================================================================

// Minimum planned reward-to-risk ratio for the future
// execution engine.
//
// 2.0 = minimum 2:1 reward-to-risk.
#define ICT_MIN_REWARD_RISK         2.0


//====================================================================
// POSITION SAFETY
//====================================================================

// Prevent multiple EA positions on the same symbol.
#define ICT_BLOCK_DUPLICATE_SYMBOL  true

// Prevent opening an opposite-direction position on a symbol
// that already has an EA position.
#define ICT_BLOCK_OPPOSITE_SYMBOL   true

// Maximum number of EA positions.
#define ICT_MAX_OPEN_TRADES         3


//====================================================================
// TRADING DEFAULT
//====================================================================

// IMPORTANT:
// Trading remains disabled during development/testing.
#define ICT_TRADING_DEFAULT_ENABLED false


//====================================================================
// DATA REQUIREMENTS
//====================================================================

// Minimum amount of historical data required before analysis.
#define ICT_MIN_HISTORY_BARS        100


//====================================================================
// PRICE COMPARISON
//====================================================================

// Small price tolerance used when comparing liquidity levels.
#define ICT_PRICE_EPSILON_POINTS    1


#endif
//+------------------------------------------------------------------+

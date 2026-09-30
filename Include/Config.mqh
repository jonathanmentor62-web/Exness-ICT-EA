//+------------------------------------------------------------------+
//| Config.mqh                                                       |
//| Central configuration for the Exness ICT EA                     |
//+------------------------------------------------------------------+
#ifndef __EXNESS_ICT_CONFIG_MQH__
#define __EXNESS_ICT_CONFIG_MQH__

//--- Primary analysis
#define ICT_PRIMARY_TF       PERIOD_H4
#define ICT_CONFIRM_TF       PERIOD_M15

//--- Risk
#define ICT_MAX_RISK_MONEY   2.00

//--- EA identification
#define ICT_MAGIC_NUMBER     26093001

//--- Execution safety
#define ICT_MAX_SPREAD_PTS   50
#define ICT_MAX_SLIPPAGE_PTS 20

//--- Structure settings
#define ICT_SWING_LEFT       2
#define ICT_SWING_RIGHT      2

//--- Minimum displacement
#define ICT_MIN_BODY_RATIO   0.60

//--- Setup expiration
#define ICT_SETUP_MAX_BARS   12

#endif

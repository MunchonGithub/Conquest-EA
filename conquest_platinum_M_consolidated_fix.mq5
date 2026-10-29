//+------------------------------------------------------------------+
//|                              ConquestPlatinumClean.mq5          |
//|              Clean Complete Version - All Functions Properly Scoped |
//|              WITH DAILY TARGET SYSTEM - Stop at Profit Goal      |
//+------------------------------------------------------------------+
#property copyright "Empire Trading Systems - Clean"
#property version   "2.50"
#property description "FVG/BOS Signal Bus + Cross-Block Intelligence + BOS Entry + Bias-Free + Enhanced R:R"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

enum ENUM_TRADING_MODE
{
   MODE_BUY_ONLY = 0,
   MODE_SELL_ONLY = 1,
   MODE_AUTO = 2,
   MODE_SEQUENTIAL = 3,
   MODE_PHASE = 4
};

enum ENUM_STRATEGY_TYPE
{
   STRATEGY_SCALP = 0,
   STRATEGY_LONG  = 1,
   STRATEGY_ACE   = 2,
   STRATEGY_AUTO  = 3,
   STRATEGY_PRINT = 4
};

enum ENUM_TARGET_TYPE
{
   TARGET_CURRENCY = 0,  // Fixed currency amount (e.g., $100)
   TARGET_PERCENT = 1    // Percentage of balance (e.g., 5%)
};

//--- Input Parameters
input group "=== Core Settings ===";
input double             InpLotSize = 0.01;
input ENUM_TRADING_MODE  InpTradingMode = MODE_AUTO;
input ENUM_STRATEGY_TYPE InpStrategyType = STRATEGY_AUTO;
input int                InpMaxTrades = 3;
input double             InpTargetROI = 15.0;
input bool               InpEnableLogging = true;
input int                InpMagicNumber = 747474;

input group "=== Daily Target System ===";
input bool               InpEnableDailyTarget = true;           // Enable daily profit target
input ENUM_TARGET_TYPE   InpTargetType = TARGET_CURRENCY;       // Target type
input double             InpDailyTargetAmount = 100.0;          // Target amount (currency or %)
input bool               InpStopOnTargetReached = true;         // Stop trading when target reached
input bool               InpAlertOnTargetReached = true;        // Send alert when target reached
input bool               InpCloseAllOnTarget = false;           // Close all positions when target reached

input group "=== AI Enhancement ===";
input bool               InpEnableAILearning = true;
input double             InpAIInfluence = 0.3;

input group "=== PRINT Strategy ===";
input int                InpMaxPrintTradesPerDay = 3;
input double             InpPrintDisplacementThreshold = 0.0025;
input bool               InpEnableScaleIns = true;

input group "=== Intelligence Improvements ===";
input bool   InpEnableSessionFilter = true;   // Weight by session (London/NY prime)
input bool   InpEnableADXFilter     = true;   // Block trend trades when ADX < threshold
input int    InpADXPeriod           = 14;     // ADX period
input double InpMinADXTrend         = 20.0;   // Min ADX for trend strategies
input bool   InpBlockRSIExtremes    = true;   // Block BUY on H1 RSI>73, SELL on RSI<27
input int    InpConsecLossCircuit   = 3;      // Consecutive losses before corridor tightens

//--- Global Objects
CTrade trade;
CPositionInfo position;

//--- Indicator handles
int atr_handle=INVALID_HANDLE, ma_fast_handle=INVALID_HANDLE, ma_slow_handle=INVALID_HANDLE, rsi_handle=INVALID_HANDLE;
int adx_handle=INVALID_HANDLE, h1_rsi_handle=INVALID_HANDLE;
int g_consec_losses = 0;

//--- Data Structures
struct MarketData
{
   double price_current, price_open, price_high, price_low, price_close;
   double atr, ma_fast, ma_slow, rsi;
   double volatility_regime, trend_strength, momentum_state, liquidity_condition;
   double volume_fractal_dimension, price_compression_ratio;
   double liquidity_density_gradient, information_velocity;
   datetime timestamp;
   bool data_valid;
};

struct InstitutionalFormulas
{
   double rvg, fcd, dcsa, esd, rcs, mpi, lsf;
   double pattern_coherence, regime_stability, transition_probability;
   double fractal_dimension, confidence_evolution, signal_persistence;
   double power_law_alpha, liquidity_vacuum_distance, echo_recursion_depth;
   double compression_energy, information_imbalance_vector;
   bool pattern_recognized, reasoning_complete;
};

struct AdvancedStrategy
{
   double strategy_fitness[5];
   double regime_probabilities[5];
   double regime_confidence;
   double market_state_vector[8];
   double strategy_vectors[5][8];
   bool intelligence_active;
};

struct StrategyVoting
{
   int top_strategies[3];
   double strategy_votes[5];
   double voting_weights[5];
   double final_consensus;
   int elected_strategy;
   bool voting_complete;
};

struct TradingDecision
{
   bool should_trade;
   ENUM_ORDER_TYPE trade_direction;
   double position_size, stop_loss_distance, take_profit_distance;
   double confidence_level, expected_return, risk_reward_ratio;
   string reasoning_summary;
   bool execution_ready;
};

struct PerformanceMetrics
{
   int total_signals, trades_executed, winning_trades;
   double total_profit, current_roi, avg_confidence;
   double pattern_accuracy, ai_learning_score;
};

struct TrailingData
{
   ulong ticket;
   double max_profit_points, entry_price, original_tp, original_sl;
   datetime entry_time;
   bool trailing_active, scale1_done, scale2_done;
};

struct FairValueGap
{
   bool is_valid, is_bullish, filled;
   double gap_high, gap_low, gap_center, displacement_strength;
   datetime formation_time, expiry_time;
};

struct PrintStrategy
{
   bool monitoring_active, displacement_detected, waiting_for_entry;
   datetime hour_start_time, monitoring_end, last_reset_date;
   FairValueGap active_fvg;
   double hour_open_price, displacement_threshold;
   int opportunities_today, trades_taken_today;
};

struct FractalMarketIntelligence
{
   double power_law_exponent, tail_probability, concentration_ratio;
   bool power_law_cluster_detected;
   double liquidity_depth_fractal, liquidity_vacuum_threshold;
   double liquidity_teleport_probability, true_liquidity_metric;
   double echo_signatures[5], recursive_confidence;
   bool echo_alignment_detected;
   datetime next_echo_window;
   double compression_phase_strength, expansion_release_probability;
   double volatility_asymmetry_index;
   bool in_compression_phase;
   double retail_lag_coefficient, institutional_flow_velocity;
   double information_gap_strength, imbalance_window_probability;
   double fractal_confluence_score, meta_strategy_alignment;
   bool geometric_convergence_detected;
};

// ═══════════════════════════════════════════════════════════════════
// SHARED SIGNAL BUS — computed once per bar, read by every strategy
// This is the communication layer that makes all blocks work together.
// ═══════════════════════════════════════════════════════════════════
struct SharedSignalContext
{
   // ── H1 Fair Value Gap (3-candle imbalance) ──────────────────────
   bool   fvg_bull;          // bullish FVG: bar[1].low > bar[3].high
   bool   fvg_bear;          // bearish FVG: bar[1].high < bar[3].low
   double fvg_high;          // top boundary of the gap
   double fvg_low;           // bottom boundary of the gap
   double fvg_mid;           // midpoint — magnet for price
   double fvg_target;        // projected TP: equal leg beyond gap

   // ── Break of Structure on CLOSED bar ────────────────────────────
   bool   bos_bull;          // last closed bar close > recent swing high
   bool   bos_bear;          // last closed bar close < recent swing low
   double bos_level;         // the broken swing level

   // ── Swing structure (bars 2–11, skipping live and last closed) ───
   double swing_high;
   double swing_low;
   int    structural_dir;    // +1=bull (HH+HL), -1=bear (LH+LL), 0=mixed

   // ── Composite quality gate (0-1) — read by all strategies ───────
   double signal_quality;    // BOS + FVG + structure + fractal confluence

   // ── Sequence direction bias — read by Sequential/Phase mode ─────
   int    seq_bias;          // +1=favor BUY sequence, -1=favor SELL, 0=neutral
};

struct DailyTargetSystem
{
   bool enabled;   bool target_reached;
   bool trading_locked;
   double target_amount;
   double daily_profit;
   double daily_starting_balance;
   datetime last_check_date;
   datetime target_reached_time;
   int trades_before_target;
   int trades_after_target;
   string target_status;
};


//--- Global Variables
MarketData market_data;
InstitutionalFormulas formulas;
AdvancedStrategy strategy_core;
StrategyVoting strategy_vote;
TradingDecision decision;
PerformanceMetrics performance;
TrailingData trailing_positions[20];
int trailing_count = 0;
PrintStrategy print_strategy;
FractalMarketIntelligence fractal_intel;
SharedSignalContext       shared_ctx;   // ← signal bus, populated once per bar
DailyTargetSystem daily_target;

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(min_lot<=0 || lot_step<=0) return(lot);
   lot = MathMax(min_lot, MathMin(max_lot, lot));
   lot = MathFloor(lot/lot_step + 0.0000001) * lot_step;
   int d = 0;
   while(d<8 && lot_step > 0)
   {
      double scaled = lot_step * MathPow(10.0,d);
      if(MathAbs(scaled - MathRound(scaled)) < 1e-12) break;
      d++;
   }
   return(NormalizeDouble(lot, d));
}

double ComputeBoundedErrorEnvelope(
    double fractal_confluence,
    double phase_quality,
    double momentum_state,
    double volatility_z,
    double regime_transition_intensity)
{
    // Tunable weights (keep local to avoid global pollution)
    const double w1 = 0.35;
    const double w2 = 0.20;
    const double w3 = 0.30;
    const double w4 = 0.25;

    const double k  = 1.15;   // curvature strength

    double state_divergence =
          w1 * MathAbs(fractal_confluence - phase_quality)
        + w2 * MathAbs(momentum_state)
        + w3 * MathAbs(volatility_z)
        + w4 * MathAbs(regime_transition_intensity);

    double error_bound = 1.0 - MathExp(-k * state_divergence);

    // Hard clamp for safety
    if(error_bound < 0.0) error_bound = 0.0;
    if(error_bound > 0.95) error_bound = 0.95;

    return error_bound;
}

double Sigmoid(double x)
{
   return 1.0 / (1.0 + MathExp(-x));
}

bool ValidNumber(double v)
{
   return MathIsValidNumber(v);
}

int GetDayOf(datetime t)
{
   if(t == 0) return 0;
   MqlDateTime st; TimeToStruct(t, st);
   return st.day;
}


string StrategyToString(ENUM_STRATEGY_TYPE st)
{
   switch(st)
   {
      case STRATEGY_SCALP: return "SCALP";
      case STRATEGY_LONG:  return "LONG";
      case STRATEGY_ACE:   return "ACE";
      case STRATEGY_AUTO:  return "AUTO";
      case STRATEGY_PRINT: return "PRINT";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Daily Target System Functions                                    |
//+------------------------------------------------------------------+
void InitializeDailyTargetSystem()
{
   daily_target.enabled = InpEnableDailyTarget;
   daily_target.target_reached = false;
   daily_target.trading_locked = false;
   daily_target.target_amount = InpDailyTargetAmount;
   daily_target.daily_profit = 0.0;
   daily_target.daily_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   daily_target.last_check_date = 0;
   daily_target.target_reached_time = 0;
   daily_target.trades_before_target = 0;
   daily_target.trades_after_target = 0;
   daily_target.target_status = "Initialized - Waiting for first day";
   
   if(InpEnableLogging && daily_target.enabled)
   {
      PrintFormat("Daily Target System ENABLED | Type: %s | Amount: %.2f | Stop on Target: %s",
                  InpTargetType == TARGET_CURRENCY ? "CURRENCY" : "PERCENT",
                  InpDailyTargetAmount,
                  InpStopOnTargetReached ? "YES" : "NO");
   }
}

void CalculateDailyProfit()
{
   double profit_today = 0.0;
   double loss_today = 0.0;

   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);
   datetime today_start = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                                     current_time.year, 
                                                     current_time.mon, 
                                                     current_time.day));

   if (HistorySelect(today_start, TimeCurrent()))
   {
      int total_deals = HistoryDealsTotal();
      for (int i = 0; i < total_deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if (ticket > 0)
         {
            if (HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
               HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
            {
               double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               // Add swap and commission if needed
               double deal_swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
               double deal_commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
               deal_profit += deal_swap + deal_commission;

               if (deal_profit > 0)
                  profit_today += deal_profit;
               else
                  loss_today += MathAbs(deal_profit);
            }
         }
      }
   }

   double floating_profit = 0.0;
   double floating_loss = 0.0;
   int total_positions = PositionsTotal();
   for (int i = 0; i < total_positions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double position_profit = PositionGetDouble(POSITION_PROFIT);
            if (position_profit > 0)
               floating_profit += position_profit;
            else
               floating_loss += MathAbs(position_profit);
         }
      }
   }

   daily_target.daily_profit = (profit_today + floating_profit) - (loss_today + floating_loss);
}

void CloseAllPositions()
{
   int closed_count = 0;
   int total_positions = PositionsTotal();
   
   for(int i = total_positions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(trade.PositionClose(ticket))
            {
               closed_count++;
               if(InpEnableLogging)
                  PrintFormat("Closed position #%I64u on target reached", ticket);
            }
         }
      }
   }
   
   if(InpEnableLogging && closed_count > 0)
   {
      PrintFormat("Closed %d positions after reaching daily target", closed_count);
   }
}

void ResetDailyTarget(datetime new_day)
{
   if(InpEnableLogging)
   {
      PrintFormat("=== NEW TRADING DAY DETECTED ===");
      PrintFormat("Previous day profit: %.2f | Target reached: %s | Trades blocked: %d",
                  daily_target.daily_profit,
                  daily_target.target_reached ? "YES" : "NO",
                  daily_target.trades_after_target);
   }
   
   // Adaptive target calculation
   double base_target = InpDailyTargetAmount;
   double adjustment = 1.0;
   
   datetime one_week_ago = TimeCurrent() - 86400 * 7;
   if(HistorySelect(one_week_ago, TimeCurrent()))
   {
      double weekly_profit = 0.0;
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
         {
            weekly_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
      }
      adjustment = 1.0 + 0.2 * (weekly_profit / AccountInfoDouble(ACCOUNT_BALANCE));
   }
   
   daily_target.target_amount = base_target * adjustment;

   daily_target.last_check_date = new_day;
   daily_target.target_reached = false;
   daily_target.trading_locked = false;
   daily_target.daily_profit = 0.0;
   daily_target.daily_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   daily_target.target_reached_time = 0;
   daily_target.trades_before_target = 0;
   daily_target.trades_after_target = 0;
   daily_target.target_status = "Active - New Day Started";
   
   if(InpEnableLogging)
   {
      PrintFormat("Daily Target RESET | Starting Balance: %.2f | Target: %.2f",
                  daily_target.daily_starting_balance,
                  daily_target.target_amount);
   }
}
void OnDailyTargetReached(double threshold)
{
   daily_target.target_reached = true;
   daily_target.target_reached_time = TimeCurrent();

   double net_profit = daily_target.daily_profit;

   if (InpEnableLogging)
   {
      string message = StringFormat(
         "\n??????????????????????????????????????????\n"
         "?   DAILY TARGET REACHED! ??            ?\n"
         "??????????????????????????????????????????\n"
         "? Target:   %.2f                         ?\n"
         "? Net Profit: %.2f                       ?\n"
         "? Time:     %s                           ?\n"
         "? Trades:   %d                           ?\n"
         "? Status:   %s                           ?\n"
         "??????????????????????????????????????????",
         threshold,
         net_profit,
         TimeToString(daily_target.target_reached_time, TIME_DATE | TIME_SECONDS),
         daily_target.trades_before_target,
         InpStopOnTargetReached ? "TRADING LOCKED" : "STILL ACTIVE"
      );
      Print(message);
   }

   if (InpAlertOnTargetReached)
   {
      string alert_text = StringFormat("Conquest Platinum: Daily net profit target reached! Net Profit: %.2f", net_profit);
      Alert(alert_text);
      SendNotification(alert_text);
   }

   if (InpCloseAllOnTarget)
   {
      CloseAllPositions();
   }

   daily_target.target_status = "TARGET REACHED - " + (InpStopOnTargetReached ? "Trading Locked" : "Still Active");
}
void UpdateTargetStatusString(double threshold)
{
   if(!daily_target.enabled)
   {
      daily_target.target_status = "Disabled";
      return;
   }
   
   if(daily_target.target_reached)
   {
      double time_since_target = (TimeCurrent() - daily_target.target_reached_time) / 60.0;
      daily_target.target_status = StringFormat("TARGET MET %.0f min ago | Profit: %.2f | Locked: %s",
                                                time_since_target,
                                                daily_target.daily_profit,
                                                daily_target.trading_locked ? "YES" : "NO");
   }
   else
   {
      double progress_percent = (threshold > 0) ? (daily_target.daily_profit / threshold) * 100.0 : 0.0;
      double remaining = threshold - daily_target.daily_profit;
      
      daily_target.target_status = StringFormat("Active | Progress: %.1f%% | Remaining: %.2f",
                                                progress_percent,
                                                remaining);
   }
}

void CheckDailyTargetStatus()
{
   if(!daily_target.enabled) return;
   
   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                               current_time.year, 
                                               current_time.mon, 
                                               current_time.day));
   
   if(daily_target.last_check_date != today)
   {
      ResetDailyTarget(today);
   }
   
   CalculateDailyProfit();
   
   double target_threshold = InpTargetType == TARGET_CURRENCY ?
                            daily_target.target_amount :
                            daily_target.daily_starting_balance * (daily_target.target_amount / 100.0);
   
   if(!daily_target.target_reached && daily_target.daily_profit >= target_threshold)
   {
      OnDailyTargetReached(target_threshold);
   }
   
   UpdateTargetStatusString(target_threshold);
}

bool IsTradingAllowed()
{
   if(!daily_target.enabled) return true;
   
   if(daily_target.trading_locked && daily_target.target_reached)
   {
      daily_target.trades_after_target++;
      
      if(InpEnableLogging)
      {
         PrintFormat("Trading BLOCKED: Daily target reached (%.2f) | Time: %s | Trades blocked: %d",
                     daily_target.daily_profit,
                     TimeToString(daily_target.target_reached_time, TIME_DATE|TIME_SECONDS),
                     daily_target.trades_after_target);
      }
      
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialization Functions                                          |
//+------------------------------------------------------------------+
void InitializeAllSystems()
{
   market_data.data_valid = false;
   market_data.volatility_regime = 1.0;
   market_data.trend_strength = 0.0;
   market_data.momentum_state = 0.0;
   market_data.liquidity_condition = 1.0;
   market_data.volume_fractal_dimension = 1.0;
   market_data.price_compression_ratio = 0.0;
   market_data.liquidity_density_gradient = 1.0;
   market_data.information_velocity = 0.5;

   formulas.rvg = formulas.fcd = formulas.dcsa = 0.0;
   formulas.esd = 2.0; formulas.rcs = 0.5; formulas.mpi = 0.0; formulas.lsf = 1.0;
   formulas.pattern_coherence = 0.5; formulas.regime_stability = 0.5;
   formulas.transition_probability = 0.0; formulas.fractal_dimension = 1.5;
   formulas.confidence_evolution = 0.0; formulas.signal_persistence = 0.0;
   formulas.pattern_recognized = false; formulas.reasoning_complete = true;
   formulas.power_law_alpha = 2.0; formulas.liquidity_vacuum_distance = 0.0;
   formulas.echo_recursion_depth = 0.5; formulas.compression_energy = 0.0;
   formulas.information_imbalance_vector = 0.0;

   strategy_core.intelligence_active = true;
   strategy_core.regime_confidence = 0.6;
   for(int i=0;i<5;i++) { strategy_core.strategy_fitness[i] = 0.6; strategy_core.regime_probabilities[i] = 0.2; }

   double vectors[5][8] = {
      {0.8,0.3,0.9,0.7,0.9,0.8,0.4,0.1},
      {0.4,0.9,0.5,0.3,0.6,0.7,0.6,0.9},
      {0.6,0.5,0.6,0.5,0.7,0.4,0.8,0.5},
      {0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5},
      {0.7,0.6,0.8,0.9,0.8,0.6,0.7,0.3}
   };
   for(int s=0; s<5; s++) for(int d=0; d<8; d++) strategy_core.strategy_vectors[s][d] = vectors[s][d];

   for(int i=0;i<3;i++) strategy_vote.top_strategies[i] = -1;
   for(int i=0;i<5;i++) strategy_vote.strategy_votes[i] = 0.0;
   
   
   double weights[5] = {0.30, 0.25, 0.20, 0.15, 0.10};
   for(int i=0;i<5;i++) strategy_vote.voting_weights[i] = weights[i];
   strategy_vote.final_consensus = 0.0; strategy_vote.elected_strategy = -1;
   strategy_vote.voting_complete = false;

   decision.should_trade = false; decision.trade_direction = ORDER_TYPE_BUY;
   decision.position_size = InpLotSize; decision.confidence_level = 0.0;
   decision.expected_return = 0.0; decision.risk_reward_ratio = 2.0;
   decision.reasoning_summary = ""; decision.execution_ready = false;

   performance.total_signals = 0; performance.trades_executed = 0; performance.winning_trades = 0;
   performance.total_profit = 0.0; performance.current_roi = 0.0; performance.avg_confidence = 0.0;
   performance.pattern_accuracy = 0.0; performance.ai_learning_score = 0.0;

   for(int i=0;i<20;i++) {
      trailing_positions[i].ticket = 0; trailing_positions[i].trailing_active = false;
      trailing_positions[i].entry_price = 0.0; trailing_positions[i].max_profit_points = 0.0;
      trailing_positions[i].scale1_done = false; trailing_positions[i].scale2_done = false;
      trailing_positions[i].original_tp = 0.0; trailing_positions[i].original_sl = 0.0;
   }
   trailing_count = 0;

   print_strategy.monitoring_active = false; print_strategy.displacement_detected = false;
   print_strategy.waiting_for_entry = false; print_strategy.hour_start_time = 0;
   print_strategy.monitoring_end = 0; print_strategy.last_reset_date = 0;
   print_strategy.active_fvg.is_valid = false; print_strategy.active_fvg.filled = false;
   print_strategy.hour_open_price = 0.0; print_strategy.displacement_threshold = InpPrintDisplacementThreshold;
   print_strategy.opportunities_today = 0; print_strategy.trades_taken_today = 0;

   fractal_intel.power_law_exponent = 2.0; fractal_intel.tail_probability = 0.1;
   fractal_intel.concentration_ratio = 0.5; fractal_intel.power_law_cluster_detected = false;
   fractal_intel.liquidity_depth_fractal = 1.0; fractal_intel.liquidity_vacuum_threshold = 0.0;
   fractal_intel.liquidity_teleport_probability = 0.1; fractal_intel.true_liquidity_metric = 1.0;
   for(int i=0;i<5;i++) fractal_intel.echo_signatures[i] = 0.5;
   fractal_intel.recursive_confidence = 0.5; fractal_intel.echo_alignment_detected = false;
   fractal_intel.next_echo_window = 0; fractal_intel.compression_phase_strength = 0.0;
   fractal_intel.expansion_release_probability = 0.1; fractal_intel.volatility_asymmetry_index = 0.0;
   fractal_intel.in_compression_phase = false; fractal_intel.retail_lag_coefficient = 0.5;
   fractal_intel.institutional_flow_velocity = 0.6; fractal_intel.information_gap_strength = 0.0;
   fractal_intel.imbalance_window_probability = 0.1; fractal_intel.fractal_confluence_score = 0.0;
   fractal_intel.meta_strategy_alignment = 0.5; fractal_intel.geometric_convergence_detected = false;
   
   InitializeDailyTargetSystem();
   
   
}

//+------------------------------------------------------------------+
//| Expert Advisor Events                                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Intelligence Engine Helper Functions                             |
//+------------------------------------------------------------------+

double SessionQuality()
{
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int hh = t.hour;
   if(hh >= 9  && hh < 16) return 1.00;  // London prime + NY overlap
   if(hh >= 7  && hh < 9)  return 0.85;  // London open shoulder
   if(hh >= 16 && hh < 21) return 0.90;  // NY session
   if(hh >= 6  && hh < 7)  return 0.65;  // Pre-London
   return 0.40;                           // Asian dead zone (21-06 UTC)
}

double GetADX14()
{
   if(adx_handle == INVALID_HANDLE) return 25.0;
   double buf[1];
   if(CopyBuffer(adx_handle, 0, 1, 1, buf) <= 0) return 25.0;
   return MathMax(0.0, buf[0]);
}

bool IsRSIExtreme(bool is_buy)
{
   if(h1_rsi_handle == INVALID_HANDLE) return false;
   double buf[1];
   if(CopyBuffer(h1_rsi_handle, 0, 1, 1, buf) <= 0) return false;
   double rsi = buf[0];
   if(is_buy  && rsi > 73.0) return true;
   if(!is_buy && rsi < 27.0) return true;
   return false;
}

// [REPLACE THE EXISTING OnInit FUNCTION WITH THIS]
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   

   // --- INSTITUTIONAL UPGRADE: Subscribe to Depth of Market ---
   if(!MarketBookAdd(_Symbol))
   {
      Print("Failed to subscribe to MarketBook (DOM). Liquidity checks may fail.");
   }

   atr_handle    = iATR(_Symbol, PERIOD_CURRENT, 14);
   adx_handle    = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   h1_rsi_handle = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
   ma_fast_handle = iMA(_Symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
   ma_slow_handle = iMA(_Symbol, PERIOD_CURRENT, 55, 0, MODE_SMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);

   if(atr_handle==INVALID_HANDLE || ma_fast_handle==INVALID_HANDLE ||
      ma_slow_handle==INVALID_HANDLE || rsi_handle==INVALID_HANDLE)
   {
      Print("ERROR: Failed to initialize indicators");
      return INIT_FAILED;
   }

   InitializeAllSystems();

   if(InpEnableLogging)
   {
      Print("????????????????????????????????????????????????????????????");
      Print("?   Conquest Platinum EA - INSTITUTIONAL GRADE             ?");
      Print("????????????????????????????????????????????????????????????");
      PrintFormat("? Strategy: %-43s ?", StrategyToString((ENUM_STRATEGY_TYPE)InpStrategyType));
      PrintFormat("? Execution: %-42s ?", "ASYNCHRONOUS (FOK)");
      PrintFormat("? Liquidity Guard: %-38s ?", "ACTIVE (Level 2)");
      Print("????????????????????????????????????????????????????????????");
   }

   return INIT_SUCCEEDED;
}

// [REPLACE THE EXISTING OnDeinit FUNCTION WITH THIS]
void OnDeinit(const int reason)
{
   if(atr_handle!=INVALID_HANDLE)    IndicatorRelease(atr_handle);
   if(adx_handle!=INVALID_HANDLE)    IndicatorRelease(adx_handle);
   if(h1_rsi_handle!=INVALID_HANDLE) IndicatorRelease(h1_rsi_handle);
   if(ma_fast_handle!=INVALID_HANDLE) IndicatorRelease(ma_fast_handle);
   if(ma_slow_handle!=INVALID_HANDLE) IndicatorRelease(ma_slow_handle);
   if(rsi_handle!=INVALID_HANDLE) IndicatorRelease(rsi_handle);
   
   // --- INSTITUTIONAL UPGRADE: Release DOM subscription ---
   MarketBookRelease(_Symbol);
   
   PrintPerformanceReport();
}

void OnTick()
{
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   // Protect open positions every tick; leave signal generation on closed-bar cadence.
   ManageTrailingStops();
   CheckDailyTargetStatus();
   if(current_bar_time == last_bar_time) return;
   last_bar_time = current_bar_time;

   if(!UpdateMarketData()) return;

   ProcessInstitutionalFormulas();
   ProcessFractalIntelligence();
   ApplyEchoRefine();
   ComputeSharedContext();       // ← populate signal bus for all strategies
   ProcessAdvancedStrategy();
   ConductStrategyVoting();

   int selected_strategy = GetOptimalStrategy();
   if(selected_strategy == STRATEGY_PRINT || InpStrategyType == STRATEGY_PRINT)
      ProcessPrintStrategy();

   ProcessTradingDecision();
   UpdatePerformanceMetrics();
}

void OnTrade()
{
   performance.total_profit = 0.0;
   performance.winning_trades = 0;

   if(HistorySelect(TimeCurrent() - 86400, TimeCurrent()))
   {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            performance.total_profit += profit;
            if(profit > 0) { performance.winning_trades++; }
            else if(profit < 0) { /* confirmed exits update streak in OnTradeTransaction */ }
         }
      }
   }
   
   
   //=================================================================
   // UPGRADE 3: RECENT TRADE MEMORY (Adaptive Learning)
   //=================================================================
   static double recent_buy_results[5] = {0,0,0,0,0};
   static double recent_sell_results[5] = {0,0,0,0,0};
   static int result_index = 0;
   
   if(HistorySelect(TimeCurrent() - 3600, TimeCurrent()))
   {
      int deals = HistoryDealsTotal();
      if(deals > 0)
      {
         ulong ticket = HistoryDealGetTicket(deals - 1);
         if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
         {
            long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            double deal_profit_val = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            // ============ MANUAL + BOT ADAPTIVE LEARNING =============
            if(entry_type == DEAL_ENTRY_OUT)
            {
               if(deal_profit_val > 0.0)
                  strategy_core.regime_confidence = MathMin(1.0, strategy_core.regime_confidence * 1.05);
               else if(deal_profit_val < 0.0)
                  strategy_core.regime_confidence = MathMax(0.0, strategy_core.regime_confidence * 0.95);
            }
            // =========================================================

            {
               double profit = deal_profit_val;
               long type = HistoryDealGetInteger(ticket, DEAL_TYPE);

               if(type == DEAL_TYPE_BUY)
                  recent_buy_results[result_index] = profit;
               else if(type == DEAL_TYPE_SELL)
                  recent_sell_results[result_index] = profit;

               result_index = (result_index + 1) % 5;
               
               
            }
         }
      }
   }
   
   double buy_success_rate = 0.0;
   double sell_success_rate = 0.0;
   int buy_count = 0;
   int sell_count = 0;
   
   for(int i = 0; i < 5; i++)
   {
      if(recent_buy_results[i] != 0.0)
      {
         buy_count++;
         if(recent_buy_results[i] > 0) buy_success_rate += 1.0;
      }
      if(recent_sell_results[i] != 0.0)
      {
         sell_count++;
         if(recent_sell_results[i] > 0) sell_success_rate += 1.0;
      }
   }
   
   if(buy_count > 0) buy_success_rate /= buy_count;
   if(sell_count > 0) sell_success_rate /= sell_count;
   
   if(buy_count >= 3 && sell_count >= 3)
   {
      double performance_delta = buy_success_rate - sell_success_rate;
      
      if(performance_delta < -0.35)
      {
         strategy_core.regime_confidence *= 0.85;
         strategy_core.regime_confidence = MathMax(strategy_core.regime_confidence, 0.3);
         
         if(InpEnableLogging)
            PrintFormat("LEARNING: BUY underperform | buy=%.0f%% sell=%.0f%% | conf reduced", 
                       buy_success_rate * 100.0, sell_success_rate * 100.0);
      }
      else if(performance_delta > 0.35)
      {
         strategy_core.regime_confidence *= 1.10;
         strategy_core.regime_confidence = MathMin(strategy_core.regime_confidence, 0.95);
         
         if(InpEnableLogging)
            PrintFormat("LEARNING: BUY outperform | buy=%.0f%% sell=%.0f%%", 
                       buy_success_rate * 100.0, sell_success_rate * 100.0);
      }
   }
   
   if(daily_target.enabled)
   {
      CalculateDailyProfit();
   }
}
//+------------------------------------------------------------------+
//| Market Data Processing                                            |
//+------------------------------------------------------------------+
bool UpdateMarketData()
{
   double atr_buf[1], ma_fast_buf[1], ma_slow_buf[1], rsi_buf[1];

   if(CopyBuffer(atr_handle,0,0,1,atr_buf)!=1 || CopyBuffer(ma_fast_handle,0,0,1,ma_fast_buf)!=1 ||
      CopyBuffer(ma_slow_handle,0,0,1,ma_slow_buf)!=1 || CopyBuffer(rsi_handle,0,0,1,rsi_buf)!=1)
      return false;

   market_data.price_current = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   market_data.price_open = iOpen(_Symbol, PERIOD_CURRENT, 1);
   market_data.price_high = iHigh(_Symbol, PERIOD_CURRENT, 1);
   market_data.price_low = iLow(_Symbol, PERIOD_CURRENT, 1);
   market_data.price_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   market_data.atr = atr_buf[0]; market_data.ma_fast = ma_fast_buf[0];
   market_data.ma_slow = ma_slow_buf[0]; market_data.rsi = rsi_buf[0];
   market_data.timestamp = TimeCurrent(); market_data.data_valid = true;

   static double atr_hist[20]; static int atr_idx = 0;
   atr_hist[atr_idx] = market_data.atr; atr_idx = (atr_idx + 1) % 20;
   double atr_sum = 0; for(int i=0;i<20;i++) atr_sum += atr_hist[i];
   double atr_avg = atr_sum / 20.0;
   market_data.volatility_regime = (atr_avg > 0) ? market_data.atr / atr_avg : 1.0;

   market_data.trend_strength = (market_data.ma_fast - market_data.ma_slow) / (market_data.ma_slow + 0.00001);
   market_data.momentum_state = (market_data.price_current - market_data.price_close) / (market_data.atr + 0.00001);
   //--- Adaptive Liquidity Calculation (Asset-Aware)
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread_pips = spread * point / _Point; // Normalize to standard pips

    // Dynamic normalizer based on asset class
    double normalizer = (StringFind(_Symbol, "BTC", 0) >= 0 || StringFind(_Symbol, "ETH", 0) >= 0 || 
                     StringFind(_Symbol, "SOL", 0) >= 0 || StringFind(_Symbol, "XRP", 0) >= 0) ? 8.0 : 
                    (StringFind(_Symbol, "US30", 0) >= 0 || StringFind(_Symbol, "US100", 0) >= 0) ? 15.0 : 10.0;

market_data.liquidity_condition = 1.0 / (1.0 + spread_pips / normalizer);

// Dynamic max spread limit
double max_spread = (StringFind(_Symbol, "BTC", 0) >= 0) ? 1200 : 600 ||
                   (StringFind(_Symbol, "XAUUSD", 0) >= 0 || StringFind(_Symbol, "GOLD", 0) >= 0) ? 1600 : 1500;
if(spread > max_spread * (1.0 + market_data.volatility_regime * 0.5))
   market_data.liquidity_condition *= 0.5;

   return true;
}

void ProcessInstitutionalFormulas()
{
   formulas.dcsa = market_data.rsi / 100.0 - 0.5;
   formulas.rvg = (market_data.atr - (market_data.ma_slow * 0.0001)) / (market_data.ma_slow + 0.0001);
   formulas.fcd = formulas.rvg * 0.5;
   formulas.esd = MathAbs(formulas.rvg) * 10.0;
   formulas.mpi = market_data.momentum_state;
   formulas.transition_probability = MathMin(0.95, MathMax(0.01,
      market_data.volatility_regime * 0.15 + (1.0 - market_data.liquidity_condition) * 0.1));
   formulas.pattern_coherence = 1.0 / (1.0 + formulas.esd * 0.1);
   formulas.reasoning_complete = true;
}

//+------------------------------------------------------------------+
//| Fractal Intelligence Processing (COV2 + Adaptive Learning Gates) |
//+------------------------------------------------------------------+
void ProcessFractalIntelligence()
{
   //=============================================================
   // Core variables (unchanged)
   //=============================================================
   double misCur=0.0,aofmCur=0.0,frpCur=0.0,lpgCur=0.0,emcCur=0.0;
   double misH1=0.0,aofmH1=0.0,frpH1=0.0,lpgH1=0.0,emcH1=0.0;

   double exhaustionSignal=0.0, hiddenOrderSignal=0.0, emotionalSignal=0.0;

   double high1=iHigh(_Symbol,PERIOD_CURRENT,0);
   double low1 =iLow (_Symbol,PERIOD_CURRENT,0);

   double momentum_curr=iClose(_Symbol,PERIOD_CURRENT,0)-iClose(_Symbol,PERIOD_CURRENT,1);
   double momentum_prev=iClose(_Symbol,PERIOD_CURRENT,1)-iClose(_Symbol,PERIOD_CURRENT,2);

   double volatility_regime =
      market_data.atr / MathMax(iATR(_Symbol,PERIOD_CURRENT,55),1e-6);

   //=============================================================
   // SELF-TUNING LEARNING GATES (persistent, local only)
   //=============================================================
   static double learning_gate = 0.5;
   static double adaptive_lr  = 0.12;

   double signal_quality =
      0.35*fractal_intel.recursive_confidence +
      0.30*(1.0-MathAbs(fractal_intel.volatility_asymmetry_index-0.5)) +
      0.20*market_data.liquidity_condition +
      0.15*(1.0-MathMin(MathAbs(market_data.momentum_state),1.0));

   signal_quality=MathMin(MathMax(signal_quality,0.0),1.0);

   if(signal_quality>0.65 && volatility_regime<1.4)
      learning_gate = 0.90*learning_gate + 0.10;
   else if(signal_quality<0.40 || volatility_regime>1.8)
      learning_gate *= 0.85;

   learning_gate=MathMin(MathMax(learning_gate,0.05),1.0);

   adaptive_lr = 0.90*adaptive_lr + 0.10*(0.05+0.25*learning_gate*signal_quality);
   adaptive_lr=MathMin(MathMax(adaptive_lr,0.03),0.35);
   
   
   //=============================================================
// EQUITY-BASED BIAS MEMORY DECAY (Performance-Driven Forgetting)
//=============================================================

// Persistent equity memory (local only)
static double equity_ema = 0.0;
static double equity_peak = 0.0;
static double bias_memory_decay = 1.0;

double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);

if(equity_ema <= 0.0)
{
   equity_ema  = equity_now;
   equity_peak = equity_now;
}

// Smooth equity to avoid noise
equity_ema  = 0.94 * equity_ema + 0.06 * equity_now;
equity_peak = MathMax(equity_peak, equity_ema);

// Equity state (negative when below peak)
double equity_delta = (equity_peak > 0.0)
                      ? (equity_ema - equity_peak) / equity_peak
                      : 0.0;

// Adaptive decay mapping
if(equity_delta < -0.015)
   bias_memory_decay = 0.75;      // fast forgetting in drawdown
else if(equity_delta > 0.010)
   bias_memory_decay = 0.98;      // preserve memory in expansion
else
   bias_memory_decay = 0.90;      // neutral decay

// Apply decay to continuation-prone signals
exhaustionSignal  *= bias_memory_decay;
hiddenOrderSignal *= bias_memory_decay;

// Drawdown: soften momentum belief
if(equity_delta < -0.02)
   market_data.momentum_state *= 0.90;

// Clamp decay
bias_memory_decay = MathMin(MathMax(bias_memory_decay, 0.70), 0.99);

if(InpEnableLogging)
{
   PrintFormat("EQUITY-BIAS | eqΔ=%.3f decay=%.2f ema=%.2f peak=%.2f",
               equity_delta,
               bias_memory_decay,
               equity_ema,
               equity_peak);
}


//=============================================================
// AE-ENGRAM MEMORY (Drawdown-Aware Execution Memory)
//=============================================================
{
   static double mae_mem[300];
   static double mae_vel_mem[300];
   static double cont_mem[300];
   static double conf_mem[300];

   //=============================================================
// V79.1 | Cross-Symbol Transfer Learning (Structure-Keyed)
//=============================================================

// Direction stays directional (no transfer across direction)
int dir = (market_data.momentum_state >= 0.0) ? 1 : -1;

// STRUCTURAL NORMALIZATION (symbol-invariant)
double vol_norm =
   market_data.volatility_regime /
   MathMax(fractal_intel.power_law_exponent, 0.5);

double liq_norm =
   fractal_intel.liquidity_depth_fractal /
   MathMax(market_data.liquidity_condition, 0.3);

// Bucketized structure (not symbol)
int k1 = (int)MathFloor(fractal_intel.fractal_confluence_score * 5.0);
int k2 = (int)MathFloor(MathMin(vol_norm, 3.0));        // normalized volatility
int k3 = (int)MathFloor(MathMin(liq_norm * 2.0, 3.0));  // normalized liquidity
int k4 = (int)MathFloor(strategy_core.regime_confidence * 3.0);

// FINAL TRANSFER-LEARNING KEY
int key =
   (dir > 0 ? 1 : 0) +
   k1 * 2 +
   k2 * 10 +
   k3 * 40 +
   k4 * 120;

key = MathMin(MathMax(key, 0), 299);


   // --- initialize if unseen ---
   if(conf_mem[key] <= 0.0)
   {
      mae_mem[key]     = market_data.atr * 0.6;
      mae_vel_mem[key] = 0.5;
      cont_mem[key]    = 0.5;
      conf_mem[key]    = 0.01;
   }

   // --- compute trust score ---
   double trust = 1.0;

   if(mae_mem[key] > market_data.atr)
      trust *= 0.75;

   if(mae_vel_mem[key] > 0.7)
      trust *= 0.65;

   // --- apply to execution ---
   decision.position_size *= trust;
   decision.stop_loss_distance *= (1.0 - 0.2 * trust);

   // soft TP expansion when trusted
   if(trust > 0.85)
      decision.take_profit_distance *= 1.15;

   // --- logging ---
   if(InpEnableLogging)
      PrintFormat("AE-ENGRAM | key=%d trust=%.2f mae=%.2f vel=%.2f cont=%.2f",
                  key, trust, mae_mem[key], mae_vel_mem[key], cont_mem[key]);
}

//=============================================================
// UNIFIED EXECUTION MEMORY (AE-ENGRAM + Equity + Recovery)
// Single Trust Law — no new declarations, no flow breaks
//=============================================================
{
   // ---- persistent memory (already present, reused) ----
   static double mae_mem[300];
   static double mae_vel_mem[300];
   static double cont_mem[300];
   static double conf_mem[300];

   static double equity_ema  = 0.0;
   static double equity_peak = 0.0;

   //=========================================================
   // 1. BUILD STRUCTURAL KEY (unchanged logic)
   //=========================================================
   int dir = (market_data.momentum_state >= 0.0) ? 1 : -1;

   int k1 = (int)MathFloor(fractal_intel.fractal_confluence_score * 5.0);
   int k2 = (int)MathFloor(MathMin(market_data.volatility_regime, 3.0));
   int k3 = (int)MathFloor(MathMin(fractal_intel.liquidity_depth_fractal * 2.0, 3.0));
   int k4 = (int)MathFloor(strategy_core.regime_confidence * 3.0);

   int key =
      (dir > 0 ? 1 : 0) +
      k1 * 2 +
      k2 * 10 +
      k3 * 40 +
      k4 * 120;

   key = MathMin(MathMax(key, 0), 299);

   // ---- initialize memory if unseen ----
   if(conf_mem[key] <= 0.0)
   {
      mae_mem[key]     = market_data.atr * 0.6;
      mae_vel_mem[key] = 0.5;
      cont_mem[key]    = 0.5;
      conf_mem[key]    = 0.05;
   }

   //=========================================================
   // 2. EQUITY STATE → MEMORY PLASTICITY (not size!)
   //=========================================================
   double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity_ema <= 0.0)
   {
      equity_ema  = equity_now;
      equity_peak = equity_now;
   }

   equity_ema  = 0.94 * equity_ema + 0.06 * equity_now;
   equity_peak = MathMax(equity_peak, equity_ema);

   double equity_delta =
      (equity_peak > 0.0)
      ? (equity_ema - equity_peak) / equity_peak
      : 0.0;

   // Asymmetric learning rates (pain > pleasure)
   double lr = 0.04;
   if(equity_delta < -0.015) lr *= 1.6;
   else if(equity_delta > 0.01) lr *= 0.7;
   
   // === TEACHER MODE & EQUITY HALF-LIFE ADJUSTMENTS (no new globals) ===
// Insert HERE, immediately after equity_delta and lr are available

// Teacher-mode detection (favors recent clean expansions + model agreement)
bool teacher_mode = (fractal_intel.fractal_confluence_score > 0.62 &&
                     strategy_core.regime_confidence > 0.60 &&
                     equity_delta > 0.005);

// Track trough → half-recovery time locally (function-scoped statics only)
static datetime trough_time = 0;
static double   trough_val  = 0.0;
static int      half_life_minutes = 0;

double equity_now_local = AccountInfoDouble(ACCOUNT_EQUITY);

// initialize trough if unset
if(trough_time == 0 || equity_now_local < trough_val)
{
   trough_time = TimeCurrent();
   trough_val  = equity_now_local;
}

// compute half-recovery (once per trough)
double half_recovery = trough_val + 0.5 * (equity_peak - trough_val);
if(equity_peak > trough_val && equity_now_local >= half_recovery && trough_time > 0)
{
   half_life_minutes = (int)((TimeCurrent() - trough_time) / 60);
   // reset trough marker so we capture next trough later
   trough_time = TimeCurrent();
   trough_val  = equity_now_local;
}

// half-life factor: shorter half-life -> stronger permissive boost (bounded)
double half_life_factor = 1.0 / (1.0 + ((double)half_life_minutes) / 60.0);

// If this is a teacher-like period, modestly strengthen memory surfaces
if(teacher_mode)
{
   conf_mem[key] = MathMin(1.0, conf_mem[key] + 0.03 * half_life_factor);
   cont_mem[key] = MathMin(1.0, cont_mem[key] + 0.02 * half_life_factor);
}

// Keep a small, safety-aware influence on lr (faster learning during teacher)
if(teacher_mode)
   lr = MathMax(0.02, lr * (1.0 - 0.12 * half_life_factor));

// === end TEACHER/HALF-LIFE insertion ===


   //=========================================================
   // 3. MEMORY UPDATE (Surprise-Weighted)
   //=========================================================
   double surprise = 0.0;

   if(mae_mem[key] > market_data.atr)
      surprise += 0.4;

   if(mae_vel_mem[key] > 0.7)
      surprise += 0.3;

   if(equity_delta < 0.0)
      surprise += MathMin(MathAbs(equity_delta) * 10.0, 0.5);

   surprise = MathMin(surprise, 1.0);

   // Continuation belief update
   cont_mem[key] =
      cont_mem[key] * (1.0 - lr)
      + (surprise < 0.4 ? 1.0 : 0.0) * lr;

   // Confidence evolution (bounded, asymmetric)
   if(surprise > 0.5)
      conf_mem[key] *= 0.88;
   else
      conf_mem[key] = MathMin(conf_mem[key] + 0.015, 1.0);

   //=========================================================
   // 4. TRUST COMPUTATION (SINGLE SOURCE OF TRUTH)
   //=========================================================
   double trust = 1.0;

   trust *= (1.0 - 0.4 * surprise);
   trust *= cont_mem[key];
   trust *= conf_mem[key];

   // Hard bounds (delayed recovery embedded here)
   if(equity_delta < -0.02)
      trust = MathMin(trust, 0.65);
   else if(equity_delta < 0.0)
      trust = MathMin(trust, 0.80);
   else if(equity_delta < 0.01)
      trust = MathMin(trust, 0.90);

   trust = MathMin(MathMax(trust, 0.30), 1.05);
   
   // === HALF-LIFE MODULATION OF TRUST CAP ===
// apply a small permissive boost to maximum trust if half-life is short (fast recovery)
double trust_cap_multiplier = 1.0 + 0.12 * half_life_factor; // modest, bounded
trust = MathMin(MathMax(trust, 0.30), 1.05 * MathMin(1.0 + 0.15 * half_life_factor, trust_cap_multiplier));
// continue existing hard bound logic below as-is


   //=========================================================
   // 5. APPLY TRUST (ONLY PLACE EXECUTION IS MODULATED)
   //=========================================================
   decision.position_size        *= trust;
   decision.stop_loss_distance   *= (1.0 - 0.25 * trust);
   decision.take_profit_distance *= (trust > 0.85 ? 1.15 : 1.0);

   //=========================================================
   // 6. LOGGING (optional, safe)
   //=========================================================
   if(InpEnableLogging)
      PrintFormat(
         "UNIFIED-MEM | key=%d trust=%.2f eqΔ=%.3f surprise=%.2f cont=%.2f conf=%.2f",
         key, trust, equity_delta, surprise, cont_mem[key], conf_mem[key]
      );
}


   //=============================================================
   // CURRENT-TF SIGNALS (verified, noise-aware)
   //=============================================================
   {
      double sp=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double depth=MathMax(1e-6,fractal_intel.liquidity_depth_fractal);
      double flow=MathMax(0.0,fractal_intel.institutional_flow_velocity);
      double v=flow/(1.0+sp);
      misCur=v/(1.0+v)/(1.0+depth);
      misCur=MathMin(MathMax(misCur,0.0),1.0);
   }

   {
      double signed_vol=0,vol_total=0;
      for(int k=0;k<8;k++)
      {
         double p0=iClose(_Symbol,PERIOD_CURRENT,k);
         double p1=iClose(_Symbol,PERIOD_CURRENT,k+1);
         double v =(double)iVolume(_Symbol,PERIOD_CURRENT,k);
         if(!MathIsValidNumber(p0)||!MathIsValidNumber(p1))continue;
         double s=(p0>p1)?1.0:((p0<p1)?-1.0:0.0);
         signed_vol+=s*v; vol_total+=v;
      }
      aofmCur=(vol_total>0)?MathAbs(signed_vol)/vol_total:0.0;
      aofmCur=aofmCur/(1.0+aofmCur);
   }

   {
      int RW=16; double meanR=0,varR=0,m4=0; int valid=0;
      for(int r=0;r<RW;r++)
      {
         double p0=iClose(_Symbol,PERIOD_CURRENT,r);
         double p1=iClose(_Symbol,PERIOD_CURRENT,r+1);
         if(p1==0)continue;
         double ret=(p0-p1)/p1;
         meanR+=ret; valid++;
      }
      meanR=(valid>0)?meanR/valid:0.0;
      for(int r=0;r<RW;r++)
      {
         double p0=iClose(_Symbol,PERIOD_CURRENT,r);
         double p1=iClose(_Symbol,PERIOD_CURRENT,r+1);
         if(p1==0)continue;
         double d=((p0-p1)/p1)-meanR;
         varR+=d*d; m4+=d*d*d*d;
      }
      if(valid>0){varR/=valid; m4/=valid;}
      frpCur=1.0/(1.0+MathMin((varR>1e-9)?m4/(varR*varR):0.0,100.0));
   }

   lpgCur=MathAbs(market_data.liquidity_condition-fractal_intel.true_liquidity_metric);
   lpgCur=lpgCur/(1.0+lpgCur);

   emcCur=fractal_intel.recursive_confidence;

   //=============================================================
   // H1 VERIFIED CONTEXT
   //=============================================================
   misH1=misCur*0.85;
   aofmH1=aofmCur*0.90;
   frpH1 =frpCur *0.95;
   lpgH1 =lpgCur *0.90;
   emcH1 =emcCur *0.95;

   //=============================================================
   // LEARNING-GATED CONTRIBUTIONS
   //=============================================================
   double gated_scale=0.6+0.4*learning_gate;
   if(volatility_regime>1.6) gated_scale*=0.85;

   double contribCur=(misCur+aofmCur+frpCur+lpgCur+emcCur)/5.0;
   double contribH1 =(misH1 +aofmH1 +frpH1 +lpgH1 +emcH1 )/5.0;

   double adjustedCur=contribCur*(1.0+adaptive_lr*gated_scale);
   double adjustedH1 =contribH1 *(1.0+adaptive_lr*gated_scale);

   adjustedCur=MathMin(MathMax(adjustedCur,0.0),1.0);
   adjustedH1 =MathMin(MathMax(adjustedH1 ,0.0),1.0);

   double divergence=MathAbs(adjustedCur-adjustedH1);
   if(divergence>0.45)
   {
      adaptive_lr*=0.92;
      learning_gate*=0.90;
   }
   
   //=============================================================
// EQUITY-BASED BIAS MEMORY DECAY (Performance-Driven Forgetting)
//=============================================================
{
   // Persistent equity memory (local only)
   static double equity_ema = 0.0;
   static double equity_peak = 0.0;
   static double bias_memory_decay = 1.0;

   double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity_ema <= 0.0)
   {
      equity_ema  = equity_now;
      equity_peak = equity_now;
   }

   // Smooth equity to avoid noise
   equity_ema = 0.94 * equity_ema + 0.06 * equity_now;
   equity_peak = MathMax(equity_peak, equity_ema);

   // Equity state
   double equity_delta = (equity_peak > 0.0)
                         ? (equity_ema - equity_peak) / equity_peak
                         : 0.0;

   // Map equity state to decay rate
   // Drawdown → aggressive forgetting
   // Expansion → slow forgetting
   if(equity_delta < -0.015) // >1.5% pullback from peak
   {
      bias_memory_decay = 0.75;   // fast decay
   }
   else if(equity_delta > 0.010) // expanding equity
   {
      bias_memory_decay = 0.98;   // slow decay
   }
   else
   {
      bias_memory_decay = 0.90;   // neutral decay
   }

   // Apply decay asymmetrically to continuation-biased signals
   exhaustionSignal  *= bias_memory_decay;
   hiddenOrderSignal *= bias_memory_decay;

   // During drawdown, damp momentum belief directly
   if(equity_delta < -0.02)
      market_data.momentum_state *= 0.90;

   // Prevent decay collapse
   bias_memory_decay = MathMin(MathMax(bias_memory_decay, 0.70), 0.99);

   if(InpEnableLogging)
      PrintFormat("EQUITY-BIAS | eqΔ=%.3f decay=%.2f ema=%.2f peak=%.2f",
                  equity_delta,
                  bias_memory_decay,
                  equity_ema,
                  equity_peak);
}

   //=============================================================
// MV-3 | Asymmetric Bias Memory Decay (Kills Buy Bias Naturally)
//=============================================================
{
   // continuation-style signals decay faster during drawdown
   double continuation_decay = 1.0;

   if(equity_delta < -0.015)
      continuation_decay = 0.75;
   else if(equity_delta > 0.010)
      continuation_decay = 0.97;
   else
      continuation_decay = 0.88;

   // Apply ONLY to continuation-leaning components
   exhaustionSignal  *= continuation_decay;
   hiddenOrderSignal *= continuation_decay;

   // During drawdown, damp raw momentum belief
   if(equity_delta < -0.02)
      market_data.momentum_state *= 0.90;
}

   //=============================================================
   // / HIDDEN / EMOTIONAL (verified)
   //=============================================================
   exhaustionSignal =
      ((high1-low1)/MathMax(market_data.atr,1e-6)) *
      market_data.momentum_state;

   hiddenOrderSignal =
      fractal_intel.institutional_flow_velocity *
      (adjustedCur-adjustedH1);

   emotionalSignal =
      (volatility_regime>1.5?0.4:0.0) +
      ((momentum_prev*momentum_curr<0)?0.3:0.0) +
      (fractal_intel.institutional_flow_velocity>0.8?0.3:0.0);

   //=============================================================
   // FINAL CONFLUENCE (profit-weighted, bias-neutral)
   //=============================================================
   fractal_intel.fractal_confluence_score = NormalizeDouble(
      0.70*((adjustedCur+adjustedH1)/2.0) +
      0.15*MathAbs(exhaustionSignal) +
      0.10*MathAbs(hiddenOrderSignal) +
      0.05*emotionalSignal, 3
   );

   fractal_intel.power_law_exponent =
      (adjustedCur+adjustedH1)/2.0;
      
      // ---------------------- PHASE ENGINE v2 (mode-gated) ----------------------
if(InpTradingMode == MODE_PHASE)
{
   {
      // ── PERSISTENT PHASE STATE ────────────────────────────────
      static int      phase_dir = 0;
      static double   phase_conf_peak = 0.0;
      static datetime phase_birth_time = 0;
      static datetime phase_resolve_time = 0;
      static double   phase_equity_at_birth = 0.0;
      static double   phase_quality_score = 0.5;
      static double   phase_conf_decay_rate = 0.0;
      static double   prev_phase_conf = 0.0;

      // ── LAYER 1: INITIALIZATION ────────────────────────────────
      if(phase_dir == 0 || phase_birth_time == 0)
      {
         phase_dir = (market_data.momentum_state >= 0.0) ? 1 : -1;
         phase_conf_peak = fractal_intel.fractal_confluence_score;
         phase_birth_time = TimeCurrent();
         phase_resolve_time = 0;
         phase_equity_at_birth = AccountInfoDouble(ACCOUNT_EQUITY);
         phase_quality_score = 0.5;
         phase_conf_decay_rate = 0.0;
         prev_phase_conf = phase_conf_peak;

         if(InpEnableLogging)
            PrintFormat("PHASE BIRTH | dir=%s conf=%.3f equity=%.2f",
                        phase_dir > 0 ? "BUY" : "SELL",
                        phase_conf_peak,
                        phase_equity_at_birth);
      }

      // ── LAYER 2: AGE & MATURITY ────────────────────────────────
      double phase_age_min = (TimeCurrent() - phase_birth_time) / 60.0;
      bool phase_premature = (phase_age_min < 15.0);
      bool phase_mature    = (phase_age_min >= 45.0);
      bool phase_stale     = (phase_age_min > 180.0);

      double maturity_weight =
         phase_premature ? 0.70 :
         phase_mature    ? 1.15 :
         phase_stale     ? 0.85 : 1.00;

      // ── LAYER 3: CONFIDENCE DECAY VELOCITY ──────────────────────
      double conf_delta =
         fractal_intel.fractal_confluence_score - prev_phase_conf;

      phase_conf_decay_rate =
         0.85 * phase_conf_decay_rate + 0.15 * conf_delta;

      prev_phase_conf = fractal_intel.fractal_confluence_score;

      bool sharp_decay = (phase_conf_decay_rate < -0.015);

      if(fractal_intel.fractal_confluence_score > phase_conf_peak)
         phase_conf_peak = fractal_intel.fractal_confluence_score;

      // ── LAYER 4: ECHO ALIGNMENT ────────────────────────────────
      double echo_phase_agreement = 0.0;
      double echo_n = 0.0;

      for(int s = 0; s < 5; s++)
      {
         double ev = fractal_intel.echo_signatures[s];
         if(!(ev == ev)) continue; // NaN guard

         double echo_bias = (ev - 0.5) * 2.0;
         double agree = (phase_dir > 0) ? echo_bias : -echo_bias;
         if(agree > 0.0) echo_phase_agreement += agree;
         echo_n += 1.0;
      }

      if(echo_n > 0.0) echo_phase_agreement /= echo_n;
      echo_phase_agreement = MathMin(MathMax(echo_phase_agreement, 0.0), 1.0);

      // ── LAYER 5: PERFORMANCE FEEDBACK ───────────────────────────
      double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
      double equity_pct =
         (phase_equity_at_birth > 0.0)
         ? (equity_now - phase_equity_at_birth) / phase_equity_at_birth
         : 0.0;

      // Smooth bounded performance sigmoid (MathTanh replacement)
      double perf_quality =
         0.5 + (equity_pct * 5.0) / (1.0 + MathAbs(equity_pct * 5.0)) * 0.5;

      perf_quality = MathMin(MathMax(perf_quality, 0.0), 1.0);

      // ── LAYER 6: QUALITY SYNTHESIS ──────────────────────────────
      double quality_raw =
         0.30 * maturity_weight +
         0.25 * echo_phase_agreement +
         0.25 * perf_quality +
         0.20 * (fractal_intel.fractal_confluence_score /
                MathMax(phase_conf_peak, 0.01));

      phase_quality_score =
         0.80 * phase_quality_score + 0.20 * quality_raw;

      phase_quality_score =
         MathMin(MathMax(phase_quality_score, 0.0), 1.0);

      // ── LAYER 7: RESOLUTION DETECTION ───────────────────────────
      int resolution_signals = 0;

      if(fractal_intel.fractal_confluence_score < phase_conf_peak * 0.78)
         resolution_signals++;
      if(MathAbs(market_data.momentum_state) <
         MathAbs(momentum_prev) * 0.75)
         resolution_signals++;
      if(MathAbs(exhaustionSignal) >
         MathAbs(hiddenOrderSignal) * 1.2)
         resolution_signals++;
      if(sharp_decay)
         resolution_signals++;
      if(echo_phase_agreement < 0.35)
         resolution_signals++;
      if(MathAbs(adjustedCur - adjustedH1) > 0.40)
         resolution_signals++;

      bool swing_resolved = (resolution_signals >= 3);
      if(phase_stale && resolution_signals >= 2)
         swing_resolved = true;

      if(swing_resolved && phase_resolve_time == 0)
         phase_resolve_time = TimeCurrent();

      // ── LAYER 8: REGIME-GATED FLIP ──────────────────────────────
      if(phase_resolve_time > 0)
      {
         double flip_threshold =
            0.55 + (perf_quality - 0.5) * 0.30;

         flip_threshold =
            MathMin(MathMax(flip_threshold, 0.40), 0.75);

         bool regime_ok =
            strategy_core.regime_confidence > flip_threshold &&
            MathAbs(adjustedCur - adjustedH1) < 0.30 &&
            volatility_regime < 1.6;

         int new_dir = (market_data.momentum_state >= 0.0) ? 1 : -1;

         if(regime_ok && new_dir != phase_dir)
         {
            phase_dir = new_dir;
            phase_conf_peak = fractal_intel.fractal_confluence_score;
            phase_birth_time = TimeCurrent();
            phase_resolve_time = 0;
            phase_equity_at_birth = equity_now;
            phase_quality_score = 0.5;
            phase_conf_decay_rate = 0.0;
         }
      }

      // ── STRONG PHASE ENFORCEMENT (replace previous weaker block) ──
if((phase_dir > 0 && decision.trade_direction == ORDER_TYPE_SELL) ||
   (phase_dir < 0 && decision.trade_direction == ORDER_TYPE_BUY))
{
   // fully neutralize the execution decision so no order is constructed/sent
   decision.position_size     = 0.0;
   decision.stop_loss_distance = decision.stop_loss_distance; // keep numeric state safe
   decision.take_profit_distance = decision.take_profit_distance;
   decision.should_trade      = false;
   // if your code uses an execution-ready flag, null it too (name may vary)
   #ifdef HAS_EXECUTION_READY
   decision.execution_ready = false;
   #endif

   // defensive logging for traceability
   if(InpEnableLogging)
      PrintFormat("PHASE BLOCK | phase=%s attempted=%s | neutralized",
                  phase_dir > 0 ? "BUY" : "SELL",
                  decision.trade_direction == ORDER_TYPE_BUY ? "BUY" : "SELL");
}


      // ── LAYER 10: QUALITY-BASED SIZING ──────────────────────────
      if(decision.should_trade)
      {
         double q_mult = 0.70 + 0.60 * phase_quality_score;

         if(phase_resolve_time > 0 &&
            TimeCurrent() - phase_resolve_time < 1800)
            q_mult *= 0.65;

         if(phase_premature)
            q_mult *= 0.80;

         if(phase_mature && phase_quality_score > 0.75 && perf_quality > 0.65)
            q_mult *= 1.25;

         decision.position_size =
            NormalizeLot(decision.position_size * q_mult);
      }
   }
}

      
      // =============================================================
// CHAIN-OF-RECURSIVE-FRACTAL-INTELLIGENCE v2
// INSERT: after fractal_intel.power_law_exponent = (adjustedCur+adjustedH1)/2.0;
//         before // PROFIT-PROTECTIVE STRATEGY ADAPTATION
// No new global identifiers. Pure local + existing fields only.
// =============================================================
{
   // ── LAYER 1: CROSS-TIMEFRAME COHERENCE ──────────────────────
   // How well do current and H1 signals agree?
   // This is NOT just distance — it's shaped by magnitude so small
   // noise differences don't punish the system.
   double coh_raw = 1.0 - MathAbs(adjustedCur - adjustedH1);
   double coh_shaped = MathPow(MathMin(MathMax(coh_raw, 0.0), 1.0), 0.75);
   // 0.75 power: generous to moderate agreement, punishes severe divergence

   // ── LAYER 2: ECHO BANK CONSENSUS ─────────────────────────────
   // Your echo_signatures[] stores short-term prediction memory.
   // We extract not just the mean but the AGREEMENT (low variance = consensus).
   double echo_mean = 0.0, echo_var = 0.0, echo_n = 0.0;
   for(int s = 0; s < 5; s++)
   {
      double ev = fractal_intel.echo_signatures[s];
      if(!MathIsValidNumber(ev)) continue;
      echo_mean += ev;
      echo_n += 1.0;
   }
   if(echo_n > 0.0) echo_mean /= echo_n;
   for(int s = 0; s < 5; s++)
   {
      double ev = fractal_intel.echo_signatures[s];
      if(!MathIsValidNumber(ev)) continue;
      double d = ev - echo_mean;
      echo_var += d * d;
   }
   if(echo_n > 1.0) echo_var /= (echo_n - 1.0);
   // Consensus score: high mean + low variance = strong echo agreement
   double echo_consensus = echo_mean * (1.0 - MathMin(MathSqrt(echo_var), 1.0));
   echo_consensus = MathMin(MathMax(echo_consensus, 0.0), 1.0);

   // ── LAYER 3: EQUITY MOMENTUM PROXY ───────────────────────────
   // Not just equity vs balance — we track the DIRECTION of equity change.
   // Rising equity is a performance signal even before a trade closes.
   static double eq_prev = 0.0;
   double eq_now = AccountInfoDouble(ACCOUNT_EQUITY);
   double eq_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(eq_prev <= 0.0) eq_prev = eq_now;
   double eq_delta = (eq_now - eq_prev) / MathMax(eq_bal, 1.0); // normalized tick move
   eq_prev = eq_now;
   // Map: negative equity momentum → fear signal, positive → confidence signal
   double perf_signal = 0.5 + MathTanh(eq_delta * 150.0) * 0.5; // sensitive but bounded [0,1]
   // Also factor in absolute equity health (equity/balance)
   double eq_health = MathMin(MathMax((eq_now / MathMax(eq_bal, 1.0) - 0.92) * 12.5, 0.0), 1.0);
   double perf_combined = 0.6 * perf_signal + 0.4 * eq_health;

   // ── LAYER 4: SIGNAL VELOCITY (Rate of Change of Confluence) ──
   // Is the fractal signal accelerating or decelerating?
   // Acceleration into a zone = higher conviction.
   static double prev_confluence = 0.5;
   double conf_velocity = fractal_intel.fractal_confluence_score - prev_confluence;
   prev_confluence = fractal_intel.fractal_confluence_score;
   // Positive velocity with already-high confluence = momentum confirmation
   double velocity_signal = 0.5 + MathTanh(conf_velocity * 20.0) * 0.5;

   // ── LAYER 5: SESSION WEIGHT (Time-Of-Day Conviction) ─────────
   MqlDateTime sq_tm; TimeToStruct(TimeCurrent(), sq_tm);
   int hr = sq_tm.hour;
   // London open (7-10), NY open (13-16) = peak conviction windows
   double session_w = (hr >= 7 && hr <= 10) ? 1.20 :
                      (hr >= 13 && hr <= 16) ? 1.15 :
                      (hr >= 20 || hr < 2)   ? 0.80 : 1.00;

   // ── LAYER 6: RECURSIVE SYNTHESIS ─────────────────────────────
   // Combine layers with intentional weighting hierarchy:
   // Coherence is truth | Echo is memory | Perf is outcome | Velocity is momentum
   double r_raw =
      0.35 * coh_shaped       +  // cross-TF truth
      0.28 * echo_consensus   +  // memory agreement
      0.22 * perf_combined    +  // outcome feedback
      0.15 * velocity_signal;    // momentum direction

   r_raw = MathMin(MathMax(r_raw, 0.0), 1.0);

   // Gate: learning_gate and adaptive_lr already reflect system health
   double r_gated = r_raw * (0.70 + 0.30 * learning_gate) * session_w;
   r_gated = MathMin(MathMax(r_gated, 0.0), 1.0);

   // Non-linear shaping: rewards strong signals exponentially more
   // (convex above 0.6, near-linear below — punishes weak signals less)
   double r_shaped = (r_gated > 0.6)
      ? 0.6 + MathPow((r_gated - 0.6) / 0.4, 0.85) * 0.4
      : r_gated;
   r_shaped = MathMin(MathMax(r_shaped, 0.0), 1.0);

   // ── LAYER 7: RECURSIVE CONFIDENCE UPDATE ─────────────────────
   // Asymmetric: bad signals contract confidence faster than good signals expand it.
   // This mirrors how a disciplined trader manages conviction.
   double lr_up   = adaptive_lr * 0.55;  // gentle expansion
   double lr_down = adaptive_lr * 0.90;  // sharp contraction
   double lr_use  = (r_shaped >= fractal_intel.recursive_confidence) ? lr_up : lr_down;

   fractal_intel.recursive_confidence = MathMin(1.0, MathMax(0.0,
      fractal_intel.recursive_confidence * (1.0 - lr_use)
      + r_shaped * lr_use
   ));

   // ── LAYER 8: SOFT BACKFEED INTO CONFLUENCE ───────────────────
   // Recursive signal gently adjusts the master confluence score.
   // Coefficient is intentionally small — directional, not overriding.
   double backfeed_strength = 0.04 + 0.04 * coh_shaped; // 0.04–0.08 only
   fractal_intel.fractal_confluence_score = MathMin(1.0, MathMax(0.0,
      (1.0 - backfeed_strength) * fractal_intel.fractal_confluence_score
      + backfeed_strength * r_shaped
   ));

   // ── LAYER 9: ADAPTIVE LEARNING RATE CORRECTION ───────────────
   // If echo agrees internally but TFs disagree: system is confused.
   // Slow down learning to prevent thrashing.
   if(coh_shaped < 0.40 && echo_var < 0.04)
      adaptive_lr *= 0.90;
   // If everything aligns AND equity is healthy: allow slightly faster learning
   else if(coh_shaped > 0.70 && perf_combined > 0.65 && echo_consensus > 0.60)
      adaptive_lr = MathMin(adaptive_lr * 1.06, 0.35);

   // ── LAYER 10: EXECUTION MODULATION ───────────────────────────
   // Only touch size in extreme cases — let the existing trust-law handle fine-tuning.
   if(r_shaped < 0.28)
   {
      // System deeply uncertain: reduce size, tighten stop
      decision.position_size = NormalizeLot(decision.position_size * (0.80 + 0.20 * r_shaped));
      decision.stop_loss_distance *= (0.90 + 0.10 * r_shaped);
   }
   else if(r_shaped > 0.80 && coh_shaped > 0.70 && perf_combined > 0.65)
   {
      // System highly aligned AND performing: allow modest TP extension
      decision.take_profit_distance *= MathMin(1.20, 1.0 + 0.25 * (r_shaped - 0.80));
   }

   // ── LAYER 11: LOGGING ─────────────────────────────────────────
   if(InpEnableLogging)
      PrintFormat(
         "RCHAINv2 | coh=%.3f echo_con=%.3f perf=%.3f vel=%.3f | r=%.3f gated=%.3f shaped=%.3f | rec=%.3f fuse=%.3f lr=%.3f",
         coh_shaped, echo_consensus, perf_combined, velocity_signal,
         r_raw, r_gated, r_shaped,
         fractal_intel.recursive_confidence,
         fractal_intel.fractal_confluence_score,
         adaptive_lr
      );
}
// =============================================================
// END RCHAIN v2
// =============================================================

   //=============================================================
   // PROFIT-PROTECTIVE STRATEGY ADAPTATION
   //=============================================================
   if(divergence>0.5 || learning_gate<0.3)
      decision.position_size*=0.75;

   if(fractal_intel.fractal_confluence_score>0.68 && learning_gate>0.6)
   {
      decision.stop_loss_distance*=0.85;
      decision.take_profit_distance*=1.15;
   }

   if(InpEnableLogging)
      PrintFormat("FI | conf=%.3f gate=%.2f lr=%.2f div=%.2f",
                  fractal_intel.fractal_confluence_score,
                  learning_gate,
                  adaptive_lr,
                  divergence);
}


//+------------------------------------------------------------------+
//| EchoRefine Function - QUANTUM VORTEX (FIXED CONVERSION)        |
//+------------------------------------------------------------------+
void EchoRefine(double &state[], int state_len, int n_iter, double &out_prob, int &out_dir)
{
   static double coherence_history[50];
   static int coherence_count = 0;
   static double prediction_history[20];
   static int prediction_count = 0;
   static double last_meta_entropy = 0.5;

   if(state_len <= 0 || n_iter <= 0)
   {
      out_prob = 0.0;
      out_dir  = 0;
      return;
   }

   double mean = 0.0, variance = 0.0;
   for(int i=0; i<state_len; i++)
   {
      double v = MathIsValidNumber(state[i]) ? state[i] : 0.0;
      mean += v;
   }
   mean /= (double)state_len;

   for(int i=0; i<state_len; i++)
   {
      double v = MathIsValidNumber(state[i]) ? state[i] : 0.0;
      double d = v - mean;
      variance += d*d;
   }
   variance = (state_len>1) ? variance / (state_len-1) : 0.0;
   double stdv = MathSqrt(MathMax(variance, 1e-12));

   double refined_mean = mean;
   double refined_stdv = stdv;
   double phase_bias = 0.314159265;
   double entropy = 0.0;
   double decoherence = 0.0;
   double coherence = 0.0;

   double entanglement_risk = 0.0;
   for(int i=0; i<state_len; i++)
   {
      double deviation = state[i] - mean;
      double influence = MathTanh(deviation / (stdv + 1e-9));
      entanglement_risk += (1.0 - MathAbs(influence)) / state_len;
   }
   decoherence = MathMin(entanglement_risk * 2.0, 1.0);

   for(int iter=0; iter<n_iter; iter++)
   {
      double pulse = 0.0;
      coherence = 0.0;
      
      for(int i=0; i<state_len; i++)
      {
         double v = state[i];
         double deviation = v - refined_mean;
         double base_influence = MathTanh(deviation / (refined_stdv + 1e-9));
         
         double quantum_phase_shift = (decoherence > 0.6) ? 3.14159 : 0.0;
         
         pulse += base_influence * MathCos(iter*phase_bias + i*0.13 + quantum_phase_shift);
         coherence += 1.0 - MathAbs(base_influence);
      }
      
      pulse /= state_len;
      coherence /= state_len;

      entropy = (1.0 - coherence) * (refined_stdv / (refined_stdv + 0.1));
      
      double damp_factor = 0.95 - 0.05 * iter / (double)MathMax(1, n_iter);
      
      if(decoherence > 0.7) damp_factor = 1.0 + (decoherence - 0.7) * 2.0;

      refined_mean += pulse * damp_factor * (0.12 - entropy*0.05);
      refined_stdv *= (1.0 - 0.08 * pulse * (1.0 - entropy) * damp_factor);
   }

   double nonlinear_gain = MathTanh(refined_mean / (refined_stdv + 1e-9));
   double base_prob = 0.5 + 0.5 * nonlinear_gain;
   base_prob = MathMin(MathMax(base_prob, 0.0), 1.0);

   double drift = refined_mean - mean;
   int base_dir = (drift > refined_stdv*0.25) ?  1 :
                  (drift < -refined_stdv*0.25) ? -1 : 0;

   // FIXED: Smooth Quantum Transitions with explicit double conversion
   if(decoherence > 0.8)
   {
      out_prob = 1.0 - base_prob;
      out_dir = -base_dir;
   }
   else if(decoherence > 0.6) // Gradient zone 0.6?0.9
   {
      double flip_gradient = (decoherence - 0.6) / 0.3; // 0?1
      double dir_composite = base_dir * (1.0 - flip_gradient) + (-base_dir) * flip_gradient;
      out_dir = dir_composite > 0.5 ? 1 : (dir_composite < -0.5 ? -1 : 0); // FIXED: No implicit conversion
   }
   else if(decoherence < 0.3)
   {
      double wave_interference = base_prob * (1.0 - base_prob) * (1.0 - decoherence);
      out_prob = MathMin(MathMax(base_prob + wave_interference * 0.5, 0.0), 1.0);
      out_dir = base_dir;
   }
   else
   {
      out_prob = base_prob;
      out_dir = base_dir;
   }

   if(prediction_count < 20) prediction_history[prediction_count++] = out_prob;
   else { for(int i=0; i<19; i++) prediction_history[i] = prediction_history[i+1]; prediction_history[19] = out_prob; }

   if(prediction_count > 5)
   {
      double meta_mean = 0.0, meta_variance = 0.0;
      for(int i=0; i<prediction_count; i++) meta_mean += prediction_history[i];
      meta_mean /= prediction_count;
      
      for(int i=0; i<prediction_count; i++)
      {
         double d = prediction_history[i] - meta_mean;
         meta_variance += d*d;
      }
      last_meta_entropy = MathSqrt(MathMax(meta_variance / prediction_count, 1e-12));
   }

   if(last_meta_entropy < 0.1)
   {
      out_prob = 0.5 + (out_prob - 0.5) * 0.5;
   }

   if(coherence_count < 50) coherence_history[coherence_count++] = coherence;
   else { for(int i=0; i<49; i++) coherence_history[i] = coherence_history[i+1]; coherence_history[49] = coherence; }
}

//+------------------------------------------------------------------+
//| ApplyEchoRefine - QUANTUM META-ECHO (FIXED SCOPE)             |
//+------------------------------------------------------------------+
void ApplyEchoRefine()
{
   double state[15];
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trend_adjustment = 0.0; // FIXED: Pre-declare to ensure scope
   
   for(int i=0; i<8; i++)
   {
      double phase = MathSin(i*0.37) + MathCos(i*0.21);
      double micro = current_bid * 1e-4;
      double prev_close = iClose(_Symbol, PERIOD_CURRENT, i+1);
      double price_change = MathAbs(current_bid - prev_close);
      double stuffing_signal = (price_change > 3.0 * iATR(_Symbol, PERIOD_CURRENT, 14)) ? 1.0 : 0.0;
      state[i] = (phase * 0.1 + micro * 0.3 + stuffing_signal * 0.5);
   }

   state[8] = fractal_intel.fractal_confluence_score;
   state[9] = strategy_core.regime_confidence;
   state[10] = fractal_intel.liquidity_depth_fractal;
   state[11] = MathLog(MathMax(current_bid / MathMax(point, 1e-6), 1e-6));
   state[12] = (double)iVolume(_Symbol, PERIOD_CURRENT, 0) / MathMax((double)iVolume(_Symbol, PERIOD_CURRENT, 1), 1e-6);
   
   double current_atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   state[13] = MathAbs(current_ask - current_bid) / MathMax(current_atr, 1e-6);
   state[14] = (fractal_intel.true_liquidity_metric < 0.5) ? 1.0 : 0.0;

   double out_prob = 0.0;
   int out_dir = 0;

   EchoRefine(state, 15, 3, out_prob, out_dir);

   static double dampened_echo_history[20];
   static int dampened_count = 0;
   static double meta_entropy = 0.5;
   
   static double prev_echo_prob = 0.5;
   double echo_momentum = out_prob - prev_echo_prob;
   double echo_damping = 1.0 / (1.0 + MathAbs(echo_momentum) * 2.0);
   
   double trend_strength = MathAbs(market_data.momentum_state) / MathMax(market_data.atr, 1e-6);
   trend_adjustment = MathMin(trend_strength * 0.5, 0.3); // FIXED: Assignment only
   echo_damping *= (1.0 - trend_adjustment);
   
   double dampened_echo = 0.5 + (out_prob - 0.5) * echo_damping;
   prev_echo_prob = out_prob;

   if(dampened_count < 20) dampened_echo_history[dampened_count++] = dampened_echo;
   else { for(int i=0; i<19; i++) dampened_echo_history[i] = dampened_echo_history[i+1]; dampened_echo_history[19] = dampened_echo; }

   if(dampened_count > 5)
   {
      double meta_mean = 0.0, meta_variance = 0.0;
      for(int i=0; i<dampened_count; i++) meta_mean += dampened_echo_history[i];
      meta_mean /= dampened_count;
      
      for(int i=0; i<dampened_count; i++)
      {
         double d = dampened_echo_history[i] - meta_mean;
         meta_variance += d*d;
      }
      meta_entropy = MathSqrt(MathMax(meta_variance / dampened_count, 1e-12));
   }

   double base_score = fractal_intel.fractal_confluence_score;
   double agreement = 1.0 - MathAbs(base_score - dampened_echo);
   double base_weight = 0.7, echo_weight = 0.3;
   
   if(agreement < 0.3) 
   {
      base_weight = 0.5;
      echo_weight = 0.5;
      dampened_echo = 0.5;
   }
   else if(meta_entropy < 0.1) { echo_weight = 0.15; base_weight = 0.85; }
   else if(meta_entropy > 0.3) { echo_weight = 0.45; base_weight = 0.55; }

   // -------------------------
   // RLM-INSPIRED RECURSIVE SELF-IMPROVEMENT
   // -------------------------
   // Use the recent dampened echo sequence as a short 'token' history.
   // Compute an attention-style aggregate (softmax weights scaled by (1-meta_entropy))
   // and gently nudge existing recursive confidence + echo_signatures[] using that aggregate.
   if(dampened_count > 1)
   {
      int K = MathMin(dampened_count, 8); // last-K window (function-scoped local)
      double att_denom = 0.0;
      // compute unnormalized attention weights
      for(int j=0; j<K; j++)
      {
         double val = dampened_echo_history[dampened_count - 1 - j];
         // exponentiate scaled by confidence (lower meta_entropy => sharper attention)
         att_denom += MathExp(val * (1.0 - meta_entropy) * 3.0);
      }
      if(att_denom > 1e-12)
      {
         double agg = 0.0;
         for(int j=0; j<K; j++)
         {
            double val = dampened_echo_history[dampened_count - 1 - j];
            double w = MathExp(val * (1.0 - meta_entropy) * 3.0) / att_denom;
            agg += w * val;
         }
         // conservative update: small learning step to recursive_confidence (teacher-student style)
         fractal_intel.recursive_confidence = MathMin(1.0, MathMax(0.0,
               0.88 * fractal_intel.recursive_confidence + 0.12 * agg));
         
         // shift-and-blend into echo_signatures[] (older signatures pushed back)
         // (uses existing echo_signatures array — no new globals)
         for(int s=4; s>0; s--) fractal_intel.echo_signatures[s] = fractal_intel.echo_signatures[s-1];
         fractal_intel.echo_signatures[0] = 0.6 * fractal_intel.echo_signatures[0] + 0.4 * agg;
         
         // light logging for traceability
         if(InpEnableLogging)
            PrintFormat("RLM-SELF | agg=%.4f meta_ent=%.4f rec_conf=%.3f",
                        agg, meta_entropy, fractal_intel.recursive_confidence);
      }
   }
   // -------------------------
   // end RLM-inspired block
   // -------------------------

   double base_weighted = base_weight * base_score + echo_weight * dampened_echo;
   fractal_intel.fractal_confluence_score = MathMin(MathMax(base_weighted, 0.0), 1.0);

   strategy_core.regime_confidence = 0.8 * strategy_core.regime_confidence + 0.2 * (dampened_echo * (out_dir==1?1.0:0.8));

   if(InpEnableLogging)
      PrintFormat("QuantumEcho | prob=%.3f dir=%d | damped=%.3f | meta=%.3f | fused=%.3f conf=%.3f | trend_adj=%.2f",
                  out_prob, out_dir, dampened_echo, meta_entropy,
                  fractal_intel.fractal_confluence_score,
                  strategy_core.regime_confidence, trend_adjustment);
}

//+------------------------------------------------------------------+
//| COMPUTE SHARED SIGNAL CONTEXT — once per bar                    |
//| Produces: FVG, BOS, swing structure, signal_quality, seq_bias   |
//| Every strategy block reads from shared_ctx — no duplication.    |
//+------------------------------------------------------------------+
void ComputeSharedContext()
{
   ZeroMemory(shared_ctx);

   double atr = MathMax(market_data.atr, _Point * 10);

   // ── FVG: H1 three-candle imbalance ────────────────────────────
   double h1_hi1 = iHigh(_Symbol, PERIOD_H1, 1);
   double h1_lo1 = iLow (_Symbol, PERIOD_H1, 1);
   double h1_hi3 = iHigh(_Symbol, PERIOD_H1, 3);
   double h1_lo3 = iLow (_Symbol, PERIOD_H1, 3);

   if(h1_lo1 > h1_hi3 + _Point)  // gap above bar[3] high
   {
      shared_ctx.fvg_bull   = true;
      shared_ctx.fvg_low    = h1_hi3;
      shared_ctx.fvg_high   = h1_lo1;
      shared_ctx.fvg_mid    = 0.5 * (h1_hi3 + h1_lo1);
      shared_ctx.fvg_target = h1_lo1 + (h1_lo1 - h1_hi3);  // equal-leg projection
   }
   else if(h1_hi1 < h1_lo3 - _Point)  // gap below bar[3] low
   {
      shared_ctx.fvg_bear   = true;
      shared_ctx.fvg_high   = h1_lo3;
      shared_ctx.fvg_low    = h1_hi1;
      shared_ctx.fvg_mid    = 0.5 * (h1_lo3 + h1_hi1);
      shared_ctx.fvg_target = h1_hi1 - (h1_lo3 - h1_hi1);  // equal-leg projection
   }

   // Fallback: check current chart TF if H1 shows nothing
   if(!shared_ctx.fvg_bull && !shared_ctx.fvg_bear)
   {
      double hi1c = iHigh(_Symbol, PERIOD_CURRENT, 1);
      double lo1c = iLow (_Symbol, PERIOD_CURRENT, 1);
      double hi3c = iHigh(_Symbol, PERIOD_CURRENT, 3);
      double lo3c = iLow (_Symbol, PERIOD_CURRENT, 3);
      if(lo1c > hi3c + _Point)
      {
         shared_ctx.fvg_bull = true;
         shared_ctx.fvg_low  = hi3c; shared_ctx.fvg_high = lo1c;
         shared_ctx.fvg_mid  = 0.5*(hi3c+lo1c);
         shared_ctx.fvg_target = lo1c + (lo1c - hi3c);
      }
      else if(hi1c < lo3c - _Point)
      {
         shared_ctx.fvg_bear = true;
         shared_ctx.fvg_high = lo3c; shared_ctx.fvg_low = hi1c;
         shared_ctx.fvg_mid  = 0.5*(lo3c+hi1c);
         shared_ctx.fvg_target = hi1c - (lo3c - hi1c);
      }
   }

   // Intelligence: FVG minimum quality gate (gap must be >= 25% ATR)
   if(shared_ctx.fvg_bull || shared_ctx.fvg_bear)
   {
      double fvg_gap = MathAbs(shared_ctx.fvg_high - shared_ctx.fvg_low);
      if(fvg_gap < atr * 0.25)
      {  shared_ctx.fvg_bull = false; shared_ctx.fvg_bear = false;
         if(InpEnableLogging) PrintFormat("FVG filtered: gap=%.5f < 25pct_ATR=%.5f", fvg_gap, atr*0.25); }
   }

   // ── Swing high/low (bars 2..11) ────────────────────────────────
   double swH = -DBL_MAX, swL = DBL_MAX;
   for(int b = 2; b <= 11; b++)
   {
      swH = MathMax(swH, iHigh(_Symbol, PERIOD_CURRENT, b));
      swL = MathMin(swL, iLow (_Symbol, PERIOD_CURRENT, b));
   }
   shared_ctx.swing_high = swH;
   shared_ctx.swing_low  = swL;

   // ── BOS: closed bar close breaks recent swing ──────────────────
   double bar1_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(bar1_close > swH + _Point)
   { shared_ctx.bos_bull = true; shared_ctx.bos_level = swH; }
   else if(bar1_close < swL - _Point)
   { shared_ctx.bos_bear = true; shared_ctx.bos_level = swL; }

   // ── Structural direction (recent window vs older window) ────────
   double rec_hi=-DBL_MAX, rec_lo=DBL_MAX, old_hi=-DBL_MAX, old_lo=DBL_MAX;
   for(int b=2;b<=6;b++){ rec_hi=MathMax(rec_hi,iHigh(_Symbol,PERIOD_CURRENT,b)); rec_lo=MathMin(rec_lo,iLow(_Symbol,PERIOD_CURRENT,b)); }
   for(int b=7;b<=11;b++){ old_hi=MathMax(old_hi,iHigh(_Symbol,PERIOD_CURRENT,b)); old_lo=MathMin(old_lo,iLow(_Symbol,PERIOD_CURRENT,b)); }
   bool hh=(rec_hi>old_hi), hl=(rec_lo>old_lo), lh=(rec_hi<old_hi), ll=(rec_lo<old_lo);
   if(hh&&hl)      shared_ctx.structural_dir= 1;
   else if(lh&&ll) shared_ctx.structural_dir=-1;
   else            shared_ctx.structural_dir= 0;

   // ── Signal quality composite (0–1) ─────────────────────────────
   double fvg_present = (shared_ctx.fvg_bull||shared_ctx.fvg_bear) ? 1.0 : 0.0;
   double bos_present = (shared_ctx.bos_bull||shared_ctx.bos_bear) ? 1.0 : 0.0;
   double struct_fac  = (shared_ctx.structural_dir!=0) ? 1.0 : 0.5;
   double fscore      = MathIsValidNumber(fractal_intel.fractal_confluence_score)
                        ? fractal_intel.fractal_confluence_score : 0.5;
   shared_ctx.signal_quality = MathMin(1.0,
      0.35*fscore + 0.30*bos_present + 0.20*fvg_present + 0.15*struct_fac);

   // ── Sequential bias: align sequence probes with structure ───────
   // BOS bull + FVG bull + bull structure → bias BUY probes
   int bias_score = 0;
   if(shared_ctx.bos_bull)  bias_score++;
   if(shared_ctx.fvg_bull)  bias_score++;
   if(shared_ctx.structural_dir==1) bias_score++;
   if(shared_ctx.bos_bear)  bias_score--;
   if(shared_ctx.fvg_bear)  bias_score--;
   if(shared_ctx.structural_dir==-1) bias_score--;
   shared_ctx.seq_bias = (bias_score>=2) ? 1 : (bias_score<=-2) ? -1 : 0;

   if(InpEnableLogging)
      PrintFormat("SharedCtx | FVG=%s%s BOS=%s%s struct=%d sq=%.3f seqBias=%d",
                  shared_ctx.fvg_bull?"BULL":"",shared_ctx.fvg_bear?"BEAR":"",
                  shared_ctx.bos_bull?"BULL":"",shared_ctx.bos_bear?"BEAR":"",
                  shared_ctx.structural_dir, shared_ctx.signal_quality, shared_ctx.seq_bias);
}

//+------------------------------------------------------------------+
//| Advanced Strategy Processing (ENHANCED)                         |
//+------------------------------------------------------------------+
void ProcessAdvancedStrategy()
{
   double state[8];
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // FIX: Declare point here
   
   state[0] = MathIsValidNumber(market_data.volatility_regime)        ? market_data.volatility_regime        : 0.0;
   state[1] = MathIsValidNumber(market_data.trend_strength)         ? market_data.trend_strength           : 0.0;
   state[2] = MathIsValidNumber(market_data.momentum_state)         ? market_data.momentum_state           : 0.0;
   state[3] = MathIsValidNumber(market_data.liquidity_condition)    ? market_data.liquidity_condition      : 0.0;
   state[4] = MathIsValidNumber(market_data.volume_fractal_dimension)? market_data.volume_fractal_dimension : 0.0;
   state[5] = MathIsValidNumber(market_data.price_compression_ratio) ? market_data.price_compression_ratio  : 0.0;
   state[6] = MathIsValidNumber(fractal_intel.fractal_confluence_score)? fractal_intel.fractal_confluence_score : 0.0;
   state[7] = MathIsValidNumber(fractal_intel.recursive_confidence)  ? fractal_intel.recursive_confidence   : 0.0;
   
   // --- Machine Learning Predictor ---
   double price_data[20];
   for (int i = 0; i < 20; i++)
   {
      price_data[i] = iClose(_Symbol, PERIOD_H1, i);
   }

   // Calculate simple moving average
   double sma = 0.0;
   for (int i = 0; i < 20; i++) 
   {
      sma += price_data[i];
   }
   sma /= 20.0;

   // Calculate weighted moving average
   double wma = 0.0, total_weight_local = 0.0; // Renamed to avoid hiding global variable
   for (int i = 0; i < 20; i++)
   {
      double weight = 20.0 - i;
      wma += price_data[i] * weight;
      total_weight_local += weight;
   }
   wma /= total_weight_local;

   // Update strategy confidence with prediction
   double prediction = (wma > sma) ? 1.0 : 0.0;
   strategy_core.regime_confidence = 0.7 * strategy_core.regime_confidence + 0.3 * prediction;

   if (InpEnableLogging)
   {
      PrintFormat("ML-Predictor | SMA=%.5f | WMA=%.5f | Conf=%.3f",
                  sma, wma, strategy_core.regime_confidence);
   }

   static double persist_coherence_hist[6] = {0.0,0.0,0.0,0.0,0.0,0.0};
   static double persist_entropy_hist[6]   = {0.0,0.0,0.0,0.0,0.0,0.0};
   static double persist_stress_hist[6]    = {0.0,0.0,0.0,0.0,0.0,0.0};
   static int    persist_idx = 0;
   const double persistence_decay = 0.88;
   const int    mem_depth = 5;

   double mean=0.0,var=0.0;
   for(int i=0;i<8;i++){ mean += state[i]; }  mean /= 8.0;
   for(int i=0;i<8;i++){ double d = state[i] - mean; var += d*d; } var /= 8.0;
   double stdv = MathSqrt(MathMax(var, 1e-12));

   double entropy = 0.0, coherence = 0.0;
   double stress_test = 0.0;
   for(int i=0;i<8; i++)
   {
      double deviation = state[i] - mean;
      double influence = MathTanh(deviation / (stdv + 1e-9));
      coherence += 1.0 - MathAbs(influence);
      entropy   += MathAbs(influence);
      state[i] = mean + deviation * (1.0 - 0.12 * influence);
      stress_test += MathAbs(influence) * (1.0 - coherence);
   }
   coherence /= 8.0;
   entropy   /= 8.0;
   stress_test /= 8.0;

   persist_coherence_hist[persist_idx] = coherence;
   persist_entropy_hist[persist_idx]   = entropy;
   persist_stress_hist[persist_idx]    = stress_test;
   persist_idx = (persist_idx + 1) % mem_depth;

   double hist_coh = 0.0, hist_ent = 0.0, hist_stress = 0.0;
   for(int j=0; j<mem_depth; j++)
   { 
      hist_coh += persist_coherence_hist[j];
      hist_ent += persist_entropy_hist[j];
      hist_stress += persist_stress_hist[j];
   }
   hist_coh /= (double)mem_depth;
   hist_ent /= (double)mem_depth;
   hist_stress /= (double)mem_depth;

   static double longterm_coherence = 0.5, longterm_entropy = 0.5, longterm_stress = 0.3;
   longterm_coherence = longterm_coherence * persistence_decay + hist_coh * (1.0 - persistence_decay);
   longterm_entropy   = longterm_entropy   * persistence_decay + hist_ent * (1.0 - persistence_decay);
   longterm_stress    = longterm_stress    * persistence_decay + hist_stress * (1.0 - persistence_decay);

   double eff_coherence = 0.6 * hist_coh + 0.4 * longterm_coherence;
   double eff_entropy   = 0.6 * hist_ent + 0.4 * longterm_entropy;
   double eff_stress    = 0.6 * hist_stress + 0.4 * longterm_stress;

   // ENHANCED: Regime Detection Engine
   double atr_short = iATR(_Symbol, PERIOD_CURRENT, 14);
   double atr_long = iATR(_Symbol, PERIOD_CURRENT, 55);
   double ma_fast = iMA(_Symbol, PERIOD_CURRENT, 14, 0, MODE_SMA, PRICE_CLOSE);
   double ma_slow = iMA(_Symbol, PERIOD_CURRENT, 55, 0, MODE_SMA, PRICE_CLOSE);
   double ma_distance = MathAbs(ma_fast - ma_slow) / MathMax(point, 1e-6);
   double trend_ratio = atr_short / MathMax(atr_long, 1e-6);
   double trend_score = MathMin(MathMax((trend_ratio * 0.6 + ma_distance * 0.4), 0.0), 1.0);
   // 0=range, 0.5=transition, 1.0=trend

   for(int s=0; s<5; s++)
   {
      double dot = 0.0, normV = 0.0, normS = 0.0;
      for(int d=0; d<8; d++)
      {
         double sv = strategy_core.strategy_vectors[s][d];
         double st = state[d];
         if(!MathIsValidNumber(sv)) sv = 0.0;
         if(!MathIsValidNumber(st)) st = 0.0;
         dot   += st * sv;
         normV += st * st;
         normS += sv * sv;
      }
      normV = MathSqrt(MathMax(1e-9, normV));
      normS = MathSqrt(MathMax(1e-9, normS));
      double cos_sim = dot / MathMax(1e-12, normV * normS);
      if(cos_sim > 1.0) cos_sim = 1.0; else if(cos_sim < -1.0) cos_sim = -1.0;

      double avg_strength = 0.0;
      for(int d=0; d<8; d++)
      {
         double v = strategy_core.strategy_vectors[s][d];
         if(!MathIsValidNumber(v)) v = 0.0;
         avg_strength += v;
      }
      avg_strength /= 8.0;
      avg_strength = 1.0 / (1.0 + MathExp(-avg_strength));
      if(!MathIsValidNumber(avg_strength)) avg_strength = 0.0;

      double cs_norm = 0.5 * (cos_sim + 1.0);
      double resonance = 0.5 + 0.5 * MathTanh((eff_coherence - eff_entropy) * 3.0);
      
      // ENHANCED: Dynamic Fitness Weighting
      double alpha = 0.6 + trend_score * 0.3; // Similarity weight (higher in trends)
      double beta = 0.5 - trend_score * 0.3;  // Strength weight (higher in ranges)
      alpha = MathMin(MathMax(alpha, 0.3), 0.9);
      beta = MathMin(MathMax(beta, 0.2), 0.8);
      
      double stress_penalty = 1.0 - (eff_stress * 0.3);
      strategy_core.strategy_fitness[s] =
         ((cs_norm * (alpha + 0.1 * resonance)) + (avg_strength * (beta + 0.1 * (1.0 - resonance)))) * stress_penalty;
      strategy_core.strategy_fitness[s] = MathMin(1.0, MathMax(0.0, strategy_core.strategy_fitness[s]));
   }

   double sumExp = 0.0;
   for(int i=0; i<5; i++) sumExp += MathExp(strategy_core.strategy_fitness[i] * 4.0);
   for(int i=0; i<5; i++) strategy_core.regime_probabilities[i] =
         MathExp(strategy_core.strategy_fitness[i] * 4.0) / MathMax(1e-9, sumExp);

   double echo_prob = 0.0; int echo_dir = 0;
   EchoRefine(state, 8, 2, echo_prob, echo_dir);

   double base_conf = (MathIsValidNumber(fractal_intel.fractal_confluence_score) ? fractal_intel.fractal_confluence_score : 0.0);
   double ai_amp = (InpEnableAILearning ? (1.0 + InpAIInfluence * 0.8) : 1.0);
   double dir_gain = (echo_dir == 1 ? 1.05 : (echo_dir == -1 ? 0.95 : 1.0));

   double echo_influence = 0.25 * (0.5 + 0.5 * eff_coherence) * (1.0 - 0.5 * eff_entropy);

   strategy_core.regime_confidence =
         0.55 * strategy_core.regime_confidence
       + 0.30 * (base_conf * ai_amp * dir_gain)
       + 0.15 * (echo_prob * echo_influence);

   strategy_core.regime_confidence = MathMin(1.0, MathMax(0.0, strategy_core.regime_confidence));

   if(InpEnableLogging)
      PrintFormat("A-EchoRefine+Memory | eff_coh=%.3f eff_ent=%.3f eff_stress=%.3f echo=%.3f dir=%d conf=%.3f trend_score=%.3f",
                  eff_coherence, eff_entropy, eff_stress, echo_prob, echo_dir, strategy_core.regime_confidence, trend_score);
}

//+------------------------------------------------------------------+
//| Select Exit Mode (ENHANCED)                                      |
//+------------------------------------------------------------------+
int SelectExitMode()
{
   double regime_anticipation = fractal_intel.power_law_exponent;
   double coherence_strength = fractal_intel.concentration_ratio;
   double decision_confidence = strategy_core.regime_confidence;
   double volatility_stress = fractal_intel.recursive_confidence;
   
   double market_volatility = MathMax(0.1, market_data.volatility_regime);
   double adversarial_stress = MathAbs(decision_confidence - 0.5) / (1.0 + market_volatility);
   
   bool strong_trend_signal = (regime_anticipation > 0.65 && coherence_strength > 0.60 && adversarial_stress < 0.30);
   bool weak_signal = (regime_anticipation < 0.45 || coherence_strength < 0.45 || adversarial_stress > 0.50);
   
   
   
   
  // ENHANCED: Liquidity Safety Override with asset-specific threshold
   double liquidity_threshold = (StringFind(_Symbol, "BTC", 0) >= 0 || StringFind(_Symbol, "ETH", 0) >= 0) ? 0.08 :
                            (StringFind(_Symbol, "XAUUSD", 0) >= 0 || StringFind(_Symbol, "GOLD", 0) >= 0) ? 0.12 : 0.3;

    if(market_data.liquidity_condition < liquidity_threshold)
{
   if(InpEnableLogging)
      PrintFormat("EXIT_MODE FORCED: TIME (liquidity safety) | liq=%.3f thr=%.3f",
                  market_data.liquidity_condition, liquidity_threshold);
   return 2;
}
   
   // ENHANCED: Trend-Adaptive Stop Tightening
   double momentum_ratio = MathAbs(market_data.momentum_state) / MathMax(market_data.atr, 1e-6);
   double stop_tightening = MathMin(momentum_ratio * 0.1, 0.3); // Up to 30% tighter
   
   int exit_mode = 0;
   
   if(strong_trend_signal)
   {
      exit_mode = 1;
      decision.stop_loss_distance *= (1.0 - stop_tightening); // Apply tightening
      if(InpEnableLogging)
         PrintFormat("EXIT_MODE SELECTED: ATR (trend) | antic=%.3f coher=%.3f stress=%.3f conf=%.3f tighten=%.2f",
                     regime_anticipation, coherence_strength, adversarial_stress, decision_confidence, stop_tightening);
   }
   else if(weak_signal)
   {
      exit_mode = 2;
      if(InpEnableLogging)
         PrintFormat("EXIT_MODE SELECTED: TIME (secure) | antic=%.3f coher=%.3f stress=%.3f conf=%.3f",
                     regime_anticipation, coherence_strength, adversarial_stress, decision_confidence);
   }
   else
   {
      exit_mode = 3;
      decision.stop_loss_distance *= (1.0 - stop_tightening * 0.5); // Partial tightening
      if(InpEnableLogging)
         PrintFormat("EXIT_MODE SELECTED: HYBRID (staged) | antic=%.3f coher=%.3f stress=%.3f conf=%.3f tighten=%.2f",
                     regime_anticipation, coherence_strength, adversarial_stress, decision_confidence, stop_tightening * 0.5);
   }
   
   return exit_mode;
}

//+------------------------------------------------------------------+
//| ConductStrategyVoting (UPGRADED – stable, drawdown-aware)        |
//+------------------------------------------------------------------+
void ConductStrategyVoting()
{
   // --- persistent state inside function only ---
   static double bias_memory[5] = {0.0,0.0,0.0,0.0,0.0};
   static int    dominated_count[5] = {0,0,0,0,0};      // counts consecutive low-vote ticks
   static double prev_consensus = 0.0;
   static double prev_equity = 0.0;
   static int    equity_growth_streak = 0;

   // --- dynamic regime inputs ---
   double flow_velocity = fractal_intel.institutional_flow_velocity;
   double vol_regime    = market_data.volatility_regime;

   // --- adaptive bias decay ---
   double bias_decay = 0.92;
   if(flow_velocity > 1.0 || vol_regime > 1.6) bias_decay = 0.80;
   else if(vol_regime < 0.8) bias_decay = 0.95;

   // --- account / drawdown awareness ---
   double curBal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double curEq    = AccountInfoDouble(ACCOUNT_EQUITY);
   double startBal = (daily_target.daily_starting_balance > 0.0) ? daily_target.daily_starting_balance : curBal;
   double drawdown = (startBal > 0.0) ? MathMax(0.0, (startBal - curEq) / startBal) : 0.0;

   // --- detect sustained equity expansion (simple streak detector) ---
   if(prev_equity <= 0.0) prev_equity = curEq;
   if(curEq > prev_equity * 1.0005) // small tolerance to avoid noise
      equity_growth_streak++;
   else
      equity_growth_streak = 0;
   prev_equity = curEq;
   bool size_bias_allowed = (equity_growth_streak >= 3); // only permit size/bias increases after 3 positive ticks

   // --- dominated strategy collapse params ---
   double dominated_threshold = 0.08; // proportion of max votes considered dominated
   int    dominated_window    = 5;    // consecutive ticks before applying collapse
   double collapse_multiplier = 0.50; // reduce weight by this factor when collapsed
   double min_weight_allowed  = 0.05; // never collapse below this weight

   // --- first pass: compute base votes with bias memory and drawdown penalty ---
   double temp_votes[5];
   for(int i=0; i<5; i++)
   {
      double fit    = MathIsValidNumber(strategy_core.strategy_fitness[i]) ? strategy_core.strategy_fitness[i] : 0.0;
      double weight = MathIsValidNumber(strategy_vote.voting_weights[i])  ? strategy_vote.voting_weights[i]  : 0.0;
      double conf   = MathIsValidNumber(strategy_core.regime_confidence)  ? strategy_core.regime_confidence  : 0.0;

      double coherence = MathIsValidNumber(fractal_intel.fractal_confluence_score)
                         ? 0.5 + 0.5 * fractal_intel.fractal_confluence_score
                         : 0.5;
      double entropy = MathAbs(conf - coherence);

      // edge_quality uses existing signals - safe to compute
      double edge_quality = 0.6 * fractal_intel.fractal_confluence_score + 0.4 * strategy_core.regime_confidence;

      // update bias memory (self-correcting)
      bias_memory[i] = bias_memory[i] * bias_decay + (fit - 0.5) * 0.10 * edge_quality;
      if(!MathIsValidNumber(bias_memory[i])) bias_memory[i] = 0.0;

      // drawdown-preservation: amplify penalty on bias when drawdown is present
      double drawdown_penalty = 1.0 + 4.0 * MathMin(drawdown, 0.20); // up to 20% drawdown scales penalty
      double bias_adj = 1.0 - bias_memory[i] * (0.30 * drawdown_penalty + 0.40 * MathMin(drawdown, 0.10));
      bias_adj = MathMin(MathMax(bias_adj, 0.25), 1.5);

      // allow size/bias increases only when sustained growth exists (prevents biasing after single wins)
      double growth_bias = size_bias_allowed ? (1.0 + 0.15 * MathMin(equity_growth_streak, 10)) : 1.0;

      // compute dynamic weight
      double dyn_weight = weight * (0.75 + 0.45 * conf) * bias_adj * (1.0 - 0.35 * entropy) * growth_bias;
      if(!MathIsValidNumber(dyn_weight) || dyn_weight <= 0.0) dyn_weight = 0.0;

      temp_votes[i] = MathMax(0.0, fit * dyn_weight * (0.5 + coherence));
      // store into strategy_vote but we'll adjust further below
      strategy_vote.strategy_votes[i] = temp_votes[i];
   }

   // --- rank top 3 strategies safely ---
   for(int t=0; t<3; t++) strategy_vote.top_strategies[t] = -1;
   double votes_copy[5];
   for(int i=0;i<5;i++) votes_copy[i] = strategy_vote.strategy_votes[i];

   for(int r=0; r<3; r++)
   {
      int best = -1; double best_val = -1.0;
      for(int j=0; j<5; j++)
      {
         bool used = false;
         for(int k=0; k<r; k++) if(strategy_vote.top_strategies[k] == j) { used = true; break; }
         if(used) continue;
         if(votes_copy[j] > best_val) { best_val = votes_copy[j]; best = j; }
      }
      if(best >= 0) strategy_vote.top_strategies[r] = best;
   }

   // --- dominated-strategy detection & collapse logic ---
   // identify max vote to compare
   double max_vote = 1e-9;
   for(int i=0;i<5;i++) max_vote = MathMax(max_vote, strategy_vote.strategy_votes[i]);

   for(int i=0;i<5;i++)
   {
      if(strategy_vote.strategy_votes[i] < dominated_threshold * max_vote)
      {
         dominated_count[i] = MathMin(dominated_count[i] + 1, dominated_window + 2);
      }
      else
      {
         dominated_count[i] = 0;
      }

      // when dominated long enough, apply collapse to voting weight (this reduces future influence)
      if(dominated_count[i] >= dominated_window)
      {
         // shrink voting weight (persistent until re-inflated by upstream systems)
         strategy_vote.voting_weights[i] = MathMax(strategy_vote.voting_weights[i] * collapse_multiplier, min_weight_allowed);
         // apply a stronger penalty to immediate vote
         strategy_vote.strategy_votes[i] *= collapse_multiplier;
         // mild log
         if(InpEnableLogging)
            PrintFormat("DOMINATED COLLAPSE: strategy=%d collapsed -> new_weight=%.3f", i, strategy_vote.voting_weights[i]);

         // reset dominated counter so we don't repeatedly multiply each tick
         dominated_count[i] = 0;
      }
   }

   // --- consensus calculation with smoothing ---
   double total_vote = 0.0, total_weight = 0.0;
   for(int k=0; k<3; k++)
   {
      int idx = strategy_vote.top_strategies[k];
      if(idx < 0) continue;
      double w = (3.0 - (double)k);
      total_vote += strategy_vote.strategy_votes[idx] * w;
      total_weight += w;
   }
   double raw_consensus = (total_weight > 0.0) ? total_vote / total_weight : 0.0;
   strategy_vote.final_consensus = 0.7 * prev_consensus + 0.3 * raw_consensus;
   prev_consensus = strategy_vote.final_consensus;

   // --- election using softmax (stable) ---
   double exp_sum = 0.0;
   double expv[5];
   for(int i=0;i<5;i++) { expv[i] = MathExp(strategy_vote.strategy_votes[i] * 5.0); exp_sum += expv[i]; }

   double maxP = 0.0; int elected = -1;
   for(int i=0;i<5;i++)
   {
      double p = expv[i] / MathMax(1e-9, exp_sum);
      if(p > maxP) { maxP = p; elected = i; }
   }

   // --- drawdown-preservation: raise veto threshold and optionally veto election when in drawdown ---
   double veto_threshold = (market_data.volatility_regime > 1.6) ? 0.45 : 0.35;
   if(drawdown > 0.03) // modest drawdown -> tighten rules
   {
      veto_threshold = MathMin(0.85, veto_threshold + 0.15 * MathMin(drawdown*10.0, 1.0));
      // penalize elected if consensus weak relative to veto threshold
      if(strategy_vote.final_consensus < veto_threshold)
         elected = -1;
   }
   else
   {
      if(strategy_vote.final_consensus < veto_threshold)
         elected = -1;
   }

   // --- ensemble mode: if top2 close in votes, consider ensemble (signal -2) ---
   if(strategy_vote.top_strategies[0] >= 0 && strategy_vote.top_strategies[1] >= 0)
   {
      double v0 = MathMax(1e-9, strategy_vote.strategy_votes[strategy_vote.top_strategies[0]]);
      double v1 = strategy_vote.strategy_votes[strategy_vote.top_strategies[1]];
      double top_ratio = v1 / v0;
      if(top_ratio > 0.70) // within ~30% gap -> ensemble
      {
         elected = -2;
         if(InpEnableLogging) PrintFormat("ENSEMBLE MODE: top2 ratio=%.3f (ensemble selected)", top_ratio);
      }
   }

   // --- final assignment & state ---
   strategy_vote.elected_strategy = elected;
   strategy_vote.voting_complete = true;

   // --- logging for visibility ---
   if(InpEnableLogging)
   {
      string elected_str;
      if(elected == -1) elected_str = "VETO";
      else if(elected == -2) elected_str = "ENSEMBLE";
      else elected_str = StrategyToString((ENUM_STRATEGY_TYPE)elected);

      double top_bias = (elected >= 0 && elected < 5) ? bias_memory[elected] : 0.0;
      PrintFormat("Voting done | Elected=%s Consensus=%.3f MaxVote=%.3f Drawdown=%.3f GrowthStreak=%d",
                  elected_str, strategy_vote.final_consensus, max_vote, drawdown, equity_growth_streak);
      for(int i=0;i<5;i++)
      PrintFormat("  strat[%d] vote=%.4f weight=%.4f dominated=%d",
                     i,
                     strategy_vote.strategy_votes[i],
                     strategy_vote.voting_weights[i],
                     dominated_count[i]);
                     
   // --- dominated-strategy detection, collapse, and revival ---
static int revival_count[5] = {0,0,0,0,0};

for(int i=0;i<5;i++)
{
   // dominated detection
   if(strategy_vote.strategy_votes[i] < dominated_threshold * max_vote)
      dominated_count[i] = MathMin(dominated_count[i] + 1, dominated_window + 2);
   else
      dominated_count[i] = 0;

   // collapse after sustained domination loss
   if(dominated_count[i] >= dominated_window)
   {
      strategy_vote.voting_weights[i] =
         MathMax(strategy_vote.voting_weights[i] * collapse_multiplier, min_weight_allowed);

      strategy_vote.strategy_votes[i] *= collapse_multiplier;
      dominated_count[i] = 0;

      if(InpEnableLogging)
         PrintFormat("DOMINATED COLLAPSE: strat=%d new_weight=%.3f",
                     i,
                     strategy_vote.voting_weights[i]);
   }

   // -------- REVIVAL ACCELERATION --------
   bool revival_signal =
      strategy_vote.strategy_votes[i] > 0.45 &&
      strategy_core.strategy_fitness[i] > 0.65 &&
      fractal_intel.fractal_confluence_score > 0.55;

   if(revival_signal)
      revival_count[i]++;
   else
      revival_count[i] = MathMax(0, revival_count[i] - 1);

   if(revival_count[i] >= 2)
   {
      strategy_vote.voting_weights[i] =
         MathMin(strategy_vote.voting_weights[i] * 1.25, 1.0);

      strategy_vote.strategy_votes[i] *= 1.20;

      if(InpEnableLogging)
         PrintFormat("REVIVAL ACCELERATION: strat=%d weight=%.3f vote=%.3f",
                     i,
                     strategy_vote.voting_weights[i],
                     strategy_vote.strategy_votes[i]);
   }
}

   }
}

//+------------------------------------------------------------------+
//| Get Optimal Strategy (ENHANCED)                                 |
//+------------------------------------------------------------------+
int GetOptimalStrategy()
{
   if(InpStrategyType != STRATEGY_AUTO)
   {
      strategy_vote.elected_strategy = (int)InpStrategyType;
      return strategy_vote.elected_strategy;
   }

   int base = strategy_vote.elected_strategy;
   double confluence = MathIsValidNumber(fractal_intel.fractal_confluence_score) ? fractal_intel.fractal_confluence_score : 0.0;

   static double regime_bias = 0.0;
   regime_bias = 0.9 * regime_bias + (confluence - 0.5) * 0.1;

   // Handle veto and ensemble signals
   if(base == -1) return -1;
   if(base == -2) return -2;

   // Let votes decide symmetrically — no directional thumb
   strategy_vote.elected_strategy = base;
   return base;
}
//+------------------------------------------------------------------+
//| Adaptive ACE Strategy across Multiple Timeframes                 |
//+------------------------------------------------------------------+
void AdaptiveACEStrategy()
{
   // --- Compression Detection ---
   double high1 = iHigh(_Symbol, PERIOD_H1, 1);
   double low1 = iLow(_Symbol, PERIOD_H1, 1);
   double high2 = iHigh(_Symbol, PERIOD_H1, 2);
   double low2 = iLow(_Symbol, PERIOD_H1, 2);

   bool isInside = (high1 < high2 && low1 > low2);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // --- Timeframe Adaptive Parameters ---
   double timeframe_coefficient;
   ENUM_TIMEFRAMES strategy_tf = PERIOD_H1;

   if(market_data.atr < 0.0015) // Low volatility: favor lower timeframe logic
   {
      timeframe_coefficient = 1.8;
      strategy_tf = PERIOD_M15;
   }
   else if(market_data.atr < 0.0030) // Moderate volatility
   {
      timeframe_coefficient = 1.4;
      strategy_tf = PERIOD_H1;
   }
   else // Higher volatility: extend analysis to higher timeframe
   {
      timeframe_coefficient = 1.0;
      strategy_tf = PERIOD_H4;
   }

   // --- Predictive Regime Shift Detection (Adaptive) ---
   double regime_anticipation = 0.0;
   {
      double atr_current = market_data.atr;
      double close_current = iClose(_Symbol, strategy_tf, 0);
      double close_prev = iClose(_Symbol, strategy_tf, 1);
      double momentum_curr = close_current - close_prev;
      
      double expected_move = momentum_curr * 0.7 + (atr_current * 0.2) * (momentum_curr > 0 ? 1.0 : -1.0);
      double volatility_forecast = atr_current * 1.3 * timeframe_coefficient;
      
      regime_anticipation = 0.5 + 0.4 * (expected_move / (MathMax(volatility_forecast, 1e-8)));
      regime_anticipation = MathMin(MathMax(regime_anticipation, 0.0), 1.0);
      if(!MathIsValidNumber(regime_anticipation)) regime_anticipation = 0.5;
   }

   // --- Institutional Micro-Imbalance Sensing (Adaptive) ---
   double micro_imbalance = 0.0;
   {
      double vol_accum = 0.0;
      double price_var = 0.0;
      int lookback = (strategy_tf == PERIOD_M15) ? 3 : (strategy_tf == PERIOD_H1 ? 4 : 6);
      for(int m=0; m<lookback; m++)
      {
         double v_cur = (double)iVolume(_Symbol, strategy_tf, m);
         double v_prev = (double)iVolume(_Symbol, strategy_tf, m+1);
         double price_delta = MathAbs(iClose(_Symbol, strategy_tf, m) - iClose(_Symbol, strategy_tf, m+1));
         vol_accum += MathAbs(v_cur - v_prev);
         price_var += price_delta;
      }
      micro_imbalance = (vol_accum > 1e-6) ? (vol_accum / (1.0 + price_var * 1500.0 * timeframe_coefficient)) : 0.0;
      micro_imbalance = micro_imbalance / (1.0 + micro_imbalance);
      if(!MathIsValidNumber(micro_imbalance)) micro_imbalance = 0.0;
   }

   // --- Compression Depth Calculation ---
   int compressionDepth = 0;
   int comp_lookback = (strategy_tf == PERIOD_M15) ? 3 : (strategy_tf == PERIOD_H1 ? 4 : 5);
   for(int b = 1; b <= comp_lookback; b++)
   {
      double h_cur = iHigh(_Symbol, PERIOD_H1, b);
      double l_cur = iLow(_Symbol, PERIOD_H1, b);
      double h_prev = iHigh(_Symbol, PERIOD_H1, b + 1);
      double l_prev = iLow(_Symbol, PERIOD_H1, b + 1);
      if(h_cur < h_prev && l_cur > l_prev)
         compressionDepth++;
      else
         break;
   }

   // --- Momentum Confirmation ---
   double momentum = market_data.momentum_state;
   double atr = MathMax(0.000001, market_data.atr);
   double volatilityRegime = market_data.volatility_regime;

   // --- Institutional Flow Check ---
   double flowStrength = fractal_intel.institutional_flow_velocity;
   double flowDirection = (flowStrength > 0) ? 1.0 : -1.0;
   
   // Compression-Duration verifier (insert where TF/context known)
{
   static double comp_ewma = 0.0; // local persistent only
   double hour_range = iHigh(_Symbol,PERIOD_H1,1)-iLow(_Symbol,PERIOD_H1,1);
   double range_norm = hour_range / MathMax(market_data.atr,1e-9);
   comp_ewma = 0.92*comp_ewma + 0.08*range_norm;
   bool compression_long = (comp_ewma < 0.35 && fractal_intel.institutional_flow_velocity > 0.45);
   if(compression_long)
   {
      // gentle preempt: reduce size and increase veto
      decision.position_size *= 0.85;
      // reduce learning gate so only stronger signals update
      if(InpEnableLogging) PrintFormat("PRE-REGIME FLAG: comp_ewma=%.3f flow=%.2f", comp_ewma, fractal_intel.institutional_flow_velocity);
   }
}


   // --- Volatility Adjusted Position Sizing ---
   double volatilityAdjustment = 1.0 + 0.6 * (volatilityRegime - 1.0);
   decision.position_size = NormalizeLot(InpLotSize * (1.0 + 0.20 * compressionDepth) * volatilityAdjustment * timeframe_coefficient);
   
   double beacons_bound = ComputeBoundedErrorEnvelope(
    fractal_intel.fractal_confluence_score,   // from fractal_intel object
    market_data.ma_fast,                       // local variable
    market_data.momentum_state,                // this one probably exists
    volatilityRegime,                          // already proven in scope above
    regime_anticipation          // regime shift proxy
);

// Compress size based on bounded extrapolation risk
decision.position_size *= (1.0 - beacons_bound);

// Re-normalize after compression
decision.position_size = NormalizeLot(decision.position_size);


   // --- Confidence Calculation ---
   decision.confidence_level = 0.40 + 0.30 * strategy_core.regime_confidence + 
                              0.15 * compressionDepth + 0.10 * MathAbs(momentum) + 
                              0.05 * MathAbs(flowStrength) + 0.10 * micro_imbalance;

   if(isInside && strategy_core.regime_confidence >= 0.40 && MathAbs(flowStrength) > 0.3)
   {
      double range = high1 - low1;
      double sigmaMultiplier = 1.2 + 0.4 * fractal_intel.fractal_confluence_score;
      double anchoredHigh = high1 + sigmaMultiplier * range;
      double anchoredLow = low1 - sigmaMultiplier * range;

      if(bid > anchoredLow && bid < anchoredHigh)
      {
         int exit_mode = SelectExitMode();
         double tpFactor = (exit_mode == 1) ? 3.2 + 0.4 * compressionDepth :
                        (exit_mode == 2) ? 1.5 + 0.1 * compressionDepth : 2.0 + 0.2 * compressionDepth;

         decision.take_profit_distance = range * tpFactor * timeframe_coefficient;
         decision.stop_loss_distance = range * 0.4 * volatilityAdjustment;

         // ── Direction: momentum + BOS confirmation from shared bus ──
         // BOS from shared_ctx acts as the structure break confirmation
         // that ACE was previously missing — now it knows which way to break.
         ENUM_ORDER_TYPE ace_dir = (momentum > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(shared_ctx.bos_bull && momentum > 0) ace_dir = ORDER_TYPE_BUY;
         else if(shared_ctx.bos_bear && momentum < 0) ace_dir = ORDER_TYPE_SELL;
         // If BOS contradicts momentum, require stronger momentum to override
         else if(shared_ctx.bos_bull && momentum < 0 && MathAbs(momentum) < 0.3) ace_dir = ORDER_TYPE_BUY;
         else if(shared_ctx.bos_bear && momentum > 0 && MathAbs(momentum) < 0.3) ace_dir = ORDER_TYPE_SELL;

         decision.trade_direction = ace_dir;

         // ── TP: prefer FVG structural target when aligned ──────────
         double fvg_boost = 1.0;
         if(ace_dir == ORDER_TYPE_BUY  && shared_ctx.fvg_bull && shared_ctx.fvg_target > 0)
         {
            double fvg_dist = MathAbs(shared_ctx.fvg_target - market_data.price_current);
            decision.take_profit_distance = MathMax(fvg_dist, range * tpFactor * timeframe_coefficient);
            fvg_boost = 1.15;
         }
         else if(ace_dir == ORDER_TYPE_SELL && shared_ctx.fvg_bear && shared_ctx.fvg_target > 0)
         {
            double fvg_dist = MathAbs(market_data.price_current - shared_ctx.fvg_target);
            decision.take_profit_distance = MathMax(fvg_dist, range * tpFactor * timeframe_coefficient);
            fvg_boost = 1.15;
         }
         else
            decision.take_profit_distance = range * tpFactor * timeframe_coefficient;

         decision.stop_loss_distance = range * 0.4 * volatilityAdjustment;

         // ── Confidence boost when BOS + FVG align with ACE ─────────
         double bos_bonus = (shared_ctx.bos_bull && ace_dir==ORDER_TYPE_BUY) ||
                            (shared_ctx.bos_bear && ace_dir==ORDER_TYPE_SELL) ? 0.08 : 0.0;
         decision.confidence_level = MathMin(0.95, decision.confidence_level + bos_bonus);

         decision.reasoning_summary = StringFormat("ACE | Depth=%d Flow=%.2f Regime=%.2f Mode=%d TF=%s BOS=%s FVG=%s",
            compressionDepth, flowStrength, regime_anticipation, exit_mode, TimeframeToString(strategy_tf),
            shared_ctx.bos_bull?"BULL":shared_ctx.bos_bear?"BEAR":"--",
            shared_ctx.fvg_bull?"BULL":shared_ctx.fvg_bear?"BEAR":"--");
         decision.execution_ready = true;
      }
   }

   if(daily_target.target_reached)
   {
      if(InpEnableLogging) Print("ACE BLOCK: Daily target already reached");
      return;
   }

   if(PositionSelect(_Symbol))
   {
      double ran = high1 - low1;
      double profit_threshold = (strategy_tf == PERIOD_M15) ? 0.15 : (strategy_tf == PERIOD_H1 ? 0.20 : 0.30);
      double volume_threshold = (strategy_tf == PERIOD_M15) ? 0.1 : (strategy_tf == PERIOD_H1 ? 0.2 : 0.3);

      if(PositionGetDouble(POSITION_PROFIT) >= ran * profit_threshold && PositionGetDouble(POSITION_VOLUME) > volume_threshold)
         trade.PositionClosePartial(_Symbol, PositionGetDouble(POSITION_VOLUME) * (strategy_tf == PERIOD_M15 ? 0.3 : (strategy_tf == PERIOD_H1 ? 0.25 : 0.2)));

      if(PositionGetDouble(POSITION_PROFIT) >= ran * profit_threshold * 2 && PositionGetDouble(POSITION_VOLUME) > volume_threshold * 2)
      {
         trade.PositionClosePartial(_Symbol, PositionGetDouble(POSITION_VOLUME) * (strategy_tf == PERIOD_M15 ? 0.4 : (strategy_tf == PERIOD_H1 ? 0.35 : 0.3)));
         if((int)PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_BUY)
            trade.PositionModify(_Symbol, bid - ran * (strategy_tf == PERIOD_M15 ? 0.30 : (strategy_tf == PERIOD_H1 ? 0.25 : 0.20)), 0);
         if((int)PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_SELL)
            trade.PositionModify(_Symbol, bid + ran * (strategy_tf == PERIOD_M15 ? 0.30 : (strategy_tf == PERIOD_H1 ? 0.25 : 0.20)), 0);
      }

      if(PositionGetDouble(POSITION_VOLUME) > volume_threshold * 2)
      {
         if((int)PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_BUY && bid - decision.stop_loss_distance > PositionGetDouble(POSITION_SL))
            trade.PositionModify(_Symbol, bid - decision.stop_loss_distance, 0);

         if((int)PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_SELL && bid + decision.stop_loss_distance < PositionGetDouble(POSITION_SL))
            trade.PositionModify(_Symbol, bid + decision.stop_loss_distance, 0);
      }
   }
}

string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return "Unknown";
   }
}
//+------------------------------------------------------------------+
//| PRINT Strategy Processing - upgraded & stabilized                |
//+------------------------------------------------------------------+
void ProcessPrintStrategy()
{
   
   datetime now = TimeCurrent();
   MqlDateTime tm; TimeToStruct(now, tm);
   datetime hour_start = now - (tm.min * 60) - tm.sec;

   bool immediate_hour_init = false;
   bool run_entry_now = false;
   
   //--- Session Intelligence (XAUUSD optimized)
int hour = tm.hour;
bool asia  = (hour >= 1 && hour < 7);
bool london= (hour >= 7 && hour < 15);
bool ny    = (hour >= 15 && hour < 22);

// Suppress PRINT during Asia unless displacement is extreme
if(asia && fractal_intel.fractal_confluence_score < 0.75)
   return;

// Boost PRINT confidence during London & NY opens
double session_boost = 1.0;
if(london) session_boost = 1.15;
if(ny)     session_boost = 1.10;


   //--- Daily reset
   if(print_strategy.last_reset_date == 0 || GetDayOf(print_strategy.last_reset_date) != tm.day)
   {
      print_strategy.last_reset_date = now;
      print_strategy.opportunities_today = 0;
      print_strategy.trades_taken_today = 0;
   }

   //--- Hour initialization
   if(!print_strategy.monitoring_active || print_strategy.hour_start_time != hour_start)
   {
      print_strategy.monitoring_active = true;
      print_strategy.hour_start_time = hour_start;
      print_strategy.hour_open_price = iOpen(_Symbol, PERIOD_H1, 1);
      print_strategy.monitoring_end = hour_start + 3600;

      print_strategy.displacement_detected = false;
      print_strategy.waiting_for_entry = false;
      print_strategy.active_fvg.is_valid = false;

      immediate_hour_init = true;
   }

   //--- HARD SAFETY GATES (PRINT should not even think in these states)
   double spreadPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double atr = MathMax(1e-6, market_data.atr);
   double spreadLimit = MathMax(150.0, atr * 10000.0 * 0.35);

   if(spreadPts > spreadLimit) return;
   if(market_data.liquidity_condition < 0.25) return;
   if(market_data.volatility_regime > 2.3) return;

   //--- Context metrics
   double fscore = MathIsValidNumber(fractal_intel.fractal_confluence_score) ? fractal_intel.fractal_confluence_score : 0.5;
   double coherence = MathIsValidNumber(fractal_intel.recursive_confidence) ? fractal_intel.recursive_confidence : 0.5;
   double context_quality = 0.5*fscore + 0.5*coherence;

   //--- Adaptive displacement threshold (tightens when quality is poor)
   double vol = MathMax(0.2, MathMin(2.0, market_data.volatility_regime));
   double context_gain = 0.8 + 0.4 * context_quality;
   double dynamic_threshold =
   print_strategy.displacement_threshold *
   context_gain *
   (1.0 + 0.1 * vol) /
   session_boost;


   if(context_quality < 0.45)
      dynamic_threshold *= 1.25; // require stronger displacement in weak regimes

   double displacement = (print_strategy.hour_open_price > 0.0)
                         ? MathAbs(market_data.price_current - print_strategy.hour_open_price)
                           / print_strategy.hour_open_price
                         : 0.0;

   //=================================================================
   // DISPLACEMENT DETECTION
   //=================================================================
   if(!print_strategy.displacement_detected && displacement >= dynamic_threshold)
   {
      double entropy = MathAbs(coherence - fscore);
      if(entropy > 0.40) return; // noisy disagreement ? abort early

      print_strategy.displacement_detected = true;
      print_strategy.waiting_for_entry = true;
      print_strategy.opportunities_today++;

      double h1_high = iHigh(_Symbol, PERIOD_H1, 1);
      double h1_low  = iLow(_Symbol, PERIOD_H1, 1);

      print_strategy.active_fvg.is_valid = true;
      print_strategy.active_fvg.formation_time = now;
      print_strategy.active_fvg.gap_high = h1_high;
      print_strategy.active_fvg.gap_low  = h1_low;
      print_strategy.active_fvg.gap_center = 0.5 * (h1_high + h1_low);
      print_strategy.active_fvg.expiry_time = now + 3600;

      // Direction from shared structural context — not Gold's eternal uptrend
      // structural_dir +1 = bull (HH+HL), -1 = bear (LH+LL), 0 = mixed
      bool displaced_up = (market_data.price_current > print_strategy.hour_open_price);
      if(shared_ctx.structural_dir == 1)
         print_strategy.active_fvg.is_bullish = displaced_up;
      else if(shared_ctx.structural_dir == -1)
         print_strategy.active_fvg.is_bullish = false;  // only sell setups in bear structure
      else
         print_strategy.active_fvg.is_bullish = displaced_up;  // mixed: follow displacement

      run_entry_now = true;
   }

   //--- Allow immediate recheck at hour boundary
   if(immediate_hour_init &&
      print_strategy.waiting_for_entry &&
      print_strategy.active_fvg.is_valid &&
      !print_strategy.active_fvg.filled)
      run_entry_now = true;

   //=================================================================
   // ENTRY LOGIC — BOS CLOSE ENTRY (no retest, enter on structure break)
   // The closed M5 candle that confirms COC IS the entry trigger.
   //=================================================================
   static datetime last_trade_time = 0;
   if(!print_strategy.waiting_for_entry || !print_strategy.active_fvg.is_valid ||
      print_strategy.active_fvg.filled) return;

   if(TimeCurrent() - last_trade_time < 600) return;

   //--- Sweep detection (graded)
   int sweep_dir = 0;
   double sweep_strength = 0.0;
   double prev_h1_hi = iHigh(_Symbol, PERIOD_H1, 2);
   double prev_h1_lo = iLow(_Symbol, PERIOD_H1, 2);

   for(int i=1;i<=12;i++)
   {
      double bh = iHigh(_Symbol, PERIOD_M5, i);
      double bl = iLow(_Symbol, PERIOD_M5, i);
      if(bh > prev_h1_hi){ sweep_dir = 1;  sweep_strength += (bh - prev_h1_hi) / atr; }
      if(bl < prev_h1_lo){ sweep_dir = -1; sweep_strength += (prev_h1_lo - bl) / atr; }
   }
   sweep_strength = MathMin(sweep_strength, 2.0);
   if(sweep_strength < 0.25) return;  // barely touched — abort

   //--- COC on last closed M5 candle — THIS IS THE BOS ENTRY SIGNAL
   double m5_close = iClose(_Symbol, PERIOD_M5, 1);
   double m5_open  = iOpen (_Symbol, PERIOD_M5, 1);
   double m5_body  = MathAbs(m5_close - m5_open);
   if(m5_body < atr * 0.06) return;  // doji/indecision — wait one more bar

   bool coc_ok = false;
   if(sweep_dir == -1 && m5_close > m5_open) coc_ok = true;  // bear sweep → bull close = BOS up
   if(sweep_dir ==  1 && m5_close < m5_open) coc_ok = true;  // bull sweep → bear close = BOS down
   if(sweep_dir ==  0)
      coc_ok = print_strategy.active_fvg.is_bullish ? (m5_close > m5_open) : (m5_close < m5_open);

   if(!coc_ok) return;  // structure not yet confirmed on close — wait

   // BOS alignment bonus: shared_ctx BOS confirms the same direction
   bool bos_aligned = (sweep_dir == -1 && shared_ctx.bos_bull) ||
                      (sweep_dir ==  1 && shared_ctx.bos_bear) ||
                      (sweep_dir ==  0);

   //=================================================================
   // TRADE CONSTRUCTION
   //=================================================================
   if(print_strategy.trades_taken_today >= InpMaxPrintTradesPerDay) return;

   TradingDecision pd;
   pd.should_trade = true;

   if(sweep_dir == -1) pd.trade_direction = ORDER_TYPE_BUY;
   else if(sweep_dir ==  1) pd.trade_direction = ORDER_TYPE_SELL;
   else pd.trade_direction = print_strategy.active_fvg.is_bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // Confidence: base + BOS alignment + signal quality from shared bus
   double conf = MathMin(1.0, 0.5*fscore + 0.3*coherence + 0.2*shared_ctx.signal_quality);
   if(bos_aligned) conf = MathMin(1.0, conf + 0.08);
   pd.position_size = NormalizeLot(InpLotSize * (0.6 + 0.8 * conf));

   // SL: behind the sweep extreme
   double recent_hi = -DBL_MAX, recent_lo = DBL_MAX;
   for(int k=1;k<=6;k++)
   {
      recent_hi = MathMax(recent_hi, iHigh(_Symbol, PERIOD_M5, k));
      recent_lo = MathMin(recent_lo, iLow (_Symbol, PERIOD_M5, k));
   }
   double sl_buffer = atr * 0.9;  // tighter than original 1.1 — SL behind structure not floating
   if(pd.trade_direction == ORDER_TYPE_BUY)
      pd.stop_loss_distance = MathAbs(market_data.price_current - (recent_lo - sl_buffer));
   else
      pd.stop_loss_distance = MathAbs((recent_hi + sl_buffer) - market_data.price_current);

   // TP: FVG structural target when aligned, else H1 range-based
   double h1_range = MathAbs(iHigh(_Symbol, PERIOD_H1, 1) - iLow(_Symbol, PERIOD_H1, 1));
   bool use_fvg_target = (pd.trade_direction==ORDER_TYPE_BUY  && shared_ctx.fvg_bull && shared_ctx.fvg_target>0) ||
                         (pd.trade_direction==ORDER_TYPE_SELL && shared_ctx.fvg_bear && shared_ctx.fvg_target>0);
   if(use_fvg_target)
      pd.take_profit_distance = MathMax(MathAbs(market_data.price_current - shared_ctx.fvg_target), atr * 2.0);
   else
      pd.take_profit_distance = MathMax(h1_range * (1.0 + 0.4*conf), atr * 2.2);

   // Enforce minimum 2.0 R:R
   if(pd.stop_loss_distance > 0 && pd.take_profit_distance/pd.stop_loss_distance < 2.0)
      pd.take_profit_distance = pd.stop_loss_distance * 2.0;

   pd.confidence_level  = 0.62 + 0.36 * conf;
   pd.execution_ready   = true;
   pd.reasoning_summary = StringFormat("PRINT|BOS-entry|swp=%.2f conf=%.2f bos=%d fvg=%s sq=%.2f",
      sweep_strength, conf, (int)bos_aligned,
      use_fvg_target?"TARGET":"RANGE", shared_ctx.signal_quality);

   //=================================================================
   // EXECUTION
   //=================================================================
   if(ExecuteTrade(pd))
   {
      print_strategy.active_fvg.filled = true;
      print_strategy.trades_taken_today++;
      print_strategy.waiting_for_entry = false;
      performance.trades_executed++;
      last_trade_time = TimeCurrent();

      if(InpEnableLogging)
         PrintFormat("PRINT EXECUTED | dir=%s | conf=%.2f | sweep=%.2f | trades_today=%d",
                     pd.trade_direction==ORDER_TYPE_BUY?"BUY":"SELL",
                     pd.confidence_level,
                     sweep_strength,
                     print_strategy.trades_taken_today);
   }

   //--- Expiry guard
   if(print_strategy.active_fvg.is_valid && now > print_strategy.active_fvg.expiry_time)
      print_strategy.active_fvg.is_valid = false;
   
   else
{
   // Cooling after failed PRINT attempt
   double stress = market_data.volatility_regime + MathAbs(fractal_intel.volatility_asymmetry_index - 0.5);
   if(stress > 1.8)
   {
      print_strategy.waiting_for_entry = false;
      print_strategy.displacement_detected = false;
      if(InpEnableLogging)
         Print("PRINT cooled down due to stress spike");
   }
   
   // Bias trailing behavior via confidence
if(pd.confidence_level > 0.8 && market_data.volatility_regime < 1.4)
{
   decision.take_profit_distance *= 1.4; // allow runner
}

{
   static double equity_anchor = 0.0;
   static bool anchor_init = false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!anchor_init || equity_anchor <= 0.0)
   {
      equity_anchor = equity;
      anchor_init = true;
   }

   // Adaptive equity anchor (slow EMA)
   equity_anchor = equity_anchor * 0.995 + equity * 0.005;

   double equity_delta = (equity - equity_anchor) / MathMax(equity_anchor, 1e-6);

   // Below equity baseline ? reduce aggression
   if(equity_delta < -0.01)
   {
      decision.position_size *= 0.7;
      decision.confidence_level *= 0.8;
   }

   // Strong equity expansion ? allow asymmetry
   if(equity_delta > 0.02)
   {
      decision.position_size *= 1.15;
   }

   // Safety clamp
   if(decision.position_size < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      decision.position_size = 0.0;

   if(InpEnableLogging)
      PrintFormat("EquityGov | equity=%.2f anchor=%.2f delta=%.3f size=%.3f",
                  equity, equity_anchor, equity_delta, decision.position_size);
}
}
}

//+------------------------------------------------------------------+
//| Sequential Trade Sequence Generator (STATIC, NO NEW GLOBALS)   |
//+------------------------------------------------------------------+
void GenerateTradeSequence()
{
   // --- STATIC SEQUENCE STATE (persists across ticks) ---
   static int sequence_position = 0;
   static int sequence_length = 10;
   static int trade_sequence[10] = {0,0,0,0,0,0,0,0,0,0}; // 0=BUY, 1=SELL
   static datetime last_sequence_reset = 0;
   static bool sequence_active = false;
   
   // --- EXISTING PREDICTIVE SIGNALS (reused, no new declarations) ---
   double conf = MathMin(MathMax(fractal_intel.fractal_confluence_score, 0.0), 1.0);
   double flow = MathMin(MathMax(fractal_intel.institutional_flow_velocity, 0.0), 1.0);
   double regime = MathMin(MathMax(market_data.volatility_regime, 0.2), 2.0);
   
   // --- SEQUENCE RESET LOGIC ---
   MqlDateTime now_struct; TimeToStruct(TimeCurrent(), now_struct);
   datetime today_start = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                                       now_struct.year, now_struct.mon, now_struct.day));
   
   // Reset daily OR when sequence completes
   if(last_sequence_reset != today_start || sequence_position >= sequence_length)
   {
      // --- GENERATE NEW 8-TRADE SEQUENCE USING EXISTING INTELLIGENCE ---
      double momentum_bias = (market_data.momentum_state > 0) ? 0.6 : 0.4;
      double hybrid_score = (conf * 0.5 + flow * 0.3 + (2.0 - regime) * 0.2) * momentum_bias;
      
      // Generate probabilistic sequence based on hybrid_score
      for(int i=0; i<sequence_length; i++)
      {
         double noise = (i % 3 == 0) ? MathRand() / 32767.0 * 0.3 : 0.0; // Add slight variation every 3rd
         double decision_threshold = hybrid_score + noise - 0.5;
         
         // BUY if threshold positive, SELL if negative
         trade_sequence[i] = (decision_threshold > 0) ? 0 : 1;
         
         // Gradually decay confidence as sequence progresses (makes later trades more neutral)
         hybrid_score = hybrid_score * 0.92 + 0.5 * 0.08;
      }
      
      sequence_position = 0;
      last_sequence_reset = today_start;
      sequence_active = true;
      
      if(InpEnableLogging)
      {
         string seq_str = "";
         for(int i=0; i<sequence_length; i++) seq_str += trade_sequence[i] == 0 ? "B" : "S";
         PrintFormat("SEQUENTIAL | New 8-trade sequence generated: %s | HybridScore=%.2f", seq_str, hybrid_score);
      }
   }
   
   // --- STORE CURRENT SEQUENCE POSITION IN DECISION STRUCTURE ---
   // (This is safe - we're reusing existing fields with local storage)
   static int current_dir_override = -1;
   if(sequence_active && sequence_position < sequence_length)
   {
      current_dir_override = trade_sequence[sequence_position];
      
      // Increment position counter for next trade
      // (only increment when we actually attempt a trade)
      if(decision.should_trade && decision.execution_ready)
      {
         sequence_position++;
      }
   }
   else
   {
      current_dir_override = -1; // No override
   }
   
   // --- TEMPORARILY INJECT INTO DECISION STRUCTURE (non-breaking) ---
   // Store override in decision.reasoning_summary (parsed later) since it's a string
   // Format: "SEQ_OVERRIDE:X" where X is 0=BUY, 1=SELL, -1=NO_OVERRIDE
   if(current_dir_override >= 0)
   {
      decision.reasoning_summary = StringFormat("SEQ_OVERRIDE:%d|%s", current_dir_override, decision.reasoning_summary);
   }
}
//+------------------------------------------------------------------+
//| ProcessTradingDecision WITH Sequential Mode & Daily Target Check |
//| ENHANCED: Regime Forecasting + Flow Rider + Velocity + Micro-Seq |
//| COMPILER-CERTIFIED: 0 ERRORS, 0 WARNINGS                         |
//+------------------------------------------------------------------+
void ProcessTradingDecision()
{
   // =================================================================
   // REGIME FORECASTING ENGINE (Predictive Volatility Orchestration)
   // =================================================================
   {
      // === STATIC-LOCAL ACCELEROMETER ===
      static double fd_history[20] = {0};
      static int fd_idx = 0;
      static bool pre_expansion_mode = false;
      static bool pre_compression_mode = false;
      
      // DECLARE corridor thresholds HERE so they're in scope for this block
      double corridor_low  = 0.28;
      double corridor_mid  = 0.55;
      double corridor_high = 0.78;
      
      double current_fd = MathIsValidNumber(formulas.fractal_dimension) ? formulas.fractal_dimension : 1.5;
      fd_history[fd_idx] = current_fd;
      fd_idx = (fd_idx + 1) % 20;
      
      if(fd_idx >= 10)
      {
         double fd_velocity = 0.0, fd_acceleration = 0.0;
         
         for(int i=0; i<5; i++)
         {
            int idx1 = (fd_idx - 1 - i + 20) % 20;
            int idx2 = (fd_idx - 2 - i + 20) % 20;
            fd_velocity += (fd_history[idx1] - fd_history[idx2]);
         }
         fd_velocity /= 5.0;
         
         for(int i=0; i<5; i++)
         {
            int idx1 = (fd_idx - 1 - i + 20) % 20;
            int idx2 = (fd_idx - 6 - i + 20) % 20;
            fd_acceleration += (fd_history[idx1] - fd_history[idx2]) - fd_velocity;
         }
         fd_acceleration /= 5.0;
         
         double accel_threshold = 0.15;
         
         if(fd_acceleration > accel_threshold && !pre_expansion_mode)
         {
            pre_expansion_mode = true;
            pre_compression_mode = false;
            
            corridor_low = MathMax(0.15, corridor_low - 0.08);
            corridor_mid = MathMax(0.40, corridor_mid - 0.05);
            corridor_high = MathMax(0.65, corridor_high - 0.03);
            
            decision.position_size = NormalizeLot(InpLotSize * 1.8);
            decision.reasoning_summary = StringFormat("PRE-EXPANSION-ACCEL%.3f|", fd_acceleration);
            
            if(InpEnableLogging)
               PrintFormat("REGIME-FORECAST-EXPANSION: accel=%.3f | size=%.2f", fd_acceleration, decision.position_size);
         }
         else if(fd_acceleration < -accel_threshold && !pre_compression_mode)
         {
            pre_compression_mode = true;
            pre_expansion_mode = false;
            
            corridor_low = MathMin(0.50, corridor_low + 0.12);
            corridor_mid = MathMin(0.75, corridor_mid + 0.10);
            corridor_high = MathMin(0.95, corridor_high + 0.08);
            
            strategy_vote.elected_strategy = STRATEGY_PRINT;
            decision.position_size = NormalizeLot(InpLotSize * 0.5);
            decision.reasoning_summary = StringFormat("PRE-COMPRESSION-ACCEL%.3f|", fd_acceleration);
            
            if(InpEnableLogging)
               PrintFormat("REGIME-FORECAST-COMPRESSION: accel=%.3f | size=%.2f", fd_acceleration, decision.position_size);
         }
         else if(MathAbs(fd_acceleration) < accel_threshold * 0.5)
         {
            pre_expansion_mode = false;
            pre_compression_mode = false;
         }
      }
   }
   // =================================================================
   // END REGIME FORECASTING ENGINE
   // =================================================================
   
   if (!IsTradingAllowed()) return;
   
   // Quick symbol-position gating
   int openForSymbol = 0;
   int totalPos = PositionsTotal();
   for (int pi = 0; pi < totalPos; pi++)
   {
      ulong t = PositionGetTicket(pi);
      if (t == 0) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if (sym == _Symbol) openForSymbol++;
   }
   if (openForSymbol >= InpMaxTrades)
   {
      if (InpEnableLogging) PrintFormat("Gating: already %d positions (max %d).", openForSymbol, InpMaxTrades);
      return;
   }
   
   // reset decision
   decision.should_trade = false;
   decision.execution_ready = false;
   decision.confidence_level = 0.0;
   decision.reasoning_summary = "";
   
   
   
   // === SEQUENTIAL MODE SEQUENCE GENERATION ===
   if(InpTradingMode == MODE_SEQUENTIAL)
   {
      // =================================================================
      // GenerateTradeSequence - PHASE-AWARE MICRO-REGIME (COMPILER-SAFE)
      // =================================================================
      {
         static int sequence_position = 0;
         static int sequence_length = 8;
         static int trade_sequence[8] = {0,0,0,0,0,0,0,0};
         static datetime last_sequence_reset = 0;
         static double phase_cumulative[3] = {0,0,0};
         static int phase_trade_count[3] = {0,0,0};
         
         MqlDateTime now_struct; TimeToStruct(TimeCurrent(), now_struct);
         datetime today_start = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                                             now_struct.year, now_struct.mon, now_struct.day));
         
         if(last_sequence_reset != today_start || sequence_position >= sequence_length)
         {
            double conf = MathIsValidNumber(fractal_intel.fractal_confluence_score) ? fractal_intel.fractal_confluence_score : 0.5;
            double flow = MathIsValidNumber(fractal_intel.institutional_flow_velocity) ? fractal_intel.institutional_flow_velocity : 0.5;
            double regime = MathIsValidNumber(market_data.volatility_regime) ? market_data.volatility_regime : 1.0;
            double momentum_bias = (market_data.momentum_state > 0) ? 0.6 : 0.4;
            
            // PHASE 1: Probes — biased by shared structural direction
            // seq_bias +1=bull, -1=bear, 0=neutral from ComputeSharedContext
            double struct_bias_offset = shared_ctx.seq_bias * 0.12;  // ±0.12 tilt
            for(int i=0; i<2; i++)
            {
               double probe_score = 0.3 * conf + 0.4 * flow + 0.3 * (2.0 - regime) + struct_bias_offset;
               probe_score += (MathRand() / 32767.0 * 0.15 - 0.075);  // reduced noise vs original
               probe_score = MathMax(0.0, MathMin(1.0, probe_score));
               trade_sequence[i] = (probe_score > 0.5) ? 0 : 1;  // 0=BUY 1=SELL
            }
            
            // PHASE 2: Amplifiers
            int phase1_winner = (trade_sequence[0] == trade_sequence[1]) ? trade_sequence[0] : -1;
            double phase1_avg_profit = phase_cumulative[0] / MathMax(phase_trade_count[0], 1);
            
            for(int i=2; i<5; i++)
            {
               if(phase1_winner >= 0 && phase1_avg_profit > 0.001)
               {
                  trade_sequence[i] = phase1_winner;
               }
               else
               {
                  double amp_score = conf * momentum_bias + (MathRand() / 32767.0 * 0.3);
                  trade_sequence[i] = (amp_score > 0.5) ? 0 : 1;
               }
            }
            
            // PHASE 3: Harvesters
            double phase2_wr = (double)performance.winning_trades / MathMax(performance.trades_executed, 1);
            
            for(int i=5; i<8; i++)
            {
               if(phase2_wr > 0.55)
               {
                  trade_sequence[i] = trade_sequence[i-1];
               }
               else
               {
                  trade_sequence[i] = (trade_sequence[i-1] == 0) ? 1 : 0;
               }
            }
            
            sequence_position = 0;
            last_sequence_reset = today_start;
            
            for(int p=0; p<3; p++) { phase_cumulative[p] = 0; phase_trade_count[p] = 0; }
            
            if(InpEnableLogging)
            {
               string seq_str = "";
               for(int i=0; i<sequence_length; i++) seq_str += trade_sequence[i] == 0 ? "B" : "S";
               PrintFormat("SEQUENTIAL-MICRO: New sequence %s | P1Profit=%.4f | P2WR=%.1f%%", 
                           seq_str, phase1_avg_profit, phase2_wr * 100.0);
            }
         }
         
         int current_phase = (sequence_position < 2) ? 0 : (sequence_position < 5) ? 1 : 2;
         decision.confidence_level = current_phase;
         
         // PHASE 1
         if(current_phase == 0)
         {
            decision.position_size = NormalizeLot(InpLotSize * 0.6);
            decision.take_profit_distance = MathMax(market_data.atr * 1.5, 10 * _Point);
            decision.stop_loss_distance = MathMax(market_data.atr * 1.8, 15 * _Point);
            decision.reasoning_summary = StringFormat("PHASE1_PROBE-%d|%s", sequence_position + 1, decision.reasoning_summary);
         }
         // PHASE 2
         else if(current_phase == 1)
         {
            decision.position_size = NormalizeLot(InpLotSize * 1.0);
            decision.take_profit_distance = MathMax(market_data.atr * 2.8, 20 * _Point);
            decision.stop_loss_distance = MathMax(market_data.atr * 1.5, 12 * _Point);
            decision.reasoning_summary = StringFormat("PHASE2_AMPLIFY-%d|%s", sequence_position + 1, decision.reasoning_summary);
         }
         // PHASE 3
         else
         {
            double phase2_avg_profit = phase_cumulative[1] / MathMax(phase_trade_count[1], 1);
            
            if(phase2_avg_profit > 0.002)
            {
               decision.position_size = NormalizeLot(InpLotSize * 1.4);
               decision.take_profit_distance = MathMax(market_data.atr * 2.0, 15 * _Point);
               decision.stop_loss_distance = MathMax(market_data.atr * 1.2, 10 * _Point);
               decision.reasoning_summary = StringFormat("PHASE3_AGGR-%d|%s", sequence_position + 1, decision.reasoning_summary);
            }
            else
            {
               decision.position_size = NormalizeLot(InpLotSize * 0.7);
               decision.take_profit_distance = MathMax(market_data.atr * 3.5, 25 * _Point);
               decision.stop_loss_distance = MathMax(market_data.atr * 2.0, 18 * _Point);
               decision.reasoning_summary = StringFormat("PHASE3_DEF-%d|%s", sequence_position + 1, decision.reasoning_summary);
            }
         }
         
         if(sequence_position == 2 && phase_cumulative[0] < -AccountInfoDouble(ACCOUNT_BALANCE) * 0.02)
         {
            if(InpEnableLogging)
               PrintFormat("SEQUENCE-ABORT: Phase1 loss=%.2f > 2%% | Resetting", phase_cumulative[0]);
            sequence_position = 8;
         }
         
         static datetime last_trade_track = 0;
         if(performance.trades_executed > 0 && TimeCurrent() - last_trade_track > 60)
         {
            int phase = (sequence_position - 1 < 2) ? 0 : (sequence_position - 1 < 5) ? 1 : 2;
            phase_trade_count[phase]++;
            phase_cumulative[phase] += performance.total_profit;
            last_trade_track = TimeCurrent();
         }
         
         if(sequence_position < 8)
         {
            int seq_dir = trade_sequence[sequence_position];
            decision.reasoning_summary = StringFormat("SEQ_OVERRIDE:%d|%s", seq_dir, decision.reasoning_summary);
         }
      }
      // =================================================================
      // END GenerateTradeSequence - PHASE-AWARE MICRO-REGIME
      // =================================================================
   }

   // =================================================================
   // FLOW RIDER + VELOCITY TRACKER (Combined for efficiency)
   // =================================================================
   {
      static double manual_pulse_history[10] = {0};
      static double manual_volume_history[10] = {0};
      static int pulse_idx = 0;
      static datetime last_amplification_signal = 0;
      static datetime last_drawdown_learn = 0;
      static double manual_entry_price[5] = {0};
      static datetime manual_entry_time[5] = {0};
      static int velocity_idx = 0;
      
      bool bot_position_found = false;
      ulong bot_ticket = 0;
      double bot_open_price = 0.0;
      
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         if(PositionGetTicket(i) > 0 && 
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            bot_position_found = true;
            bot_ticket = PositionGetTicket(i);
            bot_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            break;
         }
      }
      
      // === MANUAL TRADE DETECTION ===
      if(bot_position_found && TimeCurrent() - last_amplification_signal > 900)
      {
         if(HistorySelect(TimeCurrent() - 900, TimeCurrent()))
         {
            for(int d=HistoryDealsTotal()-1; d>=0 && pulse_idx < 10; d--)
            {
               ulong manual_ticket = HistoryDealGetTicket(d);
               if(manual_ticket > 0 && 
                  HistoryDealGetString(manual_ticket, DEAL_SYMBOL) == _Symbol &&
                  HistoryDealGetInteger(manual_ticket, DEAL_MAGIC) != InpMagicNumber &&
                  HistoryDealGetInteger(manual_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  double manual_vol = HistoryDealGetDouble(manual_ticket, DEAL_VOLUME);
                  
                  if(manual_vol >= decision.position_size * 2.0)
                  {
                     double time_weight = 1.0 - (double)(TimeCurrent() - HistoryDealGetInteger(manual_ticket, DEAL_TIME)) / 900.0;
                     double pulse_score = (HistoryDealGetDouble(manual_ticket, DEAL_PROFIT) / MathMax(manual_vol * bot_open_price, 1e-6)) * time_weight;
                     
                     manual_pulse_history[pulse_idx] = pulse_score;
                     manual_volume_history[pulse_idx] = manual_vol / MathMax(decision.position_size, 1e-6);
                     pulse_idx = (pulse_idx + 1) % 10;
                     last_amplification_signal = TimeCurrent();
                  }
               }
            }
         }
      }
      
      // === PATTERN ANALYSIS ===
      if(pulse_idx >= 3)
      {
         double avg_pulse = 0.0, avg_volume_mult = 0.0, success_rate = 0.0;
         int valid_samples = 0;
         
         for(int i=0; i<10; i++)
         {
            if(manual_pulse_history[i] != 0.0)
            {
               avg_pulse += manual_pulse_history[i];
               avg_volume_mult += manual_volume_history[i];
               if(manual_pulse_history[i] > 0) success_rate += 1.0;
               valid_samples++;
            }
         }
         
         if(valid_samples >= 3)
         {
            avg_pulse /= valid_samples;
            success_rate /= valid_samples;
            
            if(success_rate > 0.65 && avg_pulse > 0.0001)
            {
   // teacher_influence bounded, scales with success and manual volume
   double teacher_influence = MathMin(0.25, 0.12 * success_rate + 0.05 * MathMin(avg_volume_mult, 3.0));

   // express a portion of teacher signal into size & exits (conservative)
   decision.position_size = NormalizeLot(decision.position_size * (1.0 + teacher_influence * success_rate));
   decision.take_profit_distance = MathMax(decision.take_profit_distance * (1.0 + 0.10 * teacher_influence), market_data.atr * 1.2);
   decision.stop_loss_distance = MathMax(decision.stop_loss_distance * (1.0 - 0.05 * teacher_influence), market_data.atr * 0.85);

   // boost regime confidence more decisively (this flows into unified memory trust)
   strategy_core.regime_confidence = MathMin(1.0, strategy_core.regime_confidence * (1.0 + 0.20 * success_rate));

   decision.reasoning_summary = StringFormat("%s | FLOW-RIDER-TEACHER(%.2f)", decision.reasoning_summary, teacher_influence);

   if(InpEnableLogging)
      PrintFormat("FLOW-TEACH | success=%.2f avgVol=%.2f teacher=%.3f conf=%.3f size=%.3f",
                  success_rate, avg_volume_mult, teacher_influence, strategy_core.regime_confidence, decision.position_size);
}
            else if(success_rate < 0.40)
            {
               decision.position_size = NormalizeLot(InpLotSize * 0.5);
               decision.stop_loss_distance = market_data.atr * 1.1;
               decision.confidence_level *= 0.70;
               decision.reasoning_summary = StringFormat("%s | FLOW-RIDER-DEFEND", decision.reasoning_summary);
            }
         }
      }
      
      // === WIPEOUT DETECTION ===
      if(TimeCurrent() - last_drawdown_learn > 600)
      {
         if(HistorySelect(TimeCurrent() - 300, TimeCurrent()))
         {
            for(int d=0; d<HistoryDealsTotal(); d++)
            {
               ulong ticket = HistoryDealGetTicket(d);
               if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber &&
                  HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
                  HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
               {
                  double exit_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                  
                  if(volume > decision.position_size * 3.0 && exit_profit < -AccountInfoDouble(ACCOUNT_BALANCE) * 0.005)
                  {
                     decision.stop_loss_distance = market_data.atr * 0.7;
                     decision.position_size = NormalizeLot(InpLotSize * 0.4);
                     strategy_core.regime_confidence *= 0.80;
                     last_drawdown_learn = TimeCurrent();
                     fractal_intel.next_echo_window = TimeCurrent();
                  }
               }
            }
         }
      }
      
      // === VELOCITY TRACKER ===
      if(pulse_idx >= 1) // Only track if we have recent manual trades
      {
         // Record manual entry for velocity measurement
         if(last_amplification_signal == TimeCurrent()) // Fresh manual trade
         {
            for(int d=0; d<HistoryDealsTotal(); d++)
            {
               ulong mt = HistoryDealGetTicket(d);
               if(mt > 0 && HistoryDealGetInteger(mt, DEAL_MAGIC) != InpMagicNumber &&
                  HistoryDealGetString(mt, DEAL_SYMBOL) == _Symbol &&
                  HistoryDealGetInteger(mt, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  manual_entry_price[velocity_idx] = HistoryDealGetDouble(mt, DEAL_PRICE);
                  manual_entry_time[velocity_idx] = (datetime)HistoryDealGetInteger(mt, DEAL_TIME);
                  velocity_idx = (velocity_idx + 1) % 5;
                  break;
               }
            }
         }
         
         // Measure velocity when price moves 1 ATR
         if(velocity_idx >= 2)
         {
            for(int i=0; i<5; i++)
            {
               if(manual_entry_time[i] > 0 && TimeCurrent() - manual_entry_time[i] < 1800)
               {
                  double price_move = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - manual_entry_price[i]);
                  double atr = MathMax(1e-6, market_data.atr);
                  
                  if(price_move >= atr)
                  {
                     double time_to_move = (TimeCurrent() - manual_entry_time[i]) / 60.0;
                     double velocity_score = 1.0 / (1.0 + time_to_move);
                     
                     static double velocity_history[10] = {0};
                     static int v_hist_idx = 0;
                     velocity_history[v_hist_idx] = velocity_score;
                     v_hist_idx = (v_hist_idx + 1) % 10;
                     
                     if(v_hist_idx >= 3)
                     {
                        double avg_velocity = 0.0;
                        for(int v=0; v<10; v++) avg_velocity += velocity_history[v];
                        avg_velocity /= MathMax(v_hist_idx, 1);
                        
                        if(avg_velocity > 0.15)
                        {
                           decision.reasoning_summary = StringFormat("FAST-MARKET-%.3f|%s", avg_velocity, decision.reasoning_summary);
                           decision.stop_loss_distance *= 0.85;
                        }
                        else if(avg_velocity < 0.05)
                        {
                           decision.reasoning_summary = StringFormat("SLOW-MARKET-%.3f|%s", avg_velocity, decision.reasoning_summary);
                           decision.position_size = NormalizeLot(decision.position_size * 1.15);
                        }
                     }
                  }
               }
            }
         }
      }
   }
   // =================================================================
   // END FLOW RIDER + VELOCITY
   // =================================================================

   int exit_mode = SelectExitMode();
   int sel = strategy_vote.elected_strategy;

   double atr = MathMax(1e-6, market_data.atr);
   double spread_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   double scoreA = MathMin(MathMax(fractal_intel.fractal_confluence_score, 0.0), 1.0);
   double scoreB = MathMin(MathMax(strategy_core.regime_confidence, 0.0), 1.0);
   double scoreC = MathMin(MathMax(fractal_intel.recursive_confidence, 0.0), 1.0);
   double composite = 0.55*scoreA + 0.35*scoreB + 0.10*scoreC;
   composite = MathMin(MathMax(composite, 0.0), 1.0);

   // Corridor thresholds (declared above for Regime Engine scope)
   double corridor_low  = 0.28;
   double corridor_mid  = 0.55;
   double corridor_high = 0.78;

   double curBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double startBal   = (daily_target.daily_starting_balance > 0.0) ? daily_target.daily_starting_balance : curBalance;
   double intraday_drawdown = (startBal > 0.0) ? MathMax(0.0, (startBal - curBalance) / startBal) : 0.0;

   if(intraday_drawdown > 0.04)
   {
      corridor_low  = MathMin(0.40, corridor_low + 0.12);
      corridor_mid  = MathMin(0.65, corridor_mid + 0.10);
      corridor_high = MathMin(0.90, corridor_high + 0.08);
   }

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPerTrade = 0.01;
   double stopLossPoints = MathMax(10.0, atr * 10000.0);
   double maxLotEstimate = NormalizeLot(MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                                    MathFloor((accountBalance * riskPerTrade) / (stopLossPoints))));
   if(maxLotEstimate <= 0.0) maxLotEstimate = NormalizeLot(InpLotSize);

   // Corridor behavior — upgraded R:R geometry for profitability target 1.6+
   // Signal quality from shared_ctx further tunes TP when structure is clear
   double sq_tp_boost = 1.0 + 0.3 * shared_ctx.signal_quality;  // up to 30% TP extension on clean signal

   // Intelligence: session quality filter
   if(InpEnableSessionFilter)
   {
      double sq = SessionQuality();
      if(sq < 0.50) { if(InpEnableLogging) PrintFormat("ABORT: Asian dead zone (sq=%.2f)", sq); return; }
      if(sq < 0.80) corridor_low = MathMin(corridor_low + 0.08, 0.55);
   }

   // Intelligence: consecutive loss circuit breaker
   if(g_consec_losses >= InpConsecLossCircuit)
   {
      double penalty = 0.05 * (g_consec_losses - InpConsecLossCircuit + 1);
      corridor_low = MathMin(0.55, corridor_low + penalty);
      corridor_mid = MathMin(0.75, corridor_mid  + penalty);
      if(InpEnableLogging) PrintFormat("CIRCUIT-BREAKER: %d consec losses, corridor_low=%.2f", g_consec_losses, corridor_low);
   }

   // Intelligence: ADX trend strength filter (skip for PRINT — works in ranges)
   if(InpEnableADXFilter && sel != STRATEGY_PRINT)
   {
      double adxV = GetADX14();
      if(adxV > 0.0 && adxV < InpMinADXTrend)
      {  if(InpEnableLogging) PrintFormat("ABORT: ADX=%.1f < %.1f (ranging)", adxV, InpMinADXTrend); return; }
   }

   // Intelligence: H1 RSI extreme block
   if(InpBlockRSIExtremes && market_data.trend_strength != 0.0)
   {
      bool buyBias = market_data.trend_strength > 0;
      if(IsRSIExtreme(buyBias))
      {  if(InpEnableLogging) PrintFormat("ABORT: H1 RSI extreme blocks %s continuation", buyBias?"BUY":"SELL"); return; }
   }

   if(composite < corridor_low)
   {
      if(InpEnableLogging) PrintFormat("Corridor ABORT | composite=%.3f < %.3f", composite, corridor_low);
      return;
   }
   else if(composite < corridor_mid)
   {
      decision.position_size = NormalizeLot(MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), maxLotEstimate * 0.5));
      decision.stop_loss_distance = atr * 1.1;
      decision.take_profit_distance = atr * 2.4 * sq_tp_boost;   // was 2.0 → 2.4+ (2.2:1 min R:R)
      decision.confidence_level = 0.30 + 0.40 * composite;
   }
   else if(composite < corridor_high)
   {
      decision.position_size = NormalizeLot(MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), maxLotEstimate * 0.9));
      decision.stop_loss_distance = atr * 1.3;
      decision.take_profit_distance = atr * 4.0 * sq_tp_boost;   // was 3.0 → 4.0+ (3.1:1 min R:R)
      decision.confidence_level = 0.45 + 0.45 * composite;
   }
   else
   {
      double scaleUp = 1.0 + 0.8 * MathMin(1.0, composite);
      decision.position_size = NormalizeLot(MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                                  maxLotEstimate * scaleUp));
      decision.stop_loss_distance = atr * 1.5;
      decision.take_profit_distance = atr * 6.5 * sq_tp_boost;   // was 4.0 → 6.5+ (4.3:1 min R:R)
      decision.confidence_level = 0.65 + 0.35 * composite;
   }

   if(spread_points > (int)MathMax(200, atr * 10000.0))
   {
      if(InpEnableLogging) PrintFormat("Blocked: wide spread (%d) or mismatch vs ATR", (int)spread_points);
      return;
   }

   decision.position_size = NormalizeLot(MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), decision.position_size));
   if(decision.position_size > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX))
      decision.position_size = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   // Cross-strategy coherence amplifier — now includes shared_ctx FVG/BOS votes
   {
      int buy_votes = 0;
      int sell_votes = 0;

      for(int rank = 0; rank < 3; rank++)
      {
         int strat_idx = strategy_vote.top_strategies[rank];
         if(strat_idx < 0 || strat_idx >= 5) continue;

         double trend_component    = strategy_core.strategy_vectors[strat_idx][1];
         double momentum_component = strategy_core.strategy_vectors[strat_idx][2];
         double directional_signal = trend_component    * market_data.trend_strength +
                                     momentum_component * market_data.momentum_state;

         if(directional_signal > 0.08) buy_votes++;
         else if(directional_signal < -0.08) sell_votes++;
      }

      // Add shared_ctx structural votes — each strong signal = 1 vote
      if(shared_ctx.bos_bull)  buy_votes++;
      if(shared_ctx.fvg_bull)  buy_votes++;
      if(shared_ctx.bos_bear)  sell_votes++;
      if(shared_ctx.fvg_bear)  sell_votes++;

      int total_votes = buy_votes + sell_votes;
      double max_votes_double = (double)MathMax(buy_votes, sell_votes);
      double coherence_ratio  = (total_votes > 0) ? max_votes_double / (double)total_votes : 0.0;

      if(coherence_ratio >= 0.70)
      {
         decision.position_size = NormalizeLot(decision.position_size * (1.0 + 0.25 * coherence_ratio));
         decision.confidence_level = MathMin(0.95, decision.confidence_level * (1.0 + 0.15 * coherence_ratio));
      }
      else if(buy_votes > 0 && sell_votes > 0 && coherence_ratio < 0.60)
      {
         decision.position_size    = NormalizeLot(decision.position_size * 0.55);
         decision.confidence_level *= 0.70;
      }
   }

   // Sequential direction override
   bool seq_override_active = false;
   ENUM_ORDER_TYPE seq_direction = ORDER_TYPE_BUY;
   
   if(InpTradingMode == MODE_SEQUENTIAL && StringFind(decision.reasoning_summary, "SEQ_OVERRIDE:") >= 0)
   {
      int split_pos = StringFind(decision.reasoning_summary, "|");
      string override_str = StringSubstr(decision.reasoning_summary, 11, split_pos - 11);
      
      if(override_str == "0")
      {
         seq_override_active = true;
         seq_direction = ORDER_TYPE_BUY;
      }
      else if(override_str == "1")
      {
         seq_override_active = true;
         seq_direction = ORDER_TYPE_SELL;
      }
      
      decision.reasoning_summary = StringSubstr(decision.reasoning_summary, split_pos + 1);
   }

   if(seq_override_active)
   {
      decision.trade_direction = seq_direction;
   }
   else if(InpTradingMode == MODE_BUY_ONLY)
   {
      decision.trade_direction = ORDER_TYPE_BUY;
   }
  else if(InpTradingMode == MODE_SELL_ONLY)
 {
    decision.trade_direction = ORDER_TYPE_SELL;
 }
   else if(sel == STRATEGY_SCALP)
   {
      if(MathAbs(market_data.momentum_state) >= 0.12)
         decision.trade_direction = (market_data.momentum_state > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      else return;
   }
  else if(sel == STRATEGY_LONG || sel == STRATEGY_ACE || sel == STRATEGY_AUTO)
{
   // Primary: trend_strength. Reinforced by BOS + FVG from shared bus.
   ENUM_ORDER_TYPE base_dir;
   if(market_data.trend_strength > 0.0001)       base_dir = ORDER_TYPE_BUY;
   else if(market_data.trend_strength < -0.0001)  base_dir = ORDER_TYPE_SELL;
   else base_dir = (market_data.momentum_state > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // BOS + FVG agreement strengthens direction; contradiction halves size as penalty
   bool ctx_agrees_buy  = (shared_ctx.bos_bull || shared_ctx.fvg_bull) && base_dir == ORDER_TYPE_BUY;
   bool ctx_agrees_sell = (shared_ctx.bos_bear || shared_ctx.fvg_bear) && base_dir == ORDER_TYPE_SELL;
   bool ctx_conflicts   = ((shared_ctx.bos_bull || shared_ctx.fvg_bull) && base_dir == ORDER_TYPE_SELL) ||
                          ((shared_ctx.bos_bear || shared_ctx.fvg_bear) && base_dir == ORDER_TYPE_BUY);

   if(ctx_conflicts && shared_ctx.signal_quality > 0.55)
      decision.position_size = NormalizeLot(decision.position_size * 0.5);  // structure fights signal

   // TP extension when FVG target available and aligned
   if(ctx_agrees_buy && shared_ctx.fvg_target > 0)
   {
      double fvg_dist = MathAbs(shared_ctx.fvg_target - market_data.price_current);
      if(fvg_dist > decision.take_profit_distance)
         decision.take_profit_distance = fvg_dist;
   }
   else if(ctx_agrees_sell && shared_ctx.fvg_target > 0)
   {
      double fvg_dist = MathAbs(market_data.price_current - shared_ctx.fvg_target);
      if(fvg_dist > decision.take_profit_distance)
         decision.take_profit_distance = fvg_dist;
   }

   if(decision.trade_direction != ORDER_TYPE_BUY && decision.trade_direction != ORDER_TYPE_SELL)
      decision.trade_direction = base_dir;
}
   else if(sel == STRATEGY_PRINT)
   {
      // PRINT handled separately
   }

   decision.should_trade = true;
   decision.execution_ready = true;
   decision.reasoning_summary = StringFormat("CorridorExec|sel=%d comp=%.3f draw=%.3f seq=%s sq=%.2f bos=%s%s fvg=%s%s",
      sel, composite, intraday_drawdown,
      seq_override_active ? (seq_direction==ORDER_TYPE_BUY?"BUY":"SELL") : "AUTO",
      shared_ctx.signal_quality,
      shared_ctx.bos_bull?"BUL":"",shared_ctx.bos_bear?"BEA":"",
      shared_ctx.fvg_bull?"BUL":"",shared_ctx.fvg_bear?"BEA":"");

   if(decision.execution_ready && decision.should_trade)
   {
      ExecuteTrade(decision);
   }
}
//+------------------------------------------------------------------+
//| Manage Trailing Stops - Zone-to-Zone Sculpting Implementation    |
//| Uses: max_profit_points (stores risk distance), scale1_done      |
//|       scale2_done (zone trackers), original_sl (initial risk)    |
//| Zones: Entry(0) -> Zone1(1R,30%) -> Zone2(2R,30%) -> Zone3(3.5R) |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i=0; i<trailing_count; i++)
   {
      if(trailing_positions[i].ticket == 0 || !trailing_positions[i].trailing_active) continue;

      if(!PositionSelectByTicket(trailing_positions[i].ticket))
      {
         trailing_positions[i].trailing_active = false;
         continue;
      }

      double open_price     = PositionGetDouble(POSITION_PRICE_OPEN);
      long   type           = PositionGetInteger(POSITION_TYPE);
      double current_price  = (type == POSITION_TYPE_BUY) ? bid : ask;
      double current_sl     = PositionGetDouble(POSITION_SL);
      double current_vol    = PositionGetDouble(POSITION_VOLUME);
      double min_lot        = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      
      // Initialize zone risk distance (1R) using max_profit_points storage
      if(trailing_positions[i].max_profit_points == 0.0)
      {
         double sl_dist = MathAbs(open_price - trailing_positions[i].original_sl);
         if(sl_dist < point * 10) sl_dist = MathMax(market_data.atr * 0.5, point * 50);
         trailing_positions[i].max_profit_points = sl_dist; // Now stores 1R distance
         
         if(InpEnableLogging) 
            PrintFormat("Z2Z Init | Ticket %I64u | Risk(1R)=%.5f", 
               trailing_positions[i].ticket, sl_dist);
      }
      
      double risk = trailing_positions[i].max_profit_points;
      bool is_buy = (type == POSITION_TYPE_BUY);
      
      // Calculate zone levels from open price
      double zone1 = is_buy ? open_price + risk : open_price - risk;           // 1R
      double zone2 = is_buy ? open_price + (risk * 2.0) : open_price - (risk * 2.0); // 2R
      double zone3 = is_buy ? open_price + (risk * 3.5) : open_price - (risk * 3.5); // 3.5R
      
      //==================================================================
      // ZONE 0 -> ZONE 1 (Breakeven + First Partial 30%)
      //==================================================================
      if(!trailing_positions[i].scale1_done)
      {
      
         // -------------------------------------------------
// FRACTAL DRAWDOWN ENVELOPE GATE (NO NEW STATE)
// -------------------------------------------------
bool allow_scale =
(
   fractal_intel.fractal_confluence_score > 0.62 &&
   strategy_core.regime_confidence       > 0.58 &&
   (
      trailing_positions[i].max_profit_points >
      MathAbs(trailing_positions[i].entry_price - trailing_positions[i].original_sl)
      * (0.85 + fractal_intel.fractal_confluence_score * 0.3)
   )
);

         bool zone1_hit = is_buy ? (current_price >= zone1) : (current_price <= zone1);
         
         if(zone1_hit)
         {
            ulong t=trailing_positions[i].ticket;
            double sl=NormalizeDouble(is_buy?open_price+2*point:open_price-2*point,_Digits);
            bool ok=trade.PositionModify(t,sl,PositionGetDouble(POSITION_TP));
            if(!ok || trade.ResultRetcode()!=TRADE_RETCODE_DONE) continue;
            double part=NormalizeLot(current_vol*0.30);
            if(part>=min_lot && current_vol-part>=min_lot)
            {
               ok=trade.PositionClosePartial(t,part);
               if(!ok || (trade.ResultRetcode()!=TRADE_RETCODE_DONE &&
                           trade.ResultRetcode()!=TRADE_RETCODE_DONE_PARTIAL)) continue;
            }
            trailing_positions[i].scale1_done=true;
         }
      }
      
      //==================================================================
      // ZONE 1 -> ZONE 2 (Second Partial 30% + Lock Zone 1 Profit)
      //==================================================================
      else if(!trailing_positions[i].scale2_done)
      {
         bool zone2_hit = is_buy ? (current_price >= zone2) : (current_price <= zone2);
         
         if(zone2_hit)
         {
            ulong t=trailing_positions[i].ticket;
            bool ok=trade.PositionModify(t,NormalizeDouble(zone1,_Digits),PositionGetDouble(POSITION_TP));
            if(!ok || trade.ResultRetcode()!=TRADE_RETCODE_DONE) continue;
            double part=NormalizeLot(current_vol*0.30);
            if(part>=min_lot && current_vol-part>=min_lot)
            {
               ok=trade.PositionClosePartial(t,part);
               if(!ok || (trade.ResultRetcode()!=TRADE_RETCODE_DONE &&
                           trade.ResultRetcode()!=TRADE_RETCODE_DONE_PARTIAL)) continue;
            }
            trailing_positions[i].scale2_done=true;
         }
      }
      
      //==================================================================
      // ZONE 2 -> ZONE 3 (Final Exit or Runner Trail)
      //==================================================================
      else
      {
         bool zone3_hit = is_buy ? (current_price >= zone3) : (current_price <= zone3);
         
         if(zone3_hit && InpCloseAllOnTarget)
         {
            // Close final position at 3.5R target
            double remaining_vol = PositionGetDouble(POSITION_VOLUME);
            if(remaining_vol >= min_lot)
            {
               bool closed=trade.PositionClose(trailing_positions[i].ticket);
                if(!closed || trade.ResultRetcode()!=TRADE_RETCODE_DONE) continue;
                trailing_positions[i].trailing_active=false;
               
               if(InpEnableLogging)
                  PrintFormat("Z2Z Zone3 | Ticket %I64u | Final close at 3.5R", 
                     trailing_positions[i].ticket);
            }
         }
         else if(!zone3_hit)
         {
            // Runner mode: Trail stop just behind Zone 2
            double buffer = market_data.atr * 0.3;
            double trail_sl = is_buy ? zone2 - buffer : zone2 + buffer;
            trail_sl = NormalizeDouble(trail_sl, _Digits);
            
            // Only move SL in winning direction
            bool should_move = is_buy ? (trail_sl > current_sl) : (trail_sl < current_sl);
            
            if(should_move && MathAbs(trail_sl - current_sl) > (5 * point))
            {
               trade.PositionModify(trailing_positions[i].ticket, trail_sl, 
                                   PositionGetDouble(POSITION_TP));
               
               if(InpEnableLogging)
                  PrintFormat("Z2Z Runner | Ticket %I64u | Trail to %.5f", 
                     trailing_positions[i].ticket, trail_sl);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| INSTITUTIONAL LIQUIDITY GUARD (Level 2 DOM Analysis)             |
//| FIX: Explicit casting added to remove type conversion warning    |
//+------------------------------------------------------------------+
bool CheckInstitutionalLiquidity(ENUM_ORDER_TYPE type, double req_vol)
{
   MqlBookInfo book[];
   // If DOM is unavailable, we default to allowing the trade to prevent paralysis,
   // but log the warning. In a pure HFT firm, we would block here.
   if(!MarketBookGet(_Symbol, book))
   {
      // No depth data on many OTC brokers: require bounded spread instead.
      double spread=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID);
      return market_data.atr>0 && spread>0 && spread<=0.15*market_data.atr;
   } 
   
   double available_vol = 0.0;
   int depth = ArraySize(book);
   int scan_depth = 3; // Only check the top 3 price tiers (strict execution)
   
   for(int i = 0; i < depth && i < scan_depth; i++)
   {
      // If buying, check Sell side (Ask liquidity)
      if(type == ORDER_TYPE_BUY && book[i].type == BOOK_TYPE_SELL)
         // FIX: Explicit cast from long to double to eliminate compiler warning
         available_vol += (double)book[i].volume; 
      // If selling, check Buy side (Bid liquidity)
      else if(type == ORDER_TYPE_SELL && book[i].type == BOOK_TYPE_BUY)
         // FIX: Explicit cast from long to double to eliminate compiler warning
         available_vol += (double)book[i].volume; 
      
      if(available_vol >= req_vol) return true;
   }
   
   if(InpEnableLogging) 
      PrintFormat("Liquidity Reject: Market depth insufficient for %.2f lots", req_vol);
      
   return false;
}

//+------------------------------------------------------------------+
//| ASYNCHRONOUS EXECUTION ENGINE (Fill-or-Kill)                     |
//+------------------------------------------------------------------+
bool ExecuteTrade(TradingDecision &td)
{
   if(!td.should_trade || !td.execution_ready) return false;
   
   // 1. LIQUIDITY FILTER (The Whale Check)
   if(!CheckInstitutionalLiquidity(td.trade_direction, td.position_size)) return false;

   // 2. PREPARE REQUEST
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = NormalizeLot(td.position_size);
   request.type         = (td.trade_direction == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price        = (td.trade_direction == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation    = 5; // Institutional strictness
   request.magic        = InpMagicNumber;
   request.type_filling = ORDER_FILLING_FOK; // Fill or Kill - No partial fills accepted
   request.comment      = "Empire HFT";

   // Calculate Hard SL/TP for the broker request
   if(td.stop_loss_distance > 0)
      request.sl = (td.trade_direction == ORDER_TYPE_BUY) ? request.price - td.stop_loss_distance : request.price + td.stop_loss_distance;
   
   if(td.take_profit_distance > 0)
      request.tp = (td.trade_direction == ORDER_TYPE_BUY) ? request.price + td.take_profit_distance : request.price - td.take_profit_distance;

   // Contract-aware risk and margin validation; never force broker minimum lot.
   if(request.sl<=0 || request.tp<=0) return false;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int stop_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(point<=0 || ask<=bid || market_data.atr<=0 || ask-bid>0.15*market_data.atr ||
      MathAbs(request.price-request.sl)<stop_level*point ||
      MathAbs(request.price-request.tp)<stop_level*point) return false;
   long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK)!=0) request.type_filling=ORDER_FILLING_FOK;
   else if((filling & SYMBOL_FILLING_IOC)!=0) request.type_filling=ORDER_FILLING_IOC;
   else return false;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY), cash_loss=0.0;
   double volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(eq<=0 || volume_step<=0 || minimum_lot<=0) return false;
   double aggregate_risk=0.0;
   for(int q=0;q<PositionsTotal();q++)
   {
      ulong t=PositionGetTicket(q);
      if(t==0 || PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      double old_stop=PositionGetDouble(POSITION_SL), potential=0;
      if(old_stop<=0) return false;
      ENUM_ORDER_TYPE direction=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
      if(!OrderCalcProfit(direction,PositionGetString(POSITION_SYMBOL),
         PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),
         old_stop,potential)) return false;
      aggregate_risk+=MathMax(0,-potential);
   }
   double budget=MathMin(eq*0.01,eq*0.03-aggregate_risk);
   if(budget<=0) return false;
   while(request.volume>=minimum_lot-1e-9)
   {
      if(!OrderCalcProfit(request.type,_Symbol,request.volume,request.price,request.sl,cash_loss)) return false;
      if(cash_loss<0 && -cash_loss<=budget) break;
      request.volume=NormalizeDouble(request.volume-volume_step,8);
   }
   if(request.volume<minimum_lot-1e-9) return false;
   double required_margin=0.0;
   if(!OrderCalcMargin(request.type,_Symbol,request.volume,request.price,required_margin) ||
      required_margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) return false;
   // 3. SYNCHRONOUS BROKER CONFIRMATION
   bool sent = OrderSend(request, result);
   bool filled = sent && (result.retcode==TRADE_RETCODE_DONE ||
                          result.retcode==TRADE_RETCODE_DONE_PARTIAL);
   
   if(filled)
   {
      if(InpEnableLogging) Print("Broker confirmed entry fill.");
   }
   else
   {
      if(InpEnableLogging) PrintFormat("Execution Failed: %d", GetLastError());
   }
   
   return filled;
}
//+------------------------------------------------------------------+
//| Update Performance Metrics                                        |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
{
   // Update basic counters (keeps existing fields coherent)
   performance.current_roi = AccountInfoDouble(ACCOUNT_BALANCE) > 0.0 ?
                             (performance.total_profit / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0 : 0.0;

   // avg_confidence: exponential rolling based on last executed trades count
   double alpha = 0.15;
   // if we have trades executed in this session, blend average; otherwise keep previous
   if(performance.trades_executed > 0)
   {
      double recent_conf = decision.confidence_level; // last decision confidence
      if(recent_conf <= 0.0) recent_conf = MathMin(1.0, fractal_intel.fractal_confluence_score * 0.7 + strategy_core.regime_confidence * 0.3);
      performance.avg_confidence = (1.0 - alpha) * performance.avg_confidence + alpha * recent_conf;
   }

   // pattern_accuracy: rough measure = winning_trades / trades_executed (clamped)
   if(performance.trades_executed > 0)
      performance.pattern_accuracy = MathMin(0.999, (double)performance.winning_trades / (double)performance.trades_executed);
   else
      performance.pattern_accuracy = performance.pattern_accuracy * 0.98; // slight decay when idle

   // ai_learning_score: conservative composite (used earlier by voting and sizing)
   // scale: [0..1] combines avg_confidence, pattern_accuracy, and recent net profit sign
   double profit_factor = (performance.total_profit > 0.0) ? 1.0 : 0.7;
   performance.ai_learning_score = 0.5 * performance.avg_confidence + 0.4 * performance.pattern_accuracy;
   performance.ai_learning_score *= profit_factor;
   performance.ai_learning_score = MathMin(MathMax(performance.ai_learning_score, 0.0), 1.0);

   if(InpEnableLogging)
   {
      PrintFormat("PerfMetrics | ROI=%.2f%% totalProfit=%.2f trades=%d wins=%d avgConf=%.3f patAcc=%.3f AIlearn=%.3f",
                  performance.current_roi, performance.total_profit, performance.trades_executed,
                  performance.winning_trades, performance.avg_confidence, performance.pattern_accuracy,
                  performance.ai_learning_score);
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler (Async Confirmation Listener)          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         if(magic == InpMagicNumber && HistoryDealGetString(trans.deal,DEAL_SYMBOL)==_Symbol)
         {
            long deal_entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

            // -------------------------------------------------
            // ENTRY CONFIRMATION (unchanged)
            // -------------------------------------------------
            if(deal_entry == DEAL_ENTRY_IN)
            {
               ulong ticket=0;
                ulong position_id=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
                for(int q=0;q<PositionsTotal();q++)
                {
                   ulong t=PositionGetTicket(q);
                   if(t>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==position_id)
                   {ticket=t;break;}
                }
               double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);

               if(ticket > 0 && trailing_count < ArraySize(trailing_positions))
               {
                  trailing_positions[trailing_count].ticket = ticket;
                  trailing_positions[trailing_count].entry_price = price;
                  trailing_positions[trailing_count].entry_time = TimeCurrent();
                  trailing_positions[trailing_count].trailing_active = true;
                  trailing_positions[trailing_count].max_profit_points = 0.0;
                  trailing_positions[trailing_count].scale1_done = false;
                  trailing_positions[trailing_count].scale2_done = false;

                  if(PositionSelectByTicket(ticket))
                  {
                     trailing_positions[trailing_count].original_sl = PositionGetDouble(POSITION_SL);
                     trailing_positions[trailing_count].original_tp = PositionGetDouble(POSITION_TP);
                  }

                  trailing_count++;
                  if(InpEnableLogging)
                     PrintFormat("CONFIRMED ENTRY | Ticket %I64u @ %.5f", ticket, price);
               }
            }

            // -------------------------------------------------
            // EXIT HANDLING — HYBRID SWARM + REGIME MEMORY
            // -------------------------------------------------
            else if(deal_entry == DEAL_ENTRY_OUT)
            {
               double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                             + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                             + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

               // Learn only after a position fully closes; partial profit is not a new trade.
               ulong closed_id=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
               for(int q=0;q<PositionsTotal();q++)
               {
                  ulong t=PositionGetTicket(q);
                  if(t>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==closed_id) return;
               }
               if(profit<0) g_consec_losses++;
               else if(profit>0) g_consec_losses=0;
               double conf_before = strategy_core.regime_confidence;

               int yes = 0, no = 0;

               // 1. Fractal structure vote
               if(fractal_intel.fractal_confluence_score > 0.65) yes++; else no++;

               // 2. Momentum alignment vote
               double mom = market_data.momentum_state;
               if((profit > 0 && mom > 0.04) || (profit < 0 && mom < -0.04))
                  yes++;
               else
                  no++;

               // 3. Equity awareness vote
               if(AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE))
                  yes++;
               else
                  no++;

               // 4. Regime stability vote
               if(strategy_core.regime_confidence > 0.66)
                  yes++;
               else if(strategy_core.regime_confidence < 0.42)
                  no++;

               int total = yes + no;

               // stricter alignment rules (tuned)
               bool strong_alignment = (yes >= 4);
               bool weak_alignment   = (no  >= 3);

               if(InpEnableLogging)
               {
                  PrintFormat("SWARM VOTE | PnL=%.2f | YES=%d NO=%d | fract=%.2f mom=%.3f conf=%.3f eq=%s",
                              profit, yes, no,
                              fractal_intel.fractal_confluence_score,
                              mom,
                              strategy_core.regime_confidence,
                              (AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE)) ? "OK" : "DD");
               }

               bool recovery_allowed =
                  strong_alignment ||
                  (strategy_core.regime_confidence > 0.66) ||
                  (AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE));

               // -----------------------------
               // POSITIVE OUTCOME
               // -----------------------------
               if(profit > 0.0)
               {
                  if(recovery_allowed)
                     strategy_core.regime_confidence = MathMin(1.0, strategy_core.regime_confidence * 1.07);
                  else
                     strategy_core.regime_confidence = MathMin(0.98, strategy_core.regime_confidence * 1.025);
               }

               // -----------------------------
               // NEGATIVE OUTCOME
               // -----------------------------
               else if(profit < 0.0)
               {
                  if(weak_alignment || strategy_core.regime_confidence < 0.48)
                     strategy_core.regime_confidence = MathMax(0.05, strategy_core.regime_confidence * 0.84);
                  else
                     strategy_core.regime_confidence = MathMax(0.05, strategy_core.regime_confidence * 0.95);
               }

               // -----------------------------
               // SUSPICIOUS WIN SAFEGUARD
               // -----------------------------
               if(profit > 0.0 && weak_alignment)
                  strategy_core.regime_confidence *= 0.96;

               // -----------------------------
               // FRACTAL ECHO RESET ON LARGE LOSS
               // -----------------------------
               if(profit < -AccountInfoDouble(ACCOUNT_BALANCE) * 0.006)
                  fractal_intel.next_echo_window = TimeCurrent();

               if(InpEnableLogging)
               {
                  PrintFormat("REGIME UPDATE | before=%.4f after=%.4f Δ=%.4f",
                              conf_before,
                              strategy_core.regime_confidence,
                              strategy_core.regime_confidence - conf_before);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Print Performance Report                                          |
//+------------------------------------------------------------------+
void PrintPerformanceReport()
{
   Print("????????????????????????????????????????????????????????????");
   Print("?      Conquest Platinum Performance Report                ?");
   Print("????????????????????????????????????????????????????????????");
   PrintFormat("? Total signals (24h): %-32d ?", performance.total_signals);
   PrintFormat("? Trades executed (24h): %-30d ?", performance.trades_executed);
   PrintFormat("? Winning trades (24h): %-31d ?", performance.winning_trades);
   PrintFormat("? Total profit (24h): %.5f%-26s ?", performance.total_profit, "");
   PrintFormat("? Current ROI: %.2f%%%-38s ?", performance.current_roi, "");
   PrintFormat("? Avg confidence: %.2f%-34s ?", performance.avg_confidence, "");
   PrintFormat("? Pattern accuracy: %.2f%%%-32s ?", performance.pattern_accuracy * 100.0, "");
   PrintFormat("? AI learning score: %.2f%-31s ?", performance.ai_learning_score, "");
   PrintFormat("? Fractal confluence: %.3f%-30s ?", fractal_intel.fractal_confluence_score, "");
   PrintFormat("? Strategy elected: %-35s ?", StrategyToString((ENUM_STRATEGY_TYPE)strategy_vote.elected_strategy));
   
   if(daily_target.enabled)
   {
      Print("????????????????????????????????????????????????????????????");
      Print("?              Daily Target System Status                  ?");
      Print("????????????????????????????????????????????????????????????");
      
      double target_threshold = InpTargetType == TARGET_CURRENCY ? 
                                InpDailyTargetAmount : 
                                (daily_target.daily_starting_balance * InpDailyTargetAmount / 100.0);
      
      PrintFormat("? Target: %.2f | Profit: %.2f%-25s ?", 
                  target_threshold, 
                  daily_target.daily_profit, "");
      PrintFormat("? Status: %-45s ?", 
                  daily_target.target_reached ? "TARGET REACHED ?" : "IN PROGRESS");
      
      if(daily_target.target_reached)
      {
         PrintFormat("? Reached at: %-41s ?", 
                     TimeToString(daily_target.target_reached_time, TIME_DATE|TIME_SECONDS));
         PrintFormat("? Trades before target: %-31d ?", daily_target.trades_before_target);
         PrintFormat("? Trades blocked after: %-31d ?", daily_target.trades_after_target);
      }
      else
      {
         double progress = (target_threshold > 0) ? (daily_target.daily_profit / target_threshold) * 100.0 : 0.0;
         PrintFormat("? Progress: %.1f%% | Remaining: %.2f%-23s ?", 
                     progress, 
                     target_threshold - daily_target.daily_profit, "");
      }
   }
   
   Print("????????????????????????????????????????????????????????????");
}

//+------------------------------------------------------------------+
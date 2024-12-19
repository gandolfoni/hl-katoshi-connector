katoshi_strat_optimized

// This Pine Script™ code is subject to the terms of the Mozilla Public License 2.0
// © katoshi_ai - Optimized version

//@version=5
strategy("Hyperliquid Strategy", 
    overlay=true, 
    max_lines_count=500, 
    default_qty_value=100, 
    initial_capital=1000, 
    commission_value=0.0336, 
    pyramiding=3, 
    process_orders_on_close=true,
    calc_on_order_fills=false, 
    calc_on_every_tick=false, 
    default_qty_type=strategy.percent_of_equity, 
    commission_type=strategy.commission.percent, 
    currency="USD"
)

// =================== Input Groups =================== //
var string G_SETUP = "Setup"
var string G_BOT = "Bot Configuration"
var string G_SIZE = "Position Sizing"
var string G_RISK = "Risk Management"
var string G_STRATEGY = "Strategy Parameters"

// =================== Configuration Inputs =================== //
bot_id = input.string(title="Bot ID", defval="", group=G_BOT)
bot_api_key = input.string(title="API Key", defval="", group=G_BOT)
bot_coin = input.string(title="Trading Pair", defval="", group=G_BOT)

// Leverage settings
bot_leverage = input.int(title="Leverage", defval=1, group=G_RISK)
bot_margin_mode = input.string(title="Margin Mode", defval="Isolated", options=["Isolated", "Cross"], group=G_RISK)
bot_update_leverage = input.bool(title="Update Leverage on Start", defval=true, group=G_RISK)

// Size settings
i_entry_size = input.float(title="Entry Size", defval=100, group=G_SIZE) * bot_leverage
i_entry_type = input.string(title="Entry Size Type", defval="%", options=["Contract", "%", "USD"], group=G_SIZE)

i_add_size = input.float(title="Add Size", defval=10, group=G_SIZE)
i_add_type = input.string(title="Add Size Type", defval="%", options=["Contract", "%", "USD"], group=G_SIZE)

i_remove_size = input.float(title="Remove Size", defval=10, group=G_SIZE)
i_remove_type = input.string(title="Remove Size Type", defval="%", options=["Contract", "%", "USD"], group=G_SIZE)

// Risk parameters
i_stop_loss = input.float(title="Stop Loss %", defval=2, minval=0.1, step=0.1, group=G_RISK)
i_take_profit = input.float(title="Take Profit %", defval=10, minval=0.1, group=G_RISK)
i_slippage = input.int(title="Max Slippage %", defval=5, group=G_RISK) / 100

// Strategy parameters
i_ema_fast = input.int(title="Fast EMA Length", defval=17, group=G_STRATEGY)
i_ema_slow = input.int(title="Slow EMA Length", defval=83, group=G_STRATEGY)

// =================== Strategy Indicators =================== //
// Moving Average Parameters
fast_length = input.int(title="Fast MA Length", defval=9, minval=1, group=G_STRATEGY)
slow_length = input.int(title="Slow MA Length", defval=21, minval=1, group=G_STRATEGY)
ma_type = input.string(title="MA Type", defval="EMA", options=["EMA", "SMA"], group=G_STRATEGY)

// Calculate Moving Averages
fast_ma = ma_type == "EMA" ? ta.ema(close, fast_length) : ta.sma(close, fast_length)
slow_ma = ma_type == "EMA" ? ta.ema(close, slow_length) : ta.sma(close, slow_length)

// =================== Strategy Logic =================== //

// Calculate indicators
var float ema_fast = ta.ema(close, i_ema_fast)
var float ema_slow = ta.ema(close, i_ema_slow)
var float atr = ta.atr(14)

// Entry conditions
var bool long_signal = ta.crossover(ema_fast, ema_slow)
var bool short_signal = ta.crossunder(ema_fast, ema_slow)

// Position management conditions
var bool should_add_long = (ta.crossunder(low, ema_slow) and close > open) or 
                          (close > ema_slow and close[1] < ema_slow)
var bool should_add_short = (ta.crossover(high, ema_slow) and close < open) or 
                           (close < ema_slow and close[1] > ema_slow)

var bool should_remove_long = close - open > atr
var bool should_remove_short = open - close > atr

// =================== Helper Functions =================== //

calcPositionSize(float base_size, string size_type) =>
    float final_qty = 0.0
    
    if size_type == "Contract"
        final_qty := base_size
    else if size_type == "%"
        position_value = strategy.equity * (base_size / 100)
        final_qty := position_value / (close * syminfo.pointvalue)
    else // USD
        final_qty := base_size / (close * syminfo.pointvalue)
    
    math.round(final_qty, 8)

// Price rounding functions
roundToTick(float price, bool round_up) =>
    tick_size = syminfo.mintick
    multiplier = 1 / tick_size
    round_up ? math.ceil(price * multiplier) / multiplier : 
               math.floor(price * multiplier) / multiplier

// =================== Position Management =================== //

// Track position state
var bool in_position = false
var bool is_long = false
var float entry_price = 0.0
var float stop_loss = 0.0
var float take_profit = 0.0

// Update position tracking
if strategy.position_size != 0
    in_position := true
    is_long := strategy.position_size > 0
    if strategy.position_size != strategy.position_size[1]  // Position changed
        entry_price := close
        
        // Calculate stop loss and take profit
        stop_loss := is_long ? 
            roundToTick(close * (1 - i_stop_loss/100), true) :
            roundToTick(close * (1 + i_stop_loss/100), false)
            
        take_profit := is_long ?
            roundToTick(close * (1 + i_take_profit/100), false) :
            roundToTick(close * (1 - i_take_profit/100), true)
else
    in_position := false

// =================== Strategy Execution =================== //

if not in_position
    if long_signal
        qty = calcPositionSize(i_entry_size, i_entry_type)
        strategy.entry("Long", strategy.long, qty=qty)
    else if short_signal
        qty = calcPositionSize(i_entry_size, i_entry_type)
        strategy.entry("Short", strategy.short, qty=qty)
else
    // Position sizing adjustments
    if is_long and should_add_long
        add_qty = calcPositionSize(i_add_size, i_add_type)
        strategy.order("Add Long", strategy.long, qty=add_qty)
    else if not is_long and should_add_short
        add_qty = calcPositionSize(i_add_size, i_add_type)
        strategy.order("Add Short", strategy.short, qty=add_qty)
        
    // Take profits
    if is_long and should_remove_long
        remove_qty = calcPositionSize(i_remove_size, i_remove_type)
        strategy.order("Remove Long", strategy.short, qty=remove_qty)
    else if not is_long and should_remove_short
        remove_qty = calcPositionSize(i_remove_size, i_remove_type)
        strategy.order("Remove Short", strategy.long, qty=remove_qty)

// Stop loss and take profit orders
if in_position
    strategy.exit("TP/SL", limit=take_profit, stop=stop_loss)

// =================== Trading Conditions =================== //
// Entry Conditions
long_entry = ta.crossover(fast_ma, slow_ma)
short_entry = ta.crossunder(fast_ma, slow_ma)

// Exit Conditions
long_exit = ta.crossunder(fast_ma, slow_ma)
short_exit = ta.crossover(fast_ma, slow_ma)

// =================== Risk Management =================== //
// Stop Loss and Take Profit
sl_percent = input.float(title="Stop Loss %", defval=2.0, minval=0.1, group=G_RISK)
tp_percent = input.float(title="Take Profit %", defval=4.0, minval=0.1, group=G_RISK)

// =================== Strategy Execution =================== //
if (long_entry)
    stop_loss = close * (1 - sl_percent/100)
    take_profit = close * (1 + tp_percent/100)
    strategy.entry("Long", strategy.long, qty=i_entry_size)
    strategy.exit("Long Exit", "Long", stop=stop_loss, limit=take_profit)

if (short_entry)
    stop_loss = close * (1 + sl_percent/100)
    take_profit = close * (1 - tp_percent/100)
    strategy.entry("Short", strategy.short, qty=i_entry_size)
    strategy.exit("Short Exit", "Short", stop=stop_loss, limit=take_profit)

// =================== Plotting =================== //

// Plot EMAs
plot(ema_fast, "Fast EMA", color=color.blue)
plot(ema_slow, "Slow EMA", color=color.yellow)

// Optional: Plot MAs for visual reference
plot(fast_ma, color=color.blue, title="Fast MA")
plot(slow_ma, color=color.red, title="Slow MA")

// Plot position levels when in a trade
if in_position
    var p_entry = plot(entry_price, "Entry", color=color.gray, style=plot.style_linebr)
    var p_sl = plot(stop_loss, "Stop Loss", color=color.red, style=plot.style_linebr)
    var p_tp = plot(take_profit, "Take Profit", color=color.green, style=plot.style_linebr)
    
    fill(p_entry, p_sl, color=color.new(color.red, 90))
    fill(p_entry, p_tp, color=color.new(color.green, 90))

// Watermark
if barstate.islast
    label.new(bar_index, high, "Katoshi.ai", 
        color=color.rgb(151, 252, 228, 50),
        textcolor=color.rgb(7, 7, 10),
        style=label.style_label_down,
        size=size.normal)

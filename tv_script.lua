// This Pine Script™ code is subject to the terms of the Mozilla Public License 2.0 at https://mozilla.org/MPL/2.0/
// © katoshi_ai

// The goal of this script is to quickly get you started automating your strategy on Hyperliquid
// Head to the {{ CUSTOMIZE_ME }} section to define your custom strategy!

// Visiti katoshi.ai and join our Telegram community for more information

// @strategy_alert_message {{strategy.order.alert_message}}

//@version=5
strategy("Hyperliquid Connector", overlay=true, max_lines_count = 500, default_qty_value=100, initial_capital=1000, commission_value=0.0336, pyramiding=3, process_orders_on_close=true, calc_on_order_fills=false, calc_on_every_tick=false, default_qty_type=strategy.percent_of_equity, commission_type=strategy.commission.percent, currency = "USD", use_bar_magnifier=false)


// ------------------ DISCLAIMER INPUPTS ------------------ //
help_setup                  = input.bool(title="Setup Instructions", defval=true, group="Read Me", tooltip = "This template allows your to automate your strategy on Hyperliquid's decentralized perpetual exchange. Please visit www.katoshi.ai to get started for free in less than 2 minutes!")
help_alert                  = input.bool(title="Alert Instructions", defval=true, group="Read Me", tooltip = "To start your strategy, create a new alert on Tradingview. Set the Condition to Hyperliquid Connector, with Order fill and alert() function calls. Set Expiration to open-eneded. Leave the message to {{strategy.order.alert_message}}. Add your Katoshi API URL in the Webhooh URL input in the Notifications tab. Also make sure your bot is enabled in Katoshi.")

// ------------------ BOT INPUTS ------------------ //
bot_id                      = input.string(title="Bot ID", defval="", group="Katōshi Integration", tooltip = "Enter your Katoshi Bot ID here.")
bot_api_key                 = input.string(title="API Key", defval="", group="Katōshi Integration", tooltip = "Enter your Katoshi API key here.")
bot_coin                    = input.string(title="Coin", defval="", group="Katōshi Integration", tooltip = "Enter the symbol (ticker) to trade. (i.e. BTC). Make sure to use the same name as shown in your Katoshi Bot settings.")

bot_update_leverage         = input.bool(title = "Update Leverage", defval = true, group = "Leverage", tooltip = "Enabling this option will send a one-time alert to update leverage on Hyperliquid when initiating the strategy.")
bot_leverage                = input.int(title = "Leverage", defval = 1, group="Leverage", tooltip = "Set a leverage multiplier.")
bot_margin_mode             = input.string(title = "Margin Mode", defval = "Isolated", options = ["Isolated", "Cross"] ,group="Leverage", tooltip = "Set the margin mode to use on Hyperliquid.")

help_size                   = input.bool(title="Size Instructions", defval=true, group="Size", tooltip = "Make sure you have enough funds on Hyperliquid when uing size types Contract and USD. Hyperliquid also requires a minimum position size of $10 USD.")

bot_entry_size_value        = input.float(title="Entry Size", defval=100, inline = "size", group="Size", tooltip = "") * bot_leverage
bot_entry_size_type         = input.string(title = "", defval = "%", inline = "size", options = ["Contract", "%", "USD"], group="Size", tooltip = "Size and type used for opening new positions.")

bot_add_size_value          = input.float(title="Adding Size", defval=10, inline = "add", group="Size", tooltip = "")
bot_add_size_type           = input.string(title = "", defval = "%", inline = "add", options = ["Contract", "%", "USD"], group="Size", tooltip = "Size and type used when adding to open positions. The % Option will apply to current position size (not original size).")

bot_remove_size_value       = input.float(title="Removing Size", defval=10, inline = "partial", group="Size", tooltip = "")
bot_remove_size_type        = input.string(title = "", defval = "%", inline = "partial", options = ["Contract", "%", "USD"], group="Size", tooltip = "Size and type used when partially closing positions. The % Option will apply to current position size (not original size).")

bot_stop_loss               = input.float(title = "Stop Loss %", defval = 2, minval=0.1, step=0.1, group = "Settings", tooltip = "Set a Stop loss percentage.")
bot_take_profit             = input.float(title = "Take Profit %", defval = 10, minval=0.1, group = "Settings", tooltip = "Set a Take profit percentage.")

bot_slippage                = input.int(title = "Slippage %", defval = 5, group="Settings", tooltip = "Set a max. % slippage for opening and closing positions on Hyperliquid.") / 100

// ------------------ STRATEGY INPUTS ------------------ //
ema_length_1                = input.int(title = "EMA Length 1", defval = 17, group = "Strategy")
ema_length_2                = input.int(title = "EMA Length 2", defval = 83, group = "Strategy")

// ------------------ BOT ALERTS ------------------ //
var string base_command = '{"bot_id":'+bot_id+',"api_key":"'+bot_api_key+'","coin":"'+bot_coin+'"'

construct_commmand(string command) =>
    final_command = base_command+command+'}'
    final_command

// Open Order
open_order(bool is_buy, float tp, float sl, float size, float size_pct, float size_usd, int slippage_pct) =>
    // is_buy = bool value, set to true for long positions, set to false for short positions
    // tp = float value, optional value that will overwrite your bot's default take profit % in order to use a direct level (not in %)
    // sl = float value, optional value that will overwrite your bot's default stop loss % in order to use a direct level (not in %)
    // size = float value, optional value that will overwrite your bot's default size in order to use a number of contracts
    // size_pct = float value, optional value that will overwrite your bot's default size in order to use a % of your available balance
    // size_usd = float value, optional value that will overwrite your bot's default size in order to use a fixed USD size
    // slippage_pct = float value, optional value that will set a max slippage percentage to execute orders

    action_command      = ',"action":"open_order"'
    is_buy_command      = not na(is_buy) ? ',"is_buy":'+str.tostring(is_buy)+'' : na
    tp_command          = not na(tp) ? ',"tp":'+str.tostring(tp)+'' : na
    sl_command          = not na(sl) ? ',"sl":'+str.tostring(sl)+'' : na
    size_command        = not na(size) ? ',"size":'+str.tostring(size)+'' : na
    size_pct_command    = not na(size_pct) ? ',"size_pct":'+str.tostring(size_pct)+'' : na
    size_usd_command    = not na(size_usd) ? ',"size_usd":'+str.tostring(size_usd)+'' : na
    slippage_command    = not na(slippage_pct) ? ',"slippage_pct":'+str.tostring(slippage_pct)+'' : na

    final_command       = construct_commmand(action_command+is_buy_command+tp_command+sl_command+size_command+size_pct_command+size_usd_command+slippage_command)
    final_command

// Close Order
close_order(float size, float size_pct, float size_usd, int slippage_pct) =>
    // size = float value, optional value to close a number of contracts
    // size_pct = float value, optional value to close a percentage of the total size
    // size_usd = float value, optional value to close a USD amount
    // slippage_pct = float value, optional value that will set a max slippage percentage to execute orders

    // TIPS: if all size types are not defined, the entire order will be closed

    action_command      = ',"action":"close_order"'
    size_command        = not na(size) ? ',"size":'+str.tostring(size)+'' : na
    size_pct_command    = not na(size_pct) ? ',"size_pct":'+str.tostring(size_pct)+'' : na
    size_usd_command    = not na(size_usd) ? ',"size_usd":'+str.tostring(size_usd)+'' : na

    slippage_command    = not na(slippage_pct) ? ',"slippage_pct":'+str.tostring(slippage_pct)+'' : na

    final_command       = construct_commmand(action_command+size_command+size_pct_command+size_usd_command+slippage_command)
    final_command

// Modify Order 
modify_order(float sl, float tp, float sl_pct, float tp_pct) =>
    // sl = float value, optional value that will move your stop loss to a new price
    // tp = float value, optional value that will move your take profit to a new price
    // sl_pct = float value, optional value that will move your stop loss to a percentage of the hyperliquid entry price (negative % move stop loss into profit)
    // tp_pct = float value, optional value that will move your take profit to a percentage of the hyperliquid entry price (negative % move stop loss into profit)

    action_command      = ',"action":"modify_order"'
    sl_command          = not na(sl) ? ',"sl":'+str.tostring(sl)+'' : na
    tp_command          = not na(tp) ? ',"tp":'+str.tostring(tp)+'' : na
    sl_pct_command      = not na(sl_pct) ? ',"sl_pct":'+str.tostring(sl_pct)+'' : na
    tp_pct_command      = not na(tp_pct) ? ',"tp_pct":'+str.tostring(tp_pct)+'' : na

    final_command       = construct_commmand(action_command+sl_command+tp_command+sl_pct_command+tp_pct_command)
    final_command

// Add Size
add_size(float size, float size_pct, float size_usd, int slippage_pct) => 
    // size = float value, optional value to add a number of contracts
    // size_pct = float value, optional value to add a percentage of the current size
    // size_usd = float value, optional value to add a USD amount

    action_command      = ',"action":"add_size"'
    size_command        = not na(size) ? ',"size":'+str.tostring(size)+'' : na
    size_pct_command    = not na(size_pct) ? ',"size_pct":'+str.tostring(size_pct)+'' : na
    size_usd_command    = not na(size_usd) ? ',"size_usd":'+str.tostring(size_usd)+'' : na
    slippage_command    = not na(slippage_pct) ? ',"slippage_pct":'+str.tostring(slippage_pct)+'' : na

    final_command       = construct_commmand(action_command+size_command+size_pct_command+size_usd_command+slippage_command)
    final_command

// Break Even
break_even() =>
    // Moves your stop loss to break-even (uses the real entry price on Hyperliquid - can be sligthly different than on Tradingview)
    action_command      = ',"action":"break_even"'

    final_command       = construct_commmand(action_command)
    final_command

// Set Leverage
set_leverage(int leverage, bool is_cross) =>
    // leverage = int value, will try to update leverage for your bot's coin
    // is_cross = bool value, set to true for margin type "Cross" or false for "Isolated"

    action_command      = ',"action":"set_leverage"'
    leverage_command    = not na(leverage) ? ',"leverage":'+str.tostring(leverage)+'' : na
    is_cross_command    = not na(is_cross) ? ',"is_cross":'+str.tostring(is_cross)+'' : na

    final_command       = construct_commmand(action_command+leverage_command+is_cross_command)
    final_command

// Start Bot
start_bot() =>
    // Enable your bot in Katoshi
    action_command      = ',"action":"start_bot"'

    final_command       = construct_commmand(action_command)
    final_command

// Stop Bot
stop_bot() =>
    // Disable your bot in Katoshi
    action_command      = ',"action":"stop_bot"'

    final_command       = construct_commmand(action_command)
    final_command


// ------------------ FUNCTIONS ------------------ //
f_round_down_to_tick(x)=>
    if not na(x)
        mult = 1 / syminfo.mintick
        value = math.floor(x*mult)/mult

f_round_up_to_tick(x)=>
    if not na(x)
        mult = 1 / syminfo.mintick
        value = math.ceil(x*mult)/mult

calcUsdContracts(usdValue) =>
    contractSize = syminfo.pointvalue * close
    usdValue / contractSize


// ------------------ STRATEGY VARIABLES ------------------ //
var bool bot_enabled            = true
var bool is_long                = false
var bool is_short               = false
var float short_entry_price     = close
var float long_entry_price      = close
var float long_stop_loss        = na
var float short_stop_loss       = na
var float long_take_profit      = na
var float short_take_profit     = na
var float long_new_sl_value     = na
var float short_new_sl_value    = na
var float long_new_tp_value     = na
var float short_new_tp_value    = na


// ------------------ {{ CUSTOMIZE_ME }} DEFINE YOUR STRATEGY CONDITIONS ------------------ //

// Simple EMA cross strategy
ema_1 = ta.ema(close, ema_length_1)
ema_2 = ta.ema(close, ema_length_2)

// Plot EMAs
plot(ema_1, color = color.blue)
plot(ema_2, color = color.yellow)

// Define Entry 
long_entry                      = ta.crossover(ema_1, ema_2)
short_entry                     = ta.crossunder(ema_1, ema_2)

// Define Exit
long_exit                       = false
short_exit                      = false

// Define condition when you want to move your stop loss
long_move_sl                    = close - open > ta.atr(14) * 2
short_move_sl                   = open - close > ta.atr(14) * 2

if long_move_sl
    long_new_sl_value           := long_entry_price // Define new price to move your long stop loss (long_entry_price == break even)

if short_move_sl
    short_new_sl_value          := short_entry_price // Define new price to move your short stop loss (short_entry_price == break even)

// Define condition when you want to move your take profits
long_move_tp                    = false
short_move_tp                   = false

if long_move_tp
    long_new_tp_value           := long_take_profit // Define new price to move your long take profit

if short_move_tp
    short_new_tp_value          := short_take_profit // Define new price to move your short take profit

// Define condition when you want to remove size from current position (partial profits)
long_remove_size                = close - open > ta.atr(14) // Candle size bigger than ATR
short_remove_size               = open - close > ta.atr(14) // Candle size bigger than ATR

// Define condition when to add size to current position
// TIPS: Use the Pyramiding feature in the Properties Tab to control the max number of time to trigger additionnal entries
long_add_size                   = (ta.crossunder(low, ema_2) and close > open) or (close > ema_2 and close[1] < ema_2) // Bullish pullback OR Reclaim of slow EMA
short_add_size                  = (ta.crossover(high, ema_2) and close < open) or (close < ema_2 and close[1] > ema_2) // Bearish pullback OR Reclaim of slow EMA

// Define condition when to update leverage 
// TIPS: Can't update leverage if a position is open - check there are no open positions first
update_leverage                 = false

// Define condition when to disable and enable your bot
// TIPS: You could disable your bot if it reaches a max. drawdown %, or max. loosing streak
enable_bot                      = false
disable_bot                     = false


// ------------------ STRATEGY TEMPLATE (Don't edit below if you don't know what you're doing) ------------------ //

// Handle bot status
if enable_bot and not bot_enabled
    bot_enabled := true

    // Send bot alert
    alert(message=start_bot(), freq=alert.freq_once_per_bar_close)

if disable_bot and bot_enabled
    bot_enabled := false

    // Send bot alert
    alert(message=stop_bot(), freq=alert.freq_once_per_bar_close)

// Update Leverage once when initiating the strategy
var bool updated_leverage = false

if bot_update_leverage and updated_leverage==false
    updated_leverage := true
    update_leverage := true

// Define Stop Loss
long_stop_loss_ratio            = bot_stop_loss
short_stop_loss_ratio           = bot_stop_loss

// Define Take Profit
long_take_profit_ratio          = bot_take_profit
short_take_profit_ratio         = bot_take_profit

// Stop Loss Exit
long_stopped                    = is_long and low <= long_stop_loss
short_stopped                   = is_short and high >= short_stop_loss

// Take Profit Exit
long_tped                       = is_long and high >= long_take_profit
short_tped                      = is_short and low <= short_take_profit

// Entry Cond
long_entry_cond                 = long_entry and not is_long and bot_enabled
short_entry_cond                = short_entry and not is_short and bot_enabled

// Exit Cond
long_exit_cond                  = is_long and (long_exit or long_stopped or long_tped or short_entry_cond)
short_exit_cond                 = is_short and (short_exit or short_stopped or short_tped or long_entry_cond)

// Move Take Profit Cond 
long_move_tp_cond               = long_move_tp and is_long and not long_entry_cond and not long_exit_cond and (close < long_new_tp_value)
short_move_tp_cond              = short_move_tp and is_short and not short_entry_cond and not short_exit_cond and (close > short_new_tp_value)

// Move Stop Loss Cond 
long_move_sl_cond               = long_move_sl and is_long and not long_entry_cond and not long_exit_cond and (close > long_new_sl_value)
short_move_sl_cond              = short_move_sl and is_short and not short_entry_cond and not short_exit_cond and (close < short_new_sl_value)

// Remove Size Cond 
long_remove_cond                = long_remove_size and is_long and not long_add_size and not long_entry_cond and not long_exit_cond
short_remove_cond               = short_remove_size and is_short and not short_add_size and not short_entry_cond and not short_exit_cond

// Add Size Cond 
long_add_cond                   = long_add_size and is_long and not long_remove_size and not long_entry_cond and not long_exit_cond
short_add_cond                  = short_add_size and is_short and not short_remove_size and not short_entry_cond and not short_exit_cond

// Set Leverage 
if update_leverage
    // Define your new leverage value
    leverage = bot_leverage
    margin_mode = bot_margin_mode == "Cross" ? true : false

    // Send bot alert
    alert(message=set_leverage(leverage, margin_mode), freq=alert.freq_once_per_bar_close)

// Long Exit
if long_exit_cond
    // Update global variables
    is_long                 := false

    // Exit Long Position
    if long_exit and not short_entry_cond
        strategy.close_all(comment="Close Long", alert_message=close_order(na, na, na, bot_slippage))

// Short Exit
if short_exit_cond
    // Update global variables
    is_short                := false

    // Exit Short Position
    if short_exit and not long_entry_cond
        strategy.close_all(comment="Close Short", alert_message=close_order(na, na, na, bot_slippage))    

// Long Entry
if long_entry_cond
    // Update global variables
    is_long                     := true
    long_entry_price            := close
    long_take_profit            := f_round_down_to_tick(close + (close * (long_take_profit_ratio / 100)))
    long_stop_loss              := f_round_up_to_tick(close - (close * (long_stop_loss_ratio / 100)))

    float size_contract = na // Contract
    float size_pct = na // Percentage
    float size_usd = na // USD
    float final_qty = na // final contracts quantity

    // Get current strategy equity
    position_size = strategy.equity // USD

    // Calculate sizes
    if bot_entry_size_type == "Contract"
        size_contract := bot_entry_size_value
        final_qty := size_contract
    else if bot_entry_size_type == "%"
        size_pct := bot_entry_size_value / 100
        final_qty := calcUsdContracts(position_size * size_pct)
    else if bot_entry_size_type == "USD"
        size_usd := bot_entry_size_value
        final_qty := calcUsdContracts(size_usd)

    // Enter Long Position
    strategy.entry("Long", direction=strategy.long, comment="Open Long", qty=final_qty, alert_message=open_order(true, long_take_profit, long_stop_loss, size_contract, size_pct, size_usd, bot_slippage))

    // Set TP/SL for Long Position
    strategy.exit("Long Exit", from_entry="Long", limit=long_take_profit, stop=long_stop_loss, comment="Close Long TP/SL", alert_message=close_order(na, na, na, bot_slippage))

// Short Entry
if short_entry_cond
    // Update global variables
    is_short                    := true
    short_entry_price           := close
    short_take_profit           := f_round_up_to_tick(close - (close * (short_take_profit_ratio / 100)))
    short_stop_loss             := f_round_down_to_tick(close + (close * (short_stop_loss_ratio / 100)))

    float size_contract = na // Contract
    float size_pct = na // Percentage
    float size_usd = na // USD
    float final_qty = na // final contracts quantity

    // Get current strategy equity
    position_size = strategy.equity // USD

    // Calculate sizes
    if bot_entry_size_type == "Contract"
        size_contract := bot_entry_size_value
        final_qty := size_contract
    else if bot_entry_size_type == "%"
        size_pct := bot_entry_size_value / 100
        final_qty := calcUsdContracts(position_size * size_pct)
    else if bot_entry_size_type == "USD"
        size_usd := bot_entry_size_value
        final_qty := calcUsdContracts(size_usd)

    // Enter Short Position 
    strategy.entry("Short", direction=strategy.short, comment="Open Short", qty=final_qty, alert_message=open_order(false, short_take_profit, short_stop_loss, size_contract, size_pct, size_usd, bot_slippage))

    // Set TP/SL for Short Position
    strategy.exit("Short Exit", from_entry = "Short", limit=short_take_profit, stop=short_stop_loss, comment="Close Short TP/SL", alert_message=close_order(na, na, na, bot_slippage))

// Move Long TP/SL 
if long_move_tp_cond or long_move_sl_cond
    // New values 
    long_take_profit_new = long_move_tp_cond ? f_round_down_to_tick(long_new_tp_value) : long_take_profit
    long_stop_loss_new = long_move_sl_cond ? f_round_up_to_tick(long_new_sl_value) : long_stop_loss

    // Check if values are different
    long_tp_changed = long_take_profit != long_take_profit_new
    long_sl_changed = long_stop_loss != long_stop_loss_new

    // Update tp/sl if values have changed
    if long_tp_changed or long_sl_changed
        // Update global variable
        long_take_profit := long_take_profit_new
        long_stop_loss := long_stop_loss_new

        // Update our limit orders
        strategy.exit("Long Exit", from_entry = "Long", limit=long_take_profit, stop=long_stop_loss, comment="Close Long TP/SL", alert_message=close_order(na, na, na, bot_slippage))
        strategy.exit("Long Exit Add", from_entry = "Long Add", limit=long_take_profit, stop=long_stop_loss, comment="Close Long Add", disable_alert = true)

        // Send bot alert
        long_take_profit_alert = long_tp_changed ? long_take_profit : na
        long_stop_loss_alert = long_sl_changed ? long_stop_loss : na

        alert(message=modify_order(long_stop_loss_alert, long_take_profit_alert, na, na), freq=alert.freq_once_per_bar_close)

// Move Short TP/SL 
if short_move_tp_cond or short_move_sl_cond
    // New values 
    short_take_profit_new = short_move_tp_cond ? f_round_up_to_tick(short_new_tp_value) : short_take_profit
    short_stop_loss_new = short_move_sl_cond ? f_round_down_to_tick(short_new_sl_value) : short_stop_loss

    // Check if values are different
    short_tp_changed = short_take_profit != short_take_profit_new
    short_sl_changed = short_stop_loss != short_stop_loss_new

    // Update tp/sl if values have changed
    if short_tp_changed or short_sl_changed
        // Update global variable
        short_take_profit := short_take_profit_new
        short_stop_loss := short_stop_loss_new

        // Update our limit orders
        strategy.exit("Short Exit", from_entry = "Short", limit=short_take_profit, stop=short_stop_loss, comment="Close Short TP/SL", alert_message=close_order(na, na, na, bot_slippage))
        strategy.exit("Short Exit Add", from_entry = "Short Add", limit=short_take_profit, stop=short_stop_loss, comment="Close Short Add", disable_alert = true)

        // Send bot alert
        short_take_profit_alert = short_tp_changed ? short_take_profit : na
        short_stop_loss_alert = short_sl_changed ? short_stop_loss : na

        alert(message=modify_order(short_stop_loss_alert, short_take_profit_alert, na, na), freq=alert.freq_once_per_bar_close)

// Remove Size
enable_remove = bot_remove_size_value > 0 ? true : false
if ((long_remove_cond) or (short_remove_cond)) and enable_remove
    float size_contract = na // Contract
    float size_pct = na // Percentage
    float size_usd = na // USD
    float final_qty = na // final contracts quantity

    // Get total position size
    position_size = math.abs(strategy.position_size) // contracts

    // Calculate sizes
    if bot_remove_size_type == "Contract"
        size_contract := bot_remove_size_value * bot_leverage
        final_qty := size_contract
    else if bot_remove_size_type == "%"
        size_pct := bot_remove_size_value / 100
        final_qty := position_size * size_pct
    else if bot_remove_size_type == "USD"
        size_usd := bot_remove_size_value * bot_leverage
        final_qty := calcUsdContracts(size_usd)

    // Make sure we don't close more than full position size
    ok_to_remove = final_qty < position_size

    // Long
    if long_remove_cond and ok_to_remove
        // label.new(bar_index, high, text="remove")
        strategy.order("Long", direction = strategy.short, comment="Remove Size Long", qty=final_qty, alert_message=close_order(size_contract, size_pct, size_usd, bot_slippage))

    // Short
    if short_remove_cond and ok_to_remove
        strategy.order("Short", direction = strategy.long, comment="Remove Size Short", qty=final_qty, alert_message=close_order(size_contract, size_pct, size_usd, bot_slippage))

// Add Size 
enable_add = bot_add_size_value > 0 ? true : false
if ((long_add_cond) or (short_add_cond)) and enable_add
    float size_contract = na // Contract
    float size_pct = na // Percentage
    float size_usd = na // USD
    float final_qty = na // final contracts quantity

    // Get total position size (including any adds)
    position_size = math.abs(strategy.position_size) // contracts

    // Calculate sizes
    if bot_add_size_type == "Contract"
        size_contract := bot_add_size_value * bot_leverage
        final_qty := size_contract
    else if bot_add_size_type == "%"
        size_pct := bot_add_size_value / 100
        final_qty := position_size * size_pct
    else if bot_add_size_type == "USD"
        size_usd := bot_add_size_value * bot_leverage
        final_qty := calcUsdContracts(size_usd)

    // Long
    if long_add_cond
        // label.new(bar_index, low, text="add")
        strategy.entry("Long Add", direction=strategy.long, qty=final_qty, comment="Add Size Long", alert_message=add_size(size_contract, size_pct, size_usd, bot_slippage))
        
        // Set the same TP/SL as main position
        strategy.exit("Long Exit Add", from_entry = "Long Add", comment = "Close Long Add", limit = long_take_profit, stop = long_stop_loss, disable_alert = true)

    // Short
    if short_add_cond
        strategy.entry("Short Add", direction=strategy.short, qty=final_qty, comment="Add Size Short", alert_message=add_size(size_contract, size_pct, size_usd, bot_slippage))

        // Set the same TP/SL as main position
        strategy.exit("Short Exit Add", from_entry = "Short Add", comment = "Close Short Add", limit = short_take_profit, stop = short_stop_loss, disable_alert = true)

// Plot Positions
plot_long_sl = plot(is_long ? long_stop_loss : na, color = color.new(color.red, 50), style = plot.style_linebr)
plot_short_sl = plot(is_short ? short_stop_loss : na, color = color.new(color.red, 50), style = plot.style_linebr)

plot_long_tp = plot(is_long ? long_take_profit : na, color = color.new(color.teal, 50), style = plot.style_linebr)
plot_short_tp = plot(is_short ? short_take_profit : na, color = color.new(color.teal, 50), style = plot.style_linebr)

plot_long_entry = plot(is_long ? long_entry_price : na, color = color.new(color.gray, 50), style = plot.style_linebr)
plot_short_entry = plot(is_short ? short_entry_price : na, color = color.new(color.gray, 50), style = plot.style_linebr)

fill(plot_long_entry, plot_long_sl, color= color.new(color.red, 95))
fill(plot_short_entry, plot_short_sl, color= color.new(color.red, 95))

fill(plot_long_entry, plot_long_tp, color= color.new(color.teal, 95))
fill(plot_short_entry, plot_short_tp, color= color.new(color.teal, 95))


// Watermark
var color table_color = #97fce4
var color table_text_color = #07070a
var table table = table.new(position.bottom_right, 1, 1, force_overlay = true)
table.cell(table, 0, 0, "Katoshi.ai", text_color=color.new(table_text_color, 0), bgcolor = color.new(table_color, 0), text_size = size.normal)
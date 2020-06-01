--[[
 * Copyright (c) AppDynamics, Inc., and its affiliates
 * 2015
 * All Rights Reserved
 * THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
 * The copyright notice above does not evidence any actual or intended
 * publication of such source code
--]]

package.path = '../../?.lua;' .. package.path
require "helper"

--[[
Helper table for computing the socket statistics.
This is the data used by the statistics function for performing
the statistics computation.
--]]
socket_statistics_data = {
	{statistic = "tcp_established", pattern = "ESTABLISHED"},
	{statistic = "tcp_synsent", pattern = "SYN_SENT"},
	{statistic = "tcp_synrecv", pattern = "SYN_RECV"},
	{statistic = "tcp_finwait1", pattern = "FIN_WAIT1"},
	{statistic = "tcp_finwait2", pattern = "FIN_WAIT2"},
	{statistic = "tcp_timewait", pattern = "TIME_WAIT"},
	{
		statistic = "tcp_close",
		pattern = "CLOSE ",	-- Deliberate space at the end
					-- of the pattern to distinguish
					-- with CLOSE_WAIT state.
	},
	{statistic = "tcp_closewait", pattern = "CLOSE_WAIT"},
	{statistic = "tcp_lastack", pattern = "LAST_ACK"},
	{statistic = "tcp_closing", pattern = "CLOSING"},
}


--[[
Helper table for computing the socket metrics.
This is the data used by the metrics function for performing
the metrics computation.
--]]
socket_metrics_data = {
	{metric = "Established", input = {"tcp_established"}},
	--{metric = "SynSent", input = {"tcp_synsent"}},
	--{metric = "SynRcv", input = {"tcp_synrecv"}},
	--{metric = "FinWait1", input = {"tcp_finwait1"}},
	--{metric = "FinWait2", input = {"tcp_finwait2"}},
	{metric = "TimeWait", input = {"tcp_timewait"}},
	--{metric = "Close", input = {"tcp_close"}},
	--{metric = "CloseWait", input = {"tcp_closewait"}},
	--{metric = "LastAck", input = {"tcp_lastack"}},
	--{metric = "Closing", input = {"tcp_closing"}},
	{metric = "Embryonic", input = {"tcp_synsent", "tcp_synrecv"}},
	{metric = "Wait", input = {"tcp_finwait1", "tcp_finwait2",
		"tcp_timewait", "tcp_closewait", "tcp_closing"}},
}


--[[
Data structure holding all information for statistics collection
--]]
socket_statistics_ds = {
	command = "netstat -np TCP",
	data = socket_statistics_data,
}


--[[
Callback function called by application to gather statistics data.
--]]
function socket_statistics_fn()
	local _table = socket_statistics_ds
	local _val_table = {}
	local _count = 0
	local _op = run_command(_table["command"])

	if (_op == nil) then return nil end

	for _k, _v in pairs(_table["data"]) do
		_count = get_pattern_count(_op, _v["pattern"])
		_val_table[_v["statistic"]] = _count or 0
	end

	return _val_table
end


--[[
Callback function called by application to gather metrics data.
--]]
function socket_metrics_fn()
	local _val_table = {}
	local stats_table = socket_statistics_fn()

	if (stats_table == nil) then return nil end

	for _, _v1 in pairs(socket_metrics_data) do
		for _, _v2 in pairs(_v1["input"]) do
			if (stats_table[_v2] ~= nil) then
				if (_val_table[_v1["metric"]] == nil) then
					_val_table[_v1["metric"]] = 0
				end

				_val_table[_v1["metric"]] =
				_val_table[_v1["metric"]] +
				    stats_table[_v2]
			end
		end
	end

	return _val_table
end


--[[
Plugin initialization function.
Just returns a table as required by the plugin infrastructure.
--]]
function plugin_init()
	return {
		-- Plugin info.
		plugin_name = "Socket",
		plugin_type = "monitoring",

		-- Statistics info.
		--statistics_cb = "socket_statistics_fn",

		-- Metrics info.
		metrics_cb = "socket_metrics_fn",
	}
end


--[[
Plugin finish function.
Nothing to do for now.
--]]
function plugin_fini()
	return
end


--[[
t={}
t = socket_statistics_fn()
dump(t)
t2 = socket_metrics_fn(t)
dump(t2)
--]]
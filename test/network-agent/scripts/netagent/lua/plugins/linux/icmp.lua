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
require "metric-properties"

local icmp_module = {}

rx_msgs_key = "# Rx Msgs"
rx_dest_unreach_key = "# Rx Dest Unreachable"
rx_errors_key = "# Rx Errors"
rx_timeout_key = "# Rx Timeouts"
tx_msgs_key = "# Tx Msgs"
tx_dest_unreach_key = "# Tx Dest Unreachable"
tx_errors_key = "# Tx Errors"
tx_timeout_key = "# Tx Timeouts"

-- Metric metdadata table
-- Used for populating metrics
icmp_md_tbl = {
	{	-- # Rx Msgs
		m_name = rx_msgs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Rx Dest Unreachable
		m_name = rx_dest_unreach_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Rx Errors
		m_name = rx_errors_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Rx Timeouts
		m_name = rx_timeout_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Msgs
		m_name = tx_msgs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Dest Unreachable
		m_name = tx_dest_unreach_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Errors
		m_name = tx_errors_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Timeouts
		m_name = tx_timeout_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
}

g_icmp_sample_data = {}

--[[
InMsgs InErrors InCsumErrors InDestUnreachs InTimeExcds InParmProbs InSrcQuenchs InRedirects InEchos InEchoReps InTimestamps InTimestampReps InAddrMasks InAddrMaskReps OutMsgs OutErrors OutDestUnreachs OutTimeExcds OutParmProbs OutSrcQuenchs OutRedirects OutEchos OutEchoReps OutTimestamps OutTimestampReps OutAddrMasks OutAddrMaskReps
--]]
--[[
Helper table for computing the icmp statistics.
This is the data used by the statistics function for performing
the statistics computation.
--]]
icmp_statistics_data = {
	{statistic = "in_msgs", pattern = "InMsgs"},
	{statistic = "in_errs", pattern = "InErrors"},
	{statistic = "in_csumerrs", pattern = "InCsumErrors"},
	{statistic = "in_dstunreachs", pattern = "InDestUnreachs"},
	{statistic = "in_timeouts", pattern = "InTimeExcds"},
	{statistic = "in_paramprobs", pattern = "InParmProbs"},
	{statistic = "in_srcquenchs", pattern = "InSrcQuenchs"},
	{statistic = "in_redirects", pattern = "InRedirects"},
	{statistic = "in_echoes", pattern = "InEchos"},
	{statistic = "in_echoreps", pattern = "InEchoReps"},
	{statistic = "in_timestamps", pattern = "InTimestamps"},
	{statistic = "in_timestampreps", pattern = "InTimestampReps"},
	{statistic = "in_addrmasks", pattern = "InAddrMasks"},
	{statistic = "in_addrmaskreps", pattern = "InAddrMaskReps"},
	{statistic = "out_msgs", pattern = "OutMsgs"},
	{statistic = "out_errs", pattern = "OutErrors"},
	{statistic = "out_dstunreachs", pattern = "OutDestUnreachs"},
	{statistic = "out_timeouts", pattern = "OutTimeExcds"},
	{statistic = "out_paramprobs", pattern = "OutParmProbs"},
	{statistic = "out_srcquenchs", pattern = "OutSrcQuenchs"},
	{statistic = "out_redirects", pattern = "OutRedirects"},
	{statistic = "out_echoes", pattern = "OutEchos"},
	{statistic = "out_echoreps", pattern = "OutEchoReps"},
	{statistic = "out_timestamps", pattern = "OutTimestamps"},
	{statistic = "out_timestampreps", pattern = "OutTimestampReps"},
	{statistic = "out_addrmasks", pattern = "OutAddrMasks"},
	{statistic = "out_addrmaskreps", pattern = "OutAddrMaskReps"}
}

--[[
Helper table for computing the icmp metrics.
This is the data used by the metrics function for performing
the metrics computation.
--]]
icmp_metrics_data = {
	{metric = rx_msgs_key, input = {"in_msgs"}},
	{metric = rx_errors_key, input = {"in_errs"}},
	{metric = rx_dest_unreach_key, input = {"in_dstunreachs"}},
	{metric = rx_timeout_key, input = {"in_timeouts"}},
	{metric = tx_msgs_key, input = {"out_msgs"}},
	{metric = tx_errors_key, input = {"out_errs"}},
	{metric = tx_dest_unreach_key, input = {"out_dstunreachs"}},
	{metric = tx_timeout_key, input = {"out_timeouts"}},
}


--[[
Data structure holding all information for statistics collection
--]]
icmp_statistics_ds = {
	filename = "/proc/net/snmp",
	data = icmp_statistics_data,
}


--[[
Callback function called by application to gather statistics data.
--]]
function icmp_statistics_fn()
	local _table = icmp_statistics_ds
	local _val_table = {}
	local _count = 0
	local _op = read_file(_table["filename"])

	if (_op == nil) then return nil end

	for _k, _v in pairs(_table["data"]) do
		_count = get_column_value_snmp_format(_op, "Icmp", _v["pattern"])
		if _count == nil then
			_val_table[_v["statistic"]] = 0
		else
			_val_table[_v["statistic"]] = _count
		end
	end
	return _val_table
end


--[[
Callback function called by application to gather metrics data.
--]]
function icmp_metrics_fn()
	local _val_table = {}	-- Table to hold the metrics to be returned.
	local _agg_val_table = {}	-- Table to hold the aggregate metrics.
	local stats_table = icmp_statistics_fn()

	if (stats_table == nil) then return nil end

	-- Fill up the metric values using the stats value. The metrics filled
	-- up in this loop would be aggregate metric value since the proc entries
	-- only provides aggregate values.
	for _, _v1 in pairs(icmp_metrics_data) do
		for _, _v2 in pairs(_v1["input"]) do
			if (stats_table[_v2] ~= nil) then
				if (_agg_val_table[_v1["metric"]] == nil) then
					_agg_val_table[_v1["metric"]] = 0
				end

				_agg_val_table[_v1["metric"]] =
				    _agg_val_table[_v1["metric"]] +
				    stats_table[_v2]
			end
		end
	end

	-- Modify the metrics to be per interval values.
	if next(g_icmp_sample_data) == nil then
		local _tmp_icmp_table={}
		_tmp_icmp_table["value_table"] = _agg_val_table
		g_icmp_sample_data = _tmp_icmp_table

		-- Create a copy of the _val_table and set all the values to
		-- be 0 initially.
		for key, _ in pairs(_agg_val_table) do
			_val_table[key] = 0
		end
	else
		local _tmp_icmp_table = {}
		local _prev_metrics_table = g_icmp_sample_data["value_table"]

		-- Create the _val_table which would be per interval.
		for key, value in pairs(_agg_val_table) do
			_val_table[key] = value - _prev_metrics_table[key]
		end

		-- Set the value table in the global to be that of aggregate values.
		g_icmp_sample_data["value_table"] = _agg_val_table
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
		plugin_name = "ICMP",
		plugin_type = "monitoring",

		-- Metrics info.
		metrics_md = "icmp_md_tbl",
		metrics_cb = "icmp_metrics_fn",
	}
end


--[[
Plugin finish function.
Nothing to do for now.
--]]
function plugin_fini()
	return
end

icmp_module.plugin_init = plugin_init
icmp_module.plugin_fini = plugin_fini

return icmp_module
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

local tcp_module = {}

seg_in_key = "Rx Segments Per Sec"
seg_out_key = "Tx Segments Per Sec"
seg_retrans_key = "# Segment Retransmissions"
seg_in_err_key = "# Rx Segment Errors"

-- Metric metdadata table
-- Used for populating metrics
tcp_md_tbl = {
	{	-- Rx Segments Per Sec
		m_name = seg_in_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Tx Segments Per Sec
		m_name = seg_out_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Segment Retransmissions
		m_name = seg_retrans_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Rx Segment Errors
		m_name = seg_in_err_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
}

g_tcp_sample_data = {}

--[[
Helper table for computing the tcp statistics.
This is the data used by the statistics function for performing
the statistics computation.
--]]
tcp_statistics_data = {
	{statistic = "in_segs", pattern = "InSegs"},
	{statistic = "out_segs", pattern = "OutSegs"},
	{statistic = "retran_segs", pattern = "RetransSegs"},
	{statistic = "in_errs", pattern = "InErrs"},
}


--[[
Helper table for computing the tcp metrics.
This is the data used by the metrics function for performing
the metrics computation.
--]]
tcp_metrics_data = {
	{metric = seg_in_key, input = {"in_segs"}},
	{metric = seg_out_key, input = {"out_segs"}},
	{metric = seg_retrans_key, input = {"retran_segs"}},
	{metric = seg_in_err_key, input = {"in_errs"}},
}


--[[
Data structure holding all information for statistics collection
--]]
tcp_statistics_ds = {
	filename = "/proc/net/snmp",
	data = tcp_statistics_data,
}


--[[
Callback function called by application to gather statistics data.
--]]
function tcp_statistics_fn()
	local _table = tcp_statistics_ds
	local _val_table = {}
	local _count = 0
	local _op = read_file(_table["filename"])

	if (_op == nil) then return nil end

	for _k, _v in pairs(_table["data"]) do
		_count = get_column_value_snmp_format(_op, "Tcp", _v["pattern"])
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
function tcp_metrics_fn()
	local _val_table = {}	-- Table to hold the metrics to be returned.
	local _agg_val_table = {}	-- Table to hold the aggregate metrics.
	local stats_table = tcp_statistics_fn()
	local _time = os.time()

	if (stats_table == nil) then return nil end

	-- Fill up the metric values using the stats value. The metrics filled
	-- up in this loop would be aggregate metric value since the proc entries
	-- only provides aggregate values.
	for _, _v1 in pairs(tcp_metrics_data) do
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
	if next(g_tcp_sample_data) == nil then
		local _tmp_tcp_table={}
		_tmp_tcp_table["value_table"] = _agg_val_table
		g_tcp_sample_data = _tmp_tcp_table
		g_tcp_sample_data.time = _time

		-- Create a copy of the _val_table and set all the values to
		-- be 0 initially.
		for key, _ in pairs(_agg_val_table) do
			_val_table[key] = 0
		end
	else
		local _tmp_tcp_table = {}
		local _prev_metrics_table = g_tcp_sample_data["value_table"]

		local _time_diff = _time - g_tcp_sample_data.time

		-- Create the _val_table which would be per interval.
		for key, value in pairs(_agg_val_table) do
			if(_time_diff > 0) then
				_val_table[key] =
				    (value - _prev_metrics_table[key]) / _time_diff
			else
				_val_table[key] = 0;
			end
		end

		-- Set the value table in the global to be that of aggregate values.
		g_tcp_sample_data.time = _time
		g_tcp_sample_data["value_table"] = _agg_val_table
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
		plugin_name = "TCP",
		plugin_type = "monitoring",

		-- Metrics info.
		metrics_md = "tcp_md_tbl",
		metrics_cb = "tcp_metrics_fn",
	}
end


--[[
Plugin finish function.
Nothing to do for now.
--]]
function plugin_fini()
	return
end

tcp_module.plugin_init = plugin_init
tcp_module.plugin_fini = plugin_fini

return tcp_module
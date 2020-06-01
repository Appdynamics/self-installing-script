--[[
 * Copyright (c) AppDynamics, Inc., and its affiliates
 * 2016
 * All Rights Reserved
 * THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
 * The copyright notice above does not evidence any actual or intended
 * publication of such source code
--]]

package.path = '../../?.lua;' .. package.path
require "helper"
require "metric-properties"

local memory_module = {}

-- Key names of metrics
tot_mem_key = "Total Memory (MB)"
mem_free_key = "Memory Free (MB)"
mem_used_key = "Memory Used (MB)"
mem_usage_key = "Memory Usage (%)"

-- Metric metdadata table
-- Used for populating metrics
memory_md_tbl = {
	{	-- Total Memory (MB)
		m_name = tot_mem_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Memory Free (MB)
		m_name = mem_free_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Memory Used (MB)
		m_name = mem_used_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Memory Usage (%)
		m_name = mem_usage_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
}

-- Table of metric names and their patterns.
memory_stats = {
	{statistic = tot_mem_key,
	    pattern = "MemTotal:%s*(%d+)%s*kB"},
	{statistic = mem_free_key,
	    pattern = "MemFree:%s*(%d+)%s*kB"},
}

--[[
-- Generic function to get memory usage. Reads data from /proc/meminfo
--]]
function get_memusage()
	local _table = memory_stats
	local _val_table = {}

	local _op = read_file("/proc/meminfo")
	if _op == nil then return nil end

	for _k, _v in pairs(_table) do
		local _val = generic_complex_parse_fn(
		    _op, _v.pattern, 1)

		-- Convert _val from kB to mB
		_val = ((_val and (tonumber(_val) / 1024)) or 0)
		_val_table[_v.statistic] = round(_val, 0)
	end

	if _val_table[tot_mem_key] ~= 0 then
		-- Compute memory used in MB
		_val_table[mem_used_key] = _val_table[tot_mem_key]
		    - _val_table[mem_free_key]

		-- Compute Memory usage in %
		_val_table[mem_usage_key] =
		    (_val_table[mem_used_key] * 100)/
		    _val_table[tot_mem_key]
		_val_table[mem_usage_key] =
		    round(_val_table[mem_usage_key], 0)
	else
		_val_table[mem_used_key] = 0
		_val_table[mem_usage_key] = 0
	end

	return _val_table
end

--[[
-- Function callback called by tha application to get memory statistics.
--]]
function memory_statistics_fn()
	local _val_table = get_memusage()

	return _val_table
end

--[[
-- Function callback called by tha application to get memory metrics.
--]]
function memory_metrics_fn()
	local _val_table = memory_statistics_fn()

	return _val_table
end

--[[
-- Record for populating this plugin.
--]]
function plugin_init()
	return {
		-- Plugin info
		plugin_name = "Memory",
		plugin_type = "monitoring",

		-- Metrics info
		metrics_md = "memory_md_tbl",
		metrics_cb = "memory_metrics_fn",
	}
end

function plugin_fini()
	return
end

memory_module.plugin_init = plugin_init
memory_module.plugin_fini = plugin_fini

return memory_module
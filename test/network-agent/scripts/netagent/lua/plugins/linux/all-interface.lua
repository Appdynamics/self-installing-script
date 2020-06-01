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

local all_interface_module = {}

rx_errs_key = "# Receive Errors"
rx_drops_key = "# Receive Drops"
tx_errs_key = "# Transmit Errors"
tx_drops_key = "# Transmit Drops"
colls_key = "# Collisions"
total_errs_key = "# Total Errors"

-- Metric metdadata table
-- Used for populating metrics
all_if_md_tbl = {
	{	-- # Receive errors
		m_name = rx_errs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Receive drops
		m_name = rx_drops_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Transmit errors
		m_name = tx_errs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Transmit drops
		m_name = tx_drops_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Collisions
		m_name = colls_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Total errors
		m_name = total_errs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
}

-- Global holding previous sampled data.
g_if_sample_data = {}

--
-- Save current sample's data.
--
function save_sample_values(stats_tbl, total_errs)
	g_if_sample_data.rx_errs = stats_tbl.rx_errs
	g_if_sample_data.rx_drops = stats_tbl.rx_drops
	g_if_sample_data.tx_errs = stats_tbl.tx_errs
	g_if_sample_data.tx_drops = stats_tbl.tx_drops
	g_if_sample_data.colls = stats_tbl.colls
	g_if_sample_data.total_errs = total_errs
end

--
-- Function callback called by the application to get interface metrics.
--
function if_metrics_fn()
	local val_tbl = {}
	local total_errs
	local stats_tbl = get_if_stats()

	if (stats_tbl == nil) then return nil end

	total_errs = stats_tbl.rx_errs + stats_tbl.rx_drops
	    + stats_tbl.tx_errs + stats_tbl.tx_drops + stats_tbl.colls
	if next(g_if_sample_data) == nil then
		-- Save this sample values.
		save_sample_values(stats_tbl, total_errs)

		-- Return a zero table.
		val_tbl[rx_errs_key] = 0
		val_tbl[rx_drops_key] = 0
		val_tbl[tx_errs_key] = 0
		val_tbl[tx_drops_key] = 0
		val_tbl[colls_key] = 0
		val_tbl[total_errs_key] = 0
	else
		val_tbl[rx_errs_key] = stats_tbl.rx_errs
		    - g_if_sample_data.rx_errs
		val_tbl[rx_drops_key] = stats_tbl.rx_drops
		    - g_if_sample_data.rx_drops
		val_tbl[tx_errs_key] = stats_tbl.tx_errs
		    - g_if_sample_data.tx_errs
		val_tbl[tx_drops_key] = stats_tbl.tx_drops
		    - g_if_sample_data.tx_drops
		val_tbl[colls_key] = stats_tbl.colls
		    - g_if_sample_data.colls
		val_tbl[total_errs_key] = total_errs
		    - g_if_sample_data.total_errs

		-- Save this sample values.
		save_sample_values(stats_tbl, total_errs)
	end

	return val_tbl
end

--
-- Record for populating this plugin.
--
function plugin_init()
	return {
		-- Plugin info
		plugin_name = "Interface",
		plugin_type = "monitoring",

		-- Metrics info
		metrics_md = "all_if_md_tbl",
		metrics_cb = "if_metrics_fn",
	}
end

function plugin_fini()
	return
end

all_interface_module.plugin_init = plugin_init
all_interface_module.plugin_fini = plugin_fini

return all_interface_module
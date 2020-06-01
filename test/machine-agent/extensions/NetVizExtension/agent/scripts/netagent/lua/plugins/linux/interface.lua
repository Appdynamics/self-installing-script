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

local interface_module = {}

rx_bps_key = "Rx Bytes Per Sec"
rx_pps_key = "Rx Packets Per Sec"
rx_errs_key = "# Rx Errors"
rx_drops_key = "# Rx Drops"
tx_bps_key = "Tx Bytes Per Sec"
tx_pps_key = "Tx Packets Per Sec"
tx_errs_key = "# Tx Errors"
tx_drops_key = "# Tx Drops"
tx_colls_key = "# Collisions"

-- Metric metdadata table
-- Used for populating metrics
if_md_tbl = {
	{	-- Rx Bytes Per Sec
		m_name = rx_bps_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Rx Packets Per Sec
		m_name = rx_pps_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Rx Errors
		m_name = rx_errs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Rx Drops
		m_name = rx_drops_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Tx Bytes Per Sec
		m_name = tx_bps_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Tx Packets Per Sec
		m_name = tx_pps_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Errors
		m_name = tx_errs_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Drops
		m_name = tx_drops_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- # Tx Collisions
		m_name = tx_colls_key,
		m_type = metric_type.mt_agg,
		m_dmm_mode = dmm_mode.dmm_adv,
		m_time_roll = time_rollup.tr_sum,
		m_cluster_roll = cluster_rollup.cr_coll,
		m_agg_roll = agg_rollup.ar_avg,
	},
}

-- Global interface metrics zero table
g_ifm_zero_tbl = {
	[rx_bps_key] = 0,
	[rx_pps_key] = 0,
	[rx_errs_key] = 0,
	[rx_drops_key] = 0,
	[tx_bps_key] = 0,
	[tx_pps_key] = 0,
	[tx_errs_key] = 0,
	[tx_drops_key] = 0,
	[tx_colls_key] = 0,
}


-- Global holding some data from the previous round.
-- This is needed because for some statistics like bps, pps we need
-- to store the previously computed data.
g_interface_prev_data = {}

-- Function callback called by tha application to get interface statistics.
function interface_statistics_fn(interface)
	return get_if_stats(interface)
end

-- Function callback called by tha application to get interface metrics.
function interface_metrics_fn(interface)
	local _val_table = {}
	local _tmp_table = {}
	local stats_table = get_if_stats(interface)

	if (stats_table == nil) then return nil end
	--dump(stats_table)

	if g_interface_prev_data[interface] == nil then
		local _tmp_intf_table = {}
		local _tmp_stats_table = {}

		_tmp_intf_table.time = os.time()

		for k, v in pairs(stats_table) do
			_tmp_stats_table[k] = v
		end

		_tmp_intf_table.value_table = _tmp_stats_table

		g_interface_prev_data[interface] = _tmp_intf_table

		--dump(g_interface_prev_data)
		_val_table = g_ifm_zero_tbl
	else
		local _tmp_intf_table = g_interface_prev_data[interface]
		local _prev_stats_table = _tmp_intf_table.value_table
		local _new_stats_table = {}
		local _time = os.time()
		local _time_diff = _time - _tmp_intf_table.time

		-- Perform computations only if there's a time difference between
		-- current call and previous call to avoid divide by zero error.
		if (_time_diff > 0) then
			-- Compute Rx pps.
			_val_table[rx_pps_key] = (stats_table.rx_pkts -
			    _prev_stats_table.rx_pkts) / _time_diff

			-- Compute Tx pps.
			_val_table[tx_pps_key] = (stats_table.tx_pkts -
			    _prev_stats_table.tx_pkts) / _time_diff

			-- Compute Rx bps.
			_val_table[rx_bps_key] = (stats_table.rx_bytes -
			    _prev_stats_table.rx_bytes) / _time_diff

			-- Compute Tx bps.
			_val_table[tx_bps_key] = (stats_table.tx_bytes -
			    _prev_stats_table.tx_bytes) / _time_diff

			-- Compute # Rx errors.
			_val_table[rx_errs_key] = (stats_table.rx_errs -
			    _prev_stats_table.rx_errs)

			-- Compute # Rx drops.
			_val_table[rx_drops_key] = (stats_table.rx_drops -
			    _prev_stats_table.rx_drops)

			-- Compute # Tx errors.
			_val_table[tx_errs_key] = (stats_table.tx_errs -
			    _prev_stats_table.tx_errs)

			-- Compute # Tx drops.
			_val_table[tx_drops_key] = (stats_table.tx_drops -
			    _prev_stats_table.tx_drops)

			-- Compute # Collisions.
			_val_table[tx_colls_key] = (stats_table.colls -
			    _prev_stats_table.colls)
		else
			_val_table = g_ifm_zero_tbl
		end

		-- Overwrite previous interface table
		for k, v in pairs(stats_table) do
			_new_stats_table[k] = v
		end

		_tmp_intf_table.time = _time
		_tmp_intf_table.value_table = _new_stats_table
	end

	return _val_table
end

--[[
Record for populating this plugin.
--]]
function plugin_init()
	return {
		-- Plugin info
		plugin_name = "Interface",
		plugin_type = "monitoring",

		-- Metrics info
		metrics_md = "if_md_tbl",
		metrics_cb = "interface_metrics_fn",
		metrics_arg1 = "APPD_INTERFACE",
	}
end

function plugin_fini()
	return
end

interface_module.plugin_init = plugin_init
interface_module.plugin_fini = plugin_fini

return interface_module
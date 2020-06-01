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

local process_module = {}

-- Keys reported by the plugin
cpu_key = "CPU (%)"
mem_kb_key = "Memory (KB)"
mem_pc_key = "Memory (%)"

-- Metric metdadata table
-- Used for populating metrics
process_md_tbl = {
	{	-- CPU (%)
		m_name = cpu_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Memory (KB)
		m_name = mem_kb_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
	{	-- Memory (%)
		m_name = mem_pc_key,
		m_type = metric_type.mt_avg,
		m_dmm_mode = dmm_mode.dmm_kpi,
		m_time_roll = time_rollup.tr_avg,
		m_cluster_roll = cluster_rollup.cr_indv,
		m_agg_roll = agg_rollup.ar_avg,
	},
}

-- Default metric table to use in case of failures.
g_metric_zero_tbl = {
	[cpu_key] = 0,
	[mem_kb_key] = 0,
	[mem_pc_key] = 0,
}

-- Global variable to enable Fault Injection.
g_inject_fault = false

-- Global variables requiring a one time initialization.
g_clk_tck = 0
g_tot_mem = 0
g_pg_sz = 0

-- Global flag to indicate whether the variables requiring one time
-- initialization have been initd or not.
globals_initd = 0

-- Global process load table
g_proc_load={}

-- Function to set globals
function set_globals()
	-- Set clock tick
	local _op = run_command("getconf CLK_TCK")
	if _op == nil then
		log("error", "process.lua: could not acquire the clock tick of system")
		return nil
	end
	g_clk_tck = tonumber(_op) or 0

	-- Set total memory
	_op = read_file("/proc/meminfo")
	if _op == nil then
		log("error", "process.lua: could not acquire the total memory of the system")
		return nil
	end
	g_tot_mem = generic_complex_parse_fn(_op, "MemTotal:%s*(%d+)%s*kB", 1)
	g_tot_mem = tonumber(g_tot_mem) or 0

	-- Set page size
	_op = run_command("getconf PAGE_SIZE")
	if _op == nil then
		log("error", "process.lua: could not acquire the current page size of the system")
		return nil
	end
	g_pg_sz = tonumber(_op) or 0

	-- Set globals_initd flag if all variables look ok.
	if g_clk_tck ~= 0 and g_tot_mem ~= 0 and g_pg_sz ~= 0 then
		globals_initd = 1
	end

	return 1
end

-- Function to update the cpu usage table
function update_stats(cpu_table, used, total)
	if cpu_table["used"] == nil then
		cpu_table["used"] = used
		cpu_table["total"] = total
		cpu_table["usage"] = 0
	else
		cpu_table["total"] = total - cpu_table["total"]
		cpu_table["used"] = used - cpu_table["used"]
		if cpu_table["total"] == 0 then
			cpu_table["usage"] = 0
		else
			cpu_table["usage"] = (cpu_table["used"] * 100)
			    / cpu_table["total"]
		end
		cpu_table["total"] = total
		cpu_table["used"] = used
	end
end

-- Function to compute CPU usage per process
-- We use values from /proc/<pid>/stat to compute CPU usage for a process.
-- More specifically utime, stime, cutime and cstime are used to
-- compute number of clock ticks used by the process.
-- The total number of ticks is taken from /proc/uptime.
function compute_cpu_and_mem(process)
	-- Set globals if required
	if globals_initd == 0 then
		local _ret = set_globals()
		if _ret == nil then return nil end
	end

	if g_proc_load[process] == nil then
		g_proc_load[process] = {}
	end


	if g_proc_load[process]["pid"] == nil then
		local _pid = get_pidof(process)
		if _pid == 0 then 
			log("error", "process.lua: unable to acquire the PID of the current process, PID is reported as 0")
			
			-- In this case then the filepath can be the self folder
			-- so leave the default for the self folder because the 
			-- appd-netagent process is the owner of the lua process
		end
		
		g_proc_load[process]["pid"] = _pid
	end

	local _filepath = ""

	if g_proc_load[process]["pid"] ~= 0 then
		_filepath = "/proc/" .. g_proc_load[process]["pid"] .. "/stat"
	else
		-- /proc/self/stat is a "magic" symlink in linux procfs that gets the 
		-- stat file for the calling process which in this case would be appd-netagent
		_filepath = "/proc/self/stat"
	end

	-- Read /proc/<pid>/stat file or the /proc/self/stat
	_op = read_file(_filepath)
	if (_op == nil) then
		-- Failure could have happened because the process died.
		-- In that case /proc/<pid>/file must be gone
		if file_exists(_file) then
			-- Failure for some other reason
			log("error", "process.lua: could not read the proc file for current process for unforeseen reason")
			return nil
		else
			-- Failure because process died
			-- Reset the process load table. Next iteration
			-- would handle recreating all data.
			log("error", "process.lua: process information for current process does not exist, process may be dead")
			g_proc_load[process] = {}
			return nil
		end
	end

	-- Get utime, stime, cutime, cstime  fields from /proc/<pid>/stat
	local _utime, _stime, _cutime, _cstime
	local _rss
	local _column = 1
	for word in _op:gmatch("%S+") do
		-- CPU utilization metrics
		if _column == 14 then _utime = tonumber(word) end
		if _column == 15 then _stime = tonumber(word) end
		if _column == 16 then _cutime = tonumber(word) end
		if _column == 17 then _cstime = tonumber(word) end

		-- Memory utilization metrics
		if _column == 24 then
			_rss = tonumber(word)
			-- Convert _rss to KB.
			_rss = (_rss * g_pg_sz) / 1024
		end

		_column = _column + 1
	end

	-- Compute total time used by process
	local _used_time = _utime + _stime + _cutime + _cstime

	-- Read /proc/uptime
	_op = read_file("/proc/uptime")
	if (_op == nil) then 
		log("error", "process.lua: unable to get the uptime information for the process")
		return nil 
	end

	-- Get total ticks from /proc/uptime
	_column = 1
	local _uptime
	for word in _op:gmatch("%S+") do
		if _column == 1 then _uptime = tonumber(word)
		else break end
		_column = _column + 1
	end

	-- Convert uptime to ticks
	_uptime = _uptime * g_clk_tck

	-- Update the statistics for this process
	update_stats(g_proc_load[process], _used_time, _uptime)

	local _val_table = {}
	_val_table[cpu_key] = round(g_proc_load[process]["usage"], 0) or 0
	_val_table[mem_kb_key] = round(_rss, 0) or 0
	_val_table[mem_pc_key] = round((_rss * 100 / g_tot_mem), 0) or 0
	return _val_table
end

--
-- Function callback called by tha application to get process statistics.
--
function process_statistics_fn(process)
	local _val_table = compute_cpu_and_mem(process)

	return _val_table
end

--
-- Function callback called by tha application to get process metrics.
--
function process_metrics_fn(process)
	local _val_table = process_statistics_fn(process)

	if _val_table == nil or next(_val_table) == nil then
		return g_metric_zero_tbl
	else
		return _val_table
	end
end

--
-- Record for populating this plugin.
--
function plugin_init()
	return {
		-- Plugin info
		plugin_name = "Process",
		plugin_type = "monitoring",

		-- Metrics info
		metrics_md = "process_md_tbl",
		metrics_cb = "process_metrics_fn",
		metrics_arg1 = "APPD_PROCESS",
	}
end

function plugin_fini()
	return
end

process_module.plugin_init = plugin_init
process_module.plugin_fini = plugin_fini

return process_module
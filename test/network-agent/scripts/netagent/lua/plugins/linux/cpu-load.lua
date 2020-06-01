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

local cpu_load_module = {}

g_num_cpus = 0
-- function to get number of CPUs in a system
function get_cpus()
	local num_cpus = 0
	for line in io.lines("/proc/cpuinfo") do
		if string.find(line, "processor") then
			num_cpus = num_cpus + 1
		end
	end
	return num_cpus
end

-- Global stats table
g_cpu_load = {}

-- Function to update the CPU table statistics.
function update_stats(cpu_table, total, idle)
	if next(cpu_table) == nil then
		cpu_table["total"] = total
		cpu_table["idle"] = idle
		cpu_table["usage"] = 0
	else
		cpu_table["total"] = total - cpu_table["total"]
		cpu_table["idle"] = idle - cpu_table["idle"]
		cpu_table["usage"] =
		    ((cpu_table["total"] - cpu_table["idle"]) * 100) / cpu_table["total"]
		cpu_table["total"] = total
		cpu_table["idle"] = idle
	end
end

-- get cpu load from /proc/stat
function get_cpuload()
	local cpu
	local user, nice, sys, sys_idle, iowait, irq, softirq, steal, quest, quest_nice
	local total, idle

	-- Compute the number of CPU's in the system first time the api is called
	if g_num_cpus == 0 then
		g_num_cpus = get_cpus()
	end

	for line in io.lines("/proc/stat") do
		-- Parsing for individual CPU stats.
		_, _, cpu = string.find(line, "cpu(%d*)")

		if cpu ~= nil then
			_, _, user, nice, sys, sys_idle, iowait, irq, softirq, steal, quest, quest_nice =
			    string.find(line, "%a%d*%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*")
			total = user + nice + sys + sys_idle + iowait + irq + softirq + steal + quest + quest_nice
			idle = sys_idle + iowait

			if cpu == '' then
				-- Empty cpu string implies overall CPU usage.
				-- Use index g_num_cpus for it.
				cpu = g_num_cpus
			else
				-- For a particular cpu, convert cpu to number
				cpu = tonumber(cpu)
			end

			if g_cpu_load[cpu] == nil then
				g_cpu_load[cpu] = {}
			end

			update_stats(g_cpu_load[cpu], total,idle)
		end
	end

	return g_cpu_load
end

--[[
Function callback called by tha application to get cpu statistics.
--]]
function cpu_statistics_fn()
	local _val_table = {}
	local _cpu_load = get_cpuload()

	-- Compute individual CPU usage metric
	for _cpu=0,g_num_cpus-1 do
		if _cpu_load[_cpu] then
			_val_table["CPU " .. _cpu .. " usage (%)"] =
			round(_cpu_load[_cpu]["usage"], 0)
		end
	end

	-- Compute overall CPU usage metric. Index g_num_cpus is used for overall CPU
	_val_table["Overall CPU usage (%)"] = round(_cpu_load[g_num_cpus]["usage"], 0)

	return _val_table
end

--[[
Function callback called by tha application to get cpu metrics.
--]]
function cpu_metrics_fn()
	local _val_table = cpu_statistics_fn()

	return _val_table
end

--[[
Record for populating this plugin.
--]]
function plugin_init()
	return {
		-- Plugin info
		plugin_name = "CPU",
		plugin_type = "monitoring",

		-- Metrics info
		metrics_cb = "cpu_metrics_fn",
	}
end

function plugin_fini()
	return
end

cpu_load_module.plugin_init = plugin_init
cpu_load_module.plugin_fini = plugin_fini

return cpu_load_module
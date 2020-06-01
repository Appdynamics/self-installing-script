--
-- Copyright (c) 2015 AppDynamics Inc.
-- All rights reserved.
--
-- $Id$
package.path = './?.lua;' .. package.path
require "config_helper"

ROOT_DIR="/opt/appdynamics/netviz"
INSTALL_DIR=ROOT_DIR
-- Define a unique hostname for identification on controller
UNIQUE_HOST_ID = ""

-- Define the ip of the interface where webservice is bound
WEBSERVICE_IP="127.0.0.1"

--
-- NPM global configuration
-- Configurable params
-- {
--	enable_monitor = 0/1,	-- def:0, enable/disable monitoring
--	disable_filter = 0/1,	-- def:0, disable/enable language agent filtering
--	mode = KPI/Diagnostic/Advanced,	-- def:KPI
--	lua_scripts_path	-- Path to lua scripts.
--	enable_fqdn = 0/1	-- def:0, enable/disable fqdn resolution of ip
--	enable_netlib = 1/0	-- def:1 Disable/enable app filtering
--	app_filtering_channel	-- def:tcp://127.0.0.1:3898, Channel for app
--	filetering messages between App agents and Network Agent
--	backoff_enable = 0/1	-- def:1 Enable/Disable agent backoff module
--	backoff_time = [90 - 1200]	-- def:300, Agent auto backoff kick in period in secs
-- }
--
npm_config = {
	log_destination = "file",
	log_file = "appd-netagent.log",
	debug_log_file = "agent-debug.log",
	disable_filter = 1,
	mode = "KPI",
	enable_netlib = 1,
	lua_scripts_path = ROOT_DIR .. "/scripts/netagent/lua/",
	enable_fqdn = 1,
	backoff_enable = 1,
	backoff_time = 300,
}

--
-- Webserver configuration
-- Configurable params
-- {
--	host = ,	-- Ip on which webserver is listening on. Default set to
--			-- localhost. Set it to 0.0.0.0 to listen on all
--	port = ,		-- Port on which to open the webserver
--	request_timeout = , -- Request timeout in ms
--	threads = ,		-- Number of threads on the webserver
-- }
--
webserver_config = {
	host = WEBSERVICE_IP,
	port = 3892,
	request_timeout = 10000,
	threads = 4,
}

--
-- Packet capture configurations (multiple captures can be configured)
-- Confiurable params, there can be multiple of these.
-- {
-- 	cap_module = "pcap",		-- def:"pcap", capture module
-- 	cap_type = "device"/"file",	-- def:"device", type of capture
-- 	ifname = "",		-- def:"any", interface name/pcap filename
-- 	enable_promisc = 0/1,	-- def:0, promiscuous mode pkt capture
-- 	thinktime = ,		-- def: 100, time in msec, to sleep if no pkts
-- 	snaplen = ,		-- def:1518. pkt capture len
-- 	buflen = ,		-- def:2. pcap buffer size in MB
-- 	ppi = ,			-- def:32. pcap ppi
-- },
--
capture = {
	-- first capture interface
	{
		cap_module = "pcap",
		cap_type = "device",
		ifname = "any",
		thinktime = 25,
		buflen = 48,
--		filter = "",
	},
--[[	{
		cap_module = "pcap",
		cap_type = "device",
		ifname = "en0",
	},
--]]
}

--
-- IP configuration
-- ip_config = {
--	expire_timeout = ,	-- Mins after which we expire ip metadata
--	retry_count = ,		-- No of tries to resolve fqdn for ip
-- }
ip_config = {
	expire_interval = 20,
	retry_count = 5,
}

--
-- DPI configuration
-- Configurable params
-- {
--	max_flows = ,	-- Max number of flows per fg to DPI at any given time.
--	max_data = ,	-- Max mega bytes to DPI per flow.
--	max_depth = ,	-- Max bytes to DPI in a packet
--	max_callchains = , -- Max callchains to store for a flowgroup
--	max_cc_perflow = , -- Max number of call chains to look for in each flow
-- }
--
dpi_config = {
	max_flows = 10,
	max_data = 4,
	max_depth = 4096,
	max_callchains_in_fg = 32,
	max_callchains_in_flow = 2,
}

-- Configurations for application service ports
-- {
--	ports = ,	-- Comma separated list of application service
--			   ports greater than 32000. Example
--			   ports = "40000, 41000, 42000"
-- }
--[[
application_service_ports = {
	ports = "",
}
--]]

--
-- Export data from network agent configuration/tunnables
-- Configurable params, there can be multiple of these.
-- {
-- 	exportype = "file"/"remote",	-- type of export mechanism
-- 	statsfile = "",			-- filename for stats export
-- 	metricsfile = "", 		-- filename for metrics export
-- 	serialization = "pb",		-- pb/capnp, serialization module
-- 	transport = "zmq", 		-- def:"zmq", transport module
-- 	zmqdest = "", 			-- dest peer for zmq
--  },
--
export_config = {
	-- file export
	{
		exporttype = "file",
		statsfile = "agent-stats.log",
		metricsfile = "agent-metrics.log",
		eventsfile =  "agent-events.log",
		snapshotsfile = "agent-snapshots.log",
		metadatafile = "agent-metadata.log",
	},
}

-- Plugin interface configuration.
-- List of interfaces to be monitored by supported plugins.
-- Configurable params, there can be multiple of these.
-- {
-- 	interface = "eth0",	-- def: "eth0", interface name
-- }
plugin_if_config = {
--[[
	{interface = "eth0"},
--]]
}

-- Plugin process configuration.
-- List of processes to be monitored by supported plugins.
-- Configurable params, there can be multiple of these.
-- {
--	process = "",		-- def: "appd-netagent", process name
-- }
plugin_proc_config = {
	{process = "appd-netagent"},
}

-- Config to define the usage limits of netagent
-- Configurable params
-- {
-- 	enable = , 	-- enable/disable selfmon module
-- 	interval = , 	-- Timeperiod after which selfmon module runs (in sec)
-- 	max_memory = , 	-- Max Memory that can be used by agent (in MB)
-- }
--[[
	selfmon_config = {
		enable = 1,
		interval = 30,
		max_memory = 750,
	}
--]]

-- metadata to pass to pass the agent metadata specific params
system_metadata = {
	unique_host_id = UNIQUE_HOST_ID,
	install_dir = INSTALL_DIR,
	install_time = get_last_update_time(),
}

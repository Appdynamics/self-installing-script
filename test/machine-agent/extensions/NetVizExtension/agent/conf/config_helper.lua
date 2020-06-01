--
-- Copyright (c) 2015 AppDynamics Inc.
-- All rights reserved.
--
-- $Id$

function os.capture(cmd, raw)
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*all'))
	f:close()
    if raw then return s end
    s = s:remove_whitespace()
	return s
end

if not io.fileseparator then
    if string.find(os.getenv("PATH"),";",1,true) then
        io.fileseparator, io.pathseparator, os.type = "\\", ";", os.type or "mswin"
    else
        io.fileseparator, io.pathseparator, os.type = "/" , ":", os.type or "unix"
    end
end

function get_last_update_time()
    if (os.type == unix) then
        local curr_dir = os.capture("pwd", false)
        local stat_fmt = "-c %Y"
        if (OS_NAME == "Darwin") then
            stat_fmt = "-f %B"
        end
        local stat_cmd = "stat " .. stat_fmt .. " \"" .. curr_dir .. "\""
        local  time_update = os.capture(stat_cmd, false)
        epoch_time_update = tonumber(time_update)
    else
		epoch_time_update = 0
    end
	return epoch_time_update
end
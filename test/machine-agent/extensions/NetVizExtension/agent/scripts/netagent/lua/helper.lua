--[[
 * Copyright (c) AppDynamics, Inc., and its affiliates
 * 2015
 * All Rights Reserved
 * THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
 * The copyright notice above does not evidence any actual or intended
 * publication of such source code
--]]

--[[
TODO: Check the parameters being passed to the api's. The api's
are expecting a certain type for each argument but no checking
is currently happening.
--]]
require "dumper"
function dump(...)
	print(DataDumper(...), "\n---")
end

-- TODO: Find a way to insert the match pattern
-- into the string. Right now %a does not work.
g_match_pattern = "@match_pattern@"

--[[
Set of magic characters for pattern matching purposes. Used in string
searches where the string to be searched itself has a magic character.
NOTE: "%" is the first entry in the table for a reason. "%" acts like
an escape character itslef. And we don't want to escape it twice.
--]]
g_magic_chars = {"(", ")", ".", "+", "-", "*", "?", "[", "]", "^", "$"}

--[[
Function to sleep for a given number of seconds.
--]]
function sleep(n)
	os.execute("sleep " .. tonumber(n))
end

--[[
Function to round up/down a number to a given precision.
Adopted from http://lua-users.org/wiki/SimpleRound
--]]
function round(num, idp)
	if num == nil then return 0 end

	local _mult = 10^(idp or 0)
	return math.floor(num * _mult + 0.5) / _mult
end

-- the filename for the logging for the extensions
-- this will produce the log file inside of the folder
-- from which the executable is running
g_log_filename = "plugins.log"
g_log_filepath = "../logs/" .. g_log_filename
g_working_dir = nil

g_logger_fh = nil

--[[
Open the logger file handler for use. This is to prevent multiple open
and closes of the same file for logging. The Lua interpreter will close
the file when the interpreter shuts down along with appd-netagent
@returns - the file handler if successful or nil otherwise
--]]
function openLogger()
    if g_logger_fh ~= nil then
            return g_logger_fh
    end

    if g_working_dir == nil then
            g_working_dir = run_command("pwd")

            if g_working_dir == nil then
                    g_log_filepath = g_log_filename
                    g_working_dir = "."
            end
    end

    if string.find(g_working_dir, "/home", -6) == nil then
            g_log_filepath = g_log_filename
    end

    g_logger_fh = io.open(g_log_filepath, "a")
    return g_logger_fh
end

--[[
Log a message to the log file with a severity level
@param severity - the severity of the log message (error, warn, etc.)
@param message - the message to put inside of the log
Note: this currently is for Linux support only and the Linux plugins
--]]
function log(severity, message)
	local _file = openLogger()

	if _file == nil then
		return
	end

	-- Put the date as mm/dd/yyyy hh:mm:ss
	_file:write(os.date("%x %X") .. " [" .. string.upper(severity) .. "] : " .. message .. "\n")
end

--[[
Run a command on the system.
@param command	- the command to be run provided as string.
@return		- the ouput of the command returned as string.
--]]
function run_command(command)
	local _file = io.popen(command .. " 2>/dev/null")
	if _file == nil then return nil end

	local _output = _file:read("*all")
	_file:close()
	return _output
end

--[[
Read a file from the system and return its content
@param filename - name of file to br read.
@return		- contents of the file returned as string.
--]]
function read_file(filename)
	local _file = io.open(filename, "r")
	if _file == nil then return nil end

	local _output = _file:read("*all")
	_file:close()
	return _output
end

-- Get pid of given process
function get_pidof(process)
	local _cmd = "pidof " .. process
	local _ret = run_command(_cmd)

	-- Handle the case of process not running.
	if _ret == nil or _ret == '' then return 0 end

	-- Handle the case of 2 or more processes running. Use the first one.
	_, _, _pid = string.find(_ret, "%s*(%d+)%s*")
	return tonumber(_pid)
end

-- Check if given file exists
function file_exists(file)
	local _f = io.open(file, "r")
	if _f ~= nil then
		io.close(_f)
		return true
	else
		return false
	end
end

--[[
A generic function to capture a pattern from a given string. Useful in cases like
a) If the value to be extracted is a string.
b) When there are multiple numbers in the string.
TODO: Make it flexibe enough to return multiple values.
@param str	- The string to be searched.
@param pattern	- The pattern to be used for searching.
@param arg	- The argument number where the value resides.
@return		- The desired value. nil on errors.
--]]
function generic_complex_parse_fn(str, pattern, arg)
	if (type(str) ~= "string") then return nil end
	if (type(pattern) ~= "string") then return nil end
	if (arg < 1 or arg > 10) then return nil end

	a, b, c, d, e, f, g, h, i, j = string.match(str, pattern)

	if arg == 1 then return a
	elseif arg == 2 then return b
	elseif arg == 3 then return c
	elseif arg == 4 then return d
	elseif arg == 5 then return e
	elseif arg == 6 then return f
	elseif arg == 7 then return g
	elseif arg == 8 then return h
	elseif arg == 9 then return i
	elseif arg == 10 then return j
	end

	return nil
end

--[[
Function to get specific data from the system. This is
a very generic api which can create a table of key value
pairs given a table containing all the information to
build the output table.
@param in_table	- The table holding the record details to
be processed.
@param cmd_opt_arg	- The optional argument to be passed to the
command to be run.
@return		- Table of key value pairs. The key is the paramter
field of the in_table. The value is the value determined
using this api.
--]]
function get_data(in_table, cmd_opt_arg)
	local _out_table = {}
	for key,value in pairs(in_table) do
		local _command
		local _value_str

		if cmd_opt_arg ~= nil then
			-- Replace pattern in the command if required. No side
			-- effect if pattern does not exist.
			_command = string.gsub(value["command"],
				g_match_pattern, cmd_opt_arg)
		else
			_command = value["command"]
		end

		-- Run the desired command.
		local _cmd_string = run_command(_command)

		if value["callback_fn"] == nil then
			-- Remove the newline from the output if present
			_value_str = string.gsub(_cmd_string, "\n", "")
		else
			-- Call the callback function.
			--TODO: Is there a better way to call the callback function.
			_value_str = _G[value["callback_fn"]](_cmd_string,
					value["value_pattern"], value["arg_num"])
		end

		_out_table[value["parameter"]] = _value_str

	end

	return _out_table
end

--[[
Function to count the number of times pattern occurs in
the given string.
@param str	- The string to be searched.
@param pattern	- The pattern to be searched.
@return		- Number of occurences of pattern.
--]]
function get_pattern_count(str, pattern)
	local _pattern = escape_magic_chars(pattern, g_magic_chars)
	local _, _count = string.gsub(str, _pattern, pattern)
	return _count
end

--[[
Generic iterator to iterate through all lines of a multi
line string using closure.
NOTE: This api is to be used in iterator context only.
ex: for line in multi_line_iter(str) do ... end
@param str	- The string to be iterated over.
@return		- lines in a string.
--]]
function multi_line_iter(str)
	local _pos = 1
	local _str_len = #str
	return function()
		while _pos <= _str_len do
			local _s, _e = string.find(str, '.-\n', _pos)
			if _s then
				_pos = _e + 1
				return string.sub(str, _s, _e - 1)
			else
				return nil
			end
		end
		return nil
	end
end

--[[
Generic iterator to iterate through all words of a line
using closure.
NOTE: This is to be used only in iteraor context.
ex: for word in single_line_iter(line) do ... end
@param line	- The line to be iterated over.
@return		- words in line.
--]]
function single_line_iter(line)
	local _pos = 1
	local _line_len = #line
	return function()
		while _pos <= _line_len do
			local _s, _e = string.find(line, "%g+", _pos)
			if _s then
				_pos = _e + 1
				return string.sub(line, _s, _e)
			else
				return nil
			end
		end
		return nil
	end
end

--[[
Function for parsing column based values from string.
Unfortunaltely, many of the statistics exposed via /proc are
in column based format. This is a generic api to get the value
of a field from a string representing stats in columns.
This is specific for snmp formatted string.
@param str	- The string to be parsed.
@param row_identifier	- The header pattern used to identify the
		row containing the key.
@param column_name	- The key whose value is desired.
@return		- Value of the key being searched.
--]]
function get_column_value_snmp_format(str, row_identifier, column_name,
		magic_char)
	local _magic_char = false or magic_char
	local _column_offset = 0
	local _column_offset_found = false
	for _line in multi_line_iter(str) do

		-- If the offset of the column name hasn't been found yet
		-- then find it now.
		if _column_offset_found == false then
			local _s = string.find(_line, row_identifier)
			if _s ~= nil then
				for _word in single_line_iter(_line) do
					if _word ~= column_name then
						_column_offset = _column_offset + 1
					else
						_column_offset_found = true
						break
					end
				end
			end
		else
			-- Column offset has been found. Find the corresponding
			-- column value from the next line
			local _s = string.find(_line, row_identifier)
			if _s ~= nil then
				local _i = 0
				for _word in single_line_iter(_line) do
					if _i == _column_offset then
						return _word
					else
						_i = _i + 1
					end
				end
			end
		end
	end

	return nil
end


--[[
Function for parsing column based name value pairs.
Unfortunaltely, many of the statistics exposed via /proc are
in column based format. This is a generic api to get the value
of a field from a string representing stats in columns.
In some cases like output of ps, there is no row name. In cases
like that use should pass in row_selector as nil. Make sure that
@param str	- The string to be parsed.
@param column_name	- The key whose value is desired.
@return		- Value of the key being searched.
--]]
function get_column_value(str, row_selector, column_selector,
		magic_char)
	-- By default magic character replace is turned off.
	local _magic_char = false or magic_char
	local _column_offset = 0
	local _column_offset_found = false
	local _row_selector
	local _column_selector

	-- Setup the _row_selector and _column_selector based on
	-- whether _magic_char is set or not.
	if _magic_char == true then
		if row_selector == nil then
			_row_selector = nil
		else
			_row_selector = escape_magic_chars(
			    row_selector, g_magic_chars)
		end
		_column_selector = escape_magic_chars(column_selector,
		    g_magic_chars)
	else
		_row_selector = row_selector
		_column_selector = column_selector
	end

	--dump(str)
	--dump(_row_selector)
	--dump(_column_selector)
	for _line in multi_line_iter(str) do

		-- If the offset of the column name hasn't been found yet
		-- then find it now.
		if _column_offset_found == false then
			local _s = string.find(_line, _column_selector)
			if _s ~= nil then
				for _word in single_line_iter(_line) do
					if _word ~= column_selector then
						_column_offset = _column_offset + 1
					else
						_column_offset_found = true
						break
					end
				end
			end
		else
			-- Column offset has been found. Find the corresponding
			-- column value from the next line
			local _s
			-- If the row selector is nil then just use the next line
			-- to get value of column.
			if _row_selector == nil then
				_s = _line
			else
				_s = string.find(_line, _row_selector)
			end
			--dump(_s)

			if _s ~= nil then
				local _i = 0
				for _word in single_line_iter(_line) do
					if _i == _column_offset then
						return _word
					else
						_i = _i + 1
					end
				end
				return nil
			end
		end
	end

	return nil
end

--[[
Generic function to escape magic characters from the string.
TODO: This will probably not work if the magic_char_table
contains the escape character(%) itself.
@param str	- The string which needs to be formatted.
@param magic_char_table	- Table containing list of magic
		characters to be escaped.
@return	- New string with the magic characters escaped.
--]]
function escape_magic_chars(str, magic_char_table)
	local _s = str
	for _, _char in ipairs(magic_char_table) do
		_s = string.gsub(_s, ("%" .. _char), "%%%1")
		--dump(_s)
	end
	return _s
end

--[[
Generic function to merge 2 tables. This makes sure that
the new table is of the form key = value i.e the final
table has the key as well as value.
NOTE: Make sure that the table is not a table of records.
Else since the keys are indices, the original values of
table1 will be overwritten.
@param table1	- The first table to be merged.
@param table2	- The second table to be merged.
@return			- The merged table.
--]]
function merge_tables(table1, table2)
	local _t = {}

	for _k, _v in pairs(table1) do
		_t[_k] = _v
	end

	for _k, _v in pairs(table2) do
		_t[_k] = _v
	end

	return _t
end

--[[
Generic function to merge 2 records. Records are nothing but
lists. Since they are lists, we do not care about the keys.
This api is useful for merging 2 table records.
@param record1	- The first record to be merged.
@param record2	- The second record to be merged.
@return			- The merged record.
--]]
function merge_records(record1, record2)
	local _t = {}

	for _, _v in pairs(record1) do
		table.insert(_t, _v)
	end

	for _, _v in pairs(record2) do
		table.insert(_t, _v)
	end

	return _t
end

--[[
Generic iterator to iterate over a table using a given
sort function.
--]]
function spairs(t, order)
	-- collect the keys
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end

	-- if order function given, sort by it by passing the table and keys a, b,
	-- otherwise just sort the keys
	if order then
		table.sort(keys, function(a,b) return order(t, a, b) end)
	else
		table.sort(keys)
	end

	-- return the iterator function
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

--
-- Function to parse and get interface stats from proc entry.
-- If no interface is provided then aggregate metrics from all interfaces.
--
function get_if_stats(interface)
	local line_num = 0
	local val_tbl = {rx_bytes = 0, rx_pkts = 0, rx_errs = 0, rx_drops = 0,
	    tx_bytes = 0, tx_pkts = 0, tx_errs = 0, tx_drops = 0, colls = 0}
	local fmt1 = "%s*(%w+):%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*%d+%s*%d+%s*%d+%s*%d+%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*%d+%s*(%d+)"
	local fmt2 = "%s*(%w+):%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*%d+%s*%d+%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*%d+%s*(%d+)"
	local op = read_file("/proc/net/dev")
	if op == nil then return nil end

	for line in multi_line_iter(op) do
		if line_num == 1 then
			-- The output of /proc/net/dev could be different on OS.
			-- The following logic determines which format to use.
			if string.find(line, "compressed") ~= nil then
				fmt = fmt1
			elseif string.find(line, "bytes") ~= nil then
				fmt = fmt2
			end
		elseif line_num >= 2 then
			_, _, intf, rx_bytes, rx_pkts, rx_errs, rx_drops,
			    tx_bytes, tx_pkts, tx_errs, tx_drops,
			    colls = string.find(line, fmt)
			if (intf == interface or (not interface and intf ~= nil)) then
				val_tbl.rx_bytes = val_tbl.rx_bytes + rx_bytes
				val_tbl.rx_pkts = val_tbl.rx_pkts + rx_pkts
				val_tbl.rx_errs = val_tbl.rx_errs + rx_errs
				val_tbl.rx_drops = val_tbl.rx_drops + rx_drops
				val_tbl.tx_bytes = val_tbl.tx_bytes + tx_bytes
				val_tbl.tx_pkts = val_tbl.tx_pkts + tx_pkts
				val_tbl.tx_errs = val_tbl.tx_errs + tx_errs
				val_tbl.tx_drops = val_tbl.tx_drops + tx_drops
				val_tbl.colls = val_tbl.colls + colls
			end
		end
		line_num = line_num + 1
	end

	return val_tbl
end

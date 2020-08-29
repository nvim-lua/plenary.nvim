
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------

do
    local searchers = package.searchers or package.loaders
    local origin_seacher = searchers[2]
    searchers[2] = function(path)
        local files =
        {
------------------------
-- Modules part begin --
------------------------

["plenary.context_manager"] = function()
--------------------
-- Module: 'plenary.context_manager'
--------------------
--- I like context managers for Python
--- I want them in Lua.

local context_manager = {}

function context_manager.with(obj, callable)
  -- Wrap functions for people since we're nice
  if type(obj) == 'function' then
    obj = coroutine.create(obj)
  end

  if type(obj) == 'thread' then
    local ok, context = coroutine.resume(obj)
    assert(ok, "Should have yielded in coroutine.")

    local result = callable(context)

    local done, _ = coroutine.resume(obj)
    assert(done, "Should be done")

    local no_other = not coroutine.resume(obj)
    assert(no_other, "Should not yield anymore, otherwise that would make things complicated")

    return result
  else
    assert(obj.enter)
    assert(obj.exit)

    -- TODO: Callable can be string for vimL function or a lua callable
    local context = obj:enter()
    local result = callable(context)
    obj:exit()

    return result
  end
end

--- @param filename string|table -- If string, used as io.open(filename)
---                                 Else, should be a table with `filename` as an attribute
function context_manager.open(filename, mode)
  if type(filename) == 'table' and filename.filename then
    filename = filename.filename
  end

  local file_io = assert(io.open(filename, mode))

  return coroutine.create(function()
    coroutine.yield(file_io)

    file_io:close()
  end)
end

return context_manager

end,

["plenary.debug_utils"] = function()
--------------------
-- Module: 'plenary.debug_utils'
--------------------
local debug_utils = {}

function debug_utils.sourced_filepath()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str
end

function debug_utils.sourced_filename()
  local str = debug_utils.sourced_filepath()
  return str:match("^.*/(.*).lua$") or str
end


return debug_utils

end,

["plenary.functional"] = function()
--------------------
-- Module: 'plenary.functional'
--------------------
local f = {}

function f.map(fun, iter)
  local results = {}
  for _, v in pairs(iter) do
    table.insert(results, fun(v))
  end

  return results
end

function f.partial(fun, ...)
  local args = {...}
  return function(...)
    return fun(unpack(args), ...)
  end
end

function f.any(f, iterable)
  for k, v in pairs(iterable) do
    if f(k, v) then
      return true
    end
  end

  return false
end

function f.all(f, iterable)
  for k, v in pairs(iterable) do
    if not f(k, v) then
      return false
    end
  end

  return true
end

function f.select_only(n)
  return function(...)
    local x = select(n, ...)
    return x
  end
end

f.first = f.select_only(1)
f.second = f.select_only(2)
f.third = f.select_only(3)

function f.last(...)
  local length = select('#', ...)
  local x = select(length, ...)
  return x
end

return f

end,

["plenary.job"] = function()
--------------------
-- Module: 'plenary.job'
--------------------
local vim = vim
local uv = vim.loop

local log = require('plenary.log')

local Job = {}
Job.__index = Job

local function close_safely(handle)
  if not handle:is_closing() then
    handle:close()
  end
end

local shutdown_factory = function (child)
  return function(code, signal)
    child:shutdown(code, signal)
  end
end


--- Create a new job
--@param o table
--@field o.command string  : Command to run
--@field o.args Array      : List of arguments to pass
--@field o.cwd string      ? Working directory for job
--@field o.env Map         : Environment
--@field o.detach callable : Function to call on detach.
--
--@field o.call_on_lines boolean? Only call callbacks on line.
function Job:new(o)
  local obj = {}

  obj.command = o.command
  obj.args = o.args
  obj.cwd = o.cwd
  obj.env = o.env
  obj.detach = o.detach

  obj._user_on_start = o.on_start
  obj._user_on_stdout = o.on_stdout
  obj._user_on_stderr = o.on_stderr
  obj._user_on_exit = o.on_exit

  obj._additional_on_exit_callbacks = {}

  obj._maximum_results = o.maximum_results

  obj.user_data = {}

  return setmetatable(obj, self)
end

--- Send data to a job.
function Job:send(data)
  self.stdin:write(data)

  -- TODO: I don't remember why I put this.
  -- self.stdin:shutdown()
end

--- Stop a job and close all handles
function Job:_stop()
  close_safely(self.stdin)
  close_safely(self.stderr)
  close_safely(self.stdout)
  close_safely(self.handle)
end

--- Shutdown a job.
function Job:shutdown(code, signal)
  self.code = code
  self.signal = signal

  if self._user_on_exit then
    self:_user_on_exit(code, signal)
  end

  for _, v in ipairs(self._additional_on_exit_callbacks) do
    v(self, code, signal)
  end

  self.stdout:read_stop()
  self.stderr:read_stop()

  self:_stop()

  self.is_shutdown = true
end

function Job:_create_uv_options()
  local options = {}

  self.stdin = uv.new_pipe(false)
  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)

  options.command = self.command
  options.args = self.args
  options.stdio = {
    self.stdin,
    self.stdout,
    self.stderr
  }

  if self.cwd then
    options.cwd = self.cwd
  end

  if self.env then
    options.env = self.env
  end

  if self.detach then
    options.detach = self.detach
  end

  return options
end

-- TODO: Add the ability to have callback called ONLY on complete lines.
--          Remember, to send the last line when you're done though :laugh:
local on_output = function(self, cb)
  if not self.results then
    self.results = {''}
  end

  local results = self.results

  return function(err, data)
    if data == nil then
      if results[#results] == '' then
        table.remove(results, #results)
      end

      return
    end

    local line, start, found_newline
    repeat
      start = string.find(data, "\n") or #data
      found_newline = string.find(data, "\n")

      line = string.sub(data, 1, start)
      data = string.sub(data, start + 1, -1)

      line = line:gsub("\r", "")

      results[#results] = (results[#results] or '') .. line

      if found_newline then
        local result_number = #results

        if cb then
          cb(err, results[result_number], self)
        end

        -- Stop processing if we've surpassed the maximum.
        if self._maximum_results then
          if result_number > self._maximum_results then
            self:shutdown()
            return
          end
        end

        table.insert(results, '')
      end
    until not found_newline

  end
end

function Job:start()
  local options = self:_create_uv_options()

  if self._user_on_start then
    self:_user_on_start()
  end

  self.handle, self.pid = uv.spawn(
    options.command,
    options,
    vim.schedule_wrap(shutdown_factory(self))
  )

  self.stdout:read_start(on_output(self, self._user_on_stdout))
  self.stderr:read_start(on_output(self, self._user_on_stderr))

  return self
end

function Job:sync()
  self:start()
  self:wait()

  return self:result()
end

function Job:result()
  return self.results
end

function Job:pid()
  return self.pid
end

function Job:wait()
  if self.handle == nil then
    vim.api.nvim_err_writeln(vim.inspect(self))
    return
  end

  while not vim.wait(100, function() return not self.handle:is_active() or self.is_shutdown end, 10) do
  end

  return self
end

function Job:co_wait(wait_time)
  wait_time = wait_time or 5

  if self.handle == nil then
    vim.api.nvim_err_writeln(vim.inspect(self))
    return
  end

  while not vim.wait(wait_time, function() return self.is_shutdown end) do
    coroutine.yield()
  end

  return self
end

--- Wait for all jobs to complete
function Job.join(...)
  local jobs_to_wait = {...}

  while true do
    if #jobs_to_wait == 0 then
      break
    end

    local current_job = jobs_to_wait[1]
    if current_job.is_shutdown then
      table.remove(jobs_to_wait, 1)
    end

    -- vim.cmd.sleep(10)
    vim.cmd("sleep 100m")
  end
end

local _request_id = 0
local _request_status = {}

function Job.chain(...)
  _request_id = _request_id + 1
  _request_status[_request_id] = false

  local jobs = {...}

  for index, job in ipairs(jobs) do
    if index ~= 1 then
      local prev_job = jobs[index - 1]
      local original_on_exit = prev_job._user_on_exit
      prev_job._user_on_exit = function(self, err, data)
        if original_on_exit then
          original_on_exit(self, err, data)
        end

        job:start()
      end
    end
  end

  local last_on_exit = jobs[#jobs]._user_on_exit
  jobs[#jobs]._user_on_exit = function(self, err, data)
    if last_on_exit then
      last_on_exit(self, err, data)
    end

    _request_status[_request_id] = true
  end

  jobs[1]:start()

  return _request_id
end

function Job.chain_status(id)
  return _request_status[id]
end

function Job.is_job(item)
  if type(item) ~= 'table' then
    return false
  end

  return getmetatable(item) == Job
end

function Job:add_on_exit_callback(cb)
  table.insert(self._additional_on_exit_callbacks, cb)
end

return Job

end,

["plenary.log"] = function()
--------------------
-- Module: 'plenary.log'
--------------------
-- log.lua
--
-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.


local p_debug = vim.fn.getenv("DEBUG_PLENARY")
if p_debug == vim.NIL then
  p_debug = false
end

-- User configuration section
local default_config = {
  -- Name of the plugin. Prepended to log messages
  plugin = 'plenary',

  -- Should print the output to neovim while running
  use_console = true,

  -- Should highlighting be used in console (using echohl)
  highlights = true,

  -- Should write to a file
  use_file = true,

  -- Any messages above this level will be logged.
  level = p_debug and "debug" or "info",

  -- Level configuration
  modes = {
    { name = "trace", hl = "Comment", },
    { name = "debug", hl = "Comment", },
    { name = "info",  hl = "None", },
    { name = "warn",  hl = "WarningMsg", },
    { name = "error", hl = "ErrorMsg", },
    { name = "fatal", hl = "ErrorMsg", },
  },

  -- Can limit the number of decimals displayed for floats
  float_precision = 0.01,
}

-- {{{ NO NEED TO CHANGE
local log = {}

local unpack = unpack or table.unpack

log.new = function(config, standalone)
  config = vim.tbl_deep_extend("force", default_config, config)

  local outfile = string.format('%s/%s.log', vim.api.nvim_call_function('stdpath', {'data'}), config.plugin)

  local obj
  if standalone then
    obj = log
  else
    obj = config
  end

  local levels = {}
  for i, v in ipairs(config.modes) do
    levels[v.name] = i
  end

  local round = function(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
  end

  local make_string = function(...)
    local t = {}
    for i = 1, select('#', ...) do
      local x = select(i, ...)

      if type(x) == "number" and config.float_precision then
        x = tostring(round(x, config.float_precision))
      elseif type(x) == "table" then
        x = vim.inspect(x)
      else
        x = tostring(x)
      end

      t[#t + 1] = x
    end
    return table.concat(t, " ")
  end


  local log_at_level = function(level, level_config, message_maker, ...)
    -- Return early if we're below the config.level
    if level < levels[config.level] then
      return
    end
    local nameupper = level_config.name:upper()

    local msg = message_maker(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline

    -- Output to console
    if config.use_console then
      local console_string = string.format(
        "[%-6s%s] %s: %s",
        nameupper,
        os.date("%H:%M:%S"),
        lineinfo,
        msg
      )

      if config.highlights and level_config.hl then
        vim.cmd(string.format("echohl %s", level_config.hl))
      end

      local split_console = vim.split(console_string, "\n")
      for _, v in ipairs(split_console) do
        local formatted_msg = string.format("[%s] %s", config.plugin, vim.fn.escape(v, '"'))

        local ok = pcall(vim.cmd, string.format([[echom "%s"]], formatted_msg))
        if not ok then
          vim.api.nvim_out_write(msg .. "\n")
        end
      end

      if config.highlights and level_config.hl then
        vim.cmd "echohl NONE"
      end
    end

    -- Output to log file
    if config.use_file then
      local fp = io.open(outfile, "a")
      local str = string.format("[%-6s%s] %s: %s\n",
      nameupper, os.date(), lineinfo, msg)
      fp:write(str)
      fp:close()
    end
  end

  for i, x in ipairs(config.modes) do
    obj[x.name] = function(...)
      return log_at_level(i, x, make_string, ...)
    end

    obj[("fmt_%s" ):format(x.name)] = function()
      return log_at_level(i, x, function(...)
        local passed = {...}
        local fmt = table.remove(passed, 1)
        local inspected = {}
        for _, v in ipairs(passed) do
          table.insert(inspected, vim.inspect(v))
        end
        return string.format(fmt, unpack(inspected))
      end)
    end
  end

  return obj
end

log.new(default_config, true)
-- }}}

return log

end,

["plenary.lsp.override"] = function()
--------------------
-- Module: 'plenary.lsp.override'
--------------------
local vim = vim

local M = {}

M._original_functions = {}

--- Override an lsp method default callback
--- @param method string
--- @param new_function function
function M.override(method, new_function)
  if M._original_functions[method] == nil then
    M._original_functions[method] = vim.lsp.callbacks[method]
  end

  vim.lsp.callbacks[method] = new_function
end

--- Get the original method callback
---     useful if you only want to override in some circumstances
---
--- @param method string
function M.get_original_function(method)
  if M._original_functions[method] == nil then
    M._original_functions[method] = vim.lsp.callbacks[method]
  end

  return M._original_functions[method]
end

return M

end,

["plenary.neorocks"] = function()
--------------------
-- Module: 'plenary.neorocks'
--------------------
local Job = require('plenary.job')
local Path = require('plenary.path')

local log = require('plenary.log')
local run = require('plenary.run')
local window_float = require('plenary.window.float')

-- TODO: We should consider not making windows when headless.
-- local headless = require('plenary.nvim_meta').is_headless

local neorocks = {}

neorocks.scheduler = require('plenary.neorocks.scheduler'):new()

neorocks.job_with_display_output = function(title_text, command, args)
  log.debug("Starting job:", title_text, command, args)

  if type(title_text) == "string" then
    title_text = {title_text}
  end

  local outputter = vim.schedule_wrap(function(_, data, self)
    if data == nil then
      return
    end

    if not self then
      return
    end

    local bufnr = self.user_data.views.bufnr
    local win_id = self.user_data.views.win_id

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local split_data = vim.split(data, "\n")
    if #split_data > 1 and split_data[#split_data] == "" then
      split_data[#split_data] = nil
    end

    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, split_data)

    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end

    local final_row = #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    vim.api.nvim_win_set_cursor(win_id, {final_row, 0})
  end)

  return Job:new {
    -- TODO: Should test if this splits or not... otherwise gotta do that annoyin thing
    command = command,
    args = args,

    on_start = function(self)
      self.user_data.views = window_float.centered_with_top_win(title_text, {winblend = 0})

      vim.fn.win_gotoid(self.user_data.views.win_id)
      vim.api.nvim_win_set_option(self.user_data.views.win_id, 'wrap', false)
    end,

    on_stdout = outputter,
    on_stderr = outputter,

    on_exit = vim.schedule_wrap(function(self, signal)
      -- if not vim.tbl_isempty(self._additional_on_exit_callbacks) then
      --   return
      -- end

      local bufnr = self.user_data.views.bufnr
      if not vim.api.nvim_buf_is_valid(bufnr) then return end

      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", ("="):rep(40), "  Success! Leave window to close.", ("="):rep(40)})

      local win_id = self.user_data.views.win_id
      if not vim.api.nvim_win_is_valid(win_id) then return end

      local final_row = #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      vim.api.nvim_win_set_cursor(win_id, {final_row, 0})

    end)
  }
end

---@return table Of the form: {
---     lua: Lua Version (5.1, 5.2, etc.)
---     jit: Jit Version (2.1.0-beta3, or nil)
---     dir: Directory of hererocks installation
--- }
neorocks._lua_version = (function()
  if jit then
    return {
      lua = string.gsub(_VERSION, "Lua ", ""),
      jit = string.gsub(jit.version, "LuaJIT ", ""),
      dir = string.gsub(jit.version, "LuaJIT ", "")
    }
  end

  error("NEOROCKS: Unsupported Lua Versions", _VERSION)
end)()

neorocks._base_path                  = Path:new(vim.fn.stdpath('cache'), 'plenary_hererocks')
neorocks._hererocks_file             = Path:new(vim.fn.stdpath('cache'), 'hererocks.py')
neorocks._hererocks_install_location = Path:new(neorocks._base_path, neorocks._lua_version.dir)
neorocks._is_setup                   = vim.fn.isdirectory(Path:new(neorocks._hererocks_install_location, "lib"):absolute()) > 0

neorocks._get_hererocks_job = function()
  local url_loc = 'https://raw.githubusercontent.com/luarocks/hererocks/latest/hererocks.py'

  local command, args
  if vim.fn.executable('curl') > 0 then
    command = 'curl'
    args = {url_loc, '-o', neorocks._hererocks_file:absolute()}
  elseif vim.fn.executable('wget') > 0 then
    command = 'wget'
    args = {url_loc, '-O', neorocks._hererocks_file:absolute(), '--verbose'}
  else
    error('"curl" or "wget" is required')
  end

  return neorocks.job_with_display_output(
    {"Installing hererocks"},
    command,
    args
  )
end

neorocks._get_setup_job = function(force, opts)
  local lua_version = neorocks._lua_version
  local install_location = neorocks._hererocks_install_location

  if force == nil then
    force = false
  end

  if opts == nil then
    opts = {}
    opts.split = true
    opts.wait = true
  end

  if neorocks._is_setup and not force then
    return
  end

  if vim.fn.filereadable(neorocks._hererocks_file:absolute()) == 0 then
    neorocks.scheduler:insert(neorocks._get_hererocks_job(opts))
  end

  if lua_version.jit then
    return neorocks.job_with_display_output(
      {"Installing luajit & luarocks"},
      -- TODO: This should be a user specified python, just in case?
      "python",
      {
        neorocks._hererocks_file:absolute(),
        "--verbose",
        "-j",
        lua_version.jit,
        "-r",
        "latest",
        install_location:absolute()
      }
    )
  end
end

neorocks._get_package_paths = function()
  local lua_version = neorocks._lua_version
  local install_location = neorocks._hererocks_install_location

  local install_path = install_location:joinpath(
    "lib",
    "luarocks",
    string.format("rocks-%s", lua_version.lua)
  )

  local share_path = install_location:joinpath(
    "share",
    "lua",
    lua_version.lua
  )

  local gen_pattern = function(directory)
    return string.format(
    "%s?.lua;%s&/init.lua",
    directory,
    directory
  )
  end

  return gen_pattern(share_path:absolute()) .. ';' .. gen_pattern(install_path:absolute())
end

--- Idempotent adding of paths for both package.path and package.cpath
neorocks.setup_paths = function()
  if not neorocks._is_setup then
    return
  end

  if neorocks._path_setup_complete then
    return
  end

  local lua_version = neorocks._lua_version
  local install_location = neorocks._hererocks_install_location

  local match_install_path = neorocks._get_package_paths()

  if not string.find(package.path, match_install_path, 1, true) then
    package.path = package.path .. ';' .. match_install_path
  end

  local install_cpath = install_location:joinpath("lib", "lua", lua_version.lua)
  local match_install_cpath = string.format(
    "%s?.so",
    install_cpath:absolute()
  )
  if not string.find(package.cpath, match_install_cpath, 1, true) then
    package.cpath = package.cpath .. ';' .. match_install_cpath
  end

  neorocks._path_setup_complete = true
end

-- activate hererocks based on current $SHELL
local function source_activate(install_location, activate_file)
  return string.format('source %s', install_location:joinpath('bin', activate_file):absolute())
end

--- Get the string to source hererocks
neorocks._source_string = function(install_location)
  local user_shell = os.getenv("SHELL")
  local shell = user_shell:gmatch("([^/]*)$")()
  if shell == "fish" then
    return source_activate(install_location, 'activate.fish')
  elseif shell == "csh" then
    return source_activate(install_location, 'activate.csh')
  end
  return source_activate(install_location, 'activate')
end

neorocks._luarocks_exec = function(luarocks_arg)
  local install_location = neorocks._hererocks_install_location

  return vim.fn.systemlist(string.format(
    "%s && luarocks %s",
    neorocks._source_string(install_location),
    luarocks_arg
  ))
end

--- Properly source and run a luarocks command. Will run `luarocks $luarocks_arg`
neorocks._luarocks_run = function(luarocks_arg)
  local install_location = neorocks._hererocks_install_location
  local source_string = neorocks._source_string(install_location)

  run.with_displayed_output(
    {"Lua rocks install"},
    string.format(
      '%s && luarocks %s',
      source_string,
      luarocks_arg
    ),
    {
      split = true,
      wait = true
    }
  )
end

--- Properly source and return the output of a luarocks command.
neorocks._get_luarocks_job = function(luarocks_arg)
  local install_location = neorocks._hererocks_install_location
  local source_string = neorocks._source_string(install_location)

  local command = "bash"
  local args = {"-c", string.format('%s && luarocks %s', source_string, luarocks_arg)}

  return neorocks.job_with_display_output("Luarocks: " .. luarocks_arg, command, args)
end


neorocks._get_install_job = function(package_name)
  return neorocks._get_luarocks_job(string.format('install %s', package_name))
end

neorocks.install = function(package_name, lua_name, force)
  neorocks.scheduler:insert(neorocks._get_setup_job())

  if not force and neorocks.is_package_installed(package_name, lua_name) then
    print(package_name, 'is already installed!')
    return
  end

  neorocks.scheduler:insert(neorocks._get_install_job(package_name))
end

neorocks.ensure_installed = function(package_name, lua_name)
  -- Don't try and install on startup. It's annoying.
  -- Maybe someday we can do it.
  if not neorocks._is_setup then
    vim.api.nvim_err_writeln("Neorocks is not yet set up. Please manually install")
    return
  end

  neorocks.setup_paths()

  if lua_name == nil then
    lua_name = package_name
  end

  if neorocks.is_package_installed(package_name, lua_name) then
    return
  end

  neorocks.install(package_name, lua_name)
end

neorocks.remove = function(package_name)
  neorocks._luarocks_run(string.format('remove %s', package_name))
end

neorocks.list = function(package_filter)
  if package_filter == nil then
    package_filter = ''
  end

  local result = {}
  for _, line in ipairs(
    neorocks._luarocks_exec(
      string.format('list %s --porcelain', package_filter),
      true
    )
  ) do
    for l_package, version, status, install_path in string.gmatch(line, "([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)") do
      table.insert(result, {
        l_package = l_package,
        version = version,
        status = status,
        install_path = install_path
      })
    end
  end

  return result
end

neorocks.is_package_installed = function(package_name, lua_name)
  -- TODO: Decided if I need anything more than this.
  -- This tells me if it's available or not, which is really all I care about.
  if lua_name == nil then
    lua_name = package_name
  end

  if package.loaded[package_name] then
    return true
  end

  local can_import, _ = pcall(function() return require(lua_name) end)
  if can_import then
    return true
  end

  local options = neorocks.list(package_name)

  for _, p in ipairs(options) do
    if p.l_package == package_name then
      return true
    end
  end

  return false
end

-- package.searchpath(${1:name: string}, ${2:path: string}, ${3:sep: string}, ${4:rep: string})
-- package.searchpath("pl", package.path)

return neorocks

end,

["plenary.neorocks.scheduler"] = function()
--------------------
-- Module: 'plenary.neorocks.scheduler'
--------------------
local Job = require('plenary.job')

local scheduler = {}

function scheduler:new()
  return setmetatable({
    items = {},

    in_progress = nil,
  }, {
    __index = self,
  })
end

function scheduler:insert(item)
  if not item then
    return
  end

  table.insert(self.items, item)

  if not self.in_progress then
    self:_run_item(item)
  else
    self:_chain_item(item)
  end
end

function scheduler:_run_item(item)
  self.in_progress = true
  item:add_on_exit_callback(function()
    self.in_progress = false
  end)

  item:start()
end

function scheduler:_chain_item(item)
  self.items[#self.items - 1]:add_on_exit_callback(function()
    self:_run_item(item)
  end)
end

return scheduler

end,

["plenary.nvim_meta"] = function()
--------------------
-- Module: 'plenary.nvim_meta'
--------------------
local get_lua_version = function()
  if jit then
    return {
      lua = string.gsub(_VERSION, "Lua ", ""),
      jit = not not string.find(jit.version, "LuaJIT"),
      version = string.gsub(jit.version, "LuaJIT ", "")
    }
  end

  error("NEOROCKS: Unsupported Lua Versions", _VERSION)
end

return {
  -- Is run in `--headless` mode.
  is_headless = (#vim.fn.nvim_list_uis() == 0),

  lua_jit = get_lua_version(),
}

end,

["plenary.path"] = function()
--------------------
-- Module: 'plenary.path'
--------------------
--- Path.lua
---
--- Goal: Create objects that are extremely similar to Python's `Path` Objects.
--- Reference: https://docs.python.org/3/library/pathlib.html

local vim = vim
local luv = require('luv')  -- TODO: Might want to consider more luv, less vim for some of these.

local path = {}

path.__index = path

-- TODO: Could use this to not have to call new... not sure
-- path.__call = path:new

path.__div = function(self, other)
    assert(path.is_path(self))
    assert(path.is_path(other) or type(other) == 'string')

    return self:joinpath(other)
end

path.__tostring = function(self)
    return self.filename
end

-- TODO: See where we concat the table, and maybe we could make this work.
path.__concat = function(self, other)
    print(self, other)
    return self.filename .. other
end

path.is_path = function(a)
    return getmetatable(a) == path
end

-- TODO: check for windows
path._sep = "/"

function path:new(...)
    local args = {...}

    if type(self) == 'string' then
        table.insert(args, 1, self)
        self = path
    end

    local path_input
    if #args == 1 then
        path_input = args[1]
    else
        path_input = args
    end

    -- If we already have a path, it's fine.
    --   Just return it
    if path.is_path(path_input) then
        return path_input
    end


    local path_string
    if vim.tbl_islist(path_input) then
        -- TODO: It's possible this could be done more elegantly with __concat
        --       But I'm unsure of what we'd do to make that happen
        local path_objs = {}
        for _, v in ipairs(path_input) do
            if path.is_path(v) then
                table.insert(path_objs, v.filename)
            else
                assert(type(v) == 'string')
                table.insert(path_objs, v)
            end
        end

        path_string = table.concat(path_objs, path._sep)
    else
        assert(type(path_input) == 'string')
        path_string = path_input
    end

    -- TODO: Should probably remove and dumb stuff like double seps, periods in the middle, etc.

    local obj = {
        filename = path_string,


        _absolute=nil,
    }

    setmetatable(obj, path)

    return obj
end

function path:joinpath(...)
    return path:new(self.filename, ...)
end

function path:absolute()
    if self._absolute == nil then
        -- NOTE: I can see a potential bug here in the fact that
        --   I'm not sure how we know if we've got the right cwd to do this.
        --   So maybe at some point we'll have to cache the cwd when we create the path.
        self._absolute = vim.fn.fnamemodify(self.filename, ":p")
    end

    return self._absolute
end

function path:exists()
    return vim.fn.filereadable(self:absolute()) == 1 or self:is_dir()
end

function path:mkdir(mode, parents, exists_ok)
    mode = mode or 448 -- 0700 -> decimal

    if parents == nil then
        parents = true
    end

    if exists_ok == nil then
        exists_ok = true
    end

    local vim_fn_path = ""
    if parents then
        vim_fn_path = "p"
    end

    return vim.fn.mkdir(self:absolute(), vim_fn_path, mode)
end

function path:rmdir()
    if not self:exists() then
        return
    end

    luv.fs_rmdir(self:absolute())
end

function path:is_dir()
    return vim.fn.isdirectory(self:absolute()) == 1
end

-- TODO:
--  Maybe I can use libuv for this?
function path:open()
end

function path:close()
end

return path

end,

["plenary.popup"] = function()
--------------------
-- Module: 'plenary.popup'
--------------------
--- popup.lua
---
--- Wrapper to make the popup api from vim in neovim.
--- Hope to get this part merged in at some point in the future.

local vim = vim

local Border = require("plenary.window.border")

local popup = {}

popup._pos_map = {
  topleft="NW",
  topright="NE",
  botleft="SW",
  botright="SE",
}

-- Keep track of hidden popups, so we can load them with popup.show()
popup._hidden = {}


local function dict_default(options, key, default)
  if options[key] == nil then
    return default[key]
  else
    return options[key]
  end
end


function popup.popup_create(what, vim_options)
  local bufnr
  if type(what) == 'number' then
    bufnr = what
  else
    bufnr = vim.fn.nvim_create_buf(false, true)
    assert(bufnr, "Failed to create buffer")

    -- TODO: Handle list of lines
    vim.fn.nvim_buf_set_lines(bufnr, 0, -1, true, {what})
  end

  local option_defaults = {
    posinvert = true
  }

  local win_opts = {}

  if vim_options.line then
    -- TODO: Need to handle "cursor", "cursor+1", ...
    win_opts.row = vim_options.line
  else
    -- TODO: It says it needs to be "vertically cenetered"?...
    -- wut is that.
    win_opts.row = 0
  end

  if vim_options.col then
    -- TODO: Need to handle "cursor", "cursor+1", ...
    win_opts.col = vim_options.col
  else
    -- TODO: It says it needs to be "horizontally cenetered"?...
    win_opts.col = 0
  end

  if vim_options.pos then
    if vim_options.pos == 'center' then
      -- TODO: Do centering..
    else
      win_opts.anchor = popup._pos_map[vim_options.pos]
    end
  end

  -- posinvert	When FALSE the value of "pos" is always used.  When
  -- 		TRUE (the default) and the popup does not fit
  -- 		vertically and there is more space on the other side
  -- 		then the popup is placed on the other side of the
  -- 		position indicated by "line".
  if dict_default(vim_options, 'posinvert', option_defaults) then
    -- TODO: handle the invert thing
  end

  -- 	fixed		When FALSE (the default), and:
  -- 			 - "pos" is "botleft" or "topleft", and
  -- 			 - "wrap" is off, and
  -- 			 - the popup would be truncated at the right edge of
  -- 			   the screen, then
  -- 			the popup is moved to the left so as to fit the
  -- 			contents on the screen.  Set to TRUE to disable this.

  win_opts.style = 'minimal'

  -- Feels like maxheigh, minheight, maxwidth, minwidth will all be related
  win_opts.height = 5
  win_opts.width = 25

  -- textprop	When present the popup is positioned next to a text
  -- 		property with this name and will move when the text
  -- 		property moves.  Use an empty string to remove.  See
  -- 		|popup-textprop-pos|.
  -- related:
  --   textpropwin
  --   textpropid

  -- border
  local border_options = {}
  if vim_options.border then
    local b_top, b_rgight, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft
    if vim_options.borderchars == nil then
      b_top , b_rgight , b_bot , b_left , b_topleft , b_topright , b_botright , b_botleft = {
        '-' , '|'      , '-'   , '|'    , '┌'        , '┐'       , '┘'       , '└'
      }
    elseif #vim_options.borderchars == 1 then
      -- TODO: Unpack 8 times cool to the same vars
      print('...')
    elseif #vim_options.borderchars == 2 then
      -- TODO: Unpack to edges & corners
      print('...')
    elseif #vim_options.borderchars == 8 then
      b_top , b_rgight , b_bot , b_left , b_topleft , b_topright , b_botright , b_botleft = vim_options.borderhighlight
    end
  end

  win_opts.relative = "editor"

  local win_id
  if vim_options.hidden then
    assert(false, "I have not implemented this yet and don't know how")
  else
    win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)
  end


  -- Moved, handled after since we need the window ID
  if vim_options.moved then
    if vim_options.moved == 'any' then
      vim.lsp.util.close_preview_autocmd({'CursorMoved', 'CursorMovedI'}, win_id)
    elseif vim_options.moved == 'word' then
      -- TODO: Handle word, WORD, expr, and the range functions... which seem hard?
    end
  else
    vim.cmd(
      string.format(
        "autocmd BufLeave <buffer=%s> ++once call nvim_win_close(%s, v:false)",
        bufnr,
        win_id
      )
    )
  end

  if vim_options.time then
    local timer = vim.loop.new_timer()
    timer:start(vim_options.time, 0, vim.schedule_wrap(function()
      vim.fn.nvim_close_win(win_id, false)
    end))
  end

  -- Buffer Options
  if vim_options.cursorline then
    vim.fn.nvim_win_set_option(0, 'cursorline', true)
  end

  -- vim.fn.nvim_win_set_option(0, 'wrap', dict_default(vim_options, 'wrap', option_defaults))

  -- ===== Not Implemented Options =====
  -- flip: not implemented at the time of writing
  -- Mouse:
  --    mousemoved: no idea how to do the things with the mouse, so it's an exercise for the reader.
  --    drag: mouses are hard
  --    resize: mouses are hard
  --    close: mouses are hard
  --
  -- scrollbar
  -- scrollbarhighlight
  -- thumbhighlight
  --
  -- tabpage: seems useless

  -- Create border

  -- title
  if vim_options.title then
    border_options.title = vim_options.title

    if vim_options.border == 0 or vim_options.border == nil then
      vim_options.border = 1
      border_options.width = 1
    end
  end

  if vim_options.border then
    Border:new(bufnr, win_id, win_opts, border_options)
  end

  -- TODO: Perhaps there's a way to return an object that looks like a window id,
  --    but actually has some extra metadata about it.
  --
  --    This would make `hidden` a lot easier to manage
  return win_id
end

function popup.show(self, asdf)
end

popup.show = function()
end

return popup


end,

["plenary.profile"] = function()
--------------------
-- Module: 'plenary.profile'
--------------------
local profile = {}

function profile.benchmark(iterations, f, ...)
  local start_time = vim.loop.hrtime()
  for _ = 1, iterations do
    f(...)
  end
  return (vim.loop.hrtime() - start_time) / 1E9
end

return profile

end,

["plenary.reload"] = function()
--------------------
-- Module: 'plenary.reload'
--------------------
local reload = {}

reload.reload_module = function(module_name, starts_with_only)
  -- TODO: Might need to handle cpath / compiled lua packages? Not sure.
  local matcher
  if not starts_with_only then
    matcher = function(pack)
      return string.find(pack, module_name, 1, true)
    end
  else
    matcher = function(pack)
      return string.find(pack, '^' .. module_name)
    end
  end

  for pack, _ in pairs(package.loaded) do
    if matcher(pack) then
      package.loaded[pack] = nil
    end
  end
end

return reload

end,

["plenary.run"] = function()
--------------------
-- Module: 'plenary.run'
--------------------
local floatwin = require("plenary.window.float")

local run = {}

run.with_displayed_output = function(title_text, cmd, opts)
  local views = floatwin.centered_with_top_win(title_text)

  local job_id = vim.fn.termopen(cmd)

  local count = 0
  while not vim.wait(1000, function() return vim.fn.jobwait({job_id}, 0)[1] == -1 end)
  do
    vim.cmd [[normal! G]]
    count = count + 1

    if count == 10 then
      break
    end
  end

  vim.fn.win_gotoid(views.win_id)
  vim.cmd [[startinsert]]

  return views.bufnr, views.win_id
end

return run

end,

["plenary.tbl"] = function()
--------------------
-- Module: 'plenary.tbl'
--------------------
local tbl = {}

function tbl.apply_defaults(original, defaults)
  if original == nil then
    original = {}
  end

  original = vim.deepcopy(original)

  for k, v in pairs(defaults) do
    if original[k] == nil then
      original[k] = v
    end
  end

  return original
end

return tbl

end,

["plenary.test_harness"] = function()
--------------------
-- Module: 'plenary.test_harness'
--------------------
local lu = require("luaunit")

local Path = require("plenary.path")
local Job = require("plenary.job")

local f = require("plenary.functional")
local log = require("plenary.log")
local win_float = require("plenary.window.float")

local headless = require("plenary.nvim_meta").is_headless

local harness = {}

local function validate_test_type(test_type)
  if test_type ~= 'luaunit' and test_type ~= 'busted' then
    error(
      string.format(
        'Unexpected test_type: %s. Expected luaunit or busted.\n%s',
        test_type,
        debug.traceback()
      )
    )
  end
end

local print_output = function(_, ...)
  for _, v in ipairs({...}) do
    print(v)
  end
end

local nvim_output = function(bufnr, ...)
  vim.fn.nvim_buf_set_lines(bufnr, -1, -1, false, {...})
end

function harness:run(test_type, bufnr, win_id, ...)
  validate_test_type(test_type)

  if bufnr == nil then
    bufnr = vim.fn.nvim_create_buf(false, true)
  end

  if win_id == nil then
    -- TODO: Could just make win be 0...?
    local opts = win_float.default_opts()
    win_id = vim.fn.nvim_open_win(bufnr, true, opts)
  end

  vim.fn.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.fn.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
  vim.fn.nvim_buf_set_option(bufnr, 'swapfile', false)

  if test_type == 'luaunit' then
    print("\n")
    print("===== Results ===== ")
    print("\n")
    print("\n")

    local luaunit_result = lu.LuaUnit.run(...)
    if headless and luaunit_result ~= 0 then
      os.exit(luaunit_result)
    end

  elseif test_type == 'busted' then
    -- Requires people to have called `setup_busted`
  else
    assert(false)
  end

  -- Would not mind having a bit nicer output, but it's fine for now.
  -- lu.LuaUnit.run("--outputtype=tap")

  -- weirdly need to redraw the screen sometimes... oh well
  vim.fn.win_gotoid(win_id)
  vim.cmd("mode")
  vim.cmd("nnoremap q :q<CR>")
end

function harness:test_directory(test_type, directory)
  validate_test_type(test_type)

  log.debug("Starting...")
  if test_type == 'busted' then
    -- Only need to make sure penlight/lfs is available, since we have slightly different busted
    -- require('plenary.neorocks').ensure_installed('luafilesystem', 'lfs', true)
    -- require('plenary.neorocks').ensure_installed('penlight', 'pl', true)
  end


  local res = win_float.centered()
  vim.cmd('mode')
  vim.fn.nvim_buf_set_keymap(res.bufnr, "n", "q", ":q<CR>", {})

  local outputter
  if headless then
    outputter = print_output
  else
    outputter = nvim_output
  end

  local paths = self:_find_files_to_run(directory)
  local jobs = f.map(
    function(p)
      return Job:new({
        command = 'nvim',
        args = {
          '--headless',
          '-c',
          string.format(
            'lua require("plenary.test_harness"):_run_path("%s", "%s")',
            test_type, p
          )
        },
        -- Can be turned on to debug
        on_stdout = function(...)
          if p_debug then
            print("STDOUT:", ...)
          end
        end,
        on_stderr = function(...)
          if p_debug then
            print("STDERR:", ...)
          end
        end,
        on_exit = function(j_self, _, _)
          outputter(res.bufnr, unpack(j_self:result()))
          vim.cmd('mode')
        end
      })
    end,
    paths
  )

  log.debug("Running...")
  for _, j in ipairs(jobs) do
    j:start()
  end

  log.debug("...Waiting")
  Job.join(unpack(jobs))
  log.debug("Done...")

  if headless then
    if f.any(function(_, v) return v.code ~= 0 end, jobs) then
      os.exit(1)
    end

    vim.cmd('qa!')
  end
end

function harness:_find_files_to_run(directory)
  local finder = Job:new({
    command = 'find',
    args = {directory, '-type', 'f', '-name', '*_spec.lua'},
  })

  return f.map(Path.new, finder:sync())
end

function harness:_run_path(test_type, directory)
  validate_test_type(test_type)

  local paths = harness:_find_files_to_run(directory)

  local bufnr = 0
  local win_id = 0

  for _, p in pairs(paths) do
    print(" ")
    print("Loading Tests For: ", p:absolute(), "\n")

    dofile(p:absolute())
    -- local ok, _ = pcall(function() dofile(p:absolute()) end)

    -- if not ok then
    --   print("Failed to load file")
    -- end
  end

  harness:run(test_type, bufnr, win_id)
  vim.cmd("qa!")

  return paths
end


function harness:setup_busted()
  if not pcall(require, 'lfs') then
    vim.api.nvim_err_writeln("Lua Filesystem (lfs) is required.")
    return
  end

  if not pcall(require, 'pl') then
    vim.api.nvim_err_writeln("Penlight (pl) is required.")
    return
  end

  require('busted.runner')({output='plainTerminal'}, 3)
end

return harness

end,

["plenary.window.border"] = function()
--------------------
-- Module: 'plenary.window.border'
--------------------
local tbl = require('plenary.tbl')

local Border = {}

Border.__index = Border

Border._default_thickness = {
  top = 1,
  right = 1,
  bot = 1,
  left = 1,
}

function Border._create_lines(content_win_options, border_win_options)
  -- TODO: Handle border width, which I haven't right here.
  local thickness = border_win_options.border_thickness

  local top_enabled = thickness.top == 1
  local right_enabled = thickness.right == 1
  local bot_enabled = thickness.bot == 1
  local left_enabled = thickness.left == 1

  local border_lines = {}

  local topline = nil

  local topleft = (left_enabled and border_win_options.topleft) or ''
  local topright = (right_enabled and border_win_options.topright) or ''

  if border_win_options.title then
    local title = string.format(" %s ", border_win_options.title)
    local title_len = string.len(title)

    local midpoint = math.floor(content_win_options.width / 2)
    local left_start = midpoint - math.floor(title_len / 2)

    topline = string.format("%s%s%s%s%s",
      topleft,
      string.rep(border_win_options.top, left_start),
      title,
      string.rep(border_win_options.top, content_win_options.width - title_len - left_start),
      topright
    )
  else
    if top_enabled then
      topline = topleft
        .. string.rep(border_win_options.top, content_win_options.width)
        .. topright
    end
  end

  if topline then
    table.insert(border_lines, topline)
  end

  local middle_line = string.format(
    "%s%s%s",
    (left_enabled and border_win_options.left) or '',
    string.rep(' ', content_win_options.width),
    (right_enabled and border_win_options.right) or ''
  )

  for _ = 1, content_win_options.height do
    table.insert(border_lines, middle_line)
  end

  if bot_enabled then
    table.insert(border_lines,
      string.format(
        "%s%s%s",
        (left_enabled and border_win_options.botleft) or '',
        string.rep(border_win_options.bot, content_win_options.width),
        (right_enabled and border_win_options.botright) or ''
      )
    )
  end

  return border_lines
end

function Border:new(content_bufnr, content_win_id, content_win_options, border_win_options)
  assert(type(content_win_id) == 'number', "Must supply a valid win_id. It's possible you forgot to call with ':'")

  -- TODO: Probably can use just deep_extend, now that it's available
  border_win_options = tbl.apply_defaults(border_win_options, {
    border_thickness = Border._default_thickness,

    -- Border options, could be passed as a list?
    topleft  = '╔',
    topright = '╗',
    top      = '═',
    left     = '║',
    right    = '║',
    botleft  = '╚',
    botright = '╝',
    bot      = '═',
  })

  local obj = {}

  obj.content_win_id = content_win_id
  obj.content_win_options = content_win_options
  obj._border_win_options = border_win_options


  obj.bufnr = vim.api.nvim_create_buf(false, true)
  assert(obj.bufnr, "Failed to create border buffer")

  obj.contents = Border._create_lines(content_win_options, border_win_options)
  vim.api.nvim_buf_set_lines(obj.bufnr, 0, -1, false, obj.contents)

  local thickness = border_win_options.border_thickness

  obj.win_id = vim.api.nvim_open_win(obj.bufnr, false, {
    anchor = content_win_options.anchor,
    relative = content_win_options.relative,
    style = "minimal",
    row = content_win_options.row - thickness.top,
    col = content_win_options.col - thickness.left,
    width = content_win_options.width + thickness.left + thickness.right,
    height = content_win_options.height + thickness.top + thickness.bot,
  })

  -- local silent = true
  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufLeave,BufDelete %s <buffer=%s> ++once ++nested :call popup#close_win(%s, v:true)",
  --     (silent and "<silent>") or "",
  --     content_bufnr,
  --     obj.win_id
  --   )
  -- )
  -- vim.cmd(string.format(
  --   "autocmd WinClosed,BufLeave,BufDelete,WinLeave <silent> <buffer=%s> ++once ++nested :call popup#close_win(%s, v:true)",
  --   content_bufnr,
  --   obj.win_id
  -- ))

  vim.cmd(string.format(
    "autocmd BufLeave,BufDelete <buffer=%s> ++nested ++once :lua require('plenary.window').close_related_win(%s, %s)",
    content_bufnr,
    content_win_id,
    obj.win_id))

  vim.cmd(string.format(
    "autocmd WinClosed,WinLeave <buffer=%s> ++nested ++once :lua require('plenary.window').try_close(%s, true)",
    content_bufnr,
    obj.win_id))


  setmetatable(obj, Border)

  return obj
end


return Border

end,

["plenary.window.float"] = function()
--------------------
-- Module: 'plenary.window.float'
--------------------
package.loaded['plenary.tbl'] = nil
package.loaded['plenary.window.float'] = nil

local Border = require("plenary.window.border")
local tbl = require('plenary.tbl')

_associated_bufs = {}


local clear_buf_on_leave = function(bufnr)
  vim.cmd(
    string.format(
      "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once ++nested lua require('plenary.window.float').clear(%s)",
      bufnr,
      bufnr
    )
  )
end

local win_float = {}

win_float.default_options = {
  winblend = 15,
  percentage = 0.9,
}

function win_float.default_opts(options)
  options = tbl.apply_defaults(options, win_float.default_options)

  local width = math.floor(vim.o.columns * options.percentage)
  local height = math.floor(vim.o.lines * options.percentage)

  local top = math.floor(((vim.o.lines - height) / 2) - 1)
  local left = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    row      = top,
    col      = left,
    width    = width,
    height   = height,
    style    = 'minimal'
  }

  return opts
end

function win_float.centered(options)
  options = tbl.apply_defaults(options, win_float.default_options)

  local win_opts = win_float.default_opts(options)

  local bufnr = vim.fn.nvim_create_buf(false, true)
  local win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(win_id, 'winblend', options.winblend)

  vim.cmd(
    string.format(
      "autocmd WinLeave <buffer> silent! execute 'bdelete! %s'",
      bufnr
    )
  )

  return {
    bufnr=bufnr,
    win_id=win_id,
  }
end

function win_float.centered_with_top_win(top_text, options)
  options = tbl.apply_defaults(options, win_float.default_options)

  table.insert(top_text, 1, string.rep("=", 80))
  table.insert(top_text, string.rep("=", 80))

  local primary_win_opts = win_float.default_opts(options)
  local minor_win_opts = vim.deepcopy(primary_win_opts)

  primary_win_opts.height = primary_win_opts.height - #top_text - 1
  primary_win_opts.row = primary_win_opts.row + #top_text + 1

  minor_win_opts.height = #top_text

  local minor_bufnr = vim.fn.nvim_create_buf(false, true)
  local minor_win_id = vim.fn.nvim_open_win(minor_bufnr, true, minor_win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(minor_win_id, 'winblend', options.winblend)

  vim.api.nvim_buf_set_lines(minor_bufnr, 0, -1, false, top_text)

  local primary_bufnr = vim.fn.nvim_create_buf(false, true)
  local primary_win_id = vim.fn.nvim_open_win(primary_bufnr, true, primary_win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(primary_win_id, 'winblend', options.winblend)

  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufDelete,BufLeave <buffer=%s> ++once ++nested silent! execute 'bdelete! %s'",
  --     primary_buf,
  --     minor_buf
  --   )
  -- )

  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufDelete,BufLeave <buffer> ++once ++nested silent! execute 'bdelete! %s'",
  --     primary_buf
  --   )
  -- )


  local primary_border = Border:new(primary_bufnr, primary_win_id, primary_win_opts, {})
  local minor_border = Border:new(minor_bufnr, minor_win_id, minor_win_opts, {})

  _associated_bufs[primary_bufnr] = {
    primary_win_id, minor_win_id, primary_border.win_id, minor_border.win_id
  }

  clear_buf_on_leave(primary_bufnr)

  return {
    bufnr = primary_bufnr,
    win_id = primary_win_id,

    minor_bufnr = minor_bufnr,
    minor_win_id = minor_win_id,
  }
end

--- Create window that takes up certain percentags of the current screen.
---
--- Works regardless of current buffers, tabs, splits, etc.
--@param col_range number | Table:
--                  If number, then center the window taking up this percentage of the screen.
--                  If table, first index should be start, second_index should be end
--@param row_range number | Table:
--                  If number, then center the window taking up this percentage of the screen.
--                  If table, first index should be start, second_index should be end
function win_float.percentage_range_window(col_range, row_range, options)
  options = tbl.apply_defaults(options, win_float.default_options)

  local win_opts = win_float.default_opts(options)
  win_opts.relative = "editor"

  local height_percentage, row_start_percentage
  if type(row_range) == 'number' then
    assert(row_range <= 1)
    assert(row_range > 0)
    height_percentage = row_range
    row_start_percentage = (1 - height_percentage) / 2
  elseif type(row_range) == 'table' then
    height_percentage = row_range[2] - row_range[1]
    row_start_percentage = row_range[1]
  else
    error(string.format("Invalid type for 'row_range': %p", row_range))
  end

  win_opts.height = math.ceil(vim.o.lines * height_percentage)
  win_opts.row = math.ceil(vim.o.lines *  row_start_percentage)

  local width_percentage, col_start_percentage
  if type(col_range) == 'number' then
    assert(col_range <= 1)
    assert(col_range > 0)
    width_percentage = col_range
    col_start_percentage = (1 - width_percentage) / 2
  elseif type(col_range) == 'table' then
    width_percentage = col_range[2] - col_range[1]
    col_start_percentage = col_range[1]
  else
    error(string.format("Invalid type for 'col_range': %p", col_range))
  end

  win_opts.col = math.floor(vim.o.columns * col_start_percentage)
  win_opts.width = math.floor(vim.o.columns * width_percentage)

  local bufnr = options.bufnr or vim.fn.nvim_create_buf(false, true)
  local win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)
  vim.api.nvim_win_set_buf(win_id, bufnr)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(win_id, 'winblend', options.winblend)

  local border = Border:new(bufnr, win_id, win_opts, {})

  _associated_bufs[bufnr] = { win_id, border.win_id, }

  clear_buf_on_leave(bufnr)

  return {
    bufnr = bufnr,
    win_id = win_id,

    border_bufnr = border.bufnr,
    border_win_id = border.win_id,
  }
end

function win_float.clear(bufnr)
  if _associated_bufs[bufnr] == nil then
    return
  end

  for _, win_id in ipairs(_associated_bufs[bufnr]) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.fn.nvim_win_close(win_id, true)
    end
  end

  _associated_bufs[bufnr] = nil
end

return win_float

end,

["plenary.window"] = function()
--------------------
-- Module: 'plenary.window'
--------------------

local window = {}

window.try_close = function(win_id, force)
  if force == nil then
    force = true
  end

  pcall(vim.api.nvim_win_close, win_id, force)
end

window.close_related_win = function(parent_win_id, child_win_id)
  window.try_close(parent_win_id, true)
  window.try_close(child_win_id, true)
end

return window

end,

----------------------
-- Modules part end --
----------------------
        }
        if files[path] then
            return files[path]
        else
            return origin_seacher(path)
        end
    end
end
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------
PLENARY_DEBUG = PLENARY_DEBUG == nil and true or PLENARY_DEBUG

if PLENARY_DEBUG then
  require('plenary.reload').reload_module('plenary')
end

-- Lazy load everything into plenary.
local plenary = setmetatable({}, {
  __index = function(t, k)
    local ok, val = pcall(require, string.format('plenary.%s', k))

    if ok then
      rawset(t, k, val)
    end

    return val
  end
})

return plenary
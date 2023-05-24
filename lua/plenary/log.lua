-- log.lua
-- Does only support logging source files.
--
-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.

local p_debug = vim.fn.getenv "DEBUG_PLENARY"
if p_debug == vim.NIL then
  p_debug = false
end

-- User configuration section
local default_config = {
  -- Name of the plugin. Prepended to log messages.
  plugin = "plenary",

  -- Should print the output to neovim while running.
  -- values: 'sync','async',false
  use_console = "async",

  -- Should highlighting be used in console (using echohl).
  highlights = true,

  -- Should write to a file.
  -- Default output for logging file is `stdpath("cache")/plugin`.
  use_file = true,

  -- Output file has precedence over plugin, if not nil.
  -- Used for the logging file, if not nil and use_file == true.
  outfile = nil,

  -- Should write to the quickfix list.
  use_quickfix = false,

  -- Any messages above this level will be logged.
  level = p_debug and "debug" or "info",

  -- Level configuration.
  modes = {
    { name = "trace", hl = "Comment" },
    { name = "debug", hl = "Comment" },
    { name = "info", hl = "None" },
    { name = "warn", hl = "WarningMsg" },
    { name = "error", hl = "ErrorMsg" },
    { name = "fatal", hl = "ErrorMsg" },
  },

  -- Can limit the number of decimals displayed for floats.
  float_precision = 0.01,

  -- Adjust content as needed, but must keep function parameters to be filled
  -- by library code.
  ---@param is_console boolean If output is for console or log file.
  ---@param mode_name string Level configuration 'modes' field 'name'
  ---@param src_path string Path to source file given by debug.info.source
  ---@param src_line integer Line into source file given by debug.info.currentline
  ---@param msg string Message, which is later on escaped, if needed.
  fmt_msg = function(is_console, mode_name, src_path, src_line, msg)
    local nameupper = mode_name:upper()
    local lineinfo = src_path .. ":" .. src_line
    if is_console then
      return string.format("[%-6s%s] %s: %s", nameupper, os.date "%H:%M:%S", lineinfo, msg)
    else
      return string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
    end
  end,
}

-- {{{ NO NEED TO CHANGE
local log = {}

local unpack = unpack or table.unpack

log.new = function(config, standalone)
  config = vim.tbl_deep_extend("force", default_config, config)

  local outfile = vim.F.if_nil(
    config.outfile,
    string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "cache" }), config.plugin)
  )

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
    return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
  end

  local make_string = function(...)
    local t = {}
    for i = 1, select("#", ...) do
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
    local msg = message_maker(...)
    local info = debug.getinfo(config.info_level or 2, "Sl")
    local src_path = info.source:sub(2)
    local src_line = info.currentline
    -- Output to console
    if config.use_console then
      local log_to_console = function()
        local console_string = config.fmt_msg(true, level_config.name, src_path, src_line, msg)

        if config.highlights and level_config.hl then
          vim.cmd(string.format("echohl %s", level_config.hl))
        end

        local split_console = vim.split(console_string, "\n")
        for _, v in ipairs(split_console) do
          local formatted_msg = string.format("[%s] %s", config.plugin, vim.fn.escape(v, [["\]]))

          local ok = pcall(vim.cmd, string.format([[echom "%s"]], formatted_msg))
          if not ok then
            vim.api.nvim_out_write(msg .. "\n")
          end
        end

        if config.highlights and level_config.hl then
          vim.cmd "echohl NONE"
        end
      end
      if config.use_console == "sync" and not vim.in_fast_event() then
        log_to_console()
      else
        vim.schedule(log_to_console)
      end
    end

    -- Output to log file
    if config.use_file then
      local outfile_parent_path = require("plenary.path"):new(outfile):parent()
      if not outfile_parent_path:exists() then
        outfile_parent_path:mkdir { parents = true }
      end
      local fp = assert(io.open(outfile, "a"))
      local str = config.fmt_msg(false, level_config.name, src_path, src_line, msg)
      fp:write(str)
      fp:close()
    end

    -- Output to quickfix
    if config.use_quickfix then
      local nameupper = level_config.name:upper()
      local formatted_msg = string.format("[%s] %s", nameupper, msg)
      local qf_entry = {
        -- remove the @ getinfo adds to the file path
        filename = info.source:sub(2),
        lnum = info.currentline,
        col = 1,
        text = formatted_msg,
      }
      vim.fn.setqflist({ qf_entry }, "a")
    end
  end

  for i, x in ipairs(config.modes) do
    -- log.info("these", "are", "separated")
    obj[x.name] = function(...)
      return log_at_level(i, x, make_string, ...)
    end

    -- log.fmt_info("These are %s strings", "formatted")
    obj[("fmt_%s"):format(x.name)] = function(...)
      return log_at_level(i, x, function(...)
        local passed = { ... }
        local fmt = table.remove(passed, 1)
        local inspected = {}
        for _, v in ipairs(passed) do
          table.insert(inspected, vim.inspect(v))
        end
        return string.format(fmt, unpack(inspected))
      end, ...)
    end

    -- log.lazy_info(expensive_to_calculate)
    obj[("lazy_%s"):format(x.name)] = function()
      return log_at_level(i, x, function(f)
        return f()
      end)
    end

    -- log.file_info("do not print")
    obj[("file_%s"):format(x.name)] = function(vals, override)
      local original_console = config.use_console
      config.use_console = false
      config.info_level = override.info_level
      log_at_level(i, x, make_string, unpack(vals))
      config.use_console = original_console
      config.info_level = nil
    end
  end

  return obj
end

log.new(default_config, true)
-- }}}

return log

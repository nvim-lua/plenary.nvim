local Job = require('plenary.job')
local Path = require('plenary.path')

local log = require('plenary.log')
local run = require('plenary.run')
local window_float = require('plenary.window.float')

-- TODO: We should consider not making windows when headless.
local headless = require('plenary.nvim_meta').is_headless

local neorocks = {}

neorocks.scheduler = require('plenary.neorocks.scheduler'):new()

neorocks.job_with_display_output = function(title_text, command, args)
  log.debug("Starting job:", title_text, command, args)

  if type(title_text) == "string" then
    title_text = {title_text}
  end

  if headless then
    io.write(command .. '\n')
    io.write(vim.inspect(args) .. '\n')
  end

  local outputter = vim.schedule_wrap(function(_, data, self)
    if data == nil then
      return
    end

    if not self then
      return
    end

    if headless then
      io.write(data .. '\n')
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

    on_exit = vim.schedule_wrap(function(self, code)
      local bufnr = self.user_data.views.bufnr
      if not vim.api.nvim_buf_is_valid(bufnr) then return end

      if code == 0 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", ("="):rep(40), "  Success! <Enter> to close.", ("="):rep(40)})
      else
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", ("="):rep(40), "  Failed to complete. <Enter> to close.", ("="):rep(40)})
      end

      local win_id = self.user_data.views.win_id
      if not vim.api.nvim_win_is_valid(win_id) then return end

      local final_row = #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      vim.api.nvim_win_set_cursor(win_id, {final_row, 0})

      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', ':quit<CR>', {silent = true, noremap = true})
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
        force and "-i" or "",
        "-j",
        lua_version.jit,
        "-r",
        "latest",
        install_location:absolute()
      }
    )
  else
    error("Unsupported version")
  end
end

neorocks.setup = function(force, quit)
  vim.fn.mkdir(neorocks._base_path:absolute(), "p")
  quit = (quit == nil and true) or quit
  neorocks.scheduler:insert(neorocks._get_setup_job(force))

  if quit then
    neorocks.scheduler:insert {
      start = function()
        vim.cmd [[qa!]]
      end,

      add_on_exit_callback = function()
      end,
    }
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
    "%s/?.lua;%s/?/init.lua",
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
    "%s/?.so",
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
  local user_shell = os.getenv("SHELL") or "bash"
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

neorocks.install = function(package_name, lua_name, force, should_quit)
  neorocks.scheduler:insert(neorocks._get_setup_job())

  if not force and neorocks.is_package_installed(package_name, lua_name) then
    print(package_name, 'is already installed!')
    return
  end

  local install_job = neorocks.scheduler:insert(neorocks._get_install_job(package_name))

  if headless and should_quit == nil then
    should_quit = true
  end

  if should_quit then
    neorocks.scheduler:insert {
      start = function()
        vim.cmd [[qa!]]
      end,

      add_on_exit_callback = function()
      end,
    }
  end

  return install_job
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

  neorocks.install(package_name, lua_name):wait(60000, 100, true)
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

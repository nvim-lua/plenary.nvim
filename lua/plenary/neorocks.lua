-- package.loaded['plenary.path'] = nil
-- package.loaded['plenary.neorocks'] = nil

local luvjob = require('luvjob')

local Path = require('plenary.path')
local win_float = require('plenary.window.float')


local job_printer = function(prefix, should_write)
  return function(_, data, _)
    if data == nil then return end
    if should_write then
      io.write(prefix .. data)
    else
      print(prefix .. data)
    end
  end
end


local run = function(cmd, headless, opts)
  if opts == nil then
    opts = {}
  end

  local job_id

  -- if cmd then print(cmd) end
  if headless then
    job_id = -1

    local j = luvjob:new({
      command = "bash",
      args = {"-c", cmd},
      on_stdout = job_printer("OUT >> "),
      on_stderr = job_printer("ERR >> ", true),
    })

    j:start()
    j:wait()
  else
    if opts.split then
      vim.cmd("botright 10new")
    else
      local floater = win_float.centered()
      vim.fn.win_gotoid(floater.win)
    end

    job_id = vim.fn.termopen(cmd)
    vim.cmd("startinsert")
  end

  return job_id
end

local neorocks = {}

neorocks._hererocks_file = Path:new(vim.fn.stdpath('cache'), 'hererocks.py')
-- neorocks._bin_dir = Path:new(vim.fn.fnamemodify(debug_utils.sourced_filepath(), ":h:h:h"), "bin")

neorocks._hererocks_install_location = function(lua_version)
  return Path:new(vim.fn.stdpath('cache'), 'neorocks_install', lua_version.dir)
end

neorocks.is_setup = function()
  local lua_version = neorocks.get_lua_version()
  local install_location = neorocks._hererocks_install_location(lua_version)

  if vim.fn.isdirectory(install_location:joinpath("lib"):absolute()) > 0 then
    return true
  else
    return false
  end
end

neorocks.get_hererocks = function(headless, opts)
  local url_loc = 'https://raw.githubusercontent.com/luarocks/hererocks/latest/hererocks.py'

  local cmd
  if vim.fn.executable('curl') > 0 then
    cmd = string.format(
      'curl %s -o %s',
      url_loc,
      neorocks._hererocks_file:absolute()
    )
  elseif vim.fn.executable('wget') > 0 then
    cmd = string.format(
      'wget %s -O %s',
      url_loc,
      neorocks._hererocks_file:absolute()
    )
  end

  print("================================================================================")
  print("                       Installing hererocks")
  print("================================================================================")
  run(cmd, headless, opts)
end

neorocks.setup_hererocks = function(force, headless, opts)
  local lua_version = neorocks.get_lua_version()
  local install_location = neorocks._hererocks_install_location(lua_version)

  if force == nil then
    force = false
  end

  if headless == nil then
    headless = true
  end

  if opts == nil then
    opts = {}
    opts.split = true
    opts.wait = true
  end

  if vim.fn.filereadable(neorocks._hererocks_file:absolute()) == 0 then
   neorocks.get_hererocks(headless, opts)
  end

  if neorocks.is_setup() and not force then
    return
  end

  if lua_version.jit then
    print("================================================================================")
    print("                       Installing luajit & luarocks")
    print("================================================================================")
    local job_id = run(
      string.format(
        "python %s --verbose -j %s -r %s %s",
        neorocks._hererocks_file:absolute(),
        lua_version.jit,
        "latest",
        install_location:absolute()
      ),
      headless,
      opts
    )
  end
end

neorocks.get_lua_version = function()
  if jit then
    return {
      lua = string.gsub(_VERSION, "Lua ", ""),
      jit = string.gsub(jit.version, "LuaJIT ", ""),
      dir = string.gsub(jit.version, "LuaJIT ", "")
    }
  end

  error("NEOROCKS: Unsupported Lua Versions", _VERSION)
end


neorocks._get_package_paths = function()
  local lua_version = neorocks.get_lua_version()
  local install_location = neorocks._hererocks_install_location(lua_version)

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
  local lua_version = neorocks.get_lua_version()
  local install_location = neorocks._hererocks_install_location(lua_version)

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
end

--- Get the string to source hererocks
neorocks._source_string = function(install_location)
  return string.format('source %s', install_location:joinpath('bin', 'activate'):absolute())
end

--- Properly source and run a luarocks command. Will run `luarocks $luarocks_arg`
neorocks._luarocks_run = function(luarocks_arg)
  local lua_version = neorocks.get_lua_version()
  local install_location = neorocks._hererocks_install_location(lua_version)
  local source_string = neorocks._source_string(install_location)

  run(
    string.format(
      '%s && luarocks %s',
      source_string,
      luarocks_arg
    )
  )
end

--- Properly source and return the output of a luarocks command.
neorocks._luarocks_exec = function(luarocks_arg, silent)
  local lua_version = neorocks.get_lua_version()
  local install_location = neorocks._hererocks_install_location(lua_version)
  local source_string = neorocks._source_string(install_location)

  local opts = {
    command = "bash",
    args = {"-c", string.format('%s && luarocks %s', source_string, luarocks_arg)},
  }

  if not silent then
    opts.on_stdout = job_printer("> ")
    opts.on_stderr = job_printer("~ ")
  end

  local j = luvjob:new(opts)

  j:start()
  j:wait()

  return j:result()
end

neorocks.install = function(package_name, headless)
  neorocks.setup_hererocks(false, headless)

  if headless then
    neorocks._luarocks_exec(string.format('install %s', package_name))
  else
    neorocks._luarocks_run(string.format('install %s', package_name))
  end

  neorocks.setup_paths()
end

neorocks.ensure_installed = function(package_name, lua_name, headless)
  neorocks.setup_paths()

  if lua_name == nil then
    lua_name = package_name
  end

  if neorocks.is_package_installed(package_name, lua_name) then
    return
  end

  neorocks.install(package_name, headless)
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

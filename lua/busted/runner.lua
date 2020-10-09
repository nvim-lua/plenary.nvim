-- Busted command-line runner

local path = require 'pl.path'
local tablex = require 'pl.tablex'
local term = require 'term'
local utils = require 'busted.utils'
local exit = require 'busted.compatibility'.exit
local loadstring = require 'busted.compatibility'.loadstring
local loaded = false

return function(options, level)
  if loaded then return function() end else loaded = true end

  local isatty = io.type(io.stdout) == 'file' and term.isatty(io.stdout)
  options = tablex.update(require 'busted.options', options or {})
  options.output = options.output or (isatty and 'utfTerminal' or 'plainTerminal')

  local busted = require 'busted.core'()

  local cli = require 'busted.modules.cli'(options)
  local filterLoader = require 'busted.modules.filter_loader'()
  local helperLoader = require 'busted.modules.helper_loader'()
  local outputHandlerLoader = require 'busted.modules.output_handler_loader'()

  local luacov = require 'busted.modules.luacov'()

  require 'busted'(busted)

  level = level or 2
  local info = debug.getinfo(level, 'Sf')
  local source = info.source
  local fileName = source:sub(1,1) == '@' and source:sub(2) or nil
  local forceExit = fileName == nil

  -- Parse the cli arguments
  local appName = path.basename(fileName or 'busted')
  cli:set_name(appName)
  local cliArgs, err = cli:parse(arg)
  if not cliArgs then
    io.stderr:write(err .. '\n')
    exit(1, forceExit)
  end

  if cliArgs.version then
    -- Return early if asked for the version
    print(busted.version)
    exit(0, forceExit)
  end

  -- Load current working directory
  local _, err = path.chdir(path.normpath(cliArgs.directory))
  if err then
    io.stderr:write(appName .. ': error: ' .. err .. '\n')
    exit(1, forceExit)
  end

  -- If coverage arg is passed in, load LuaCovsupport
  if cliArgs.coverage then
    local ok, err = luacov()
    if not ok then
      io.stderr:write(appName .. ': error: ' .. err .. '\n')
      exit(1, forceExit)
    end
  end

  -- If auto-insulate is disabled, re-register file without insulation
  if not cliArgs['auto-insulate'] then
    busted.register('file', 'file', {})
  end

  -- If lazy is enabled, make lazy setup/teardown the default
  if cliArgs.lazy then
    busted.register('setup', 'lazy_setup')
    busted.register('teardown', 'lazy_teardown')
  end

  -- Add additional package paths based on lpath and cpath cliArgs
  if #cliArgs.lpath > 0 then
    package.path = (cliArgs.lpath .. ';' .. package.path):gsub(';;',';')
  end

  if #cliArgs.cpath > 0 then
    package.cpath = (cliArgs.cpath .. ';' .. package.cpath):gsub(';;',';')
  end

  -- Load and execute commands given on the command-line
  if cliArgs.e then
    for k,v in ipairs(cliArgs.e) do
      loadstring(v)()
    end
  end

  -- watch for test errors and failures
  local failures = 0
  local errors = 0
  local quitOnError = not cliArgs['keep-going']

  busted.subscribe({ 'error', 'output' }, function(element, parent, message)
    io.stderr:write(appName .. ': error: Cannot load output library: ' .. element.name .. '\n' .. message .. '\n')
    return nil, true
  end)

  busted.subscribe({ 'error', 'helper' }, function(element, parent, message)
    io.stderr:write(appName .. ': error: Cannot load helper script: ' .. element.name .. '\n' .. message .. '\n')
    return nil, true
  end)

  busted.subscribe({ 'error' }, function(element, parent, message)
    errors = errors + 1
    busted.skipAll = quitOnError
    return nil, true
  end)

  busted.subscribe({ 'failure' }, function(element, parent, message)
    if element.descriptor == 'it' then
      failures = failures + 1
    else
      errors = errors + 1
    end
    busted.skipAll = quitOnError
    return nil, true
  end)

  -- Set up randomization options
  busted.sort = cliArgs['sort-tests']
  busted.randomize = cliArgs['shuffle-tests']
  busted.randomseed = tonumber(cliArgs.seed) or utils.urandom() or os.time()

  -- Set up output handler to listen to events
  outputHandlerLoader(busted, cliArgs.output, {
    defaultOutput = options.output,
    enableSound = cliArgs['enable-sound'],
    verbose = cliArgs.verbose,
    suppressPending = cliArgs['suppress-pending'],
    language = cliArgs.lang,
    deferPrint = cliArgs['defer-print'],
    arguments = cliArgs.Xoutput,
  })

  -- Pre-load the LuaJIT 'ffi' module if applicable
  local isJit = (tostring(assert):match('builtin') ~= nil)
  if isJit then
    -- pre-load the ffi module, such that it becomes part of the environment
    -- and Busted will not try to GC and reload it. The ffi is not suited
    -- for that and will occasionally segfault if done so.
    local ffi = require "ffi"

    -- Now patch ffi.cdef to only be called once with each definition, as it
    -- will error on re-registering.
    local old_cdef = ffi.cdef
    local exists = {}
    ffi.cdef = function(def)
      if exists[def] then return end
      exists[def] = true
      return old_cdef(def)
    end

    -- Now patch ffi.typeof to only be called once with each definition, as it
    -- will error on re-registering.
    local old_typeof = ffi.typeof
    local exists_typeof = {}
    ffi.typeof = function(def)
      if exists_typeof[def] then return exists_typeof[def] end
      local ok, err = old_typeof(def)
      if ok then
        exists_typeof[def] = ok
        return ok
      end
      return ok, err
    end
  end

  -- Set up helper script
  if cliArgs.helper and cliArgs.helper ~= '' then
    helperLoader(busted, cliArgs.helper, {
      verbose = cliArgs.verbose,
      language = cliArgs.lang,
      arguments = cliArgs.Xhelper
    })
  end

  -- Load tag and test filters
  filterLoader(busted, {
    tags = cliArgs.tags,
    excludeTags = cliArgs['exclude-tags'],
    filter = cliArgs.filter,
    filterOut = cliArgs['filter-out'],
    list = cliArgs.list,
    nokeepgoing = not cliArgs['keep-going'],
    suppressPending = cliArgs['suppress-pending'],
  })

  if cliArgs.ROOT then
    -- Load test directories/files
    local rootFiles = cliArgs.ROOT
    local patterns = cliArgs.pattern
    local testFileLoader = require 'busted.modules.test_file_loader'(busted, cliArgs.loaders)
    testFileLoader(rootFiles, patterns, {
      excludes = cliArgs['exclude-pattern'],
      verbose = cliArgs.verbose,
      recursive = cliArgs['recursive'],
    })
  else
    -- Running standalone, use standalone loader
    local testFileLoader = require 'busted.modules.standalone_loader'(busted)
    testFileLoader(info, { verbose = cliArgs.verbose })
  end

  local runs = cliArgs['repeat']
  local execute = require 'busted.execute'(busted)
  execute(runs, {
    seed = cliArgs.seed,
    shuffle = cliArgs['shuffle-files'],
    sort = cliArgs['sort-files'],
  })

  busted.publish({ 'exit' })

  if failures > 0 or errors > 0 then
    -- exit(failures + errors, forceExit)
    os.exit(failures + errors)
  end
end

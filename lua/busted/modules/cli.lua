local utils = require 'busted.utils'
local path = require 'pl.path'
local tablex = require 'pl.tablex'
local exit = require 'busted.compatibility'.exit
local execute = require 'busted.compatibility'.execute

return function(options)
  local appName = ''
  local options = options or {}
  local cli = require 'cliargs.core'()

  local configLoader = require 'busted.modules.configuration_loader'()

  -- Default cli arg values
  local defaultOutput = options.output or 'utfTerminal'
  local defaultLoaders = 'lua,moonscript'
  local defaultPattern = '_spec'
  local defaultSeed = '/dev/urandom or os.time()'
  local lpathprefix = './src/?.lua;./src/?/?.lua;./src/?/init.lua'
  local cpathprefix = path.is_windows and './csrc/?.dll;./csrc/?/?.dll;' or './csrc/?.so;./csrc/?/?.so;'

  local cliArgsParsed = {}

  local function makeList(values)
    return type(values) == 'table' and values or { values }
  end

  local function fixupList(values, sep)
    local sep = sep or ','
    local list = type(values) == 'table' and values or { values }
    local olist = {}
    for _, v in ipairs(list) do
      tablex.insertvalues(olist, utils.split(v, sep))
    end
    return olist
  end

  local function processOption(key, value, altkey, opt)
    if altkey then cliArgsParsed[altkey] = value end
    cliArgsParsed[key] = value
    return true
  end

  local function processArg(key, value)
    cliArgsParsed[key] = value
    return true
  end

  local function processArgList(key, value)
    local list = cliArgsParsed[key] or {}
    tablex.insertvalues(list, utils.split(value, ','))
    processArg(key, list)
    return true
  end

  local function processNumber(key, value, altkey, opt)
    local number = tonumber(value)
    if not number then
      return nil, 'argument to ' .. opt:gsub('=.*', '') .. ' must be a number'
    end
    if altkey then cliArgsParsed[altkey] = number end
    cliArgsParsed[key] = number
    return true
  end

  local function processList(key, value, altkey, opt)
    local list = cliArgsParsed[key] or {}
    tablex.insertvalues(list, utils.split(value, ','))
    processOption(key, list, altkey, opt)
    return true
  end

  local function processMultiOption(key, value, altkey, opt)
    local list = cliArgsParsed[key] or {}
    table.insert(list, value)
    processOption(key, list, altkey, opt)
    return true
  end

  local function append(s1, s2, sep)
    local sep = sep or ''
    if not s1 then return s2 end
    return s1 .. sep .. s2
  end

  local function processLoaders(key, value, altkey, opt)
    local loaders = append(cliArgsParsed[key], value, ',')
    processOption(key, loaders, altkey, opt)
    return true
  end

  local function processPath(key, value, altkey, opt)
    local lpath = append(cliArgsParsed[key], value, ';')
    processOption(key, lpath, altkey, opt)
    return true
  end

  local function processDir(key, value, altkey, opt)
    local dpath = path.normpath(path.join(cliArgsParsed[key] or '', value))
    processOption(key, dpath, altkey, opt)
    return true
  end

  local function processShuffle(key, value, altkey, opt)
    processOption('shuffle-files', value, nil, opt)
    processOption('shuffle-tests', value, nil, opt)
  end

  local function processSort(key, value, altkey, opt)
    processOption('sort-files', value, nil, opt)
    processOption('sort-tests', value, nil, opt)
  end

  -- Load up the command-line interface options
  cli:flag('--version', 'prints the program version and exits', false, processOption)

  if not options.standalone then
    cli:splat('ROOT', 'test script file/folder. Folders will be traversed for any file that matches the --pattern option.', 'spec', 999, processArgList)

    cli:option('-p, --pattern=PATTERN', 'only run test files matching the Lua pattern', defaultPattern, processMultiOption)
    cli:option('--exclude-pattern=PATTERN', 'do not run test files matching the Lua pattern, takes precedence over --pattern', nil, processMultiOption)
  end

  cli:option('-e STATEMENT', 'execute statement STATEMENT', nil, processMultiOption)
  cli:option('-o, --output=LIBRARY', 'output library to load', defaultOutput, processOption)
  cli:option('-C, --directory=DIR', 'change to directory DIR before running tests. If multiple options are specified, each is interpreted relative to the previous one.', './', processDir)
  cli:option('-f, --config-file=FILE', 'load configuration options from FILE', nil, processOption)
  cli:option('-t, --tags=TAGS', 'only run tests with these #tags', {}, processList)
  cli:option('--exclude-tags=TAGS', 'do not run tests with these #tags, takes precedence over --tags', {}, processList)
  cli:option('--filter=PATTERN', 'only run test names matching the Lua pattern', {}, processMultiOption)
  cli:option('--filter-out=PATTERN', 'do not run test names matching the Lua pattern, takes precedence over --filter', {}, processMultiOption)
  cli:option('-m, --lpath=PATH', 'optional path to be prefixed to the Lua module search path', lpathprefix, processPath)
  cli:option('--cpath=PATH', 'optional path to be prefixed to the Lua C module search path', cpathprefix, processPath)
  cli:option('-r, --run=RUN', 'config to run from .busted file', nil, processOption)
  cli:option('--repeat=COUNT', 'run the tests repeatedly', '1', processNumber)
  cli:option('--seed=SEED', 'random seed value to use for shuffling test order', defaultSeed, processNumber)
  cli:option('--lang=LANG', 'language for error messages', 'en', processOption)
  cli:option('--loaders=NAME', 'test file loaders', defaultLoaders, processLoaders)
  cli:option('--helper=PATH', 'A helper script that is run before tests', nil, processOption)
  cli:option('--lua=LUA', 'The path to the lua interpreter busted should run under', nil, processOption)

  cli:option('-Xoutput OPTION', 'pass `OPTION` as an option to the output handler. If `OPTION` contains commas, it is split into multiple options at the commas.', {}, processList)
  cli:option('-Xhelper OPTION', 'pass `OPTION` as an option to the helper script. If `OPTION` contains commas, it is split into multiple options at the commas.', {}, processList)

  cli:flag('-c, --[no-]coverage', 'do code coverage analysis (requires `LuaCov` to be installed)', false, processOption)
  cli:flag('-v, --[no-]verbose', 'verbose output of errors', false, processOption)
  cli:flag('-s, --[no-]enable-sound', 'executes `say` command if available', false, processOption)
  cli:flag('-l, --list', 'list the names of all tests instead of running them', false, processOption)
  cli:flag('--ignore-lua', 'Whether or not to ignore the lua directive', false, processOption)
  cli:flag('--[no-]lazy', 'use lazy setup/teardown as the default', false, processOption)
  cli:flag('--[no-]auto-insulate', 'enable file insulation', true, processOption)
  cli:flag('-k, --[no-]keep-going', 'continue as much as possible after an error or failure', true, processOption)
  cli:flag('-R, --[no-]recursive', 'recurse into subdirectories', true, processOption)
  cli:flag('--[no-]shuffle', 'randomize file and test order, takes precedence over --sort (--shuffle-test and --shuffle-files)', processShuffle)
  cli:flag('--[no-]shuffle-files', 'randomize file execution order, takes precedence over --sort-files', processOption)
  cli:flag('--[no-]shuffle-tests', 'randomize test order within a file, takes precedence over --sort-tests', processOption)
  cli:flag('--[no-]sort', 'sort file and test order (--sort-tests and --sort-files)', processSort)
  cli:flag('--[no-]sort-files', 'sort file execution order', processOption)
  cli:flag('--[no-]sort-tests', 'sort test order within a file', processOption)
  cli:flag('--[no-]suppress-pending', 'suppress `pending` test output', false, processOption)
  cli:flag('--[no-]defer-print', 'defer print to when test suite is complete', false, processOption)

  local function parse(args)
    -- Parse the cli arguments
    local cliArgs, cliErr = cli:parse(args)
    if not cliArgs then
      return nil, appName .. ': error: ' .. cliErr .. '; re-run with --help for usage.'
    end

    -- Load busted config file if available
    local bustedConfigFilePath
    if cliArgs.f then
      -- if the file is given, then we require it to exist
      if not path.isfile(cliArgs.f) then
        return nil, ("specified config file '%s' not found"):format(cliArgs.f)
      end
      bustedConfigFilePath = cliArgs.f
    else
      -- try default file
      bustedConfigFilePath = path.normpath(path.join(cliArgs.directory, '.busted'))
      if not path.isfile(bustedConfigFilePath) then
        bustedConfigFilePath = nil  -- clear default file, since it doesn't exist
      end
    end
    if bustedConfigFilePath then
      local bustedConfigFile, err = loadfile(bustedConfigFilePath)
      if not bustedConfigFile then
        return nil, ("failed loading config file `%s`: %s"):format(bustedConfigFilePath, err)
      else
        local ok, config = pcall(function()
          local conf, err = configLoader(bustedConfigFile(), cliArgsParsed, cliArgs)
          return conf or error(err, 0)
        end)
        if not ok then
          return nil, appName .. ': error: ' .. config
        else
          cliArgs = config
        end
      end
    else
      cliArgs = tablex.merge(cliArgs, cliArgsParsed, true)
    end

    -- Switch lua, we should rebuild this feature once luarocks changes how it
    -- handles executeable lua files.
    if cliArgs['lua'] and not cliArgs['ignore-lua'] then
      local _, code = execute(
        cliArgs['lua']..' '..args[0]..' --ignore-lua '..table.concat(args, ' ')
      )
      exit(code)
    end

    -- Ensure multi-options are in a list
    cliArgs.e = makeList(cliArgs.e)
    cliArgs.pattern = makeList(cliArgs.pattern)
    cliArgs.p = cliArgs.pattern
    cliArgs['exclude-pattern'] = makeList(cliArgs['exclude-pattern'])
    cliArgs.filter = makeList(cliArgs.filter)
    cliArgs['filter-out'] = makeList(cliArgs['filter-out'])

    -- Fixup options in case options from config file are not of the right form
    cliArgs.tags = fixupList(cliArgs.tags)
    cliArgs.t = cliArgs.tags
    cliArgs['exclude-tags'] = fixupList(cliArgs['exclude-tags'])
    cliArgs.loaders = fixupList(cliArgs.loaders)
    cliArgs.Xoutput = fixupList(cliArgs.Xoutput)
    cliArgs.Xhelper = fixupList(cliArgs.Xhelper)

    -- We report an error if the same tag appears in both `options.tags`
    -- and `options.excluded_tags` because it does not make sense for the
    -- user to tell Busted to include and exclude the same tests at the
    -- same time.
    for _, excluded in pairs(cliArgs['exclude-tags']) do
      for _, included in pairs(cliArgs.tags) do
        if excluded == included then
          return nil, appName .. ': error: Cannot use --tags and --exclude-tags for the same tags'
        end
      end
    end

    cliArgs['repeat'] = tonumber(cliArgs['repeat'])

    return cliArgs
  end

  return {
    set_name = function(self, name)
      appName = name
      return cli:set_name(name)
    end,

    set_silent = function(self, name)
      appName = name
      return cli:set_silent(name)
    end,

    parse = function(self, args)
      return parse(args)
    end
  }
end

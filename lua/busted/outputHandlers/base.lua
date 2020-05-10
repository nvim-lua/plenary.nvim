return function()
  local busted = require 'busted'
  local handler = {
    successes = {},
    successesCount = 0,
    pendings = {},
    pendingsCount = 0,
    failures = {},
    failuresCount = 0,
    errors = {},
    errorsCount = 0,
    inProgress = {}
  }

  handler.cancelOnPending = function(element, parent, status)
    return not ((element.descriptor == 'pending' or status == 'pending') and handler.options.suppressPending)
  end

  handler.subscribe = function(handler, options)
    require('busted.languages.en')
    handler.options = options

    if options.language ~= 'en' then
      require('busted.languages.' .. options.language)
    end

    busted.subscribe({ 'suite', 'reset' }, handler.baseSuiteReset, { priority = 1 })
    busted.subscribe({ 'suite', 'start' }, handler.baseSuiteStart, { priority = 1 })
    busted.subscribe({ 'suite', 'end' }, handler.baseSuiteEnd, { priority = 1 })
    busted.subscribe({ 'test', 'start' }, handler.baseTestStart, { priority = 1, predicate = handler.cancelOnPending })
    busted.subscribe({ 'test', 'end' }, handler.baseTestEnd, { priority = 1, predicate = handler.cancelOnPending })
    busted.subscribe({ 'pending' }, handler.basePending, { priority = 1, predicate = handler.cancelOnPending })
    busted.subscribe({ 'failure', 'it' }, handler.baseTestFailure, { priority = 1 })
    busted.subscribe({ 'error', 'it' }, handler.baseTestError, { priority = 1 })
    busted.subscribe({ 'failure' }, handler.baseError, { priority = 1 })
    busted.subscribe({ 'error' }, handler.baseError, { priority = 1 })
  end

  handler.getFullName = function(context)
    local parent = busted.parent(context)
    local names = { (context.name or context.descriptor) }

    while parent and (parent.name or parent.descriptor) and
          parent.descriptor ~= 'file' do

      table.insert(names, 1, parent.name or parent.descriptor)
      parent = busted.parent(parent)
    end

    return table.concat(names, ' ')
  end

  handler.format = function(element, parent, message, debug, isError)
    local function copyElement(e)
      local copy = {}
      for k,v in next, e do
        if type(v) ~= 'function' and k ~= 'env' then
          copy[k] = v
        end
      end
      return copy
    end

    local formatted = {
      trace = debug or element.trace,
      element = copyElement(element),
      name = handler.getFullName(element),
      message = message,
      randomseed = parent and parent.randomseed,
      isError = isError
    }
    formatted.element.trace = element.trace or debug

    return formatted
  end

  handler.getDuration = function()
    if not handler.endTick or not handler.startTick then
      return 0
    end

    return handler.endTick - handler.startTick
  end

  handler.baseSuiteStart = function(suite)
    handler.startTick = suite.starttick
    handler.startTime = suite.starttime
    return nil, true
  end

  handler.baseSuiteReset = function()
    handler.successes = {}
    handler.successesCount = 0
    handler.pendings = {}
    handler.pendingsCount = 0
    handler.failures = {}
    handler.failuresCount = 0
    handler.errors = {}
    handler.errorsCount = 0
    handler.inProgress = {}

    return nil, true
  end

  handler.baseSuiteEnd = function(suite)
    handler.endTick = suite.endtick
    handler.endTime = suite.endtime
    return nil, true
  end

  handler.baseTestStart = function(element, parent)
    handler.inProgress[tostring(element)] = {}
    return nil, true
  end

  handler.baseTestEnd = function(element, parent, status, debug)
    local insertTable

    if status == 'success' then
      insertTable = handler.successes
      handler.successesCount = handler.successesCount + 1
    elseif status == 'pending' then
      insertTable = handler.pendings
      handler.pendingsCount = handler.pendingsCount + 1
    elseif status == 'failure' then
      -- failure already saved in failure handler
      handler.failuresCount = handler.failuresCount + 1
      return nil, true
    elseif status == 'error' then
      -- error count already incremented and saved in error handler
      return nil, true
    end

    local formatted = handler.format(element, parent, element.message, debug)

    local id = tostring(element)
    if handler.inProgress[id] then
      for k, v in pairs(handler.inProgress[id]) do
        formatted[k] = v
      end

      handler.inProgress[id] = nil
    end

    table.insert(insertTable, formatted)

    return nil, true
  end

  handler.basePending = function(element, parent, message, debug)
    local id = tostring(element)
    handler.inProgress[id].message = message
    handler.inProgress[id].trace = debug
    return nil, true
  end

  handler.baseTestFailure = function(element, parent, message, debug)
    table.insert(handler.failures, handler.format(element, parent, message, debug))
    return nil, true
  end

  handler.baseTestError = function(element, parent, message, debug)
    handler.errorsCount = handler.errorsCount + 1
    table.insert(handler.errors, handler.format(element, parent, message, debug, true))
    return nil, true
  end

  handler.baseError = function(element, parent, message, debug)
    if element.descriptor ~= 'it' then
      handler.errorsCount = handler.errorsCount + 1
      table.insert(handler.errors, handler.format(element, parent, message, debug, true))
    end

    return nil, true
  end

  return handler
end

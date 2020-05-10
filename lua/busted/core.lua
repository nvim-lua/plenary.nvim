local getfenv = require 'busted.compatibility'.getfenv
local setfenv = require 'busted.compatibility'.setfenv
local unpack = require 'busted.compatibility'.unpack
local path = require 'pl.path'
local pretty = require 'pl.pretty'
local system = require 'system'
local throw = error

local failureMt = {
  __index = {},
  __tostring = function(e) return tostring(e.message) end,
  __type = 'failure'
}

local failureMtNoString = {
  __index = {},
  __type = 'failure'
}

local pendingMt = {
  __index = {},
  __tostring = function(p) return p.message end,
  __type = 'pending'
}

local function errortype(obj)
  local mt = debug.getmetatable(obj)
  if mt == failureMt or mt == failureMtNoString then
    return 'failure'
  elseif mt == pendingMt then
    return 'pending'
  end
  return 'error'
end

local function hasToString(obj)
  return type(obj) == 'string' or (debug.getmetatable(obj) or {}).__tostring
end

local function isCallable(obj)
  return type(obj) == 'function' or (debug.getmetatable(obj) or {}).__call
end

return function()
  local mediator = require 'mediator'()

  local busted = {}
  busted.version = '2.0.0-0'

  local root = require 'busted.context'()
  busted.context = root.ref()

  local environment = require 'busted.environment'(busted.context)

  busted.api = {}
  busted.executors = {}
  local executors = {}
  local eattributes = {}

  busted.gettime = system.gettime
  busted.monotime = system.monotime
  busted.sleep = system.sleep
  busted.status = require 'busted.status'

  function busted.getTrace(element, level, msg)
    local function trimTrace(info)
      local index = info.traceback:find('\n%s*%[C]')
      info.traceback = info.traceback:sub(1, index)
      return info
    end
    level = level or  3

    local thisdir = path.dirname(debug.getinfo(1, 'Sl').source)
    local info = debug.getinfo(level, 'Sl')
    while info.what == 'C' or info.short_src:match('luassert[/\\].*%.lua$') or
          (info.source:sub(1,1) == '@' and thisdir == path.dirname(info.source)) do
      level = level + 1
      info = debug.getinfo(level, 'Sl')
    end

    info.traceback = debug.traceback('', level)
    info.message = msg

    local file = busted.getFile(element)
    return file and file.getTrace(file.name, info) or trimTrace(info)
  end

  function busted.rewriteMessage(element, message, trace)
    local file = busted.getFile(element)
    local msg = hasToString(message) and tostring(message)
    msg = msg or (message ~= nil and pretty.write(message) or 'Nil error')
    msg = (file and file.rewriteMessage and file.rewriteMessage(file.name, msg) or msg)

    local hasFileLine = msg:match('^[^\n]-:%d+: .*')
    if not hasFileLine then
      local trace = trace or busted.getTrace(element, 3, message)
      local fileline = trace.short_src .. ':' .. trace.currentline .. ': '
      msg = fileline .. msg
    end

    return msg
  end

  function busted.publish(...)
    return mediator:publish(...)
  end

  function busted.subscribe(...)
    return mediator:subscribe(...)
  end

  function busted.unsubscribe(...)
    return mediator:removeSubscriber(...)
  end

  function busted.getFile(element)
    local parent = busted.context.parent(element)

    while parent do
      if parent.file then
        local file = parent.file[1]
        return {
          name = file.name,
          getTrace = file.run.getTrace,
          rewriteMessage = file.run.rewriteMessage
        }
      end

      if parent.descriptor == 'file' then
        return {
          name = parent.name,
          getTrace = parent.run.getTrace,
          rewriteMessage = parent.run.rewriteMessage
        }
      end

      parent = busted.context.parent(parent)
    end

    return parent
  end

  function busted.fail(msg, level)
    local rawlevel = (type(level) ~= 'number' or level <= 0) and level
    local level = level or 1
    local _, emsg = pcall(throw, msg, rawlevel or level+2)
    local e = { message = emsg }
    setmetatable(e, hasToString(msg) and failureMt or failureMtNoString)
    throw(e, rawlevel or level+1)
  end

  function busted.pending(msg)
    local p = { message = msg }
    setmetatable(p, pendingMt)
    throw(p)
  end

  function busted.bindfenv(callable, var, value)
    local env = {}
    local f = (debug.getmetatable(callable) or {}).__call or callable
    setmetatable(env, { __index = getfenv(f) })
    env[var] = value
    setfenv(f, env)
  end

  function busted.wrap(callable)
    if isCallable(callable) then
      -- prioritize __call if it exists, like in files
      environment.wrap((debug.getmetatable(callable) or {}).__call or callable)
    end
  end

  function busted.safe(descriptor, run, element)
    busted.context.push(element)
    local trace, message
    local status = 'success'

    local ret = { xpcall(run, function(msg)
      status = errortype(msg)
      trace = busted.getTrace(element, 3, msg)
      message = busted.rewriteMessage(element, msg, trace)
    end) }

    if not ret[1] then
      if status == 'success' then
        status = 'error'
        trace = busted.getTrace(element, 3, ret[2])
        message = busted.rewriteMessage(element, ret[2], trace)
      elseif status == 'failure' and descriptor ~= 'it' then
        -- Only 'it' blocks can generate test failures. Failures in all
        -- other blocks are errors outside the test.
        status = 'error'
      end
      -- Note: descriptor may be different from element.descriptor when
      -- safe_publish is used (i.e. for test start/end). The safe_publish
      -- descriptor needs to be different for 'it' blocks so that we can
      -- detect that a 'failure' in a test start/end handler is not really
      -- a test failure, but rather an error outside the test, much like a
      -- failure in a support function (i.e. before_each/after_each or
      -- setup/teardown).
      busted.publish({ status, element.descriptor }, element, busted.context.parent(element), message, trace)
    end
    ret[1] = busted.status(status)

    busted.context.pop()
    return unpack(ret)
  end

  function busted.safe_publish(descriptor, channel, element, ...)
    local args = {...}
    local n = select('#', ...)
    if channel[2] == 'start' then
      element.starttick = busted.monotime()
      element.starttime = busted.gettime()
    elseif channel[2] == 'end' then
      element.endtime = busted.gettime()
      element.endtick = busted.monotime()
      element.duration = element.starttick and (element.endtick - element.starttick)
    end
    local status = busted.safe(descriptor, function()
      busted.publish(channel, element, unpack(args, 1, n))
    end, element)
    return status:success()
  end

  function busted.exportApi(key, value)
    busted.api[key] = value
  end

  function busted.export(key, value)
    busted.exportApi(key, value)
    environment.set(key, value)
  end

  function busted.hide(key, value)
    busted.api[key] = nil
    environment.set(key, nil)
  end

  function busted.register(descriptor, executor, attributes)
    local alias = nil
    if type(executor) == 'string' then
      alias = descriptor
      descriptor = executor
      executor = executors[descriptor]
      attributes = attributes or eattributes[descriptor]
      executors[alias] = executor
      eattributes[alias] = attributes
    else
      if executor ~= nil and not isCallable(executor) then
        attributes = executor
        executor = nil
      end
      executors[descriptor] = executor
      eattributes[descriptor] = attributes
    end

    local publisher = function(name, fn)
      if not fn and type(name) == 'function' then
        fn = name
        name = alias
      end

      local trace

      local ctx = busted.context.get()
      if busted.context.parent(ctx) then
        trace = busted.getTrace(ctx, 3, name)
      end

      local publish = function(f)
        busted.publish({ 'register', descriptor }, name, f, trace, attributes)
      end

      if fn then publish(fn) else return publish end
    end

    local edescriptor = alias or descriptor
    busted.executors[edescriptor] = publisher
    busted.export(edescriptor, publisher)

    busted.subscribe({ 'register', descriptor }, function(name, fn, trace, attributes)
      local ctx = busted.context.get()
      local plugin = {
        descriptor = descriptor,
        attributes = attributes or {},
        name = name,
        run = fn,
        trace = trace,
        starttick = nil,
        endtick = nil,
        starttime = nil,
        endtime = nil,
        duration = nil,
      }

      busted.context.attach(plugin)

      if not ctx[descriptor] then
        ctx[descriptor] = { plugin }
      else
        ctx[descriptor][#ctx[descriptor]+1] = plugin
      end
    end)
  end

  function busted.execute(current)
    if not current then current = busted.context.get() end
    for _, v in pairs(busted.context.children(current)) do
      local executor = executors[v.descriptor]
      if executor and not busted.skipAll then
        busted.safe(v.descriptor, function() executor(v) end, v)
      end
    end
  end

  return busted
end

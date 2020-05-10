local json = require 'dkjson'

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()

  handler.suiteEnd = function()
    print(json.encode({
      pendings = handler.pendings,
      successes = handler.successes,
      failures = handler.failures,
      errors = handler.errors,
      duration = handler.getDuration()
    }))

    return nil, true
  end

  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)

  return handler
end

local setfenv = require 'busted.compatibility'.setfenv

return function(context)

  local environment = {}

  local function getEnv(self, key)
    if not self then return nil end
    return
      self.env and self.env[key] or
      getEnv(context.parent(self), key) or
      _G[key]
  end

  local function setEnv(self, key, value)
    if not self.env then self.env = {} end
    self.env[key] = value
  end

  local function __index(self, key)
    return getEnv(context.get(), key)
  end

  local function __newindex(self, key, value)
    setEnv(context.get(), key, value)
  end

  local env = setmetatable({}, { __index=__index, __newindex=__newindex })

  function environment.wrap(fn)
    return setfenv(fn, env)
  end

  function environment.set(key, value)
    local env = context.get('env')

    if not env then
      env = {}
      context.set('env', env)
    end

    env[key] = value
  end
  return environment
end

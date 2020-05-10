local tablex = require 'pl.tablex'

local function save()
  local g = {}
  for k,_ in next, _G, nil do
    g[k] = rawget(_G, k)
  end
  return {
    gmt = debug.getmetatable(_G),
    g = g,
    loaded = tablex.copy(package.loaded)
  }
end

local function restore(state)
  setmetatable(_G, state.gmt)
  for k,_ in next, _G, nil do
    rawset(_G, k, state.g[k])
  end
  for k,_ in pairs(package.loaded) do
    package.loaded[k] = state.loaded[k]
  end
end

return function()
  local context = {}

  local data = { descriptor = 'suite', attributes = {} }
  local parents = {}
  local children = {}
  local stack = {}
  local states = {}

  function context.ref()
    local ref = {}
    local ctx = data

    local function unwrap(element, levels)
      local levels = levels or 1
      local parent = element
      for i = 1, levels do
        parent = ref.parent(parent)
        if not parent then break end
      end
      if not element.env then element.env = {} end
      setmetatable(element.env, {
        __newindex = function(self, key, value)
          if not parent then
            _G[key] = value
          else
            if not parent.env then parent.env = {} end
            parent.env[key] = value
          end
        end
      })
    end

    local function push_state(current)
      local state = false
      if current.attributes.envmode == 'insulate' then
        state = save()
      elseif current.attributes.envmode == 'unwrap' then
        unwrap(current)
      elseif current.attributes.envmode == 'expose' then
        unwrap(current, 2)
      end
      table.insert(states, state)
    end

    local function pop_state(current)
      local state = table.remove(states)
      if current.attributes.envmode == 'expose' then
        states[#states] = states[#states] and save()
      end
      if state then
        restore(state)
      end
    end

    function ref.get(key)
      if not key then return ctx end
      return ctx[key]
    end

    function ref.set(key, value)
      ctx[key] = value
    end

    function ref.clear()
      data = { descriptor = 'suite', attributes = {} }
      parents = {}
      children = {}
      stack = {}
      states = {}
      ctx = data
    end

    function ref.attach(child)
      if not children[ctx] then children[ctx] = {} end
      parents[child] = ctx
      table.insert(children[ctx], child)
    end

    function ref.children(parent)
      return children[parent] or {}
    end

    function ref.parent(child)
      return parents[child]
    end

    function ref.push(current)
      if not parents[current] and current ~= data then error('Detached child. Cannot push.') end
      if ctx ~= current then push_state(current) end
      table.insert(stack, ctx)
      ctx = current
    end

    function ref.pop()
      local current = ctx
      ctx = table.remove(stack)
      if ctx ~= current then pop_state(current) end
      if not ctx then error('Context stack empty. Cannot pop.') end
    end

    return ref
  end

  return context
end

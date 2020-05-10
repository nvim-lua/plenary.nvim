local shuffle = require 'busted.utils'.shuffle
local urandom = require 'busted.utils'.urandom
local tablex = require 'pl.tablex'

local function sort(elements)
  table.sort(elements, function(t1, t2)
    if t1.name and t2.name then
      return t1.name < t2.name
    end
    return t2.name ~= nil
  end)
  return elements
end

return function(busted)
  local block = require 'busted.block'(busted)

  local function execute(runs, options)
    local root = busted.context.get()
    local children = tablex.copy(busted.context.children(root))

    local function suite_reset()
      local oldctx = busted.context.get()

      busted.context.clear()
      local ctx = busted.context.get()
      for k, v in pairs(oldctx) do
        ctx[k] = v
      end

      for _, child in ipairs(children) do
        for descriptor, _ in pairs(busted.executors) do
          child[descriptor] = nil
        end
        busted.context.attach(child)
      end

      busted.randomseed = tonumber(options.seed) or urandom() or os.time()
    end

    for i = 1, runs do
      if i > 1 then
        suite_reset()
        root = busted.context.get()
        busted.safe_publish('suite', { 'suite', 'reset' }, root, i, runs)
      end

      if options.sort then
        sort(busted.context.children(root))
      elseif options.shuffle then
        root.randomseed = busted.randomseed
        shuffle(busted.context.children(root), busted.randomseed)
      end

      local seed = (busted.randomize and busted.randomseed or nil)
      if busted.safe_publish('suite', { 'suite', 'start' }, root, i, runs, seed) then
        if block.setup(root) then
          busted.execute()
        end
        block.lazyTeardown(root)
        block.teardown(root)
      end
      busted.safe_publish('suite', { 'suite', 'end' }, root, i, runs)

      if busted.skipAll then
        break
      end
    end
  end

  return execute
end

-- Lazy load everything into plenary.
---@class Plenary
---@field async PlenaryAsync
---@field functional PlenaryFunctional
---@field path PlenaryPath
---@field scandir PlenaryScandir
local plenary = setmetatable({}, {
  __index = function(t, k)
    local ok, val = pcall(require, string.format("plenary.%s", k))

    if ok then
      rawset(t, k, val)
    end

    return val
  end,
})

return plenary

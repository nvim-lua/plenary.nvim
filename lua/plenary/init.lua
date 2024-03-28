-- Lazy load everything into plenary.
---@class Plenary
---@field async PlenaryAsync
---@field class PlenaryClass
---@field context_manager PlenaryContextManager
---@field curl PlenaryCurl
---@field functional PlenaryFunctional
---@field job PlenaryJob
---@field json PlenaryJson
---@field path PlenaryPath
---@field scandir PlenaryScandir
---@field tbl PlenaryTbl
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

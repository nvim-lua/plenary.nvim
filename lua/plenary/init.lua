-- Lazy load everything into plenary.
---@class Plenary
---@field async PlenaryAsync
---@field class PlenaryClass
---@field context_manager PlenaryContextManager
---@field curl PlenaryCurl
---@field enum PlenaryEnum
---@field filetype PlenaryFiletype
---@field fun PlenaryFun
---@field functional PlenaryFunctional
---@field job PlenaryJob
---@field json PlenaryJson
---@field log PlenaryLog
---@field nvim_meta PlenaryNvimMeta
---@field operators PlenaryOperators
---@field path PlenaryPath
---@field reload PlenaryReload
---@field scandir PlenaryScandir
---@field strings PlenaryStrings
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

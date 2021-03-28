local SEP = '\n\n\n'

local api_info = vim.fn.api_info().functions

local array_re = [[ArrayOf%(%s*(%w+)%s*%)]]

-- local s = 'ArrayOf(Buffer)'
-- local res = s:match(array_re)
-- dump(res)

-- we need a formatting/templating library!!!!
-- borrowed from daedulus
local function format(s)
  local res = {}
  function res:with(opts)
    return (s:gsub('($%b{})', function(w) return opts[w:sub(3, -2)] or w end))
  end
  return res
end

local template_normal = format [[
function ${object_name}:${method_short_name}(...)
  return vim.api.${method_real_name}(self.id, ...)
end
]]

local template_non_object_return = format [[
function Nvim:${method_short_name}(...)
  return vim.api.${method_real_name}(...)
end
]]

local template_return = format [[
function Nvim:${method_short_name}(...)
  local res = vim.api.${method_real_name}(...)
  return ${object_name}.new(res)
end
]]

local template_return_list = format [[
function Nvim:${method_short_name}(...)
  local res = vim.api.${method_real_name}(...)
  return tbl.map_inplace(res, ${object_name}.new)
end
]]

local contents = ''

contents = contents .. [[
local tbl = require('plenary.tbl')

local Buffer = {}
Buffer.__index = Buffer

function Buffer.new(id)
  return setmetatable({id = id}, Buffer)
end




local Tabpage = {}
Tabpage.__index = Tabpage

function Tabpage.new(id)
  return setmetatable({id = id}, Tabpage)
end




local Window = {}
Window.__index = Window

function Window.new(id)
  return setmetatable({id = id}, Window)
end


local objects = {
  Window = Window,
  Buffer = Buffer,
  Tabpage = Tabpage,
}



local Nvim = {}
Nvim.__index = function(t, k)
  return t[k] or objects[k]
end
]]

local processed_info = vim.tbl_map(function(info)
  if info.name:match("nvim_buf_") then
    info.short_name = info.name:gsub("nvim_buf_", "")
    info.object = "Buffer"
  elseif info.name:match("nvim_win_") then
    info.short_name = info.name:gsub("nvim_win_", "")
    info.object = "Window"
  elseif info.name:match("nvim_tabpage_") then
    info.short_name = info.name:gsub("nvim_tabpage_", "")
    info.object = "Tabpage"
  else
    info.short_name = info.name:gsub("nvim_", "")
    info.object = "Nvim"
  end
  return info
end, api_info)

processed_info = vim.tbl_filter(function(info)
  return not info.deprecated_since
end, processed_info)

local objects = {
  Buffer = true,
  Window = true,
  Tabpage = true,
}

for _, processed_info in ipairs(processed_info) do
  if processed_info.object ~= "Nvim" then
    contents = contents .. SEP .. template_normal:with {
      object_name = processed_info.object,
      method_short_name = processed_info.short_name,
      method_real_name = processed_info.name,
    }
  else
    local array_match = processed_info.return_type:match(array_re)
    if objects[array_match] then
      contents = contents .. SEP .. template_return_list:with {
        object_name = array_match,
        method_short_name = processed_info.short_name,
        method_real_name = processed_info.name,
      }
    elseif objects[processed_info.return_type] then
      contents = contents .. SEP .. template_return:with {
        object_name = processed_info.return_type,
        method_short_name = processed_info.short_name,
        method_real_name = processed_info.name,
      }
    else
      contents = contents .. SEP .. template_non_object_return:with {
        method_short_name = processed_info.short_name,
        method_real_name = processed_info.name,
      }
    end
  end
end

contents = contents .. '\n' .. 'return Nvim'

local file = io.open("../lua/plenary/nvim/generated.lua", "w")
file:write(contents)
file:close()

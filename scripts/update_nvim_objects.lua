local SEP = '\n\n\n'
local PRELUDE = [[-- Don't edit this file, it was generated. See scripts/update_nvim_objects.lua]]

local api_info = vim.fn.api_info().functions

local array_re = [[ArrayOf%(%s*(%w+)%s*%)]]

-- we need a formatting/templating library!!!!
-- borrowed from daedulus
local function format(s)
  local res = {}
  function res:with(opts)
    return (s:gsub('($%b{})', function(w)
      local word = w:sub(3, -2)
      local to_sub = opts[w:sub(3, -2)]
      if to_sub == nil then
        error('The key for ' .. word .. ' was not provided')
      end
      return to_sub
    end))
  end
  return res
end

local template = format [[
function ${object_name}:${method_short_name}(...)
  ${return_statements}
end
]]

local object_return_template = format [[
local res = vim.api.${method_real_name}(${should_id}...)
  return ${object_name}.new(res)]]

local object_list_return_template = format [[
local res = vim.api.${method_real_name}(${should_id}...)
  return tbl.map_ipairs_inplace(res, ${object_name}.new)]]

local normal_return_template = format [[
return vim.api.${method_real_name}(${should_id}...)]]

local contents = PRELUDE

local function add(s)
  contents = contents .. SEP .. s
end
add [[
local tbl = require('plenary.tbl')
]]

add [[
local Buffer = {}
Buffer.__index = Buffer

function Buffer.new(id)
  return setmetatable({id = id}, Buffer)
end

function Buffer.is_buffer(object)
  return getmetatable(object) == Buffer
end

function Buffer.prefix()
  return "nvim_buf_"
end
]]

add [[
local Tabpage = {}
Tabpage.__index = Tabpage

function Tabpage.new(id)
  return setmetatable({id = id}, Tabpage)
end

function Tabpage.is_tabpage(object)
  return getmetatable(object) == Tabpage
end

function Tabpage.prefix()
  return "nvim_tabpage_"
end
]]

add [[
local Window = {}
Window.__index = Window

function Window.new(id)
  return setmetatable({id = id}, Window)
end

function Window.is_window(object)
  return getmetatable(object) == Window
end

function Window.prefix()
  return "nvim_win_"
end
]]

add [[
local Nvim = {
  Buffer = Buffer,
  Tabpage = Tabpage,
  Window = Window,
}
]]

-- we need iterators!
local processed_infos = vim.tbl_map(function(info)
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

processed_infos = vim.tbl_filter(function(info)
  return not info.deprecated_since
end, processed_infos)

local objects = {
  Buffer = true,
  Window = true,
  Tabpage = true,
}

for _, processed_info in ipairs(processed_infos) do
  local return_statements

  local should_id = objects[processed_info.object]
  local should_id_s = should_id and "self.id, " or ""

  local array_match = processed_info.return_type:match(array_re)
  if objects[array_match] then
    return_statements = object_list_return_template:with {
      method_real_name = processed_info.name,
      object_name = array_match,
      should_id = should_id_s
    }
  elseif objects[processed_info.return_type] then
    return_statements = object_return_template:with {
      method_real_name = processed_info.name,
      object_name = processed_info.return_type,
      should_id = should_id_s
    }
  else
    return_statements = normal_return_template:with {
      method_real_name = processed_info.name,
      should_id = should_id_s
    }
  end

  local full = template:with {
    object_name = processed_info.object,
    method_short_name = processed_info.short_name,
    return_statements = return_statements,
  }

  add(full)
end

contents = contents .. '\n' .. 'return Nvim'

local file = io.open("../lua/plenary/nvim/generated.lua", "w")
file:write(contents)
file:close()

print('Done!')

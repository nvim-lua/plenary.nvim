local api = vim.api
local tbl = require'plenary.tbl'

local function get_method(object, method)
  local prefix = object:prefix()
  local real_name = object .. method

  local api_func = api[prefix .. method]
  if api_func == nil then
    error(string.format('No function found for method %s with real name %s', method, real_name))
  end

  local id = object.id
  if id == nil then
    error(string.format('Object does not have an id'))
  end

  return function(...)
    api_func(object.id, ...)
  end
end

local Buffer = {}

do
  local manual = {
    get_current_buf = function()
      return Buffer.new(api.nvim_get_current_buf())
    end,

    list_bufs = function()
      return tbl.map_inplace(api.nvim_list_bufs(), Buffer.new)
    end
  }

  Buffer.__index = function(object, method)
    return manual[method] or get_method(object, method)
  end
end

function Buffer.new(id)
  return setmetatable({id = id}, Buffer)
end

function Buffer:prefix()
  return "nvim_buf_"
end

local Tabpage = {}
do
  local manual = {
    list_tabpages = function ()
      return tbl.map_inplace(api.nvim_list_tabpages(), Tabpage.new)
    end
  }

  Tabpage.__index = function(object, method)
    return manual[method] or get_method(object, method)
  end
end

function Tabpage.new(id)
  return setmetatable({id = id}, Tabpage)
end

function Tabpage:prefix()
  return "nvim_tabpage_"
end

local Window = {}
do
  local manual = {
    list_wins = function()
      return tbl.map_inplace(api.nvim_list_bufs(), Window.new)
    end
  }

  Tabpage.__index = function(object, method)
    return manual[method] or get_method(object, method)
  end
end

function Window.new(id)
  return setmetatable({id = id}, Window)
end

function Window:prefix()
  return "nvim_window_"
end

return {
  Buffer = Buffer,
  Tabpage = Tabpage,
  Window = Window,
}

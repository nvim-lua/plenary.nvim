local api = vim.api
local tbl = require'plenary.tbl'

local function get_method(object, name)
  local prefix = object:prefix()
  local real_name = prefix .. name

  local api_func = api[real_name]
  if api_func == nil then
    error(string.format('No function found for method %s with real name %s', name, real_name))
  end

  return function(self, ...)
    return api_func(self.id or error("Object does not have an id"), ...)
  end
end

local Buffer = {}

do
  local manual = {}

  local not_implemented = {
    get_current_buf = true,
    list_bufs = true,
  }

  Buffer.__index = function(object, method)
    if not_implemented[method] then error("Method not implemented") end
    return Buffer[method] or manual[method] or get_method(object, method)
  end
end

function Buffer.new(id)
  return setmetatable({id = id}, Buffer)
end

function Buffer:get_current()
  return Buffer.new(api.nvim_get_current_buf())
end

function Buffer:get_list()
  return tbl.map_inplace(api.nvim_list_bufs(), Buffer.new)
end

function Buffer:prefix()
  return "nvim_buf_"
end

function Buffer:id()
  return self.id
end

local Tabpage = {}
do
  local manual = {}

  local not_implemented = {
    get_current_buf = true,
    list_bufs = true,
  }

  Tabpage.__index = function(object, method)
    if not_implemented[method] then error("Method not implemented") end
    return Tabpage[method] or manual[method] or get_method(object, method)
  end
end

function Tabpage.new(id)
  return setmetatable({id = id}, Tabpage)
end

function Tabpage:prefix()
  return "nvim_tabpage_"
end

function Tabpage:get_current()
  return Tabpage.new(api.nvim_get_current_tabpage())
end

function Tabpage:get_list()
  return tbl.map_inplace(api.nvim_list_bufs(), Tabpage.new)
end

local Window = {}
do
  local manual = {
    list_wins = function()
      return tbl.map_inplace(api.nvim_list_bufs(), Window.new)
    end
  }

  local not_implemented = {
    get_current_win = true,
    list_wins = true,
  }

  Window.__index = function(object, method)
    if not_implemented[method] then error("Method not implemented") end
    return Window[method] or manual[method] or get_method(object, method)
  end
end

function Window.new(id)
  return setmetatable({id = id}, Window)
end

function Window:prefix()
  return "nvim_win_"
end

function Window:get_current()
  return Window.new(api.nvim_get_current_win())
end

function Window:get_list()
  return tbl.map_inplace(api.nvim_list_wins(), Window.new)
end

return setmetatable(
  {
    Buffer = Buffer,
    Tabpage = Tabpage,
    Window = Window,
  },
  {
    __index = function(_, k)
      return api["nvim_" .. k]
    end
  }
)

local eq = assert.are.same
local nvim = require('plenary.nvim')

describe('Buffer', function()
  it('should have the correct prefix', function()
    local prefix = nvim.Buffer:prefix()
    eq(prefix, "nvim_buf_")
  end)

  it('should get current and get commands', function()
    local buffer = nvim.Buffer:get_current()
    eq(getmetatable(buffer), nvim.Buffer)
    local commands = buffer:get_commands({})
    eq(type(commands), "table")
  end)

  it('should list bufs', function()
    local buffers = nvim.Buffer:get_list()
    for _, buffer in ipairs(buffers) do
      eq(getmetatable(buffer), nvim.Buffer)
      local commands = buffer:get_commands({})
      eq(type(commands), "table")
    end
  end)
end)

describe('Tabpage', function ()
  it('should be able to get current', function ()
    local curr = nvim.Tabpage:get_current()
      eq(getmetatable(curr), nvim.Tabpage)
  end)

  it('should be able to list', function ()
    local tabpages = nvim.Tabpage:get_list()
    for _, tabpage in ipairs(tabpages) do
      eq(getmetatable(tabpage), nvim.Tabpage)
    end
  end)
end)

describe('Window', function ()
  it('should be able to get current', function ()
    local curr = nvim.Window:get_current()
    eq(getmetatable(curr), nvim.Window)
  end)

  it('should be able to list', function ()
    local windows = nvim.Window:get_list()
    for _, tabpage in ipairs(windows) do
      eq(getmetatable(tabpage), nvim.Window)
    end
  end)
end)

describe('nvim', function()
  it('should be able to call normal api functions', function ()
    nvim:get_mode()
  end)
end)

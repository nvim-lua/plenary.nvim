local eq = assert.are.same
local Nvim = require('plenary.nvim')

describe('Buffer', function()
  it('should have the correct prefix', function()
    local prefix = Nvim.Buffer:prefix()
    eq(prefix, "nvim_buf_")
  end)
end)

describe('Nvim', function()
  it('should be able to call normal api functions', function ()
    Nvim:get_mode()
  end)

  it('should be able to call normal api functions that return objects', function()
    local buffer = Nvim:get_current_buf()
    assert(Nvim.Buffer.is_buffer(buffer))
    local commands = buffer:get_commands({})
    eq(type(commands), "table")
  end)

  it('should be able to call normal api functions that return a list of objects', function()
    local buffers = Nvim:list_bufs()
    for _, buffer in ipairs(buffers) do
      assert(Nvim.Buffer.is_buffer(buffer))
      local commands = buffer:get_commands({})
      eq(type(commands), "table")
    end
  end)
end)

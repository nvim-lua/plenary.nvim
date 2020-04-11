local lu = require("plenary.luaunit")

local test_harness = {}
test_harness.__index = lu.__index

function test_harness:run()
  vim.cmd("setlocal buftype=nofile")
  vim.cmd("setlocal bufhidden=hide")
  vim.cmd("setlocal noswapfile")

  -- Stuff shouldn't print to stdout, we can do something cooler
  local print_stdout = print
  print = function(...)
    local message = vim.split(table.concat({...}, "    "), "\n")
    if message == {} then
      message = {""}
    end

    vim.fn.nvim_buf_set_lines(0, -1, -1, false, message)
  end

  lu.LuaUnit.run()
  -- Would not mind having a bit nicer output, but it's fine for now.
  -- lu.LuaUnit.run("--outputtype=tap")

  -- Restore print
  print = print_stdout

  -- weirdly need to redraw the screen sometimes... oh well
  vim.cmd("mode")
end


return test_harness

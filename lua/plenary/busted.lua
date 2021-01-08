local dirname = function(p)
  return vim.fn.fnamemodify(p, ":h")
end

local function get_trace(element, level, msg)
  local function trimTrace(info)
    local index = info.traceback:find('\n%s*%[C]')
    info.traceback = info.traceback:sub(1, index)
    return info
  end
  level = level or  3

  local thisdir = dirname(debug.getinfo(1, 'Sl').source, ":h")
  local info = debug.getinfo(level, 'Sl')
  while info.what == 'C' or info.short_src:match('luassert[/\\].*%.lua$') or
        (info.source:sub(1,1) == '@' and thisdir == dirname(info.source)) do
    level = level + 1
    info = debug.getinfo(level, 'Sl')
  end

  info.traceback = debug.traceback('', level)
  info.message = msg

  -- local file = busted.getFile(element)
  local file = false
  return file and file.getTrace(file.name, info) or trimTrace(info)
end



local is_headless = require('plenary.nvim_meta').is_headless

local print = function(...)
  for _, v in ipairs({...}) do
    io.stdout:write(tostring(v))
    io.stdout:write("\t")
  end

  io.stdout:write("\r\n")
end

local mod = {}

local results = {}
local current_description = {}

local add_description = function(desc)
  table.insert(current_description, desc)

  return vim.deepcopy(current_description)
end

local pop_description = function()
  current_description[#current_description] = nil
end

local execution_stack = {}

local call_inner = function(desc, func)
  local desc_stack = add_description(desc)

  -- Push function onto stack
  table.insert(execution_stack, func)

  local ok, msg = xpcall(func, function(msg)
    -- debug.traceback
    -- return vim.inspect(get_trace(nil, 3, msg))
    local trace = get_trace(nil, 3, msg)
    return trace.message .. "\n" .. trace.traceback
  end)

  -- Remove function from stack
  execution_stack[#execution_stack] = nil

  pop_description()

  return ok, msg, desc_stack
end

local color_table = {
  yellow = 33,
  green = 32,
  red = 31,
}

local color_string = function(color, str)
  if not is_headless then
    return str
  end

  return string.format("%s[%sm%s%s[%sm",
    string.char(27),
    color_table[color] or 0,
    str,
    string.char(27),
    0
  )
end

local SUCCESS = color_string("green", "Success")
local FAIL = color_string("red", "Fail")
local PENDING = color_string("yellow", "Pending")

local HEADER = string.rep("=", 40)

mod.format_results = function(res)
  local num_pass = #res.pass
  local num_fail = #res.fail
  local num_errs = #res.errs

  print("")
  print(color_string("green", "Success: "), num_pass)
  print(color_string("red", "Failed : "), num_fail)
  print(color_string("red", "Errors : "), num_errs)
  print(HEADER)
end

mod.describe = function(desc, func)
  results.pass = {}
  results.fail = {}
  results.errs = {}

  print("\n" .. HEADER)
  print("Testing: ", debug.getinfo(2, 'Sl').source)

  describe = mod.inner_describe
  local ok, msg = call_inner(desc, func)
  describe = mod.describe

  mod.format_results(results)

  if not ok then
    print("We had an unexpected error: ", msg, vim.inspect(results))
    if is_headless then
      os.exit(2)
    end
  elseif #results.fail > 0 then
    print("Tests Failed. Exit: 1")

    if is_headless then
      os.exit(1)
    end
  else
    if is_headless then
      os.exit(0)
    end
  end
end

mod.inner_describe = function(desc, func)
  local ok, msg, desc_stack = call_inner(desc, func)

  if not ok then
    table.insert(results.errs, {
      descriptions = desc_stack,
      msg = msg
    })
  end
end

local indent = function(msg, spaces)
  if spaces == nil then
    spaces = 4
  end

  local prefix = string.rep(" ", spaces)
  return prefix .. msg:gsub("\n", "\n" .. prefix)

end

mod.it = function(desc, func)
  -- TODO: Should probably clean this up.
  -- TODO: Also needs after_each
  -- call before_each
  for _, exec_func in ipairs(execution_stack) do
    for _, before in ipairs(mod._before_each_map[exec_func] or {}) do
      before()
    end
  end

  local ok, msg, desc_stack = call_inner(desc, func)

  local test_result = {
    descriptions = desc_stack,
    msg = nil,
  }

  -- TODO: We should figure out how to determine whether
  -- and assert failed or whether it was an error...

  local to_insert
  if not ok then
    to_insert = results.fail
    test_result.msg = msg

    print(FAIL, "||", table.concat(test_result.descriptions, " "))
    print(indent(msg, 12))
  else
    to_insert = results.pass
    print(SUCCESS, "||", table.concat(test_result.descriptions, " "))
  end

  table.insert(to_insert, test_result)
end

mod.pending = function(desc, func)
  -- TODO: Probably want to show description stack
  -- local _, _, desc_stack = call_inner(desc, func)
  print(PENDING, "||", desc)
end

mod._before_each_map = {}
mod.before_each = function(func)
  -- Add a reference to the before each for the current execution.
  -- When we pop this off the stack later, we won't run it then!
  local current_func = execution_stack[#execution_stack]
  if not mod._before_each_map[current_func] then
    mod._before_each_map[current_func] = {}
  end

  table.insert(mod._before_each_map[current_func], func)
end

_PlenaryBustedOldAssert = _PlenaryBustedOldAssert or assert


describe = mod.describe
it = mod.it
pending = mod.pending
assert = require("luassert")

before_each = mod.before_each

mod.run = function(file)
  local ok, msg = pcall(dofile, file)

  if not ok then
    print(HEADER)
    print("FAILED TO LOAD FILE")
    print(color_string("red", msg))
    print(HEADER)
    os.exit(2)
  end

  os.exit(0)
end

return mod

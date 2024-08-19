local util = require "plenary.async.util"

---@class PlenaryAsyncTests
local M = {}

---@param s string
---@param async_func PlenaryAsyncFunction
M.describe = function(s, async_func)
  describe(s, async_func)
end

---@param s string
---@param async_func PlenaryAsyncFunction
M.it = function(s, async_func)
  it(s, util.will_block(async_func, tonumber(vim.env.PLENARY_TEST_TIMEOUT)))
end

---@param async_func PlenaryAsyncFunction
M.pending = function(async_func)
  pending(async_func)
end

---@param async_func PlenaryAsyncFunction
M.before_each = function(async_func)
  before_each(util.will_block(async_func))
end

---@param async_func PlenaryAsyncFunction
M.after_each = function(async_func)
  after_each(util.will_block(async_func))
end

return M

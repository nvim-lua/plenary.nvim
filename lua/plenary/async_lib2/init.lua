---@brief [[
--- NOTE: This API is still under construction.
---         It may change in the future :)
---@brief ]]

local exports = require('plenary.async_lib2.async')
exports.uv = require('plenary.async_lib2.uv_async')
exports.util = require('plenary.async_lib2.util')
exports.lsp = require('plenary.async_lib2.lsp')
exports.api = require('plenary.async_lib2.api')
exports.tests = require('plenary.async_lib2.tests')
exports.control = require('plenary.async_lib2.control')

exports.tests.add_globals = function()
  a = exports
  async = exports.async
  await = exports.await
  await_all = exports.await_all

  -- must prefix with a or stack overflow, plenary.test harness already added it
  a.describe = exports.tests.describe
  -- must prefix with a or stack overflow
  a.it = exports.tests.it
end

exports.tests.add_to_env = function()
  local env = getfenv(2)

  env.a = exports
  env.async = exports.async
  env.await = exports.await
  env.await_all = exports.await_all

  -- must prefix with a or stack overflow, plenary.test harness already added it
  env.a.describe = exports.tests.describe
  -- must prefix with a or stack overflow
  env.a.it = exports.tests.it

  setfenv(2, env)
end

return exports

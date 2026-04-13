local a = require "plenary.async.async"

---@class PlenaryAsyncLsp
local M = {}

---@alias ClientRequestIds table<integer, integer>

---This will be deprecated because the callback can be called multiple times.
---This will give a coroutine error because the coroutine will be resumed multiple times.
---Please use buf_request_all instead.
---@type async fun(bufnr: integer, method: string, params?: table, handler?: lsp.Handler): ClientRequestIds, function
M.buf_request = a.wrap(vim.lsp.buf_request, 4)

---@alias BufRequestAllHandler fun(results: table<integer, { error: lsp.ResponseError, result: any }>)

---Sends an async request for all active clients attached to the buffer and executes the `handler`
---callback with the combined result.
---
---* param bufnr (integer) Buffer handle, or 0 for current.
---* param method (string) LSP method name
---* param params (table|nil) Parameters to send to the server
---* param handler fun(results: table<integer, {error: lsp.ResponseError, result: any}>) (function)
--- Handler called after all requests are completed. Server results are passed as
--- a `client_id:result` map.
---* return function cancel Function that cancels all requests.
---@type async fun(bufnr: integer, method: string, params?: table, handler: BufRequestAllHandler): function
M.buf_request_all = a.wrap(vim.lsp.buf_request_all, 4)

return M

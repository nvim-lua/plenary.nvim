local a = require('plenary.async.async')

local M = {}

M.buf_request = a.wrap(vim.lsp.buf_request)

return M

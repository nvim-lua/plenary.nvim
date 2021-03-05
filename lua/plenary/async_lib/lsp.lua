local a = require('plenary.async_lib.async')

local M = {}

M.buf_request = a.wrap(vim.lsp.buf_request, 4)

return M

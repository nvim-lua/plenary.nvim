local a = require('plenary.async_lib.async')

local M = {}

---Same as vim.lsp.buf_request but works with async await
M.buf_request = a.wrap(vim.lsp.buf_request, 4)

return M

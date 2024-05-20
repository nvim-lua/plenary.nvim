local m = {}

m.flatten = (function()
  if vim.fn.has "nvim-0.11" == 1 then
    return function(t)
      return vim.iter(t):flatten():totable()
    end
  else
    return function(t)
      return vim.tbl_flatten(t)
    end
  end
end)()

m.islist = vim.islist or vim.tbl_islist

return m

local profile = {}

function profile.time(f, iterations, ...)
  local start_time = vim.fn.reltime()
  for _ = 1, iterations or 1E9 do
    f(...)
  end
  return vim.fn.reltimestr(vim.fn.reltime(start_time))
end

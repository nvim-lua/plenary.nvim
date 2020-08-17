local profile = {}

function profile.time(f, iterations, ...)
  local start_time = vim.loop.hrtime()
  for _ = 1, iterations or 1E9 do
    f(...)
  end
  return (vim.loop.hrtime() - start_time) / 1E9
end

return profile

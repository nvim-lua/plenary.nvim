local profile = {}

function profile.benchmark(iterations, f, ...)
  local start_time = vim.loop.hrtime()
  for _ = 1, iterations do
    f(...)
  end
  return (vim.loop.hrtime() - start_time) / 1E9
end

return profile

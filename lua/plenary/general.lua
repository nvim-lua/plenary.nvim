local general = {}

function general.profile(f, iterations, ...)
  local start_time = vim.fn.reltime()
  for _ = 1, iterations or 1E9 do
    f(...)
  end
  return vim.fn.reltimestr(vim.fn.reltime(start_time))
end

function general.first(...)
  local x = select(1, ...)
  return x
end

function general.second(...)
  local x = select(2, ...)
  return x
end

function general.third(...)
  local x = select(3, ...)
  return x
end

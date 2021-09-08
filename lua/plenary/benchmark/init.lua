local B = {}
local stat = require "plenary.benchmark.stat"

local get_stat = function(start, runs, fun)
  local result = {}

  for i = 1, runs do
    fun()
    result[i] = vim.loop.hrtime() - start
  end

  local ret = {}

  ret.max, ret.min = stat.maxmin(result)
  ret.mean = stat.mean(result)
  ret.median = stat.median(result)
  ret.std = stat.std_dev(result)

  return ret
end

local get_output = function(name, res)
  local start = "  - "
  if type(name) ~= "number" then
    start = start .. ("[[%s]] "):format(name)
  end

  return start
    .. ("min: %.3fs, max: %.3fs, mean: %.3fs, median: %fs, std: %fs\n"):format(
      res.min,
      res.max,
      res.mean,
      res.median,
      res.std
    )
end

---@class benchmark_run_opts
---@field warmup number @number of initial runs before starting to track time.
---@field runs number @number of runs to make
---@field fun table<string, function>|function @function to execute

---Benchmark a function
---@param name string @benchmark name
---@param opts benchmark_run_opts
local bench = function(name, opts)
  opts.fun = type(opts.fun) == "function" and { opts.fun } or opts.fun
  for _ = 1, opts.warmup or 5 do
    for _, fun in pairs(opts.fun) do
      fun()
    end
  end
  local start = vim.loop.hrtime()

  local output, res = "", {}

  for k, fun in pairs(opts.fun) do
    res[k] = get_stat(start, opts.runs, fun)
    output = output .. get_output(k, res[k])
  end

  res.elapsed = vim.loop.hrtime() - start

  print(
    ("[[%s]] Benchmark: \n\n  - total elapsed time: %.3fms\n  - runs: %s\n"):format(name, res.elapsed, opts.runs)
      .. output
  )

  return res
end

-- bench("Predicting Y", {
--   runs = 10,
--   fun = function()
--     vim.wait(200, function() end)
--   end,
-- })
-- (slower / faster)
bench("Predicting Y", {
  runs = 5,
  fun = {
    base = function()
      vim.wait(200, function() end)
    end,
    ench = function()
      vim.wait(100, function() end)
    end,
  },
})

return bench

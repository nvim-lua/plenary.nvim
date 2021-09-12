local B = {}
local stat = require "plenary.benchmark.stat"

local get_stats = function(results)
  local ret = {}

  ret.max, ret.min = stat.maxmin(results)
  ret.mean = stat.mean(results)
  ret.median = stat.median(results)
  ret.std = stat.std_dev(results)

  return ret
end

local get_output = function(index, res, runs)
  -- divine with a sutable one / 1e3, 1e6, 1e9
  return string.format(
    "Benchmark #%d: '%s'\n  Time(mean ± σ):    %.1f ms ± %.1f ms\n  Range(min … max):  %.1f ms … %.1f ms  %d runs\n",
    index,
    res.name,
    res.stats.mean / 1e6,
    res.stats.std / 1e6,
    res.stats.min / 1e6,
    res.stats.max / 1e6,
    runs
  )
end

local get_summary = function(res)
  if #res == 1 then
    return ""
  end

  local fastest_mean = math.huge
  local fastest_index = 1
  for i, benchmark in ipairs(res) do
    if benchmark.stats.mean < fastest_mean then
      fastest_mean = benchmark.stats.mean
      fastest_index = i
    end
  end

  if fastest_mean == math.huge then
    return ""
  end

  local output = {}
  local fastest = res[fastest_index].stats
  for i, benchmark in ipairs(res) do
    if i ~= fastest_index then
      local result = benchmark.stats
      local ratio = result.mean / fastest.mean

      -- // https://en.wikipedia.org/wiki/Propagation_of_uncertainty#Example_formulas
      -- // Covariance asssumed to be 0, i.e. variables are assumed to be independent
      local ratio_std = ratio
        * math.sqrt(math.pow(result.std / result.mean, 2) + math.pow(fastest.std / fastest.mean, 2))

      table.insert(output, string.format("  %.1f ± %.1f times faster than '%s'\n", ratio, ratio_std, benchmark.name))
    end
  end

  return string.format("Summary\n  '%s' ran\n%s", res[fastest_index].name, table.concat(output, ""))
end

---@class benchmark_run_opts
---@field warmup number @number of initial runs before starting to track time.
---@field runs number @number of runs to make
---@field fun table<array<string, function>> @functions to execute

---Benchmark a function
---@param name string @benchmark name
---@param opts benchmark_run_opts
local bench = function(name, opts)
  vim.validate {
    opts = { opts, "table" },
    fun = { opts.fun, "table" },
  }
  opts.warmup = vim.F.if_nil(opts.warmup, 3)
  opts.runs = vim.F.if_nil(opts.runs, 5)

  opts.fun = type(opts.fun) == "function" and { opts.fun } or opts.fun
  local output = { string.format("Benchmark Group: '%s' -----------------------\n", name) }
  local res = {}
  for i, fun in ipairs(opts.fun) do
    res[i] = { name = fun[1], results = {} }
    for _ = 1, opts.warmup do
      fun[2]()
    end
    for j = 1, opts.runs do
      local start = vim.loop.hrtime()
      fun[2]()
      res[i].results[j] = vim.loop.hrtime() - start
    end
    res[i].stats = get_stats(res[i].results)
    table.insert(output, get_output(i, res[i], opts.runs))
  end

  print(string.format("%s\n%s", table.concat(output, ""), get_summary(res)))

  return res
end

return bench

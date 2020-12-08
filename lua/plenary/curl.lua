local F = require('plenary.functional')
local J = require('plenary.job')
local c = { util = {}, parse = {}, api = {} }
local util, parse, api = c.util, c.parse, c.api

-- Utils ----------------------------------------------------
-------------------------------------------------------------

util.expand = function(path)
  local expanded
  if string.find(path, "~") then
    expanded = string.gsub(path, "^~", vim.loop.os_homedir())
  elseif string.find(path, "^%.") then
    expanded = vim.loop.fs_realpath(path)
    if expanded == nil then
     expanded = vim.fn.fnamemodify(path, ":p")
   end
  elseif string.find(path, "%$") then
    local rep = string.match(path, "([^%$][^/]*)")
    local val = os.getenv(rep)
    if val then
      expanded = string.gsub(string.gsub(path, rep, val), "%$", "")
    else
      expanded = nil
    end
  else
    expanded = path
  end
  return expanded and expanded or error("Path not valid")
end

util.isfile = function(path)
  local stat = vim.loop.fs_stat(util.expand(path))
  if stat then
    return stat.type == "file" and true or nil
  end
end

util.readfile = function(path)
  local f, err = io.open(path, "rb")
  assert(not err, err)
  local content = vim.split(f:read("a"), "\n")
  f:close()
  local lines = {}
  for _, line in pairs(content) do
    if ("" ~= line) then
      table.insert(lines, line)
    end
  end
  return lines
end

util.url_encode = function(str)
  if type(str) ~= "number" then
  str = str:gsub("\r?\n", "\r\n")
  str = str:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", c:byte())
  end)
  str = str:gsub(" ", "+")
  return str
  else
    return str
  end
end

util.kv_to_list = function(kv, prefix, sep)
  return vim.tbl_flatten(F.kv_map(function(kvp)
    return {prefix, kvp[1] .. sep .. kvp[2]}
  end, kv))
end

util.kv_to_str = function(kv, sep, kvsep)
  return F.join(F.kv_map(function(kvp)
    return kvp[1] .. kvsep .. util.url_encode(kvp[2])
  end, kv), sep)
end

util.gen_dump_path = function()
  local id = string.gsub("xxxx4xxx", "[xy]", function(l)
    local v = (l == "x") and math.random(0, 0xf) or math.random(0, 0xb)
    return string.format("%x", v)
  end)
  local path = "/tmp/plenary_curl_" .. id .. ".headers"
  return {"-D", path}
end

-- Helpers ----------------------------------------------------
---------------------------------------------------------------

parse.curl_headers = function(t)
  if not t then return end
  local upper = function(str)
    return string.gsub(" " .. str, "%W%l", string.upper):sub(2)
  end
  return util.kv_to_list((function()
    local normilzed = {}
    for k,v in pairs(t) do
      normilzed[upper(k:gsub("_", "%-"))] = v
    end
    return normilzed
  end)(), "-H", ": ")
end

parse.curl_data = function(t)
  if not t then return end
  return util.kv_to_list(t, "-d", "=")
end

parse.curl_raw = function(xs)
  if not xs then return end
  if type(xs) == "table" then
    return parse.curl_data(xs)
  else
    return {"--data-raw", xs}
  end
end

parse.curl_form = function(t)
  if not t then return end
  return util.kv_to_list(t, "-F", "=")
end

parse.curl_query = function(t)
  if not t then return end
  return util.kv_to_str(t, "&", "=")
end

parse.curl_method = function(s)
  if not s then return end
  if s ~= "head" then
    return {"-X", string.upper(s)}
  else
    return {"-I"}
  end
end

parse.curl_in_file = function(p)
  if not p then return end
  return {"-d", "@" .. util.expand(p) }
end

parse.curl_auth = function(xs)
  if not xs then return end
  return {"-u", type(xs) == "table" and util.kv_to_str(xs, nil, ":") or xs}
end

parse.curl_url = function(xs, q)
  if not xs then return end
  q = parse.curl_query(q)
  if type(xs) == "string" then
    return q and xs .. "?" .. q or xs
  elseif type(xs) == "table" then
    error("Low level URL definition is not supported.")
  end
end

parse.curl_accept = function(s)
  if not s then return end
  return {"-H", "Accept: " .. s}
end

parse.curl_opts = function(opts)
  if opts.body then
    local b = opts.body; opts.body = nil
    if type(b) == "table" then
      opts.data = b
    elseif util.isfile(b) then
      opts.in_file = b
    elseif type(b) == "string" then
      opts.raw = b
    end
  end
  opts.dump = util.gen_dump_path()
  local args = {
    "-sSL", opts.dump,
    opts.compressed and "--compressed" or nil,
    parse.curl_method(opts.method),
    parse.curl_headers(opts.headers),
    parse.curl_accept(opts.accept),
    parse.curl_raw(opts.raw),
    parse.curl_data(opts.data),
    parse.curl_form(opts.form),
    parse.curl_in_file(opts.in_file),
    parse.curl_auth(opts.auth),
    opts.raw_args,
    opts.output and {"-o", opts.output} or nil,
    parse.curl_url(opts.url, opts.query)
  }

  return vim.tbl_flatten(args), opts
end

-- Main ----------------------------------------------------
------------------------------------------------------------

parse.response = function(lines, dump_path, code)
  local headers = util.readfile(dump_path)
  local status = tonumber(string.match(headers[1], "([%w+]%d+)"))
  local body = F.join(lines, "\n")

  vim.loop.fs_unlink(dump_path)
  table.remove(headers, 1)

  return {
    status = status,
    headers = headers,
    body = body,
    exit = code
  }
end

api.request = function(o)
  local response = {}
  local defaults = { compressed = true, dry_run = false }
  local args, opts = parse.curl_opts(vim.tbl_extend("force", defaults, o))
  if opts.dry_run then return args end

  local on_exit = function(j, code)
    local output = parse.response(j:result(), opts.dump[2], code)
    if not opts.callback then
      response = output
    else
      return opts.callback(output)
    end
  end

  local job = J:new({ command = "curl", args = args, on_exit = on_exit })

  if not opts.callback then
    job:sync(10000)
    return response
  else
    job:start()
  end
end

-- Export --------------------------------------------------
------------------------------------------------------------
api.wrap = function(url, opts, method)
  opts = opts or {}
  return api.request(vim.tbl_extend("keep", opts, {
    url = url,
    method = method
  }))
end

api.get = function(url, opts)
  return api.wrap(url, opts ,"get")
end

api.post = function(url, opts)
  return api.wrap(url, opts ,"post")
end

api.put = function(url, opts)
  return api.wrap(url, opts ,"put")
end

api.head = function(url, opts)
  return api.wrap(url, opts ,"head")
end

api.patch = function(url, opts)
  return api.wrap(url, opts ,"patch")
end

api.delete = function(url, opts)
  return api.wrap(url, opts ,"delete")
end

return api

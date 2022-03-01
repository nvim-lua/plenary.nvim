local cmd = vim.cmd

local M = {}

local callbacks = {}

function M._exec(id)
  callbacks[id]()
end

local function set_callback(fn)
  local id = string.format("%p", fn)
  callbacks[id] = fn
  return string.format('lua require("plenary.autocmd")._exec("%s")', id)
end

function M.autocmd(event, opts)
  cmd(
    table.concat {
      "autocmd",
      opts.group or "",
      type(event) == "table" and table.concat(event, ",") or event,
      type(opts.pattern) == "table" and table.concat(opts.pattern, ",") or opts.pattern or "*",
      opts.once and "++once" or "",
      opts.nested and "++nested" or "",
      type(opts.callback) == "function" and set_callback(opts.callback) or opts.command,
    },
    " "
  )
end

function M.augroup(name, opts)
  opts = opts or {}

  cmd("augroup " .. name)
  if opts.clear ~= false then
    cmd "autocmd!"
  end
  cmd "augroup END"
end

return M

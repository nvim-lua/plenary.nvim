-- Taken from neovim/runtime/lua/vim/keymap,lua

local api = vim.api

local keymap = {}

function keymap.set(mode, lhs, rhs, opts)
  vim.validate {
    mode = { mode, { "s", "t" } },
    lhs = { lhs, "s" },
    rhs = { rhs, { "s", "f" } },
    opts = { opts, "t", true },
  }

  opts = vim.deepcopy(opts) or {}
  local is_rhs_luaref = type(rhs) == "function"
  mode = type(mode) == "string" and { mode } or mode

  if is_rhs_luaref and opts.expr and opts.replace_keycodes ~= false then
    local user_rhs = rhs
    rhs = function()
      return api.nvim_replace_termcodes(user_rhs(), true, true, true)
    end
  end
  -- clear replace_keycodes from opts table
  opts.replace_keycodes = nil

  if opts.remap == nil then
    -- default remap value is false
    opts.noremap = true
  else
    -- remaps behavior is opposite of noremap option.
    opts.noremap = not opts.remap
    opts.remap = nil
  end

  if is_rhs_luaref then
    opts.callback = rhs
    rhs = ""
  end

  if opts.buffer then
    local bufnr = opts.buffer == true and 0 or opts.buffer
    opts.buffer = nil
    for _, m in ipairs(mode) do
      api.nvim_buf_set_keymap(bufnr, m, lhs, rhs, opts)
    end
  else
    opts.buffer = nil
    for _, m in ipairs(mode) do
      api.nvim_set_keymap(m, lhs, rhs, opts)
    end
  end
end

function keymap.del(modes, lhs, opts)
  vim.validate {
    mode = { modes, { "s", "t" } },
    lhs = { lhs, "s" },
    opts = { opts, "t", true },
  }

  opts = opts or {}
  modes = type(modes) == "string" and { modes } or modes

  local buffer = false
  if opts.buffer ~= nil then
    buffer = opts.buffer == true and 0 or opts.buffer
    opts.buffer = nil
  end

  if buffer == false then
    for _, mode in ipairs(modes) do
      api.nvim_del_keymap(mode, lhs)
    end
  else
    for _, mode in ipairs(modes) do
      api.nvim_buf_del_keymap(buffer, mode, lhs)
    end
  end
end

return { keymap = keymap }

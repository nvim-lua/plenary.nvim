local lookups = {
  autocmd = "autocmds",
  augroup = "autocmds",
  keymap = "keymap",
}

local groups = {
  autocmds = { supported = vim.api.nvim_create_autocmd ~= nil },
  keymap = { supported = vim.keymap ~= nil },
}

return setmetatable({}, {
  __index = function(t, k)
    local group = lookups[k]
    if not group then
      return
    end

    local info = groups[group]

    local compat_suffix = info.supported and "" or "_compat"
    local mod = require("plenary.nvim." .. group .. compat_suffix)

    t[k] = mod[k]
    return t[k]
  end,
})

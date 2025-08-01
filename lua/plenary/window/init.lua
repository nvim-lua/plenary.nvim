---@class PlenaryWindow
local window = {}

---@param win_id integer
---@param force? boolean
window.try_close = function(win_id, force)
  if force == nil then
    force = true
  end

  pcall(vim.api.nvim_win_close, win_id, force)
end

---@param parent_win_id integer
---@param child_win_id integer
window.close_related_win = function(parent_win_id, child_win_id)
  window.try_close(parent_win_id, true)
  window.try_close(child_win_id, true)
end

return window

---@class PlenaryReload
local reload = {}

---@param module_name string
---@param starts_with_only? boolean
reload.reload_module = function(module_name, starts_with_only)
  -- Default to starts with only
  if starts_with_only == nil then
    starts_with_only = true
  end

  -- TODO: Might need to handle cpath / compiled lua packages? Not sure.
  local matcher
  if not starts_with_only then
    ---@param pack string
    ---@return integer?
    matcher = function(pack)
      return string.find(pack, module_name, 1, true)
    end
  else
    local module_name_pattern = vim.pesc(module_name)
    ---@param pack string
    ---@return integer?
    matcher = function(pack)
      return string.find(pack, "^" .. module_name_pattern)
    end
  end

  -- Handle impatient.nvim automatically.
  ---@diagnostic disable-next-line: undefined-field
  local luacache = (_G.__luacache or {}).cache

  for pack, _ in pairs(package.loaded) do
    if matcher(pack) then
      package.loaded[pack] = nil

      if luacache then
        luacache[pack] = nil
      end
    end
  end
end

return reload

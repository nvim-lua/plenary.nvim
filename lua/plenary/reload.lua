local reload = {}

reload.reload_module = function(module_name, starts_with_only)
  -- TODO: Might need to handle cpath / compiled lua packages? Not sure.
  local matcher
  if not starts_with_only then
    matcher = function(pack)
      return string.find(pack, module_name, 1, true)
    end
  else
    matcher = function(pack)
      return string.find(pack, "^" .. module_name)
    end
  end

  -- Handle impatient.nvim automatically.
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

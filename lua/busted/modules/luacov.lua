return function()
  -- Function to initialize luacov if available
  local loadLuaCov = function()
    local result, luacov = pcall(require, 'luacov.runner')

    if not result then
      return nil, 'LuaCov not found on the system, try running without --coverage option, or install LuaCov first'
    end

    -- call it to start
    luacov()

    -- exclude busted files
    table.insert(luacov.configuration.exclude, 'busted_bootstrap$')
    table.insert(luacov.configuration.exclude, 'busted%.')
    table.insert(luacov.configuration.exclude, 'luassert%.')
    table.insert(luacov.configuration.exclude, 'say%.')
    table.insert(luacov.configuration.exclude, 'pl%.')
    return true
  end

  return loadLuaCov
end

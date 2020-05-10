local tablex = require 'pl.tablex'

return function()
  -- Function to load the .busted configuration file if available
  local loadBustedConfigurationFile = function(configFile, config, defaults)
    if type(configFile) ~= 'table' then
      return nil, '.busted file does not return a table.'
    end

    defaults = defaults or {}
    local run = config.run or defaults.run

    if run and run ~= '' then
      local runConfig = configFile[run]

      if type(runConfig) == 'table' then
        config = tablex.merge(runConfig, config, true)
      else
        return nil, 'Task `' .. run .. '` not found, or not a table.'
      end
    elseif type(configFile.default) == 'table' then
      config = tablex.merge(configFile.default, config, true)
    end

    if type(configFile._all) == 'table' then
      config = tablex.merge(configFile._all, config, true)
    end

    config = tablex.merge(defaults, config, true)

    return config
  end

  return loadBustedConfigurationFile
end

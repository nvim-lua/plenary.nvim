local i = require('plenary.iterators')
local f = require('plenary.functional')

local config = {}

local Schema = {}

Schema.__index = Schema

function Schema.new(schema)
  return setmetatable(schema, Schema)
end

function Schema:validate()
end

---validate the config provided by the user
---@param user_config table
function Schema:validate_config(user_config)
  for k, v in pairs(user_config) do
    if self[k] == nil then
      error(string.format("Invalid configuration field '%s'", k))
    else
      if getmetatable(self[k]) == Schema then
        self[k]:validate_config(v)
      else
        vim.validate {
          [k] = { v, self[k].type },
        }
      end
    end
  end
end

---Merge the schema with the user config. Will also validate the user config
---@param user_config table
---@return table
function Schema:merge(user_config)
  user_config = user_config or {}

  self:validate_config(user_config)

  local new_config = {}
  for k, v in pairs(self) do
    if getmetatable(v) == Schema then
      new_config[k] = v:merge(user_config[k])
    elseif user_config[k] ~= nil then
      if v.deep_extend then
        local d = v.default
        new_config[k] = vim.tbl_deep_extend('force', d, user_config[k])
      else
        new_config[k] = user_config[k]
      end
    else
      new_config[k] = v.default
    end
  end

  return new_config
end

---Gets the descriptions
---@return Iterator
function Schema:descriptions()
  return self:into_iter()
    :map(function(...)
      local args = {...}
      local description = table.remove(args).description
      return {
        keys = args,
        description = description,
      }
    end)
end

---@return Iterator
function Schema:into_iter()
  return i.iter(self)
    :map(function(k, v)
      if getmetatable(v) == Schema then
        return v:into_iter():map(function(...)
          return k, ...
        end)
      else
        return k, v
      end
    end)
    :flatten()
end

config.Schema = Schema.new

return config

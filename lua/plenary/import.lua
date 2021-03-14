local function validate_opts(opts)
  vim.validate {
    to_import = {
      opts[1],
      function(to_import)
        return type(to_import) == "nil" or type(to_import) == "string"
      end,
      'nil or string',
    },
    from = {
      opts.from,
      function(from)
        return type(from) == "table" or type(from) == "string"
      end,
      'table or string'
    },
  }

  if opts.fresh then
    vim.validate {
      fresh = {opts.fresh, 'boolean'}
    }
  end

  if opts.into then
    vim.validate {
      into = {
        opts.into,
        function(into)
          return type(into) == "function" or type(into) == "number"
        end,
        'number or string',
      }
    }
  end
end

local function import(opts)
  opts = opts or {}

  validate_opts(opts)

  local to_import = opts[1]

  local env = opts.fresh and {} or getfenv(2)

  local exports
  if type(opts.from) == "table" then
    exports = opts.from
  else
    exports = require(opts.from)
  end

  if to_import == "*" then
    for name, export in pairs(exports) do
      if opts.override == false then
        assert(not env[name], "Overriding something with name " .. name)
      end
      env[name] = export
    end
  elseif type(to_import) == "string" then
    if opts.override == false then
      assert(not env[to_import], "Overriding something with name " .. to_import)
    end
    env[to_import] = exports[to_import]
  end

  if opts.as then
    env[opts.as] = exports
  end

  setfenv(opts.into or 2, env)
end

return import

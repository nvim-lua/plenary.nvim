local tbl = require('plenary.tbl')

local function method_resolver(traits, key)
  for _, trait in ipairs(traits) do
    local res = rawget(trait, key)
    if res then
      return res
    end
  end
end

local function extends_are_present(struct, extends)
  for _, trait in ipairs(extends) do
    if not struct.__traits[trait] then
      error("The trait " .. trait .. " was not found", 2)
    end
  end
end

local function has_all_methods(methods, trait)
  for method, is_not_default in pairs(trait) do
    if is_not_default == true then
      assert(methods[method], "You did not provide the method " .. method)
    end
  end
end

local function struct(opts)
  local t = {}

  local struct_mt = opts.mt or {}

  local init = opts.__init

  local struct_factory = {}

  struct_factory.__call = function(_, ...)
    return setmetatable(init(...) or {}, struct_mt)
  end

  t.__traits = {}

  if struct_mt.__index == nil then
    struct_mt.__index = function(_, k)
      return rawget(t, k) or method_resolver(t.__traits, k)
    end
  end

  return setmetatable(t, struct_factory)
end

local trait_mt = {}
trait_mt.__index = function(trait, k)
  return function()
    rawset(rawget(trait, "methods"), k, true)
  end
end
trait_mt.__newindex = function(trait, k, v)
  rawset(rawget(trait, "methods"), k, v)
end

local function trait(extends)
  extends = extends or {}
  return setmetatable({extends = extends, methods = {}}, trait_mt)
end

local function impl(trait, struct_factory, methods)
  if trait.extends then
    extends_are_present(struct_factory.__traits, trait.extends)
  end
  has_all_methods(methods, trait.methods)
  local combined = vim.tbl_extend("force", trait.methods, methods)
  -- dump(combined)
  table.insert(struct_factory.__traits, combined)
end

return {
  struct = struct,
  trait = trait,
  impl = impl,
}

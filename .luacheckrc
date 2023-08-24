-- Rerun tests only if their modification time changed.
cache = true

std = luajit
codes = true

self = false

-- Glorious list of warnings: https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {
  "212", -- Unused argument, In the case of callback function, _arg_name is easier to understand than _, so this option is set to off.
  "122", -- Indirectly setting a readonly global
}

globals = {
  "_",
  "_PlenaryLeafTable",
  "_PlenaryBustedOldAssert",
  "_AssociatedBufs",
}

-- Global objects defined by the C code
read_globals = {
  "vim",
}

exclude_files = {
  "lua/plenary/profile/lua_profiler.lua",
  "lua/plenary/profile/memory_profiler.lua",
  "lua/plenary/async_lib/*.lua",
}

files = {
  ["lua/plenary/busted.lua"] = {
    globals = {
      "describe",
      "it",
      "pending",
      "before_each",
      "after_each",
      "clear",
      "assert",
      "print",
    },
  },
  ["lua/plenary/async/init.lua"] = {
    globals = {
      "a",
    },
  },
  ["lua/plenary/async/tests.lua"] = {
    globals = {
      "describe",
      "it",
      "pending",
      "before_each",
      "after_each",
    },
  },
}

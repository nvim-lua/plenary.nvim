# plenary.nvim

All the lua functions I don't want to write twice.

> plenary:
>
>     full; complete; entire; absolute; unqualified.

Note that this library is useless outside of Neovim since it requires Neovim functions. It should be usable with any recent version of Neovim though.


## Modules

### plenary.path

A Lua module that implements a bunch of the things from `pathlib` from Python, so that paths are easy to work with.

### plenary.context_manager

Implements `with` and `open` just like in Python. For example:

```lua
local with = context_manager.with
local open = context_manager.open

local result = with(open("README.md"), function(reader)
  return reader:read()
end)

assert(result == "# plenary.nvim")
```

### plenary.popup

`popup_*` clone of Vim's commands. If it gets good enough, will submit PR to Neovim and write C wrappers
to provide compatibility layer for Neovim.

Status: WIP

### plenary.window

Window helper functions to wrap some of the more difficult cases. Particularly for floating windows.

Status: WIP

### plenary.test_harness

See test files in `./tests/plenary/`. For example

```lua
local lu = require("luaunit")

local Path = require("plenary.path")
local test_harness = require("plenary.test_harness")

TestPath = {}

function TestPath:testReadme()
    local p = Path:new("README.md")

    lu.assertEquals(p.raw, "README.md")
end

function TestPath:testAbsolute()
    local p = Path:new("README.md")

    lu.assertEquals(p:absolute(), vim.fn.fnamemodify("README.md", ":p"))
end


test_harness:run()
```

Running the command:

```
$ nvim -c "luafile ./tests/plenary/path_spec.lua"
```

Results in a buffer
```
  2 Ran 2 tests in 0.000 seconds, 2 successes, 0 failures
  2 OK
```

This is awesome because it uses the vim lua APi in the tests and in the code! Which is always a hassle when
writing Lua plugins for Neovim. This makes it possible to actually write tests and get the results

I will make the test harness a little nicer to use in the future, but that's the general idea.

### Bundled with:

Currently comes bundled with (or slightly modified):
- luaunit: https://github.com/bluebird75/luaunit -> Used for unit testing

### And more to come :)

- [ ] Foating window wrappers
- [ ] Easy border windows to any floating window
- [ ] ...

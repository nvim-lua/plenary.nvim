# plenary.nvim

All the lua functions I don't want to write twice.

> plenary:
>
>     full; complete; entire; absolute; unqualified.

Note that this library is useless outside of Neovim since it requires Neovim functions. It should be usable with any recent version of Neovim though.

## Installation

```vim
" Requied plugin for job management in Lua
Plug 'tjdevries/luvjob.nvim'
Plug 'tjdevries/plenary.nvim'
```

## Modules

- `plenary.path`
- `plenary.context_manager`
- `plenary.neorocks`
- `plenary.test_harness`

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

### plenary.neorocks

Install lua packages with `luarocks`!

Include the following somewhere in your configuration (either heredoc or sourced lua file):

```lua
local neorocks = require("plenary.neorocks")

-- This will run a one-time setup to install hererocks and other required packages.
-- After running this, you should be able to install anything that you can install via luarocks.
neorocks.setup_hererocks()

-- ensure_installed(package_name, lua_name, headless)
-- Only installs if currently not installed.
--
--   package_name : str             - Name of the package for luarocks
--   lua_name     : (optional) str  - Name of the package that you can require. Used to determine if we have it installed already (not from luarocks)
--   headless     : (optional) bool - Whether to display in a floating window or via prints. Recommended to use `true` when in your configs
neorocks.ensure_installed('penlight', 'pl', true)
neorocks.ensure_installed('lua-cjson', 'cjson', true)
```

Inspiration: https://github.com/theHamsta/nvim_rocks . However, I've used quite a different end goal (following XDG_CONFIG standards, using `package.path` and `package.cpath` to load the packages and a different strategy of loading).


### plenary.test_harness

Supports both `busted` and `luaunit` style testing.

#### Busted

See test files in `./tests/plenary/bu`.

Add the following line to the beginning of your test file:

```lua
require('plenary.test_harness'):setup_busted()
```

And then you can run your tests from command line by doing:

```
-> nvim --headless -c 'lua require("plenary.test_harness"):test_directory("busted", "./tests/plenary/bu/", true)'
Loading Tests For:  /home/tj/plugins/plenary.nvim/tests/plenary/bu/uses_nvim_spec.lua+
1 success / 0 failures / 0 errors / 0 pending : 0.000263 seconds
Loading Tests For:  /home/tj/plugins/plenary.nvim/tests/plenary/bu/simple_busted_spec.lua+
1 success / 0 failures / 0 errors / 0 pending : 0.000255 seconds%
```

OR you can run from within Neovim (in a new nvim instance, so you don't need to worry about hot reloading or anyything like that)

```vim
lua require("plenary.test_harness"):test_directory("busted", "./tests/plenary/bu/")
```

#### LuaUnit

See test files in `./tests/plenary/lu`. For example

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
```

Running the command:

```
$ nvim --headless -c 'lua require("plenary.test_harness"):test_directory("luaunit", "./tests/plenary/lu/", true)'
```

This is awesome because it uses the vim lua APi in the tests and in the code! Which is always a hassle when
writing Lua plugins for Neovim. This makes it possible to actually write tests and get the results

I will make the test harness a little nicer to use in the future, but that's the general idea.


### plenary.popup

`popup_*` clone of Vim's commands. If it gets good enough, will submit PR to Neovim and write C wrappers
to provide compatibility layer for Neovim.

Status: WIP

### plenary.window

Window helper functions to wrap some of the more difficult cases. Particularly for floating windows.

Status: WIP


### Troubleshooting

If you're having trouble / things are hanging / other problems:

```
$ export DEBUG_PLENARY=true
```

This will enable debuggin for the plugin.

### Bundled with:

Currently comes bundled with slightly modified versions of:
- luaunit: https://github.com/bluebird75/luaunit -> Used for unit testing
- busted: Unit testing library

### And more to come :)

- [ ] Foating window wrappers
- [ ] Easy border windows to any floating window
- [ ] ...

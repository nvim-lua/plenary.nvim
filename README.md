# plenary.nvim

All the lua functions I don't want to write twice.

> plenary:
>
>     full; complete; entire; absolute; unqualified.

Note that this library is useless outside of Neovim since it requires Neovim functions. It should be usable with any recent version of Neovim though.

At the moment, it is very much in pre-alpha :smile: Expect changes to the way some functions are structured. I'm hoping to finish some document generators to provide better documentation for people to use and consume and then at some point we'll stabilize on a few more stable APIs.

## Installation

```vim
Plug 'nvim-lua/plenary.nvim'
```

## Modules

- `plenary.path`
- `plenary.context_manager`
- `plenary.test_harness`
- `plenary.neorocks` (This may move to packer.nvim, but I have added some improvements to use it more as a library.)

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

### plenary.neorocks

Install lua packages with `luarocks`!

Include the following somewhere in your configuration (either heredoc or sourced lua file):

```lua
local neorocks = require("plenary.neorocks")

-- Installs neorocks if necessary and then installs the package you need.
--  Is not synchronous, so should be called from Neovim's command line most likely.
neorocks.install('penlight', 'pl')

-- ensure_installed(package_name, lua_name, headless)
-- Only installs if currently not installed.
--
--   package_name : str             - Name of the package for luarocks
--   lua_name     : (optional) str  - Name of the package that you can require. Used to determine if we have it installed already (not from luarocks)
neorocks.ensure_installed('penlight', 'pl')
neorocks.ensure_installed('lua-cjson', 'cjson')
```

Inspiration: https://github.com/theHamsta/nvim_rocks . However, I've used quite a different end goal (following XDG_CONFIG standards, using `package.path` and `package.cpath` to load the packages and a different strategy of loading).


### Bundled with:

Currently comes bundled with slightly modified versions of:
- luaunit: https://github.com/bluebird75/luaunit -> Used for unit testing
- busted: Unit testing library

### And more to come :)

- [ ] Floating window wrappers
- [ ] Easy border windows to any floating window



### Used by:

- [express_line.nvim](https://github.com/tjdevries/express_line.nvim)
- [apyrori.nvim](https://github.com/tjdevries/apyrori.nvim)
- [nlua.nvim](https://github.com/tjdevries/nlua.nvim)
- (TODO) [popup.nvim](https://github.com/nvim-lua/popup.nvim)
- (TODO) [telescope.nvim](https://github.com/nvim-lua/telescope.nvim)

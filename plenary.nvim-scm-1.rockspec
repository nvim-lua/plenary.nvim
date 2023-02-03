local _MODREV, _SPECREV = 'scm', '-1'
rockspec_format = "3.0"
package = 'plenary.nvim'
version = _MODREV .. _SPECREV

description = {
   summary = 'lua functions you don\'t want to write ',
   labels = { "neovim" },
   detailed = [[
      plenary: full; complete; entire; absolute; unqualified. All the lua functions I don't want to write twice.
   ]],
   homepage = 'http://github.com/nvim-lua/plenary.nvim',
   license = 'MIT/X11',
}

dependencies = {
   'lua >= 5.1, < 5.4',
   'luassert'
}

source = {
   url = 'git://github.com/nvim-lua/plenary.nvim',
}

build = {
   type = 'builtin',
   copy_directories = {
     'data',
     'plugin'
   }
}
test = {
  type = "command",
  command = "make test"
}

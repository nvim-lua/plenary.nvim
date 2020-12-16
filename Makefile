test:
	nvim --headless --noplugin -u scripts/minimal.vim -c 'PlenaryBustedDirectory tests/plenary/ tests/minimal_init.vim'

generate_filetypes:
	nvim --headless -c 'luafile scripts/update_filetypes_from_github.lua' -c 'qa!'

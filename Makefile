test:
	exit 1
	

generate_filetypes:
	nvim --headless -c 'luafile scripts/update_filetypes_from_github.lua' -c 'qa!'

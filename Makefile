.PHONY: test busted generate_filetypes lint

test:
	nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim'}"

busted:
	nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedFile tests/plenary/simple_busted_spec.lua {minimal_init = 'tests/minimal_init.vim', output_format = 'compact'}"

generate_filetypes:
	nvim --headless -c 'luafile scripts/update_filetypes_from_github.lua' -c 'qa!'

lint:
	luacheck lua/plenary

.PHONY: test generate_filetypes lint luarocks_upload test_luarocks_install
test:
	nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim', sequential = true}"

generate_filetypes:
	nvim --headless -c 'luafile scripts/update_filetypes_from_github.lua' -c 'qa!'

generate_luassert_types:
	nvim --headless -c 'luafile scripts/generate_luassert_types.lua' -c 'qa!'

lint:
	luacheck lua/plenary

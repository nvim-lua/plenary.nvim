test:
	nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory tests/plenary/ {minimal_init='tests/minimal_init.vim'}"

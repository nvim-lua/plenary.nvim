export PATH := build:$(PATH)

test:
	nvim --headless --noplugin -u scripts/minimal.vim -c 'PlenaryBustedDirectory tests/plenary/ tests/minimal_init.vim'

appimage:
	mkdir build -p
	wget https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
	chmod +x nvim.appimage
	mv nvim.appimage ./build/nvim
	nvim --headless --noplugin -u scripts/minimal.vim -c 'PlenaryBustedDirectory tests/plenary/ tests/minimal_init.vim'


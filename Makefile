test:
	nvim --headless -c 'lua require("plenary.test_harness"):test_directory("luaunit", "./tests/plenary/lu/")'
	nvim --headless -c 'lua require("plenary.test_harness"):test_directory("busted", "./tests/plenary/bu/")'

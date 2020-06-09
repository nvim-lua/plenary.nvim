
return {
  -- Is run in `--headless` mode.
  is_headless = (#vim.fn.nvim_list_uis() == 0)
}

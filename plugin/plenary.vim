command! -nargs=+ -complete=file PlenaryBusted
      \ lua require('plenary.test_harness').test_path_command("<args>")

command! -nargs=+ -complete=file PlenaryBustedFile
      \ lua require('plenary.test_harness').test_path_command("<args>")

command! -nargs=+ -complete=dir PlenaryBustedDirectory
      \ lua require('plenary.test_harness').test_path_command("<args>")

nnoremap <Plug>PlenaryTestFile :lua require('plenary.test_harness').test_directory(vim.fn.expand("%:p"))<CR>

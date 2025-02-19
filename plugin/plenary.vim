
" Create command for running busted
command! -nargs=+ -complete=file PlenaryBustedFile
      \ lua require('plenary.test_harness').test_file_command([[<args>]])

command! -nargs=+ -complete=file PlenaryBustedDirectory
      \ lua require('plenary.test_harness').test_directory_command([[<args>]])

nnoremap <Plug>PlenaryTestFile :lua require('plenary.test_harness').test_file(vim.fn.expand("%:p"))<CR>

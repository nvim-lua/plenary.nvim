require('plenary.test_harness'):setup_busted()

describe('simple nvim test', function()
  it('should work', function()
    vim.cmd("let g:val = v:true")
  end)
end)

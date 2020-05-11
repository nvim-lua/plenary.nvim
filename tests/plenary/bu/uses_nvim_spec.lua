require('plenary.test_harness'):setup_busted()

describe('simple nvim test', function()
  it('should work', function()
    vim.cmd("echo 'hello'")
  end)
end)

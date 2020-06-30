package.loaded['luvjob'] = nil

local bufnr = 463

local luvjob = require('luvjob')

local get_status = function(job_id)
  return vim.fn.jobwait({job_id}, 0)[1]
end


local on_output = function(err, data)
  vim.api.nvim_get_mode()

  if err then
    return
  end

  if data == nil then
    return
  end

  -- Get rid of pesky \r
  data = data:gsub("\r", "")

  local line, start, found_newline
  while true do
    start = string.find(data, "\n") or #data
    found_newline = string.find(data, "\n")

    line = string.sub(data, 1, start)
    data = string.sub(data, start + 1, -1)

    line = line:gsub("\r", "")
    line = line:gsub("\n", "")

    -- results[#results] = (results[#results] or '') .. line
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {
      (vim.api.nvim_buf_get_lines(bufnr, -1, -1, false)[1] or '') .. line
    })

    if found_newline then
      -- table.insert(results, '')
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {''})
    else
      break
    end
  end
end

runner = function()
  -- local job_id = vim.fn.termopen("wget https://google.com -o ~/Downloads/tmp.html")
  -- local job_id = vim.fn.termopen("sleep 100m")
  local j = luvjob:new({
    command = "bash",
    -- args = {"-c", "wget https://google.com -o ~/Downloads/tmp.html"},
    args = {"-c", "echo 'hello world'; sleep 2; echo 'done'"},
    on_stdout = on_output,
    on_stderr = on_output,
  })

  local next_j = luvjob:new({
    command = "bash",
    -- args = {"-c", "wget https://google.com -o ~/Downloads/tmp.html"},
    args = {"-c", "echo 'second thing'; sleep 2; echo 'done part 2'"},
    on_stdout = on_output,
    on_stderr = on_output,
  })

  return luvjob.chain(j, next_j)

  -- vim.wait(
  --   1000,
  --   function()
  --     status = get_status(job_id)

  --     vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { string.format("Status: %s", status) })
  --   end,
  --   1
  -- )
end

if false then
  print(runner())
  vim.wait(5000, function() return require('luvjob').chain_status(1) end)
end

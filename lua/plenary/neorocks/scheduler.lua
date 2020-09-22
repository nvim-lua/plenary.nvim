local scheduler = {}

function scheduler:new()
  return setmetatable({
    items = {},

    in_progress = nil,
  }, {
    __index = self,
  })
end

function scheduler:insert(item)
  if not item then
    return item
  end

  table.insert(self.items, item)

  if not self.in_progress then
    self:_run_item(item)
  else
    self:_chain_item(item)
  end

  return item
end

function scheduler:_run_item(item)
  self.in_progress = true
  item:add_on_exit_callback(function()
    self.in_progress = false
  end)

  item:start()
end

function scheduler:_chain_item(item)
  self.items[#self.items - 1]:add_on_exit_callback(vim.schedule_wrap(function()
    self:_run_item(item)
  end))
end

return scheduler

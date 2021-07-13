local Context = {}
Context.__index = Context

function Context.new()
  return setmetatable({
    canceled = false,
  }, Context)
end

function Context:set_cancel(canceller, cancel_handle)
  assert(type(canceller) == "function")
  assert(type(cancel_handle) == "userdata")

  self.canceller = canceller
  self.cancel_handle = cancel_handle
end

function Context:reset_cancel()
  self.canceller = nil
  self.cancel_handle = nil
end

function Context:cancel()
  if self.canceled == true then return end

  self.canceled = true

  if self.canceller ~= nil and self.cancel_handle ~= nil then
    self.canceller(self.cancel_handle)
  end
end

return Context

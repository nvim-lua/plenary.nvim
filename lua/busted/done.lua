local M = {}

-- adds tokens to the current wait list, does not change order/unordered
M.wait = function(self, ...)
  local tlist = { ... }

  for _, token in ipairs(tlist) do
    if type(token) ~= 'string' then
      error('Wait tokens must be strings. Got '..type(token), 2)
    end
    table.insert(self.tokens, token)
  end
end

-- set list as unordered, adds tokens to current wait list
M.wait_unordered = function(self, ...)
  self.ordered = false
  self:wait(...)
end

-- set list as ordered, adds tokens to current wait list
M.wait_ordered = function(self, ...)
  self.ordered = true
  self:wait(...)
end

-- generates a message listing tokens received/open
M.tokenlist = function(self)
  local list

  if #self.tokens_done == 0 then
    list = 'No tokens received.'
  else
    list = 'Tokens received ('..tostring(#self.tokens_done)..')'
    local s = ': '

    for _,t in ipairs(self.tokens_done) do
      list = list .. s .. '\''..t..'\''
      s = ', '
    end

    list = list .. '.'
  end

  if #self.tokens == 0 then
    list = list .. ' No more tokens expected.'
  else
    list = list .. ' Tokens not received ('..tostring(#self.tokens)..')'
    local s = ': '

    for _, t in ipairs(self.tokens) do
      list = list .. s .. '\''..t..'\''
      s = ', '
    end

    list = list .. '.'
  end

  return list
end

-- marks a token as completed, checks for ordered/unordered, checks for completeness
M.done = function(self, ...) self:_done(...) end  -- extra wrapper for same error level constant as __call method
M._done = function(self, token)
  if token then
    if type(token) ~= 'string' then
      error('Wait tokens must be strings. Got '..type(token), 3)
    end

    if self.ordered then
      if self.tokens[1] == token then
        table.remove(self.tokens, 1)
        table.insert(self.tokens_done, token)
      else
        if self.tokens[1] then
          error(('Bad token, expected \'%s\' got \'%s\'. %s'):format(self.tokens[1], token, self:tokenlist()), 3)
        else
          error(('Bad token (no more tokens expected) got \'%s\'. %s'):format(token, self:tokenlist()), 3)
        end
      end
    else
      -- unordered
      for i, t in ipairs(self.tokens) do
        if t == token then
          table.remove(self.tokens, i)
          table.insert(self.tokens_done, token)
          token = nil
          break
        end
      end

      if token then
        error(('Unknown token \'%s\'. %s'):format(token, self:tokenlist()), 3)
      end
    end
  end
  if not next(self.tokens) then
    -- no more tokens, so we're really done...
    self.done_cb()
  end
end


-- wraps a done callback into a done-object supporting tokens to sign-off
M.new = function(done_callback)
  local obj = {
    tokens = {},
    tokens_done = {},
    done_cb = done_callback,
    ordered = true,  -- default for sign off of tokens
  }

  return setmetatable( obj, {
    __call = function(self, ...)
      self:_done(...)
    end,
    __index = M,
  })
end

return M

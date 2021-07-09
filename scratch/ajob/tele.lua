
local finder = {}

function finder:find()
  for line in line_pipe:iter() do
    self.on_lines(line)
  end

  self.on_complete()
end

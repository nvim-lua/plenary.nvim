local ansi_color_table = {
   cyan = 36,
   magenta = 35,
   yellow = 33,
   green = 32,
   red = 31,
}

local color_string = function(color, str)
   if not is_headless then
      -- This is never being called
      return str
   end

   return string.format("%s[%sm%s%s[%sm",
   string.char(27),
   ansi_color_table[color] or 0,
   str,
   string.char(27),
   0
   )
end

local successDot = color_string('green', '●')
local failureDot = color_string('red', '◼')
local errorDot   = color_string('magenta', '✱')
local pendingDot = color_string('yellow', '◌')

local count = {
   successesCount = 0,
   pendingsCount = 0,
   failuresCount = 0,
   errorsCount = 0,
}

local aggregate_dots = function(countresults, dotcolor)
   for _,_ in pairs(count) do
      
   end
   for i=0, countresults, 1 do
      result_dots = result_dots .. dotcolor
   end
end
local dots_builder = function()

   local result_dots = ""
   for i=0, count.errors, 1 do
      result_dots = result_dots .. errorDot
   end

   for i=0, count.failures, 1 do
      result_dots = result_dots .. failureDot
   end

   for i=0, count.successes, 1 do
      result_dots = result_dots .. successDot
   end

   for i=0, count.pending, 1 do
      result_dots = result_dots .. pendingDot
   end

   return result_dots 
end

describe("Build String", function()
   it("title", function()
      local expected = ""
      assert.is_equal(expected, aggregate_dots(3, successDot))
   end)
end)


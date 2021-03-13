local strings = require('plenary.strings')
local eq = assert.are.same

describe('strings', function()
  describe('strdisplaywidth', function()
    for _, case in ipairs{
      {str = 'abcde', expected = {single = 5, double = 5}},
      -- This space below is a tab (U+0009)
      {str = 'abc	de', expected = {single = 10, double = 10}},
      {str = 'アイウエオ', expected = {single = 10, double = 10}},
      {str = '├─┤', expected = {single = 3, double = 6}},
    } do
      for _, ambiwidth in ipairs{'single', 'double'} do
        local msg = ('ambiwidth = %s, "%s" -> %d'):format(ambiwidth, case.str, case.expected[ambiwidth])
        local original = vim.o.ambiwidth
        vim.o.ambiwidth = ambiwidth
        it('lua: '..msg, function()
          eq(case.expected[ambiwidth], strings.strdisplaywidth(case.str))
        end)
        it('vim: '..msg, function()
          eq(case.expected[ambiwidth], vim.fn.strdisplaywidth(case.str))
        end)
        vim.o.ambiwidth = original
      end
    end
  end)

  describe('strcharpart', function()
    for _, case in ipairs{
      {args = {'abcde', 2}, expected = 'cde'},
      {args = {'abcde', 2, 2}, expected = 'cd'},
      {args = {'アイウエオ', 2, 2}, expected = 'ウエ'},
      {args = {'├───┤', 2, 2}, expected = '──'},
    } do
      local msg = ('("%s", %d, %s) -> "%s"'):format(case.args[1], case.args[2], tostring(case.args[3]), case.expected)
      it('lua: '..msg, function()
        eq(case.expected, strings.strcharpart(case.args[1], case.args[2], case.args[3]))
      end)
      it('vim: '..msg, function()
        if case.args[3] then
          eq(case.expected, vim.fn.strcharpart(case.args[1], case.args[2], case.args[3]))
        else
          eq(case.expected, vim.fn.strcharpart(case.args[1], case.args[2]))
        end
      end)
    end
  end)

  describe('truncate', function()
    for _, case in ipairs{
      {args = {'abcde', 6}, expected = {single = 'abcde', double = 'abcde'}},
      {args = {'abcde', 5}, expected = {single = 'abcde', double = 'abcde'}},
      {args = {'abcde', 4}, expected = {single = 'abc…', double = 'ab…'}},
      {args = {'アイウエオ', 11}, expected = {single = 'アイウエオ', double = 'アイウエオ'}},
      {args = {'アイウエオ', 10}, expected = {single = 'アイウエオ', double = 'アイウエオ'}},
      {args = {'アイウエオ', 9}, expected = {single = 'アイウエ…', double = 'アイウ…'}},
      {args = {'アイウエオ', 8}, expected = {single = 'アイウ…', double = 'アイウ…'}},
      {args = {'├─┤', 7}, expected = {single = '├─┤', double = '├─┤'}},
      {args = {'├─┤', 6}, expected = {single = '├─┤', double = '├─┤'}},
      {args = {'├─┤', 5}, expected = {single = '├─┤', double = '├…'}},
      {args = {'├─┤', 4}, expected = {single = '├─┤', double = '├…'}},
      {args = {'├─┤', 3}, expected = {single = '├─┤', double = '…'}},
      {args = {'├─┤', 2}, expected = {single = '├…', double = '…'}},
    } do
      for _, ambiwidth in ipairs{'single', 'double'} do
        local msg = ('ambiwidth = %s, [%s, %d] -> %s'):format(
          ambiwidth,
          case.args[1],
          case.args[2],
          case.expected[ambiwidth]
        )
        it(msg, function()
          local original = vim.o.ambiwidth
          vim.o.ambiwidth = ambiwidth
          eq(case.expected[ambiwidth], strings.truncate(case.args[1], case.args[2]))
          vim.o.ambiwidth = original
        end)
      end
    end
  end)

  describe('align_str', function()
    for _, case in ipairs{
      {args = {'abcde', 8}, expected = {single = 'abcde   ', double = 'abcde   '}},
      {args = {'アイウ', 8}, expected = {single = 'アイウ  ', double = 'アイウ  '}},
      {args = {'├─┤', 8}, expected = {single = '├─┤     ', double = '├─┤  '}},
      {args = {'abcde', 8, true}, expected = {single = '   abcde', double = '   abcde'}},
      {args = {'アイウ', 8, true}, expected = {single = '  アイウ', double = '  アイウ'}},
      {args = {'├─┤', 8, true}, expected = {single = '     ├─┤', double = '  ├─┤'}},
    } do
      for _, ambiwidth in ipairs{'single', 'double'} do
        local msg = ('ambiwidth = %s, [%s, %d, %s] -> "%s"'):format(
          ambiwidth,
          case.args[1],
          case.args[2],
          tostring(case.args[3]),
          case.expected[ambiwidth]
        )
        it(msg, function()
          local original = vim.o.ambiwidth
          vim.o.ambiwidth = ambiwidth
          eq(case.expected[ambiwidth], strings.align_str(case.args[1], case.args[2], case.args[3]))
          vim.o.ambiwidth = original
        end)
      end
    end
  end)
end)

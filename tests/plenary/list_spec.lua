local List = require("plenary.list")

describe('List', function()
  it('should be detected as a list by vim.tbl_islist()', function()
    local l = List {1, 2, 3}
    assert(vim.tbl_islist(l))
  end)
  it('should be equal if all elements are equal', function()
    local l1 = List{1, 2, 3}
    local l2 = List{1, 2, 3}
    local l3 = List{4, 5, 6}
    assert(l1 == l2)
    assert(l1 ~= l3)
  end)
  it('can be concatenated to other list-like tables', function()
    local l1 = List{1, 2, 3} .. {4}
    assert.are.equal(l1, List{1, 2, 3, 4})
  end)
end)

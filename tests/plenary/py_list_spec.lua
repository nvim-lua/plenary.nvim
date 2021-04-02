local List = require("plenary.collections.py_list")

describe('List', function()
  it('should be detected as a list by vim.tbl_islist()', function()
    local l = List {1, 2, 3}
    assert(vim.tbl_islist(l))
  end)
  it('should be equal if all elements are equal', function()
    local l1 = List {1, 2, 3}
    local l2 = List {1, 2, 3}
    local l3 = List {4, 5, 6}
    assert.are.equal(l1, l2)
    assert.are_not.equal(l1, l3)
  end)
  it('can be concatenated to other list-like tables', function()
    local l1 = List {1, 2, 3} .. {4}
    assert.are.equal(l1, List {1, 2, 3, 4})
  end)
  it('can create a copy of itself with equal elements', function()
    local l1 = List {1, 2, 3}
    local l2 = l1:copy()
    assert.are.equal(l1, l2)
  end)
  it('can create a slice between two indices', function()
    local l1 = List {1, 2, 3, 4}
    local l2 = l1:slice(2, 4)
    assert.are.equal(l2, List {2, 3, 4})
  end)
  it('can reverse itself in place', function()
    local l = List {1, 2, 3, 4}
    l:reverse()
    assert.are.equal(l, List {4, 3, 2, 1})
  end)
  it('can append elements to itself', function()
    local l = List {1, 2, 3}
    l:append(4)
    assert.are.equal(l, List {1, 2, 3, 4})
  end)
  it('can pop the n-th element from itself (last one by default)', function()
    local l = List {1, 2, 3, 4}
    local n = l:pop()
    assert.are.equal(l, List {1, 2, 3})
    assert.are.equal(n, 4)
  end)
end)

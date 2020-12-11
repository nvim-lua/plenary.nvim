local filetype = require('plenary.filetype')

describe('filetype', function()
  describe('_get_extension', function()
    it('should find stuff with underscores', function()
      assert.are.same('py', filetype._get_extension('__init__.py'))
    end)
  end)

  it('should work for common filetypes, like python', function()
    assert.are.same('python', filetype.detect('__init__.py'))
  end)

  it('should work for common filenames, like makefile', function()
    assert.are.same('make', filetype.detect('Makefile'))
    assert.are.same('make', filetype.detect('makefile'))
  end)

  it('should work for common files, even with .s, like .bashrc', function()
    assert.are.same('sh', filetype.detect('.bashrc'))
  end)

  it('should work fo custom filetypes, like fennel', function()
    assert.are.same('fennel', filetype.detect('init.fnl'))
  end)

  it('shjould work for custom filenames, like PogChamp', function()
    assert.are.same('PogChamp', filetype.detect('showing_twitch_chat.kappa'))
  end)
end)

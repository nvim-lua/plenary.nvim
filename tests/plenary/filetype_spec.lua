local filetype = require('plenary.filetype')

describe('filetype', function()
  describe('_get_extension', function()
    it('should find stuff with underscores', function()
      assert.are.same('py', filetype._get_extension('__init__.py'))
    end)
  end)

  describe('detect_from_extension', function()
    it('should work for md', function()
      assert.are.same('markdown', filetype.detect_from_extension('Readme.md'))
    end)

    it('should work for CMakeList.txt', function()
      assert.are.same('text', filetype.detect_from_extension('CMakeLists.txt'))
    end)
  end)

  describe('detect_from_name', function()
    it('should work for common filenames, like makefile', function()
      assert.are.same('make', filetype.detect_from_name('Makefile'))
      assert.are.same('make', filetype.detect_from_name('makefile'))
    end)

    it('should work for CMakeList.txt', function()
      assert.are.same('cmake', filetype.detect_from_name('CMakeLists.txt'))
    end)
  end)

  describe('detect_from_modeline', function()
    it('should work for modeline 2', function()
      assert.are.same('help', filetype._parse_modeline(' vim:tw=78:ts=8:noet:ft=help:norl:'))
    end)

    it('should return nothing if ft not found in modeline', function()
      assert.are.same('', filetype._parse_modeline('/* vim: set ts=8 sw=4 tw=0 noet : */'))
    end)

    it('should return nothing for random line', function()
      assert.are.same('', filetype._parse_modeline('return filetype'))
    end)
  end)

  describe('detect_from_shebang', function()
    it('should work for shell', function()
      assert.are.same('sh', filetype._parse_shebang('#!/bin/sh'))
    end)

    it('should work for bash', function()
      assert.are.same('bash', filetype._parse_shebang('#!/bin/bash'))
    end)

    it('should work for usr/bin/env shell', function()
      assert.are.same('sh', filetype._parse_shebang('#!/usr/bin/env sh'))
    end)

    it('should work for env shell', function()
      assert.are.same('sh', filetype._parse_shebang('#!/bin/env sh'))
    end)

    it('should work for python', function()
      assert.are.same('python', filetype._parse_shebang('#!/bin/python'))
    end)

    it('should work for /usr/bin/python3', function()
      assert.are.same('python', filetype._parse_shebang('#!/usr/bin/python3'))
    end)

    it('should work for python3', function()
      assert.are.same('python', filetype._parse_shebang('#!/bin/python3'))
    end)

    it('should work for env python', function()
      assert.are.same('python', filetype._parse_shebang('#!/bin/env python'))
    end)

    it('should not work for random line', function()
      assert.are.same('', filetype._parse_shebang('local path = require"plenary.path"'))
    end)
  end)

  describe('detect', function()
    it('should work for common filetypes, like python', function()
      assert.are.same('python', filetype.detect('__init__.py'))
    end)

    it('should work for common filenames, like makefile', function()
      assert.are.same('make', filetype.detect('Makefile'))
      assert.are.same('make', filetype.detect('makefile'))
    end)

    it('should work for CMakeList.txt', function()
      assert.are.same('cmake', filetype.detect('CMakeLists.txt'))
    end)

    it('should work for common files, even with .s, like .bashrc', function()
      assert.are.same('sh', filetype.detect('.bashrc'))
    end)

    it('should work fo custom filetypes, like fennel', function()
      assert.are.same('fennel', filetype.detect('init.fnl'))
    end)

    it('should work for custom filenames, like PogChamp', function()
      assert.are.same('PogChamp', filetype.detect('showing_twitch_chat.kappa'))
    end)
  end)
end)

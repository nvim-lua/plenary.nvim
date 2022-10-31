local context_manager = require "plenary.context_manager"
local debug_utils = require "plenary.debug_utils"
local Path = require "plenary.path"

local with = context_manager.with
local open = context_manager.open

local README_STR_PATH = vim.fn.fnamemodify(debug_utils.sourced_filepath(), ":h:h:h") .. "/README.md"
local README_FIRST_LINE = "# plenary.nvim"

describe("context_manager", function()
  it("works with objects", function()
    local obj_manager = {
      enter = function(self)
        self.result = 10
        return self.result
      end,

      exit = function() end,
    }

    local result = with(obj_manager, function(obj)
      return obj
    end)

    assert.are.same(10, result)
    assert.are.same(obj_manager.result, result)
  end)

  it("works with coroutine", function()
    local co = function()
      coroutine.yield(10)
    end

    local result = with(co, function(obj)
      return obj
    end)

    assert.are.same(10, result)
  end)

  it("does not work with coroutine with extra yields", function()
    local co = function()
      coroutine.yield(10)

      -- Can't yield twice. That'd be bad and wouldn't make any sense.
      coroutine.yield(10)
    end

    assert.has.error_match(function()
      with(co, function(obj)
        return obj
      end)
    end, "Should not yield anymore, otherwise that would make things complicated")
  end)

  it("reads from files with open", function()
    local result = with(open(README_STR_PATH), function(reader)
      return reader:read()
    end)

    assert.are.same(result, README_FIRST_LINE)
  end)

  it("reads from Paths with open", function()
    local p = Path:new(README_STR_PATH)

    local result = with(open(p), function(reader)
      return reader:read()
    end)

    assert.are.same(result, README_FIRST_LINE)
  end)

  it("calls exit on error with objects", function()
    local entered = false
    local exited = false
    local obj_manager = {
      enter = function(self)
        entered = true
      end,

      exit = function(self)
        exited = true
      end,
    }

    assert.has.error_match(function()
      with(obj_manager, function(obj)
        assert(false, "failed in callback")
      end)
    end, "failed in callback")

    assert.is["true"](entered)
    assert.is["true"](exited)
  end)

  it("calls exit on error with coroutines", function()
    local entered = false
    local exited = false
    local co = function()
      entered = true
      coroutine.yield(nil)

      exited = true
    end

    assert.has.error_match(function()
      with(co, function(obj)
        assert(false, "failed in callback")
      end)
    end, "failed in callback")

    assert.is["true"](entered)
    assert.is["true"](exited)
  end)

  it("fails from enter error with objects", function()
    local exited = false
    local obj_manager = {
      enter = function(self)
        assert(false, "failed in enter")
      end,

      exit = function(self)
        exited = true
      end,
    }

    local ran_callback = false
    assert.has.error_match(function()
      with(obj_manager, function(obj)
        ran_callback = true
      end)
    end, "failed in enter")

    assert.is["false"](ran_callback)
    assert.is["false"](exited)
  end)

  it("fails from enter error with coroutines", function()
    local exited = false
    local co = function()
      assert(false, "failed in enter")
      coroutine.yield(nil)

      exited = true
    end

    local ran_callback = false
    assert.has.error_match(function()
      with(co, function(obj)
        ran_callback = true
      end)
    end, "Should have yielded in coroutine.")

    assert.is["false"](ran_callback)
    assert.is["false"](exited)
  end)

  it("fails from exit error with objects", function()
    local entered = false
    local obj_manager = {
      enter = function(self)
        entered = true
      end,

      exit = function(self)
        assert(false, "failed in exit")
      end,
    }

    local ran_callback = false
    assert.has.error_match(function()
      with(obj_manager, function(obj)
        ran_callback = true
      end)
    end, "failed in exit")

    assert.is["true"](entered)
    assert.is["true"](ran_callback)
  end)

  it("fails from exit error with coroutines", function()
    local entered = false
    local co = function()
      entered = true
      coroutine.yield(nil)

      assert(false, "failed in exit")
    end

    local ran_callback = false
    assert.has.error_match(function()
      with(co, function(obj)
        ran_callback = true
      end)
    end, "Should be done")

    assert.is["true"](entered)
    assert.is["true"](ran_callback)
  end)
end)

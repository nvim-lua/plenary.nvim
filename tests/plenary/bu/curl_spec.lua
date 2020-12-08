require('plenary.test_harness'):setup_busted()

local curl = require('plenary.curl')
local incl = function(p, s)
  return (nil ~= string.find(s, p))
end

describe('CURL Wrapper:', function()
  describe('GET', function()
    it('sends and returns object.', function()
      local res = curl.get("https://httpbin.org/get", {
        accept = "application/json"
      })
      assert.are.same("table", type(res)) -- returns a table
      assert.are.same(200, res.status) -- table has response status
    end)

    it('sends encoded URL query params.', function()
      local query = { name = "john Doe", key = "123456" }
      local response = curl.get("https://postman-echo.com/get", {
        query = query
      })

      assert.are.same(200, response.status)
      assert.are.same(query, vim.fn.json_decode(response.body).args)
    end)

    it('downloads files to opts.output synchronously', function()
      local file = "https://media2.giphy.com/media/bEMcuOG3hXVnihvB7x/giphy.gif"
      local loc = "/tmp/giphy2.gif"
      local res = curl.get(file, { output = loc})

      assert.are.same(1, vim.fn.filereadable(loc))
      assert.are.same(200, res.status)
      assert.are.same(0, res.exit)
      vim.fn.delete(loc)
    end)

    it('downloads files to to opts.output asynchronous', function()
      local result = nil
      local file = "https://media2.giphy.com/media/notvalid.gif"
      local loc = "/tmp/notvalid.gif"
      local download = function(url, target)
        return curl.get(url, {
          output = target,
          out = function(res)
            if res.exit == 0 then result = true end
          end})
      end
      download(file, loc)
      assert(not result, "It should fail")
      vim.fn.delete(loc)
    end)

    it('sends with basic-auth as string', function()
      local url = "https://postman-echo.com/basic-auth"
      local auth, res

      auth = "postman:password"
      res = curl.get(url, { auth = auth })
      assert(incl("authenticated.*true", res.body))
      assert.are.same(200, res.status)

      auth = "tami5:123456"
      res = curl.get(url, { auth = auth })
      assert(not incl("authenticated.*true", res.body), "it should fail")
      assert.are.same(401, res.status)
    end)

    it('sends with basic-auth as table', function()
      local url = "https://postman-echo.com/basic-auth"
      local res = curl.get(url, { auth = { postman = "password" } })
      assert(incl("authenticated.*true", res.body))
      assert.are.same(200, res.status)
    end)
  end)
  describe("POST", function()
    it("sends raw string", function()
      local res = curl.post("https://postman-echo.com/post", {
        body = "John Doe"
      })
      assert(incl("John", res.body))
      assert.are.same(200, res.status)
    end)

    it("sends lua table", function()
      local res = curl.post("https://jsonplaceholder.typicode.com/posts", {
        body = {
          title = "Hello World",
          body = "..."
        }
      })
      assert.are.same(201, res.status)
    end)

    it("sends file", function()
      local res = curl.post("https://postman-echo.com/post", {
        body = "./README.md"
      }).body

      assert(incl("plenary.test_harness", res))
    end)

    it("sends and recives json body.", function()
      local json = { title = "New", name = "YORK" }
      local res = curl.post("https://postman-echo.com/post", {
        body = vim.fn.json_encode(json),
        headers = {
          content_type = "application/json"
        }
      }).body
      assert.are.same(json, vim.fn.json_decode(res).json)
    end)
  end)
  describe("PUT", function()
    it("sends changes and get be back the new version.", function()
      local cha = { title = "New Title" }
      local res = curl.put("https://jsonplaceholder.typicode.com/posts/8",{
        body = cha
      })
      assert.are.same(cha.title, vim.fn.json_decode(res.body).title)
      assert.are.same(200, res.status)
    end)
  end)
  describe("PATCH", function()
    it("sends changes and get be back the new version.", function()
      local cha = { title = "New Title" }
      local res = curl.patch("https://jsonplaceholder.typicode.com/posts/8",{
        body = cha
      })
      assert.are.same(cha.title, vim.fn.json_decode(res.body).title)
      assert.are.same(200, res.status)
    end)
  end)
  describe("DELETE", function()
    it("sends delete request", function()
      local res = curl.delete("https://jsonplaceholder.typicode.com/posts/8")
      assert.are.same(200, res.status)
    end)
  end)
  describe("DEPUG", function()
    it("dry_run return the curl command to be ran.", function()
      local res = curl.delete("https://jsonplaceholder.typicode.com/posts/8", {dry_run = true})
      assert(type(res) == "table")
    end)
  end)
end)

require("plenary.async").tests.add_to_env()
local channel = a.control.channel
local eq = assert.are.same
local apcall = a.util.apcall

describe("channel", function()
  describe("oneshot", function()
    a.it("should work when rx is used first", function()
      local tx, rx = channel.oneshot()

      a.run(function()
        local got = rx()

        eq("sent value", got)
      end)

      tx "sent value"
    end)

    a.it("should work when tx is used first", function()
      local tx, rx = channel.oneshot()

      tx "sent value"

      local got = rx()

      eq("sent value", got)
    end)

    a.it("should work with multiple returns", function()
      local tx, rx = channel.oneshot()

      a.run(function()
        local got, got2 = rx()
        eq("sent value", got)
        eq("another sent value", got2)
      end)

      tx("sent value", "another sent value")
    end)

    a.it("should work when sending a falsey value", function()
      local tx, rx = channel.oneshot()

      tx(false)

      local res = rx()
      eq(res, false)

      local stat, ret = apcall(rx)
      eq(stat, false)
      local stat, ret = apcall(rx)
      eq(stat, false)
    end)

    a.it("should work when sending a nil value", function()
      local tx, rx = channel.oneshot()

      tx(nil)

      local res = rx()
      eq(res, nil)

      local stat, ret = apcall(rx)
      eq(stat, false)
      local stat, ret = apcall(rx)
      eq(stat, false)
    end)

    a.it("should error when sending mulitple times", function()
      local tx, rx = channel.oneshot()

      tx()
      local stat = pcall(tx)
      eq(stat, false)
    end)

    a.it("should block receiving multiple times", function()
      local tx, rx = channel.oneshot()
      tx(true)
      rx()
      local stat = apcall(rx)
      eq(stat, false)
    end)
  end)

  describe("mpsc", function()
    a.it("should wait multiple recv before any send", function()
      local sender, receiver = channel.mpsc()

      local expected_count = 10

      a.run(function()
        for i = 1, expected_count do
          a.util.sleep(250)
          sender.send(i)
        end
      end)

      local receive_count = 0
      while receive_count < expected_count do
        receive_count = receive_count + 1
        local i = receiver.recv()
        eq(receive_count, i)
      end
    end)

    a.it("should queues multiple sends before any read", function()
      local sender, receiver = channel.mpsc()

      local counter = 0

      a.run(function()
        counter = counter + 1
        sender.send(10)

        counter = counter + 1
        sender.send(20)
      end)

      a.util.sleep(1000)

      eq(10, receiver.recv())
      eq(20, receiver.recv())
      eq(2, counter)
    end)

    a.it("should queues multiple sends from multiple producers before any read", function()
      local sender, receiver = channel.mpsc()

      local counter = 0

      a.run(function()
        counter = counter + 1
        sender.send(10)

        counter = counter + 1
        sender.send(20)
      end)

      a.run(function()
        counter = counter + 1
        sender.send(30)

        counter = counter + 1
        sender.send(40)
      end)

      a.util.sleep(1000)

      local read_counter = 0
      a.util.block_on(function()
        for _ = 1, 4 do
          receiver.recv()
          read_counter = read_counter + 1
        end
      end, 1000)
      eq(4, counter)
      eq(4, read_counter)
    end)

    a.it("should read only the last value", function()
      local sender, receiver = channel.mpsc()

      local counter = 0

      a.run(function()
        counter = counter + 1
        sender.send(10)

        counter = counter + 1
        sender.send(20)
      end)

      a.util.sleep(1000)

      eq(20, receiver.last())
      eq(2, counter)
    end)
  end)

  describe("counter", function()
    a.it("should work", function()
      local tx, rx = channel.counter()

      tx.send()
      tx.send()
      tx.send()

      local counter = 0

      a.run(function()
        for i = 1, 3 do
          rx.recv()
          counter = counter + 1
        end
      end)

      eq(counter, 3)
    end)

    a.it("should work when getting last", function()
      local tx, rx = channel.counter()

      tx.send()
      tx.send()
      tx.send()

      local counter = 0

      a.run(function()
        rx.last()
        counter = counter + 1
      end)

      eq(counter, 1)
    end)
  end)
end)

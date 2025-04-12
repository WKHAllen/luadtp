local luadtp = require("luadtp")
local testutils = require("test.testutils")

local function testServerServing()
  local server = luadtp.server()
  assert(not server:serving())
  local co = server:start(testutils.host, testutils.portServerServing)
  assert(server:serving())
  print("Server address: ", server:getAddr())

  for _ = 1, 100 do
    testutils.pollNil(co)
  end

  server:stop()
  assert(not server:serving())
  testutils.pollEnd(co)
end

local function testClientConnect()
  local server = luadtp.server()
  local co = server:start(testutils.host, testutils.portClientConnecting)
  print("Server address: ", server:getAddr())
  testutils.pollUntil(co, { eventType = "connect", clientId = 1 })
  print("Client address: ", server:getClientAddr(1))

  testutils.pollUntil(co, { eventType = "disconnect", clientId = 1 })
  server:stop()
  testutils.pollEnd(co)
end

local function testSend()
  local server = luadtp.server()
  local co = server:start(testutils.host, testutils.portSend)
  print("Server address: ", server:getAddr())
  testutils.pollUntil(co, { eventType = "connect", clientId = 1 })

  server:sendAll(testutils.sendMessageFromServer)
  testutils.pollUntilNotNillValue(co, { eventType = "receive", clientId = 1, data = testutils.sendMessageFromClient })

  testutils.pollUntil(co, { eventType = "disconnect", clientId = 1 })
  server:stop()
  testutils.pollEnd(co)
end

local function testLargeSend()
  -- TODO
end

local function testSendingNumerousMessages()
  -- TODO
end

local function testSendingCustomTypes()
  -- TODO
end

local function testMultipleClients()
  -- TODO
end

local function testRemoveClient()
  -- TODO
end

local function testStopServerWhileClientConnected()
  -- TODO
end

local function testExample()
  -- TODO
end

local function test()
  print("Beginning tests")

  print("Testing server serving...")
  testServerServing()
  print("Testing client connecting...")
  testClientConnect()
  print("Testing send...")
  testSend()
  print("Testing large send...")
  testLargeSend()
  print("Testing sending numerous messages...")
  testSendingNumerousMessages()
  print("Testing sending custom types...")
  testSendingCustomTypes()
  print("Testing multiple clients...")
  testMultipleClients()
  print("Testing removing a client...")
  testRemoveClient()
  print("Testing stopping a server while a client is connected...")
  testStopServerWhileClientConnected()
  print("Testing the README example...")
  testExample()

  print("Completed tests")
end

test()

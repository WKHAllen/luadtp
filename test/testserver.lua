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
  testutils.pollUntilNotNilValue(co, { eventType = "receive", clientId = 1, data = testutils.sendMessageFromClient })

  testutils.pollUntil(co, { eventType = "disconnect", clientId = 1 })
  server:stop()
  testutils.pollEnd(co)
end

local function testLargeSend()
  testutils.randomSeed(testutils.portLargeSend)
  local messageFromServer = testutils.randomBytes(math.random(512, 1023))
  local messageFromClient = testutils.randomBytes(math.random(256, 511))
  print("Large server message length: ", #messageFromServer)
  print("Large client message length: ", #messageFromClient)

  local server = luadtp.server()
  local co = server:start(testutils.host, testutils.portLargeSend)
  print("Server address: ", server:getAddr())
  testutils.pollUntil(co, { eventType = "connect", clientId = 1 })

  server:sendAll(messageFromServer)
  testutils.pollUntilNotNilValue(co, { eventType = "receive", clientId = 1, data = messageFromClient })

  testutils.pollUntil(co, { eventType = "disconnect", clientId = 1 })
  server:stop()
  testutils.pollEnd(co)
end

local function testSendingNumerousMessages()
  testutils.randomSeed(testutils.portSendingNumerousMessages)
  local messagesFromServer = testutils.randomNumbers(math.random(64, 127), 0, 65535)
  local messagesFromClient = testutils.randomNumbers(math.random(128, 255), 0, 65535)
  print("Number of server messages: ", #messagesFromServer)
  print("Number of client messages: ", #messagesFromClient)

  local server = luadtp.server()
  local co = server:start(testutils.host, testutils.portSendingNumerousMessages)
  print("Server address: ", server:getAddr())
  testutils.pollUntil(co, { eventType = "connect", clientId = 1 })

  for _, serverMessage in ipairs(messagesFromServer) do
    server:sendAll(serverMessage)
  end
  for _, clientMessage in ipairs(messagesFromClient) do
    testutils.pollUntilNotNilValue(co, { eventType = "receive", clientId = 1, data = clientMessage })
  end

  testutils.pollUntil(co, { eventType = "disconnect", clientId = 1 })
  server:stop()
  testutils.pollEnd(co)
end

local function testSendingCustomTypes()
  local server = luadtp.server()
  local co = server:start(testutils.host, testutils.portSendingCustomTypes)
  print("Server address: ", server:getAddr())
  testutils.pollUntil(co, { eventType = "connect", clientId = 1 })

  server:sendAll(testutils.sendingCustomTypesMessageFromServer)
  testutils.pollUntilNotNilValue(co, { eventType = "receive", clientId = 1, data = testutils.sendingCustomTypesMessageFromClient })

  testutils.pollUntil(co, { eventType = "disconnect", clientId = 1 })
  server:stop()
  testutils.pollEnd(co)
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

local function testClientCleanupOnGC()
  -- TODO
end

local function testServerCleanupOnGC()
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
  print("Testing that client resources are cleaned up when garbage collected...")
  testClientCleanupOnGC()
  print("Testing that server resources are cleaned up when garbage collected...")
  testServerCleanupOnGC()
  print("Testing the README example...")
  testExample()

  print("Completed tests")
end

test()

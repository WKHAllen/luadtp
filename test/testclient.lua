local luadtp = require("luadtp")
---@module "src.crypto"
local crypto = require("luadtp.crypto")
---@module "src.util"
local util = require("luadtp.util")
local testutils = require("test.testutils")

---Tests serialization and deserialization functions.
local function testSerializeDeserialize()
  local value = { id = 1, bar = "baz" }
  local valueSerialized = util.serialize(value)
  local valueDeserialized = util.deserialize(valueSerialized)
  print("Original value:")
  testutils.print_r(value)
  print("Serialized value:")
  testutils.print_r(valueSerialized)
  print("Deserialized value:")
  testutils.print_r(valueDeserialized)
  testutils.assertEq(value, valueDeserialized)
end

---Tests message size encoding.
local function testEncodeMessageSize()
  testutils.assertEq(util.encodeMessageSize(0), string.char(0, 0, 0, 0, 0))
  testutils.assertEq(util.encodeMessageSize(1), string.char(0, 0, 0, 0, 1))
  testutils.assertEq(util.encodeMessageSize(255), string.char(0, 0, 0, 0, 255))
  testutils.assertEq(util.encodeMessageSize(256), string.char(0, 0, 0, 1, 0))
  testutils.assertEq(util.encodeMessageSize(257), string.char(0, 0, 0, 1, 1))
  testutils.assertEq(util.encodeMessageSize(4311810305), string.char(1, 1, 1, 1, 1))
  testutils.assertEq(util.encodeMessageSize(4328719365), string.char(1, 2, 3, 4, 5))
  testutils.assertEq(util.encodeMessageSize(47362409218), string.char(11, 7, 5, 3, 2))
  testutils.assertEq(util.encodeMessageSize(1099511627775), string.char(255, 255, 255, 255, 255))
end

---Tests message size decoding.
local function testDecodeMessageSize()
  testutils.assertEq(util.decodeMessageSize(string.char(0, 0, 0, 0, 0)), 0)
  testutils.assertEq(util.decodeMessageSize(string.char(0, 0, 0, 0, 1)), 1)
  testutils.assertEq(util.decodeMessageSize(string.char(0, 0, 0, 0, 255)), 255)
  testutils.assertEq(util.decodeMessageSize(string.char(0, 0, 0, 1, 0)), 256)
  testutils.assertEq(util.decodeMessageSize(string.char(0, 0, 0, 1, 1)), 257)
  testutils.assertEq(util.decodeMessageSize(string.char(1, 1, 1, 1, 1)), 4311810305)
  testutils.assertEq(util.decodeMessageSize(string.char(1, 2, 3, 4, 5)), 4328719365)
  testutils.assertEq(util.decodeMessageSize(string.char(11, 7, 5, 3, 2)), 47362409218)
  testutils.assertEq(util.decodeMessageSize(string.char(255, 255, 255, 255, 255)), 1099511627775)
end

---Tests cryptographic functions.
local function testCrypto()
  local rsaMessage = "Hello, RSA!"
  local publicKey, privateKey = crypto.newRsaKeyPair()
  local rsaEncrypted = crypto.rsaEncrypt(publicKey, rsaMessage)
  local rsaDecrypted = crypto.rsaDecrypt(privateKey, rsaEncrypted)
  print("Original string:  '" .. rsaMessage .. "'")
  print("Encrypted string: '" .. rsaEncrypted .. "'")
  print("Decrypted string: '" .. rsaDecrypted .. "'")
  testutils.assertEq(rsaDecrypted, rsaMessage)
  testutils.assertNe(rsaEncrypted, rsaMessage)

  local aesMessage = "Hello, AES!"
  local key = crypto.newAesKey()
  local aesEncrypted = crypto.aesEncrypt(key, aesMessage)
  local aesDecrypted = crypto.aesDecrypt(key, aesEncrypted)
  print("Original string:  '" .. aesMessage .. "'")
  print("Encrypted string: '" .. aesEncrypted .. "'")
  print("Decrypted string: '" .. aesDecrypted .. "'")
  testutils.assertEq(aesDecrypted, aesMessage)
  testutils.assertNe(aesEncrypted, aesMessage)

  local publicKey2, privateKey2 = crypto.newRsaKeyPair()
  local key2 = crypto.newAesKey()
  local encryptedKey = crypto.rsaEncrypt(publicKey2, key2)
  local decryptedKey = crypto.rsaDecrypt(privateKey2, encryptedKey)
  testutils.assertEq(key2, decryptedKey)
  testutils.assertNe(key2, encryptedKey)
end

---Tests that the client is able to connect to the server.
local function testClientConnect()
  crypto.sleep(0.1)

  local client = luadtp.client()
  assert(not client:connected())
  local co = client:connect(testutils.host, testutils.portClientConnecting)
  assert(client:connected())
  print("Client address: ", client:getAddr())

  for _ = 1, 100 do
    testutils.pollNil(co)
  end

  crypto.sleep(0.1)
  client:disconnect()
  assert(not client:connected())
  testutils.pollEnd(co)
end

---Tests data sending capabilities.
local function testSend()
  crypto.sleep(0.1)

  local client = luadtp.client()
  local co = client:connect(testutils.host, testutils.portSend)
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  client:send(testutils.sendMessageFromClient)
  testutils.pollUntilNotNilValue(co, { eventType = "receive", data = testutils.sendMessageFromServer })

  crypto.sleep(0.1)
  client:disconnect()
  testutils.pollEnd(co)
end

---Tests sending large messages over the network.
local function testLargeSend()
  crypto.sleep(0.1)

  testutils.randomSeed(testutils.portLargeSend)
  local messageFromServer = testutils.randomBytes(math.random(512, 1023))
  local messageFromClient = testutils.randomBytes(math.random(256, 511))
  print("Large server message length: ", #messageFromServer)
  print("Large client message length: ", #messageFromClient)

  local client = luadtp.client()
  local co = client:connect(testutils.host, testutils.portLargeSend)
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  client:send(messageFromClient)
  testutils.pollUntilNotNilValue(co, { eventType = "receive", data = messageFromServer })

  crypto.sleep(0.1)
  client:disconnect()
  testutils.pollEnd(co)
end

---Tests sending lots of messages over the network.
local function testSendingNumerousMessages()
  crypto.sleep(0.1)

  testutils.randomSeed(testutils.portSendingNumerousMessages)
  local messagesFromServer = testutils.randomNumbers(math.random(64, 127), 0, 65535)
  local messagesFromClient = testutils.randomNumbers(math.random(128, 255), 0, 65535)
  print("Number of server messages: ", #messagesFromServer)
  print("Number of client messages: ", #messagesFromClient)

  local client = luadtp.client()
  local co = client:connect(testutils.host, testutils.portSendingNumerousMessages)
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  for _, clientMessage in ipairs(messagesFromClient) do
    client:send(clientMessage)
  end
  for _, serverMessage in ipairs(messagesFromServer) do
    testutils.pollUntilNotNilValue(co, { eventType = "receive", data = serverMessage })
  end

  crypto.sleep(0.1)
  client:disconnect()
  testutils.pollEnd(co)
end

---Tests sending more complex data structures over the network.
local function testSendingCustomTypes()
  crypto.sleep(0.1)

  local client = luadtp.client()
  local co = client:connect(testutils.host, testutils.portSendingCustomTypes)
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  client:send(testutils.sendingCustomTypesMessageFromClient)
  testutils.pollUntilNotNilValue(co, { eventType = "receive", data = testutils.sendingCustomTypesMessageFromServer })

  crypto.sleep(0.1)
  client:disconnect()
  testutils.pollEnd(co)
end

---Tests having multiple clients connected to the server at once.
local function testMultipleClients()
  crypto.sleep(0.1)

  local client1 = luadtp.client()
  local co1 = client1:connect(testutils.host, testutils.portMultipleClients)
  print("Client 1 address: ", client1:getAddr())

  local client2 = luadtp.client()
  local co2 = client2:connect(testutils.host, testutils.portMultipleClients)
  print("Client 2 address: ", client2:getAddr())

  crypto.sleep(0.1)
  client1:send(testutils.multipleClientsMessageFromClient1)
  client2:send(testutils.multipleClientsMessageFromClient2)

  testutils.pollUntilNotNilValue(co1, { eventType = "receive", data = #testutils.multipleClientsMessageFromClient1 })
  testutils.pollUntilNotNilValue(co2, { eventType = "receive", data = #testutils.multipleClientsMessageFromClient2 })

  testutils.pollUntilNotNilValue(co1, { eventType = "receive", data = testutils.multipleClientsMessageFromServer })
  testutils.pollUntilNotNilValue(co2, { eventType = "receive", data = testutils.multipleClientsMessageFromServer })

  crypto.sleep(0.1)
  client1:disconnect()
  crypto.sleep(0.1)
  client2:disconnect()
  testutils.pollEnd(co1)
  testutils.pollEnd(co2)
end

---Tests explicitly disconnecting a client from the server.
local function testRemoveClient()
  crypto.sleep(0.1)

  local client = luadtp.client()
  assert(not client:connected())
  local co = client:connect(testutils.host, testutils.portRemoveClient)
  assert(client:connected())
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  testutils.pollUntilNotNilValue(co, { eventType = "disconnected" })
  assert(not client:connected())
  testutils.pollEnd(co)
end

---Tests stopping the server while a client is still connected.
local function testStopServerWhileClientConnected()
  crypto.sleep(0.1)

  local client = luadtp.client()
  assert(not client:connected())
  local co = client:connect(testutils.host, testutils.portStopServerWhileClientConnected)
  assert(client:connected())
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  testutils.pollUntilNotNilValue(co, { eventType = "disconnected" })
  assert(not client:connected())
  testutils.pollEnd(co)
end

---Tests that all client network resources are correctly cleaned up when the client's memory is deallocated.
local function testClientCleanupOnGC()
  local function inner()
    local client = luadtp.client()
    client:connect(testutils.host, testutils.portClientCleanupOnGC)
    print("Client address: ", client:getAddr())
  end

  crypto.sleep(0.1)

  inner()
  collectgarbage("collect")
end

---Tests that all server network resources are correctly cleaned up when the server's memory is deallocated.
local function testServerCleanupOnGC()
  crypto.sleep(0.1)

  local client = luadtp.client()
  local co = client:connect(testutils.host, testutils.portServerCleanupOnGC)
  print("Client address: ", client:getAddr())

  crypto.sleep(0.1)
  testutils.pollUntilNotNilValue(co, { eventType = "disconnected" })
  assert(not client:connected())
  testutils.pollEnd(co)
end

---Tests the README example.
local function testExample()
  -- Create a client that sends a message to the server and receives the length of the message
  local client = luadtp.client()
  local co = client:connect(testutils.host, testutils.portExample)

  -- Send a message to the server
  local message = "Hello, server!"
  client:send(message)

  -- Receive the response
  local success, event = coroutine.resume(co)
  while success and event == nil do success, event = coroutine.resume(co) end

  if not success then
    error("server closed unexpectedly")
  elseif event.eventType == "receive" then
    -- Validate the response
    print("Received response from server: " .. event.data)
    assert(event.data == #message)
  else
    -- Unexpected response
    error("expected to receive a response from the server, instead got an event of type " .. event.eventType)
  end

  client:disconnect()
end

---Runs all client tests.
local function test()
  print("Beginning client tests")

  print("Testing serialize and deserialize...")
  testSerializeDeserialize()
  print("Testing encode message size...")
  testEncodeMessageSize()
  print("Testing decode message size...")
  testDecodeMessageSize()
  print("Testing crypto...")
  testCrypto()
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

  print("Completed client tests")
end

test()

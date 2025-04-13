local luadtp = require("luadtp")
local crypto = require("luadtp.crypto")
local util = require("luadtp.util")
local testutils = require("test.testutils")

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

  print("Completed tests")
end

test()

local luadtp = require("luadtp")
local crypto = require("luadtp.crypto")
local util = require("luadtp.util")

local function print_r(t, fd)
  fd = fd or io.stdout
  local function print(str)
     str = str or ""
     fd:write(str.."\n")
  end
  local print_r_cache={}
  local function sub_print_r(t,indent)
    if (print_r_cache[tostring(t)]) then
      print(indent.."*"..tostring(t))
    else
      print_r_cache[tostring(t)]=true
      if (type(t)=="table") then
        for pos,val in pairs(t) do
          if (type(val)=="table") then
            print(indent.."["..pos.."] => "..tostring(t).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            print(indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            print(indent.."["..pos..'] => "'..val..'"')
          else
            print(indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
          print(indent..tostring(t))
      end
    end
  end
  if (type(t)=="table") then
    print(tostring(t).." {")
    sub_print_r(t,"  ")
    print("}")
  else
    sub_print_r(t,"  ")
  end
  print()
end

local function equals(o1, o2, ignore_mt)
  if o1 == o2 then return true end
  local o1Type = type(o1)
  local o2Type = type(o2)
  if o1Type ~= o2Type then return false end
  if o1Type ~= 'table' then return false end

  if not ignore_mt then
    local mt1 = getmetatable(o1)
    if mt1 and mt1.__eq then
      --compare using built in method
      return o1 == o2
    end
  end

  local keySet = {}

  for key1, value1 in pairs(o1) do
    local value2 = o2[key1]
    if value2 == nil or equals(value1, value2, ignore_mt) == false then
      return false
    end
    keySet[key1] = true
  end

  for key2, _ in pairs(o2) do
    if not keySet[key2] then return false end
  end
  return true
end

local function assertEq(a, b, ignore_mt)
  if not equals(a, b, ignore_mt) then
    print("assertEq assertion failed:")
    print("left = ")
    print_r(a)
    print("right = ")
    print_r(b)
    error("assertion failed")
  end
end

local function assertNe(a, b, ignore_mt)
  if equals(a, b, ignore_mt) then
    print("assertNe assertion failed:")
    print("left = ")
    print_r(a)
    print("right = ")
    print_r(b)
    error("assertion failed")
  end
end

local function testSerializeDeserialize()
  local value = { id = 1, bar = "baz" }
  local valueSerialized = util.serialize(value)
  local valueDeserialized = util.deserialize(valueSerialized)
  print("Original value:")
  print_r(value)
  print("Serialized value:")
  print_r(valueSerialized)
  print("Deserialized value:")
  print_r(valueDeserialized)
  assertEq(value, valueDeserialized)
end

local function testEncodeMessageSize()
  assertEq(util.encodeMessageSize(0), string.char(0, 0, 0, 0, 0))
  assertEq(util.encodeMessageSize(1), string.char(0, 0, 0, 0, 1))
  assertEq(util.encodeMessageSize(255), string.char(0, 0, 0, 0, 255))
  assertEq(util.encodeMessageSize(256), string.char(0, 0, 0, 1, 0))
  assertEq(util.encodeMessageSize(257), string.char(0, 0, 0, 1, 1))
  assertEq(util.encodeMessageSize(4311810305), string.char(1, 1, 1, 1, 1))
  assertEq(util.encodeMessageSize(4328719365), string.char(1, 2, 3, 4, 5))
  assertEq(util.encodeMessageSize(47362409218), string.char(11, 7, 5, 3, 2))
  assertEq(util.encodeMessageSize(1099511627775), string.char(255, 255, 255, 255, 255))
end

local function testDecodeMessageSize()
  assert(util.decodeMessageSize(string.char(0, 0, 0, 0, 0)), 0)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 0, 1)), 1)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 0, 255)), 255)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 1, 0)), 256)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 1, 1)), 257)
  assert(util.decodeMessageSize(string.char(1, 1, 1, 1, 1)), 4311810305)
  assert(util.decodeMessageSize(string.char(1, 2, 3, 4, 5)), 4328719365)
  assert(util.decodeMessageSize(string.char(11, 7, 5, 3, 2)), 47362409218)
  assert(util.decodeMessageSize(string.char(255, 255, 255, 255, 255)), 1099511627775)
end

local function testCrypto()
  local rsaMessage = "Hello, RSA!"
  local publicKey, privateKey = crypto.newRsaKeyPair()
  local rsaEncrypted = crypto.rsaEncrypt(publicKey, rsaMessage)
  local rsaDecrypted = crypto.rsaDecrypt(privateKey, rsaEncrypted)
  print("Original string:  '" .. rsaMessage .. "'")
  print("Encrypted string: '" .. rsaEncrypted .. "'")
  print("Decrypted string: '" .. rsaDecrypted .. "'")
  assertEq(rsaDecrypted, rsaMessage)
  assertNe(rsaEncrypted, rsaMessage)

  local aesMessage = "Hello, AES!"
  local key = crypto.newAesKey()
  local aesEncrypted = crypto.aesEncrypt(key, aesMessage)
  local aesDecrypted = crypto.aesDecrypt(key, aesEncrypted)
  print("Original string:  '" .. aesMessage .. "'")
  print("Encrypted string: '" .. aesEncrypted .. "'")
  print("Decrypted string: '" .. aesDecrypted .. "'")
  assertEq(aesDecrypted, aesMessage)
  assertNe(aesEncrypted, aesMessage)

  local publicKey2, privateKey2 = crypto.newRsaKeyPair()
  local key2 = crypto.newAesKey()
  local encryptedKey = crypto.rsaEncrypt(publicKey2, key2)
  local decryptedKey = crypto.rsaDecrypt(privateKey2, encryptedKey)
  assertEq(key2, decryptedKey)
  assertNe(key2, encryptedKey)
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

  print("Completed tests")
end

test()

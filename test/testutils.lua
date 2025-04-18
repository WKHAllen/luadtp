---Debug-prints a value.
---@param t any The value to debug-print.
---@param fd any? An optional file descriptor. Defaults to stdout.
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

---Checks for value equality. Will work on just about any type.
---@param o1 any The first value.
---@param o2 any The second value.
---@param ignore_mt boolean? Whether to ignore metatable equality.
---@return boolean
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

---Asserts the value equality of two objects.
---@param a any The first object.
---@param b any The second object.
---@param ignore_mt boolean? Whether to ignore metatable equality.
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

---Asserts the value inequality of two objects.
---@param a any The first object.
---@param b any The second object.
---@param ignore_mt boolean? Whether to ignore metatable equality.
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

---Polls a coroutine once and asserts that it will poll successfully and will return a given resulting value.
---@param co thread The coroutine to poll.
---@param value any The expected resulting value.
local function pollValue(co, value)
  local success, res = coroutine.resume(co)
  assert(success)
  assertEq(res, value)
end

---Polls a coroutine once and asserts that it will poll successfully and will return nil.
---@param co thread The coroutine to poll.
local function pollNil(co)
  pollValue(co, nil)
end

---Polls a coroutine repeatedly until it signals it has completed, asserting that only nils will be returned before completion.
---@param co thread The coroutine to poll.
local function pollEnd(co)
  local success, res = coroutine.resume(co)

  while success do
    assertEq(res, nil)
    success, res = coroutine.resume(co)
  end

  assert(not success)
  assertNe(res, nil)
end

---Polls a coroutine repeatedly until it yields a given value.
---@param co thread The coroutine to poll.
---@param value any The desired value.
local function pollUntil(co, value)
  while true do
    local success, res = coroutine.resume(co)
    assert(success)

    if res ~= nil then
      assertEq(res, value)
      break
    end
  end
end

---Polls a coroutine repeatedly until it yields a value other than nil.
---@param co thread The coroutine to poll.
---@return any # The yielded value.
local function pollUntilNotNil(co)
  while true do
    local success, res = coroutine.resume(co)
    assert(success)

    if res ~= nil then
      return res
    end
  end
end

---Polls a coroutine repeatedly until it yields something other than nil, and asserts that the yielded object will be a given value.
---@param co thread The coroutine to poll.
---@param value any The expected next non-nil value.
local function pollUntilNotNilValue(co, value)
  local res = pollUntilNotNil(co)
  assertEq(res, value)
end

---Seeds the random number generator.
---@param seed integer The value used to seed the random number generator.
local function randomSeed(seed)
  math.randomseed(seed)
end

---Generates a sequence of random bytes of a given length.
---@param size integer The number of bytes to generate.
---@return string # The randomly generated bytes.
local function randomBytes(size)
  local bytes = ""

  for _ = 1, size do
    bytes = bytes .. string.char(math.random(0, 255))
  end

  return bytes
end

---Generates a sequence of random numbers of a given length, with each number in a given range.
---@param size integer The number of numbers to generate.
---@param min integer The minimum value for each generated number.
---@param max integer The maximum value for each generated number.
---@return table # The randomly generated sequence of numbers.
local function randomNumbers(size, min, max)
  local nums = {}

  for _ = 1, size do
    table.insert(nums, math.random(min, max))
  end

  return nums
end

return {
  host = "127.0.0.1",
  portServerServing = 33001,
  portClientConnecting = 33002,
  portSend = 33003,
  portLargeSend = 33004,
  portSendingNumerousMessages = 33005,
  portSendingCustomTypes = 33006,
  portMultipleClients = 33007,
  portRemoveClient = 33008,
  portStopServerWhileClientConnected = 33009,
  portClientCleanupOnGC = 33010,
  portServerCleanupOnGC = 33011,
  portExample = 33012,
  sendMessageFromServer = 29275,
  sendMessageFromClient = "Hello, server!",
  sendingCustomTypesMessageFromServer = { a = 123, b = "Hello, custom server type!", c = { "first server item", "second server item" } },
  sendingCustomTypesMessageFromClient = { a = 456, b = "Hello, custom client type!", c = { "#1 client item", "client item #2", "(3) client item" } },
  multipleClientsMessageFromServer = 29275,
  multipleClientsMessageFromClient1 = "Hello from client #1",
  multipleClientsMessageFromClient2 = "Goodbye from client #2",
  print_r = print_r,
  equals = equals,
  assertEq = assertEq,
  assertNe = assertNe,
  pollValue = pollValue,
  pollNil = pollNil,
  pollEnd = pollEnd,
  pollUntil = pollUntil,
  pollUntilNotNil = pollUntilNotNil,
  pollUntilNotNilValue = pollUntilNotNilValue,
  randomSeed = randomSeed,
  randomBytes = randomBytes,
  randomNumbers = randomNumbers,
}

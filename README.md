# Data Transfer Protocol for Lua

Ergonomic networking interfaces for Lua.

## Data Transfer Protocol

The Data Transfer Protocol (DTP) is a larger project to make ergonomic network programming available in any language. See the full project [here](https://wkhallen.com/dtp/).

## Installation

Install the package:

```sh
$ luarocks install luadtp
```

Add the package as a dependency in the rockspec file:

```lua
dependencies = {
   "luadtp == 1.0.0"
}
```

## Creating a server

A server can be built using the `Server` implementation:

```lua
local luadtp = require("luadtp")

-- Create a server that receives strings and returns the length of each string
local server = luadtp.server()
local co = server:start("127.0.0.1", 29275)

-- Iterate over events
while true do
  local success, event = coroutine.resume(co)
  if not success then break end

  if event ~= nil then
    if event.eventType == "connect" then
      print("Client with ID " .. event.clientId .. " connected")
    elseif event.eventType == "disconnect" then
      print("Client with ID " .. event.clientId .. " disconnected")
    elseif event.eventType == "receive" then
      -- Send back the length of the string
      server:send(#event.data, event.clientId)
    end
  end
end
```

## Creating a client

A client can be built using the `Client` implementation:

```lua
local luadtp = require("luadtp")

-- Create a client that sends a message to the server and receives the length of the message
local client = luadtp.client()
local co = client:connect("127.0.0.1", 29275)

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
```

## Serialization

All data sent through a network interface is serialized first. Data of any shape can be serialized, but if you need more customizable serialization, you can configure the internal serializer via [`binser`](https://github.com/bakpakin/binser). `binser` is used under the hood for LuaDTP, so configuring the serializer for your custom types is trivial.

## Security

Information security comes included. Every message sent over a network interface is encrypted with AES-256. Key exchanges are performed using a 2048-bit RSA key-pair.

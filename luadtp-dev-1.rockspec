package = "luadtp"
version = "dev-1"
source = {
   url = "git+https://github.com/WKHAllen/luadtp.git"
}
description = {
   summary = "Ergonomic networking interfaces for Lua.",
   homepage = "https://wkhallen.com/dtp/",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "binser == 0.0-8"
}

local function make_platform(platform)
   local libraries = {}

   if platform == "win32" or platform == "mingw32" then
      libraries = { "libcrypto-3-x64" }
   else
      libraries = { "crypto" }
   end

   local modules = {
      ["luadtp.cryptocore"] = {
         sources = {
            "src/luadtpcryptocore.c",
         },
         libraries = libraries
      },
      ["luadtp.util"] = "src/util.lua",
      ["luadtp.crypto"] = "src/crypto.lua",
      ["luadtp.client"] = "src/client.lua",
      ["luadtp.server"] = "src/server.lua",
      luadtp = "src/luadtp.lua"
   }

   return { modules = modules }
end

build = {
   type = "builtin",
   platforms = {
      unix = make_platform("unix"),
      macosx = make_platform("macosx"),
      win32 = make_platform("win32"),
      mingw32 = make_platform("mingw32")
   }
}

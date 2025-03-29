#ifndef LUADTPCRYPTOCORE_H

#include <lua.h>

#ifdef _WIN32
#define LUADTPCRYPTOCORE_API __declspec(dllexport)
#else
#define LUADTPCRYPTOCORE_API __attribute__((visibility("default")))
#endif

LUADTPCRYPTOCORE_API int luaopen_luadtp_cryptocore(lua_State *L);

#endif /* LUADTPCRYPTOCORE_H */

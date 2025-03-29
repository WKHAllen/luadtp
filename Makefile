.PHONY: all build test

CI = false

ifeq ($(OS),Windows_NT)
	LUA = lua.bat
	LUAROCKS = luarocks.bat
	CLEAN_OBJECTS = del src\*.o
else
	LUA = ./lua
	LUAROCKS = ./luarocks
	CLEAN_OBJECTS = rm -f src/*.o
endif

ifeq ($(CI),true)
	LUA = lua
	LUAROCKS = luarocks
endif

BUILD_FLAGS = $(PLAT_BUILD_FLAGS) -fPIC -std=gnu11
LINK_FLAGS = $(PLAT_LINK_FLAGS) -std=gnu11

all: build

build:
	$(LUAROCKS) build CC=gcc LD=gcc && $(CLEAN_OBJECTS)

test:
	$(LUA) test/test.lua

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

COMPILER_FLAGS = \
	-std=gnu11 -pedantic -Wall \
	-Wno-missing-braces -Wextra -Wno-missing-field-initializers -Wformat=2 \
	-Wswitch-default -Wswitch-enum -Wcast-align -Wpointer-arith \
	-Wstrict-overflow=5 -Wstrict-prototypes -Winline \
	-Wundef -Wnested-externs -Wshadow -Wunreachable-code \
	-Wlogical-op -Wstrict-aliasing=2 -Wredundant-decls \
	-Wold-style-definition -Wno-pedantic-ms-format -Werror \
	-g -O0 \
	-fno-omit-frame-pointer -ffloat-store -fno-common
BUILD_FLAGS = $(COMPILER_FLAGS) -fPIC
LINK_FLAGS = $(COMPILER_FLAGS)

all: build

build:
	$(LUAROCKS) build CC=gcc LD=gcc CFLAGS="$(BUILD_FLAGS)" LDFLAGS="$(LINK_FLAGS)" && $(CLEAN_OBJECTS)

test:
	$(LUA) test/test.lua

#!/usr/bin/env python3
"""Run portable Lua tests using liblua5.4 (no game or ROM required)."""
import ctypes
import ctypes.util
import sys
lib = ctypes.CDLL(ctypes.util.find_library('lua5.4'))
ptr = ctypes.c_void_p
lib.luaL_newstate.restype = ptr
lib.luaL_openlibs.argtypes = [ptr]
lib.luaL_loadfilex.argtypes = [ptr, ctypes.c_char_p, ctypes.c_char_p]
lib.luaL_loadfilex.restype = ctypes.c_int
lib.lua_pcallk.argtypes = [ptr, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ptr]
lib.lua_pcallk.restype = ctypes.c_int
lib.lua_tolstring.argtypes = [ptr, ctypes.c_int, ptr]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = [ptr]
for filename in sys.argv[1:]:
    state = lib.luaL_newstate()
    lib.luaL_openlibs(state)
    status = lib.luaL_loadfilex(state, filename.encode(), None)
    if status == 0:
        status = lib.lua_pcallk(state, 0, 0, 0, 0, None)
    if status:
        message = lib.lua_tolstring(state, -1, None)
        print(f'{filename}: {message.decode() if message else "Lua error"}', file=sys.stderr)
    lib.lua_close(state)
    if status:
        sys.exit(1)

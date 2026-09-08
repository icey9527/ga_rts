"""Validate project Lua and run headless regression checks using LOVE's LuaJIT."""
import ctypes
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
lua = ctypes.CDLL(r"C:\Program Files\LOVE\lua51.dll")
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
errors = []
files = [root / "main.lua", root / "conf.lua"]
for folder in ("core", "systems", "entities", "ui", "config", "units", "dialogue", "levels", "tools"):
    files.extend((root / folder).rglob("*.lua"))
for path in files:
    if lua.luaL_loadfile(state, str(path).encode("utf-8")):
        errors.append(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
    lua.lua_settop(state, 0)
if not errors:
    portraits = sorted(p.name for p in (root / "assets/portraits").iterdir())
    listing = ",".join('"' + p + '"' for p in portraits)
    bootstrap = 'package.path="' + root.as_posix() + '/?.lua;"..package.path\nPORTRAITS={' + listing + '}\n'
    if lua.luaL_loadstring(state, bootstrap.encode()) or lua.lua_pcall(state, 0, 0, 0):
        errors.append(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
    elif lua.luaL_loadfile(state, str(root / "tools/headless.lua").encode()) or lua.lua_pcall(state, 0, 0, 0):
        errors.append(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
lua.lua_close(state)
if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"PASS: {len(files)} Lua files compile; headless regression checks passed")

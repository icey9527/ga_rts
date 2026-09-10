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
for folder in ("core", "systems", "entities", "ui", "config", "units", "battle", "levels", "tools"):
    files.extend((root / folder).rglob("*.lua"))
for path in files:
    if lua.luaL_loadfile(state, str(path).encode("utf-8")):
        errors.append(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
    lua.lua_settop(state, 0)
if not errors:
    portraits = sorted(p.name for p in (root / "assets/portraits").iterdir())
    listing = ",".join('"' + p + '"' for p in portraits)
    team_dirs = {"": []}
    teams_root = root / "teams"
    if teams_root.exists():
        for team in sorted(d.name for d in teams_root.iterdir() if d.is_dir()):
            team_dirs[""].append(team)
            chara_root = teams_root / team / "chara"
            if not chara_root.exists():
                continue
            ids = sorted(d.name for d in chara_root.iterdir() if d.is_dir())
            team_dirs[team + "/chara"] = ids
            for cid in ids:
                face = chara_root / cid / "face"
                if face.exists():
                    team_dirs[f"{team}/chara/{cid}/face"] = sorted(f.name for f in face.iterdir())

    def lua_array(items):
        return "{" + ",".join('"' + i + '"' for i in items) + "}"

    teams_listing = ",".join('["' + k + '"]=' + lua_array(v) for k, v in team_dirs.items())
    bootstrap = ('package.path="' + root.as_posix() + '/?.lua;"..package.path\n'
                 'PORTRAITS={' + listing + '}\n'
                 'TEAM_DIRS={' + teams_listing + '}\n')
    if lua.luaL_loadstring(state, bootstrap.encode()) or lua.lua_pcall(state, 0, 0, 0):
        errors.append(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
    elif lua.luaL_loadfile(state, str(root / "tools/headless.lua").encode()) or lua.lua_pcall(state, 0, 0, 0):
        errors.append(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
lua.lua_close(state)
if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"PASS: {len(files)} Lua files compile; headless regression checks passed")

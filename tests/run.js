// Runs RoleLoot in a Lua interpreter against a fake WoW API (tests/wow.lua).
// Setup once: cd tests && npm install. Then: node tests/run.js
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const here = __dirname;
const addon = path.join(here, "..", "RoleLoot");
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
for (const [name, file] of [["DATA_SRC", path.join(addon, "Data.lua")], ["ADDON_SRC", path.join(addon, "RoleLoot.lua")]]) {
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(file, "utf8")));
  lua.lua_setglobal(L, to_luastring(name));
}
const status = lauxlib.luaL_dostring(L, to_luastring(fs.readFileSync(path.join(here, "wow.lua"), "utf8")));
if (status !== lua.LUA_OK) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}

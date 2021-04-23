#!/usr/bin/env lua

-- The author disclaims copyright to this source code.

-- The C compiler used to compile and link the generated C source file.
local CC = os.getenv("CC") or "cc"
-- The nm used to determine whether a library is liblua or a Lua binary module.
local NM = os.getenv("NM") or "nm"

local function file_exists(name)
	local file = io.open(name, "r")
	if file then
		file:close()
		return true
	end
	return false
end

--[[
Run a shell command, wait for it to finish, and return a string containing stdout.
--]]
local function shellout(command)
	local file = io.popen(command)
	local stdout = file:read("*all")
	local ok = file:close()
	if ok then
		return stdout
	end
	return nil
end

--[[
Use execute() when stdout isn't needed instead of shellout() because io.popen() does 
not return the status code in Lua 5.1.
--]]
local function execute(cmd)
	local ok = os.execute(cmd)
	return (ok == true or ok == 0)
end

--[[
Return a comma separated hex string suitable for a C array definition.
--]]
local function string_to_c_hex_literal(characters)
	local hex = {}
	for character in characters:gmatch(".") do
		table.insert(hex, ("0x%02x"):format(string.byte(character)))
	end
	return table.concat(hex, ", ")
end
assert(string_to_c_hex_literal("hello") == "0x68, 0x65, 0x6c, 0x6c, 0x6f")

--[[
Strip the directory from a filename.
--]]
local function basename(path)
	local name = path:gsub([[(.*[\/])(.*)]], "%2")
	return name
end
assert(basename("/path/to/file.lua") == "file.lua")
assert(basename([[C:\path\to\file.lua]]) == "file.lua")

local function is_source_file(extension)
	return
		-- Source file.
		extension == "lua" or
		-- Precompiled chunk.
		extension == "luac"
end

local function is_binary_library(extension)
	return 
		-- Object file.
		extension == "o" or 
		-- Static library.
		extension == "a" or 
		-- Shared library.
		extension == "so" or
		-- Mach-O dynamic library.
		extension == "dylib"
end

-- Required Lua source files.
local lua_source_files = {}
-- Libraries for required Lua binary modules.
local module_library_files = {}
local module_link_libraries = {}
-- Libraries other than Lua binary modules, including liblua.
local dep_library_files = {}
-- Additional arguments are passed to the C compiler.
local other_arguments = {}
-- Get the operating system name.
local UNAME = (shellout("uname -s") or "Unknown"):match("%a+") or "Unknown"
local link_with_libdl = ""

--[[
Parse command line arguments. main.lua must be the first argument. Static libraries are 
passed to the compiler in the order they appear and may be interspersed with arguments to 
the compiler. Arguments to the compiler are passed to the compiler in the order they 
appear.
--]]
for i, name in ipairs(arg) do
	local extension = name:match("%.(%a+)$")
	if i == 1 or (is_source_file(extension) or is_binary_library(extension)) then
		if not file_exists(name) then
			io.stderr:write("file does not exist: " .. name .. "\n")
			os.exit(1)
		end

		local info = {}
		info.path = name
		info.basename = basename(info.path)
		info.basename_noextension = info.basename:match("(.+)%.") or info.basename
		--[[
		Handle the common case of "./path/to/file.lua".
		This won't work in all cases.
		--]]
		info.dotpath = info.path:gsub("^%.%/", "")
		info.dotpath = info.dotpath:gsub("[\\/]", ".")
		info.dotpath_noextension = info.dotpath:match("(.+)%.") or info.dotpath
		info.dotpath_underscore = info.dotpath_noextension:gsub("[.-]", "_")

		if i == 1 or is_source_file(extension) then
			table.insert(lua_source_files, info)
		elseif is_binary_library(extension) then
			-- The library is either a Lua module or a library dependency.
			local nmout = shellout(NM .. " " .. info.path)
			if not nmout then
				io.stderr:write("nm not found\n")
				os.exit(1)
			end
			local is_module = false
			if nmout:find("T _?luaL_newstate") then
				if nmout:find("U _?dlopen") then
					if UNAME == "Linux" or UNAME == "SunOS" or UNAME == "Darwin" then
						--[[
						Link with libdl because liblua was built with support loading 
						shared objects and the operating system depends on it.
						--]]
						link_with_libdl = "-ldl"
					end
				end
			else
				for luaopen in nmout:gmatch("[^dD] _?luaopen_([%a%p%d]+)") do
					local modinfo = {}
					modinfo.path = info.path
					modinfo.dotpath_underscore = luaopen
					modinfo.dotpath = modinfo.dotpath_underscore:gsub("_", ".")
					modinfo.dotpath_noextension = modinfo.dotpath
					is_module = true
					table.insert(module_library_files, modinfo)
				end
			end
			if is_module then
				table.insert(module_link_libraries, info.path)
			else
				table.insert(dep_library_files, info.path)
			end
		end
	else
		-- Forward the remaining arguments to the C compiler.
		table.insert(other_arguments, name)
	end
end

if #lua_source_files == 0 then
	local version = "0.0.12"
	print("luastatic " .. version)
	print([[
usage: luastatic main.lua[1] require.lua[2] liblua.a[3] library.a[4] -I/include/lua[5] [6]
  [1]: The entry point to the Lua program
  [2]: One or more required Lua source files
  [3]: The path to the Lua interpreter static library
  [4]: One or more static libraries for a required Lua binary module
  [5]: The path to the directory containing lua.h
  [6]: Additional arguments are passed to the C compiler]])
	os.exit(1)
end

-- The entry point to the Lua program.
local mainlua = lua_source_files[1]
--[[
Generate a C program containing the Lua source files that uses the Lua C API to 
initialize any Lua libraries and run the program.
--]]
local outfilename = mainlua.basename_noextension .. ".luastatic.c"
local outfile = io.open(outfilename, "w+")
local function out(...)
	outfile:write(...)
end
local function outhex(str)
	outfile:write(string_to_c_hex_literal(str), ", ")
end

--[[
Embed Lua program source code.
--]]
local function out_lua_source(file)
	local f = io.open(file.path, "r")
	local prefix = f:read(4)
	if prefix then
		if prefix:match("\xef\xbb\xbf") then
			-- Strip the UTF-8 byte order mark.
			prefix = prefix:sub(4)
		end
		if prefix:match("#") then
			-- Strip the shebang.
			f:read("*line")
			prefix = "\n"
		end
		out(string_to_c_hex_literal(prefix), ", ")
	end
	while true do
		local strdata = f:read(4096)
		if strdata then
			out(string_to_c_hex_literal(strdata), ", ")
		else
			break
		end
	end
	f:close()
end

out([[
#ifdef __cplusplus
extern "C" {
#endif
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#ifdef __cplusplus
}
#endif
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM == 501
	#define LUA_OK 0
#endif

/* Copied from lua.c */

static lua_State *globalL = NULL;

static void lstop (lua_State *L, lua_Debug *ar) {
	(void)ar;  /* unused arg. */
	lua_sethook(L, NULL, 0, 0);  /* reset hook */
	luaL_error(L, "interrupted!");
}

static void laction (int i) {
	signal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
	lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static void createargtable (lua_State *L, char **argv, int argc, int script) {
	int i, narg;
	if (script == argc) script = 0;  /* no script name? */
	narg = argc - (script + 1);  /* number of positive indices */
	lua_createtable(L, narg, script + 1);
	for (i = 0; i < argc; i++) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i - script);
	}
	lua_setglobal(L, "arg");
}

static int msghandler (lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL) {  /* is error object not a string? */
		if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
				lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
			return 1;  /* that is the message */
		else
			msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
	}
	/* Call debug.traceback() instead of luaL_traceback() for Lua 5.1 compatibility. */
	lua_getglobal(L, "debug");
	lua_getfield(L, -1, "traceback");
	/* debug */
	lua_remove(L, -2);
	lua_pushstring(L, msg);
	/* original msg */
	lua_remove(L, -3);
	lua_pushinteger(L, 2);  /* skip this function and traceback */
	lua_call(L, 2, 1); /* call debug.traceback */
	return 1;  /* return the traceback */
}

static int docall (lua_State *L, int narg, int nres) {
	int status;
	int base = lua_gettop(L) - narg;  /* function index */
	lua_pushcfunction(L, msghandler);  /* push message handler */
	lua_insert(L, base);  /* put it under function and args */
	globalL = L;  /* to be available to 'laction' */
	signal(SIGINT, laction);  /* set C-signal handler */
	status = lua_pcall(L, narg, nres, base);
	signal(SIGINT, SIG_DFL); /* reset C-signal handler */
	lua_remove(L, base);  /* remove message handler from the stack */
	return status;
}

#ifdef __cplusplus
extern "C" {
#endif
]])

for _, library in ipairs(module_library_files) do
	out(('	int luaopen_%s(lua_State *L);\n'):format(library.dotpath_underscore))
end

out([[
#ifdef __cplusplus
}
#endif


int main(int argc, char *argv[])
{
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	createargtable(L, argv, argc, 0);

	static const unsigned char lua_loader_program[] = {
		]])

outhex([[
local args = {...}
local lua_bundle = args[1]

local function load_string(str, name)
	if _VERSION == "Lua 5.1" then
		return loadstring(str, name)
	else
		return load(str, name)
	end
end

local function lua_loader(name)
	local separator = package.config:sub(1, 1)
	name = name:gsub(separator, ".")
	local mod = lua_bundle[name] or lua_bundle[name .. ".init"]
	if mod then
		if type(mod) == "string" then
			local chunk, errstr = load_string(mod, name)
			if chunk then
				return chunk
			else
				error(
					("error loading module '%s' from luastatic bundle:\n\t%s"):format(name, errstr),
					0
				)
			end
		elseif type(mod) == "function" then
			return mod
		end
	else
		return ("\n\tno module '%s' in luastatic bundle"):format(name)
	end
end
table.insert(package.loaders or package.searchers, 2, lua_loader)

-- Lua 5.1 has unpack(). Lua 5.2+ has table.unpack().
local unpack = unpack or table.unpack
]])

outhex(([[
local func = lua_loader("%s")
if type(func) == "function" then
	-- Run the main Lua program.
	func(unpack(arg))
else
	error(func, 0)
end
]]):format(mainlua.dotpath_noextension))

out(([[

	};
	/*printf("%%.*s", (int)sizeof(lua_loader_program), lua_loader_program);*/
	if
	(
		luaL_loadbuffer(L, (const char*)lua_loader_program, sizeof(lua_loader_program), "%s") 
		!= LUA_OK
	)
	{
		fprintf(stderr, "luaL_loadbuffer: %%s\n", lua_tostring(L, -1));
		lua_close(L);
		return 1;
	}
	
	/* lua_bundle */
	lua_newtable(L);
]]):format(mainlua.basename_noextension));

for i, file in ipairs(lua_source_files) do
	out(('	static const unsigned char lua_require_%i[] = {\n		'):format(i))
	out_lua_source(file);
	out("\n	};\n")
	out(([[
	lua_pushlstring(L, (const char*)lua_require_%i, sizeof(lua_require_%i));
]]):format(i, i))
	out(('	lua_setfield(L, -2, "%s");\n\n'):format(file.dotpath_noextension))
end

for _, library in ipairs(module_library_files) do
	out(('	lua_pushcfunction(L, luaopen_%s);\n'):format(library.dotpath_underscore))
	out(('	lua_setfield(L, -2, "%s");\n\n'):format(library.dotpath_noextension))
end

out([[
	if (docall(L, 1, LUA_MULTRET))
	{
		const char *errmsg = lua_tostring(L, 1);
		if (errmsg)
		{
			fprintf(stderr, "%s\n", errmsg);
		}
		lua_close(L);
		return 1;
	}
	lua_close(L);
	return 0;
}
]])

outfile:close()

if os.getenv("CC") == "" then
	-- Disable compiling and exit with a success code.
	os.exit(0)
end

if not execute(CC .. " --version 1>/dev/null 2>/dev/null") then
	io.stderr:write("C compiler not found.\n")
	os.exit(1)
end

-- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
local rdynamic = "-rdynamic"
local binary_extension = ""
if shellout(CC .. " -dumpmachine"):match("mingw") then
	rdynamic = ""
	binary_extension = ".exe"
end

local compile_command = table.concat({
	CC,
	"-Os",
	outfilename,
	-- Link with Lua modules first to avoid linking errors.
	table.concat(module_link_libraries, " "),
	table.concat(dep_library_files, " "),
	rdynamic,
	"-lm",
	link_with_libdl,
	"-o " .. mainlua.basename_noextension .. binary_extension,
	table.concat(other_arguments, " "),
}, " ")
print(compile_command)
local ok = execute(compile_command)
if ok then
	os.exit(0)
else
	os.exit(1)
end

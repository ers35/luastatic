# make CC="gcc"
# make CC="musl-gcc"
# make CC="clang"

LUA_VERSION ?= 5.2.4
#LUA_VERSION ?= 5.3.1

.PHONY: *.lua *.lua.c test

default: luastatic

lua liblua.a:
	cd lua-$(LUA_VERSION) && make posix
	cp lua-$(LUA_VERSION)/src/liblua.a . 
	cp lua-$(LUA_VERSION)/src/lua . 

luastatic: lua liblua.a
	./lua luastatic.lua luastatic.lua liblua.a -Ilua-$(LUA_VERSION)/src

hello: luastatic
	./luastatic test/hello.lua liblua.a -Ilua-$(LUA_VERSION)/src
multiple.dots: luastatic
	./luastatic test/multiple.dots.lua liblua.a -Ilua-$(LUA_VERSION)/src
hypen-: luastatic
	./luastatic test/hypen-.lua liblua.a -Ilua-$(LUA_VERSION)/src
sql: luastatic
	./lua luastatic.lua test/sql.lua liblua.a test/lsqlite3.a \
	/usr/lib/x86_64-linux-gnu/libsqlite3.a -pthread -Ilua-$(LUA_VERSION)/src
require1: luastatic
	./lua luastatic.lua test/require1.lua test/require2.lua liblua.a -Ilua-$(LUA_VERSION)/src

test: hello multiple.dots hypen- require1
	./hello
	./multiple.dots
	./hypen-
	./require1

run: hello
	./hello

clean:
	cd lua-$(LUA_VERSION) && make clean
	rm -f liblua.a lua *.lua.c luastatic hello multiple.dots hypen- sql require1

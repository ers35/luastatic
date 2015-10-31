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
	cd test && ../luastatic hello.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
multiple.dots: luastatic
	cd test && ../luastatic multiple.dots.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
hypen-: luastatic
	cd test && ../luastatic hypen-.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
sql: luastatic
	cd test && ../luastatic sql.lua ../liblua.a lsqlite3.a \
	/usr/lib/x86_64-linux-gnu/libsqlite3.a -pthread -I../lua-$(LUA_VERSION)/src
require1: luastatic
	cd test && ../luastatic require1.lua require2.lua ../liblua.a -I../lua-$(LUA_VERSION)/src

test: hello multiple.dots hypen- require1
	./test/hello
	./test/multiple.dots
	./test/hypen-
	./test/require1

clean:
	cd lua-$(LUA_VERSION) && make clean
	rm -f liblua.a lua *.lua.c luastatic hello multiple.dots hypen- sql require1

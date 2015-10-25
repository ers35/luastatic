# make CC="gcc"
# make CC="musl-gcc"
# make CC="clang"

.PHONY: *.lua *.lua.c

default: luastatic

lua liblua.a:
	cd lua-5.2.4 && make posix
	cp lua-5.2.4/src/liblua.a . 
	cp lua-5.2.4/src/lua . 

luastatic: lua liblua.a
	./lua luastatic.lua luastatic.lua liblua.a

hello: luastatic
	./luastatic hello.lua liblua.a

run: hello
	./hello

clean:
	cd lua-5.2.4 && make clean
	rm -f *.lua.c luastatic hello liblua.a lua

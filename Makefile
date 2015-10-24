# make CC="gcc"
# make CC="musl-gcc"
# make CC="clang"

.PHONY: *.lua *.lua.c

default: luastatic

liblua.a:
	cd lua-5.2.4 && make posix
	cp lua-5.2.4/src/liblua.a . 

luastatic: liblua.a
	lua luastatic.lua luastatic.lua

hello: luastatic
	./luastatic hello.lua

run: hello
	./hello

clean:
	cd lua-5.2.4 && make clean
	rm -f *.lua.c luastatic hello liblua.a

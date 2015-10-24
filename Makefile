# make CC="gcc"
# make CC="musl-gcc"
# make CC="clang"

.PHONY: *.lua *.lua.c

default: luastatic

luastatic:
	lua luastatic.lua luastatic.lua

hello: luastatic
	luastatic hello.lua

run: hello
	./hello

clean:
	rm -f *.lua.c luastatic hello

# make CC="gcc"
# make CC="musl-gcc"
# make CC="clang"

LUA = lua5.2
LIBLUA_A = /usr/lib/x86_64-linux-gnu/liblua5.2.a
LUA_INCLUDE = /usr/include/lua5.2

.PHONY: *.lua *.lua.c test

default: luastatic

luastatic: luastatic.lua
	$(LUA) luastatic.lua luastatic.lua $(LIBLUA_A) -I$(LUA_INCLUDE)

hello: luastatic
	cd test && ../luastatic hello.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
multiple.dots: luastatic
	cd test && ../luastatic multiple.dots.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
hypen-: luastatic
	cd test && ../luastatic hypen-.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
sql: luastatic
	cd test && ../luastatic sql.lua $(LIBLUA_A) lsqlite3.a \
	/usr/lib/x86_64-linux-gnu/libsqlite3.a -pthread -I$(LUA_INCLUDE)
require1: luastatic
	cd test && ../luastatic require1.lua require2.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
subdir: luastatic
	cd test && ../luastatic subdir.lua subdirectory/test.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
binmodule: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule.c -o binmodule.o \
	&& ar rcs binmodule.a binmodule.o && \
	../luastatic binmodule.lua $(LIBLUA_A) binmodule.a -I$(LUA_INCLUDE)
binmodule_so_: luastatic
	cd test && cc -shared -fPIC -I$(LUA_INCLUDE) binmodule_so.c -o binmodule_so.so && \
	../luastatic binmodule_so_.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
binmodule_multiple: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule_multiple.c -o binmodule_multiple.o \
	&& ar rcs binmodule_multiple.a binmodule_multiple.o && \
	../luastatic binmodule_multiple.lua $(LIBLUA_A) binmodule_multiple.a -I$(LUA_INCLUDE)
binmodule_dots: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule_dots.c -o binmodule_dots.o \
	&& ar rcs binmodule.dots.a binmodule_dots.o && \
	../luastatic binmodule_dots.lua $(LIBLUA_A) binmodule.dots.a -I$(LUA_INCLUDE)
bom: luastatic
	cd test && ../luastatic bom.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
shebang: luastatic
	cd test && ../luastatic shebang.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
shebang_nonewline: luastatic
	cd test && ../luastatic shebang_nonewline.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
empty: luastatic
	cd test && ../luastatic empty.lua $(LIBLUA_A) -I$(LUA_INCLUDE)
subdir_binmodule: luastatic
	cd test && \
	cc -c -I$(LUA_INCLUDE) subdirectory/binmodule.c -o subdirectory/binmodule.o && \
	ar rcs subdirectory/binmodule.a subdirectory/binmodule.o && \
	../luastatic subdir_binmodule.lua subdirectory/binmodule.a $(LIBLUA_A) -I$(LUA_INCLUDE)
# Building mangled is good enough. No need to run it.
mangled: luastatic
	cd test && c++ -c -I$(LUA_INCLUDE) mangled.cpp -o mangled.o \
	&& ar rcs mangled.a mangled.o && \
	../luastatic hello.lua $(LIBLUA_A) mangled.a -I$(LUA_INCLUDE)

# mingw
# CC=x86_64-w64-mingw32-gcc lua luastatic.lua test/hello.lua /usr/x86_64-w64-mingw32/lib/liblua5.2.a -Ilua-5.2.4/src/

test: hello multiple.dots hypen- require1 subdir binmodule binmodule_multiple \
	binmodule_so_ binmodule_dots bom shebang shebang_nonewline empty subdir_binmodule \
	mangled
	./test/hello
	./test/multiple.dots
	./test/hypen-
	./test/require1
	./test/subdir
	./test/binmodule
	cd test && ./binmodule_so_
	./test/binmodule_multiple
	./test/binmodule_dots
	# Lua 5.1 does not support BOM
	./test/bom || true
	./test/shebang
	./test/shebang_nonewline
	./test/empty
	./test/subdir_binmodule

luastatic-git.zip:
	git archive HEAD --output $@

clean:
	rm -f *.lua.c luastatic
	find test/ -type f -executable | xargs rm -f
	find test/ -name *.o | xargs rm -f
	find test/ -name *.a | xargs rm -f
	find test/ -name *.so | xargs rm -f

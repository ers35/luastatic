# make CC="gcc"
# make CC="musl-gcc"
# make CC="clang"

#LUA_VERSION ?= 5.1.5
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
subdir: luastatic
	cd test && ../luastatic subdir.lua subdirectory/test.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
binmodule: luastatic
	cd test && cc -c -I../lua-$(LUA_VERSION)/src binmodule.c -o binmodule.o \
	&& ar rcs binmodule.a binmodule.o && \
	../luastatic binmodule.lua ../liblua.a binmodule.a -I../lua-$(LUA_VERSION)/src
binmodule_multiple: luastatic
	cd test && cc -c -I../lua-$(LUA_VERSION)/src binmodule_multiple.c -o binmodule_multiple.o \
	&& ar rcs binmodule_multiple.a binmodule_multiple.o && \
	../luastatic binmodule_multiple.lua ../liblua.a binmodule_multiple.a -I../lua-$(LUA_VERSION)/src
binmodule_dots: luastatic
	cd test && cc -c -I../lua-$(LUA_VERSION)/src binmodule_dots.c -o binmodule_dots.o \
	&& ar rcs binmodule.dots.a binmodule_dots.o && \
	../luastatic binmodule_dots.lua ../liblua.a binmodule.dots.a -I../lua-$(LUA_VERSION)/src
bom: luastatic
	cd test && ../luastatic bom.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
shebang: luastatic
	cd test && ../luastatic shebang.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
shebang_nonewline: luastatic
	cd test && ../luastatic shebang_nonewline.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
empty: luastatic
	cd test && ../luastatic empty.lua ../liblua.a -I../lua-$(LUA_VERSION)/src
subdir_binmodule: luastatic
	cd test && \
	cc -c -I../lua-$(LUA_VERSION)/src subdirectory/binmodule.c -o subdirectory/binmodule.o && \
	ar rcs subdirectory/binmodule.a subdirectory/binmodule.o && \
	../luastatic subdir_binmodule.lua subdirectory/binmodule.a ../liblua.a -I../lua-$(LUA_VERSION)/src
mangled: luastatic
	cd test && c++ -c -I../lua-$(LUA_VERSION)/src mangled.cpp -o mangled.o \
	&& ar rcs mangled.a mangled.o && \
	../luastatic hello.lua ../liblua.a mangled.a -I../lua-$(LUA_VERSION)/src

# mingw
# CC=x86_64-w64-mingw32-gcc lua luastatic.lua test/hello.lua /usr/x86_64-w64-mingw32/lib/liblua5.2.a -Ilua-5.2.4/src/

test: hello multiple.dots hypen- require1 subdir binmodule binmodule_multiple \
	binmodule_dots bom shebang shebang_nonewline empty subdir_binmodule mangled
	./test/hello
	./test/multiple.dots
	./test/hypen-
	./test/require1
	./test/subdir
	./test/binmodule
	./test/binmodule_multiple
	./test/binmodule_dots
# Lua 5.1 does not support BOM
ifneq ($(LUA_VERSION), 5.1.5)
	./test/bom
endif
	./test/shebang
	./test/shebang_nonewline
	./test/empty
	./test/subdir_binmodule
	@# Building mangled is good enough. No need to run it.

luastatic-git.zip:
	git archive HEAD --output $@

clean:
	cd lua-$(LUA_VERSION) && make clean
	rm -f liblua.a lua *.lua.c luastatic
	cd test && rm -f hello hypen- multiple.dots require1 subdir \
		binmodule binmodule_multiple binmodule_dots bom \
		shebang shebang_nonewline empty subdir_binmodule
	find test/ -name *.o | xargs rm -f
	find test/ -name *.a | xargs rm -f

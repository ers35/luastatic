LUA ?= lua5.2
LIBLUA_A ?= /usr/lib/x86_64-linux-gnu/lib$(LUA).a
LUA_INCLUDE ?= /usr/include/$(LUA)

.PHONY: *.lua *.lua.c test run_test

default: luastatic

luastatic: luastatic.lua
	$(LUA) luastatic.lua luastatic.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)

hello: luastatic
	cd test && ../luastatic hello.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
multiple.dots: luastatic
	cd test && ../luastatic multiple.dots.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
hypen-: luastatic
	cd test && ../luastatic hypen-.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
require1: luastatic
	cd test && ../luastatic require1.lua require2.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
subdir: luastatic
	cd test && ../luastatic subdir.lua subdirectory/test.lua $(LIBLUA_A) -I$(LUA_INCLUDE) \
		$(CFLAGS)
binmodule: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule.c -o binmodule.o \
	&& ar rcs binmodule.a binmodule.o && \
	../luastatic binmodule.lua $(LIBLUA_A) binmodule.a -I$(LUA_INCLUDE) $(CFLAGS)
binmodule_so_: luastatic
	cd test && cc -shared -fPIC -I$(LUA_INCLUDE) binmodule_so.c -o binmodule_so.so && \
	../luastatic binmodule_so_.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
binmodule_multiple: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule_multiple.c -o binmodule_multiple.o \
	&& ar rcs binmodule_multiple.a binmodule_multiple.o && \
	../luastatic binmodule_multiple.lua $(LIBLUA_A) binmodule_multiple.a -I$(LUA_INCLUDE) \
		$(CFLAGS)
binmodule_dots: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule_dots.c -o binmodule_dots.o \
	&& ar rcs binmodule.dots.a binmodule_dots.o && \
	../luastatic binmodule_dots.lua $(LIBLUA_A) binmodule.dots.a -I$(LUA_INCLUDE) $(CFLAGS)
bom: luastatic
	cd test && ../luastatic bom.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
shebang: luastatic
	cd test && ../luastatic shebang.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
shebang_nonewline: luastatic
	cd test && ../luastatic shebang_nonewline.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
bom_shebang: luastatic
	cd test && ../luastatic bom_shebang.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
empty: luastatic
	cd test && ../luastatic empty.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
subdir_binmodule: luastatic
	cd test && \
	cc -c -I$(LUA_INCLUDE) subdirectory/binmodule.c -o subdirectory/binmodule.o && \
	ar rcs subdirectory/binmodule.a subdirectory/binmodule.o && \
	../luastatic subdir_binmodule.lua subdirectory/binmodule.a $(LIBLUA_A) \
		-I$(LUA_INCLUDE) $(CFLAGS)
# Building mangled is good enough. No need to run it.
# Also test compiling with a C++ compiler.
mangled: luastatic
	cd test && c++ -c -I$(LUA_INCLUDE) mangled.cpp -o mangled.o \
	&& ar rcs mangled.a mangled.o && \
	CC=c++ ../luastatic hello.lua $(LIBLUA_A) mangled.a -I$(LUA_INCLUDE) $(CFLAGS)
disable_compiling: luastatic
	cd test && CC="" ../luastatic hello.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
compiler_not_found: luastatic
	cd test && \
	if CC="sds43fq1z7sfw" ../luastatic hello.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS) ; \
	then false ; else true ; fi
precompiled_chunk: luastatic
	cd test && luac5.2 -o precompiled_chunk.luac precompiled_chunk.lua && \
	../luastatic precompiled_chunk.luac $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)

test:
	LUA=lua5.1 make -j5 run_test
	LUA=lua5.2 make -j5 run_test
	LUA=lua5.3 make -j5 run_test
	LUA=luajit LIBLUA_A=/usr/lib/x86_64-linux-gnu/libluajit-5.1.a \
		LUA_INCLUDE=/usr/include/luajit-2.0 CFLAGS="-no-pie" make -j5 run_test

run_test: hello multiple.dots hypen- require1 subdir binmodule binmodule_multiple \
	binmodule_so_ binmodule_dots bom shebang shebang_nonewline bom_shebang \
	empty subdir_binmodule mangled disable_compiling compiler_not_found
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
	./test/bom_shebang || true
	./test/shebang
	./test/shebang_nonewline
	./test/empty
	./test/subdir_binmodule

clean:
	rm -f *.lua.c luastatic
	find test/ -type f -executable | xargs rm -f
	find test/ -type f -name *.lua.c | xargs rm -f
	find test/ -type f -name *.luac.c | xargs rm -f
	find test/ -type f -name *.luac | xargs rm -f
	find test/ -type f -name *.o | xargs rm -f
	find test/ -type f -name *.a | xargs rm -f
	find test/ -type f -name *.so | xargs rm -f

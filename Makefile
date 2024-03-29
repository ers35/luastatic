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
subdir_slash: luastatic
	cd test && ../luastatic subdir_slash.lua subdirectory/test.lua $(LIBLUA_A) -I$(LUA_INCLUDE) \
		$(CFLAGS)
binmodule: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule.c -o binmodule.o \
	&& ar rcs binmodule.a binmodule.o && \
	../luastatic binmodule.lua $(LIBLUA_A) binmodule.a -I$(LUA_INCLUDE) $(CFLAGS)
binmodule_cpp: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule.c -o binmodule.o \
	&& ar rcs binmodule.a binmodule.o && \
	CC=c++ ../luastatic binmodule.lua $(LIBLUA_A) binmodule.a -I$(LUA_INCLUDE) $(CFLAGS) \
		-o binmodule_cpp
binmodule_o: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) binmodule.c -o binmodule.o \
	&& ../luastatic binmodule.lua $(LIBLUA_A) binmodule.o -I$(LUA_INCLUDE) $(CFLAGS) -o binmodule_o
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
init: luastatic
	cd test && ../luastatic init_.lua foo/init.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
error: luastatic
	cd test && ../luastatic error_.lua error.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
main_in_dir: luastatic
	./luastatic test/hello.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS) -o test/main_in_dir
lazy_load_modules: luastatic
	cd test && cc -c -I$(LUA_INCLUDE) lazy_load_modules.c -o lazy_load_modules.o \
	&& ar rcs lazy_load_modules.a lazy_load_modules.o && \
	../luastatic lazy_load_modules.lua $(LIBLUA_A) lazy_load_modules.a -I$(LUA_INCLUDE) \
		$(CFLAGS)
utf8: luastatic
	cd test && ../luastatic utf8.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
stack: luastatic
	cd test && ../luastatic stack.lua $(LIBLUA_A) -I$(LUA_INCLUDE) $(CFLAGS)
subdir_dot: luastatic
	cd test && ../luastatic subdir.lua ./subdirectory/test.lua $(LIBLUA_A) -I$(LUA_INCLUDE) \
		$(CFLAGS) -o subdir_dot

test:
	LUA=lua5.1 make run_test
	LUA=lua5.2 make run_test
	LUA=lua5.2 make run_test_5_2
	LUA=lua5.3 make run_test
	LUA=lua5.3 make run_test_5_3
	LUA=lua5.4 make run_test
	LUA=luajit LIBLUA_A=/usr/lib/x86_64-linux-gnu/libluajit-5.1.a \
		LUA_INCLUDE=/usr/include/luajit-2.1 CFLAGS="-no-pie" make run_test

run_test: hello multiple.dots hypen- require1 subdir binmodule binmodule_multiple \
	binmodule_o binmodule_so_ binmodule_dots shebang shebang_nonewline \
	empty subdir_binmodule mangled disable_compiling compiler_not_found main_in_dir \
	lazy_load_modules utf8 stack subdir_dot subdir_slash binmodule_cpp
	./test/hello
	./test/multiple.dots
	./test/hypen-
	./test/require1
	./test/subdir
	./test/binmodule
	./test/binmodule_o
	cd test && ./binmodule_so_
	./test/binmodule_multiple
	./test/binmodule_dots
	./test/shebang
	./test/shebang_nonewline
	./test/empty
	./test/subdir_binmodule
	./test/main_in_dir
	./test/lazy_load_modules
	./test/utf8
	./test/stack a b c
	./test/subdir_dot
	./test/subdir_slash
	./test/binmodule_cpp
	
run_test_5_2: bom bom_shebang
	# Lua 5.1 does not support BOM
	./test/bom
	./test/bom_shebang
	
run_test_5_3: bom bom_shebang init
	./test/bom
	./test/bom_shebang
	# Only Lua 5.3 looks for init.lua in a relative subdirectory
	./test/init_

clean:
	rm -f *.luastatic.c luastatic
	find test/ -type f -executable | xargs rm -f
	find test/ -type f -name "*.luastatic.c" | xargs rm -f
	find test/ -type f -name "*.luac" | xargs rm -f
	find test/ -type f -name "*.o" | xargs rm -f
	find test/ -type f -name "*.a" | xargs rm -f
	find test/ -type f -name "*.so" | xargs rm -f

# This file is made by Mojca and Hans and is subjected to changes
# as we proceed with luametatex and the contextgarden compile farm.

cmake_minimum_required(VERSION 3.7)

# Lucky us: only normal C is used:

project (mujs
	VERSION 1.0.6
	DESCRIPTION "MuJS embeddable Javascript interpreter"
	LANGUAGES C)

# The jsrepr.c is not needed and depends on utf.c as well has some function
# pointer cast issue (accessing unknown name field).

set (mujs_sources
	jsarray.c
	jsboolean.c
	jsbuiltin.c
	jscompile.c
	jsdate.c
	jsdtoa.c
	jsdump.c
	jserror.c
	jsfunction.c
	jsgc.c
	jsintern.c
	jslex.c
	jsmath.c
	jsnumber.c
	jsobject.c
	json.c
	jsparse.c
	jsproperty.c
	jsregexp.c
#	jsrepr.c
	jsrun.c
	jsstate.c
	jsstring.c
	jsvalue.c
	regexp.c
	utf.c
	utftype.c
)

set (mujs_headers
	jsbuiltin.h
	jscompile.h
	jsi.h
	jslex.h
	jsparse.h
	jsrun.h
	jsvalue.h
	mujs.h
	regexp.h
	utf.h
)

# We need this in order for msvc to export the symbols (which is default on
# gcc). Otherwise we need this dllexport stuff.

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# The previous one has to come before the next one!

if (MSVC)

	add_library(mujs SHARED ${mujs_headers} ${mujs_sources} )

else()

	# Is this hack still needed or does the above work ok.?

	add_library(mujs SHARED ${mujs_headers} one.c)

endif()

# As per make file.

set_property(TARGET mujs PROPERTY C_STANDARD 99)

# We want consistent and predictable names:

set_target_properties(mujs PROPERTIES OUTPUT_NAME "libmujs")

# Some options based on what's in upstream's make file.

if (NOT MSVC)

	target_compile_options(mujs
		PRIVATE
			-pedantic
			-Wall
			-Wextra
			-Wno-unused-parameter
		)

	if (CMAKE_C_COMPILER_ID STREQUAL "Clang")

		target_compile_options(mujs
			PRIVATE
				-Wunreachable-code
		)

	endif()

endif()

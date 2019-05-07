set(luaffi_sources
    luaffi/call_arm.h
    luaffi/call.c
    luaffi/call_x64.h
    luaffi/call_x64win.h
    luaffi/call_x86.h
    luaffi/ctype.c
    luaffi/ffi.c
    luaffi/ffi.h
    luaffi/parser.c
)

add_library(luaffi STATIC ${luaffi_sources})

target_include_directories(luaffi
    PRIVATE
        luaffi
        luaffi/dynasm
        lua54/src
)

target_compile_options(luaffi PRIVATE -Wno-cast-align)
target_compile_options(luaffi PRIVATE -Wno-cast-qual)
target_compile_options(luaffi PRIVATE -Wno-extra)
target_compile_options(luaffi PRIVATE -Wno-unused)
target_compile_options(luaffi PRIVATE -Wno-builtin-declaration-mismatch)
target_compile_options(luaffi PRIVATE -Wno-misleading-indentation)

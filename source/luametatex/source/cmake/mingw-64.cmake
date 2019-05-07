# SET (CMAKE_C_COMPILER "/usr/bin/clang")
# add_compile_options(-target x86_64-pc-windows-gnu)

set(CMAKE_SYSTEM_NAME Windows)
set(TOOLCHAIN_PREFIX  x86_64-w64-mingw32)
set(CMAKE_C_COMPILER  ${TOOLCHAIN_PREFIX}-gcc)

set(extra_libraries
    wsock32
    ws2_32
)

# ws2_32
# dlopen

# if (NOT __MINGW64_TOOLCHAIN_)
#     add_compile_options(-DLUASOCKET_INET_PTON)
# endif()

set(CMAKE_SYSTEM_NAME Windows)
set(TOOLCHAIN_PREFIX  x86_64-w64-mingw32ucrt)
set(CMAKE_C_COMPILER  ${TOOLCHAIN_PREFIX}-gcc)

add_compile_options(-mtune=nocona)

set(LUAMETATEX_MINGW 64)
set(LUAMETATEX_NOLDL 1)

# set(CMAKE_EXE_LINKER_FLAGS "-static-libgcc")

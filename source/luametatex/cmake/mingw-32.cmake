if (NOT __MINGW64_TOOLCHAIN_)
    add_compile_options(-DLUASOCKET_INET_PTON)
endif()

set(CMAKE_SYSTEM_NAME Windows)
set(TOOLCHAIN_PREFIX  i686-w64-mingw32)
set(CMAKE_C_COMPILER  ${TOOLCHAIN_PREFIX}-gcc)

add_compile_options(-mtune=nocona)

set(LUAMETATEX_MINGW 32)

# set(CMAKE_EXE_LINKER_FLAGS "-static-libgcc")

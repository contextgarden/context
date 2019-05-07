set(CMAKE_SYSTEM_NAME Windows)
set(TOOLCHAIN_PREFIX  i686-w64-mingw32)
set(CMAKE_C_COMPILER  ${TOOLCHAIN_PREFIX}-gcc)

set(extra_libraries
    wsock32
    ws2_32
)

# ws2_32
# dlopen

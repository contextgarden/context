# set(CMAKE_C_COMPILER "/usr/bin/clang")

add_compile_options(-DLUA_USE_POSIX)
add_compile_options(-DLUA_USE_DLOPEN)

# a quick hack for wsl

set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -o3 -m32")

set(extra_libraries
    dl
)

# dlopen

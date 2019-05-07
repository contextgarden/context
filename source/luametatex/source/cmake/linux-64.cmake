# set(CMAKE_C_COMPILER "/usr/bin/clang")

add_compile_options(-DLUA_USE_POSIX)
add_compile_options(-DLUA_USE_DLOPEN)

set(extra_libraries
    dl
)

# dlopen

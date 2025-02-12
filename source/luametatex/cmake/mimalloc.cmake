include("source/libraries/mimalloc/cmake/mimalloc-config-version.cmake")

set(mimalloc_sources
    source/libraries/mimalloc/src/alloc.c
    source/libraries/mimalloc/src/alloc-aligned.c
    source/libraries/mimalloc/src/alloc-posix.c
    source/libraries/mimalloc/src/arena.c
    source/libraries/mimalloc/src/bitmap.c
    source/libraries/mimalloc/src/heap.c
    source/libraries/mimalloc/src/init.c
    source/libraries/mimalloc/src/libc.c
    source/libraries/mimalloc/src/options.c
    source/libraries/mimalloc/src/os.c
    source/libraries/mimalloc/src/page.c
    source/libraries/mimalloc/src/random.c
    source/libraries/mimalloc/src/segment.c
    source/libraries/mimalloc/src/segment-map.c
    source/libraries/mimalloc/src/stats.c
    source/libraries/mimalloc/src/prim/prim.c
)

# if (MI_OSX_ZONE)
#     list(APPEND mimalloc_sources source/libraries/mimalloc/src/prim/osx/alloc-override-zone.c)
#     add_definitions(-DMI_OSX_ZONE=1)
#     add_definitions(-DMI_OSX_INTERPOSE=1)
# endif()

set(mi_cflags "")
set(mi_libraries "")

add_library(mimalloc STATIC ${mimalloc_sources})

# set(CMAKE_C_STANDARD 11)
# set(CMAKE_CXX_STANDARD 17)

target_include_directories(mimalloc PRIVATE
    source/libraries/mimalloc
    source/libraries/mimalloc/src
    source/libraries/mimalloc/prim
    source/libraries/mimalloc/include
)

target_compile_definitions(mimalloc PRIVATE
    MIMALLOC_LARGE_OS_PAGES=1
    MI_DEBUG=0
    MI_SECURE=0
    NDEBUG=0
  # MI_DEBUG=3
  # MI_SHOW_ERRORS=1
  # MI_PADDING=1
)

if (NOT MSVC)
    target_compile_options(mimalloc PRIVATE
        -Wno-cast-align
        -Wno-cast-qual
    )
endif ()

# list(APPEND mi_defines MI_LIBC_MUSL=1)
# list(APPEND mi_cflags -Wno-static-in-inline)

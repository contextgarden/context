# The cerf library is actually optional but for now we compile it with the
# rest because the complex interfaces are different per platform. There is
# not that much code involved. But, anyway, at some point it might become
# a real optional module in which case the following will change.

set(luarest_sources

    source/luaoptional/lmtcerflib.c

    source/libraries/libcerf/erfcx.c
    source/libraries/libcerf/err_fcts.c
    source/libraries/libcerf/im_w_of_x.c
    source/libraries/libcerf/w_of_z.c
    source/libraries/libcerf/width.c
)

add_library(luarest STATIC ${luarest_sources})

target_include_directories(luarest PRIVATE
    source/libraries/libcerf
    source/luacore/lua54/src
)

# only when all ok, to avoid messages

include(CheckCCompilerFlag)

CHECK_C_COMPILER_FLAG("-Wno-discarded-qualifiers" limited_support)

if (limited_support)
    target_compile_options(luarest PRIVATE -Wno-discarded-qualifiers)
endif()

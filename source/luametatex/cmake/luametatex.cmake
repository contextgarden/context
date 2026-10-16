add_compile_options(-DLUA_CORE)

set(luametatex_sources
    source/luametatex.c
)

add_executable(luametatex ${luametatex_sources})

target_include_directories(luametatex PRIVATE
    .
    source/.
    source/luacore/lua55/src
)

target_link_libraries(tex PRIVATE luaoptional)
target_link_libraries(luaoptional PRIVATE tex)

target_link_libraries(luametatex

  #  $<LINK_GROUP:REDEF,tex,luarest,utilities,luaoptional,mp>

    luaoptional
    tex
    luarest
    utilities
    lua
    mp

    pplib
    miniz
    softposit
    potrace
    qrcodegen
    triangles
    nanojpeg    
    filib

#   qhull
)

if (LMT_SOCKET_TOO)
    target_link_libraries(luametatex
        luasocket
    )
else()
    if (WIN32)
        target_link_libraries(luametatex
            wsock32
            ws2_32
        )
    endif()
endif()

if (LUAMETATEX_NOLDL) 
    # mingw ucrt
else()
    target_link_libraries(luametatex
        ${CMAKE_DL_LIBS}
    )
endif()

install(TARGETS luametatex
    EXPORT luametatex
    RUNTIME
        DESTINATION ${CMAKE_INSTALL_BINDIR}
        COMPONENT luametatex_runtime
)

if (luametatex_use_mimalloc)
    target_include_directories(luametatex PRIVATE
        source/libraries/mimalloc/include
    )
    target_link_libraries(luametatex
        mimalloc
    )
    if (LUAMETATEX_MINGW)
        target_link_libraries(luametatex --static)
        target_link_libraries(luametatex
            pthread
            psapi
            bcrypt
        )
    elseif (NOT MSVC)
        target_link_libraries(luametatex
            pthread
        )
    endif()
endif()

if (NOT MSVC)
    target_link_libraries(luametatex
        m
)
endif()

if (${CMAKE_HOST_SOLARIS})
    target_link_libraries(luametatex
        rt
        socket
        nsl
        resolv
    )
endif()

if (DEFINED LMT_OPTIMIZE)
    # we strip anyway
elseif (CMAKE_HOST_SOLARIS)
    # no strip
elseif (CMAKE_C_COMPILER_ID MATCHES "GNU")
    # -g -S -d : remove all debugging symbols & sections
    # -x       : remove all non-global symbols
    # -X       : remove any compiler-generated symbols
    add_custom_command(TARGET luametatex POST_BUILD COMMAND ${CMAKE_STRIP} -g -S -d -x luametatex${CMAKE_EXECUTABLE_SUFFIX})
endif()

if (DEFINED LMT_OPTIMIZE)
  # if (MINGW)
    if (NOT MSVC)
        target_compile_options(luametatex PRIVATE
            -Wno-array-bounds
            -Wno-attributes
            -Wno-stringop-overflow
        )

        # If using LTO, pass flag to linker as well so lto1 stays quiet
        target_link_options(luametatex PRIVATE
            -Wno-attributes
            -Wno-stringop-overflow
        )
    endif()
endif()

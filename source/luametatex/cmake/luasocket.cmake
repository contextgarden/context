set(luasocket_sources

    source/luacore/luasocket/src/auxiliar.c
    source/luacore/luasocket/src/buffer.c
    source/luacore/luasocket/src/compat.c
    source/luacore/luasocket/src/except.c
    source/luacore/luasocket/src/inet.c
    source/luacore/luasocket/src/io.c
    source/luacore/luasocket/src/luasocket.c
    source/luacore/luasocket/src/mime.c
    source/luacore/luasocket/src/options.c
    source/luacore/luasocket/src/select.c
    source/luacore/luasocket/src/socket.c
    source/luacore/luasocket/src/tcp.c
    source/luacore/luasocket/src/timeout.c
    source/luacore/luasocket/src/udp.c

  # source/luacore/luasocket/src/serial.c
  # source/luacore/luasocket/src/usocket.c
  # source/luacore/luasocket/src/wsocket.c

  # source/luacore/luasec/src/config.c
  # source/luacore/luasec/src/options.c
  # source/luacore/luasec/src/ec.c
  # source/luacore/luasec/src/x509.c
  # source/luacore/luasec/src/context.c
  # source/luacore/luasec/src/ssl.c

)

add_library(luasocket STATIC ${luasocket_sources})

target_include_directories(luasocket PRIVATE
    source/luacore/luasocket
  # source/luacore/luasec
  # source/luacore/luasec/src
    source/luacore/lua54/src
)

if (NOT MSVC)
    target_compile_options(luasocket PRIVATE
        -Wno-cast-qual
        -Wno-cast-align
    )
endif()

if (WIN32)
    target_link_libraries(luasocket PRIVATE
        wsock32
        ws2_32
    )
endif()

if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    target_compile_definitions(luasocket PRIVATE
        LUASOCKET_INET_PTON
    )
endif()





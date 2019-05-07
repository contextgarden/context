set(luasocket_sources
    luasocket/src/auxiliar.c
    luasocket/src/auxiliar.h
    luasocket/src/buffer.c
    luasocket/src/buffer.h
    luasocket/src/compat.c
    luasocket/src/compat.h
    luasocket/src/except.c
    luasocket/src/except.h
    luasocket/src/inet.c
    luasocket/src/inet.h
    luasocket/src/io.c
    luasocket/src/io.h
    luasocket/src/luasocket.c
    luasocket/src/luasocket.h
    luasocket/src/mime.c
    luasocket/src/mime.h
    luasocket/src/options.c
    luasocket/src/options.h
    luasocket/src/pierror.h
    luasocket/src/select.c
    luasocket/src/select.h
#   luasocket/src/serial.c
    luasocket/src/socket.h
    luasocket/src/socket.c
    luasocket/src/tcp.c
    luasocket/src/tcp.h
    luasocket/src/timeout.c
    luasocket/src/timeout.h
    luasocket/src/udp.c
    luasocket/src/udp.h
#   luasocket/src/usocket.h
#   luasocket/src/usocket.c
#   luasocket/src/wsocket.h
#   luasocket/src/wsocket.c
)

add_library(luasocket STATIC ${luasocket_sources})

target_include_directories(luasocket
    PRIVATE
        luasocket
        lua54/src
)

target_compile_options(luasocket PRIVATE -Wno-implicit-fallthrough)

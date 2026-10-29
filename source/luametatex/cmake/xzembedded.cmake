set(xzembedded_sources
    source/libraries/xzembedded/xz_crc32.c
    source/libraries/xzembedded/xz_crc64.c
    source/libraries/xzembedded/xz_dec_lzma2.c
    source/libraries/xzembedded/xz_dec_stream.c
)

add_library(xzembedded STATIC ${xzembedded_sources})

target_include_directories(xzembedded PUBLIC
    utilities
    source/libraries/xzembedded
)

# target_compile_definitions(xzembedded PUBLIC
#     XZ_USE_CRC64
#     XZ_DEC_CONCATENATED
# )

if (NOT MSVC)
    target_compile_options(xzembedded PRIVATE
        -Wno-cast-align
        -Wno-cast-qual
    )
endif (NOT MSVC)
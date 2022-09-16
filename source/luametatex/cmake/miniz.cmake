set(miniz_sources

    source/libraries/miniz/miniz.c

)

add_library(miniz STATIC ${miniz_sources})

target_compile_definitions(miniz PUBLIC
    MINIZ_NO_ARCHIVE_APIS=1
    MINIZ_NO_STDIO=1
    MINIZ_NO_MALLOC=1
)

if (NOT MSVC)
    target_compile_options(miniz PRIVATE
        -Wno-cast-align
        -Wno-cast-qual
    )
endif (NOT MSVC)


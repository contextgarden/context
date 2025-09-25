set(nanojpeg_sources

  source/libraries/nanojpeg/nanojpeg.c

)

add_library(nanojpeg STATIC ${nanojpeg_sources})

target_include_directories(nanojpeg PRIVATE
    source/libraries/mimalloc/include
    source/libraries/nanojpeg
)

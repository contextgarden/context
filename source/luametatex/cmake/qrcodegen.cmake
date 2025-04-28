set(qrcodegen_sources

  source/libraries/qrcodegen/qrcodegen.c

)

add_library(qrcodegen STATIC ${qrcodegen_sources})

target_include_directories(qrcodegen PRIVATE
    source/libraries/mimalloc/include
    source/libraries/qrcodegen
)
